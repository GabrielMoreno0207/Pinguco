class_name CustomerRig
extends Node3D
## Boneco cartunesco montado com primitivas: cabeça grande, olhos expressivos,
## pálpebras, sobrancelhas e bochechas que reagem à embriaguez.
## Frente do boneco = -Z local. Origem = chão.

const HIP_Y := 0.85

var profile: CustomerProfile
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var hand_r: Node3D
var belly: MeshInstance3D
var mouth: Node3D
var mouth_mesh: MeshInstance3D
var brow_l: Node3D
var brow_r: Node3D
var lid_l: MeshInstance3D
var lid_r: MeshInstance3D
var pupil_l: MeshInstance3D
var pupil_r: MeshInstance3D
var cheek_mat: StandardMaterial3D
var nose_mat: StandardMaterial3D
var face_mat: StandardMaterial3D
var _base_skin: Color
var _eye_y := 0.0
var _eye_x := 0.0
var _mouth_y := 0.0


func build(p: CustomerProfile) -> void:
	profile = p
	_base_skin = p.skin_color
	# materiais próprios do cliente (mudam de cor com a bebedeira)
	face_mat = Mats.toon(p.skin_color).duplicate()
	nose_mat = Mats.toon(p.skin_color.darkened(0.05)).duplicate()
	cheek_mat = StandardMaterial3D.new()
	cheek_mat.albedo_color = Color(1.0, 0.25, 0.3, 0.0)
	cheek_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cheek_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var body_w := 1.0
	var body_depth := 1.0
	var height := 1.0
	match p.body:
		CustomerProfile.Body.VALENTAO:
			body_w = 1.35
			height = 1.05
		CustomerProfile.Body.FALANTE:
			body_w = 0.85
			body_depth = 0.85
			height = 1.08
		CustomerProfile.Body.FOFOQUEIRA:
			body_w = 0.95
			height = 0.95

	# pernas
	leg_l = _leg(-0.11 * body_w, p)
	leg_r = _leg(0.11 * body_w, p)

	# tronco
	torso = Node3D.new()
	torso.name = "Torso"
	torso.position.y = HIP_Y
	add_child(torso)
	var chest := Mats.capsule(torso, 0.2 * body_w, 0.62 * height, Vector3(0, 0.3 * height, 0), p.shirt_color)
	chest.scale = Vector3(1.0, 1.0, 0.85 * body_depth)
	Mats.cylinder(torso, 0.2 * body_w, 0.12, Vector3(0, 0.03, 0), p.pants_color)
	if p.body == CustomerProfile.Body.TIOZAO:
		belly = Mats.sphere(torso, 0.25, Vector3(0, 0.2, -0.1), p.shirt_color, true, Vector3(1.0, 0.9, 0.95))
		# regata: braços de fora
	elif p.body == CustomerProfile.Body.VALENTAO:
		Mats.sphere(torso, 0.17, Vector3(-0.17, 0.48, -0.03), p.shirt_color, true, Vector3(1.1, 0.8, 1.0))
		Mats.sphere(torso, 0.17, Vector3(0.17, 0.48, -0.03), p.shirt_color, true, Vector3(1.1, 0.8, 1.0))
		# corrente de ouro
		var chain := Mats.torus(torso, 0.1, 0.12, Vector3(0, 0.55, -0.08), Color(1.0, 0.8, 0.2))
		chain.rotation_degrees.x = 70
	elif p.body == CustomerProfile.Body.FALANTE:
		# camisa florida: bolinhas
		for i in 7:
			var a := i * 1.7
			Mats.sphere(torso, 0.03, Vector3(cos(a) * 0.1, 0.18 + (i % 4) * 0.1, -0.165), Color(1.0, 0.9, 0.3), false)
	elif p.body == CustomerProfile.Body.FOFOQUEIRA:
		# colar de pérolas
		for i in 9:
			var a := lerpf(-1.1, 1.1, i / 8.0)
			Mats.sphere(torso, 0.022, Vector3(sin(a) * 0.13, 0.56 - cos(a) * 0.05, -0.12 - cos(a) * 0.03), Color(1, 0.98, 0.92), false)

	# braços
	var sleeve_short := p.body == CustomerProfile.Body.TIOZAO or p.body == CustomerProfile.Body.VALENTAO
	arm_l = _arm(-0.26 * body_w, 0.52 * height, p, sleeve_short)
	arm_r = _arm(0.26 * body_w, 0.52 * height, p, sleeve_short)
	hand_r = arm_r.get_node("Hand")

	# cabeça
	head = Node3D.new()
	head.name = "Head"
	head.position.y = 0.62 * height
	torso.add_child(head)
	_build_head(p)
	_merge_parts()


## Menos draw calls: junta as peças estáticas de cada osso.
func _merge_parts() -> void:
	if belly:
		belly.set_meta("dynamic", true)
	for n: MeshInstance3D in [lid_l, lid_r, pupil_l, pupil_r]:
		n.set_meta("dynamic", true)
	for bone: Node3D in [torso, head, arm_l, arm_r, leg_l, leg_r, hand_r, arm_l.get_node("Hand")]:
		Mats.merge_children(bone)


