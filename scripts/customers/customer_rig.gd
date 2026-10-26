class_name CustomerRig
extends Node3D
## Boneco cartunesco montado com primitivas: cabeça grande, olhos com íris e brilho,
## pálpebras, sobrancelhas, boca com dentes e língua, mãos com dedos, roupa e acessórios
## próprios de cada tipo. Cada freguês sorteia tom de pele, roupa e proporções.
## Frente do boneco = -Z local. Origem = chão.

const HIP_Y := 0.85
const SKIN_TONES := [Color(0.98, 0.8, 0.66), Color(0.93, 0.72, 0.56), Color(0.8, 0.56, 0.4),
	Color(0.66, 0.44, 0.3), Color(0.5, 0.33, 0.22), Color(0.38, 0.25, 0.17)]
const IRIS_COLORS := [Color(0.35, 0.22, 0.12), Color(0.2, 0.45, 0.25), Color(0.25, 0.45, 0.75), Color(0.45, 0.3, 0.15)]
const SHOE := Color(0.15, 0.1, 0.08)

var profile: CustomerProfile
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var hand_l: Node3D
var hand_r: Node3D
var belly: MeshInstance3D
var mouth: Node3D
var mouth_mesh: MeshInstance3D
var brow_l: Node3D
var brow_r: Node3D
var lid_l: MeshInstance3D
var lid_r: MeshInstance3D
var pupil_l: Node3D
var pupil_r: Node3D
## Acessório de mão animado por perfil (celular, leque, chapéu...). Pode ser null.
var prop: Node3D
var hat: Node3D
var cheek_mat: StandardMaterial3D
var nose_mat: StandardMaterial3D
var face_mat: StandardMaterial3D
## Mesma pele, sem contorno (peças pequenas: dedos, dedões do pé, queixo, colo).
var skin_flat_mat: StandardMaterial3D
var skin: Color
var shirt: Color
var _base_skin: Color
var _eye_y := 0.0
var _eye_x := 0.0
var _mouth_y := 0.0
var _rng := RandomNumberGenerator.new()


## variation_seed: mesmo valor → mesmo visual (ex.: hash do apelido).
func build(p: CustomerProfile, variation_seed := 0) -> void:
	profile = p
	_rng.seed = variation_seed if variation_seed != 0 else randi()
	skin = p.skin_color if _rng.randf() < 0.45 else SKIN_TONES[_rng.randi_range(0, SKIN_TONES.size() - 1)]
	shirt = p.shirt_color if p.shirt_variants.is_empty() else p.shirt_variants[_rng.randi_range(0, p.shirt_variants.size() - 1)]
	_base_skin = skin
	# materiais próprios do cliente (mudam de cor com a bebedeira)
	face_mat = Mats.toon(skin).duplicate()
	face_mat.next_pass = Mats.outline_mat()
	skin_flat_mat = Mats.toon(skin, false).duplicate()
	nose_mat = Mats.toon(skin.darkened(0.04)).duplicate()
	nose_mat.next_pass = Mats.outline_mat()
	cheek_mat = StandardMaterial3D.new()
	cheek_mat.albedo_color = Color(1.0, 0.3, 0.35, 0.0)
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
		CustomerProfile.Body.UNIVERSITARIO:
			body_w = 0.82
			body_depth = 0.85
			height = 1.06
		CustomerProfile.Body.MALANDRO:
			body_w = 0.95
			height = 1.02
	# cada freguês é um pouquinho diferente
	body_w *= _rng.randf_range(0.94, 1.06)
	height *= _rng.randf_range(0.96, 1.04)

	leg_l = _leg(-0.11 * body_w, p)
	leg_r = _leg(0.11 * body_w, p)

	torso = Node3D.new()
	torso.name = "Torso"
	torso.position.y = HIP_Y
	add_child(torso)
	_build_torso(p, body_w, body_depth, height)

	var sleeve := _sleeve_kind(p)
	arm_l = _arm(-0.26 * body_w, 0.52 * height, sleeve, false)
	arm_r = _arm(0.26 * body_w, 0.52 * height, sleeve, true)
	hand_r = arm_r.get_node("Hand")
	hand_l = arm_l.get_node("Hand")
	_arm_extras(p)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = 0.62 * height
	torso.add_child(head)
	# pescoço
	Mats.cylinder(torso, 0.07 * (1.25 if p.body == CustomerProfile.Body.VALENTAO else 1.0), 0.12, Vector3(0, 0.6 * height, 0), skin).material_override = face_mat
	_build_head(p)
	_merge_parts()


## Menos draw calls: junta as peças estáticas de cada osso.
func _merge_parts() -> void:
	if belly:
		belly.set_meta("dynamic", true)
	for n: MeshInstance3D in [lid_l, lid_r]:
		n.set_meta("dynamic", true)
	for bone: Node3D in [torso, head, arm_l, arm_r, leg_l, leg_r, hand_r, hand_l]:
		Mats.merge_children(bone)


