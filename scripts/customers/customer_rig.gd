class_name CustomerRig
extends Node3D
## Freguês modelado: malha contínua de plástico liso (estilo bonequinho de vinil),
## esculpida por campo de distância em tools/bake_customers.py e gravada em
## assets/customers/<perfil>.bin. O corpo é uma malha só com pele de esqueleto; cabeça,
## mãos, sobrancelhas, lábios, chapéu e acessório de mão são peças rígidas presas aos nós.
## Olhos, pálpebras e o interior da boca são montados aqui (são animados).
## Cada freguês sorteia tom de pele e roupa: as regiões da malha recebem as cores dele.
## Frente do boneco = -Z local. Origem = chão.

const SKIN_TONES := [Color(0.98, 0.8, 0.66), Color(0.93, 0.72, 0.56), Color(0.8, 0.56, 0.4),
	Color(0.66, 0.44, 0.3), Color(0.5, 0.33, 0.22), Color(0.38, 0.25, 0.17)]
const INK := Color(0.1, 0.06, 0.05)
## Raio do branco do olho (olhão saltado).
const EYE_R := 0.078
const DATA_DIR := "res://assets/customers/"
const FILES := {
	CustomerProfile.Body.TIOZAO: "tiozao", CustomerProfile.Body.VALENTAO: "valentao",
	CustomerProfile.Body.FALANTE: "falante", CustomerProfile.Body.FOFOQUEIRA: "fofoqueira",
	CustomerProfile.Body.UNIVERSITARIO: "universitario", CustomerProfile.Body.MALANDRO: "malandro",
}

## Papéis de cor gravados pelo bake (região < FIXED_BASE); acima disso, cor fixa do arquivo.
enum Role { SKIN, SKIN_DARK, NOSE, SHIRT, SHIRT_DARK, SHIRT_LIGHT, PANTS, PANTS_DARK, HAIR, HAIR_DARK, HAIR_SKIN, LIP, HAIR_DEEP }
const FIXED_BASE := 32

## Modelos já lidos (um por perfil, compartilhados entre fregueses).
static var _models: Dictionary = {}

var profile: CustomerProfile
var skeleton: Skeleton3D
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
## Barriga do Tiozão (osso próprio; balança na risada). Pode ser null.
var belly: Node3D
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
## Acessório de mão animado por perfil (celular, leque...). Pode ser null.
var prop: Node3D
var hat: Node3D
## Altura de descanso do chapéu (o Malandro levanta o panamá quando fica feliz).
var hat_rest_y := 0.0
var cheek_mat: StandardMaterial3D
var nose_mat: StandardMaterial3D
var face_mat: StandardMaterial3D
var skin: Color
var shirt: Color
var _base_skin: Color
var _eye_y := 0.0
var _eye_x := 0.0
var _brow_y := 0.0
var _mouth_y := 0.0
# expressão atual (0..1 cada): feliz, bravo, bêbado
var _x_happy := 0.0
var _x_angry := 0.0
var _x_drunk := 0.0
var _rng := RandomNumberGenerator.new()
var _model: Dictionary
var _nodes: Dictionary = {}
## Nó de controle de cada osso (o controlador gira os nós; o esqueleto copia).
var _bone_nodes: Array[Node3D] = []
var _mats: Dictionary = {}
var _variant: Dictionary = {}


## variation_seed: mesmo valor → mesmo visual (ex.: hash do apelido).
func build(p: CustomerProfile, variation_seed := 0) -> void:
	profile = p
	_rng.seed = variation_seed if variation_seed != 0 else randi()
	skin = p.skin_color if _rng.randf() < 0.45 else SKIN_TONES[_rng.randi_range(0, SKIN_TONES.size() - 1)]
	shirt = p.shirt_color if p.shirt_variants.is_empty() else p.shirt_variants[_rng.randi_range(0, p.shirt_variants.size() - 1)]
	_base_skin = skin
	# materiais próprios do cliente (mudam de cor com a bebedeira)
	face_mat = Mats.plastic_mat(skin).duplicate()
	nose_mat = Mats.plastic_mat(skin.darkened(0.04)).duplicate()
	cheek_mat = StandardMaterial3D.new()
	cheek_mat.albedo_color = Color(1.0, 0.3, 0.35, 0.0)
	cheek_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cheek_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# um pouquinho de variação de altura entre fregueses
	scale = Vector3.ONE * _rng.randf_range(0.97, 1.03)

	_model = _load_model(FILES[p.body])
	_build_nodes()
	_build_meshes()
	Mats.plastic = true
	_build_face(p)
	_build_extras(p)
	Mats.plastic = false
	_sync_bones()


