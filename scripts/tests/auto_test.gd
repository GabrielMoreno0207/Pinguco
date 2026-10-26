extends Node
## Teste automatizado de ponta a ponta. Rode com:
##   godot --path pinguco -- --autotest            (com janela; adicione --shots para screenshots)
##   godot --headless --path pinguco -- --autotest
## Joga um turno simulando o jogador e valida os critérios principais.

var main: Node
var failures: PackedStringArray = []
var passes := 0
var shots := false
var shot_dir := "user://shots"


func _ready() -> void:
	main = get_parent()
	shots = OS.get_cmdline_user_args().has("--shots")
	if shots:
		DirAccess.make_dir_recursive_absolute(shot_dir)
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("  [ok] ", what)
	else:
		failures.append(what)
		print("  [FALHOU] ", what)


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func shot(file: String) -> void:
	if not shots:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_dir.path_join(file + ".png"))
	print("  [shot] ", ProjectSettings.globalize_path(shot_dir.path_join(file + ".png")))


func _run() -> void:
	print("=== PINGUÇO AUTOTEST ===  renderer: ", RenderingServer.get_current_rendering_method())
	var player: PlayerController = main.player
	var bar: BarBuilder = main.bar
	var spawner: CustomerSpawner = main.spawner
	var orders: OrderSystem = main.order_system

	# ---------------------------------------------------------------- menu
	GameManager.set_state(GameManager.State.MENU)
	await wait(0.5)
	await shot("01_menu")
	main._start_shift()
	spawner.stop() # controlamos os fregueses manualmente
	await wait(0.3)
	check(GameManager.is_playing(), "turno iniciou (estado PLAYING)")
	check(BeverageDatabase.all().size() == 6, "6 bebidas registradas")
	for bev in BeverageDatabase.all():
		check(bar.dispensers.has(bev.id), "dispenser no cenário: %s" % bev.display_name)
	check(bar.seats.size() >= 3, "pelo menos 3 posições de cliente")

	# ---------------------------------------------------------------- movimento
	var p0 := player.global_position
	Input.action_press("move_forward")
	await wait(0.6)
	Input.action_release("move_forward")
	await wait(0.2)
	check(player.global_position.distance_to(p0) > 0.3, "WASD move o jogador")
	check(player.is_on_floor(), "gravidade/colisão: jogador no chão")
	# tenta atravessar o balcão
	for i in 60:
		Input.action_press("move_forward")
		await get_tree().physics_frame
	Input.action_release("move_forward")
	check(player.global_position.z < -0.3, "balcão bloqueia o jogador (z=%.2f)" % player.global_position.z)
	var yaw0 := player.rotation.y
	player.apply_look(Vector2(120, 40))
	check(absf(player.rotation.y - yaw0) > 0.1, "mouse gira a câmera")
	await shot("02_counter_view")

	# ---------------------------------------------------------------- raycast de interação
	player.global_position = Vector3(bar.glass_stacks[0].global_position.x, 0.05, -1.3)
	await wait(0.1)
	_aim_at(player, bar.glass_stacks[0].global_position + Vector3(0, 0.1, 0))
	await wait(0.25)
	check(player.interaction.focused == bar.glass_stacks[0], "mirar nos copos foca a pilha de copos")
	await shot("03_aim_glasses")
	await _press_interact()
	await wait(0.1)
	check(player.held.is_empty_glass(), "tecla E pega um copo")

	# ---------------------------------------------------------------- clientes
	var tiozao := spawner.spawn(CustomerDatabase.get_profile(&"tiozao"))
	var valentao := spawner.spawn(CustomerDatabase.get_profile(&"valentao"))
	var falante := spawner.spawn(CustomerDatabase.get_profile(&"falante"))
	check(tiozao != null and valentao != null and falante != null, "3 tipos de cliente surgem")
	Engine.time_scale = 4.0
	await _wait_for(func() -> bool: return orders.has_order(tiozao) and orders.has_order(valentao) and orders.has_order(falante), 30.0)
	Engine.time_scale = 1.0
	check(orders.has_order(tiozao), "clientes sentam e fazem pedidos")
	player.global_position = Vector3(0, 0.05, -1.0)
	_aim_at(player, tiozao.head_position() + Vector3(0, -0.3, 0))
	await wait(0.4)
	await shot("04_orders")
	print("  FPS=", Engine.get_frames_per_second(), " draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " objs=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))

	# ---------------------------------------------------------------- fluxo de preparo pelo raycast
	var station: PrepStation = bar.prep_stations[0]
	player.global_position = Vector3(station.global_position.x, 0.05, -0.9)
	_aim_at(player, station.global_position + Vector3(0, 0.05, 0))
	await wait(0.25)
	check(player.interaction.focused == station, "mirar na área de preparo foca a estação")
	await _press_interact()
	check(station.state == PrepStation.State.GLASS, "copo apoiado na área de preparo")

	var order := orders.get_order(tiozao)
	var bev := BeverageDatabase.get_beverage(order.beverage_id)
	player.interaction.force_interact(bar.dispensers[bev.id])
	check(player.held.is_bottle() and player.held.beverage == bev, "pega a garrafa de %s" % bev.display_name)
	check(not bar.dispensers[bev.id].model.visible, "garrafa sai da prateleira")
	_aim_at(player, station.global_position + Vector3(0, 0.05, 0))
	await wait(0.2)
	_send_interact(true)
	await shot("05_pouring")
	for i in 6:
		await wait((bev.prep_time + 0.5) / 6.0)
		if not Input.is_action_pressed("interact"):
			print("  dbg: E solto pelo SO, reenviando")
			_send_interact(true)
	_send_interact(false)
	await wait(0.1)
	check(station.state == PrepStation.State.READY and station.beverage == bev, "segurar E prepara a bebida (%.1fs)" % bev.prep_time)
	check(player.held.is_empty(), "garrafa volta sozinha ao lugar")
	check(bar.dispensers[bev.id].model.visible, "garrafa reaparece na prateleira")
	await _press_interact()
	check(player.held.is_served_glass() and player.held.beverage == bev, "pega o copo pronto")

	# ---------------------------------------------------------------- validação de entrega
	var money0: int = GameManager.stats.money
	# entrega para o cliente errado (se ele pediu outra coisa)
	var other := valentao if orders.get_order(valentao).beverage_id != bev.id else falante
	if orders.get_order(other).beverage_id != bev.id:
		other.receive(player)
		check(GameManager.stats.wrong == 1, "entregar ao cliente errado conta como erro")
		check(player.held.is_served_glass(), "copo recusado continua na mão")
		check(GameManager.stats.correct == 0, "entrega errada não conta como acerto")
	player.global_position = Vector3(tiozao.global_position.x, 0.05, -0.7)
	await wait(0.1)
	_aim_at(player, tiozao.head_position() + Vector3(0, -0.25, 0))
	await wait(0.25)
	check(player.interaction.focused is CustomerHitbox, "mirar no cliente foca o cliente")
	await _press_interact()
	check(GameManager.stats.correct == 1, "entrega correta validada")
	check(GameManager.stats.money > money0, "dinheiro aumentou (R$ %d)" % GameManager.stats.money)
	check(tiozao.drunk_level > 0.0 or bev.strength <= 0.0, "embriaguez do Tiozão mudou conforme a bebida (%.0f)" % tiozao.drunk_level)
	check(valentao.drunk_level == 0.0, "embriaguez é individual (Valentão ainda 0)")
	await wait(0.8)
	await shot("06_drinking")

	# ---------------------------------------------------------------- pedido atrasado
	var vo := orders.get_order(valentao)
	vo.patience_left = 0.05
	await wait(0.3)
	check(GameManager.stats.late >= 1, "pedido atrasado detectado")

	# ---------------------------------------------------------------- progressão até capotar
	print("  -- pedidos do Tiozão conforme bebe:")
	var stages_seen := {}
	var guard := 0
	Engine.time_scale = 4.0
	while is_instance_valid(tiozao) and tiozao.state != CustomerController.State.PASSING_OUT \
			and tiozao.state != CustomerController.State.ASLEEP and guard < 30:
		guard += 1
		await _wait_for(func() -> bool: return not is_instance_valid(tiozao) or orders.has_order(tiozao) or tiozao.state == CustomerController.State.PASSING_OUT, 30.0)
		if not is_instance_valid(tiozao) or not orders.has_order(tiozao):
			break
		var o := orders.get_order(tiozao)
		stages_seen[o.stage] = true
		print("     [%s] \"%s\"  pistas=%s  (bebida real: %s)" % [DrunkennessSystem.STAGE_NAMES[o.stage], o.text, _clue_str(o.clues), o.beverage_id])
		player.set_held(HeldItem.glass(BeverageDatabase.get_beverage(o.beverage_id)))
		tiozao.receive(player)
		if o.stage >= 2 and not stages_seen.has(&"shot_drunk"):
			stages_seen[&"shot_drunk"] = true
			Engine.time_scale = 1.0
			_aim_at(player, tiozao.head_position() + Vector3(0, -0.3, 0))
			await wait(0.3)
			await shot("07_drunk_customer")
			Engine.time_scale = 4.0
	check(stages_seen.has(0) and stages_seen.has(1) and stages_seen.has(2), "pedidos passam por vários estágios de embriaguez (%s)" % str(stages_seen.keys()))
	await _wait_for(func() -> bool: return is_instance_valid(tiozao) and tiozao.state == CustomerController.State.ASLEEP, 10.0)
	Engine.time_scale = 1.0
	check(GameManager.stats.passed_out >= 1, "cliente capotou")
	check(is_instance_valid(tiozao) and tiozao.state == CustomerController.State.ASLEEP, "cliente dormindo no balcão")
	check(not orders.has_order(tiozao), "cliente capotado não pede mais")
	_aim_at(player, tiozao.head_position() + Vector3(0, -0.5, 0))
	await wait(1.2)
	await shot("08_passed_out")
	var seat := tiozao.seat
	Engine.time_scale = 4.0
	await _wait_for(func() -> bool: return seat.occupant != tiozao, 20.0)
	Engine.time_scale = 1.0
	check(seat.occupant != tiozao, "cliente libera a banqueta depois de capotar")
	var newcomer := spawner.spawn()
	check(newcomer != null, "novo freguês pode ocupar a posição")

	# ---------------------------------------------------------------- distorção (verificação estatística)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var prof := CustomerDatabase.get_profile(&"falante")
	var all_ok := true
	for b in BeverageDatabase.all():
		for st in 4:
			for k in 20:
				var r := DrunkennessSystem.compose_order(prof, b, st, &"", rng)
				var clue_count := int(r.clues.color) + int(r.clues.letter) + int(r.clues.symbol)
				if clue_count < 1 or (st <= 1 and clue_count < 3):
					all_ok = false
				if st == 0 and not r.text.to_lower().contains(b.display_name.to_lower()):
					all_ok = false
	check(all_ok, "pedidos sóbrios são claros e todo pedido mantém ao menos uma pista visual")

	# ---------------------------------------------------------------- fim de turno
	main.shift.time_left = 0.2
	await wait(0.6)
	check(GameManager.state == GameManager.State.RESULTS, "turno termina e mostra resultados")
	await shot("09_results")

	print("=== RESULTADO: %d ok, %d falhas ===" % [passes, failures.size()])
	for f in failures:
		print("   FALHA: ", f)
	print("AUTOTEST " + ("PASS" if failures.is_empty() else "FAIL"))
	Engine.time_scale = 1.0
	get_tree().quit(0 if failures.is_empty() else 1)


func _send_interact(down: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = down
	Input.parse_input_event(ev)


func _press_interact() -> void:
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var up := InputEventAction.new()
	up.action = &"interact"
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().physics_frame


func _wait_for(cond: Callable, timeout: float) -> void:
	var t := 0.0
	while not cond.call() and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time() / maxf(Engine.time_scale, 0.01)


func _aim_at(player: PlayerController, target: Vector3) -> void:
	var cam := player.camera
	var from := player.global_position + Vector3(0, player.eye_height, 0)
	var d := target - from
	player.rotation.y = atan2(-d.x, -d.z)
	var flat := Vector2(d.x, d.z).length()
	player.set("_pitch", atan2(d.y, flat))
	cam.rotation.x = atan2(d.y, flat)


func _clue_str(c: Dictionary) -> String:
	var parts := []
	for k in ["color", "letter", "symbol"]:
		if c[k]:
			parts.append({"color": "cor", "letter": "letra", "symbol": "símbolo"}[k])
	return "+".join(parts)
