class_name Hands
extends Node3D
## Mãos em primeira pessoa (viewmodel). Cada braço é uma malha esculpida em
## tools/bake_hands.py (assets/hands/hand_r.bin e hand_l.bin): antebraço com manga
## dobrada (relógio na esquerda) e mão numa malha contínua só, com esqueleto nos dedos.
## Os dedos fecham de verdade em volta do item: cada falange gira até encostar no
## cilindro do copo/garrafa (raio medido pela malha). Solta = dedos relaxados e palma
## para baixo. Servir = o antebraço gira (pronação) em volta do próprio eixo.

const SKIN := Color(0.96, 0.76, 0.6)
const SLEEVE := Color(0.85, 0.2, 0.18)
const DATA_DIR := "res://assets/hands/"
## Direção pulso → cotovelo (mão direita; a esquerda é o espelho em X).
const FORE_DIR := Vector3(0.22, -0.4, 1.0)
## Comprimento da ponta de cada dedo (as outras falanges saem das posições dos ossos).
const TIP_LEN := [0.017, 0.018, 0.017, 0.015]
const FINGER_R := [0.0104, 0.0106, 0.0101, 0.009]
## Dobra de cada falange com a mão solta (o mindinho dobra um pouco mais).
const IDLE_CURL := [0.22, 0.38, 0.28]

var _right: _Arm
var _left: _Arm
var _item_anchor: Node3D
var _item: Node3D
var _base_right := Vector3(0.24, -0.27, -0.44)
var _base_left := Vector3(-0.3, -0.34, -0.48)
var _pouring := false
var _pour_blend := 0.0
var _poke := 0.0


## Um braço montado: nós de controle dos ossos (o esqueleto copia a cada quadro) e
## as curvas dos dedos solta/segurando.
class _Arm:
	var side := 1.0
	var root: Node3D
	## pivô do pulso: gira o braço inteiro (palma para baixo, servir)
	var pose: Node3D
	var skeleton: Skeleton3D
	var nodes: Dictionary = {}
	var bone_nodes: Array[Node3D] = []
	var wrist := Vector3.ZERO
	var thumb_rest := Basis()
	var grip := 0.0
	## [dedo][falange] em radianos, e a direção do dedão ao segurar
	var grip_curl := []
	var thumb_dir := Vector3.ZERO
	var thumb_curl := 0.0

	func finger(i: int, j: int) -> Node3D:
		return nodes["f%d%s" % [i, "abc"[j]]]

	func sync() -> void:
		for k in bone_nodes.size():
			var n := bone_nodes[k]
			skeleton.set_bone_pose_position(k, n.position)
			skeleton.set_bone_pose_rotation(k, n.quaternion)


func _ready() -> void:
	_right = _build_arm(true)
	_right.root.position = _base_right
	_left = _build_arm(false)
	_left.root.position = _base_left
	_item_anchor = Node3D.new()
	_right.nodes.hand.add_child(_item_anchor)
	_apply_pose(_right)
	_apply_pose(_left)


## Plástico liso, como os fregueses. Sem contorno: perto da câmera o casco invertido
## vazava pelas dobras dos dedos (pontinhos pretos nas costas da mão).
func _mat(c: Color, rough := 0.8) -> StandardMaterial3D:
	return Mats.plastic_mat(c, rough)


func _region_mat(model: Dictionary, r: int) -> Material:
	if r >= CustomerRig.FIXED_BASE:
		var e: Dictionary = model.fixed[r - CustomerRig.FIXED_BASE]
		return _mat(e.colors[0], e.rough if e.rough >= 0.0 else 0.8)
	match r:
		CustomerRig.Role.SHIRT:
			return _mat(SLEEVE)
		CustomerRig.Role.SHIRT_LIGHT:
			return _mat(SLEEVE.lightened(0.2))
	return _mat(SKIN)


func _build_arm(right: bool) -> _Arm:
	var a := _Arm.new()
	a.side = 1.0 if right else -1.0
	var model := CustomerRig.load_model("hand_r" if right else "hand_l", DATA_DIR)
	a.root = Node3D.new()
	add_child(a.root)
	a.pose = Node3D.new()
	a.root.add_child(a.pose)
	a.skeleton = Skeleton3D.new()
	a.pose.add_child(a.skeleton)
	var list: Array[Node3D] = []
	var bone_of: Dictionary = {}
	for i in model.nodes.size():
		var n: Dictionary = model.nodes[i]
		var nd := Node3D.new()
		nd.name = n.name
		nd.transform = n.xform
		(a.pose if n.parent < 0 else list[n.parent]).add_child(nd)
		list.append(nd)
		a.nodes[n.name] = nd
		if n.bone:
			var b := a.skeleton.add_bone(n.name)
			if n.parent >= 0 and bone_of.has(n.parent):
				a.skeleton.set_bone_parent(b, bone_of[n.parent])
			a.skeleton.set_bone_rest(b, n.bind)
			bone_of[i] = b
			a.bone_nodes.append(nd)
	a.skeleton.reset_bone_poses()
	var skin_res := a.skeleton.create_skin_from_rest_transforms()
	for part: Dictionary in model.parts:
		var mi := MeshInstance3D.new()
		mi.name = part.name
		mi.mesh = part.mesh
		var regions: PackedInt32Array = part.regions
		for i in regions.size():
			mi.set_surface_override_material(i, _region_mat(model, regions[i]))
		if part.skinned:
			a.skeleton.add_child(mi)
			mi.skeleton = NodePath("..")
			mi.skin = skin_res
		else:
			list[part.node].add_child(mi)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("no_highlight", true)
	a.wrist = a.nodes.arm.position
	a.thumb_rest = a.nodes.t_a.basis
	return a


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
	if _item:
		for c in _item.find_children("*", "GeometryInstance3D", true, false):
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.set_meta("no_highlight", true)
		_item_anchor.add_child(_item)
		# encosta o item na palma (raio medido pela malha) e fecha os dedos em volta dele
		var radius := _item_radius(_item) * _item.scale.x
		_item_anchor.position = Vector3(-(0.024 + radius), 0.0, -0.012) - _right.wrist
		_item_anchor.rotation.y = 0.35
		_fit_grip(_right, Vector2(_item_anchor.position.x, _item_anchor.position.z), radius)
		# entra de baixo com um "pop"
		_right.root.position = _base_right + Vector3(0, -0.2, 0.05)
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


