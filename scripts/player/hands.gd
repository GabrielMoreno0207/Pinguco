class_name Hands
extends Node3D
## Mãos estilizadas em primeira pessoa (viewmodel) segurando garrafa/copo.
## Cada mão tem duas poses montadas uma vez só (malhas mescladas, poucas draw calls):
## "Grip" (dedos fechados em volta do item, dedão cruzando a frente) e "Idle" (palma
## para baixo, dedos relaxados). Antebraço com manga dobrada; relógio no pulso esquerdo.

const SKIN := Color(0.96, 0.76, 0.6)
const SLEEVE := Color(0.85, 0.2, 0.18)
const NAIL := Color(1.0, 0.86, 0.8)
const OUTLINE_GROW := 0.0035

var _right: Node3D
var _left: Node3D
var _right_grip: Node3D
var _right_idle: Node3D
var _item_anchor: Node3D
var _item: Node3D
var _base_right := Vector3(0.24, -0.27, -0.44)
var _base_left := Vector3(-0.3, -0.34, -0.48)
var _pouring := false
var _pour_blend := 0.0
var _poke := 0.0
var _mats: Dictionary = {}


func _ready() -> void:
	_right = _build_hand(true)
	_right.position = _base_right
	add_child(_right)
	_left = _build_hand(false)
	_left.position = _base_left
	add_child(_left)
	_right_grip = _right.get_node("Grip")
	_right_idle = _right.get_node("Idle")
	# a esquerda nunca segura nada
	_left.get_node("Grip").visible = false
	_item_anchor = Node3D.new()
	_right_grip.add_child(_item_anchor)
	_set_holding(false)


## Material toon com contorno fino (o de 1.2 cm do cenário fica grosso demais tão perto da câmera).
func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := Mats.toon(c, false).duplicate() as StandardMaterial3D
	var o := Mats.outline_mat().duplicate() as StandardMaterial3D
	o.grow_amount = OUTLINE_GROW
	m.next_pass = o
	_mats[key] = m
	return m


func _seg(parent: Node3D, a: Vector3, b: Vector3, r: float, c: Color) -> MeshInstance3D:
	var mi := Mats.limb(parent, a, b, r, c)
	mi.material_override = _mat(c)
	return mi


