class_name CustomerRig
extends Node3D
## Boneco cartunesco montado com primitivas: tronco torneado (quadril, cintura, peito e
## ombros), braços com cotovelo, pernas com joelho, mãos com quatro dedos dobrados e dedão,
## rosto com cílios, pálpebras, nariz com narinas, lábios, dentes e língua, roupas com
## barras, bolsos e costuras, calçados próprios e acessórios de cada tipo.
## Cada freguês sorteia tom de pele, roupa, olhos e proporções.
## Frente do boneco = -Z local. Origem = chão.

const HIP_Y := 0.85
const THIGH := 0.42
const SKIN_TONES := [Color(0.98, 0.8, 0.66), Color(0.93, 0.72, 0.56), Color(0.8, 0.56, 0.4),
	Color(0.66, 0.44, 0.3), Color(0.5, 0.33, 0.22), Color(0.38, 0.25, 0.17)]
const IRIS_COLORS := [Color(0.35, 0.22, 0.12), Color(0.2, 0.45, 0.25), Color(0.25, 0.45, 0.75), Color(0.45, 0.3, 0.15)]
const SHOE := Color(0.15, 0.1, 0.08)
const INK := Color(0.1, 0.06, 0.05)
const GOLD := Color(1.0, 0.8, 0.2)

enum Shoe { SNEAKER, DRESS, BOOT, FLIPFLOP, HEEL }

var profile: CustomerProfile
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var hand_l: Node3D
var hand_r: Node3D
var belly: MeshInstance3D
var mouth: Node3D
var mouth_mesh: MeshInstance3D
var lip_low: Node3D
var lip_low_l: Node3D
var lip_low_r: Node3D
## Metades do lábio de cima, presas no centro da boca (giram para sorrir ou fechar a cara).
var lip_up_l: Node3D
var lip_up_r: Node3D
## Pálpebras de baixo (sobem no sorriso e na cara de bravo) e maçãs do rosto do sorriso.
var lower_lid_l: MeshInstance3D
var lower_lid_r: MeshInstance3D
var apple_l: MeshInstance3D
var apple_r: MeshInstance3D
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
## Partes pequenas do nariz (asas, ponte), sem contorno: também avermelham.
var nose_flat_mat: StandardMaterial3D
var face_mat: StandardMaterial3D
## Mesma pele, sem contorno (peças pequenas: dedos, dedões do pé, queixo, colo).
var skin_flat_mat: StandardMaterial3D
var skin: Color
var shirt: Color
var _base_skin: Color
var _eye_y := 0.0
var _eye_x := 0.0
var _mouth_y := 0.0
# expressão atual (0..1 cada): feliz, bravo, bêbado
var _x_happy := 0.0
var _x_angry := 0.0
var _x_drunk := 0.0
var _rng := RandomNumberGenerator.new()
# forma do tronco (para colar bolsos, botões e estampas na superfície)
var _torso_prof := PackedVector2Array()
var _bw := 1.0
var _depth := 1.0


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
	nose_flat_mat = Mats.toon(skin.darkened(0.04), false).duplicate()
	cheek_mat = StandardMaterial3D.new()
	cheek_mat.albedo_color = Color(1.0, 0.3, 0.35, 0.0)
	cheek_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cheek_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var body_w := 1.0
	var body_depth := 1.0
	var height := 1.0
	match p.body:
		CustomerProfile.Body.VALENTAO:
			body_w = 1.3
			height = 1.05
		CustomerProfile.Body.FALANTE:
			body_w = 0.85
			body_depth = 0.85
			height = 1.08
		CustomerProfile.Body.FOFOQUEIRA:
			body_w = 0.95
			height = 0.95
		CustomerProfile.Body.UNIVERSITARIO:
			body_w = 0.85
			body_depth = 0.9
			height = 1.06
		CustomerProfile.Body.MALANDRO:
			body_w = 0.95
			height = 1.02
	# cada freguês é um pouquinho diferente
	body_w *= _rng.randf_range(0.94, 1.06)
	height *= _rng.randf_range(0.96, 1.04)

	leg_l = _leg(-0.11 * body_w, p, false)
	leg_r = _leg(0.11 * body_w, p, true)
	knee_l = leg_l.get_node("Knee")
	knee_r = leg_r.get_node("Knee")

	torso = Node3D.new()
	torso.name = "Torso"
	torso.position.y = HIP_Y
	add_child(torso)
	_build_torso(p, body_w, body_depth, height)

	var sleeve := _sleeve_kind(p)
	arm_l = _arm(-0.26 * body_w, 0.52 * height, sleeve, false)
	arm_r = _arm(0.26 * body_w, 0.52 * height, sleeve, true)
	fore_l = arm_l.get_node("Fore")
	fore_r = arm_r.get_node("Fore")
	hand_l = fore_l.get_node("Hand")
	hand_r = fore_r.get_node("Hand")
	_arm_extras(p)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = 0.62 * height
	torso.add_child(head)
	# pescoço (com a sombrinha do queixo)
	var neck_r := 0.075 * (1.3 if p.body == CustomerProfile.Body.VALENTAO else 1.0)
	_skin(Mats.cylinder(torso, neck_r, 0.14, Vector3(0, 0.6 * height, 0.005), skin), true)
	Mats.cylinder(torso, neck_r * 0.98, 0.02, Vector3(0, 0.655 * height, 0.0), skin.darkened(0.18), false)
	_build_head(p)
	_merge_parts()


## Menos draw calls: junta as peças estáticas de cada osso.
func _merge_parts() -> void:
	if belly:
		belly.set_meta("dynamic", true)
	for n: MeshInstance3D in [lid_l, lid_r, lower_lid_l, lower_lid_r, apple_l, apple_r]:
		n.set_meta("dynamic", true)
	var bones: Array[Node3D] = [torso, head, arm_l, arm_r, fore_l, fore_r, hand_r, hand_l,
		leg_l, leg_r, knee_l, knee_r, brow_l, brow_r]
	if hat:
		bones.append(hat)
	if prop:
		bones.append(prop)
	for bone in bones:
		Mats.merge_children(bone)


## Onde fica o copo/salgado segurado (no lado da palma, em coordenadas da mão).
func hold_offset(right := true) -> Vector3:
	return Vector3((-0.075 if right else 0.075), -0.11, 0.0)


# ------------------------------------------------------------------ helpers

func _skin(mi: MeshInstance3D, outlined := false) -> MeshInstance3D:
	mi.material_override = face_mat if outlined else skin_flat_mat
	return mi


func _limb(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color, outline := false) -> MeshInstance3D:
	return Mats.limb(parent, a, b, radius, color, outline)


## Calota (cabelo, boné, touca): pedaço de esfera de `from_deg` (abaixo do equador) até o topo.
func _dome(parent: Node3D, pos: Vector3, radius: float, scl: Vector3, from_deg: float, color: Color, outline := true) -> MeshInstance3D:
	var prof := PackedVector2Array()
	var steps := 8
	for i in steps + 1:
		var a := deg_to_rad(lerpf(from_deg, 90.0, float(i) / steps))
		prof.append(Vector2(cos(a), sin(a)) * radius)
	prof[steps] = Vector2(0.0, radius)
	var mi := MeshInstance3D.new()
	mi.mesh = BeverageModels.lathe(prof, 20)
	mi.material_override = Mats.toon(color, outline)
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


## Raio do tronco na altura y (perfil torneado).
func _radius_at(y: float) -> float:
	var prof := _torso_prof
	for i in range(1, prof.size()):
		if prof[i].y >= y:
			var a := prof[i - 1]
			var b := prof[i]
			if b.y - a.y < 0.0001:
				return b.x
			return lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
	return prof[prof.size() - 1].x


## Ponto na superfície da frente (z < 0) ou das costas (back = true) do tronco.
func _surf(x: float, y: float, out := 0.004, back := false) -> Vector3:
	var rx := _radius_at(y) * _bw
	var k := clampf(x / maxf(rx, 0.001), -0.98, 0.98)
	var z := _radius_at(y) * _depth * sqrt(1.0 - k * k) + out
	return Vector3(x, y, z if back else -z)


# ------------------------------------------------------------------ corpo

