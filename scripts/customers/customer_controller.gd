class_name CustomerController
extends Node3D
## Um freguês: chega, senta, pede, bebe, fica bêbado, capota (ou vai embora bravo).
## A embriaguez é individual; o texto dos pedidos vem do DrunkennessSystem.

signal seat_released(customer: CustomerController)
signal departed(customer: CustomerController)

enum State { ENTERING, GREETING, THINKING, ORDERING, DRINKING, PASSING_OUT, ASLEEP, LEAVING, ANGRY_LEAVING }

const WALK_SPEED := 1.6
const SLEEP_TIME := 7.0
const PASS_OUT_BONUS := 15
const EAT_LINES := ["Hmm, forrou o bucho!", "Agora sim, deu uma rebatida!", "Ufa, voltei pro prumo!",
	"Que salgado, hein? Fiquei novo!"]

var profile: CustomerProfile
var nickname := ""
var seat: Seat
var order_system: OrderSystem
var rig: CustomerRig
var hitbox: CustomerHitbox
var state: State = State.ENTERING

var drunk_level := 0.0
## Fome 0..1: sobe a cada bebida alcoólica; alta = pede salgado (que corta o porre).
var hunger := 0.0
var last_beverage: StringName = &""
var strikes := 0
var drinks := 0

## Balão de fala (lido pelo HUD)
var bubble_text := ""
var bubble_kind: StringName = &""
var bubble_timer := 0.0

var _rng := RandomNumberGenerator.new()
var _path: Array[Vector3] = []
var _exit_path: Array[Vector3] = []
var _state_timer := 0.0
var _t := 0.0
var _talk := 0.0
var _happy := 0.0
var _angry := 0.0
var _flush := 0.0
var _hiccup_timer := 6.0
var _hiccup := 0.0
var _blink_timer := 2.0
var _blink := 0.0
var _bang_timer := 3.0
var _bang := 0.0
var _fickle_checked := false
var _seated := false
var _sit_blend := 0.0
var _slump := 0.0
var _zzz_timer := 0.0
var _drink_glass: Node3D
var _drink_anim := 0.0
var _wake_anim := 0.0
var _eating := false


func setup(p: CustomerProfile, nick: String, s: Seat, orders: OrderSystem, entry: Array[Vector3], exit: Array[Vector3]) -> void:
	profile = p
	nickname = nick
	seat = s
	order_system = orders
	_path = entry.duplicate()
	_exit_path = exit.duplicate()
	_rng.randomize()
	name = "Customer_%s" % nick.replace(" ", "_")


func _ready() -> void:
	add_to_group("customers")
	rig = CustomerRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.build(profile, hash(nickname))
	hitbox = CustomerHitbox.new()
	hitbox.customer = self
	hitbox.highlight_root = rig
	add_child(hitbox)
	hitbox.setup_shape(Vector3(0.7, 1.0, 0.6), Vector3(0, 1.45, 0))
	order_system.order_expired.connect(_on_order_expired)
	AudioManager.play_at("doorbell", global_position, 1.0, -6.0)


# ------------------------------------------------------------------ consultas

func stage() -> int:
	return DrunkennessSystem.stage_for(drunk_level, profile.tolerance)


func drunk_fraction() -> float:
	return DrunkennessSystem.fraction(drunk_level, profile.tolerance)


func is_seated_active() -> bool:
	return state in [State.GREETING, State.THINKING, State.ORDERING, State.DRINKING]


func can_receive() -> bool:
	return state in [State.GREETING, State.THINKING, State.ORDERING]


func current_order() -> OrderSystem.Order:
	return order_system.get_order(self)


func head_position() -> Vector3:
	return rig.head.global_position + Vector3(0, 0.62, 0)


# ------------------------------------------------------------------ fala

func say(text: String, kind: StringName, duration := 2.8) -> void:
	bubble_text = text
	bubble_kind = kind
	bubble_timer = duration
	_talk = clampf(text.length() * 0.045, 0.4, 2.0)
	AudioManager.speak(head_position(), profile.voice_pitch, clampi(text.length() / 6, 2, 7), stage())


func _line(lines: PackedStringArray) -> String:
	if lines.is_empty():
		return "..."
	return lines[_rng.randi_range(0, lines.size() - 1)]


# ------------------------------------------------------------------ ciclo