# ------------------------------------------------------------------ corpo

func _build_torso(p: CustomerProfile, bw: float, bd: float, h: float) -> void:
	var chest := Mats.capsule(torso, 0.2 * bw, 0.62 * h, Vector3(0, 0.3 * h, 0), shirt)
	chest.scale = Vector3(1.0, 1.0, 0.85 * bd)
	Mats.cylinder(torso, 0.2 * bw, 0.12, Vector3(0, 0.03, 0), p.pants_color)
	# cinto
	Mats.cylinder(torso, 0.202 * bw, 0.035, Vector3(0, 0.1, 0), Color(0.25, 0.15, 0.08), false)
	var front := -0.17 * bd
	match p.body:
		CustomerProfile.Body.TIOZAO:
			# regata branca: ombros de fora, barrigão, pelinho no peito e cordão
			belly = Mats.sphere(torso, 0.25, Vector3(0, 0.2, -0.1), shirt, true, Vector3(1.0, 0.9, 0.95))
			Mats.sphere(torso, 0.1, Vector3(0, 0.52 * h, front + 0.03), skin, false, Vector3(1.4, 0.6, 0.4)).material_override = skin_flat_mat
			for i in 5:
				Mats.sphere(torso, 0.012, Vector3(-0.04 + i * 0.02, 0.5 * h + (i % 2) * 0.012, front - 0.0), Color(0.55, 0.55, 0.55), false)
			for side in [-1.0, 1.0]:
				Mats.sphere(torso, 0.09, Vector3(side * 0.2 * bw, 0.5 * h, 0), skin, false, Vector3(1, 0.8, 1)).material_override = face_mat
			Mats.torus(torso, 0.07, 0.078, Vector3(0, 0.53 * h, front + 0.01), Color(1.0, 0.82, 0.2)).rotation_degrees.x = 75
			# caneta atrás da orelha fica na cabeça; aqui a carteira no bolso de trás
			Mats.box(torso, Vector3(0.1, 0.07, 0.02), Vector3(0.1, 0.05, 0.19 * bd), Color(0.35, 0.2, 0.1), false)
		CustomerProfile.Body.VALENTAO:
			# regata preta, ombros de academia e corrente grossa
			for side in [-1.0, 1.0]:
				Mats.sphere(torso, 0.17, Vector3(side * 0.17, 0.48 * h, -0.03), skin, true, Vector3(1.1, 0.8, 1.0)).material_override = face_mat
			Mats.sphere(torso, 0.16, Vector3(-0.08, 0.38 * h, front + 0.02), shirt, false, Vector3(1.0, 0.7, 0.5))
			Mats.sphere(torso, 0.16, Vector3(0.08, 0.38 * h, front + 0.02), shirt, false, Vector3(1.0, 0.7, 0.5))
			for i in 9:
				var a := lerpf(-1.2, 1.2, i / 8.0)
				Mats.sphere(torso, 0.017, Vector3(sin(a) * 0.12, 0.52 * h - cos(a) * 0.08, front - 0.02 - cos(a) * 0.02), Color(1.0, 0.8, 0.2), false)
			Mats.box(torso, Vector3(0.05, 0.06, 0.015), Vector3(0, 0.42 * h, front - 0.06), Color(1.0, 0.8, 0.2), false)
		CustomerProfile.Body.FALANTE:
			# camisa havaiana: gola, botões, bolso com caneta e flores
			_collar(bw, h, front, shirt.lightened(0.15))
			for i in 4:
				Mats.sphere(torso, 0.011, Vector3(0, 0.45 * h - i * 0.1, front - 0.01), Color(0.95, 0.95, 0.9), false)
			Mats.box(torso, Vector3(0.08, 0.08, 0.01), Vector3(-0.09, 0.4 * h, front + 0.0), shirt.darkened(0.12), false)
			Mats.cylinder(torso, 0.008, 0.08, Vector3(-0.07, 0.44 * h, front - 0.005), Color(0.15, 0.3, 0.8), false)
			var petal := Color(1.0, 0.9, 0.3) if shirt.get_luminance() < 0.6 else Color(0.9, 0.2, 0.3)
			for i in 9:
				var a := i * 2.1
				var pos := Vector3(cos(a) * 0.12 * bw, 0.12 + (i % 5) * 0.09, front + 0.01 + absf(sin(a)) * 0.02)
				Mats.sphere(torso, 0.026, pos, petal, false, Vector3(1, 1, 0.4))
				Mats.sphere(torso, 0.01, pos + Vector3(0, 0, -0.008), Color(1, 1, 1), false)
		CustomerProfile.Body.FOFOQUEIRA:
			# blusa com babado, colar de pérolas e bolsa no ombro
			for i in 7:
				var a := lerpf(-1.0, 1.0, i / 6.0)
				Mats.sphere(torso, 0.035, Vector3(sin(a) * 0.15, 0.56 * h - cos(a) * 0.04, front + 0.02 - cos(a) * 0.02), shirt.lightened(0.25), false)
			for i in 11:
				var a := lerpf(-1.1, 1.1, i / 10.0)
				Mats.sphere(torso, 0.018, Vector3(sin(a) * 0.13, 0.53 * h - cos(a) * 0.06, front - 0.01 - cos(a) * 0.03), Color(1, 0.98, 0.92), false)
			var bag := Mats.box(torso, Vector3(0.18, 0.13, 0.07), Vector3(0.25 * bw, 0.12, 0.05), Color(0.85, 0.65, 0.2))
			bag.rotation.z = 0.1
			Mats.torus(torso, 0.1, 0.11, Vector3(0.21 * bw, 0.3, 0.05), Color(0.6, 0.4, 0.1)).rotation_degrees = Vector3(0, 90, 60)
		CustomerProfile.Body.UNIVERSITARIO:
			# moletom com capuz, cordinhas, bolso canguru e mochila
			Mats.torus(torso, 0.09, 0.15, Vector3(0, 0.56 * h, 0.06), shirt.darkened(0.1), true).rotation_degrees.x = -20
			for side in [-1.0, 1.0]:
				Mats.cylinder(torso, 0.006, 0.14, Vector3(side * 0.04, 0.45 * h, front - 0.015), Color(0.95, 0.95, 0.95), false)
				Mats.sphere(torso, 0.012, Vector3(side * 0.04, 0.38 * h, front - 0.015), Color(0.95, 0.95, 0.95), false)
			Mats.box(torso, Vector3(0.22 * bw, 0.1, 0.02), Vector3(0, 0.18, front - 0.005), shirt.darkened(0.15), false)
			Mats.label3d(torso, "UFPZ", Vector3(0, 0.36 * h, front - 0.02), 40, Color(1, 1, 1), 0).rotation.y = PI
			var pack := Mats.box(torso, Vector3(0.3 * bw, 0.36, 0.16), Vector3(0, 0.33 * h, 0.22), Color(0.2, 0.3, 0.55))
			pack.name = "Backpack"
			Mats.box(torso, Vector3(0.22 * bw, 0.14, 0.05), Vector3(0, 0.22 * h, 0.31), Color(0.25, 0.35, 0.6), false)
			for side in [-1.0, 1.0]:
				Mats.box(torso, Vector3(0.04, 0.4, 0.02), Vector3(side * 0.11 * bw, 0.36 * h, front + 0.0), Color(0.15, 0.2, 0.4), false)
		CustomerProfile.Body.MALANDRO:
			# camisa listrada de malandro, gola aberta, lenço no bolso
			for i in 6:
				Mats.cylinder(torso, 0.203 * bw, 0.035, Vector3(0, 0.17 + i * 0.075 * h, 0), Color(0.97, 0.97, 0.95), false)
			_collar(bw, h, front, Color(0.97, 0.97, 0.95))
			Mats.sphere(torso, 0.06, Vector3(0, 0.53 * h, front + 0.03), skin, false, Vector3(1, 1.2, 0.5)).material_override = skin_flat_mat
			Mats.box(torso, Vector3(0.06, 0.03, 0.01), Vector3(-0.1, 0.42 * h, front - 0.005), Color(0.95, 0.85, 0.2), false)
			Mats.torus(torso, 0.05, 0.056, Vector3(0, 0.52 * h, front + 0.0), Color(1.0, 0.82, 0.2)).rotation_degrees.x = 75


