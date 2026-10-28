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
	if shots:
		var menu: MainMenu = main.hud._menu
		for page: StringName in [&"splash", &"howto", &"options", &"confirm"]:
			menu.show_page(page)
			await wait(1.6 if page == &"splash" else 0.3)
			await shot("01_menu_%s" % page)
		menu.show_page(&"main")
	main._start_shift()
	spawner.stop() # controlamos os fregueses manualmente
	await wait(0.3)
	check(GameManager.is_playing(), "turno iniciou (estado PLAYING)")
	check(BeverageDatabase.drinks().size() >= 12, "%d bebidas registradas" % BeverageDatabase.drinks().size())
	check(BeverageDatabase.foods().size() >= 2, "salgados registrados")
	var all_drinks_placed := true
	for bev in BeverageDatabase.drinks():
		if not bar.dispensers.has(bev.id):
			all_drinks_placed = false
			print("     sem dispenser: ", bev.id)
	check(all_drinks_placed, "toda bebida tem garrafa no cenário")
	var all_foods_placed := true
	for food in BeverageDatabase.foods():
		all_foods_placed = all_foods_placed and bar.snack_trays.has(food.id)
	check(all_foods_placed, "todo salgado tem bandeja na estufa")
	check(CustomerDatabase.all().size() >= 6, "%d tipos de freguês" % CustomerDatabase.all().size())
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
	if shots:
		var keep_pos := player.global_position
		player.global_position = Vector3(-0.9, 0.05, -1.2)
		_aim_at(player, Vector3(-0.9, 1.35, -2.45))
		await wait(0.3)
		await shot("03b_shelves")
		player.global_position = Vector3(2.6, 0.05, -1.0)
		_aim_at(player, bar.snack_trays.values()[0].global_position)
		await wait(0.3)
		await shot("03c_snacks")
		player.global_position = keep_pos
		_aim_at(player, bar.glass_stacks[0].global_position + Vector3(0, 0.1, 0))
		await wait(0.25)
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

	# ---------------------------------------------------------------- fome e salgados
	check(main.hud.find_children("*", "StatusTag", true, false).size() >= 3, "bafômetro sobre a cabeça de cada freguês")
	player.set_held(HeldItem.empty())
	player.interaction.force_interact(bar.snack_trays[&"coxinha"])
	check(player.held.is_food() and player.held.beverage.id == &"coxinha", "pega coxinha na estufa")
	orders.cancel(falante)
	falante.state = CustomerController.State.ORDERING
	orders.create_order(falante, &"coxinha", 30.0)
	falante.drunk_level = 50.0
	falante.hunger = 1.0
	var food_text := orders.get_order(falante).text
	falante.receive(player)
	check(GameManager.stats.food_served == 1, "salgado entregue (pedido: \"%s\")" % food_text)
	check(falante.drunk_level < 50.0, "salgado corta o porre (%.0f → %.1f)" % [50.0, falante.drunk_level])
	check(falante.hunger == 0.0, "salgado mata a fome")
	check(tiozao.hunger > 0.0 or tiozao.drinks == 0 or BeverageDatabase.get_beverage(tiozao.last_beverage).strength <= 0.0, "bebida alcoólica dá fome")
	var hungry_test := CustomerController.new()
	hungry_test.profile = CustomerDatabase.get_profile(&"universitario")
	hungry_test.hunger = 1.0
	hungry_test.drunk_level = hungry_test.profile.tolerance * 0.3 # alegre: a larica já bateu
	var got_food := false
	for k in 30:
		got_food = got_food or BeverageDatabase.get_beverage(hungry_test._pick_order_item()).is_food()
	check(got_food, "freguês com fome pede salgado")
	hungry_test.free()

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
		var ob := BeverageDatabase.get_beverage(o.beverage_id)
		player.set_held(HeldItem.food(ob) if ob.is_food() else HeldItem.glass(ob))
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
		if b.is_food():
			continue
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

	# ---------------------------------------------------------------- bar fechado: caixa
	var earned: int = GameManager.stats.money
	check(BarProgress.register_cash == earned, "féria do turno vai pra gaveta do caixa (R$ %d)" % earned)
	main._close_bar()
	await wait(0.3)
	check(GameManager.is_closed(), "fechar o caixa deixa o bar fechado (estado CLOSED)")
	BarProgress.register_cash += 500 # garante saldo para testar o investimento
	var bank0 := BarProgress.bank
	player.interaction.force_interact(bar.cash_register)
	check(BarProgress.register_cash == 0 and BarProgress.bank == bank0 + earned + 500, "recolher a gaveta passa o dinheiro pro saldo")
	player.interaction.force_interact(bar.cash_register)
	check(GameManager.state == GameManager.State.SHOP, "caixa vazia abre o caderninho de investimentos")
	await wait(0.2)
	await shot("10_shop")
	if shots:
		for tab: StringName in [&"reform", &"move"]:
			main.hud._shop_tab = tab
			main.hud._refresh_shop()
			await wait(0.2)
			await shot("10_shop_%s" % tab)
		main.hud._shop_tab = &"service"
	var cost := BarProgress.next_cost(&"cardapio")
	var bank1 := BarProgress.bank
	check(BarProgress.buy(&"cardapio") and BarProgress.bank == bank1 - cost and BarProgress.level(&"cardapio") == 1,
		"comprar melhoria desconta do saldo")
	var cerveja := BeverageDatabase.get_beverage(&"cerveja")
	check(BarProgress.price_of(cerveja) > cerveja.price, "cardápio reajustado aumenta o preço")
	BarProgress.bank = 0
	check(not BarProgress.buy(&"neon"), "sem saldo não compra")
	GameManager.set_state(GameManager.State.CLOSED)

	# ---------------------------------------------------------------- bar fechado: arrumação
	var beer: BottleDispenser = bar.dispensers[&"cerveja"]
	var empty: BottleSlot = null
	for sl: BottleSlot in bar.bottle_slots.values():
		if sl.occupant == null and String(sl.id).begins_with("shelf_"):
			empty = sl
			break
	check(empty != null, "prateleira tem lugar vazio para arrumar")
	player.interaction.force_interact(beer)
	check(player.held.is_bottle() and player.held.source == beer, "pega garrafa com o bar fechado")
	if shots:
		player.global_position = Vector3(empty.global_position.x, player.global_position.y, -1.3)
		_aim_at(player, empty.global_position + Vector3(0, 0.15, 0))
		await wait(0.3)
		check(player.interaction.focused == empty, "mirar num lugar vazio foca o lugar")
		await shot("11a_arrange")
	player.interaction.force_interact(empty)
	check(beer.slot == empty and beer.get_parent() == empty and beer.model.visible and player.held.is_empty(),
		"garrafa guardada em outro lugar")
	check(BarProgress.slot_of(&"cerveja") == empty.id, "arrumação registrada no progresso")
	var pinga: BottleDispenser = bar.dispensers[&"pinga"]
	var pinga_slot := pinga.slot
	player.interaction.force_interact(pinga)
	player.interaction.force_interact(beer)
	check(beer.slot == pinga_slot and pinga.slot == empty and pinga_slot.occupant == beer and empty.occupant == pinga,
		"troca duas garrafas de lugar")
	await shot("11_closed")

	# ---------------------------------------------------------------- reformas e mudança de ponto
	BarProgress.bank = 100000
	var tip0 := BarProgress.ambience_tip()
	check(BarProgress.buy(&"pintura") and BarProgress.ambience_tip() == tip0 + 1, "reforma comprada rende gorjeta extra")
	check(not BarProgress.can_move(), "não muda de ponto antes do tempo (dia %d)" % BarProgress.day)
	BarProgress.day = 5
	for id: StringName in [&"piso", &"luz", &"tv"]:
		BarProgress.buy(id)
	check(BarProgress.reform_count() >= 3 and BarProgress.can_move(), "dia 5 + 3 reformas + dinheiro libera o próximo ponto")
	var bank_before := BarProgress.bank
	check(BarProgress.move_to_next() and BarProgress.location == &"choperia", "muda para a Choperia")
	check(BarProgress.bank == bank_before - int(BarLocations.get_location(&"choperia").cost), "mudança desconta o preço do ponto")
	check(BarProgress.reform_count() == 0 and BarProgress.layout.is_empty(), "bar novo começa sem reformas nem arrumação")
	var beer_price := BarProgress.price_of(BeverageDatabase.get_beverage(&"cerveja"))
	check(beer_price > BeverageDatabase.get_beverage(&"cerveja").price, "ponto novo cobra mais caro (cerveja R$ %d)" % beer_price)

	# save: grava e lê de volta (arquivo de teste, o save do jogador fica intacto)
	var bp_script: GDScript = load("res://scripts/systems/bar_progress.gd")
	var w: Node = bp_script.new()
	w.save_path = "user://autotest_progress.json"
	w.day = 7
	w.location = &"choperia"
	w.bank = 1234
	w.register_cash = 56
	w.levels = {&"pintura": 1, &"luz": 2}
	w.layout = {&"cerveja": &"shelf_3"}
	w._commit()
	var r: Node = bp_script.new()
	r.save_path = w.save_path
	r._load()
	check(r.day == 7 and r.location == &"choperia" and r.bank == 1234 and r.register_cash == 56
		and r.level(&"luz") == 2 and r.level(&"pintura") == 1 and r.slot_of(&"cerveja") == &"shelf_3",
		"save grava e carrega ponto, dinheiro, reformas e arrumação")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(w.save_path))
	w.free()
	r.free()

	# a jukebox troca o rádio do boteco pelo phonk; sem ela a faixa padrão vale em qualquer tela
	main.bar.has_jukebox = false
	main._update_music()
	check(AudioManager.music_name() == "music", "sem jukebox toca o rádio do boteco")
	main.bar.has_jukebox = true
	main._update_music()
	check(AudioManager.music_name() == "music_menu", "com jukebox toca o phonk")
	main.bar.has_jukebox = false
	main._update_music()
	check(AudioManager.music_name() == "music", "tirar a jukebox devolve o rádio")

	# monta cada ponto, sem e com todas as reformas, e confere que o bar fica jogável
	main.bar.visible = false
	# só um WorldEnvironment vale por vez: tira o do bar principal enquanto testa os outros
	var main_env: WorldEnvironment = main.bar.find_children("*", "WorldEnvironment", false, false)[0]
	main.bar.remove_child(main_env)
	for loc_id: StringName in BarLocations.ORDER:
		for full in [false, true]:
			BarProgress.location = loc_id
			BarProgress.levels = {}
			if full:
				for u: Dictionary in BarProgress.UPGRADES:
					BarProgress.levels[u.id] = BarProgress.max_level(u.id)
			BarProgress.layout = {}
			var b := BarBuilder.new()
			main.world.add_child(b)
			b.build()
			var ok := b.dispensers.size() == BeverageDatabase.drinks().size() and b.seats.size() == BarProgress.seat_count() \
				and b.cash_register != null and b.prep_stations.size() == 3
			check(ok, "%s %s: monta com %d banquetas e todas as garrafas" % [loc_id, "reformado" if full else "original", b.seats.size()])
			check(b.has_jukebox == full, "%s %s: jukebox %s" % [loc_id, "reformado" if full else "original",
				"instalada" if full else "ainda não"])
			if shots:
				player.global_position = Vector3(0, 0.05, -1.0)
				_aim_at(player, Vector3(0, 1.4, 4.5))
				await wait(0.4)
				await shot("12_%s_%s" % [loc_id, "full" if full else "base"])
			b.queue_free()
			await get_tree().process_frame
	main.bar.visible = true
	main.bar.add_child(main_env)

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