func _process(delta: float) -> void:
	# com o bar fechado eles continuam vivos só para sair pela porta
	if not GameManager.can_act():
		return
	_t += delta
	_state_timer -= delta
	bubble_timer -= delta
	match state:
		State.ENTERING:
			if _walk(delta, _path, false):
				_sit_down()
		State.GREETING:
			if _state_timer <= 0.0:
				_enter_thinking()
		State.THINKING:
			if _state_timer <= 0.0:
				_place_order()
		State.ORDERING:
			_update_ordering(delta)
		State.DRINKING:
			_drink_anim += delta
			if _state_timer <= 0.0:
				_finish_drink()
		State.PASSING_OUT:
			if _state_timer <= 0.0:
				state = State.ASLEEP
				_state_timer = SLEEP_TIME
		State.ASLEEP:
			_update_asleep(delta)
		State.LEAVING, State.ANGRY_LEAVING:
			if _walk(delta, _exit_path, true):
				departed.emit(self)
				queue_free()
	_animate(delta)


func _walk(delta: float, path: Array[Vector3], leaving: bool) -> bool:
	if path.is_empty():
		return true
	var target := path[0]
	var to := target - global_position
	to.y = 0.0
	var speed := WALK_SPEED * (1.0 - drunk_fraction() * 0.35) * (1.5 if state == State.ANGRY_LEAVING else 1.0)
	if to.length() < 0.08:
		path.remove_at(0)
		return path.is_empty()
	var step := to.normalized() * minf(speed * delta, to.length())
	# bêbado anda torto
	var side := Vector3(-to.z, 0, to.x).normalized() * sin(_t * 3.0) * drunk_fraction() * 0.6 * delta if leaving else Vector3.ZERO
	global_position += step + side
	var face := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, face, 1.0 - exp(-10.0 * delta))
	return false


func _sit_down() -> void:
	global_position = seat.position
	_seated = true
	state = State.GREETING
	_state_timer = 2.4
	create_tween().tween_property(self, "rotation:y", 0.0, 0.35)
	say(_line(profile.greetings), &"chat", 2.4)


func _enter_thinking() -> void:
	state = State.THINKING
	var st := stage()
	_state_timer = profile.order_delay * (1.0 - 0.18 * st) + _rng.randf_range(0.0, 1.2)
	if _rng.randf() < profile.chatter and bubble_timer <= 0.0:
		var fav := _pick_beverage()
		say(_line(profile.chatter_lines).replace("{bebida}", BeverageDatabase.get_beverage(fav).display_name.to_lower()), &"chat", 2.6)
		_state_timer += 1.2


func _pick_beverage() -> StringName:
	var st := stage()
	var all := BeverageDatabase.ids()
	# bêbado fica imprevisível: às vezes pede qualquer coisa
	if st >= DrunkennessSystem.Stage.DRUNK and _rng.randf() < 0.35:
		return all[_rng.randi_range(0, all.size() - 1)]
	var total := 0.0
	for id in profile.favorites:
		if BeverageDatabase.has_beverage(id):
			total += float(profile.favorites[id])
	var roll := _rng.randf() * total
	for id in profile.favorites:
		if not BeverageDatabase.has_beverage(id):
			continue
		roll -= float(profile.favorites[id])
		if roll <= 0.0:
			return id
	return all[0]


## Com fome, às vezes pede salgado em vez de bebida.
func _pick_order_item() -> StringName:
	var foods := BeverageDatabase.food_ids()
	# a larica só bate depois que o freguês já está alegre
	if not foods.is_empty() and is_hungry() and stage() >= DrunkennessSystem.Stage.TIPSY \
			and _rng.randf() < 0.3 + (hunger - DrunkennessSystem.HUNGRY_AT) * 1.5:
		return foods[_rng.randi_range(0, foods.size() - 1)]
	return _pick_beverage()


func is_hungry() -> bool:
	return hunger >= DrunkennessSystem.HUNGRY_AT


func _place_order() -> void:
	var bev := _pick_order_item()
	var patience := profile.patience * BarProgress.patience_multiplier() * (1.0 - stage() * 0.08)
	var order := order_system.create_order(self, bev, patience)
	state = State.ORDERING
	_fickle_checked = false
	_state_timer = _rng.randf_range(5.0, 9.0)
	bubble_timer = 0.0
	_talk = 1.2
	AudioManager.speak(head_position(), profile.voice_pitch, 4, order.stage)