func _collar(bw: float, h: float, front: float, c: Color) -> void:
	for side in [-1.0, 1.0]:
		var col := Mats.box(torso, Vector3(0.09, 0.02, 0.07), Vector3(side * 0.06 * bw, 0.56 * h, front + 0.04), c, false)
		col.rotation = Vector3(0.5, side * 0.5, side * -0.4)


func _sleeve_kind(p: CustomerProfile) -> int:
	# 0 = sem manga (regata), 1 = manga curta, 2 = manga comprida
	match p.body:
		CustomerProfile.Body.TIOZAO, CustomerProfile.Body.VALENTAO:
			return 0
		CustomerProfile.Body.UNIVERSITARIO:
			return 2
		CustomerProfile.Body.FOFOQUEIRA:
			return 2
	return 1


func _leg(x: float, p: CustomerProfile) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, HIP_Y, 0)
	add_child(pivot)
	match p.body:
		CustomerProfile.Body.TIOZAO:
			# bermuda + canela de fora + chinelo
			Mats.capsule(pivot, 0.095, 0.42, Vector3(0, -0.18, 0), p.pants_color)
			Mats.capsule(pivot, 0.065, 0.45, Vector3(0, -0.56, 0), skin).material_override = face_mat
			_flip_flop(pivot)
		CustomerProfile.Body.FOFOQUEIRA:
			# saia rodada (acompanha a perna quando senta) + meia-calça + sapatinho vermelho
			Mats.cylinder(pivot, 0.15, 0.36, Vector3(0, -0.16, 0), shirt.darkened(0.3), true, 0.12)
			Mats.capsule(pivot, 0.06, 0.55, Vector3(0, -0.5, 0), skin.darkened(0.15))
			var shoe := Mats.box(pivot, Vector3(0.1, 0.06, 0.2), Vector3(0, -0.8, -0.04), Color(0.8, 0.12, 0.15))
			shoe.name = "Shoe"
			Mats.box(pivot, Vector3(0.03, 0.06, 0.03), Vector3(0, -0.82, 0.05), Color(0.6, 0.08, 0.1), false)
		_:
			Mats.capsule(pivot, 0.085, 0.8, Vector3(0, -0.38, 0), p.pants_color)
			var shoe_col := SHOE
			match p.body:
				CustomerProfile.Body.UNIVERSITARIO:
					shoe_col = Color(0.95, 0.95, 0.95)
				CustomerProfile.Body.MALANDRO:
					shoe_col = Color(0.98, 0.98, 0.96)
			var shoe := Mats.box(pivot, Vector3(0.13, 0.08, 0.25), Vector3(0, -0.8, -0.05), shoe_col)
			shoe.name = "Shoe"
			Mats.box(pivot, Vector3(0.135, 0.025, 0.26), Vector3(0, -0.835, -0.05), Color(0.12, 0.1, 0.1) if p.body != CustomerProfile.Body.UNIVERSITARIO else Color(0.85, 0.2, 0.2), false)
			if p.body == CustomerProfile.Body.MALANDRO:
				# sapato bicolor
				Mats.box(pivot, Vector3(0.132, 0.082, 0.08), Vector3(0, -0.8, -0.14), Color(0.1, 0.08, 0.08), false)
			elif p.body == CustomerProfile.Body.VALENTAO:
				# coturno
				Mats.cylinder(pivot, 0.08, 0.14, Vector3(0, -0.73, 0), SHOE, false)
	return pivot


