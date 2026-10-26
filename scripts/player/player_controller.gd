class_name PlayerController
extends CharacterBody3D
## Controle em primeira pessoa: WASD, mouse, gravidade, colisão e o item na mão.

signal held_changed(item: HeldItem)

@export var walk_speed := 3.4
@export var sprint_speed := 5.2
@export var accel := 14.0
@export var mouse_sensitivity := 0.0024
@export var gravity := 18.0
@export var eye_height := 1.62

var held: HeldItem = HeldItem.empty()
var camera: Camera3D
var hands: Hands
var interaction: InteractionSystem

var _pitch := 0.0
var _bob_t := 0.0
var _step_t := 0.0
var _shake := 0.0
var _shake_t := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.875
	add_child(shape)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position.y = eye_height
	camera.fov = 78.0
	camera.near = 0.03
	camera.current = true
	add_child(camera)

	hands = Hands.new()
	hands.name = "Hands"
	camera.add_child(hands)

	interaction = InteractionSystem.new()
	interaction.name = "InteractionSystem"
	add_child(interaction)
	interaction.setup(self, camera)


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_playing() or GameManager.has_meta("autotest"):
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look(event.relative)
	elif event.is_action_pressed("discard"):
		discard_held()


func apply_look(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	_pitch = clampf(_pitch - relative.y * mouse_sensitivity, deg_to_rad(-82), deg_to_rad(82))
	camera.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	var input := Vector2.ZERO
	if GameManager.is_playing():
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target := dir * speed
	var t := 1.0 - exp(-accel * delta)
	velocity.x = lerpf(velocity.x, target.x, t)
	velocity.z = lerpf(velocity.z, target.z, t)
	move_and_slide()
	_update_view(delta)


## Balanço de cabeça + tremida de câmera (offset visual, nunca move o corpo).
func _update_view(delta: float) -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if hspeed > 0.3 and is_on_floor():
		_bob_t += delta * hspeed * 2.4
		_step_t += delta * hspeed
		if _step_t > 1.35:
			_step_t = 0.0
			AudioManager.play_at("step", global_position, randf_range(0.9, 1.1), -14.0)
	else:
		_bob_t = lerpf(_bob_t, roundf(_bob_t / PI) * PI, 1.0 - exp(-8.0 * delta))
	var bob := Vector3(cos(_bob_t * 0.5) * 0.025, absf(sin(_bob_t)) * 0.035, 0.0)
	_shake = maxf(_shake - delta * 1.8, 0.0)
	_shake_t += delta * 32.0
	var s := _shake * _shake
	var shake_off := Vector3(sin(_shake_t * 1.7) * 0.05 * s, sin(_shake_t * 2.3) * 0.04 * s, 0)
	camera.position = Vector3(0, eye_height, 0) + bob + shake_off
	camera.rotation.z = sin(_shake_t * 1.1) * 0.03 * s
	hands.update_motion(delta, hspeed, _bob_t)


func add_shake(amount: float) -> void:
	_shake = clampf(_shake + amount, 0.0, 1.0)


func set_held(item: HeldItem) -> void:
	held = item
	hands.show_item(item)
	held_changed.emit(item)


## Q / pia: copo vai pro lixo, garrafa volta pro lugar.
func discard_held() -> void:
	match held.kind:
		HeldItem.Kind.BOTTLE:
			var src := held.source as BottleDispenser
			set_held(HeldItem.empty())
			if src:
				src.set_taken(false)
		HeldItem.Kind.GLASS:
			AudioManager.play_at("glass_break" if held.filled else "clink", global_position, 1.0, -4.0)
			set_held(HeldItem.empty())


func look_dir() -> Vector3:
	return -camera.global_transform.basis.z