func _leg(x: float, p: CustomerProfile) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, HIP_Y, 0)
	add_child(pivot)
	Mats.capsule(pivot, 0.085, 0.8, Vector3(0, -0.38, 0), p.pants_color)
	var shoe := Mats.box(pivot, Vector3(0.13, 0.08, 0.24), Vector3(0, -0.8, -0.05), Color(0.15, 0.1, 0.08))
	shoe.name = "Shoe"
	return pivot


func _arm(x: float, y: float, p: CustomerProfile, short_sleeve: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, y, 0)
	torso.add_child(pivot)
	Mats.capsule(pivot, 0.065, 0.48, Vector3(0, -0.22, 0), p.skin_color if short_sleeve else p.shirt_color)
	if short_sleeve:
		Mats.cylinder(pivot, 0.08, 0.12, Vector3(0, -0.03, 0), p.shirt_color)
	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0, -0.48, 0)
	pivot.add_child(hand)
	Mats.sphere(hand, 0.075, Vector3.ZERO, p.skin_color)
	return pivot


func _build_head(p: CustomerProfile) -> void:
	var r := 0.25
	var head_scale := Vector3(1.0, 1.05, 0.95)
	match p.body:
		CustomerProfile.Body.VALENTAO:
			head_scale = Vector3(1.12, 0.95, 1.0)
		CustomerProfile.Body.FALANTE:
			head_scale = Vector3(0.9, 1.15, 0.92)
	var skull := Mats.sphere(head, r, Vector3(0, r, 0), p.skin_color, true, head_scale)
	skull.material_override = face_mat
	face_mat.next_pass = Mats.outline_mat()
	var fy := r * 1.0
	var fz := -r * head_scale.z * 0.86
	# orelhas
	for side in [-1.0, 1.0]:
		var ear := Mats.sphere(head, 0.06, Vector3(side * r * head_scale.x * 0.98, fy, 0), p.skin_color, true, Vector3(0.5, 1.0, 0.8))
		ear.material_override = face_mat
	# olhos
	var eye_x := 0.085 * head_scale.x
	var eye_y := fy + 0.06
	_eye_y = eye_y
	_eye_x = eye_x
	_mouth_y = fy - 0.11
	for side in [-1.0, 1.0]:
		var white := Mats.sphere(head, 0.068, Vector3(side * eye_x, eye_y, fz + 0.02), Color.WHITE, true, Vector3(1.0, 1.15, 0.7))
		white.name = "EyeWhite"
		var pupil := Mats.sphere(head, 0.032, Vector3(side * eye_x, eye_y, fz - 0.025), Color(0.08, 0.05, 0.04), false)
		var lid := Mats.sphere(head, 0.073, Vector3(side * eye_x, eye_y + 0.004, fz + 0.018), p.skin_color.darkened(0.08), false, Vector3(1.05, 1.2, 0.75))
		# pálpebra = meia esfera que desce; começa recolhida (escala y pequena, deslocada para cima)
		lid.scale = Vector3(1.05, 0.2, 0.78)
		lid.position.y = eye_y + 0.07
		var brow := Node3D.new()
		brow.position = Vector3(side * eye_x, eye_y + 0.1, fz - 0.005)
		head.add_child(brow)
		Mats.box(brow, Vector3(0.1, 0.025, 0.03), Vector3.ZERO, p.hair_color, false)
		if side < 0:
			pupil_l = pupil
			lid_l = lid
			brow_l = brow
		else:
			pupil_r = pupil
			lid_r = lid
			brow_r = brow
	# nariz (fica vermelho com a bebida)
	var nose := Mats.sphere(head, 0.055, Vector3(0, fy - 0.02, fz - 0.06), p.skin_color, true, Vector3(1.0, 0.85, 1.0))
	nose.material_override = nose_mat
	nose_mat.next_pass = Mats.outline_mat()
	if p.body == CustomerProfile.Body.FALANTE:
		nose.scale = Vector3(0.8, 1.0, 1.5)
	# bochechas coradas
	for side in [-1.0, 1.0]:
		var cheek := Mats.sphere(head, 0.05, Vector3(side * 0.15 * head_scale.x, fy - 0.05, fz + 0.03), Color.WHITE, false, Vector3(1.0, 0.6, 0.3))
		cheek.material_override = cheek_mat
		cheek.set_meta("no_highlight", true)
	# boca
	mouth = Node3D.new()
	mouth.position = Vector3(0, fy - 0.11, fz + 0.01)
	head.add_child(mouth)
	mouth_mesh = Mats.sphere(mouth, 0.05, Vector3.ZERO, Color(0.35, 0.08, 0.1), false, Vector3(1.4, 0.35, 0.5))
	Mats.box(mouth, Vector3(0.07, 0.012, 0.02), Vector3(0, 0.012, -0.012), Color.WHITE, false)
	_build_hair(p, r, head_scale, fy, fz)