func _process(_delta: float) -> void:
	_sync_bones()


## Onde fica o copo/salgado segurado (no lado da palma, em coordenadas da mão).
func hold_offset(right := true) -> Vector3:
	return Vector3((-0.075 if right else 0.075), -0.11, 0.0)


## Dobra os joelhos (0 = perna esticada). Usado ao sentar e ao andar.
func set_knees(left: float, right: float) -> void:
	knee_l.rotation.x = -left
	knee_r.rotation.x = -right


# ------------------------------------------------------------------ montagem

func _build_nodes() -> void:
	var list: Array[Node3D] = []
	var bone_of: Dictionary = {}
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	for i in _model.nodes.size():
		var n: Dictionary = _model.nodes[i]
		var nd := Node3D.new()
		nd.name = n.name
		nd.transform = n.xform
		(self as Node3D if n.parent < 0 else list[n.parent]).add_child(nd)
		list.append(nd)
		_nodes[n.name] = nd
		if n.bone:
			var b := skeleton.add_bone(n.name)
			if n.parent >= 0 and bone_of.has(n.parent):
				skeleton.set_bone_parent(b, bone_of[n.parent])
			# repouso = pose A em que a malha foi esculpida; o nó começa na pose neutra
			skeleton.set_bone_rest(b, n.bind)
			bone_of[i] = b
			_bone_nodes.append(nd)
	skeleton.reset_bone_poses()
	process_priority = 10 # depois do controlador mexer nos nós
	torso = _nodes.torso
	head = _nodes.head
	arm_l = _nodes.arm_l
	arm_r = _nodes.arm_r
	fore_l = _nodes.fore_l
	fore_r = _nodes.fore_r
	hand_l = _nodes.hand_l
	hand_r = _nodes.hand_r
	leg_l = _nodes.leg_l
	leg_r = _nodes.leg_r
	knee_l = _nodes.knee_l
	knee_r = _nodes.knee_r
	belly = _nodes.get("belly")
	hat = _nodes.get("hat")
	prop = _nodes.get("prop")
	brow_l = _nodes.brow_l
	brow_r = _nodes.brow_r
	mouth = _nodes.mouth
	lip_up_l = _nodes.lip_up_l
	lip_up_r = _nodes.lip_up_r
	lip_low = _nodes.lip_low
	lip_low_l = _nodes.lip_low_l
	lip_low_r = _nodes.lip_low_r
	if hat:
		hat_rest_y = hat.position.y


func _build_meshes() -> void:
	var skin_res := skeleton.create_skin_from_rest_transforms()
	for part: Dictionary in _model.parts:
		var mi := MeshInstance3D.new()
		mi.name = part.name
		mi.mesh = part.mesh
		var regions: PackedInt32Array = part.regions
		for i in regions.size():
			mi.set_surface_override_material(i, _region_mat(regions[i]))
		if part.skinned:
			skeleton.add_child(mi)
			mi.skeleton = NodePath("..")
			mi.skin = skin_res
		else:
			_nodes[_model.nodes[part.node].name].add_child(mi)


func _sync_bones() -> void:
	for i in _bone_nodes.size():
		var n := _bone_nodes[i]
		skeleton.set_bone_pose_position(i, n.position)
		skeleton.set_bone_pose_rotation(i, n.quaternion)
		skeleton.set_bone_pose_scale(i, n.scale)


