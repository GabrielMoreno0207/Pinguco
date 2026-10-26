class_name CustomerSpawner
extends Node3D
## Faz fregueses entrarem pela porta enquanto houver banqueta livre.

signal customer_spawned(customer: CustomerController)

@export var first_delay := 2.0
@export var interval_start := 11.0
@export var interval_end := 6.0

var seats: Array[Seat] = []
var door_inside := Vector3.ZERO
var door_outside := Vector3.ZERO
var order_system: OrderSystem
var shift: ShiftManager
var enabled := false

var _timer := 0.0
var _used_names: Dictionary = {}


func start() -> void:
	enabled = true
	_timer = first_delay


func stop() -> void:
	enabled = false


func _process(delta: float) -> void:
	if not enabled or not GameManager.is_playing():
		return
	_timer -= delta
	if _timer <= 0.0:
		var progress := shift.progress() if shift else 0.0
		_timer = lerpf(interval_start, interval_end, progress) + randf_range(-1.5, 1.5)
		spawn()


func free_seats() -> Array[Seat]:
	var out: Array[Seat] = []
	for s in seats:
		if s.is_free():
			out.append(s)
	return out


func spawn(profile: CustomerProfile = null) -> CustomerController:
	var free := free_seats()
	if free.is_empty():
		_timer = 2.0 # tenta de novo logo
		return null
	var seat: Seat = free[randi() % free.size()]
	var active_profiles := []
	for s in seats:
		if s.occupant:
			active_profiles.append(s.occupant.profile.id)
	if profile == null:
		profile = CustomerDatabase.random_profile(active_profiles)
	var c := CustomerController.new()
	var entry: Array[Vector3] = [door_inside, seat.approach, seat.position]
	var exit: Array[Vector3] = [seat.approach, door_inside, door_outside]
	c.setup(profile, _unique_name(profile), seat, order_system, entry, exit)
	seat.occupant = c
	c.seat_released.connect(_on_seat_released)
	c.departed.connect(_on_departed)
	add_child(c)
	c.global_position = door_outside
	customer_spawned.emit(c)
	return c


func _unique_name(p: CustomerProfile) -> String:
	var options := Array(p.nicknames).filter(func(n: String) -> bool: return not _used_names.has(n))
	var nick: String = options[randi() % options.size()] if options.size() > 0 else p.nicknames[0] + " Jr."
	_used_names[nick] = true
	return nick


func _on_seat_released(c: CustomerController) -> void:
	for s in seats:
		if s.occupant == c:
			s.occupant = null


func _on_departed(c: CustomerController) -> void:
	_used_names.erase(c.nickname)
	_on_seat_released(c)


func clear_all() -> void:
	for c in get_tree().get_nodes_in_group("customers"):
		c.force_leave()