func _flip_flop(pivot: Node3D) -> void:
	Mats.box(pivot, Vector3(0.12, 0.02, 0.26), Vector3(0, -0.83, -0.05), Color(0.2, 0.55, 0.3))
	var foot := Mats.box(pivot, Vector3(0.1, 0.05, 0.22), Vector3(0, -0.8, -0.05), skin, false)
	foot.material_override = skin_flat_mat
	for i in 4:
		Mats.sphere(pivot, 0.016, Vector3(-0.03 + i * 0.02, -0.79, -0.165), skin, false).material_override = skin_flat_mat
	Mats.box(pivot, Vector3(0.11, 0.012, 0.012), Vector3(0, -0.77, -0.09), Color(0.95, 0.95, 0.95), false)


func _arm(x: float, y: float, sleeve: int, right: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, y, 0)
	torso.add_child(pivot)
	var thick := 1.35 if profile.body == CustomerProfile.Body.VALENTAO else 1.0
	var arm := Mats.capsule(pivot, 0.065 * thick, 0.48, Vector3(0, -0.22, 0), shirt if sleeve == 2 else skin)
	if sleeve != 2:
		arm.material_override = face_mat
	if sleeve == 1:
		Mats.cylinder(pivot, 0.082 * thick, 0.14, Vector3(0, -0.04, 0), shirt)
	elif sleeve == 2:
		Mats.cylinder(pivot, 0.07 * thick, 0.04, Vector3(0, -0.43, 0), shirt.darkened(0.15), false)
	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0, -0.48, 0)
	pivot.add_child(hand)
	_build_hand(hand, right, thick)
	return pivot


## Mão cartunesca: palma, dedão e três dedos levemente dobrados.
func _build_hand(hand: Node3D, right: bool, thick: float) -> void:
	var side := 1.0 if right else -1.0
	var s := 0.9 + (thick - 1.0) * 0.6
	var palm := Mats.sphere(hand, 0.06 * s, Vector3.ZERO, skin, true, Vector3(0.9, 1.0, 0.7))
	palm.material_override = face_mat
	var thumb := Mats.capsule(hand, 0.02 * s, 0.07 * s, Vector3(-side * 0.045 * s, 0.0, -0.03 * s), skin, false)
	thumb.material_override = skin_flat_mat
	thumb.rotation = Vector3(0.6, 0, side * 0.7)
	for i in 3:
		var f := Mats.capsule(hand, 0.018 * s, 0.07 * s, Vector3((-0.025 + i * 0.025) * s, -0.06 * s, -0.012 * s), skin, false)
		f.material_override = skin_flat_mat
		f.rotation.x = 0.35