func _build_torso(p: CustomerProfile, bw: float, bd: float, h: float) -> void:
	var chest_k := 1.0
	var waist_k := 0.92
	var hip_k := 1.0
	var sh_k := 1.0
	match p.body:
		CustomerProfile.Body.TIOZAO:
			waist_k = 1.08
			chest_k = 1.04
		CustomerProfile.Body.VALENTAO:
			waist_k = 0.84
			chest_k = 1.12
			sh_k = 1.12
		CustomerProfile.Body.FOFOQUEIRA:
			waist_k = 0.8
			hip_k = 1.1
			chest_k = 1.04
		CustomerProfile.Body.UNIVERSITARIO:
			waist_k = 1.0
	_bw = bw
	_depth = 0.85 * bd
	var r0 := 0.206 * maxf(hip_k, waist_k)
	_torso_prof = PackedVector2Array([Vector2(0.0, 0.05), Vector2(r0, 0.05), Vector2(r0 + 0.002, 0.08),
		Vector2(0.19 * waist_k, 0.17 * h), Vector2(0.2 * chest_k, 0.29 * h), Vector2(0.208 * chest_k, 0.38 * h),
		Vector2(0.2 * sh_k, 0.46 * h), Vector2(0.17 * sh_k, 0.52 * h), Vector2(0.12, 0.57 * h),
		Vector2(0.075, 0.6 * h), Vector2(0.0, 0.61 * h)])
	var scl := Vector3(bw, 1.0, _depth)
	# quadril (calça) + camisa torneada por cima
	var pelvis := MeshInstance3D.new()
	pelvis.mesh = BeverageModels.lathe(PackedVector2Array([Vector2(0.0, -0.06), Vector2(0.17 * hip_k, -0.06),
		Vector2(0.198 * hip_k, -0.01), Vector2(0.2 * hip_k, 0.06), Vector2(0.196 * hip_k, 0.11), Vector2(0.0, 0.11)]), 18)
	pelvis.material_override = Mats.toon(p.pants_color)
	pelvis.scale = scl
	torso.add_child(pelvis)
	var body := MeshInstance3D.new()
	body.mesh = BeverageModels.lathe(_torso_prof, 14 if GameManager.low_end else 18)
	body.material_override = Mats.toon(shirt)
	body.scale = scl
	torso.add_child(body)
	# barra da camisa + cinto com fivela (o moletom e a blusa cobrem o cinto)
	var hem := Mats.cylinder(torso, r0 + 0.004, 0.025, Vector3(0, 0.06, 0), shirt.darkened(0.15), false)
	hem.scale = scl
	if p.body != CustomerProfile.Body.UNIVERSITARIO and p.body != CustomerProfile.Body.FOFOQUEIRA:
		var belt := Mats.cylinder(torso, 0.2 * hip_k + 0.004, 0.035, Vector3(0, 0.035, 0), Color(0.25, 0.15, 0.08), false)
		belt.scale = scl
		Mats.box(torso, Vector3(0.05, 0.04, 0.012), Vector3(0, 0.035, -0.2 * hip_k * _depth - 0.008), GOLD, false)
		Mats.box(torso, Vector3(0.03, 0.022, 0.014), Vector3(0, 0.035, -0.2 * hip_k * _depth - 0.009), Color(0.25, 0.15, 0.08), false)
	# bolsos de trás
	for side: float in [-1.0, 1.0]:
		var bp := Mats.box(torso, Vector3(0.08, 0.075, 0.01), Vector3(side * 0.09 * bw, -0.01, 0.2 * hip_k * _depth), p.pants_color.darkened(0.15), false)
		bp.rotation.y = side * 0.35
	match p.body:
		CustomerProfile.Body.TIOZAO:
			_torso_tiozao(h)
		CustomerProfile.Body.VALENTAO:
			_torso_valentao(h)
		CustomerProfile.Body.FALANTE:
			_torso_falante(h)
		CustomerProfile.Body.FOFOQUEIRA:
			_torso_fofoqueira(h)
		CustomerProfile.Body.UNIVERSITARIO:
			_torso_universitario(h)
		CustomerProfile.Body.MALANDRO:
			_torso_malandro(h)


func _torso_tiozao(h: float) -> void:
	# regata: alças, decote com pelinho, barrigão (anima na risada), cordão com medalha
	belly = Mats.sphere(torso, 0.25, Vector3(0, 0.2, -0.1), shirt, true, Vector3(1.0, 0.9, 0.95))
	# mancha de molho na regata (é o Tiozão, né)
	Mats.sphere(belly, 0.035, Vector3(0.09, 0.08, -0.222), Color(0.75, 0.45, 0.2), false, Vector3(1.2, 0.9, 0.25))
	Mats.sphere(belly, 0.016, Vector3(0.13, 0.05, -0.21), Color(0.75, 0.45, 0.2), false, Vector3(1, 1, 0.3))
	var neck_y := 0.5 * h
	_skin(Mats.sphere(torso, 0.11, _surf(0, neck_y, -0.04), skin, false, Vector3(1.3, 0.75, 0.45)))
	for i in 7:
		var a := i * 2.4
		Mats.sphere(torso, 0.011, _surf(cos(a) * 0.04, neck_y - 0.02 + sin(a) * 0.025, 0.012), profile.hair_color.darkened(0.2), false)
	for side: float in [-1.0, 1.0]:
		var x := side * 0.11 * _bw
		var f := _surf(x, 0.45 * h, 0.006)
		var b := _surf(x, 0.45 * h, 0.006, true)
		_limb(torso, f, Vector3(x * 0.95, 0.585 * h, 0.0), 0.024, shirt)
		_limb(torso, Vector3(x * 0.95, 0.585 * h, 0.0), b, 0.024, shirt)
		# ombro de fora
		_skin(Mats.sphere(torso, 0.095, Vector3(side * 0.19 * _bw, 0.5 * h, 0), skin, false, Vector3(1, 0.85, 1)), true)
	# cordão com medalhinha
	_chain(0.55 * h, 0.09, 0.1, 0.012)
	var medal := Mats.cylinder(torso, 0.028, 0.008, _surf(0, 0.43 * h, 0.03), GOLD, false)
	medal.rotation.x = PI / 2.0
	# carteira no bolso de trás
	Mats.box(torso, Vector3(0.09, 0.06, 0.025), Vector3(0.09 * _bw, -0.01, 0.2 * _depth + 0.01), Color(0.35, 0.2, 0.1), false)


func _torso_valentao(h: float) -> void:
	# regata justa: peitoral, trapézio, ombros de academia e corrente grossa
	for side: float in [-1.0, 1.0]:
		_skin(Mats.sphere(torso, 0.15, Vector3(side * 0.18 * _bw, 0.5 * h, -0.01), skin, true, Vector3(1.1, 0.75, 0.95)), true)
		_skin(Mats.sphere(torso, 0.08, Vector3(side * 0.09, 0.57 * h, 0.02), skin, false, Vector3(1.3, 0.7, 1.0)))
		Mats.sphere(torso, 0.13, _surf(side * 0.085 * _bw, 0.4 * h, -0.05), shirt, false, Vector3(1.1, 0.7, 0.5))
	# decote cavado
	_skin(Mats.sphere(torso, 0.08, _surf(0, 0.52 * h, -0.045), skin, false, Vector3(1.1, 0.9, 0.4)))
	# "tanquinho" marcado na regata
	for i in 3:
		Mats.box(torso, Vector3(0.09 * _bw, 0.006, 0.006), _surf(0, (0.17 + i * 0.06) * h, 0.0), shirt.darkened(0.3), false)
	Mats.box(torso, Vector3(0.006, 0.18 * h, 0.006), _surf(0, 0.23 * h, 0.0), shirt.darkened(0.3), false)
	_chain(0.56 * h, 0.13, 0.12, 0.02)
	Mats.box(torso, Vector3(0.05, 0.06, 0.015), _surf(0, 0.42 * h, 0.03), GOLD, false)


func _torso_falante(h: float) -> void:
	# camisa havaiana: gola, carcela com botões, bolso com caneta, flores e folhas
	_collar(h, shirt.lightened(0.15))
	_skin(Mats.sphere(torso, 0.06, _surf(0, 0.55 * h, -0.035), skin, false, Vector3(1, 1.1, 0.5)))
	Mats.box(torso, Vector3(0.035, 0.42 * h, 0.006), _surf(0, 0.3 * h, 0.001), shirt.darkened(0.1), false)
	for i in 5:
		Mats.sphere(torso, 0.011, _surf(0, (0.48 - i * 0.085) * h, 0.006), Color(0.95, 0.95, 0.9), false)
	var pocket := _surf(-0.09 * _bw, 0.4 * h, 0.003)
	Mats.box(torso, Vector3(0.075, 0.08, 0.008), pocket, shirt.darkened(0.12), false)
	Mats.box(torso, Vector3(0.075, 0.012, 0.01), pocket + Vector3(0, 0.035, -0.002), shirt.darkened(0.25), false)
	Mats.cylinder(torso, 0.007, 0.08, pocket + Vector3(0.02, 0.035, -0.004), Color(0.15, 0.3, 0.8), false)
	var petal := Color(1.0, 0.92, 0.35) if shirt.get_luminance() < 0.6 else Color(0.9, 0.2, 0.3)
	var leaf := Color(0.12, 0.45, 0.2)
	for i in 7:
		var a := i * 2.1
		var p := _surf(cos(a) * 0.15 * _bw, (0.13 + (i % 4) * 0.1) * h, 0.004)
		if absf(p.x) < 0.035:
			p.x += 0.07
			p = _surf(p.x, p.y, 0.004)
		_flower(p, 0.024, petal, leaf, a)


func _flower(p: Vector3, s: float, petal: Color, leaf: Color, a: float) -> void:
	var l := Mats.sphere(torso, s * 0.9, p + Vector3(cos(a) * s * 1.3, sin(a) * s * 1.3, 0.003), leaf, false, Vector3(1.6, 0.6, 0.3))
	l.rotation.z = a
	for k in 5:
		var b := a + k * TAU / 5.0
		Mats.sphere(torso, s * 0.6, p + Vector3(cos(b) * s * 0.75, sin(b) * s * 0.75, -0.002), petal, false, Vector3(1, 1, 0.35))
	Mats.sphere(torso, s * 0.35, p + Vector3(0, 0, -0.006), Color(0.95, 0.5, 0.1), false)


func _torso_fofoqueira(h: float) -> void:
	# blusa com babado, mangas bufantes, pérolas, cós da saia e bolsa no ombro
	_skin(Mats.sphere(torso, 0.08, _surf(0, 0.53 * h, -0.04), skin, false, Vector3(1.3, 0.9, 0.45)))
	for i in 9:
		var a := lerpf(-1.1, 1.1, i / 8.0)
		Mats.sphere(torso, 0.032, _surf(sin(a) * 0.15, 0.53 * h - cos(a) * 0.05, 0.004), shirt.lightened(0.3), false, Vector3(1, 0.8, 0.6))
	for i in 13:
		var a := lerpf(-1.1, 1.1, i / 12.0)
		Mats.sphere(torso, 0.016, _surf(sin(a) * 0.11, 0.535 * h - cos(a) * 0.06, 0.012), Color(1, 0.98, 0.92), false)
	# cós da saia (junta as duas "pernas" da saia)
	var skirt := profile.pants_color
	var waist := Mats.cylinder(torso, 0.205 * 1.1, 0.12, Vector3(0, 0.02, 0), skirt, true, 0.2)
	waist.scale = Vector3(_bw, 1, _depth)
	var band := Mats.cylinder(torso, _radius_at(0.1) + 0.004, 0.03, Vector3(0, 0.1, 0), skirt.darkened(0.2), false)
	band.scale = Vector3(_bw, 1, _depth)
	# bolsa de alça com fecho
	var bag_col := Color(0.85, 0.65, 0.2)
	var bag := Mats.box(torso, Vector3(0.18, 0.13, 0.07), Vector3(0.26 * _bw, 0.12, 0.05), bag_col)
	bag.rotation.z = 0.1
	Mats.box(torso, Vector3(0.185, 0.05, 0.074), Vector3(0.262 * _bw, 0.17, 0.05), bag_col.darkened(0.2), false).rotation.z = 0.1
	Mats.sphere(torso, 0.012, Vector3(0.262 * _bw, 0.15, 0.012), GOLD, false)
	_limb(torso, Vector3(0.2 * _bw, 0.18, 0.05), Vector3(0.17 * _bw, 0.52 * h, 0.02), 0.012, bag_col.darkened(0.3))


