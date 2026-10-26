class_name InteractionSystem
extends Node
## Raycast da câmera → Interactable em foco, destaque visual, tecla E (toque ou segurar).

signal focus_changed(target: Interactable, prompt: String, hint: String)
signal progress_changed(value: float)

const REACH := 2.4

var focused: Interactable
var _player: PlayerController
var _camera: Camera3D
var _holding := false
var _last_prompt := ""
var _last_hint := ""
var _press_queued := false


func setup(player: PlayerController, camera: Camera3D) -> void:
	_player = player
	_camera = camera


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and GameManager.is_playing():
		_press_queued = true


func _physics_process(delta: float) -> void:
	if not GameManager.is_playing():
		_press_queued = false
		return
	var target := _raycast()
	if target != focused:
		if _holding and focused:
			focused.interact_release(_player)
			_holding = false
			progress_changed.emit(0.0)
		if is_instance_valid(focused):
			focused.set_focused(false)
		focused = target
	var prompt := focused.get_prompt(_player) if focused else ""
	var hint := focused.get_hint(_player) if focused and prompt == "" else ""
	if focused:
		focused.set_focused(prompt != "")
	if prompt != _last_prompt or hint != _last_hint:
		_last_prompt = prompt
		_last_hint = hint
		focus_changed.emit(focused, prompt, hint)
	_handle_input(delta)


func _handle_input(delta: float) -> void:
	var pressed := _press_queued
	_press_queued = false
	var down := Input.is_action_pressed("interact")
	if focused == null:
		return
	if focused.is_hold_action(_player):
		if down:
			_holding = true
			var p := focused.interact_hold(_player, delta)
			progress_changed.emit(p)
			if p >= 1.0:
				_holding = false
				progress_changed.emit(0.0)
		elif _holding:
			_holding = false
			focused.interact_release(_player)
			progress_changed.emit(0.0)
	elif pressed and _last_prompt != "":
		focused.interact(_player)
		_player.hands.poke()
	elif _holding and not down:
		_holding = false
		focused.interact_release(_player)
		progress_changed.emit(0.0)


func _raycast() -> Interactable:
	var space := _camera.get_world_3d().direct_space_state
	var from := _camera.global_position
	var to := from + _player.look_dir() * REACH
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | Interactable.LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.collider as Interactable


## Usado pelos testes automatizados.
func force_interact(target: Interactable) -> void:
	focused = target
	if target.get_prompt(_player) != "":
		target.interact(_player)