func _region_mat(r: int) -> Material:
	if _mats.has(r):
		return _mats[r]
	var m: Material
	if r == Role.SKIN:
		m = face_mat
	elif r == Role.NOSE:
		m = nose_mat
	elif r >= FIXED_BASE:
		var e: Dictionary = _model.fixed[r - FIXED_BASE]
		var colors: Array = e.colors
		if not _variant.has(e.group):
			_variant[e.group] = _rng.randi_range(0, colors.size() - 1)
		var c: Color = colors[mini(_variant[e.group], colors.size() - 1)]
		m = Mats.plastic_mat(c, e.rough if e.rough >= 0.0 else 0.8, e.emission)
	else:
		m = Mats.plastic_mat(_role_color(r))
	_mats[r] = m
	return m


func _role_color(r: int) -> Color:
	var hair := profile.hair_color
	match r:
		Role.SKIN_DARK:
			return skin.darkened(0.15)
		Role.SHIRT:
			return shirt
		Role.SHIRT_DARK:
			return shirt.darkened(0.15)
		Role.SHIRT_LIGHT:
			return shirt.lightened(0.2)
		Role.PANTS:
			return profile.pants_color
		Role.PANTS_DARK:
			return profile.pants_color.darkened(0.18)
		Role.HAIR:
			return hair
		Role.HAIR_DARK:
			return hair.darkened(0.15)
		Role.HAIR_SKIN:
			return hair.lerp(skin, 0.35)
		Role.LIP:
			return skin.darkened(0.32).lerp(Color(0.55, 0.22, 0.2), 0.2)
		Role.HAIR_DEEP:
			return hair.darkened(0.45)
	return skin


func _anchor(n: String) -> Vector3:
	return _model.anchors[n].pos


# ------------------------------------------------------------------ rosto

func _build_face(p: CustomerProfile) -> void:
	# olhões: bolas brancas saltadas, quase encostadas, com pupila pretinha que olha em volta
	var er := EYE_R
	var ecs: Array[Vector3] = [_anchor("eye_l"), _anchor("eye_r")]
	_eye_x = ecs[1].x
	_eye_y = ecs[1].y
	_brow_y = brow_l.position.y
	_mouth_y = mouth.position.y
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var ec := ecs[i]
		var white := Mats.sphere(head, er, ec, Color(0.98, 0.98, 0.96), false, Vector3(1.0, 1.12, 0.78))
		white.material_override = Mats.plastic_mat(Color(0.98, 0.98, 0.96), 0.25)
		white.name = "EyeWhite"
		var look := Node3D.new()
		look.position = ec
		head.add_child(look)
		var front := er * 0.78
		Mats.sphere(look, 0.017, Vector3(0, 0, -front + 0.002), Color(0.05, 0.04, 0.04), false, Vector3(1.0, 1.1, 0.5))
		Mats.sphere(look, 0.0045, Vector3(0.006, 0.007, -front - 0.004), Color.WHITE, false)
		# pálpebra de cima: escondida em cima do olho; desce para piscar
		var lid := Mats.sphere(head, er * 1.04, ec + Vector3(0, 0.004, -0.002), skin.darkened(0.06), false)
		lid.scale = Vector3(1.05, 0.2, 0.84)
		lid.position.y = _eye_y + er * 0.95
		lid.visible = false
		# pálpebra de baixo: escondida; sobe para "apertar" o olho (sorriso, raiva)
		var low := Mats.sphere(head, er * 1.02, ec + Vector3(0, -er * 0.8, -0.002), skin, false, Vector3(1.05, 0.2, 0.84))
		low.material_override = face_mat
		low.visible = false
		# maçã do rosto que só aparece no sorriso (bochecha levantada)
		var apple := Mats.sphere(head, 0.045, ec + Vector3(side * 0.035, -er * 1.25, 0.012), skin, false, Vector3(1.2, 0.8, 0.6))
		apple.material_override = face_mat
		apple.visible = false
		if p.body == CustomerProfile.Body.FOFOQUEIRA:
			# cílios postiços + sombra azul
			for k in 3:
				var base := ec + Vector3(side * (er * 0.75 + k * 0.01), er * 0.7 - k * 0.014, -er * 0.35)
				Mats.limb(head, base, base + Vector3(side * 0.025, 0.02 - k * 0.006, -0.005), 0.004, INK)
			Mats.sphere(head, er * 0.85, ec + Vector3(0, er * 0.75, 0.004), Color(0.45, 0.6, 0.95), false, Vector3(1.3, 0.5, 0.82))
		if i == 0:
			pupil_l = look
			lid_l = lid
			lower_lid_l = low
			apple_l = apple
		else:
			pupil_r = look
			lid_r = lid
			lower_lid_r = low
			apple_r = apple
	# bochechas coradas (aparecem com a bebedeira)
	for n in ["cheek_l", "cheek_r"]:
		var cheek := Mats.sphere(head, 0.045, _anchor(n) + Vector3(0, 0, -0.004), Color.WHITE, false, Vector3(1.0, 0.6, 0.3))
		cheek.material_override = cheek_mat
		cheek.set_meta("no_highlight", true)
	# interior da boca: fundo escuro, língua e dentes (os lábios vêm do modelo)
	mouth_mesh = Mats.sphere(mouth, 0.042, Vector3.ZERO, Color(0.3, 0.07, 0.08), false, Vector3(1.4, 0.35, 0.5))
	Mats.sphere(mouth_mesh, 0.028, Vector3(0, -0.02, -0.008), Color(0.9, 0.4, 0.45), false)
	Mats.box(mouth, Vector3(0.06, 0.012, 0.018), Vector3(0, 0.008, -0.012), Color.WHITE, false)
	if p.body == CustomerProfile.Body.MALANDRO:
		Mats.box(mouth, Vector3(0.014, 0.0125, 0.019), Vector3(0.019, 0.008, -0.0125), Color(1.0, 0.8, 0.2), false)
	if p.body == CustomerProfile.Body.FOFOQUEIRA:
		mouth_mesh.material_override = Mats.plastic_mat(Color(0.45, 0.05, 0.1))
	if p.body == CustomerProfile.Body.FALANTE:
		# lentes dos óculos (a armação vem do modelo)
		for ec: Vector3 in ecs:
			var glass := Mats.cylinder(head, _eye_x * 0.9, 0.003, Vector3(ec.x, ec.y, ec.z - EYE_R * 0.8 - 0.008), Color(0.8, 0.9, 1.0), false)
			glass.material_override = Mats.glass(Color(0.8, 0.9, 1.0), 0.22)
			glass.rotation_degrees.x = 90
			glass.set_meta("no_highlight", true)