func _torso_universitario(h: float) -> void:
	# moletom: capuz embolado, cordinhas, bolso canguru, punho/barra canelados e mochila
	Mats.torus(torso, 0.1, 0.17, Vector3(0, 0.57 * h, 0.07), shirt.darkened(0.1), true).rotation_degrees.x = -25
	Mats.sphere(torso, 0.12, Vector3(0, 0.55 * h, 0.15), shirt.darkened(0.15), false, Vector3(1.3, 0.8, 0.6))
	for side: float in [-1.0, 1.0]:
		var top := _surf(side * 0.035, 0.53 * h, 0.01)
		var bot := _surf(side * 0.04, 0.4 * h, 0.012)
		_limb(torso, top, bot, 0.006, Color(0.95, 0.95, 0.95))
		Mats.sphere(torso, 0.013, bot + Vector3(0, -0.01, 0), Color(0.95, 0.95, 0.95), false)
	var pk := _surf(0, 0.17 * h, 0.002)
	Mats.box(torso, Vector3(0.24 * _bw, 0.11, 0.012), pk, shirt.darkened(0.12), false)
	for side: float in [-1.0, 1.0]:
		var e := Mats.box(torso, Vector3(0.012, 0.11, 0.016), pk + Vector3(side * 0.12 * _bw, 0, -0.002), shirt.darkened(0.25), false)
		e.rotation.z = side * 0.3
	Mats.label3d(torso, "UFPZ", _surf(0, 0.37 * h, 0.012), 40, Color(1, 1, 1), 0).rotation.y = PI
	# mochila: corpo, bolso da frente com zíper e alças por cima dos ombros
	var pack_col: Color = [Color(0.2, 0.3, 0.55), Color(0.15, 0.15, 0.17), Color(0.7, 0.25, 0.2)][_rng.randi_range(0, 2)]
	var pack := Mats.box(torso, Vector3(0.3 * _bw, 0.36, 0.15), Vector3(0, 0.33 * h, 0.23), pack_col)
	pack.name = "Backpack"
	Mats.box(torso, Vector3(0.22 * _bw, 0.14, 0.05), Vector3(0, 0.24 * h, 0.32), pack_col.lightened(0.08), false)
	Mats.box(torso, Vector3(0.2 * _bw, 0.008, 0.008), Vector3(0, 0.31 * h, 0.347), Color(0.75, 0.75, 0.78), false)
	Mats.box(torso, Vector3(0.02, 0.035, 0.01), Vector3(0.07, 0.3 * h, 0.35), Color(0.85, 0.85, 0.85), false)
	for side: float in [-1.0, 1.0]:
		var x := side * 0.1 * _bw
		_limb(torso, _surf(x, 0.2 * h, 0.012), _surf(x, 0.5 * h, 0.014), 0.018, pack_col.darkened(0.3))
		_limb(torso, _surf(x, 0.5 * h, 0.014), Vector3(x, 0.56 * h, 0.12), 0.018, pack_col.darkened(0.3))


func _torso_malandro(h: float) -> void:
	# camisa listrada, gola aberta, peito de fora com corrente e lenço no bolso
	for i in 6:
		var y := 0.15 + i * 0.075 * h
		var stripe := Mats.cylinder(torso, _radius_at(y - 0.0175) + 0.008, 0.035, Vector3(0, y, 0), Color(0.97, 0.97, 0.95), false, _radius_at(y + 0.0175) + 0.008)
		stripe.scale = Vector3(_bw, 1, _depth)
	_collar(h, Color(0.97, 0.97, 0.95))
	_skin(Mats.sphere(torso, 0.065, _surf(0, 0.53 * h, -0.035), skin, false, Vector3(1, 1.3, 0.5)))
	var pocket := _surf(-0.1 * _bw, 0.42 * h, 0.004)
	Mats.box(torso, Vector3(0.07, 0.07, 0.008), pocket, shirt.darkened(0.15), false)
	for k in 3:
		var tip := Mats.box(torso, Vector3(0.02, 0.035, 0.006), pocket + Vector3(-0.02 + k * 0.02, 0.04 + (k % 2) * 0.008, -0.004), Color(0.95, 0.85, 0.2), false)
		tip.rotation.z = (k - 1) * 0.4
	_chain(0.54 * h, 0.06, 0.09, 0.009)


func _chain(y: float, w: float, drop: float, link: float) -> void:
	for i in 11:
		var a := lerpf(-1.25, 1.25, i / 10.0)
		var yy := y - (1.0 - cos(a)) / (1.0 - cos(1.25)) * drop
		Mats.sphere(torso, link, _surf(sin(a) * w, yy, link * 0.8), GOLD, false)


func _collar(h: float, c: Color) -> void:
	for side: float in [-1.0, 1.0]:
		var p := _surf(side * 0.055 * _bw, 0.545 * h, 0.012)
		var col := Mats.box(torso, Vector3(0.09, 0.018, 0.075), p, c, false)
		col.rotation = Vector3(0.6, side * 0.5, side * -0.5)


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


# ------------------------------------------------------------------ pernas

func _leg(x: float, p: CustomerProfile, right: bool) -> Node3D:
	var side := 1.0 if right else -1.0
	var pivot := Node3D.new()
	pivot.position = Vector3(x, HIP_Y, 0)
	add_child(pivot)
	var knee := Node3D.new()
	knee.name = "Knee"
	knee.position = Vector3(0, -THIGH, 0)
	pivot.add_child(knee)
	var pants := p.pants_color
	match p.body:
		CustomerProfile.Body.TIOZAO:
			# bermuda larga com bolso de lado + canela de fora + chinelo
			Mats.cylinder(pivot, 0.108, 0.4, Vector3(0, -0.2, 0), pants, true, 0.1)
			Mats.cylinder(pivot, 0.11, 0.025, Vector3(0, -0.39, 0), pants.darkened(0.15), false)
			Mats.box(pivot, Vector3(0.012, 0.09, 0.08), Vector3(side * 0.106, -0.25, 0), pants.darkened(0.12), false)
			_skin(Mats.sphere(knee, 0.07, Vector3(0, 0.0, -0.005), skin), true)
			_skin(_limb(knee, Vector3(0, -0.02, 0), Vector3(0, -0.35, 0.0), 0.06, skin, true), true)
			for i in 4:
				Mats.sphere(knee, 0.008, Vector3(side * 0.03 - 0.02 + i * 0.012, -0.12 - i * 0.05, -0.058), profile.hair_color.darkened(0.3), false)
			_shoe(knee, Shoe.FLIPFLOP, Color(0.2, 0.55, 0.3))
		CustomerProfile.Body.FOFOQUEIRA:
			# saia rodada com bolinhas (acompanha a perna quando senta) + meia-calça + scarpin
			var skirt := Mats.cylinder(pivot, 0.17, 0.38, Vector3(0, -0.16, 0), pants, true, 0.13)
			skirt.name = "Skirt"
			Mats.cylinder(pivot, 0.172, 0.03, Vector3(0, -0.34, 0), pants.darkened(0.25), false)
			for i in 6:
				var a := i * 1.7 + side
				var yy := -0.07 - (i % 3) * 0.09
				var rr := lerpf(0.13, 0.17, (-yy - 0.0) / 0.36) + 0.003
				Mats.sphere(pivot, 0.016, Vector3(sin(a) * rr, yy, -cos(a) * rr), Color(1, 0.96, 0.9), false, Vector3(1, 1, 0.4)).rotation.y = -a
			var stocking := skin.darkened(0.15)
			Mats.sphere(knee, 0.062, Vector3.ZERO, stocking)
			_limb(knee, Vector3(0, -0.02, 0), Vector3(0, -0.35, 0), 0.055, stocking, true)
			_shoe(knee, Shoe.HEEL, Color(0.8, 0.12, 0.15))
		_:
			# calça comprida: coxa, joelho, canela, vinco na frente e barra
			_limb(pivot, Vector3(0, -0.02, 0), Vector3(0, -THIGH, 0), 0.09, pants, true)
			Mats.sphere(knee, 0.087, Vector3.ZERO, pants)
			Mats.cylinder(knee, 0.082, 0.36, Vector3(0, -0.2, 0), pants, true, 0.086)
			Mats.box(knee, Vector3(0.006, 0.3, 0.006), Vector3(0, -0.19, -0.084), pants.darkened(0.18), false)
			Mats.box(pivot, Vector3(0.006, 0.34, 0.006), Vector3(0, -0.22, -0.09), pants.darkened(0.18), false)
			# costura lateral
			Mats.box(pivot, Vector3(0.006, 0.36, 0.006), Vector3(side * 0.09, -0.22, 0), pants.darkened(0.25), false)
			Mats.cylinder(knee, 0.087, 0.03, Vector3(0, -0.36, 0), pants.darkened(0.12), false)
			match p.body:
				CustomerProfile.Body.VALENTAO:
					# calça cargo com bolsão + coturno
					Mats.box(pivot, Vector3(0.025, 0.11, 0.1), Vector3(side * 0.095, -0.25, 0), pants.darkened(0.1), false)
					Mats.box(pivot, Vector3(0.028, 0.03, 0.105), Vector3(side * 0.096, -0.2, 0), pants.darkened(0.2), false)
					_shoe(knee, Shoe.BOOT, Color(0.13, 0.1, 0.08))
				CustomerProfile.Body.UNIVERSITARIO:
					_shoe(knee, Shoe.SNEAKER, Color(0.95, 0.95, 0.95))
				CustomerProfile.Body.MALANDRO:
					_shoe(knee, Shoe.DRESS, Color(0.98, 0.98, 0.96))
				_:
					_shoe(knee, Shoe.DRESS, Color(0.35, 0.2, 0.1))
	return pivot


