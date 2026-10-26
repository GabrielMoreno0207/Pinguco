class_name BarBuilder
extends Node3D
## Monta o buteco inteiro: arquitetura, balcão, geladeira, prateleiras, mesas,
## decoração, luzes e os pontos interativos. Tudo procedural (sem assets externos).

const WORLD_LAYER := 1
## Paredes invisíveis que só bloqueiam o jogador (o raycast de interação as ignora).
const PLAYER_BLOCK_LAYER := 16

const ROOM_MIN := Vector3(-6.0, 0.0, -2.6)
const ROOM_MAX := Vector3(6.0, 3.2, 6.2)
const COUNTER_TOP := 1.05
const BACK_TOP := 0.95
const SEAT_XS := [-2.4, -0.8, 0.8, 2.4]
const PREP_XS := [-1.6, 0.0, 1.6]

var seats: Array[Seat] = []
var dispensers: Dictionary = {} # bev id -> BottleDispenser
var prep_stations: Array[PrepStation] = []
var glass_stacks: Array[GlassStack] = []
var sink: TrashBin
var player_spawn := Vector3(0, 0.05, -1.1)
var door_inside := Vector3(3.0, 0, 5.3)
var door_outside := Vector3(3.0, 0, 8.0)
var spinners: Array[Node3D] = []
var clock_hand_h: Node3D
var clock_hand_m: Node3D

var _wall_mat: ShaderMaterial
var _wood := Color(0.55, 0.3, 0.16)
var _wood_dark := Color(0.36, 0.19, 0.1)


func build() -> void:
	_wall_mat = BarShaders.material(BarShaders.WALL)
	_build_environment()
	_build_room()
	_build_main_counter()
	_build_back_area()
	_build_fridge()
	_build_menu_board()
	_build_customer_area()
	_build_decor()
	_build_lights()
	_build_seats()
	merge_static_meshes(self)


# =================================================================== ambiente

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.04, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.62, 0.45)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.38, 0.25)
	env.fog_density = 0.012
	we.environment = env
	add_child(we)


# =================================================================== arquitetura

func _solid(size: Vector3, pos: Vector3, layer := WORLD_LAYER) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	add_child(body)
	return body


func _wall(size: Vector3, pos: Vector3) -> void:
	var body := _solid(size, pos)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _wall_mat
	body.add_child(mi)


func _build_room() -> void:
	var size := ROOM_MAX - ROOM_MIN
	var center := (ROOM_MAX + ROOM_MIN) / 2.0
	# piso de caquinhos
	var floor_body := _solid(Vector3(size.x, 0.2, size.z + 3.0), Vector3(center.x, -0.1, center.z + 1.5))
	var floor_mesh := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(size.x, 0.2, size.z)
	floor_mesh.mesh = fm
	floor_mesh.position.z = -1.5
	floor_mesh.material_override = BarShaders.floor_texture_material() if GameManager.low_end else BarShaders.material(BarShaders.FLOOR)
	floor_body.add_child(floor_mesh)
	# teto de madeira com vigas
	Mats.box(self, Vector3(size.x, 0.1, size.z), Vector3(center.x, ROOM_MAX.y + 0.05, center.z), Color(0.5, 0.32, 0.2), false)
	for i in 7:
		Mats.box(self, Vector3(size.x, 0.14, 0.14), Vector3(center.x, ROOM_MAX.y - 0.07, ROOM_MIN.z + 0.6 + i * 1.3), _wood_dark, false)
	# paredes
	var t := 0.2
	_wall(Vector3(size.x, size.y, t), Vector3(center.x, size.y / 2.0, ROOM_MIN.z - t / 2.0)) # fundo
	_wall(Vector3(t, size.y, size.z), Vector3(ROOM_MIN.x - t / 2.0, size.y / 2.0, center.z)) # esquerda
	_wall(Vector3(t, size.y, size.z), Vector3(ROOM_MAX.x + t / 2.0, size.y / 2.0, center.z)) # direita
	# parede da frente com vão da porta de enrolar (x 2.2..3.8, até 2.4 m)
	var fz := ROOM_MAX.z + t / 2.0
	_wall(Vector3(8.2, size.y, t), Vector3(-1.9, size.y / 2.0, fz))
	_wall(Vector3(2.2, size.y, t), Vector3(4.9, size.y / 2.0, fz))
	_wall(Vector3(1.6, 0.8, t), Vector3(3.0, 2.8, fz))
	# divisórias atrás do balcão (limitam a área do jogador)
	_wall(Vector3(t, size.y, 2.95), Vector3(-3.95 - t / 2.0, size.y / 2.0, -1.125))
	_wall(Vector3(t, size.y, 2.95), Vector3(3.95 + t / 2.0, size.y / 2.0, -1.125))
	# a rua lá fora
	var street := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(14, 6)
	street.mesh = q
	street.position = Vector3(3.0, 2.0, 10.5)
	street.rotation_degrees.y = 180
	street.material_override = BarShaders.material(BarShaders.STREET)
	add_child(street)
	Mats.box(self, Vector3(6, 0.1, 4), Vector3(3.0, -0.04, 8.4), Color(0.45, 0.45, 0.48), false)
	_build_door()