func _arm_extras(p: CustomerProfile) -> void:
	match p.body:
		CustomerProfile.Body.VALENTAO:
			# tatuagem de coração "MÃE" no braço
			var tat := Node3D.new()
			tat.position = Vector3(0.0, -0.17, -0.085)
			arm_r.add_child(tat)
			var heart := MeshInstance3D.new()
			heart.mesh = Mats.flat_polygon_mesh(SymbolShapes.polygon(&"heart"), 0.035)
			heart.material_override = Mats.unshaded(Color(0.75, 0.1, 0.15))
			heart.rotation.y = PI
			tat.add_child(heart)
			var l := Mats.label3d(tat, "MÃE", Vector3(0, -0.002, -0.002), 24, Color(0.15, 0.2, 0.45), 0)
			l.pixel_size = 0.0012
			l.rotation.y = PI
			# relógio dourado
			Mats.cylinder(arm_l, 0.09, 0.03, Vector3(0, -0.4, 0), Color(1.0, 0.8, 0.2), false)
		CustomerProfile.Body.FOFOQUEIRA:
			# pulseiras + leque na mão esquerda
			for i in 3:
				Mats.torus(arm_l, 0.06, 0.07, Vector3(0, -0.38 - i * 0.02, 0), [Color(1, 0.8, 0.2), Color(0.9, 0.3, 0.5), Color(0.3, 0.7, 0.9)][i])
			prop = Node3D.new()
			prop.name = "Fan"
			prop.position = Vector3(0, -0.07, -0.03)
			hand_l.add_child(prop)
			var fan := MeshInstance3D.new()
			var pts := PackedVector2Array([Vector2(0, 0)])
			for i in 9:
				var a := lerpf(-0.9, 0.9, i / 8.0) - PI / 2.0
				pts.append(Vector2(cos(a), sin(a)) * (1.0 if i % 2 == 0 else 0.93))
			fan.mesh = Mats.flat_polygon_mesh(pts, 0.14)
			fan.material_override = Mats.unshaded(Color(0.95, 0.35, 0.5))
			fan.rotation = Vector3(0, PI / 2.0, PI)
			prop.add_child(fan)
		CustomerProfile.Body.UNIVERSITARIO:
			# celular na mão esquerda (tela acesa)
			prop = Node3D.new()
			prop.name = "Phone"
			prop.position = Vector3(0, -0.06, -0.03)
			hand_l.add_child(prop)
			Mats.box(prop, Vector3(0.07, 0.13, 0.012), Vector3.ZERO, Color(0.1, 0.1, 0.12), false)
			var screen := Mats.box(prop, Vector3(0.06, 0.115, 0.004), Vector3(0, 0, -0.007), Color(0.4, 0.7, 1.0), false)
			screen.material_override = Mats.toon(Color(0.45, 0.75, 1.0), false, 0.5, 1.5)
		CustomerProfile.Body.MALANDRO:
			# anel de ouro e relógio
			Mats.torus(hand_r, 0.016, 0.024, Vector3(0.0, -0.05, -0.02), Color(1.0, 0.82, 0.2))
			Mats.cylinder(arm_l, 0.072, 0.03, Vector3(0, -0.4, 0), Color(1.0, 0.82, 0.2), false)


# ------------------------------------------------------------------ cabeça