## Calçado preso no joelho. A sola fica em y = -(THIGH + 0.01) do joelho (no chão).
func _shoe(knee: Node3D, kind: Shoe, color: Color) -> void:
	var y := -0.39
	match kind:
		Shoe.FLIPFLOP:
			Mats.box(knee, Vector3(0.11, 0.02, 0.25), Vector3(0, -0.42, -0.05), color)
			Mats.box(knee, Vector3(0.112, 0.008, 0.252), Vector3(0, -0.428, -0.05), Color(0.95, 0.95, 0.9), false)
			var foot := Mats.capsule(knee, 0.045, 0.22, Vector3(0, -0.39, -0.05), skin, false)
			foot.basis = Mats.orient(Vector3(0, 0, -1))
			foot.scale = Vector3(1.0, 1.0, 0.7)
			_skin(foot)
			for i in 5:
				_skin(Mats.sphere(knee, 0.016 - absf(i - 1.5) * 0.0015, Vector3(-0.036 + i * 0.018, -0.395, -0.16 + absf(i - 1.0) * 0.006), skin, false))
			# tira em V
			for s: float in [-1.0, 1.0]:
				_limb(knee, Vector3(0, -0.375, -0.12), Vector3(s * 0.045, -0.405, -0.04), 0.008, Color(0.95, 0.95, 0.95))
		Shoe.HEEL:
			var body := Mats.capsule(knee, 0.045, 0.2, Vector3(0, y, -0.04), color)
			body.basis = Mats.orient(Vector3(0, -0.25, -1))
			body.scale = Vector3(1.0, 1.0, 0.7)
			Mats.cylinder(knee, 0.012, 0.05, Vector3(0, -0.405, 0.04), color.darkened(0.4), false, 0.016)
			_skin(Mats.sphere(knee, 0.04, Vector3(0, -0.37, -0.03), skin.darkened(0.15), false, Vector3(1, 0.5, 1.4)))
			Mats.sphere(knee, 0.012, Vector3(0, -0.375, -0.1), Color(1, 0.9, 0.5), false)
		Shoe.BOOT:
			Mats.cylinder(knee, 0.078, 0.14, Vector3(0, -0.3, 0), color, true, 0.082)
			var body := Mats.capsule(knee, 0.066, 0.25, Vector3(0, y, -0.05), color)
			body.basis = Mats.orient(Vector3(0, 0, -1))
			body.scale = Vector3(1.0, 1.0, 0.75)
			Mats.box(knee, Vector3(0.13, 0.03, 0.26), Vector3(0, -0.418, -0.05), Color(0.08, 0.06, 0.05), false)
			for i in 4:
				Mats.box(knee, Vector3(0.05, 0.006, 0.008), Vector3(0, -0.26 - i * 0.03, -0.082), Color(0.6, 0.5, 0.35), false)
		_:
			var dress := kind == Shoe.DRESS
			var body := Mats.capsule(knee, 0.062, 0.25, Vector3(0, y, -0.05), color)
			if dress:
				body.material_override = Mats.toon(color, true, 0.25)
			body.basis = Mats.orient(Vector3(0, 0, -1))
			body.scale = Vector3(1.0, 1.0, 0.72)
			var sole := Color(0.12, 0.1, 0.1) if dress else Color(0.95, 0.95, 0.95)
			Mats.box(knee, Vector3(0.124, 0.022, 0.25), Vector3(0, -0.418, -0.05), sole, false)
			if dress:
				if profile.body == CustomerProfile.Body.MALANDRO:
					# sapato bicolor: biqueira e calcanhar pretos
					Mats.sphere(knee, 0.064, Vector3(0, y, -0.13), Color(0.08, 0.06, 0.06), false, Vector3(1, 0.72, 0.9))
					Mats.sphere(knee, 0.062, Vector3(0, y, 0.025), Color(0.08, 0.06, 0.06), false, Vector3(1.01, 0.73, 0.6))
				Mats.sphere(knee, 0.015, Vector3(0.0, -0.35, -0.08), Color(1, 1, 1, 1), false).set_meta("no_highlight", true)
			else:
				# tênis: biqueira, cadarço e faixa lateral
				Mats.sphere(knee, 0.06, Vector3(0, -0.4, -0.13), Color(0.95, 0.95, 0.95), false, Vector3(1.04, 0.5, 0.9))
				for i in 3:
					Mats.box(knee, Vector3(0.06, 0.008, 0.012), Vector3(0, -0.345 - i * 0.006, -0.03 - i * 0.03), Color(0.2, 0.2, 0.25), false)
				for s: float in [-1.0, 1.0]:
					var stripe := Mats.box(knee, Vector3(0.006, 0.02, 0.1), Vector3(s * 0.063, -0.39, -0.04), Color(0.85, 0.2, 0.2), false)
					stripe.rotation.x = 0.4


## Dobra os joelhos (0 = perna esticada). Usado ao sentar e ao andar.
func set_knees(left: float, right: float) -> void:
	knee_l.rotation.x = -left
	knee_r.rotation.x = -right


# ------------------------------------------------------------------ braços

func _arm(x: float, y: float, sleeve: int, right: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, y, 0)
	torso.add_child(pivot)
	var side := 1.0 if right else -1.0
	var thick := 1.0
	match profile.body:
		CustomerProfile.Body.VALENTAO:
			thick = 1.35
		CustomerProfile.Body.TIOZAO:
			thick = 1.1
		CustomerProfile.Body.FALANTE, CustomerProfile.Body.UNIVERSITARIO:
			thick = 0.9
	# ombro + braço
	var sh := Mats.sphere(pivot, 0.072 * thick, Vector3(0, -0.01, 0), skin if sleeve == 0 else shirt)
	if sleeve == 0:
		_skin(sh, true)
	var upper := _limb(pivot, Vector3(0, -0.03, 0), Vector3(0, -0.24, 0), 0.06 * thick, shirt if sleeve == 2 else skin, true)
	if sleeve != 2:
		_skin(upper, true)
	if profile.body == CustomerProfile.Body.VALENTAO:
		# bíceps
		_skin(Mats.sphere(pivot, 0.06 * thick, Vector3(0, -0.13, -0.025), skin, false, Vector3(0.9, 1.3, 0.9)))
	if sleeve == 1:
		Mats.cylinder(pivot, 0.08 * thick, 0.14, Vector3(0, -0.07, 0), shirt, true, 0.076 * thick)
		Mats.cylinder(pivot, 0.082 * thick, 0.022, Vector3(0, -0.135, 0), shirt.darkened(0.15), false)
	elif sleeve == 2 and profile.body == CustomerProfile.Body.FOFOQUEIRA:
		# manga bufante
		Mats.sphere(pivot, 0.09, Vector3(0, -0.05, 0), shirt.lightened(0.1), true, Vector3(1, 0.9, 1))
	var fore := Node3D.new()
	fore.name = "Fore"
	fore.position = Vector3(0, -0.26, 0)
	fore.rotation.x = 0.3
	pivot.add_child(fore)
	var fore_col := shirt if sleeve == 2 else skin
	var elbow := Mats.sphere(fore, 0.056 * thick, Vector3.ZERO, fore_col, false)
	var fa := Mats.cylinder(fore, 0.045 * thick, 0.22, Vector3(0, -0.11, 0), fore_col, true, 0.056 * thick)
	if sleeve != 2:
		_skin(elbow)
		_skin(fa, true)
	else:
		# punho (canelado no moletom)
		var cuff := shirt.darkened(0.15)
		Mats.cylinder(fore, 0.05 * thick, 0.05, Vector3(0, -0.2, 0), cuff, false)
		if profile.body == CustomerProfile.Body.UNIVERSITARIO:
			for i in 3:
				Mats.cylinder(fore, 0.052 * thick, 0.006, Vector3(0, -0.185 - i * 0.014, 0), cuff.darkened(0.15), false)
	_skin(Mats.sphere(fore, 0.04 * thick, Vector3(0, -0.225, 0), skin, false, Vector3(1.0, 0.8, 0.9)))
	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0, -0.235, 0)
	hand.rotation.y = side * 0.8
	fore.add_child(hand)
	_build_hand(hand, right, thick)
	return pivot