func _build_door() -> void:
	var d := Node3D.new()
	d.position = Vector3(3.0, 0, ROOM_MAX.z + 0.1)
	add_child(d)
	# batente de metal e a porta de enrolar recolhida lá em cima
	Mats.box(d, Vector3(0.12, 2.4, 0.3), Vector3(-0.86, 1.2, 0), Color(0.45, 0.48, 0.5))
	Mats.box(d, Vector3(0.12, 2.4, 0.3), Vector3(0.86, 1.2, 0), Color(0.45, 0.48, 0.5))
	var roll := Mats.cylinder(d, 0.2, 1.84, Vector3(0, 2.25, 0.05), Color(0.55, 0.58, 0.6))
	roll.rotation_degrees.z = 90
	for i in 3:
		Mats.box(d, Vector3(1.6, 0.06, 0.04), Vector3(0, 2.05 - i * 0.07, 0.12), Color(0.5, 0.52, 0.55), false)
	# poste de luz lá fora
	Mats.cylinder(self, 0.06, 4.0, Vector3(5.6, 2.0, 9.2), Color(0.3, 0.3, 0.32))
	Mats.sphere(self, 0.2, Vector3(5.6, 4.0, 9.2), Color(1.0, 0.85, 0.5), false).material_override = Mats.toon(Color(1.0, 0.85, 0.5), false, 0.5, 3.0)
	var street_light := OmniLight3D.new()
	street_light.position = Vector3(5.6, 3.8, 9.0)
	street_light.light_color = Color(1.0, 0.75, 0.4)
	street_light.light_energy = 2.0
	street_light.omni_range = 7.0
	add_child(street_light)
	_omni(street_light)


# =================================================================== balcão principal

func _build_main_counter() -> void:
	var length := 7.9
	var body := _solid(Vector3(length, COUNTER_TOP, 0.7), Vector3(0, COUNTER_TOP / 2.0, 0))
	# corpo com azulejo verde na frente (lado do cliente)
	var front := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(length, COUNTER_TOP - 0.06, 0.66)
	front.mesh = fm
	front.position.y = -0.03
	front.material_override = BarShaders.material(BarShaders.WALL, {
		"tile_a": Color(0.18, 0.5, 0.38), "tile_b": Color(0.24, 0.6, 0.45), "tile_top": 5.0, "tile_size": 0.12})
	body.add_child(front)
	# tampo de madeira envernizada com borda
	Mats.box(self, Vector3(length + 0.1, 0.07, 0.92), Vector3(0, COUNTER_TOP + 0.005, 0.03), _wood)
	Mats.box(self, Vector3(length + 0.12, 0.05, 0.06), Vector3(0, COUNTER_TOP - 0.02, 0.5), _wood_dark)
	# rodapé de madeira e apoio de pé cromado
	Mats.box(self, Vector3(length, 0.12, 0.04), Vector3(0, 0.06, 0.36), _wood_dark, false)
	var bar := Mats.cylinder(self, 0.025, length - 0.2, Vector3(0, 0.25, 0.48), Color(0.8, 0.8, 0.85), false)
	bar.rotation_degrees.z = 90
	for x in [-3.6, -1.2, 1.2, 3.6]:
		Mats.box(self, Vector3(0.04, 0.22, 0.12), Vector3(x, 0.17, 0.42), Color(0.75, 0.75, 0.8), false)
	# estações de preparo (lado do jogador)
	for i in PREP_XS.size():
		var p := PrepStation.create(i)
		p.position = Vector3(PREP_XS[i], COUNTER_TOP + 0.04, -0.17)
		add_child(p)
		prep_stations.append(p)
	# estufa de salgados na ponta do balcão
	_build_snack_case(Vector3(3.45, COUNTER_TOP + 0.04, 0.05))
	# porta-guardanapo e amendoim na frente de cada banqueta
	for x: float in SEAT_XS:
		_napkin_holder(Vector3(x + 0.3, COUNTER_TOP + 0.04, 0.3))
		_peanut_bowl(Vector3(x - 0.3, COUNTER_TOP + 0.04, 0.28))


func _build_snack_case(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	Mats.box(n, Vector3(0.75, 0.04, 0.55), Vector3(0, 0.02, 0), Color(0.75, 0.75, 0.78))
	var glass := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.73, 0.38, 0.53)
	glass.mesh = gm
	glass.position.y = 0.23
	glass.material_override = Mats.glass(Color(0.85, 0.95, 1.0), 0.18)
	n.add_child(glass)
	Mats.box(n, Vector3(0.75, 0.03, 0.55), Vector3(0, 0.43, 0), Color(0.75, 0.75, 0.78))
	var lamp := Mats.box(n, Vector3(0.6, 0.02, 0.04), Vector3(0, 0.41, 0), Color(1.0, 0.8, 0.5), false)
	lamp.material_override = Mats.toon(Color(1.0, 0.75, 0.4), false, 0.5, 2.5)
	# coxinhas e pastéis
	for i in 6:
		var x := -0.25 + (i % 3) * 0.25
		var z := -0.1 + (i / 3) * 0.2
		if i % 2 == 0:
			var cox := Mats.sphere(n, 0.055, Vector3(x, 0.1, z), Color(0.85, 0.5, 0.18), false, Vector3(1.0, 0.9, 1.0))
			Mats.cylinder(n, 0.045, 0.08, Vector3(x, 0.17, z), Color(0.85, 0.5, 0.18), false, 0.008)
			cox.name = "Coxinha"
		else:
			Mats.box(n, Vector3(0.16, 0.035, 0.09), Vector3(x, 0.07, z), Color(0.95, 0.75, 0.35), false)
	var tag := Mats.label3d(n, "SALGADOS", Vector3(0, 0.25, 0.28), 30, UiTheme.RED, 6)
	tag.pixel_size = 0.0016