func _build_head(p: CustomerProfile) -> void:
	var r := 0.25
	var hs := Vector3(1.0, 1.05, 0.95)
	match p.body:
		CustomerProfile.Body.VALENTAO:
			hs = Vector3(1.12, 0.95, 1.0)
		CustomerProfile.Body.FALANTE:
			hs = Vector3(0.9, 1.15, 0.92)
		CustomerProfile.Body.UNIVERSITARIO:
			hs = Vector3(0.92, 1.1, 0.95)
		CustomerProfile.Body.MALANDRO:
			hs = Vector3(0.95, 1.08, 0.95)
	var skull := Mats.sphere(head, r, Vector3(0, r, 0), skin, true, hs)
	skull.material_override = face_mat
	# queixo/mandíbula para tirar o "cabeça-bola"
	var jaw := Mats.sphere(head, r * 0.72, Vector3(0, r * 0.62, -0.03), skin, false, Vector3(hs.x * 1.0, 0.75, hs.z))
	jaw.material_override = skin_flat_mat
	var fy := r * 1.0
	var fz := -r * hs.z * 0.86
	# orelhas com parte interna
	for side in [-1.0, 1.0]:
		var ear := Mats.sphere(head, 0.06, Vector3(side * r * hs.x * 0.98, fy, 0), skin, true, Vector3(0.5, 1.0, 0.8))
		ear.material_override = face_mat
		var inner := Mats.sphere(head, 0.035, Vector3(side * (r * hs.x * 0.98 + 0.018), fy, -0.005), skin.darkened(0.2), false, Vector3(0.4, 1.0, 0.7))
		inner.set_meta("no_highlight", true)
	# olhos: branco + (íris, pupila, brilho) num grupo que olha em volta
	var eye_x := 0.085 * hs.x
	var eye_y := fy + 0.06
	_eye_y = eye_y
	_eye_x = eye_x
	_mouth_y = fy - 0.11
	var iris_col: Color = IRIS_COLORS[_rng.randi_range(0, IRIS_COLORS.size() - 1)]
	for side in [-1.0, 1.0]:
		var white := Mats.sphere(head, 0.068, Vector3(side * eye_x, eye_y, fz + 0.02), Color.WHITE, true, Vector3(1.0, 1.15, 0.7))
		white.name = "EyeWhite"
		var look := Node3D.new()
		look.position = Vector3(side * eye_x, eye_y, fz)
		head.add_child(look)
		Mats.sphere(look, 0.038, Vector3(0, 0, -0.022), iris_col, false, Vector3(1.0, 1.1, 0.45))
		Mats.sphere(look, 0.021, Vector3(0, 0, -0.035), Color(0.05, 0.03, 0.03), false, Vector3(1.0, 1.1, 0.45))
		Mats.sphere(look, 0.009, Vector3(0.012, 0.014, -0.042), Color.WHITE, false)
		var lid := Mats.sphere(head, 0.073, Vector3(side * eye_x, eye_y + 0.004, fz + 0.018), skin.darkened(0.08), false, Vector3(1.05, 1.2, 0.75))
		lid.scale = Vector3(1.05, 0.2, 0.78)
		lid.position.y = eye_y + 0.07
		var brow := Node3D.new()
		brow.position = Vector3(side * eye_x, eye_y + 0.1, fz - 0.005)
		head.add_child(brow)
		var brow_thick := 0.02
		match p.body:
			CustomerProfile.Body.VALENTAO, CustomerProfile.Body.TIOZAO:
				brow_thick = 0.026
			CustomerProfile.Body.FOFOQUEIRA:
				brow_thick = 0.012
		var bm := Mats.capsule(brow, brow_thick, 0.12, Vector3.ZERO, p.hair_color, false)
		bm.rotation.z = PI / 2.0
		if p.body == CustomerProfile.Body.FOFOQUEIRA:
			# cílios
			for k in 3:
				var lash := Mats.box(head, Vector3(0.006, 0.03, 0.006), Vector3(side * (eye_x + 0.035 + k * 0.012), eye_y + 0.05 - k * 0.012, fz - 0.005), Color(0.08, 0.05, 0.05), false)
				lash.rotation.z = side * (-0.6 - k * 0.3)
		if side < 0:
			pupil_l = look
			lid_l = lid
			brow_l = brow
		else:
			pupil_r = look
			lid_r = lid
			brow_r = brow
	# nariz (fica vermelho com a bebida)
	var nose_scale := Vector3(1.0, 0.85, 1.0)
	var nose_r := 0.055
	match p.body:
		CustomerProfile.Body.FALANTE:
			nose_scale = Vector3(0.8, 1.0, 1.5)
		CustomerProfile.Body.TIOZAO:
			nose_r = 0.068
		CustomerProfile.Body.FOFOQUEIRA:
			nose_r = 0.04
		CustomerProfile.Body.VALENTAO:
			nose_scale = Vector3(1.2, 0.8, 0.9)
	var nose := Mats.sphere(head, nose_r, Vector3(0, fy - 0.02, fz - 0.06), skin, true, nose_scale)
	nose.material_override = nose_mat
	# bochechas coradas
	for side in [-1.0, 1.0]:
		var cheek := Mats.sphere(head, 0.05, Vector3(side * 0.15 * hs.x, fy - 0.05, fz + 0.03), Color.WHITE, false, Vector3(1.0, 0.6, 0.3))
		cheek.material_override = cheek_mat
		cheek.set_meta("no_highlight", true)
	# boca: interior escuro + dentes + língua (a língua escala junto quando abre)
	mouth = Node3D.new()
	mouth.position = Vector3(0, fy - 0.11, fz + 0.01)
	head.add_child(mouth)
	mouth_mesh = Mats.sphere(mouth, 0.05, Vector3.ZERO, Color(0.35, 0.08, 0.1), false, Vector3(1.4, 0.35, 0.5))
	Mats.sphere(mouth_mesh, 0.032, Vector3(0, -0.022, -0.01), Color(0.9, 0.4, 0.45), false)
	Mats.box(mouth, Vector3(0.07, 0.012, 0.02), Vector3(0, 0.012, -0.012), Color.WHITE, false)
	if p.body == CustomerProfile.Body.FOFOQUEIRA:
		mouth_mesh.material_override = Mats.toon(Color(0.85, 0.1, 0.25), false)
	_build_hair(p, r, hs, fy, fz)