## Mão cartunesca: palma virada para dentro, nós dos dedos, quatro dedos com duas
## falanges dobradas para a palma e dedão opositor. Indicador na frente (-Z).
func _build_hand(hand: Node3D, right: bool, thick: float) -> void:
	var side := 1.0 if right else -1.0
	var s := 0.92 + (thick - 1.0) * 0.6
	_skin(Mats.sphere(hand, 0.052 * s, Vector3(0, -0.035 * s, 0), skin, true, Vector3(0.62, 1.0, 1.0)), true)
	var lens := [0.03, 0.034, 0.032, 0.025]
	for i in 4:
		var z := (-0.03 + i * 0.02) * s
		var base := Vector3(-side * 0.004 * s, -0.075 * s, z)
		var l: float = lens[i] * s
		var mid := base + Vector3(-side * 0.35, -1.0, 0).normalized() * l
		var tip := mid + Vector3(-side * 1.0, -0.45, 0).normalized() * l * 0.85
		var r := (0.0135 if i < 3 else 0.012) * s
		_skin(_limb(hand, base, mid, r, skin))
		_skin(_limb(hand, mid, tip, r * 0.95, skin))
		# nó do dedo
		_skin(Mats.sphere(hand, r * 1.05, base + Vector3(side * 0.006, 0.004, 0), skin, false))
	var t0 := Vector3(-side * 0.012 * s, -0.025 * s, -0.035 * s)
	var t1 := Vector3(-side * 0.035 * s, -0.06 * s, -0.048 * s)
	var t2 := Vector3(-side * 0.05 * s, -0.085 * s, -0.036 * s)
	_skin(_limb(hand, t0, t1, 0.016 * s, skin))
	_skin(_limb(hand, t1, t2, 0.014 * s, skin))


func _arm_extras(p: CustomerProfile) -> void:
	match p.body:
		CustomerProfile.Body.TIOZAO:
			# relógio de pulseira de couro
			Mats.cylinder(fore_l, 0.05, 0.03, Vector3(0, -0.19, 0), Color(0.35, 0.2, 0.1), false)
			var face := Mats.cylinder(fore_l, 0.022, 0.012, Vector3(0.0, -0.19, -0.05), Color(0.95, 0.95, 0.9), false)
			face.rotation.x = PI / 2.0
		CustomerProfile.Body.VALENTAO:
			# tatuagem de coração "MÃE" no braço + tribal no outro + munhequeira
			var tat := Node3D.new()
			tat.position = Vector3(0.0, -0.13, -0.09)
			arm_r.add_child(tat)
			var heart := MeshInstance3D.new()
			heart.mesh = Mats.flat_polygon_mesh(SymbolShapes.polygon(&"heart"), 0.038)
			heart.material_override = Mats.unshaded(Color(0.75, 0.1, 0.15))
			heart.rotation.y = PI
			tat.add_child(heart)
			var banner := MeshInstance3D.new()
			banner.mesh = Mats.flat_polygon_mesh(PackedVector2Array([Vector2(-1.2, -0.3), Vector2(1.2, -0.3), Vector2(1.0, 0.0), Vector2(1.2, 0.3), Vector2(-1.2, 0.3), Vector2(-1.0, 0.0)]), 0.03)
			banner.material_override = Mats.unshaded(Color(0.95, 0.9, 0.75))
			banner.rotation.y = PI
			banner.position = Vector3(0, -0.005, -0.001)
			tat.add_child(banner)
			var l := Mats.label3d(tat, "MÃE", Vector3(0, -0.005, -0.002), 24, Color(0.15, 0.2, 0.45), 0)
			l.pixel_size = 0.0011
			l.rotation.y = PI
			for i in 4:
				var band := Mats.cylinder(arm_l, 0.082, 0.01, Vector3(0, -0.07 - i * 0.035, 0), Color(0.12, 0.12, 0.16), false)
				band.rotation.z = 0.25 * (1 if i % 2 == 0 else -1)
			Mats.cylinder(fore_r, 0.068, 0.05, Vector3(0, -0.18, 0), Color(0.85, 0.15, 0.15), false)
			Mats.cylinder(fore_l, 0.068, 0.03, Vector3(0, -0.19, 0), GOLD, false)
		CustomerProfile.Body.FALANTE:
			# relógio digital
			Mats.cylinder(fore_l, 0.048, 0.025, Vector3(0, -0.19, 0), Color(0.15, 0.15, 0.17), false)
			Mats.box(fore_l, Vector3(0.03, 0.03, 0.012), Vector3(0, -0.19, -0.048), Color(0.55, 0.85, 0.55), false)
		CustomerProfile.Body.FOFOQUEIRA:
			# pulseiras + leque na mão esquerda + unhas pintadas
			for i in 3:
				Mats.torus(fore_l, 0.048, 0.058, Vector3(0, -0.17 - i * 0.018, 0), [GOLD, Color(0.9, 0.3, 0.5), Color(0.3, 0.7, 0.9)][i])
			prop = Node3D.new()
			prop.name = "Fan"
			prop.position = Vector3(0.05, -0.08, -0.02)
			hand_l.add_child(prop)
			var fan := MeshInstance3D.new()
			var pts := PackedVector2Array([Vector2(0, 0)])
			for i in 13:
				var a := lerpf(-0.95, 0.95, i / 12.0) - PI / 2.0
				pts.append(Vector2(cos(a), sin(a)) * (1.0 if i % 2 == 0 else 0.93))
			fan.mesh = Mats.flat_polygon_mesh(pts, 0.14)
			fan.material_override = Mats.unshaded(Color(0.95, 0.35, 0.5))
			fan.rotation = Vector3(0, PI / 2.0, PI)
			prop.add_child(fan)
			var ribs := MeshInstance3D.new()
			var rp := PackedVector2Array([Vector2(0, 0)])
			for i in 13:
				var a := lerpf(-0.95, 0.95, i / 12.0) - PI / 2.0
				rp.append(Vector2(cos(a), sin(a)) * 0.35)
			ribs.mesh = Mats.flat_polygon_mesh(rp, 0.14)
			ribs.material_override = Mats.unshaded(Color(0.45, 0.25, 0.12))
			ribs.rotation = Vector3(0, PI / 2.0, PI)
			ribs.position.x = 0.001
			prop.add_child(ribs)
		CustomerProfile.Body.UNIVERSITARIO:
			# celular na mão esquerda (tela acesa com app aberto)
			prop = Node3D.new()
			prop.name = "Phone"
			prop.position = Vector3(0.04, -0.08, -0.01)
			prop.rotation.y = -PI / 2.0
			hand_l.add_child(prop)
			Mats.box(prop, Vector3(0.07, 0.13, 0.012), Vector3.ZERO, Color(0.1, 0.1, 0.12), false)
			var screen := Mats.box(prop, Vector3(0.06, 0.115, 0.004), Vector3(0, 0, -0.007), Color(0.4, 0.7, 1.0), false)
			screen.material_override = Mats.toon(Color(0.45, 0.75, 1.0), false, 0.5, 1.5)
			for i in 3:
				var row := Mats.box(prop, Vector3(0.045, 0.012, 0.002), Vector3(0, 0.035 - i * 0.025, -0.0095), Color(1, 1, 1), false)
				row.material_override = Mats.toon(Color(1, 1, 1), false, 0.5, 1.0)
		CustomerProfile.Body.MALANDRO:
			# anel de ouro no dedo e relógio dourado
			Mats.torus(hand_r, 0.012, 0.02, Vector3(0.0, -0.085, -0.03), GOLD)
			Mats.cylinder(fore_l, 0.05, 0.03, Vector3(0, -0.19, 0), GOLD, false)
			Mats.cylinder(fore_l, 0.022, 0.012, Vector3(0, -0.19, -0.05), Color(0.95, 0.95, 0.9), false).rotation.x = PI / 2.0


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
	var skull_mesh := SphereMesh.new()
	skull_mesh.radius = r
	skull_mesh.height = r * 2.0
	skull_mesh.radial_segments = 18 if GameManager.low_end else 24
	skull_mesh.rings = 10 if GameManager.low_end else 12
	var skull := MeshInstance3D.new()
	skull.mesh = skull_mesh
	skull.position = Vector3(0, r, 0)
	skull.scale = hs
	head.add_child(skull)
	_skin(skull, true)
	# queixo/mandíbula para tirar o "cabeça-bola"
	_skin(Mats.sphere(head, r * 0.72, Vector3(0, r * 0.62, -0.03), skin, false, Vector3(hs.x * 1.0, 0.75, hs.z)))
	var fy := r * 1.0
	var fz := -r * hs.z * 0.86
	# orelhas: concha, parte interna e lóbulo
	for side: float in [-1.0, 1.0]:
		var ex := side * r * hs.x * 0.98
		_skin(Mats.sphere(head, 0.06, Vector3(ex, fy, 0), skin, true, Vector3(0.5, 1.0, 0.8)), true)
		var inner := Mats.sphere(head, 0.035, Vector3(ex + side * 0.018, fy + 0.005, -0.005), skin.darkened(0.25), false, Vector3(0.4, 1.0, 0.7))
		inner.set_meta("no_highlight", true)
		_skin(Mats.sphere(head, 0.022, Vector3(ex + side * 0.01, fy - 0.055, -0.01), skin, false))
	# olhos: branco + linha dos cílios + (íris, pupila, brilhos) num grupo que olha em volta
	var eye_x := 0.085 * hs.x
	var eye_y := fy + 0.06
	_eye_y = eye_y
	_eye_x = eye_x
	_mouth_y = fy - 0.11
	var iris_col: Color = IRIS_COLORS[_rng.randi_range(0, IRIS_COLORS.size() - 1)]
	var lash_r := 0.012 if p.body == CustomerProfile.Body.FOFOQUEIRA else 0.0075
	for side: float in [-1.0, 1.0]:
		var ec := Vector3(side * eye_x, eye_y, fz + 0.02)
		var white := Mats.sphere(head, 0.068, ec, Color.WHITE, true, Vector3(1.0, 1.15, 0.7))
		white.name = "EyeWhite"
		var rad := Vector3(0.068, 0.078, 0.048) * 1.04
		var lash := PackedVector3Array()
		for k in 4:
			var t := lerpf(-1.25, 1.25, k / 3.0)
			lash.append(ec + Vector3(sin(t) * 0.78, cos(t) * 0.7, -0.62).normalized() * rad)
		for k in 3:
			_limb(head, lash[k], lash[k + 1], lash_r, INK)
		var look := Node3D.new()
		look.position = Vector3(side * eye_x, eye_y, fz)
		head.add_child(look)
		Mats.sphere(look, 0.038, Vector3(0, 0, -0.022), iris_col, false, Vector3(1.0, 1.1, 0.45))
		Mats.sphere(look, 0.03, Vector3(0, -0.006, -0.025), iris_col.lightened(0.25), false, Vector3(1.0, 0.8, 0.45))
		Mats.sphere(look, 0.021, Vector3(0, 0, -0.035), Color(0.05, 0.03, 0.03), false, Vector3(1.0, 1.1, 0.45))
		Mats.sphere(look, 0.009, Vector3(0.012, 0.014, -0.042), Color.WHITE, false)
		Mats.sphere(look, 0.0045, Vector3(-0.01, -0.012, -0.041), Color.WHITE, false)
		var lid := Mats.sphere(head, 0.073, Vector3(side * eye_x, eye_y + 0.004, fz + 0.018), skin.darkened(0.08), false, Vector3(1.05, 1.2, 0.75))
		lid.scale = Vector3(1.05, 0.2, 0.78)
		lid.position.y = eye_y + 0.07
		lid.visible = false
		# pálpebra de baixo: escondida; sobe para "apertar" o olho (sorriso, raiva)
		var low := Mats.sphere(head, 0.071, ec + Vector3(0, -0.06, -0.002), skin, false, Vector3(1.05, 0.2, 0.74))
		_skin(low)
		low.visible = false
		# maçã do rosto que só aparece no sorriso (bochecha levantada)
		var apple := Mats.sphere(head, 0.045, ec + Vector3(side * 0.03, -0.09, -0.012), skin, false, Vector3(1.2, 0.8, 0.6))
		_skin(apple)
		apple.visible = false
		# dobrinha embaixo do olho
		_limb(head, ec + Vector3(-0.028, -0.078, -0.032), ec + Vector3(0.028, -0.078, -0.032), 0.0045, skin.darkened(0.15))
		var brow := Node3D.new()
		brow.position = Vector3(side * eye_x, eye_y + 0.1, fz - 0.005)
		head.add_child(brow)
		_build_brow(brow, side, p)
		if p.body == CustomerProfile.Body.FOFOQUEIRA:
			# cílios postiços + sombra azul
			for k in 3:
				var base := ec + Vector3(side * (0.045 + k * 0.012), 0.05 - k * 0.012, -0.03)
				_limb(head, base, base + Vector3(side * 0.025, 0.02 - k * 0.006, -0.005), 0.004, INK)
			Mats.sphere(head, 0.05, ec + Vector3(0, 0.055, 0.006), Color(0.45, 0.6, 0.95), false, Vector3(1.3, 0.45, 0.6))
		if side < 0:
			pupil_l = look
			lid_l = lid
			brow_l = brow
			lower_lid_l = low
			apple_l = apple
		else:
			pupil_r = look
			lid_r = lid
			brow_r = brow
			lower_lid_r = low
			apple_r = apple
	_build_nose(p, fy, fz)
	# bochechas coradas
	for side: float in [-1.0, 1.0]:
		var cheek := Mats.sphere(head, 0.05, Vector3(side * 0.15 * hs.x, fy - 0.05, fz + 0.03), Color.WHITE, false, Vector3(1.0, 0.6, 0.3))
		cheek.material_override = cheek_mat
		cheek.set_meta("no_highlight", true)
	_build_mouth(p, fy, fz)
	_build_hair(p, r, hs, fy, fz)