## Fecha cada dedo (no plano XZ da mão) até a falange encostar no cilindro do item.
## `center`: eixo do item em coordenadas do osso da mão (x, z).
func _fit_grip(a: _Arm, center: Vector2, radius: float) -> void:
	a.grip_curl = []
	for i in 4:
		var contact: float = radius + FINGER_R[i] + 0.002
		var p := Vector2(a.finger(i, 0).position.x, a.finger(i, 0).position.z)
		var lens := [-a.finger(i, 1).position.z, -a.finger(i, 2).position.z, TIP_LEN[i]]
		var prev := 0.0
		var curls := []
		for j in 3:
			var l: float = lens[j]
			var best := prev
			var best_d := INF
			var t := prev - 0.1
			while t <= prev + 1.9:
				var q := p + Vector2(-a.side * sin(t), -cos(t)) * l
				var d := q.distance_to(center)
				if d <= contact:
					best = t
					break
				if d < best_d:
					best_d = d
					best = t
				t += 0.02
			curls.append(clampf(best - prev, -0.1, 1.9))
			p += Vector2(-a.side * sin(best), -cos(best)) * l
			prev = best
		a.grip_curl.append(curls)
	# dedão: contorna o lado da câmera (+Z) e cruza na frente do item
	a.thumb_dir = Vector3(-a.side * 0.62, 0.12, 0.3 + radius * 4.0).normalized()
	a.thumb_curl = clampf(0.9 - radius * 5.0, 0.2, 0.8)


func set_pouring(on: bool) -> void:
	_pouring = on


func poke() -> void:
	_poke = 1.0


## Monta a pose atual do braço: dedos (solta ↔ segurando), dedão e pulso.
func _apply_pose(a: _Arm) -> void:
	var g := a.grip
	for i in 4:
		for j in 3:
			var relaxed: float = IDLE_CURL[j] + (0.05 * i if j == 0 else 0.0)
			var held: float = a.grip_curl[i][j] if g > 0.0 else relaxed
			a.finger(i, j).rotation = Vector3(0, a.side * lerpf(relaxed, held, g), 0)
	var t_a: Node3D = a.nodes.t_a
	if g > 0.0:
		var rest_dir := -a.thumb_rest.z
		var turn := Basis(Quaternion(rest_dir, a.thumb_dir))
		t_a.basis = a.thumb_rest.slerp(turn * a.thumb_rest, g)
	else:
		t_a.basis = a.thumb_rest
	(a.nodes.t_b as Node3D).rotation = Vector3(0, a.side * lerpf(0.3, a.thumb_curl, g), 0)
	a.sync()


func update_motion(delta: float, speed: float, bob_t: float) -> void:
	_poke = maxf(_poke - delta * 5.0, 0.0)
	_pour_blend = move_toward(_pour_blend, 1.0 if _pouring else 0.0, delta * 5.0)
	_right.grip = move_toward(_right.grip, 1.0 if _item else 0.0, delta * 6.0)
	var bob := Vector3(cos(bob_t * 0.5) * 0.012, -absf(sin(bob_t)) * 0.014, 0) * clampf(speed / 3.0, 0.0, 1.0)
	var breathe := Vector3(0, sin(Time.get_ticks_msec() * 0.002) * 0.004, 0)
	var poke_off := Vector3(0, 0.02, -0.07) * sin(_poke * PI)
	var pour_off := Vector3(-0.12, 0.08, -0.08) * _pour_blend
	var t := 1.0 - exp(-14.0 * delta)
	_right.root.position = _right.root.position.lerp(_base_right + bob + breathe + poke_off + pour_off, t)
	_left.root.position = _left.root.position.lerp(_base_left + bob * 0.8 - breathe, t)
	# servir: o antebraço gira em volta do próprio eixo e o punho acompanha
	var wobble := sin(Time.get_ticks_msec() * 0.03) * 0.04 * _pour_blend
	_pose_arm(_right, _pour_blend * 1.35 + wobble)
	_pose_arm(_left, 0.0)
	_left.root.visible = _item == null or _pour_blend < 0.5


## Gira o braço no pulso: solta = palma para baixo; segurando = costas da mão para a
## câmera. `pour`: giro extra para virar a garrafa.
func _pose_arm(a: _Arm, pour: float) -> void:
	var idle := 1.0 - a.grip
	var axis := Vector3(a.side * FORE_DIR.x, FORE_DIR.y, FORE_DIR.z).normalized()
	var b := Basis(axis, a.side * 1.35 * idle + pour)
	a.pose.transform = Transform3D(b, a.wrist - b * a.wrist)
	(a.nodes.hand as Node3D).rotation = Vector3(-0.25 * idle, -a.side * 0.35 * a.grip, 0)
	_apply_pose(a)