func _build_hair(p: CustomerProfile, r: float, hs: Vector3, fy: float, fz: float) -> void:
	var hair := p.hair_color
	match p.body:
		CustomerProfile.Body.TIOZAO:
			# careca brilhante com coroinha de cabelo, bigodão, caneta atrás da orelha e palito
			Mats.torus(head, r * 0.82, r * 1.02, Vector3(0, r * 0.95, 0.03), hair, true).rotation_degrees.x = 12
			Mats.sphere(head, 0.04, Vector3(-0.07, r * 1.85, -0.08), Color(1, 1, 1), false, Vector3(1.6, 0.5, 1.0)).set_meta("no_highlight", true)
			var stache := Mats.capsule(head, 0.04, 0.22, Vector3(0, fy - 0.075, fz - 0.035), hair)
			stache.rotation_degrees.z = 90
			for side in [-1.0, 1.0]:
				Mats.sphere(head, 0.035, Vector3(side * 0.1, fy - 0.09, fz - 0.02), hair, false)
			var pen := Mats.cylinder(head, 0.008, 0.12, Vector3(r * hs.x * 0.95, fy + 0.07, 0.02), Color(0.15, 0.3, 0.8), false)
			pen.rotation = Vector3(0.0, 0.0, 1.2)
			var pick := Mats.cylinder(head, 0.003, 0.07, Vector3(0.04, fy - 0.12, fz - 0.02), Color(0.9, 0.8, 0.55), false)
			pick.rotation = Vector3(1.4, 0, 1.0)
			# rugas da testa
			for i in 2:
				Mats.box(head, Vector3(0.12, 0.004, 0.004), Vector3(0, fy + 0.19 + i * 0.03, fz + 0.035 + i * 0.012), skin.darkened(0.25), false)
		CustomerProfile.Body.VALENTAO:
			# cabelo raspado + monocelha + boné pra trás + cicatriz + barba por fazer
			Mats.sphere(head, r * 1.01, Vector3(0, r * 1.06, 0.01), hair, false, Vector3(hs.x, hs.y * 0.75, hs.z))
			hat = Node3D.new()
			hat.name = "Cap"
			head.add_child(hat)
			var cap_col := Color(0.85, 0.15, 0.15) if _rng.randf() < 0.6 else Color(0.15, 0.4, 0.85)
			Mats.sphere(hat, r * 1.04, Vector3(0, r * 1.18, 0.02), cap_col, true, Vector3(hs.x, 0.55, hs.z))
			Mats.box(hat, Vector3(0.22, 0.02, 0.16), Vector3(0, r * 1.3, r * 0.95), cap_col)
			Mats.cylinder(hat, 0.012, 0.01, Vector3(0, r * 1.73, 0.02), cap_col.darkened(0.3), false)
			Mats.capsule(head, 0.03, 0.27, Vector3(0, fy + 0.155, fz - 0.005), hair).rotation_degrees.z = 90
			Mats.sphere(head, r * 0.75, Vector3(0, fy - 0.1, fz * 0.55), skin.darkened(0.3), false, Vector3(1.0, 0.6, 0.7))
			var scar := Mats.box(head, Vector3(0.006, 0.07, 0.006), Vector3(0.14, fy + 0.0, fz + 0.04), Color(0.75, 0.35, 0.35), false)
			scar.rotation.z = 0.4
			# brinco de argola
			Mats.torus(head, 0.012, 0.018, Vector3(-r * hs.x, fy - 0.06, 0), Color(1.0, 0.82, 0.2)).rotation_degrees.z = 90
		CustomerProfile.Body.FALANTE:
			# topete alto + óculos de aro grosso com lentes + costeletas
			Mats.sphere(head, r * 0.95, Vector3(0, r * 1.35, -0.02), hair, true, Vector3(1.0, 0.7, 1.05))
			Mats.sphere(head, r * 0.5, Vector3(0, r * 1.75, -r * 0.4), hair, true, Vector3(1.1, 0.9, 1.3))
			for side in [-1.0, 1.0]:
				Mats.box(head, Vector3(0.03, 0.1, 0.05), Vector3(side * r * hs.x * 0.92, fy + 0.02, -0.06), hair, false)
				var lens := Mats.torus(head, 0.06, 0.075, Vector3(side * 0.085 * hs.x, fy + 0.06, fz - 0.045), Color(0.1, 0.1, 0.1))
				lens.rotation_degrees.x = 90
				var glass := Mats.cylinder(head, 0.062, 0.004, Vector3(side * 0.085 * hs.x, fy + 0.06, fz - 0.047), Color(0.8, 0.9, 1.0), false)
				glass.material_override = Mats.glass(Color(0.8, 0.9, 1.0), 0.25)
				glass.rotation_degrees.x = 90
				glass.set_meta("no_highlight", true)
			Mats.box(head, Vector3(0.05, 0.012, 0.012), Vector3(0, fy + 0.06, fz - 0.05), Color(0.1, 0.1, 0.1), false)
		CustomerProfile.Body.FOFOQUEIRA:
			# cabelão armado com bobes, brincos de argola e pinta charmosa
			for i in 16:
				var a := i * TAU / 16.0
				if sin(a) < -0.55:
					continue # deixa a testa (e os olhos) de fora
				var y := r * 1.0 + sin(a * 2.0) * 0.06 + 0.12
				Mats.sphere(head, 0.11, Vector3(cos(a) * r * 1.0, y, sin(a) * r * 0.95 + 0.04), hair, true)
			Mats.sphere(head, r * 0.9, Vector3(0, r * 1.45, 0.03), hair, true)
			var roller_cols := [Color(1.0, 0.55, 0.7), Color(0.45, 0.75, 1.0), Color(1.0, 0.85, 0.3)]
			for i in 5:
				var roller := Mats.cylinder(head, 0.035, 0.11, Vector3(-0.16 + i * 0.08, r * 1.95 - absf(i - 2) * 0.03, 0.04 + absf(i - 2) * 0.03), roller_cols[i % 3], false)
				roller.rotation.z = PI / 2.0
			for side in [-1.0, 1.0]:
				Mats.torus(head, 0.03, 0.045, Vector3(side * r * 1.0, fy - 0.11, -0.01), Color(1.0, 0.8, 0.2)).rotation_degrees.z = 90
			Mats.sphere(head, 0.008, Vector3(0.08, fy - 0.1, fz + 0.0), Color(0.15, 0.08, 0.05), false)
		CustomerProfile.Body.UNIVERSITARIO:
			# touca, cavanhaque, olheiras e fones no pescoço
			hat = Node3D.new()
			hat.name = "Beanie"
			head.add_child(hat)
			var beanie: Color = [Color(0.85, 0.2, 0.2), Color(0.95, 0.75, 0.15), Color(0.2, 0.55, 0.35)][_rng.randi_range(0, 2)]
			Mats.sphere(hat, r * 1.04, Vector3(0, r * 1.68, 0.03), beanie, true, Vector3(hs.x, 0.58, hs.z))
			Mats.cylinder(hat, r * 1.0, 0.06, Vector3(0, r * 1.76, 0.03), beanie.darkened(0.15), false)
			Mats.sphere(hat, 0.05, Vector3(0, r * 2.28, 0.03), Color(1, 1, 1), true)
			for side in [-1.0, 1.0]:
				Mats.box(head, Vector3(0.03, 0.12, 0.08), Vector3(side * r * hs.x * 0.94, fy + 0.04, -0.03), hair, false)
				Mats.sphere(head, 0.035, Vector3(side * eye_x_for(hs), fy + 0.02, fz + 0.035), skin.darkened(0.2), false, Vector3(1.0, 0.4, 0.4))
			Mats.sphere(head, 0.035, Vector3(0, fy - 0.17, fz + 0.02), hair, false, Vector3(1.0, 1.3, 0.8))
			Mats.torus(torso, 0.09, 0.11, Vector3(0, 0.6, 0.0), Color(0.15, 0.15, 0.18))
			for side in [-1.0, 1.0]:
				Mats.cylinder(torso, 0.04, 0.03, Vector3(side * 0.1, 0.6, -0.04), Color(0.15, 0.15, 0.18), false).rotation.z = PI / 2.0
		CustomerProfile.Body.MALANDRO:
			# chapéu panamá, bigodinho fino e cabelo na régua
			Mats.sphere(head, r * 1.01, Vector3(0, r * 1.06, 0.01), hair, false, Vector3(hs.x, hs.y * 0.72, hs.z))
			hat = Node3D.new()
			hat.name = "Panama"
			hat.position = Vector3(0, r * 1.55, 0.0)
			head.add_child(hat)
			var straw := Color(0.97, 0.94, 0.85)
			Mats.cylinder(hat, r * 1.45, 0.02, Vector3.ZERO, straw, true)
			Mats.cylinder(hat, r * 0.85, 0.16, Vector3(0, 0.08, 0), straw, true, r * 0.75)
			Mats.cylinder(hat, r * 0.86, 0.04, Vector3(0, 0.03, 0), Color(0.1, 0.08, 0.08), false)
			hat.rotation.z = 0.12
			var stache := Mats.capsule(head, 0.012, 0.13, Vector3(0, fy - 0.075, fz - 0.03), hair, false)
			stache.rotation_degrees.z = 90
			var pick := Mats.cylinder(head, 0.003, 0.08, Vector3(-0.04, fy - 0.12, fz - 0.02), Color(0.9, 0.8, 0.55), false)
			pick.rotation = Vector3(1.4, 0, -1.0)
			Mats.sphere(head, 0.012, Vector3(0.02, fy - 0.105, fz - 0.025), Color(1.0, 0.85, 0.2), false)


func eye_x_for(hs: Vector3) -> float:
	return 0.085 * hs.x


# ------------------------------------------------------------------ expressão

## Aplica as cores e a "cara" da embriaguez (0..1).
func apply_drunk_look(f: float, flush: float) -> void:
	cheek_mat.albedo_color.a = clampf(f * 0.9 + flush * 0.5, 0.0, 0.85)
	nose_mat.albedo_color = _base_skin.lerp(Color(0.95, 0.25, 0.25), clampf(f * 1.1, 0.0, 1.0))
	face_mat.albedo_color = _base_skin.lerp(Color(0.9, 0.3, 0.25), clampf(flush * 0.6, 0.0, 0.6))
	skin_flat_mat.albedo_color = face_mat.albedo_color


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
	pupil_l.position.x = -_eye_x + offset.x * 0.022
	pupil_r.position.x = _eye_x + offset.y * 0.022