func _build_hair(p: CustomerProfile, r: float, hs: Vector3, fy: float, fz: float) -> void:
	match p.body:
		CustomerProfile.Body.TIOZAO:
			# careca com coroinha de cabelo + bigodão
			Mats.torus(head, r * 0.82, r * 1.02, Vector3(0, r * 0.95, 0.03), p.hair_color, true).rotation_degrees.x = 12
			var stache := Mats.capsule(head, 0.035, 0.2, Vector3(0, fy - 0.075, fz - 0.03), p.hair_color)
			stache.rotation_degrees.z = 90
		CustomerProfile.Body.VALENTAO:
			# cabelo raspado + monocelha + boné pra trás
			Mats.sphere(head, r * 1.01, Vector3(0, r * 1.06, 0.01), p.hair_color, false, Vector3(hs.x, hs.y * 0.75, hs.z))
			var cap := Mats.sphere(head, r * 1.04, Vector3(0, r * 1.18, 0.02), Color(0.85, 0.15, 0.15), true, Vector3(hs.x, 0.55, hs.z))
			cap.name = "Cap"
			Mats.box(head, Vector3(0.22, 0.02, 0.16), Vector3(0, r * 1.3, r * 0.95), Color(0.85, 0.15, 0.15))
			Mats.capsule(head, 0.03, 0.26, Vector3(0, fy + 0.155, fz - 0.005), p.hair_color).rotation_degrees.z = 90
			# barba por fazer
			Mats.sphere(head, r * 0.75, Vector3(0, fy - 0.1, fz * 0.55), p.skin_color.darkened(0.25), false, Vector3(1.0, 0.6, 0.7))
		CustomerProfile.Body.FALANTE:
			# topete alto + óculos
			Mats.sphere(head, r * 0.95, Vector3(0, r * 1.35, -0.02), p.hair_color, true, Vector3(1.0, 0.7, 1.05))
			Mats.sphere(head, r * 0.5, Vector3(0, r * 1.75, -r * 0.4), p.hair_color, true, Vector3(1.1, 0.9, 1.3))
			for side in [-1.0, 1.0]:
				var lens := Mats.torus(head, 0.06, 0.075, Vector3(side * 0.085 * hs.x, fy + 0.06, fz - 0.04), Color(0.1, 0.1, 0.1))
				lens.rotation_degrees.x = 90
		CustomerProfile.Body.FOFOQUEIRA:
			# cabelão cacheado (bolinhas) + brincos
			for i in 16:
				var a := i * TAU / 16.0
				var y := r * 1.0 + sin(a * 2.0) * 0.06 + 0.12
				Mats.sphere(head, 0.11, Vector3(cos(a) * r * 1.0, y, sin(a) * r * 0.95 + 0.04), p.hair_color, true)
			Mats.sphere(head, r * 0.9, Vector3(0, r * 1.45, 0.03), p.hair_color, true)
			for side in [-1.0, 1.0]:
				Mats.torus(head, 0.025, 0.04, Vector3(side * r * 1.0, fy - 0.1, -0.01), Color(1.0, 0.8, 0.2)).rotation_degrees.z = 90
			# batom
			mouth_mesh.material_override = Mats.toon(Color(0.85, 0.1, 0.25), false)


## Aplica as cores e a "cara" da embriaguez (0..1).
func apply_drunk_look(f: float, flush: float) -> void:
	cheek_mat.albedo_color.a = clampf(f * 0.9 + flush * 0.5, 0.0, 0.85)
	nose_mat.albedo_color = _base_skin.lerp(Color(0.95, 0.25, 0.25), clampf(f * 1.1, 0.0, 1.0))
	face_mat.albedo_color = _base_skin.lerp(Color(0.9, 0.3, 0.25), clampf(flush * 0.6, 0.0, 0.6))


## lid = 0 aberto … 1 fechado
func set_eyelids(lid: float) -> void:
	lid = clampf(lid, 0.0, 1.0)
	for l: MeshInstance3D in [lid_l, lid_r]:
		l.scale.y = lerpf(0.2, 1.25, lid)
		l.position.y = lerpf(_eye_y + 0.07, _eye_y + 0.004, lid)


func set_brows(angle: float, raise: float) -> void:
	brow_l.rotation.z = -angle
	brow_r.rotation.z = angle
	brow_l.position.y = _eye_y + 0.1 + raise
	brow_r.position.y = brow_l.position.y


func set_mouth(open: float, smile: float) -> void:
	mouth_mesh.scale = Vector3(1.4 + smile * 0.3, 0.3 + open * 1.1, 0.5)
	mouth.position.y = _mouth_y - open * 0.015


func look_pupils(offset: Vector2) -> void:
	pupil_l.position.x = -_eye_x + offset.x * 0.025
	pupil_r.position.x = _eye_x + offset.y * 0.025