func _ball(parent: Node3D, r: float, pos: Vector3, c: Color, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := Mats.sphere(parent, r, pos, c, false, scl)
	mi.material_override = _mat(c)
	return mi


func _build_hand(right: bool) -> Node3D:
	var h := Node3D.new()
	var side := 1.0 if right else -1.0
	# antebraço (afina no pulso) indo para baixo/trás, saindo da tela
	var wrist := Vector3(side * 0.008, -0.01, 0.05)
	var elbow := wrist + Vector3(side * 0.22, -0.4, 1.0).normalized() * 0.34
	var arm := Mats.cylinder(h, 0.05, 1.0, Vector3.ZERO, SKIN, false, 0.036)
	arm.material_override = _mat(SKIN)
	arm.basis = Mats.orient(wrist - elbow)
	arm.scale = Vector3(1.0, (wrist - elbow).length(), 1.0)
	arm.position = (wrist + elbow) * 0.5
	# pelinhos do braço
	for i in 5:
		var t := 0.25 + i * 0.13
		var p := wrist.lerp(elbow, t) + Vector3(side * 0.012 * (i % 2), 0.036 + t * 0.012, 0.0)
		Mats.limb(h, p, p + Vector3(side * 0.006, 0.004, 0.012), 0.0018, SKIN.darkened(0.45))
	# manga dobrada: tubo + dobra mais clara + botão
	var sl_a := wrist.lerp(elbow, 0.68)
	var sl_b := wrist.lerp(elbow, 1.05)
	var sleeve := Mats.cylinder(h, 0.07, 1.0, Vector3.ZERO, SLEEVE, false, 0.066)
	sleeve.material_override = _mat(SLEEVE)
	sleeve.basis = Mats.orient(sl_a - sl_b)
	sleeve.scale = Vector3(1.0, (sl_a - sl_b).length(), 1.0)
	sleeve.position = (sl_a + sl_b) * 0.5
	var fold_a := wrist.lerp(elbow, 0.62)
	var fold_b := wrist.lerp(elbow, 0.74)
	var fold := Mats.cylinder(h, 0.074, 1.0, Vector3.ZERO, SLEEVE.lightened(0.2), false, 0.072)
	fold.material_override = _mat(SLEEVE.lightened(0.2))
	fold.basis = Mats.orient(fold_a - fold_b)
	fold.scale = Vector3(1.0, (fold_a - fold_b).length(), 1.0)
	fold.position = (fold_a + fold_b) * 0.5
	_ball(h, 0.009, wrist.lerp(elbow, 0.68) + Vector3(side * 0.03, 0.06, 0.0), Color(0.95, 0.93, 0.85))
	if not right:
		# relógio de pulso: pulseira + caixa + mostrador
		var wa := wrist.lerp(elbow, 0.1)
		var wb := wrist.lerp(elbow, 0.2)
		var band := Mats.cylinder(h, 0.043, 1.0, Vector3.ZERO, Color(0.2, 0.15, 0.12), false)
		band.material_override = _mat(Color(0.2, 0.15, 0.12))
		band.basis = Mats.orient(wa - wb)
		band.scale = Vector3(1.0, (wa - wb).length(), 1.0)
		band.position = (wa + wb) * 0.5
		var top := (wa + wb) * 0.5 + Vector3(0, 0.042, 0)
		var case := Mats.cylinder(h, 0.022, 0.012, top, Color(0.85, 0.75, 0.35), false)
		case.material_override = _mat(Color(0.85, 0.75, 0.35))
		Mats.cylinder(h, 0.017, 0.004, top + Vector3(0, 0.007, 0), Color(0.97, 0.96, 0.9), false)
		Mats.box(h, Vector3(0.002, 0.002, 0.013), top + Vector3(0, 0.0095, -0.004), UiTheme.INK, false)
		Mats.box(h, Vector3(0.01, 0.002, 0.002), top + Vector3(0.004, 0.0095, 0), UiTheme.INK, false)
	var grip := Node3D.new()
	grip.name = "Grip"
	# vira um pouco as costas da mão para a câmera
	grip.rotation.y = -side * 0.35
	h.add_child(grip)
	_build_pose(grip, side, true)
	var idle := Node3D.new()
	idle.name = "Idle"
	# palma para baixo, mão meio solta
	idle.rotation = Vector3(-0.25, -side * 0.2, side * 1.35)
	h.add_child(idle)
	_build_pose(idle, side, false)
	for n: Node3D in [h, grip, idle]:
		Mats.merge_children(n)
	for c in h.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.set_meta("no_highlight", true)
	return h


## Palma com a face interna em -X (mão direita), dedos saindo para -Z e empilhados
## em Y (indicador em cima). grip = dedos fechados em volta de um item a -X.
func _build_pose(n: Node3D, side: float, grip: bool) -> void:
	# palma + costas da mão
	_ball(n, 0.05, Vector3.ZERO, SKIN, Vector3(0.48, 0.92, 1.0))
	_ball(n, 0.042, Vector3(side * 0.008, 0.0, 0.01), SKIN, Vector3(0.45, 0.85, 0.95))
	# monte do dedão
	_ball(n, 0.024, Vector3(-side * 0.012, 0.022, 0.018), SKIN, Vector3(0.8, 1.0, 1.3))
	var curl1 := 0.75 if grip else 0.12
	var curl2 := 1.75 if grip else 0.45
	var curl3 := 2.5 if grip else 0.75
	var lens := [0.03, 0.033, 0.031, 0.024]
	for i in 4:
		var y := 0.03 - i * 0.02
		var r := 0.0115 if i < 3 else 0.0098
		var l: float = lens[i]
		var base := Vector3(side * 0.003, y, -0.044)
		var d1 := Vector3(-side * sin(curl1), -0.06 * i, -cos(curl1)).normalized()
		var d2 := Vector3(-side * sin(curl2), -0.04 * i, -cos(curl2)).normalized()
		var d3 := Vector3(-side * sin(curl3), 0.0, -cos(curl3)).normalized()
		var p1 := base + d1 * l
		var p2 := p1 + d2 * l * 0.75
		var p3 := p2 + d3 * l * 0.55
		_seg(n, base, p1, r, SKIN)
		_seg(n, p1, p2, r * 0.95, SKIN)
		_seg(n, p2, p3, r * 0.9, SKIN)
		# nó do dedo (costas) e unha na ponta
		_ball(n, r * 1.15, base + Vector3(side * 0.008, 0.0, 0.004), SKIN)
		var dorsal := Vector3(side * cos(curl3), 0.0, -sin(curl3))
		var nail := Mats.sphere(n, r * 0.75, p3 - d3 * r * 0.2 + dorsal * r * 0.62, NAIL, false)
		nail.basis = Mats.orient(d3)
		nail.scale = Vector3(1.0, 1.1, 0.45)
		nail.material_override = Mats.toon(NAIL, false)
	# dedão: grip = cruza a frente do item (lado da câmera)
	var t0 := Vector3(-side * 0.012, 0.03, 0.02)
	var t1 := t0 + (Vector3(-side * 0.55, 0.15, 0.45) if grip else Vector3(-side * 0.5, 0.25, -0.6)).normalized() * 0.034
	var t2 := t1 + (Vector3(-side * 1.0, 0.0, 0.05) if grip else Vector3(-side * 0.35, 0.1, -0.9)).normalized() * 0.03
	_seg(n, t0, t1, 0.0135, SKIN)
	_seg(n, t1, t2, 0.0125, SKIN)
	var td := (t2 - t1).normalized()
	var tn := Mats.sphere(n, 0.0095, t2 - td * 0.003 + (Vector3(0, 0, 0.009) if grip else Vector3(0, 0.008, 0)), NAIL, false)
	tn.basis = Mats.orient(td)
	tn.scale = Vector3(1.0, 1.1, 0.45)
	tn.material_override = Mats.toon(NAIL, false)


func _set_holding(on: bool) -> void:
	_right_grip.visible = on
	_right_idle.visible = not on


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
			_item.position = Vector3(0, -0.02, 0)
	_set_holding(_item != null)
	if _item:
		for c in _item.find_children("*", "GeometryInstance3D", true, false):
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.set_meta("no_highlight", true)
		_item_anchor.add_child(_item)
		# encosta o item na palma (raio medido pela malha) e desfaz o giro da pose
		var radius := _item_radius(_item) * _item.scale.x
		_item_anchor.position = Vector3(-(0.024 + radius), 0.0, -0.012)
		_item_anchor.rotation.y = -_right_grip.rotation.y
		# entra de baixo com um "pop"
		_right.position = _base_right + Vector3(0, -0.2, 0.05)
	poke()


## Raio horizontal aproximado do item (para a mão não atravessar jarras e panelas).
static func _item_radius(item: Node3D) -> float:
	var r := 0.03
	for c in item.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null or mi.has_meta("garnish") or mi.get_parent() != item:
			continue
		var aabb := mi.transform * mi.mesh.get_aabb()
		r = maxf(r, maxf(maxf(absf(aabb.position.x), absf(aabb.end.x)), maxf(absf(aabb.position.z), absf(aabb.end.z))))
	return minf(r, 0.11)


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
	# servir: o punho vira a garrafa, o antebraço só acompanha um pouco
	var wobble := sin(Time.get_ticks_msec() * 0.03) * 0.04 * _pour_blend
	_right.rotation = Vector3(0, 0, _pour_blend * 0.3)
	_right_grip.rotation.z = _pour_blend * 1.35 + wobble
	_left.position = _left.position.lerp(_base_left + bob * 0.8 - breathe, t)
	_left.visible = _item == null or _pour_blend < 0.5