func _update_ordering(delta: float) -> void:
	var order := current_order()
	if order == null:
		return
	# Valentão perde a linha quando a paciência acaba: soco no balcão
	if profile.body == CustomerProfile.Body.VALENTAO and order.patience_fraction() < 0.5:
		_bang_timer -= delta
		if _bang_timer <= 0.0:
			_bang_timer = 2.6
			_bang = 1.0
	if not _fickle_checked and _state_timer <= 0.0:
		_fickle_checked = true
		if BeverageDatabase.get_beverage(order.beverage_id).is_food():
			return # fome não muda de ideia
		if stage() >= DrunkennessSystem.Stage.DRUNK and _rng.randf() < profile.fickleness * 2.0:
			var new_bev := _pick_beverage()
			if new_bev != order.beverage_id:
				order_system.change_order(self, new_bev)
				_talk = 1.0
				AudioManager.speak(head_position(), profile.voice_pitch, 3, stage())


func _on_order_expired(order: OrderSystem.Order) -> void:
	if order.customer != self:
		return
	strikes += 1
	_angry = 1.0
	GameManager.register_late(head_position())
	AudioManager.play_at("late", head_position())
	AudioManager.grumble(head_position(), profile.voice_pitch)
	if strikes >= profile.max_strikes:
		_leave_angry()
	else:
		say(_line(profile.late_lines), &"angry", 2.6)


# ------------------------------------------------------------------ entrega

func receive(player: PlayerController) -> void:
	var item := player.held
	var result := order_system.validate(self, item)
	match result:
		OrderSystem.Result.CORRECT:
			var earned := order_system.complete(self)
			var bev := item.beverage
			player.set_held(HeldItem.empty())
			GameManager.register_correct(earned, head_position())
			if drinks == 0:
				GameManager.register_customer_served()
			drinks += 1
			AudioManager.play("correct")
			AudioManager.play("coin", 1.0, -6.0)
			if bev.is_food():
				_start_eat(bev)
			else:
				_start_drink(bev)
		OrderSystem.Result.WRONG_DRINK, OrderSystem.Result.NO_ORDER:
			strikes += 1
			_angry = 1.0
			_bang = 1.0 if profile.body == CustomerProfile.Body.VALENTAO else 0.0
			var msg := "Bebida errada!" if result == OrderSystem.Result.WRONG_DRINK else "Ele não pediu isso!"
			GameManager.register_wrong(head_position(), msg)
			AudioManager.play("wrong")
			AudioManager.grumble(head_position(), profile.voice_pitch)
			player.add_shake(0.25 if profile.body == CustomerProfile.Body.VALENTAO else 0.12)
			if strikes >= profile.max_strikes:
				_leave_angry()
			else:
				say(_line(profile.wrong_lines), &"angry", 2.4)


func _start_drink(bev: BeverageData) -> void:
	state = State.DRINKING
	_state_timer = 1.9
	_drink_anim = 0.0
	_happy = 1.0
	last_beverage = bev.id
	bubble_timer = 0.0
	_drink_glass = BeverageModels.build_glass(bev)
	_drink_glass.scale = Vector3.ONE * 1.4
	_drink_glass.position = rig.hold_offset()
	rig.hand_r.add_child(_drink_glass)
	drunk_level = maxf(0.0, drunk_level + bev.strength * profile.sensitivity)
	if bev.strength > 0.0:
		hunger = minf(hunger + profile.hunger_rate * (1.0 + stage() * 0.25), 1.0)
	else:
		GameManager.register_sobered(head_position(), false)


## Salgado: mata a fome e derruba a embriaguez.
func _start_eat(food: BeverageData) -> void:
	state = State.DRINKING
	_state_timer = 1.9
	_drink_anim = 0.0
	_happy = 1.0
	_eating = true
	bubble_timer = 0.0
	_drink_glass = Node3D.new()
	BeverageModels.build_snack(_drink_glass, food, Vector3.ZERO)
	_drink_glass.scale = Vector3.ONE * 1.3
	_drink_glass.position = rig.hold_offset() + Vector3(0, 0.06, 0)
	rig.hand_r.add_child(_drink_glass)
	drunk_level = maxf(0.0, drunk_level + food.strength * profile.sensitivity)
	hunger = 0.0
	GameManager.register_sobered(head_position(), true)
	AudioManager.play_at("thud", head_position(), 2.2, -12.0)


