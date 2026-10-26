class_name Hands
extends Node3D
## Mãos estilizadas em primeira pessoa (viewmodel) segurando garrafa/copo.

const SKIN := Color(0.96, 0.76, 0.6)
const SLEEVE := Color(0.85, 0.2, 0.18)

var _right: Node3D
var _left: Node3D
var _item_anchor: Node3D
var _item: Node3D
var _base_right := Vector3(0.24, -0.27, -0.44)
var _base_left := Vector3(-0.3, -0.34, -0.48)
var _pouring := false
var _pour_blend := 0.0
var _poke := 0.0
var _sway := Vector2.ZERO


func _ready() -> void:
	_right = _build_hand(true)
	_right.position = _base_right
	add_child(_right)
	_left = _build_hand(false)
	_left.position = _base_left
	add_child(_left)
	_item_anchor = Node3D.new()
	_item_anchor.position = Vector3(-0.005, 0.0, -0.035)
	_right.add_child(_item_anchor)


func _build_hand(right: bool) -> Node3D:
	var h := Node3D.new()
	var side := 1.0 if right else -1.0
	# antebraço com manga de camisa de botequeiro
	var arm := Mats.capsule(h, 0.045, 0.32, Vector3(0.03 * side, -0.07, 0.16), SKIN, false)
	arm.rotation_degrees = Vector3(70, 0, 0)
	var sleeve := Mats.cylinder(h, 0.062, 0.12, Vector3(0.04 * side, -0.13, 0.31), SLEEVE, false)
	sleeve.rotation_degrees = Vector3(70, 0, 0)
	# palma + dedões cartunescos
	Mats.sphere(h, 0.055, Vector3(0, 0, 0), SKIN, false, Vector3(1.0, 1.15, 0.8))
	Mats.capsule(h, 0.02, 0.07, Vector3(-0.045 * side, 0.02, -0.025), SKIN, false).rotation_degrees = Vector3(0, 0, 30 * side)
	for i in 3:
		var f := Mats.capsule(h, 0.019, 0.06, Vector3(0.012 * side - 0.0, 0.04 - i * 0.03, -0.045), SKIN, false)
		f.rotation_degrees = Vector3(90, 0, 0)
	for c in h.find_children("*", "MeshInstance3D", true, false):
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.set_meta("no_highlight", true)
	return h


func show_item(item: HeldItem) -> void:
	if _item:
		_item.queue_free()
		_item = null
	match item.kind:
		HeldItem.Kind.BOTTLE:
			_item = BeverageModels.build_container(item.beverage)
			_item.position = Vector3(0, -0.12, 0)
			_item.scale = Vector3.ONE * 0.9
		HeldItem.Kind.GLASS:
			_item = BeverageModels.build_glass(item.beverage if item.filled else null)
			_item.position = Vector3(0, -0.04, 0)
		HeldItem.Kind.FOOD:
			_item = BeverageModels.build_container(item.beverage, false)
			_item.position = Vector3(0, -0.02, -0.02)
	if _item:
		for c in _item.find_children("*", "GeometryInstance3D", true, false):
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.set_meta("no_highlight", true)
		_item_anchor.add_child(_item)
		# entra de baixo com um "pop"
		_right.position = _base_right + Vector3(0, -0.2, 0.05)
	poke()


func set_pouring(on: bool) -> void:
	_pouring = on


func poke() -> void:
	_poke = 1.0


func update_motion(delta: float, speed: float, bob_t: float) -> void:
	_poke = maxf(_poke - delta * 5.0, 0.0)
	_pour_blend = move_toward(_pour_blend, 1.0 if _pouring else 0.0, delta * 5.0)
	var bob := Vector3(cos(bob_t * 0.5) * 0.012, -absf(sin(bob_t)) * 0.014, 0) * clampf(speed / 3.0, 0.0, 1.0)
	var breathe := Vector3(0, sin(Time.get_ticks_msec() * 0.002) * 0.004, 0)
	var poke_off := Vector3(0, 0.02, -0.07) * sin(_poke * PI)
	var pour_off := Vector3(-0.12, 0.08, -0.08) * _pour_blend
	var t := 1.0 - exp(-14.0 * delta)
	_right.position = _right.position.lerp(_base_right + bob + breathe + poke_off + pour_off, t)
	_right.rotation = Vector3(0, 0, _pour_blend * 1.6 + sin(Time.get_ticks_msec() * 0.03) * 0.04 * _pour_blend)
	_left.position = _left.position.lerp(_base_left + bob * 0.8 - breathe, t)
	_left.visible = _item == null or _pour_blend < 0.5