func _build_extras(p: CustomerProfile) -> void:
	match p.body:
		CustomerProfile.Body.VALENTAO:
			# tatuagem de coração "MÃE" no braço
			var tat := Node3D.new()
			tat.position = _anchor("tattoo")
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
		CustomerProfile.Body.FOFOQUEIRA:
			# leque na mão esquerda
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
			Mats.label3d(torso, "UFPZ", _anchor("ufpz"), 40, Color(1, 1, 1), 0).rotation.y = PI


# ------------------------------------------------------------------ arquivo

## Lê (uma vez por perfil) o modelo esculpido: nós, âncoras, cores fixas e malhas.
static func _load_model(id: String) -> Dictionary:
	if _models.has(id):
		return _models[id]
	var raw := FileAccess.get_file_as_bytes(DATA_DIR + id + ".bin")
	assert(not raw.is_empty(), "Modelo de freguês ausente: rode tools/bake_customers.py")
	var r := _Reader.new(raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP))
	assert(r.bytes(4).get_string_from_ascii() == "PGC1")
	var model := {"nodes": [], "anchors": {}, "fixed": [], "parts": []}
	for i in r.u16():
		var n := {"name": r.str8(), "parent": r.s16(), "bone": r.u8() == 1}
		n.xform = _xform(r.floats(12))
		n.bind = _xform(r.floats(12))
		model.nodes.append(n)
	for i in r.u16():
		var a_name := r.str8()
		var node := r.s16()
		var f := r.floats(6)
		model.anchors[a_name] = {"node": node, "pos": Vector3(f[0], f[1], f[2]), "normal": Vector3(f[3], f[4], f[5])}
	for i in r.u16():
		var e := {"group": r.str8()}
		var f := r.floats(2)
		e.emission = f[0]
		e.rough = f[1]
		var colors := []
		for k in r.u8():
			var c := r.floats(3)
			colors.append(Color(c[0], c[1], c[2]))
		e.colors = colors
		model.fixed.append(e)
	for i in r.u16():
		var part := {"name": r.str8(), "node": r.s16(), "skinned": r.u8() == 1}
		var mesh := ArrayMesh.new()
		var regions := PackedInt32Array()
		for s in r.u8():
			regions.append(r.u8())
			var nv := r.u32()
			var ni := r.u32()
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = _vec3(r.floats(nv * 3))
			arrays[Mesh.ARRAY_NORMAL] = _vec3(r.floats(nv * 3))
			if part.skinned:
				arrays[Mesh.ARRAY_BONES] = r.ints(nv * 4)
				arrays[Mesh.ARRAY_WEIGHTS] = r.floats(nv * 4)
			arrays[Mesh.ARRAY_INDEX] = r.ints(ni)
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		part.mesh = mesh
		part.regions = regions
		model.parts.append(part)
	_models[id] = model
	return model