func _finish_drink() -> void:
	if is_instance_valid(_drink_glass):
		_drink_glass.queue_free()
	if _eating:
		_eating = false
		say(_line(EAT_LINES), &"happy", 2.0)
		_enter_thinking()
		return
	_flush = 0.6
	if drunk_level >= profile.tolerance:
		_pass_out()
		return
	var st := stage()
	if st >= DrunkennessSystem.Stage.TIPSY and _rng.randf() < 0.6:
		AudioManager.laugh(head_position(), profile.voice_pitch)
		say(_line(profile.happy_lines) + " " + DrunkennessSystem.LAUGHS[_rng.randi_range(0, 3)], &"happy", 2.0)
	else:
		say(_line(profile.happy_lines), &"happy", 1.8)
	_enter_thinking()


# ------------------------------------------------------------------ fim de atendimento

func _pass_out() -> void:
	state = State.PASSING_OUT
	_state_timer = 1.6
	order_system.cancel(self)
	bubble_text = ""
	var msg := _line(profile.pass_out_messages).replace("{nome}", nickname)
	GameManager.register_pass_out(nickname, msg, PASS_OUT_BONUS + drinks * 2)
	var tw := create_tween()
	tw.tween_property(self, "_slump", 1.0, 1.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(0.75, false).timeout.connect(_on_head_hits_counter)


func _on_head_hits_counter() -> void:
	AudioManager.play_at("thud", head_position(), 0.9)
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].add_shake(0.2)


func _update_asleep(delta: float) -> void:
	_zzz_timer -= delta
	if _zzz_timer <= 0.0:
		_zzz_timer = 2.3
		AudioManager.play_at("snore", head_position(), profile.voice_pitch * 0.9, -2.0)
		_spawn_z()
	bubble_text = ""
	if _state_timer <= 0.0:
		# acorda assustado e vai embora cambaleando
		state = State.LEAVING
		_wake_anim = 1.0
		say("Hã?! Que horas são? ...fui!", &"chat", 2.4)
		_stand_up()


func _spawn_z() -> void:
	var z := Mats.label3d(self, "Z", head_position() - global_position + Vector3(0.1, -0.25, 0.0), 64, Color(0.75, 0.85, 1.0), 12)
	z.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	z.top_level = true
	z.global_position = head_position() + Vector3(0.1, -0.3, 0)
	var tw := z.create_tween().set_parallel(true)
	tw.tween_property(z, "global_position", z.global_position + Vector3(0.35, 0.7, 0), 2.0)
	tw.tween_property(z, "modulate:a", 0.0, 2.0).set_ease(Tween.EASE_IN)
	tw.tween_property(z, "font_size", 110, 2.0)
	tw.chain().tween_callback(z.queue_free)


func _leave_angry() -> void:
	order_system.cancel(self)
	say(_line(profile.angry_leave_lines), &"angry", 2.8)
	GameManager.register_angry_leave(head_position())
	_angry = 1.0
	state = State.ANGRY_LEAVING
	_stand_up()


func _stand_up() -> void:
	_seated = false
	seat_released.emit(self)


## Encerramento forçado (fim do turno).
func force_leave() -> void:
	if state in [State.LEAVING, State.ANGRY_LEAVING]:
		return
	order_system.cancel(self)
	state = State.LEAVING
	_stand_up()


# ------------------------------------------------------------------ animação procedural