func _build_brow(brow: Node3D, side: float, p: CustomerProfile) -> void:
	var t := 0.02
	var arch := 0.012
	var col := p.hair_color
	match p.body:
		CustomerProfile.Body.VALENTAO, CustomerProfile.Body.TIOZAO:
			t = 0.026
			arch = 0.006
		CustomerProfile.Body.FOFOQUEIRA:
			t = 0.01
			arch = 0.022
			col = p.hair_color.darkened(0.45)
	var inner := Vector3(-side * 0.05, -0.006, 0.0)
	var mid := Vector3(side * 0.005, arch, -0.004)
	var outer := Vector3(side * 0.058, -0.006, 0.012)
	_limb(brow, inner, mid, t, col)
	_limb(brow, mid, outer, t * 0.7, col)


func _build_nose(p: CustomerProfile, fy: float, fz: float) -> void:
	var nose_scale := Vector3(1.0, 0.85, 1.0)
	var nose_r := 0.048
	match p.body:
		CustomerProfile.Body.FALANTE:
			nose_scale = Vector3(0.8, 1.0, 1.5)
		CustomerProfile.Body.TIOZAO:
			nose_r = 0.06
		CustomerProfile.Body.FOFOQUEIRA:
			nose_r = 0.036
		CustomerProfile.Body.VALENTAO:
			nose_scale = Vector3(1.25, 0.8, 0.9)
	var c := Vector3(0, fy - 0.025, fz - 0.055)
	var nose := Mats.sphere(head, nose_r, c, skin, true, nose_scale)
	nose.material_override = nose_mat
	# ponte, asas e narinas
	var bridge := _limb(head, Vector3(0, fy + 0.04, fz - 0.01), c + Vector3(0, 0.01, 0.01), nose_r * 0.42, skin)
	bridge.material_override = nose_flat_mat
	for side: float in [-1.0, 1.0]:
		var wing := Mats.sphere(head, nose_r * 0.55, c + Vector3(side * nose_r * 0.8 * nose_scale.x, -nose_r * 0.3, nose_r * 0.4), skin, false)
		wing.material_override = nose_flat_mat
		Mats.sphere(head, nose_r * 0.2, c + Vector3(side * nose_r * 0.38 * nose_scale.x, -nose_r * 0.72 * nose_scale.y, -nose_r * 0.15), Color(0.25, 0.1, 0.08), false, Vector3(1.2, 0.6, 1.0))


func _build_mouth(p: CustomerProfile, fy: float, fz: float) -> void:
	# boca: interior escuro + dentes + língua + lábios (o de baixo desce quando abre)
	mouth = Node3D.new()
	mouth.position = Vector3(0, fy - 0.11, fz + 0.01)
	head.add_child(mouth)
	mouth_mesh = Mats.sphere(mouth, 0.05, Vector3.ZERO, Color(0.35, 0.08, 0.1), false, Vector3(1.4, 0.35, 0.5))
	Mats.sphere(mouth_mesh, 0.032, Vector3(0, -0.022, -0.01), Color(0.9, 0.4, 0.45), false)
	Mats.box(mouth, Vector3(0.07, 0.014, 0.02), Vector3(0, 0.01, -0.014), Color.WHITE, false)
	if p.body == CustomerProfile.Body.MALANDRO:
		Mats.box(mouth, Vector3(0.016, 0.0145, 0.021), Vector3(0.022, 0.01, -0.0145), GOLD, false)
	var lip := skin.darkened(0.22).lerp(Color(0.7, 0.3, 0.3), 0.25)
	if p.body == CustomerProfile.Body.FOFOQUEIRA:
		lip = Color(0.85, 0.1, 0.25)
		mouth_mesh.material_override = Mats.toon(Color(0.45, 0.05, 0.1), false)
	for side: float in [-1.0, 1.0]:
		var half := Node3D.new()
		half.position = Vector3(side * 0.008, 0.02, -0.024)
		mouth.add_child(half)
		_limb(half, Vector3(side * 0.004, 0.0, 0.0), Vector3(side * 0.052, -0.008, 0.012), 0.009 if p.body != CustomerProfile.Body.FOFOQUEIRA else 0.012, lip)
		if side < 0:
			lip_up_l = half
		else:
			lip_up_r = half
	# lábio de baixo em duas metades presas no meio: dobram em "U" (sorriso) ou "∩" (cara feia)
	lip_low = Node3D.new()
	lip_low.position = Vector3(0, -0.02, -0.02)
	mouth.add_child(lip_low)
	var lr := 0.012 if p.body != CustomerProfile.Body.FOFOQUEIRA else 0.016
	for side: float in [-1.0, 1.0]:
		var half := Node3D.new()
		lip_low.add_child(half)
		_limb(half, Vector3(-side * 0.004, 0.0, 0.0), Vector3(side * 0.042, 0.0, 0.0), lr * (1.0 if side < 0 else 0.98), lip)
		if side < 0:
			lip_low_l = half
		else:
			lip_low_r = half


