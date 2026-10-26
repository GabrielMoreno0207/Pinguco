class_name PrepStation
extends Interactable
## Área de preparo: apoie o copo, segure E com a garrafa para servir/preparar,
## depois pegue o copo pronto para entregar.

enum State { EMPTY, GLASS, READY }

var state: State = State.EMPTY
var beverage: BeverageData = null
var progress := 0.0
var _glass: Node3D
var _mat: Node3D
var _pour_audio: AudioStreamPlayer3D
var _pouring_bev: BeverageData
var _pour_time := 0.0


static func create(index: int) -> PrepStation:
	var p := PrepStation.new()
	p.name = "PrepStation%d" % index
	p._mat = Node3D.new()
	p.add_child(p._mat)
	# tapetinho de borracha de bar
	Mats.box(p._mat, Vector3(0.42, 0.012, 0.3), Vector3(0, 0.006, 0), Color(0.1, 0.32, 0.22), false)
	for i in 5:
		Mats.box(p._mat, Vector3(0.38, 0.004, 0.018), Vector3(0, 0.014, -0.11 + i * 0.055), Color(0.15, 0.42, 0.3), false)
	var lbl := Mats.label3d(p, "PREPARO", Vector3(0, 0.016, -0.12), 22, UiTheme.MUSTARD, 4)
	lbl.rotation_degrees = Vector3(-90, 180, 0)
	lbl.pixel_size = 0.0014
	p.highlight_root = p._mat
	p.setup_shape(Vector3(0.44, 0.3, 0.32), Vector3(0, 0.12, 0))
	return p


func _ready() -> void:
	_pour_audio = AudioManager.make_loop_player_3d("pour", self)


func get_prompt(player: PlayerController) -> String:
	var h := player.held
	match state:
		State.EMPTY:
			if h.is_empty_glass():
				return "Apoiar copo"
			if h.is_served_glass():
				return "Apoiar copo de %s" % h.beverage.display_name
		State.GLASS:
			if h.is_bottle():
				return "Segure: %s (%s)" % [h.beverage.prep_verb, h.beverage.display_name]
			if h.is_empty():
				return "Pegar copo vazio"
		State.READY:
			if h.is_empty():
				return "Pegar %s %s" % [beverage.display_name, "pronto" if beverage.article == "um" else "pronta"]
	return ""


func get_hint(player: PlayerController) -> String:
	var h := player.held
	if state == State.EMPTY and h.is_bottle():
		return "Coloque um copo aqui primeiro!"
	if state == State.READY and not h.is_empty():
		return "Copo de %s pronto aqui" % beverage.display_name
	if state == State.GLASS and h.is_glass_any():
		return "Já tem um copo aqui"
	return ""


func is_hold_action(player: PlayerController) -> bool:
	return state == State.GLASS and player.held.is_bottle()


func interact(player: PlayerController) -> void:
	var h := player.held
	match state:
		State.EMPTY:
			if h.kind == HeldItem.Kind.GLASS:
				_place_glass(h.beverage if h.filled else null)
				player.set_held(HeldItem.empty())
				AudioManager.play_at("clink", global_position)
		State.GLASS:
			if h.is_empty():
				_remove_glass()
				player.set_held(HeldItem.glass())
		State.READY:
			if h.is_empty():
				player.set_held(HeldItem.glass(beverage))
				_remove_glass()
				AudioManager.play_at("clink", global_position, 1.1)


func interact_hold(player: PlayerController, delta: float) -> float:
	if not is_hold_action(player):
		return 0.0
	var bev := player.held.beverage
	if _pouring_bev != bev:
		_pouring_bev = bev
		progress = 0.0
	progress += delta / maxf(BarProgress.prep_time_of(bev), 0.1)
	_pour_time += delta
	if not _pour_audio.playing:
		_pour_audio.pitch_scale = 0.9 + bev.prep_time * 0.05
		_pour_audio.play()
	BeverageModels.set_glass_fill(_glass, bev, clampf(progress, 0.05, 1.0))
	player.hands.set_pouring(true)
	if progress >= 1.0:
		_finish_pour(player, bev)
		return 1.0
	return progress


func interact_release(player: PlayerController) -> void:
	_pour_audio.stop()
	player.hands.set_pouring(false)
	if state == State.GLASS and progress < 1.0:
		# soltou no meio: o copo fica com o que já foi servido, mas recomeça a contagem
		progress = 0.0
		_pouring_bev = null
		BeverageModels.set_glass_fill(_glass, null, 0.0)


func _finish_pour(player: PlayerController, bev: BeverageData) -> void:
	_pour_audio.stop()
	player.hands.set_pouring(false)
	state = State.READY
	beverage = bev
	progress = 0.0
	_pouring_bev = null
	BeverageModels.set_glass_fill(_glass, bev, 1.0)
	_pop(_glass)
	AudioManager.play_at("clink", global_position, 1.3)
	# a garrafa volta para o lugar dela sozinha
	var source := player.held.source as BottleDispenser
	player.set_held(HeldItem.empty())
	if source:
		source.set_taken(false)


func _place_glass(bev: BeverageData) -> void:
	_glass = BeverageModels.build_glass(bev)
	_glass.position = Vector3(0, 0.012, 0)
	add_child(_glass)
	_pop(_glass)
	if bev:
		state = State.READY
		beverage = bev
	else:
		state = State.GLASS


func _remove_glass() -> void:
	if _glass:
		_glass.queue_free()
		_glass = null
	state = State.EMPTY
	beverage = null
	progress = 0.0


func _pop(n: Node3D) -> void:
	n.scale = Vector3(1.3, 0.7, 1.3)
	create_tween().tween_property(n, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