func _animate(delta: float) -> void:
	var f := drunk_fraction()
	var st := stage()
	var walking := state in [State.ENTERING, State.LEAVING, State.ANGRY_LEAVING]
	_talk = maxf(_talk - delta, 0.0)
	_happy = maxf(_happy - delta * 0.5, 0.0)
	_angry = maxf(_angry - delta * 0.35, 0.0)
	_flush = maxf(_flush - delta * 0.3, 0.0)
	_hiccup = maxf(_hiccup - delta * 4.0, 0.0)
	_bang = maxf(_bang - delta * 2.5, 0.0)
	_wake_anim = maxf(_wake_anim - delta * 1.5, 0.0)
	_sit_blend = move_toward(_sit_blend, 1.0 if _seated else 0.0, delta * 3.0)
	if state != State.PASSING_OUT and state != State.ASLEEP:
		_slump = move_toward(_slump, 0.0, delta * 1.5)

	# soluço (estágio 3+)
	if st >= DrunkennessSystem.Stage.DRUNK and is_seated_active():
		_hiccup_timer -= delta
		if _hiccup_timer <= 0.0:
			_hiccup_timer = _rng.randf_range(4.0, 9.0)
			_hiccup = 1.0
			AudioManager.play_at("voice_e", head_position(), profile.voice_pitch * 1.6, -2.0)

	# piscar
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = _rng.randf_range(2.0, 4.5)
		_blink = 1.0
	_blink = maxf(_blink - delta * 8.0, 0.0)

	# --- corpo
	var sway_amp: float = [0.0, 0.05, 0.1, 0.17][st]
	var sway_freq := 1.6 - st * 0.25
	var sway := sin(_t * sway_freq) * sway_amp
	var bounce := sin(_hiccup * PI) * 0.06
	rig.position.y = bounce
	rig.torso.rotation = Vector3(-_slump * 1.05 + sin(_hiccup * PI) * 0.1, 0, sway * (1.0 - _slump))
	rig.head.rotation = Vector3(
		sin(_t * 0.9) * 0.05 * st - _slump * 0.25 + (0.45 * sin(clampf(_drink_anim / 1.9, 0, 1) * PI) if state == State.DRINKING else 0.0),
		sin(_t * 0.7) * 0.15 * (1.0 if _talk > 0.0 else 0.3),
		sway * 1.4 + _slump * 0.35 + sin(_t * 1.3) * 0.04 * st)

	if walking:
		var w := sin(_t * 9.0)
		rig.leg_l.rotation.x = w * 0.6
		rig.leg_r.rotation.x = -w * 0.6
		rig.set_knees(maxf(-w, 0.0) * 0.7, maxf(w, 0.0) * 0.7)
		rig.arm_l.rotation = Vector3(-w * 0.5, 0, -0.1)
		rig.arm_r.rotation = Vector3(w * 0.5, 0, 0.1)
		rig.position.y = absf(sin(_t * 9.0)) * 0.05
		if state == State.ANGRY_LEAVING:
			rig.arm_r.rotation = Vector3(2.8 + sin(_t * 20.0) * 0.3, 0, 0.2) # punho pro alto
	else:
		var leg := lerpf(0.0, 1.25, _sit_blend)
		rig.leg_l.rotation.x = leg
		rig.leg_r.rotation.x = leg
		rig.set_knees(leg * 1.05, leg * 1.05)
		# braços apoiados no balcão
		var rest := 1.05 * _sit_blend
		var arm_l := Vector3(rest, 0, -0.08)
		var arm_r := Vector3(rest, 0, 0.08)
		if state == State.DRINKING:
			var k := sin(clampf(_drink_anim / 1.9, 0, 1) * PI)
			arm_r = Vector3(lerpf(rest, 2.5, k), 0, lerpf(0.08, -0.45, k))
		elif _slump > 0.1:
			arm_l = Vector3(lerpf(rest, 1.7, _slump), 0, -0.35 * _slump)
			arm_r = Vector3(lerpf(rest, 1.7, _slump), 0, 0.35 * _slump)
		else:
			_profile_gestures(arm_l, arm_r, st)
			_face(st, f)
			return
		rig.arm_l.rotation = arm_l
		rig.arm_r.rotation = arm_r
	_face(st, f)


