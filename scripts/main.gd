extends Node
## Cena principal: monta o mundo, conecta os sistemas e controla o fluxo
## menu → turno → pausa → resultados.

var world: Node3D
var bar: BarBuilder
var player: PlayerController
var order_system: OrderSystem
var shift: ShiftManager
var spawner: CustomerSpawner
var hud: HUDController


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	if OS.get_cmdline_user_args().has("--gallery"):
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

	hud = HUDController.new()
	hud.name = "HUD"
	add_child(hud)
	hud.connect_player(player)
	hud.connect_shift(shift)
	hud.start_requested.connect(_start_shift)
	hud.restart_requested.connect(_restart)
	hud.resume_requested.connect(func() -> void: GameManager.set_state(GameManager.State.PLAYING))

	spawner.customer_spawned.connect(hud.add_customer_bubble)
	shift.shift_ended.connect(_on_shift_ended)
	shift.tick.connect(func(_s: float, _c: String) -> void: bar.set_clock(lerpf(18.0, 26.0, shift.progress())))

	AudioManager.start_loop("ambience")
	AudioManager.start_loop("music")

	if OS.get_cmdline_user_args().has("--autotest"):
		GameManager.set_meta("autotest", true)
		var t: Node = load("res://scripts/tests/auto_test.gd").new()
		t.name = "AutoTest"
		add_child(t)
	elif OS.get_cmdline_user_args().has("--bench"):
		GameManager.set_meta("autotest", true)
		add_child(load("res://scripts/tests/bench.gd").new())
	elif GameManager.get_meta("skip_menu", false):
		GameManager.set_meta("skip_menu", false)
		_start_shift()
	else:
		GameManager.set_state(GameManager.State.MENU)


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


func _on_shift_ended(reason: String) -> void:
	spawner.stop()
	hud.show_results(reason)
	GameManager.set_state(GameManager.State.RESULTS)
	AudioManager.play("correct", 0.7)


func _notification(what: int) -> void:
	# alt-tab pausa o turno
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and GameManager.is_playing() and not GameManager.has_meta("autotest"):
		GameManager.set_state(GameManager.State.PAUSED)


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.has_meta("autotest"):
		return
	if event.is_action_pressed("pause"):
		match GameManager.state:
			GameManager.State.PLAYING:
				GameManager.set_state(GameManager.State.PAUSED)
			GameManager.State.PAUSED:
				GameManager.set_state(GameManager.State.PLAYING)
	elif event is InputEventMouseButton and event.pressed and GameManager.is_playing() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