func _build_hair(p: CustomerProfile, r: float, hs: Vector3, fy: float, fz: float) -> void:
	var hair := p.hair_color
	var sc := Vector3(0, r, 0) # centro do crânio
	match p.body:
		CustomerProfile.Body.TIOZAO:
			# careca brilhante com coroinha de cabelo em tufos, bigodão de vassoura, papada,
			# rugas, caneta atrás da orelha e palito
			for i in 13:
				var a := lerpf(-0.25, PI + 0.25, i / 12.0)
				var pos := sc + Vector3(cos(a) * r * hs.x * 0.98, 0.04 + sin(i * 1.7) * 0.012, sin(a) * r * hs.z * 0.98)
				Mats.sphere(head, 0.05, pos, hair, true, Vector3(0.8, 1.1, 0.8))
			Mats.sphere(head, 0.04, Vector3(-0.07, r * 1.85, -0.08), Color(1, 1, 1), false, Vector3(1.6, 0.5, 1.0)).set_meta("no_highlight", true)
			Mats.sphere(head, 0.02, Vector3(-0.02, r * 1.92, -0.05), Color(1, 1, 1), false, Vector3(1.4, 0.5, 1.0)).set_meta("no_highlight", true)
			for i in 7:
				var t := lerpf(-1.0, 1.0, i / 6.0)
				var pos := Vector3(t * 0.1, fy - 0.075 - absf(t) * 0.025 + (0.008 if i % 2 == 0 else 0.0), fz - 0.045 + absf(t) * 0.03)
				Mats.sphere(head, 0.034 - absf(t) * 0.008, pos, hair, i == 3, Vector3(1.0, 0.85, 0.8))
			var pen := Mats.cylinder(head, 0.008, 0.12, Vector3(r * hs.x * 0.95, fy + 0.07, 0.02), Color(0.15, 0.3, 0.8), false)
			pen.rotation = Vector3(0.0, 0.0, 1.2)
			Mats.cylinder(head, 0.0085, 0.02, Vector3(r * hs.x * 0.95 - 0.05, fy + 0.09, 0.02), Color(0.9, 0.9, 0.9), false).rotation.z = 1.2
			var pick := Mats.cylinder(head, 0.003, 0.07, Vector3(0.04, fy - 0.13, fz - 0.02), Color(0.9, 0.8, 0.55), false)
			pick.rotation = Vector3(1.4, 0, 1.0)
			for i in 3:
				var y := fy + 0.155 + i * 0.026
				var z := -sqrt(1.0 - pow((y - r) / (r * hs.y), 2.0)) * r * hs.z - 0.002
				_limb(head, Vector3(-0.07, y, z + 0.02), Vector3(0.07, y, z + 0.02), 0.0035, skin.darkened(0.3))
				_limb(head, Vector3(-0.025, y + 0.004, z), Vector3(0.025, y + 0.004, z), 0.0036, skin.darkened(0.3))
			# rugas do sorriso e papada
			for side: float in [-1.0, 1.0]:
				_limb(head, Vector3(side * 0.07, fy - 0.04, fz - 0.005), Vector3(side * 0.095, fy - 0.12, fz + 0.01), 0.004, skin.darkened(0.25))
			_skin(Mats.sphere(head, 0.1, Vector3(0, fy - 0.185, fz + 0.075), skin, false, Vector3(1.25, 0.45, 0.8)))
		CustomerProfile.Body.VALENTAO:
			# cabelo raspado + monocelha + boné aba reta pra trás + cicatriz + barba por fazer
			var buzz := _dome(head, sc, r * 1.012, hs, 33.0, hair.lerp(skin, 0.35), false)
			buzz.rotation.x = 0.3
			hat = Node3D.new()
			hat.name = "Cap"
			hat.position = sc
			hat.rotation.x = 0.25
			head.add_child(hat)
			var cap_col := Color(0.85, 0.15, 0.15) if _rng.randf() < 0.6 else Color(0.15, 0.4, 0.85)
			_dome(hat, Vector3(0, 0.03, 0), r * 1.04, hs, 24.0, cap_col)
			Mats.cylinder(hat, r * 1.045 * hs.x * cos(deg_to_rad(24.0)), 0.03, Vector3(0, 0.03 + r * 1.04 * hs.y * sin(deg_to_rad(24.0)), 0), cap_col.darkened(0.2), false).scale = Vector3(1, 1, hs.z / hs.x)
			var visor := Mats.box(hat, Vector3(0.24, 0.016, 0.15), Vector3(0, 0.07, r * hs.z + 0.05), cap_col.darkened(0.1))
			visor.rotation.x = -0.08
			Mats.box(hat, Vector3(0.235, 0.004, 0.145), Vector3(0, 0.06, r * hs.z + 0.05), Color(0.15, 0.4, 0.2), false).rotation.x = -0.08
			Mats.cylinder(hat, 0.016, 0.012, Vector3(0, r * hs.y * 1.04 + 0.03, 0), cap_col.darkened(0.3), false)
			# fecho de trás vira "frente" do boné ao contrário
			Mats.sphere(hat, 0.05, Vector3(0, 0.15, -r * hs.z * 0.93), cap_col.darkened(0.45), false, Vector3(1.2, 0.8, 0.3))
			Mats.box(hat, Vector3(0.1, 0.014, 0.012), Vector3(0, 0.135, -r * hs.z * 0.97), Color(0.12, 0.12, 0.12), false)
			# barba por fazer no queixo (a boca fica de fora)
			Mats.sphere(head, 0.09, Vector3(0, fy - 0.185, fz + 0.055), skin.darkened(0.14), false, Vector3(1.25, 0.5, 0.7))
			var scar := Mats.box(head, Vector3(0.008, 0.075, 0.006), Vector3(0.13, fy + 0.05, fz + 0.03), Color(0.85, 0.45, 0.45), false)
			scar.rotation.z = 0.4
			for k in 3:
				var st := Mats.box(head, Vector3(0.028, 0.005, 0.006), Vector3(0.13 + (k - 1) * 0.012, fy + 0.05 + (k - 1) * 0.022, fz + 0.028), Color(0.85, 0.45, 0.45), false)
				st.rotation.z = 0.4
			# brinco de argola
			Mats.torus(head, 0.012, 0.018, Vector3(-r * hs.x, fy - 0.07, 0), GOLD).rotation_degrees.z = 90
		CustomerProfile.Body.FALANTE:
			# topete alto em mechas + costeletas + óculos de aro grosso com hastes
			var base := _dome(head, sc, r * 1.025, hs, 30.0, hair)
			base.rotation.x = 0.35
			for i in 5:
				var t := i / 4.0
				var pos := Vector3(lerpf(-0.08, 0.1, t), r * (1.8 + sin(t * PI) * 0.2), lerpf(-r * 0.35, r * 0.2, t))
				Mats.sphere(head, r * (0.42 - t * 0.12), pos, hair, true, Vector3(1.3, 0.75, 1.1))
			Mats.sphere(head, r * 0.3, Vector3(-0.1, r * 1.95, -r * 0.5), hair.lightened(0.08), true, Vector3(1.0, 0.8, 1.0))
			for side: float in [-1.0, 1.0]:
				Mats.box(head, Vector3(0.03, 0.11, 0.05), Vector3(side * r * hs.x * 0.94, fy + 0.0, -0.06), hair, false)
				var lc := Vector3(side * 0.085 * hs.x, fy + 0.06, fz - 0.045)
				var lens := Mats.torus(head, 0.06, 0.077, lc, Color(0.1, 0.1, 0.1))
				lens.rotation_degrees.x = 90
				var glass := Mats.cylinder(head, 0.062, 0.004, lc + Vector3(0, 0, 0.002), Color(0.8, 0.9, 1.0), false)
				glass.material_override = Mats.glass(Color(0.8, 0.9, 1.0), 0.25)
				glass.rotation_degrees.x = 90
				glass.set_meta("no_highlight", true)
				_limb(head, lc + Vector3(side * 0.075, 0.0, 0.0), Vector3(side * r * hs.x * 0.98, fy + 0.04, 0.0), 0.007, Color(0.1, 0.1, 0.1))
			Mats.box(head, Vector3(0.05, 0.012, 0.012), Vector3(0, fy + 0.065, fz - 0.05), Color(0.1, 0.1, 0.1), false)
		CustomerProfile.Body.FOFOQUEIRA:
			# cabelão armado em cachos, bobes com grampo, brincos de argola e pinta charmosa
			for i in 18:
				var a := i * TAU / 18.0
				if sin(a) < -0.55:
					continue # deixa a testa (e os olhos) de fora
				var y := r * 1.0 + sin(a * 2.0) * 0.06 + 0.12
				Mats.sphere(head, 0.11, Vector3(cos(a) * r * 1.0, y, sin(a) * r * 0.95 + 0.04), hair, true)
			for i in 10:
				var a := i * TAU / 10.0 + 0.3
				if sin(a) < -0.3:
					continue
				Mats.sphere(head, 0.06, Vector3(cos(a) * r * 1.08, r * 0.82 + (i % 2) * 0.04, sin(a) * r * 0.95 + 0.06), hair.darkened(0.08), false)
			Mats.sphere(head, r * 0.9, Vector3(0, r * 1.45, 0.03), hair, true)
			# franja
			for i in 4:
				Mats.sphere(head, 0.06, Vector3(-0.1 + i * 0.065, r * 1.75, fz + 0.06 + absf(i - 1.5) * 0.02), hair, false, Vector3(1.1, 0.8, 0.8))
			var roller_cols := [Color(1.0, 0.55, 0.7), Color(0.45, 0.75, 1.0), Color(1.0, 0.85, 0.3)]
			for i in 5:
				var pos := Vector3(-0.16 + i * 0.08, r * 1.95 - absf(i - 2) * 0.03, 0.04 + absf(i - 2) * 0.03)
				var roller := Mats.cylinder(head, 0.035, 0.11, pos, roller_cols[i % 3], false)
				roller.rotation.z = PI / 2.0
				Mats.cylinder(head, 0.037, 0.01, pos, Color(0.9, 0.9, 0.9), false).rotation.z = PI / 2.0
			for side: float in [-1.0, 1.0]:
				Mats.torus(head, 0.03, 0.045, Vector3(side * r * 1.0, fy - 0.11, -0.01), GOLD).rotation_degrees.z = 90
			Mats.sphere(head, 0.009, Vector3(0.085, fy - 0.1, fz + 0.0), Color(0.15, 0.08, 0.05), false)
		CustomerProfile.Body.UNIVERSITARIO:
			# touca canelada com pompom, franja escapando, cavanhaque, olheiras e fones no pescoço
			hat = Node3D.new()
			hat.name = "Beanie"
			hat.position = sc
			hat.rotation.x = 0.3
			head.add_child(hat)
			var beanie: Color = [Color(0.85, 0.2, 0.2), Color(0.95, 0.75, 0.15), Color(0.2, 0.55, 0.35)][_rng.randi_range(0, 2)]
			_dome(hat, Vector3(0, 0.02, 0), r * 1.05, Vector3(hs.x, hs.y * 1.15, hs.z), 20.0, beanie)
			var cuff_y := 0.02 + r * 1.05 * hs.y * 1.15 * sin(deg_to_rad(20.0))
			var cuff_r := r * 1.05 * hs.x * cos(deg_to_rad(20.0)) + 0.008
			var cuff := Mats.cylinder(hat, cuff_r, 0.07, Vector3(0, cuff_y, 0), beanie.darkened(0.15), true)
			cuff.scale = Vector3(1, 1, hs.z / hs.x)
			for i in 10:
				var a := i * TAU / 10.0
				var rib := Mats.box(hat, Vector3(0.006, 0.065, 0.006), Vector3(cos(a) * (cuff_r + 0.003), cuff_y, sin(a) * (cuff_r + 0.003) * hs.z / hs.x), beanie.darkened(0.3), false)
				rib.rotation.y = -a
			Mats.sphere(hat, 0.055, Vector3(0, r * hs.y * 1.2 + 0.06, 0), Color(1, 1, 1), true)
			for i in 4:
				var tuft := Mats.sphere(head, 0.035, Vector3(-0.09 + i * 0.06, fy + 0.165, fz + 0.03), hair, false, Vector3(0.9, 1.2, 0.6))
				tuft.rotation.z = (i - 1.5) * 0.3
			for side: float in [-1.0, 1.0]:
				Mats.box(head, Vector3(0.03, 0.12, 0.08), Vector3(side * r * hs.x * 0.94, fy + 0.04, -0.03), hair, false)
				Mats.sphere(head, 0.035, Vector3(side * eye_x_for(hs), fy + 0.0, fz + 0.03), skin.darkened(0.25), false, Vector3(1.0, 0.4, 0.4))
			Mats.sphere(head, 0.035, Vector3(0, fy - 0.175, fz + 0.025), hair, false, Vector3(1.0, 1.3, 0.8))
			for side: float in [-1.0, 1.0]:
				Mats.sphere(head, 0.015, Vector3(side * 0.035, fy - 0.08, fz - 0.03), hair, false, Vector3(1.5, 0.6, 0.6))
			# fones no pescoço com fio
			var phones := Color(0.15, 0.15, 0.18)
			Mats.torus(torso, 0.09, 0.11, Vector3(0, 0.6, 0.0), phones)
			for side: float in [-1.0, 1.0]:
				Mats.cylinder(torso, 0.045, 0.035, Vector3(side * 0.1, 0.6, -0.04), phones, false).rotation.z = PI / 2.0
				Mats.cylinder(torso, 0.03, 0.037, Vector3(side * 0.1, 0.6, -0.04), Color(0.85, 0.2, 0.2), false).rotation.z = PI / 2.0
		CustomerProfile.Body.MALANDRO:
			# chapéu panamá com fita, cabelo na régua, costeletas, bigodinho fino e palito
			var slick := _dome(head, sc, r * 1.012, hs, 33.0, hair)
			slick.rotation.x = 0.3
			for side: float in [-1.0, 1.0]:
				Mats.box(head, Vector3(0.025, 0.08, 0.04), Vector3(side * r * hs.x * 0.95, fy + 0.02, -0.05), hair, false)
			hat = Node3D.new()
			hat.name = "Panama"
			hat.position = Vector3(0, r * 1.55, 0.0)
			head.add_child(hat)
			var straw := Color(0.97, 0.94, 0.85)
			var brim := MeshInstance3D.new()
			brim.mesh = BeverageModels.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(r * 1.2, 0.0),
				Vector2(r * 1.45, 0.012), Vector2(r * 1.47, 0.022), Vector2(r * 1.4, 0.018), Vector2(r * 1.15, 0.01), Vector2(0.0, 0.01)]), 20)
			brim.material_override = Mats.toon(straw)
			hat.add_child(brim)
			var crown := MeshInstance3D.new()
			crown.mesh = BeverageModels.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(r * 0.85, 0.0),
				Vector2(r * 0.8, 0.12), Vector2(r * 0.72, 0.16), Vector2(r * 0.3, 0.15), Vector2(0.0, 0.13)]), 20)
			crown.material_override = Mats.toon(straw)
			hat.add_child(crown)
			Mats.cylinder(hat, r * 0.86, 0.04, Vector3(0, 0.03, 0), Color(0.1, 0.08, 0.08), false, r * 0.845)
			Mats.box(hat, Vector3(0.03, 0.035, 0.03), Vector3(-r * 0.82, 0.03, -0.05), Color(0.1, 0.08, 0.08), false)
			hat.rotation.z = 0.12
			_limb(head, Vector3(-0.065, fy - 0.068, fz - 0.03), Vector3(0.065, fy - 0.068, fz - 0.03), 0.009, hair)
			var pick := Mats.cylinder(head, 0.003, 0.08, Vector3(-0.04, fy - 0.12, fz - 0.02), Color(0.9, 0.8, 0.55), false)
			pick.rotation = Vector3(1.4, 0, -1.0)