## Animações específicas de cada perfil.
func _profile_gestures(arm_l: Vector3, arm_r: Vector3, st: int) -> void:
	var talking := _talk > 0.0 or (state == State.ORDERING and fmod(_t, 3.0) < 0.8)
	match profile.body:
		CustomerProfile.Body.TIOZAO:
			if _happy > 0.3 or (talking and st >= 1):
				# risada de barriga: barriga balança, mão no bucho
				rig.belly.scale = Vector3(1.0, 0.9, 0.95) * (1.0 + sin(_t * 22.0) * 0.05 * maxf(_happy, 0.4))
				arm_r = Vector3(0.6, 0, 0.5 + sin(_t * 18.0) * 0.08)
			else:
				rig.belly.scale = Vector3(1.0, 0.9, 0.95) * (1.0 + sin(_t * 1.5) * 0.015)
		CustomerProfile.Body.VALENTAO:
			# braços cruzados quando sóbrio e quieto; soco no balcão quando bravo
			if _bang > 0.0:
				arm_r = Vector3(lerpf(2.2, 1.0, 1.0 - _bang), 0, 0.1)
				if _bang < 0.55 and _bang > 0.45:
					AudioManager.play_at("thud", rig.hand_r.global_position, 1.3, -6.0)
			elif _angry > 0.2:
				arm_l = Vector3(1.5, 0, 0.9)
				arm_r = Vector3(1.5, 0, -0.9)
		CustomerProfile.Body.FALANTE:
			if talking:
				arm_l = Vector3(1.4 + sin(_t * 7.0) * 0.5, 0, -0.3 + sin(_t * 5.0) * 0.3)
				arm_r = Vector3(1.6 + sin(_t * 6.0 + 1.0) * 0.6, 0, 0.3 + cos(_t * 4.0) * 0.3)
		CustomerProfile.Body.FOFOQUEIRA:
			if talking and bubble_kind == &"chat":
				arm_l = Vector3(2.4, 0, 0.55) # mão na boca: "não conta pra ninguém"
			elif _happy > 0.3:
				arm_r = Vector3(1.9 + sin(_t * 10.0) * 0.2, 0, 0.0)
			else:
				# abanando o leque ("ai, que calor!")
				arm_l = Vector3(1.9, 0, 0.35 + sin(_t * 9.0) * 0.25)
		CustomerProfile.Body.UNIVERSITARIO:
			if not talking and _happy < 0.3:
				# olhando o celular
				arm_l = Vector3(1.75, 0, 0.45)
				rig.head.rotation.x += 0.35
			elif talking:
				arm_r = Vector3(1.5 + sin(_t * 8.0) * 0.3, 0, 0.2)
		CustomerProfile.Body.MALANDRO:
			if _happy > 0.3 and rig.hat:
				# levanta o chapéu: "categoria!"
				arm_r = Vector3(2.9, 0, 0.3)
				rig.hat.position.y = 0.3875 + sin(_happy * PI) * 0.06
			else:
				# batucando o samba no balcão
				arm_r = Vector3(1.05 + absf(sin(_t * 7.0)) * 0.25, 0, 0.08)
				if rig.hat:
					rig.hat.position.y = 0.3875
	if is_hungry() and not talking and _happy < 0.3 and profile.body != CustomerProfile.Body.UNIVERSITARIO:
		arm_l = Vector3(0.75, 0, 0.75 + sin(_t * 4.0) * 0.1) # mão na barriga: tá com fome
	if _wake_anim > 0.0:
		arm_l = Vector3(2.6, 0, -0.6)
		arm_r = Vector3(2.6, 0, 0.6)
	rig.arm_l.rotation = rig.arm_l.rotation.lerp(arm_l, 0.25)
	rig.arm_r.rotation = rig.arm_r.rotation.lerp(arm_r, 0.25)


func _face(st: int, f: float) -> void:
	var asleep := state == State.ASLEEP or state == State.PASSING_OUT
	var base_lid: float = [0.0, 0.25, 0.45, 0.62][st]
	var lid := 1.0 if asleep else clampf(base_lid + _blink + sin(_t * 0.8) * 0.06 * st - _angry * 0.15 - _wake_anim, 0.0, 1.0)
	rig.set_expression(_happy, _angry, f)
	rig.set_eyelids(lid)
	# sobrancelhas: bravo = franzidas; bêbado = arqueadas e tortas
	var brow_angle := _angry * 0.45 - _happy * 0.15 + (sin(_t * 1.1) * 0.12 * st if st >= 2 else 0.0)
	if profile.body == CustomerProfile.Body.VALENTAO:
		brow_angle += 0.2
	rig.set_brows(brow_angle, _happy * 0.02 - _angry * 0.015 + (0.03 if _wake_anim > 0.0 else 0.0))
	# boca: fala, sorri, ronca
	var open := 0.0
	if _talk > 0.0:
		open = absf(sin(_t * 16.0)) * 0.8
	if asleep:
		open = 0.4 + sin(_t * 2.7) * 0.25
	if _wake_anim > 0.0:
		open = 1.0
	rig.set_mouth(open, _happy - _angry * 0.6 + st * 0.1)
	# olhos vesgos/perdidos quando bêbado
	if st >= 2 and not asleep:
		var wander := sin(_t * 1.7) * (st - 1) * 0.5
		rig.look_pupils(Vector2(0.4 + wander, -0.4 + wander * 0.6))
	else:
		rig.look_pupils(Vector2.ZERO)
	rig.apply_drunk_look(f, _flush + _angry * 0.8)