func _napkin_holder(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	Mats.box(n, Vector3(0.12, 0.02, 0.07), Vector3(0, 0.01, 0), Color(0.8, 0.8, 0.82), false)
	Mats.box(n, Vector3(0.11, 0.09, 0.05), Vector3(0, 0.06, 0), Color.WHITE, false)
	Mats.box(n, Vector3(0.12, 0.1, 0.008), Vector3(0, 0.06, 0.03), Color(0.8, 0.8, 0.82), false)


func _peanut_bowl(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	Mats.cylinder(n, 0.07, 0.04, Vector3(0, 0.02, 0), Color(0.95, 0.95, 0.9), false, 0.09)
	for i in 6:
		var a := i * 1.1
		Mats.sphere(n, 0.018, Vector3(cos(a) * 0.035, 0.045, sin(a) * 0.035), Color(0.75, 0.45, 0.25), false, Vector3(1.4, 1, 1))


# =================================================================== área de trabalho (atrás do jogador)

func _build_back_area() -> void:
	var x0 := -3.95
	var x1 := 2.75
	var w := x1 - x0
	var cx := (x0 + x1) / 2.0
	var z := -2.27
	var body := _solid(Vector3(w, BACK_TOP, 0.66), Vector3(cx, BACK_TOP / 2.0, z))
	var front := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(w, BACK_TOP, 0.66)
	front.mesh = fm
	front.material_override = Mats.toon(_wood_dark)
	body.add_child(front)
	# portinhas do armário
	for i in int(w / 0.6):
		Mats.box(self, Vector3(0.52, 0.7, 0.02), Vector3(x0 + 0.33 + i * 0.6, 0.45, z + 0.335), _wood, false)
		Mats.sphere(self, 0.018, Vector3(x0 + 0.53 + i * 0.6, 0.6, z + 0.35), Color(0.85, 0.7, 0.3), false)
	Mats.box(self, Vector3(w + 0.04, 0.05, 0.7), Vector3(cx, BACK_TOP + 0.025, z), Color(0.22, 0.24, 0.26))
	var top := BACK_TOP + 0.05
	# pia
	sink = TrashBin.create()
	sink.position = Vector3(-3.35, top, z + 0.05)
	add_child(sink)
	# copos
	for gx in [-2.35, 1.95]:
		var g := GlassStack.create()
		g.position = Vector3(gx, top, z + 0.12)
		add_child(g)
		glass_stacks.append(g)
	# bebidas da bancada (jarras preparadas na hora)
	var counter_x := -0.55
	for bev in BeverageDatabase.all():
		if bev.station == &"counter":
			_add_dispenser(bev, Vector3(counter_x, top, z + 0.1))
			counter_x += 0.55
	# decoração da bancada: liquidificador, tábua com limões, caixa registradora
	_blender(Vector3(counter_x + 0.05, top, z - 0.05))
	_lime_board(Vector3(-1.2, top, z + 0.05))
	_register(Vector3(1.2, top, z - 0.05))
	# prateleiras na parede do fundo
	for i in 2:
		var y := 1.42 + i * 0.45
		Mats.box(self, Vector3(4.6, 0.04, 0.26), Vector3(-1.2, y, -2.47), _wood)
		for bx in [-3.4, 1.0]:
			Mats.box(self, Vector3(0.03, 0.12, 0.2), Vector3(bx, y - 0.07, -2.5), _wood_dark, false)
	var shelf_x := -1.25
	for bev in BeverageDatabase.all():
		if bev.station == &"shelf":
			_add_dispenser(bev, Vector3(shelf_x, 1.44, -2.45))
			shelf_x += 0.6
	# garrafas decorativas
	var deco := [Color(0.5, 0.3, 0.1), Color(0.2, 0.45, 0.2), Color(0.85, 0.85, 0.9), Color(0.6, 0.15, 0.1),
		Color(0.9, 0.6, 0.1), Color(0.3, 0.2, 0.5)]
	for i in 14:
		var px := -3.2 + i * 0.32
		var py := 1.44 if i % 2 == 0 else 1.89
		if py < 1.5 and px > -1.5 and px < 0.4:
			continue
		_deco_bottle(Vector3(px + randf_range(-0.05, 0.05), py, -2.48), deco[i % deco.size()])
	_radio(Vector3(0.6, 1.91, -2.45))
	_trophy(Vector3(-2.1, 1.91, -2.45))


func _add_dispenser(bev: BeverageData, pos: Vector3) -> BottleDispenser:
	var d := BottleDispenser.create(bev)
	d.position = pos
	add_child(d)
	dispensers[bev.id] = d
	return d


func _deco_bottle(pos: Vector3, c: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	var h := randf_range(0.22, 0.32)
	n.add_child(_glass_cyl(0.045, h, Vector3(0, h / 2.0, 0), c))
	n.add_child(_glass_cyl(0.017, 0.09, Vector3(0, h + 0.045, 0), c))
	Mats.box(n, Vector3(0.07, 0.07, 0.005), Vector3(0, h * 0.45, 0.046), Color(0.95, 0.92, 0.8), false)


func _glass_cyl(r: float, h: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 12
	mi.mesh = m
	mi.position = pos
	mi.material_override = Mats.glass(c, 0.8)
	return mi


func _blender(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	Mats.box(n, Vector3(0.16, 0.12, 0.16), Vector3(0, 0.06, 0), Color(0.9, 0.9, 0.92))
	var cup := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.075
	m.bottom_radius = 0.055
	m.height = 0.22
	cup.mesh = m
	cup.position.y = 0.23
	cup.material_override = Mats.glass(Color(1.0, 0.7, 0.85), 0.4)
	n.add_child(cup)
	Mats.cylinder(n, 0.08, 0.03, Vector3(0, 0.355, 0), Color(0.2, 0.2, 0.22), false)


func _lime_board(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	Mats.box(n, Vector3(0.36, 0.025, 0.22), Vector3(0, 0.012, 0), Color(0.75, 0.55, 0.35))
	for i in 5:
		Mats.sphere(n, 0.03, Vector3(-0.12 + i * 0.06, 0.045, sin(i * 2.0) * 0.05), Color(0.4, 0.78, 0.15), false, Vector3(1.2, 1, 1))
	var knife := Mats.box(n, Vector3(0.18, 0.006, 0.025), Vector3(0.05, 0.03, 0.08), Color(0.8, 0.8, 0.85), false)
	knife.rotation_degrees.y = 20


func _register(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	Mats.box(n, Vector3(0.36, 0.14, 0.3), Vector3(0, 0.07, 0), Color(0.75, 0.2, 0.18))
	var top := Mats.box(n, Vector3(0.34, 0.12, 0.16), Vector3(0, 0.18, -0.05), Color(0.8, 0.25, 0.2))
	top.rotation_degrees.x = -25
	Mats.box(n, Vector3(0.18, 0.06, 0.02), Vector3(0, 0.27, -0.1), Color(0.15, 0.3, 0.15), false)
	Mats.label3d(n, "R$", Vector3(0, 0.08, 0.152), 40, UiTheme.MUSTARD, 6).pixel_size = 0.0015


func _radio(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	Mats.box(n, Vector3(0.32, 0.18, 0.12), Vector3(0, 0.09, 0), Color(0.55, 0.35, 0.2))
	Mats.cylinder(n, 0.055, 0.01, Vector3(-0.07, 0.09, 0.062), Color(0.2, 0.15, 0.12), false).rotation_degrees.x = 90
	Mats.box(n, Vector3(0.1, 0.05, 0.01), Vector3(0.08, 0.12, 0.062), Color(1.0, 0.85, 0.5), false)
	var antenna := Mats.cylinder(n, 0.005, 0.3, Vector3(0.1, 0.32, 0), Color(0.8, 0.8, 0.85), false)
	antenna.rotation_degrees.z = -25


func _trophy(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	Mats.box(n, Vector3(0.12, 0.05, 0.12), Vector3(0, 0.025, 0), Color(0.3, 0.2, 0.12))
	Mats.cylinder(n, 0.015, 0.1, Vector3(0, 0.1, 0), Color(1.0, 0.8, 0.2), false)
	Mats.cylinder(n, 0.07, 0.1, Vector3(0, 0.2, 0), Color(1.0, 0.8, 0.2), true, 0.09)


# =================================================================== geladeira

func _build_fridge() -> void:
	var f := Node3D.new()
	f.name = "Fridge"
	f.position = Vector3(3.35, 0, -2.25)
	add_child(f)
	var w := 1.1
	var h := 2.0
	var d := 0.7
	var red := Color(0.85, 0.15, 0.15)
	# carcaça (aberta na frente) + colisão
	_solid(Vector3(w, h, 0.25), Vector3(3.35, h / 2.0, -2.475))
	_solid(Vector3(w, h, 0.25), Vector3(3.35, h / 2.0, -1.85), PLAYER_BLOCK_LAYER)
	Mats.box(f, Vector3(w, 0.08, d), Vector3(0, h - 0.04, 0), red)
	Mats.box(f, Vector3(w, 0.3, d), Vector3(0, 0.15, 0), red)
	Mats.box(f, Vector3(0.06, h, d), Vector3(-w / 2.0 + 0.03, h / 2.0, 0), red)
	Mats.box(f, Vector3(0.06, h, d), Vector3(w / 2.0 - 0.03, h / 2.0, 0), red)
	var back := Mats.box(f, Vector3(w, h, 0.04), Vector3(0, h / 2.0, -d / 2.0 + 0.02), Color(0.92, 0.95, 1.0), false)
	back.material_override = Mats.toon(Color(0.85, 0.92, 1.0), false, 0.4, 0.35)
	# letreiro no topo
	var sign := Mats.box(f, Vector3(w, 0.32, 0.06), Vector3(0, h + 0.16, 0.3), red)
	sign.name = "Sign"
	Mats.label3d(f, "GELADA", Vector3(0, h + 0.16, 0.335), 70, UiTheme.PAPER, 10).pixel_size = 0.0022
	# prateleiras aramadas
	var shelves := [0.6, 1.02, 1.44]
	for y: float in shelves:
		Mats.box(f, Vector3(w - 0.12, 0.02, d - 0.12), Vector3(0, y, 0), Color(0.75, 0.78, 0.82), false)
	# porta de vidro (sem colisão de raycast)
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(w - 0.08, h - 0.4, 0.02)
	door.mesh = dm
	door.position = Vector3(0, 1.08, d / 2.0)
	door.material_override = Mats.glass(Color(0.8, 0.95, 1.0), 0.14)
	door.set_meta("no_highlight", true)
	f.add_child(door)
	Mats.box(f, Vector3(0.04, 0.5, 0.05), Vector3(w / 2.0 - 0.1, 1.1, d / 2.0 + 0.03), Color(0.85, 0.85, 0.9), false)
	# luz interna
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.6, 0.1)
	light.light_color = Color(0.75, 0.9, 1.0)
	light.light_energy = 0.8
	light.omni_range = 1.4
	f.add_child(light)
	_omni(light)
	# bebidas geladas interativas na prateleira do meio
	var slot := -0.22
	for bev in BeverageDatabase.all():
		if bev.station == &"fridge":
			var disp := BottleDispenser.create(bev)
			disp.position = Vector3(slot, shelves[1] + 0.01, 0.12)
			f.add_child(disp)
			dispensers[bev.id] = disp
			# estoque decorativo da mesma bebida nas outras prateleiras
			for sy: float in [shelves[0], shelves[2]]:
				for k in 2:
					var deco := BeverageModels.build_container(bev)
					deco.position = Vector3(slot - 0.08 + k * 0.16, sy + 0.01, -0.05 - k * 0.05)
					f.add_child(deco)
			slot += 0.44


# =================================================================== cardápio de giz

func _build_menu_board() -> void:
	var n := Node3D.new()
	n.position = Vector3(-1.2, 2.55, -2.56)
	add_child(n)
	Mats.box(n, Vector3(3.2, 0.95, 0.04), Vector3.ZERO, _wood_dark)
	Mats.box(n, Vector3(3.05, 0.82, 0.02), Vector3(0, 0, 0.02), UiTheme.CHALK, false)
	Mats.label3d(n, "CARDÁPIO", Vector3(0, 0.3, 0.035), 64, UiTheme.MUSTARD, 0).pixel_size = 0.0022
	var i := 0
	for bev in BeverageDatabase.all():
		var col := i % 3
		var row := i / 3
		var pos := Vector3(-1.1 + col * 1.05, 0.05 - row * 0.28, 0.035)
		var sym := MeshInstance3D.new()
		sym.mesh = Mats.flat_polygon_mesh(SymbolShapes.polygon(bev.symbol), 0.07)
		sym.material_override = Mats.unshaded(bev.color if bev.color.get_luminance() < 0.85 else Color(0.7, 0.85, 1.0))
		sym.position = pos
		n.add_child(sym)
		var l := Mats.label3d(n, "%s  %s  R$%d" % [bev.letter, bev.display_name, bev.price], pos + Vector3(0.1, 0, 0), 34, Color(0.95, 0.95, 0.9), 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.pixel_size = 0.0017
		i += 1


# =================================================================== salão

func _build_customer_area() -> void:
	_plastic_table(Vector3(-4.6, 0, 2.3), Color(1.0, 0.82, 0.1))
	_plastic_table(Vector3(-1.7, 0, 4.7), Color(0.9, 0.15, 0.15))
	_plastic_table(Vector3(5.0, 0, 2.5), Color(1.0, 0.82, 0.1))
	_plastic_table(Vector3(5.0, 0, 4.6), Color(0.9, 0.15, 0.15))
	_pool_table(Vector3(-4.3, 0, 4.6))
	_crates(Vector3(5.2, 0, -1.6))
	_crates(Vector3(-5.3, 0, -0.8))


func _plastic_table(pos: Vector3, c: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	Mats.cylinder(n, 0.5, 0.04, Vector3(0, 0.72, 0), c)
	for k in 4:
		var a := k * TAU / 4.0 + PI / 4.0
		var leg := Mats.cylinder(n, 0.03, 0.74, Vector3(cos(a) * 0.36, 0.36, sin(a) * 0.36), c, false)
		leg.rotation = Vector3(sin(a) * 0.15, 0, -cos(a) * 0.15)
	# cadeiras de plástico
	for k in 3:
		var a := k * TAU / 3.0 + 0.4
		_plastic_chair(n, Vector3(cos(a) * 0.85, 0, sin(a) * 0.85), -a + PI / 2.0, c)
	# garrafa e copos em cima
	var beer := BeverageModels.build_container(BeverageDatabase.get_beverage(&"cerveja"))
	beer.scale = Vector3.ONE * 1.6
	beer.position = Vector3(0.05, 0.74, 0)
	n.add_child(beer)
	for k in 2:
		var g := BeverageModels.build_glass(BeverageDatabase.get_beverage(&"cerveja"))
		g.scale = Vector3.ONE * 1.3
		g.position = Vector3(-0.2 + k * 0.4, 0.74, 0.18)
		n.add_child(g)
	_peanut_bowl_on(n, Vector3(-0.15, 0.74, -0.2))
	_solid(Vector3(1.0, 0.75, 1.0), pos + Vector3(0, 0.375, 0), PLAYER_BLOCK_LAYER)


func _peanut_bowl_on(parent: Node3D, pos: Vector3) -> void:
	Mats.cylinder(parent, 0.09, 0.04, pos + Vector3(0, 0.02, 0), Color(0.95, 0.95, 0.9), false, 0.11)
	for i in 5:
		Mats.sphere(parent, 0.022, pos + Vector3(cos(i) * 0.04, 0.045, sin(i) * 0.04), Color(0.75, 0.45, 0.25), false)


func _plastic_chair(parent: Node3D, pos: Vector3, yaw: float, c: Color) -> void:
	var ch := Node3D.new()
	ch.position = pos
	ch.rotation.y = yaw
	parent.add_child(ch)
	Mats.box(ch, Vector3(0.44, 0.04, 0.42), Vector3(0, 0.44, 0), c)
	var back := Mats.box(ch, Vector3(0.44, 0.42, 0.04), Vector3(0, 0.66, 0.2), c)
	back.rotation_degrees.x = -8
	for sx in [-0.19, 0.19]:
		for sz in [-0.18, 0.18]:
			Mats.cylinder(ch, 0.02, 0.44, Vector3(sx, 0.22, sz), c, false)


func _pool_table(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = 90
	add_child(n)
	Mats.box(n, Vector3(2.0, 0.12, 1.1), Vector3(0, 0.78, 0), _wood_dark)
	Mats.box(n, Vector3(1.8, 0.02, 0.9), Vector3(0, 0.85, 0), Color(0.1, 0.5, 0.25), false)
	for sx in [-0.85, 0.85]:
		for sz in [-0.45, 0.45]:
			Mats.box(n, Vector3(0.12, 0.72, 0.12), Vector3(sx, 0.36, sz), _wood_dark)
	var ball_colors := [Color.WHITE, Color(1, 0.8, 0.1), Color(0.1, 0.2, 0.8), Color(0.85, 0.1, 0.1), Color(0.1, 0.1, 0.1), Color(0.5, 0.1, 0.6)]
	for i in ball_colors.size():
		Mats.sphere(n, 0.03, Vector3(-0.3 + (i % 3) * 0.08 + i * 0.05, 0.89, -0.1 + (i / 3) * 0.08), ball_colors[i], false)
	var cue := Mats.cylinder(n, 0.012, 1.4, Vector3(0.2, 0.9, 0.3), Color(0.85, 0.7, 0.45), false, 0.007)
	cue.rotation_degrees = Vector3(0, 20, 88)
	_solid(Vector3(1.1, 0.9, 2.0), pos + Vector3(0, 0.45, 0), PLAYER_BLOCK_LAYER)


func _crates(pos: Vector3) -> void:
	for i in 3:
		var c := Node3D.new()
		c.position = pos + Vector3((i % 2) * 0.05, i * 0.3, 0)
		c.rotation_degrees.y = i * 7.0
		add_child(c)
		var col := Color(0.95, 0.75, 0.1) if i % 2 == 0 else Color(0.85, 0.15, 0.15)
		Mats.box(c, Vector3(0.6, 0.3, 0.42), Vector3(0, 0.15, 0), col)
		for k in 6:
			var b := Node3D.new()
			b.position = Vector3(-0.2 + (k % 3) * 0.2, 0.3, -0.1 + (k / 3) * 0.2)
			c.add_child(b)
			Mats.cylinder(b, 0.012, 0.08, Vector3(0, 0.03, 0), Color(0.35, 0.18, 0.06), false)


# =================================================================== decoração

func _build_decor() -> void:
	# letreiro do bar na parede da frente (o jogador vê enquanto atende)
	var sign := Node3D.new()
	sign.position = Vector3(-1.2, 2.45, ROOM_MAX.z - 0.03)
	sign.rotation_degrees.y = 180
	add_child(sign)
	Mats.box(sign, Vector3(3.6, 0.9, 0.06), Vector3.ZERO, Color(0.12, 0.08, 0.16))
	var title := Mats.label3d(sign, "BAR DO PINGUÇO", Vector3(0, 0.07, 0.04), 150, Color(1.0, 0.82, 0.3), 24)
	title.pixel_size = 0.0028
	title.modulate = Color(1.6, 1.15, 0.45)
	var sub := Mats.label3d(sign, "desde 1987  •  gelada de verdade", Vector3(0, -0.28, 0.04), 60, Color(1.0, 0.45, 0.6), 10)
	sub.pixel_size = 0.0022
	sub.modulate = Color(1.6, 0.6, 0.8)
	var sign_light := OmniLight3D.new()
	sign_light.position = Vector3(-1.2, 2.4, ROOM_MAX.z - 0.6)
	sign_light.light_color = Color(1.0, 0.6, 0.4)
	sign_light.light_energy = 0.8
	sign_light.omni_range = 2.5
	add_child(sign_light)
	_omni(sign_light)

	# TV no suporte, passando o jogo
	var tv := Node3D.new()
	tv.position = Vector3(5.55, 2.35, 1.4)
	tv.rotation_degrees.y = -115
	add_child(tv)
	Mats.box(tv, Vector3(1.05, 0.65, 0.12), Vector3.ZERO, Color(0.1, 0.1, 0.12))
	var screen := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.95, 0.55)
	screen.mesh = q
	screen.position.z = 0.065
	screen.material_override = BarShaders.material(BarShaders.TV)
	tv.add_child(screen)
	Mats.box(self, Vector3(0.3, 0.06, 0.06), Vector3(5.85, 2.35, 1.4), Color(0.3, 0.3, 0.32))

	# cartazes
	_poster(Vector3(-5.97, 1.9, 1.6), 90, "FIADO?\nSÓ AMANHÃ!", Color(1.0, 0.95, 0.75), UiTheme.RED)
	_poster(Vector3(-5.97, 1.85, 3.6), 90, "PROIBIDO\nFALAR DE\nPOLÍTICA", Color(0.98, 0.85, 0.3), UiTheme.INK)
	_poster(Vector3(5.97, 1.9, 3.6), -90, "TEM\nTORRESMO", Color(0.95, 0.4, 0.2), UiTheme.PAPER)
	_poster(Vector3(1.3, 1.95, ROOM_MAX.z - 0.03), 180, "CERVEJA\nESTUPIDAMENTE\nGELADA", Color(0.2, 0.45, 0.85), UiTheme.PAPER)
	_poster(Vector3(-3.97, 1.95, -1.4), 90, "PENDURA\nNÃO!", Color(0.95, 0.95, 0.9), UiTheme.RED)
	_pennant(Vector3(-5.96, 2.5, 2.6), 90)
	_calendar(Vector3(3.93, 1.75, -1.1), -90)
	_wall_clock(Vector3(3.93, 2.5, -0.9), -90)
	_bead_curtain(Vector3(-3.97, 0, -1.0))

	# bandeirinhas de festa junina atravessando o teto
	for line in 4:
		var z := 0.8 + line * 1.4
		_bunting(Vector3(-5.8, 2.85, z), Vector3(5.8, 2.85, z + 0.3))

	# ventiladores de teto
	for p in [Vector3(-2.5, 3.2, 3.2), Vector3(2.0, 3.2, 3.6)]:
		_fan(p)


func _poster(pos: Vector3, yaw: float, text: String, bg: Color, fg: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	var lines := text.count("\n") + 1
	var h := 0.22 + lines * 0.16
	var board := Mats.box(n, Vector3(0.8, h, 0.02), Vector3.ZERO, bg)
	board.rotation_degrees.z = randf_range(-3.0, 3.0)
	var l := Mats.label3d(n, text, Vector3(0, 0, 0.015), 64, fg, 0)
	l.pixel_size = 0.0021
	l.rotation_degrees.z = board.rotation_degrees.z
	l.width = 340
	l.autowrap_mode = TextServer.AUTOWRAP_OFF


func _pennant(pos: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	var tri := MeshInstance3D.new()
	tri.mesh = Mats.flat_polygon_mesh(PackedVector2Array([Vector2(-1, -0.45), Vector2(1, 0), Vector2(-1, 0.45)]), 0.45)
	tri.material_override = Mats.unshaded(Color(0.1, 0.1, 0.1))
	n.add_child(tri)
	var inner := MeshInstance3D.new()
	inner.mesh = Mats.flat_polygon_mesh(PackedVector2Array([Vector2(-0.9, -0.36), Vector2(0.8, 0), Vector2(-0.9, 0.36)]), 0.45)
	inner.material_override = Mats.unshaded(Color.WHITE)
	inner.position.z = 0.004
	n.add_child(inner)
	var l := Mats.label3d(n, "TIMÃO DA VILA", Vector3(-0.05, 0, 0.01), 40, Color(0.1, 0.1, 0.1), 0)
	l.pixel_size = 0.0018


func _calendar(pos: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	Mats.box(n, Vector3(0.42, 0.6, 0.01), Vector3.ZERO, Color(0.98, 0.98, 0.95))
	Mats.box(n, Vector3(0.42, 0.22, 0.012), Vector3(0, 0.19, 0), Color(0.2, 0.6, 0.9), false)
	Mats.label3d(n, "MERCADINHO\nDA DONA ROSA", Vector3(0, 0.19, 0.01), 26, UiTheme.PAPER, 0).pixel_size = 0.0016
	Mats.label3d(n, "OUTUBRO", Vector3(0, 0.0, 0.01), 30, UiTheme.RED, 0).pixel_size = 0.0016
	for r in 3:
		for c in 6:
			Mats.box(n, Vector3(0.045, 0.035, 0.012), Vector3(-0.15 + c * 0.06, -0.08 - r * 0.06, 0), Color(0.85, 0.85, 0.82), false)


func _wall_clock(pos: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.name = "Clock"
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	var face := Mats.cylinder(n, 0.22, 0.04, Vector3.ZERO, Color(0.98, 0.97, 0.92))
	face.rotation_degrees.x = 90
	for i in 12:
		var a := i * TAU / 12.0
		Mats.box(n, Vector3(0.02, 0.04, 0.01), Vector3(sin(a) * 0.18, cos(a) * 0.18, 0.025), UiTheme.INK, false).rotation.z = -a
	clock_hand_h = Node3D.new()
	clock_hand_h.position.z = 0.03
	n.add_child(clock_hand_h)
	Mats.box(clock_hand_h, Vector3(0.022, 0.11, 0.008), Vector3(0, 0.05, 0), UiTheme.INK, false)
	clock_hand_m = Node3D.new()
	clock_hand_m.position.z = 0.035
	n.add_child(clock_hand_m)
	Mats.box(clock_hand_m, Vector3(0.014, 0.16, 0.008), Vector3(0, 0.075, 0), UiTheme.RED, false)


func set_clock(hours: float) -> void:
	if clock_hand_h:
		clock_hand_h.rotation.z = -fmod(hours, 12.0) / 12.0 * TAU
		clock_hand_m.rotation.z = -fmod(hours, 1.0) * TAU


func _bead_curtain(pos: Vector3) -> void:
	# cortina de miçanga da "cozinha" (porta falsa na divisória)
	var colors := [Color(0.95, 0.3, 0.3), Color(1.0, 0.8, 0.2), Color(0.2, 0.7, 0.4), Color(0.3, 0.5, 0.95)]
	Mats.box(self, Vector3(0.1, 2.1, 0.9), Vector3(pos.x + 0.02, 1.05, pos.z), Color(0.3, 0.12, 0.08), false)
	Mats.box(self, Vector3(0.12, 0.1, 1.05), Vector3(pos.x + 0.04, 2.15, pos.z), _wood_dark)
	for side in [-1.0, 1.0]:
		Mats.box(self, Vector3(0.12, 2.2, 0.08), Vector3(pos.x + 0.04, 1.1, pos.z + side * 0.49), _wood_dark)
	var sign := Mats.label3d(self, "COZINHA", Vector3(pos.x + 0.11, 2.15, pos.z), 40, UiTheme.MUSTARD, 6)
	sign.rotation_degrees.y = 90
	for i in 7:
		for k in 12:
			Mats.sphere(self, 0.018, Vector3(pos.x + 0.09, 2.0 - k * 0.16, pos.z - 0.36 + i * 0.12), colors[(i + k) % 4], false)


func _bunting(a: Vector3, b: Vector3) -> void:
	var colors := [Color(0.95, 0.2, 0.25), Color(1.0, 0.8, 0.15), Color(0.2, 0.65, 0.3), Color(0.2, 0.45, 0.95), Color(0.95, 0.45, 0.75), Color(1.0, 0.55, 0.15)]
	var count := 26
	for i in count:
		var t := (i + 0.5) / count
		var p := a.lerp(b, t)
		p.y -= sin(t * PI) * 0.35
		var flag := MeshInstance3D.new()
		flag.mesh = Mats.flat_polygon_mesh(PackedVector2Array([Vector2(-1, -0.2), Vector2(1, -0.2), Vector2(0, 1.2)]), 0.11)
		flag.material_override = Mats.unshaded(colors[i % colors.size()])
		flag.position = p
		flag.rotation.y = atan2(b.x - a.x, b.z - a.z) + PI / 2.0
		flag.rotation.z = randf_range(-0.12, 0.12)
		add_child(flag)
	# cordão
	var dir := b - a
	for i in 12:
		var t0 := float(i) / 12.0
		var t1 := float(i + 1) / 12.0
		var p0 := a.lerp(b, t0) - Vector3(0, sin(t0 * PI) * 0.35, 0)
		var p1 := a.lerp(b, t1) - Vector3(0, sin(t1 * PI) * 0.35, 0)
		var seg := Mats.cylinder(self, 0.006, p0.distance_to(p1), (p0 + p1) / 2.0, Color(0.9, 0.9, 0.85), false)
		seg.look_at_from_position((p0 + p1) / 2.0, p1, Vector3.UP if absf(dir.normalized().y) < 0.9 else Vector3.RIGHT)
		seg.rotate_object_local(Vector3.RIGHT, PI / 2.0)


func _fan(pos: Vector3) -> void:
	var base := Node3D.new()
	base.position = pos
	add_child(base)
	Mats.cylinder(base, 0.02, 0.4, Vector3(0, -0.2, 0), Color(0.3, 0.3, 0.3), false)
	Mats.cylinder(base, 0.12, 0.12, Vector3(0, -0.45, 0), Color(0.85, 0.85, 0.8))
	var spinner := Spinner.new()
	spinner.position.y = -0.48
	spinner.speed = 7.0
	base.add_child(spinner)
	for i in 4:
		var blade := Node3D.new()
		blade.rotation.y = i * TAU / 4.0
		spinner.add_child(blade)
		var b := Mats.box(blade, Vector3(0.7, 0.015, 0.15), Vector3(0.45, 0, 0), _wood)
		b.rotation.x = 0.15
	spinners.append(spinner)


# =================================================================== luzes

## Em GPUs fracas cada OmniLight redesenha a cena; lá usamos uma luz direcional
## quente + ambiente mais forte e mantemos só o brilho visual das lâmpadas.
func _omni(l: OmniLight3D) -> void:
	if GameManager.low_end:
		l.queue_free()


func _build_lights() -> void:
	if GameManager.low_end:
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-62, 160, 0)
		key.light_color = Color(1.0, 0.8, 0.6)
		key.light_energy = 0.55
		add_child(key)
		# Environment mínimo: os efeitos de pós-processamento custavam metade do frame.
		var we := find_children("*", "WorldEnvironment", false, false)[0] as WorldEnvironment
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.85, 0.62, 0.45)
		env.ambient_light_energy = 0.5
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		we.environment = env
	for x in [-2.6, 0.0, 2.6]:
		_bulb(Vector3(x, 2.35, 0.05), Color(1.0, 0.72, 0.42), 0.9, 4.2, x == 0.0)
	_bulb(Vector3(-3.4, 2.4, 3.5), Color(1.0, 0.7, 0.45), 0.8, 4.5, false)
	_bulb(Vector3(3.2, 2.4, 3.8), Color(1.0, 0.7, 0.45), 0.8, 4.5, false)
	# luminária fluorescente sobre a bancada (bebidas legíveis)
	var tube := Mats.box(self, Vector3(1.6, 0.05, 0.08), Vector3(-1.0, 3.08, -1.8), Color(0.95, 1.0, 1.0), false)
	tube.material_override = Mats.toon(Color(0.9, 1.0, 1.0), false, 0.5, 3.0)
	var l := OmniLight3D.new()
	l.position = Vector3(-1.0, 2.7, -1.6)
	l.light_color = Color(0.95, 0.95, 1.0)
	l.light_energy = 0.5
	l.omni_range = 3.2
	add_child(l)
	_omni(l)


func _bulb(pos: Vector3, color: Color, energy: float, rng: float, shadows: bool) -> void:
	var cord_len := ROOM_MAX.y - pos.y
	Mats.cylinder(self, 0.008, cord_len, Vector3(pos.x, pos.y + cord_len / 2.0, pos.z), Color(0.1, 0.1, 0.1), false)
	var shade := Mats.cylinder(self, 0.06, 0.14, pos + Vector3(0, 0.08, 0), Color(0.15, 0.35, 0.25), true, 0.025)
	shade.name = "Shade"
	var bulb := Mats.sphere(self, 0.055, pos, color, false)
	bulb.material_override = Mats.toon(Color(1.0, 0.9, 0.7), false, 0.5, 6.0)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.position = pos - Vector3(0, 0.08, 0)
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 0.8
	l.shadow_enabled = shadows and RenderingServer.get_current_rendering_method() != "gl_compatibility"
	l.shadow_blur = 2.0
	add_child(l)
	_omni(l)


# =================================================================== banquetas

func _build_seats() -> void:
	for i in SEAT_XS.size():
		var x: float = SEAT_XS[i]
		var s := Seat.new()
		s.index = i
		s.position = Vector3(x, 0, 0.9)
		s.approach = Vector3(x, 0, 1.7)
		seats.append(s)
		var stool := Node3D.new()
		stool.position = Vector3(x, 0, 0.9)
		add_child(stool)
		Mats.cylinder(stool, 0.23, 0.03, Vector3(0, 0.015, 0), Color(0.75, 0.75, 0.8))
		Mats.cylinder(stool, 0.035, 0.72, Vector3(0, 0.38, 0), Color(0.8, 0.8, 0.85), false)
		var ring := Mats.torus(stool, 0.15, 0.18, Vector3(0, 0.3, 0), Color(0.8, 0.8, 0.85))
		ring.name = "FootRing"
		Mats.cylinder(stool, 0.22, 0.09, Vector3(0, 0.77, 0), Color(0.85, 0.15, 0.15), true, 0.21)


# =================================================================== otimização

## Junta todas as malhas estáticas (fora de interativos e peças animadas) em uma malha
## por material. Reduz ~1000 draw calls para algumas dezenas — essencial em GPUs antigas.
static func merge_static_meshes(root: Node3D) -> void:
	var groups: Dictionary = {} # Material -> Array[MeshInstance3D]
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if not _is_static(mi, root) or mi.mesh == null or mi.material_override == null:
			continue
		if not groups.has(mi.material_override):
			groups[mi.material_override] = []
		groups[mi.material_override].append(mi)
	var inv := root.global_transform.affine_inverse()
	for mat: Material in groups:
		var list: Array = groups[mat]
		if list.size() < 2:
			continue
		var st := SurfaceTool.new()
		for mi: MeshInstance3D in list:
			for surf in mi.mesh.get_surface_count():
				st.append_from(mi.mesh, surf, inv * mi.global_transform)
		var merged := MeshInstance3D.new()
		merged.name = "Merged"
		merged.mesh = st.commit()
		merged.material_override = mat
		merged.set_meta("no_highlight", true)
		root.add_child(merged)
		for mi: MeshInstance3D in list:
			mi.queue_free()


static func _is_static(n: Node, root: Node) -> bool:
	var p := n
	while p != null and p != root:
		if p is Interactable or p is Spinner or p.name == "Clock":
			return false
		p = p.get_parent()
	return true


# =================================================================== util

class Spinner extends Node3D:
	var speed := 5.0

	func _process(delta: float) -> void:
		rotation.y += speed * delta