static func _xform(f: PackedFloat32Array) -> Transform3D:
	return Transform3D(Basis(Vector3(f[0], f[1], f[2]), Vector3(f[3], f[4], f[5]), Vector3(f[6], f[7], f[8])),
		Vector3(f[9], f[10], f[11]))


static func _vec3(f: PackedFloat32Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(f.size() / 3)
	for i in out.size():
		out[i] = Vector3(f[i * 3], f[i * 3 + 1], f[i * 3 + 2])
	return out


class _Reader:
	var b: PackedByteArray
	var o := 0

	func _init(data: PackedByteArray) -> void:
		b = data

	func bytes(n: int) -> PackedByteArray:
		o += n
		return b.slice(o - n, o)

	func u8() -> int:
		o += 1
		return b.decode_u8(o - 1)

	func u16() -> int:
		o += 2
		return b.decode_u16(o - 2)

	func s16() -> int:
		o += 2
		return b.decode_s16(o - 2)

	func u32() -> int:
		o += 4
		return b.decode_u32(o - 4)

	func str8() -> String:
		return bytes(u8()).get_string_from_utf8()

	func floats(n: int) -> PackedFloat32Array:
		return bytes(n * 4).to_float32_array()

	func ints(n: int) -> PackedInt32Array:
		return bytes(n * 4).to_int32_array()


# ------------------------------------------------------------------ expressão

## Aplica as cores e a "cara" da embriaguez (0..1).
func apply_drunk_look(f: float, flush: float) -> void:
	cheek_mat.albedo_color.a = clampf(f * 0.9 + flush * 0.5, 0.0, 0.85)
	nose_mat.albedo_color = _base_skin.lerp(Color(0.95, 0.25, 0.25), clampf(f * 1.1, 0.0, 1.0))
	face_mat.albedo_color = _base_skin.lerp(Color(0.9, 0.3, 0.25), clampf(flush * 0.6, 0.0, 0.6))


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
		l.position.y = _eye_y - EYE_R * 0.8 + low * EYE_R * 0.3
	for a: MeshInstance3D in [apple_l, apple_r]:
		a.visible = _x_happy > 0.05
		a.scale = Vector3(1.2, 0.8, 0.6) * lerpf(0.4, 1.0, _x_happy)
		a.position.y = _eye_y - EYE_R * 1.25 + _x_happy * 0.012


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
		l.position.y = lerpf(_eye_y + EYE_R * 0.95, _eye_y + 0.004, v)
		# bravo: pálpebra inclinada para dentro (olhar de raiva)
		l.rotation.z = (-1.0 if i == 0 else 1.0) * _x_angry * 0.35


func set_brows(angle: float, raise: float) -> void:
	brow_l.rotation.z = -angle
	brow_r.rotation.z = angle
	# assimetria cartunesca: bravo ergue uma; bêbado ergue a outra ("hã?")
	brow_l.position.y = _brow_y + raise + _x_drunk * 0.022 - _x_angry * 0.006
	brow_r.position.y = _brow_y + raise + _x_angry * 0.012 - _x_drunk * 0.006
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