func eye_x_for(hs: Vector3) -> float:
	return 0.085 * hs.x


# ------------------------------------------------------------------ expressão

## Aplica as cores e a "cara" da embriaguez (0..1).
func apply_drunk_look(f: float, flush: float) -> void:
	cheek_mat.albedo_color.a = clampf(f * 0.9 + flush * 0.5, 0.0, 0.85)
	nose_mat.albedo_color = _base_skin.lerp(Color(0.95, 0.25, 0.25), clampf(f * 1.1, 0.0, 1.0))
	nose_flat_mat.albedo_color = _base_skin.lerp(Color(0.95, 0.3, 0.28), clampf(f * 0.8, 0.0, 1.0))
	face_mat.albedo_color = _base_skin.lerp(Color(0.9, 0.3, 0.25), clampf(flush * 0.6, 0.0, 0.6))
	skin_flat_mat.albedo_color = face_mat.albedo_color


## Expressão do rosto (0..1 cada). Só visual: quem decide o humor é o CustomerController.
## Feliz: maçãs sobem, olhos apertados por baixo, cantos da boca para cima.
## Bravo: olhos apertados, sobrancelhas tortas, boca prensada e caída de lado.
## Bêbado: pálpebras desiguais, uma sobrancelha erguida, boca torta e meio aberta.
func set_expression(happy: float, angry: float, drunk: float) -> void:
	_x_happy = clampf(happy, 0.0, 1.0)
	_x_angry = clampf(angry, 0.0, 1.0)
	_x_drunk = clampf(drunk, 0.0, 1.0)
	var low := clampf(_x_happy * 0.6 + _x_angry * 0.35, 0.0, 1.0)
	for l: MeshInstance3D in [lower_lid_l, lower_lid_r]:
		l.visible = low > 0.04
		l.scale.y = lerpf(0.2, 0.62, low)
		l.position.y = _eye_y - 0.06 + low * 0.022
	for a: MeshInstance3D in [apple_l, apple_r]:
		a.visible = _x_happy > 0.05
		a.scale = Vector3(1.2, 0.8, 0.6) * lerpf(0.4, 1.0, _x_happy)
		a.position.y = _eye_y - 0.09 + _x_happy * 0.012


## lid = 0 aberto … 1 fechado
func set_eyelids(lid: float) -> void:
	# bravo aperta por cima; bêbado deixa um olho mais caído que o outro
	var base := lid + _x_angry * 0.22
	var sides := [clampf(base + _x_drunk * 0.14, 0.0, 1.0), clampf(base - _x_drunk * 0.06, 0.0, 1.0)]
	var lids: Array[MeshInstance3D] = [lid_l, lid_r]
	for i in 2:
		var l := lids[i]
		var v: float = sides[i]
		l.visible = v > 0.04
		l.scale.y = lerpf(0.2, 1.25, v)
		l.position.y = lerpf(_eye_y + 0.07, _eye_y + 0.004, v)
		# bravo: pálpebra inclinada para dentro (olhar de raiva)
		l.rotation.z = (-1.0 if i == 0 else 1.0) * _x_angry * 0.35


func set_brows(angle: float, raise: float) -> void:
	brow_l.rotation.z = -angle
	brow_r.rotation.z = angle
	# assimetria cartunesca: bravo ergue uma; bêbado ergue a outra ("hã?")
	brow_l.position.y = _eye_y + 0.1 + raise + _x_drunk * 0.022 - _x_angry * 0.006
	brow_r.position.y = _eye_y + 0.1 + raise + _x_angry * 0.012 - _x_drunk * 0.006
	brow_l.rotation.z -= _x_drunk * 0.2


func set_mouth(open: float, smile: float) -> void:
	smile = clampf(smile + _x_happy * 0.5 - _x_angry * 0.7, -1.0, 1.0)
	# bravo prensa a boca (a não ser falando); bêbado deixa meio aberta
	open = clampf(maxf(open * (1.0 - _x_angry * 0.4), _x_drunk * 0.35 + maxf(smile, 0.0) * 0.4), 0.0, 1.0)
	var h := 0.3 + open * 1.1
	mouth_mesh.scale = Vector3(1.4 + smile * 0.3, h, 0.5)
	mouth.position.y = _mouth_y - open * 0.015
	# boca torta: bêbado (sorriso de lado) e bravo (cantinho caído)
	mouth.rotation.z = _x_drunk * 0.2 - _x_angry * 0.1
	mouth.position.x = _x_drunk * 0.012
	# cantos da boca: sorriso sobe, cara feia desce
	# sorriso: o de baixo faz o "U" e o de cima acompanha de leve; cara feia: o de cima faz o "∩"
	var up := smile * (0.3 if smile > 0.0 else 0.6)
	var down := smile * (0.55 if smile > 0.0 else 0.15)
	lip_up_l.rotation.z = -up
	lip_up_r.rotation.z = up
	lip_low.position.y = -0.05 * h - 0.004
	lip_low_l.rotation.z = -down
	lip_low_r.rotation.z = down


func look_pupils(offset: Vector2) -> void:
	pupil_l.position.x = -_eye_x + offset.x * 0.022
	pupil_r.position.x = _eye_x + offset.y * 0.022
