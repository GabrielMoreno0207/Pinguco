extends Node
## Cena principal: monta o mundo, conecta os sistemas e controla o fluxo
## abertura/menu → turno → pausa → resultados → bar fechado (caixa, caderninho, arrumação).
## Comprar reforma ou mudar de ponto vale no próximo carregamento da cena.

var world: Node3D
var bar: BarBuilder
var player: PlayerController
var order_system: OrderSystem
var shift: ShiftManager
var spawner: CustomerSpawner
var hud: HUDController
## Câmera que passeia pelo bar atrás do menu principal.
var menu_cam: Camera3D
var _menu_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	var args := OS.get_cmdline_user_args()
	if args.has("--autotest") or args.has("--bench"):
		GameManager.set_meta("autotest", true)
	if args.has("--gallery"):
		# vitrine de modelos (garrafas, símbolos e fregueses) para conferir o visual
		GameManager.set_meta("autotest", true)
		add_child(load("res://scripts/tests/gallery.gd").new())
		return
	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)

	bar = BarBuilder.new()
	bar.name = "Bar"
	world.add_child(bar)
	bar.build()

	order_system = OrderSystem.new()
	order_system.name = "OrderSystem"
	world.add_child(order_system)

	shift = ShiftManager.new()
	shift.name = "ShiftManager"
	world.add_child(shift)

	spawner = CustomerSpawner.new()
	spawner.name = "CustomerSpawner"
	spawner.seats = bar.seats
	spawner.door_inside = bar.door_inside
	spawner.door_outside = bar.door_outside
	spawner.order_system = order_system
	spawner.shift = shift
	world.add_child(spawner)

	player = PlayerController.new()
	player.name = "Player"
	player.collision_mask = BarBuilder.WORLD_LAYER | BarBuilder.PLAYER_BLOCK_LAYER
	world.add_child(player)
	player.global_position = bar.player_spawn
	player.rotation.y = PI # começa de frente para o balcão/clientes

	menu_cam = Camera3D.new()
	menu_cam.name = "MenuCamera"
	menu_cam.fov = 70.0
	world.add_child(menu_cam)

	hud = HUDController.new()
	hud.name = "HUD"
	add_child(hud)
	hud.connect_player(player)
	hud.connect_shift(shift)
	hud.start_requested.connect(_start_shift)
	hud.restart_requested.connect(_restart)
	hud.resume_requested.connect(GameManager.resume)
	hud.close_requested.connect(_close_bar)
	hud.arrange_requested.connect(_close_bar)
	hud.reset_requested.connect(func() -> void:
		BarProgress.reset()
		_restart_to_menu())
	hud.menu_requested.connect(func() -> void:
		GameManager.set_state(GameManager.State.MENU)
		_restart_to_menu())
	hud.move_requested.connect(_move_bar)
	bar.cash_register.shop_requested.connect(func() -> void: GameManager.set_state(GameManager.State.SHOP))

	spawner.customer_spawned.connect(hud.add_customer_bubble)
	shift.shift_ended.connect(_on_shift_ended)
	shift.tick.connect(func(_s: float, _c: String) -> void: bar.set_clock(lerpf(18.0, 26.0, shift.progress())))

	AudioManager.start_loop("ambience")
	GameManager.state_changed.connect(func(_s: GameManager.State) -> void: _update_music())

	if args.has("--autotest"):
		var t: Node = load("res://scripts/tests/auto_test.gd").new()
		t.name = "AutoTest"
		add_child(t)
	elif args.has("--bench"):
		add_child(load("res://scripts/tests/bench.gd").new())
	elif GameManager.get_meta("skip_menu", false):
		GameManager.set_meta("skip_menu", false)
		_start_shift()
	elif GameManager.get_meta("enter_closed", false):
		GameManager.set_meta("enter_closed", false)
		_close_bar()
		var loc := BarProgress.loc()
		hud.show_banner("BAR NOVO!", "%s · %s" % [loc.name, loc.place])
		AudioManager.play("correct")
	else:
		GameManager.set_state(GameManager.State.MENU)
	_update_music()


## A jukebox é a fonte do phonk: instalada (nível 2 da decoração), ela toma conta do som
## do bar. Sem ela toca o "rádio" do boteco, que é a faixa padrão em qualquer tela.
func _update_music() -> void:
	var jukebox := bar != null and bar.has_jukebox
	AudioManager.play_music("music_menu" if jukebox else "music")


func _start_shift() -> void:
	GameManager.reset_stats()
	GameManager.set_state(GameManager.State.PLAYING)
	shift.start()
	spawner.start()


func _restart() -> void:
	GameManager.set_meta("skip_menu", true)
	GameManager.set_state(GameManager.State.MENU)
	get_tree().paused = false
	get_tree().reload_current_scene()


## Recarrega a cena com o bar montado a partir do progresso salvo (melhorias + arrumação).
func _restart_to_menu() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## Fora do expediente: a freguesia vai embora e o jogador anda livre pelo bar.
func _close_bar() -> void:
	spawner.stop()
	shift.running = false
	spawner.clear_all()
	bar.set_clock(26.0)
	GameManager.set_state(GameManager.State.CLOSED)


## Paga o ponto novo e recarrega a cena já com o bar novo, fechado para arrumar.
func _move_bar() -> void:
	if not BarProgress.move_to_next():
		return
	GameManager.set_meta("enter_closed", true)
	get_tree().paused = false
	get_tree().reload_current_scene()


func _process(delta: float) -> void:
	if menu_cam == null:
		return
	if GameManager.state == GameManager.State.MENU:
		if not menu_cam.current:
			menu_cam.make_current()
		# passeio lento pelo salão, olhando para o balcão
		_menu_t += delta * 0.11
		var t := _menu_t
		menu_cam.position = Vector3(sin(t) * 2.8, 1.8 + sin(t * 0.7) * 0.12, 3.5 + cos(t * 0.8) * 0.6)
		menu_cam.look_at(Vector3(sin(t * 0.5) * 0.9, 1.25, -1.3))
	elif menu_cam.current:
		player.camera.make_current()


func _on_shift_ended(reason: String) -> void:
	spawner.stop()
	BarProgress.deposit_shift(GameManager.stats.money)
	hud.show_results(reason)
	GameManager.set_state(GameManager.State.RESULTS)
	AudioManager.play("correct", 0.7)


func _notification(what: int) -> void:
	# alt-tab pausa o turno
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and GameManager.can_act() and not GameManager.has_meta("autotest"):
		GameManager.pause()


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.has_meta("autotest"):
		return
	if event.is_action_pressed("pause"):
		match GameManager.state:
			GameManager.State.PLAYING, GameManager.State.CLOSED:
				GameManager.pause()
			GameManager.State.PAUSED:
				GameManager.resume()
			GameManager.State.SHOP:
				GameManager.set_state(GameManager.State.CLOSED)
	elif event is InputEventMouseButton and event.pressed and GameManager.can_act() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
