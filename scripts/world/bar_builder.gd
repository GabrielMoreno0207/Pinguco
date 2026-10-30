class_name BarBuilder
extends Node3D
## Monta o buteco inteiro: arquitetura, balcão, geladeira, prateleiras, mesas,
## decoração, luzes e os pontos interativos. Tudo procedural (sem assets externos).
## O visual vem do ponto atual (BarLocations) e das reformas compradas (BarProgress);
## a área de trabalho atrás do balcão é igual em todos os pontos.
##
## Pontos fechados (boteco, choperia) ganham paredes e teto; pontos abertos (o quiosque
## da praia, `loc.open`) ganham telhado de palha sobre pilares e guarda-corpo baixo, e o
## salão deles é a areia lá fora. Céu e pós-processamento ficam no BarAtmosphere, o mundo
## de fora no OutsideBuilder.

const WORLD_LAYER := 1
## Paredes invisíveis que só bloqueiam o jogador (o raycast de interação as ignora).
const PLAYER_BLOCK_LAYER := 16

## Planta do salão fechado (boteco e choperia). Pontos abertos, como o quiosque da
## praia, trazem a sua em `loc.room` e o salão fica menor.
const ROOM_MIN := Vector3(-6.0, 0.0, -2.6)
const ROOM_MAX := Vector3(6.0, 3.2, 6.2)
const COUNTER_TOP := 1.05
const BACK_TOP := 0.95
const PREP_XS := [-1.6, 0.0, 1.6]

## Limites do salão deste ponto (ver ROOM_MIN/ROOM_MAX e `loc.room`).
var room_min := ROOM_MIN
var room_max := ROOM_MAX
## Ponto aberto (quiosque): sem paredes na frente nem nas laterais.
var open_air := false
## Céu, pós-processamento e a luz que vem de fora.
var atmosphere: BarAtmosphere

var seats: Array[Seat] = []
var dispensers: Dictionary = {} # bev id -> BottleDispenser
## Lugares para garrafas, na ordem em que recebem as bebidas de cada móvel.
var bottle_slots: Dictionary = {} # slot id -> BottleSlot
var cash_register: CashRegister
var snack_trays: Dictionary = {} # food id -> SnackTray
var prep_stations: Array[PrepStation] = []
var glass_stacks: Array[GlassStack] = []
var sink: TrashBin
var player_spawn := Vector3(0, 0.05, -1.1)
var door_inside := Vector3(3.0, 0, 5.3)
var door_outside := Vector3(3.0, 0, 8.0)
var spinners: Array[Node3D] = []
var clock_hand_h: Node3D
var clock_hand_m: Node3D
## A jukebox foi instalada neste bar? Quem toca a música se guia por isto.
var has_jukebox := false

## Tema do ponto atual (ver BarLocations.DATA).
var loc: Dictionary
var _wall_mat: ShaderMaterial
var _wood := Color(0.55, 0.3, 0.16)
var _wood_dark := Color(0.36, 0.19, 0.1)
## Tampos das mesas do salão (a mobília nova põe toalha e vela em cada um).
var _table_tops: Array[Vector3] = []


func build() -> void:
	loc = BarProgress.loc()
	open_air = bool(loc.get("open", false))
	var planta: Dictionary = loc.get("room", {})
	room_min = planta.get("min", ROOM_MIN)
	room_max = planta.get("max", ROOM_MAX)
	_wood = loc.wood
	_wood_dark = loc.wood_dark
	if open_air:
		# o quiosque não tem porta: o freguês entra pela areia
		door_inside = Vector3(2.4, 0, room_max.z + 0.7)
		door_outside = Vector3(2.4, 0, room_max.z + 5.0)
	var painted := BarProgress.level(&"pintura") > 0
	var wall: Dictionary = (loc.wall_new if painted else loc.wall).duplicate()
	wall["grime"] = 0.0 if painted else 0.6
	_wall_mat = BarShaders.material(BarShaders.WALL, wall)
	_build_environment()
	_build_room()
	_build_outside()
	_build_main_counter()
	_build_back_area()
	_build_fridge()
	_place_bottles()
	_build_menu_board()
	_build_customer_area()
	_build_decor()
	_build_reforms()
	_build_lights()
	_build_seats()
	merge_static_meshes(self)


# =================================================================== ambiente

func _build_environment() -> void:
	atmosphere = BarAtmosphere.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	atmosphere.setup(loc, GameManager.low_end)


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


## Peça de madeira com veio (tampos, prateleiras, vigas, portas de armário).
func _plank(parent: Node3D, size: Vector3, pos: Vector3, varnish := 0.7, plank_w := 0.3,
		along_z := false, dark := false, outline := true) -> MeshInstance3D:
	var mi := Mats.box(parent, size, pos, _wood_dark if dark else _wood, false)
	var base: Color = _wood_dark if dark else _wood
	mi.material_override = Mats.wood(base.lightened(0.12), base.darkened(0.3), varnish, plank_w, along_z, 0.25, outline)
	return mi


func _wall(size: Vector3, pos: Vector3) -> void:
	var body := _solid(size, pos)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _wall_mat
	body.add_child(mi)


func _build_room() -> void:
	var size := room_max - room_min
	var center := (room_max + room_min) / 2.0
	_build_floor(size, center)
	if open_air:
		_build_thatch_roof(size, center)
	else:
		_build_ceiling(size, center)
		_build_walls(size, center)
	# divisórias atrás do balcão (limitam a área do jogador em qualquer ponto)
	var t := 0.2
	_wall(Vector3(t, size.y, 2.95), Vector3(-3.95 - t / 2.0, size.y / 2.0, -1.125))
	_wall(Vector3(t, size.y, 2.95), Vector3(3.95 + t / 2.0, size.y / 2.0, -1.125))


func _build_floor(size: Vector3, center: Vector3) -> void:
	# o corpo de colisão passa do piso visível: segura o freguês que vem da rua
	var floor_body := _solid(Vector3(size.x + 4.0, 0.2, size.z + 6.0), Vector3(center.x, -0.1, center.z + 2.0))
	var floor_mesh := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(size.x, 0.2, size.z)
	floor_mesh.mesh = fm
	floor_mesh.position = Vector3(0, 0, center.z - (center.z + 2.0))
	floor_mesh.material_override = _floor_material()
	floor_body.add_child(floor_mesh)
	# rodapé de madeira onde o piso encosta na parede (tira o corte seco piso/parede)
	if not open_air:
		var h := 0.12
		Mats.box(self, Vector3(size.x, h, 0.04), Vector3(center.x, h / 2.0, room_min.z + 0.02), _wood_dark, false)
		for sx: float in [room_min.x + 0.02, room_max.x - 0.02]:
			Mats.box(self, Vector3(0.04, h, size.z), Vector3(sx, h / 2.0, center.z), _wood_dark, false)


func _build_ceiling(size: Vector3, center: Vector3) -> void:
	# forro de madeirite: a cor chapada era o que mais entregava "sem textura" lá em cima
	var forro := Mats.box(self, Vector3(size.x, 0.1, size.z), Vector3(center.x, room_max.y + 0.05, center.z), loc.ceiling, false)
	forro.material_override = Mats.wood(Color(loc.ceiling).lightened(0.08), Color(loc.ceiling).darkened(0.34),
		0.1, 0.42, true, 0.5, false)
	var beams := int(size.z / 1.3)
	for i in beams:
		_plank(self, Vector3(size.x, 0.14, 0.14), Vector3(center.x, room_max.y - 0.07, room_min.z + 0.6 + i * 1.3), 0.2, 0.9, false, true, false)


func _build_walls(size: Vector3, center: Vector3) -> void:
	var t := 0.2
	_wall(Vector3(size.x, size.y, t), Vector3(center.x, size.y / 2.0, room_min.z - t / 2.0)) # fundo
	_wall(Vector3(t, size.y, size.z), Vector3(room_min.x - t / 2.0, size.y / 2.0, center.z)) # esquerda
	_wall(Vector3(t, size.y, size.z), Vector3(room_max.x + t / 2.0, size.y / 2.0, center.z)) # direita
	# parede da frente com vão da porta de enrolar (x 2.2..3.8, até 2.4 m)
	var fz := room_max.z + t / 2.0
	_wall(Vector3(8.2, size.y, t), Vector3(-1.9, size.y / 2.0, fz))
	_wall(Vector3(2.2, size.y, t), Vector3(4.9, size.y / 2.0, fz))
	_wall(Vector3(1.6, 0.8, t), Vector3(3.0, 2.8, fz))
	_build_shutter()


## Quiosque: parede só no fundo (onde ficam as prateleiras e a geladeira), pilares de
## madeira e telhado de palha com caimento. A frente e as laterais do salão ficam abertas
## para a areia e o mar.
func _build_thatch_roof(size: Vector3, center: Vector3) -> void:
	var t := 0.2
	_wall(Vector3(size.x, size.y, t), Vector3(center.x, size.y / 2.0, room_min.z - t / 2.0)) # fundo
	var eave := 0.7 # avanço do telhado além dos pilares
	var x0 := room_min.x
	var x1 := room_max.x
	var z1 := room_max.z
	# pilares de madeira roliça
	for px: float in [x0 + 0.1, 0.0, x1 - 0.1]:
		for pz: float in [z1 - 0.1, room_min.z + 0.9]:
			if absf(px) < 0.5:
				continue # pilar no meio taparia a visão do salão (e a área de trabalho)
			Mats.cylinder(self, 0.09, size.y, Vector3(px, size.y / 2.0, pz), _wood_dark, true, 0.08)
			_solid(Vector3(0.24, size.y, 0.24), Vector3(px, size.y / 2.0, pz), PLAYER_BLOCK_LAYER)
	# vigas: duas longarinas e os caibros atravessados
	for pz: float in [z1 - 0.1, room_min.z + 0.9]:
		Mats.box(self, Vector3(size.x + eave * 2.0, 0.14, 0.16), Vector3(center.x, size.y - 0.07, pz), _wood_dark, false)
	var rafters := int(size.x / 0.8) + 1
	for i in rafters:
		var rx := lerpf(x0 - eave + 0.2, x1 + eave - 0.2, float(i) / maxf(rafters - 1, 1))
		Mats.box(self, Vector3(0.1, 0.1, size.z + eave * 1.6), Vector3(rx, size.y + 0.04, center.z + eave * 0.3), _wood, false)
	# palha: três águas sobrepostas, a de cima mais curta (dá o volume do quiosque)
	var palha := Color(0.78, 0.6, 0.3)
	for i in 3:
		var w := size.x + eave * 2.0 - i * 0.9
		var d := size.z + eave * 1.6 - i * 0.8
		var y := size.y + 0.12 + i * 0.22
		var layer := Mats.box(self, Vector3(w, 0.16, d), Vector3(center.x, y, center.z + eave * 0.3), palha.darkened(i * 0.06))
		layer.set_meta("thatch", true)
	# cumeeira
	Mats.box(self, Vector3(size.x - 1.2, 0.18, 0.3), Vector3(center.x, size.y + 0.78, center.z + eave * 0.3), palha.darkened(0.22))
	# franja de palha pendurada na borda da frente
	for i in int((size.x + eave * 2.0) / 0.22):
		var fx := x0 - eave + 0.11 + i * 0.22
		var strand := Mats.box(self, Vector3(0.16, 0.26, 0.05),
			Vector3(fx, size.y + 0.02, center.z + eave * 0.3 + (size.z + eave * 1.6) / 2.0), palha.lightened(0.08), false)
		strand.rotation.z = sin(fx * 3.7) * 0.12
	# guarda-corpo baixo nas laterais do salão: fecha o quiosque sem tapar a vista
	for sx: float in [x0 + 0.1, x1 - 0.1]:
		var rail_z0 := 0.45
		var rail_len := z1 - rail_z0 - 0.2
		_plank(self, Vector3(0.1, 0.07, rail_len), Vector3(sx, 0.92, rail_z0 + rail_len / 2.0), 0.5, 0.5, true)
		Mats.box(self, Vector3(0.07, 0.05, rail_len), Vector3(sx, 0.55, rail_z0 + rail_len / 2.0), _wood_dark, false)
		for i in int(rail_len / 0.4):
			Mats.cylinder(self, 0.025, 0.9, Vector3(sx, 0.45, rail_z0 + 0.2 + i * 0.4), _wood_dark, false)


## Porta de enrolar do salão fechado (fica recolhida: o bar está aberto).
func _build_shutter() -> void:
	var d := Node3D.new()
	d.position = Vector3(3.0, 0, room_max.z + 0.1)
	add_child(d)
	# batente de metal e a porta de enrolar recolhida lá em cima
	Mats.box(d, Vector3(0.12, 2.4, 0.3), Vector3(-0.86, 1.2, 0), Color(0.45, 0.48, 0.5))
	Mats.box(d, Vector3(0.12, 2.4, 0.3), Vector3(0.86, 1.2, 0), Color(0.45, 0.48, 0.5))
	var roll := Mats.cylinder(d, 0.2, 1.84, Vector3(0, 2.25, 0.05), Color(0.55, 0.58, 0.6))
	roll.rotation_degrees.z = 90
	for i in 3:
		Mats.box(d, Vector3(1.6, 0.06, 0.04), Vector3(0, 2.05 - i * 0.07, 0.12), Color(0.5, 0.52, 0.55), false)


## Piso do ponto; o "piso novo" troca o desenho e tira o encardido.
func _floor_material() -> Material:
	var renewed := BarProgress.level(&"piso") > 0
	if open_air:
		# quiosque é deck de tábuas; sem isso a areia de dentro encostaria na areia de
		# fora com shaders diferentes e apareceria a emenda
		return Mats.wood(_wood.lightened(0.1), _wood.darkened(0.32),
			0.5 if renewed else 0.2, 0.22, false, 0.1 if renewed else 0.5, false)
	var fl: Dictionary = loc.floor_new if renewed else loc.floor
	if int(fl.pattern) == 0:
		return BarShaders.floor_texture_material() if GameManager.low_end else BarShaders.material(BarShaders.FLOOR)
	return BarShaders.material(BarShaders.FLOOR_ALT, {
		"pattern": fl.pattern, "col_a": fl.a, "col_b": fl.b, "grime": 0.0 if renewed else 0.5})


## O mundo lá fora (rua do bairro, avenida do Centro ou praia), em OutsideBuilder.
func _build_outside() -> void:
	var out := OutsideBuilder.new()
	out.build(self, loc, room_min, room_max, GameManager.low_end)
	for l in out.lights:
		if GameManager.low_end:
			l.queue_free()


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
		"tile_a": loc.counter_tile[0], "tile_b": loc.counter_tile[1], "tile_top": 5.0, "tile_size": 0.12})
	body.add_child(front)
	# tampo de madeira envernizada com borda
	_plank(self, Vector3(length + 0.1, 0.07, 0.92), Vector3(0, COUNTER_TOP + 0.005, 0.03), 0.9, 0.3)
	_plank(self, Vector3(length + 0.12, 0.05, 0.06), Vector3(0, COUNTER_TOP - 0.02, 0.5), 0.9, 0.3, false, true)
	# rodapé de madeira e apoio de pé cromado
	_plank(self, Vector3(length, 0.12, 0.04), Vector3(0, 0.06, 0.36), 0.4, 0.26, false, true, false)
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
	for x: float in seat_xs():
		_napkin_holder(Vector3(x + 0.3, COUNTER_TOP + 0.04, 0.3))
		_peanut_bowl(Vector3(x - 0.3, COUNTER_TOP + 0.04, 0.28))
	_counter_clutter()


## A bagunça que faz o balcão parecer usado: pano torcido, abridor, cinzeiro com guimba
## e o pote de gorjeta.
func _counter_clutter() -> void:
	# pano de prato jogado, dobrado em duas partes
	var pano := Node3D.new()
	pano.position = Vector3(-2.55, COUNTER_TOP + 0.05, -0.1)
	pano.rotation.y = 0.4
	add_child(pano)
	Mats.box(pano, Vector3(0.28, 0.02, 0.19), Vector3.ZERO, Color(0.92, 0.9, 0.84))
	Mats.box(pano, Vector3(0.26, 0.018, 0.1), Vector3(0.02, 0.018, 0.03), Color(0.86, 0.84, 0.78)).rotation.y = 0.25
	for i in 3:
		Mats.box(pano, Vector3(0.28, 0.021, 0.015), Vector3(0, 0.001, -0.06 + i * 0.06), Color(0.3, 0.5, 0.75), false)
	# abridor de garrafa com cordinha
	var abridor := Mats.box(self, Vector3(0.09, 0.008, 0.028), Vector3(-2.2, COUNTER_TOP + 0.045, -0.12), Color(0.72, 0.73, 0.78))
	abridor.rotation.y = -0.6
	# cinzeiro de vidro com guimbas
	var cinz := Node3D.new()
	cinz.position = Vector3(-3.8, COUNTER_TOP + 0.04, 0.3)
	add_child(cinz)
	var prato := Mats.cylinder(cinz, 0.065, 0.022, Vector3(0, 0.011, 0), Color(0.82, 0.86, 0.88), false, 0.075)
	prato.material_override = Mats.glass(Color(0.84, 0.88, 0.9), 0.4)
	Mats.cylinder(cinz, 0.05, 0.012, Vector3(0, 0.026, 0), Color(0.32, 0.3, 0.28), false)
	for i in 3:
		var a := i * 2.2
		var g := Mats.cylinder(cinz, 0.006, 0.05, Vector3(cos(a) * 0.028, 0.034, sin(a) * 0.028), Color(0.95, 0.93, 0.86), false)
		g.rotation = Vector3(PI / 2.0, a, 0)
		Mats.cylinder(cinz, 0.0062, 0.016, Vector3(cos(a) * 0.05, 0.034, sin(a) * 0.05), Color(0.72, 0.55, 0.3), false).rotation = Vector3(PI / 2.0, a, 0)
	# pote de gorjeta com umas notas
	var pote := Node3D.new()
	pote.position = Vector3(2.45, COUNTER_TOP + 0.04, -0.3)
	add_child(pote)
	var vidro := Mats.cylinder(pote, 0.055, 0.12, Vector3(0, 0.06, 0), Color(0.86, 0.95, 1.0), false, 0.06)
	vidro.material_override = Mats.glass(Color(0.86, 0.95, 1.0), 0.2)
	for i in 4:
		var nota := Mats.box(pote, Vector3(0.07, 0.002, 0.035), Vector3(0, 0.018 + i * 0.008, 0), Color(0.62, 0.78, 0.55), false)
		nota.rotation = Vector3(0.1 * i, i * 0.9, 0.08 * i)
	Mats.box(pote, Vector3(0.06, 0.03, 0.002), Vector3(0, 0.085, 0.056), UiTheme.PAPER, false)
	Mats.label3d(pote, "GORJETA", Vector3(0, 0.085, 0.058), 40, UiTheme.INK, 0).pixel_size = 0.0007


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
	# bandejas de salgados (interativas)
	var foods := BeverageDatabase.foods()
	for i in foods.size():
		var tray := SnackTray.create(foods[i])
		tray.position = Vector3(lerpf(-0.18, 0.18, float(i) / maxf(foods.size() - 1, 1)), 0.04, 0.0)
		n.add_child(tray)
		snack_trays[foods[i].id] = tray
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
	front.material_override = Mats.wood(_wood_dark.lightened(0.14), _wood_dark.darkened(0.3), 0.45, 0.6, true)
	body.add_child(front)
	# portinhas do armário
	for i in int(w / 0.6):
		_plank(self, Vector3(0.52, 0.7, 0.02), Vector3(x0 + 0.33 + i * 0.6, 0.45, z + 0.335), 0.6, 0.26, true, false, false)
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
	# lugares das jarras preparadas na hora
	for i in 6:
		_add_slot(self, "bancada", i, Vector3(-0.75 + i * 0.42, top, z + 0.1))
	# decoração da bancada: liquidificador, tábua com limões, caixa registradora
	_blender(Vector3(-1.72, top, z - 0.05))
	_lime_board(Vector3(-1.2, top, z + 0.05))
	cash_register = CashRegister.create()
	cash_register.position = Vector3(2.42, top, z - 0.05)
	add_child(cash_register)
	# espelho atrás das prateleiras: um painel de vidro escuro com moldura de madeira.
	# Não reflete de verdade (sai caro), mas o Fresnel do shader de vidro abre a parede
	# e dá profundidade ao fundo do bar, que era uma parede chapada.
	# o painel fica rente à parede e as prateleiras passam na frente dele, como num
	# bar de verdade — por isso só uma moldura de tiras, e não uma caixa atrás
	var mirror := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(4.78, 1.34, 0.012)
	mirror.mesh = mm
	mirror.position = Vector3(-1.2, 1.78, -2.594)
	mirror.material_override = Mats.glass(loc.ambient.darkened(0.55), 0.82, false, 0.35)
	mirror.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mirror.set_meta("no_highlight", true)
	add_child(mirror)
	for my: float in [1.78 + 0.71, 1.78 - 0.71]:
		_plank(self, Vector3(5.0, 0.1, 0.04), Vector3(-1.2, my, -2.58), 0.7, 0.3)
	for mx: float in [-1.2 - 2.45, -1.2 + 2.45]:
		_plank(self, Vector3(0.1, 1.52, 0.04), Vector3(mx, 1.78, -2.58), 0.7, 0.3, true)
	# prateleiras na parede do fundo (um pouco à frente do espelho)
	for i in 2:
		var y := 1.42 + i * 0.45
		_plank(self, Vector3(4.6, 0.04, 0.26), Vector3(-1.2, y, -2.45), 0.6, 0.3)
		for bx in [-3.4, 1.0]:
			Mats.box(self, Vector3(0.03, 0.12, 0.2), Vector3(bx, y - 0.07, -2.48), _wood_dark, false)
		# fita de luz embaixo de cada prateleira, acendendo as garrafas por trás
		var strip := Mats.box(self, Vector3(4.5, 0.012, 0.03), Vector3(-1.2, y - 0.03, -2.35),
			Color(1.0, 0.86, 0.6), false)
		strip.material_override = Mats.toon(Color(1.0, 0.86, 0.6), false, 0.5, 2.2)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sl := OmniLight3D.new()
		sl.position = Vector3(-1.2, y + 0.16, -2.3)
		sl.light_color = Color(1.0, 0.82, 0.55)
		sl.light_energy = 1.3
		sl.omni_range = 2.4
		sl.light_volumetric_fog_energy = 0.8
		add_child(sl)
		_omni(sl)
	# lugares das garrafas na prateleira de baixo (os primeiros recebem as bebidas)
	for i in 8:
		var px := -2.2 + i * 0.55 if i < 6 else -2.2 - (i - 5) * 0.55
		_add_slot(self, "prateleira", i, Vector3(px, 1.44, -2.43))
	# garrafas decorativas na prateleira de cima
	var deco := [Color(0.5, 0.3, 0.1), Color(0.2, 0.45, 0.2), Color(0.85, 0.85, 0.9), Color(0.6, 0.15, 0.1),
		Color(0.9, 0.6, 0.1), Color(0.3, 0.2, 0.5)]
	for i in 14:
		var px := -3.2 + i * 0.32
		var py := 1.44 if i % 2 == 0 else 1.89
		if py < 1.5:
			continue
		_deco_bottle(Vector3(px + randf_range(-0.05, 0.05), py, -2.46), deco[i % deco.size()])
	_radio(Vector3(0.6, 1.91, -2.43))
	_trophy(Vector3(-2.1, 1.91, -2.43))


func _add_slot(parent: Node3D, area: String, index: int, pos: Vector3) -> BottleSlot:
	var area_ids := {"bancada": "counter", "prateleira": "shelf", "geladeira": "fridge"}
	var slot := BottleSlot.create(StringName("%s_%d" % [area_ids[area], index]), area)
	slot.position = pos
	parent.add_child(slot)
	bottle_slots[slot.id] = slot
	return slot


## Cada bebida vai pro lugar salvo (arrumação do jogador) ou, se não tiver, pro primeiro
## lugar livre do móvel de origem dela.
func _place_bottles() -> void:
	var pending: Array[BeverageData] = []
	for bev in BeverageDatabase.drinks():
		var d := BottleDispenser.create(bev)
		dispensers[bev.id] = d
		var saved: BottleSlot = bottle_slots.get(BarProgress.slot_of(bev.id))
		if saved and saved.occupant == null:
			saved.place(d)
		else:
			pending.append(bev)
	for bev in pending:
		var target: BottleSlot = null
		for slot: BottleSlot in bottle_slots.values():
			if slot.occupant == null and String(slot.id).begins_with(String(bev.station) + "_"):
				target = slot
				break
		if target == null:
			for slot: BottleSlot in bottle_slots.values():
				if slot.occupant == null:
					target = slot
					break
		if target == null:
			push_warning("Sem lugar para %s" % bev.id)
			dispensers[bev.id].queue_free()
			dispensers.erase(bev.id)
			continue
		target.place(dispensers[bev.id])


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
	var red: Color = loc.fridge
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
	sign.material_override = Mats.toon(red, true, 0.5, 0.6)
	Mats.label3d(f, loc.fridge_label, Vector3(0, h + 0.16, 0.335), 70, UiTheme.PAPER, 10).pixel_size = 0.0022
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
	# luz interna: o tubo branco em cima, a luz dele e o reflexo no vidro da porta.
	# É o que faz a geladeira de boteco chamar o olho no fundo escuro do bar.
	var tube := Mats.box(f, Vector3(w - 0.2, 0.03, 0.05), Vector3(0, h - 0.14, 0.12), Color(0.85, 0.95, 1.0), false)
	tube.material_override = Mats.toon(Color(0.85, 0.95, 1.0), false, 0.5, 3.4)
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.position = Vector3(0, h - 0.25, 0.1)
	light.light_color = Color(0.78, 0.9, 1.0)
	light.light_energy = 2.4
	light.omni_range = 2.2
	light.light_volumetric_fog_energy = 1.2
	f.add_child(light)
	_omni(light)
	# gelo cristalizado no vidro e nas bordas das prateleiras
	for i in 9:
		var ang := i * 2.3
		var frost := Mats.sphere(f, 0.02 + fmod(i * 0.013, 0.015),
			Vector3(cos(ang) * 0.4, 0.45 + fmod(i * 0.31, 1.3), d / 2.0 - 0.03),
			Color(0.88, 0.96, 1.0), false, Vector3(1.3, 1.0, 0.25))
		frost.material_override = Mats.glass(Color(0.9, 0.97, 1.0), 0.35)
		frost.set_meta("no_highlight", true)
	# lugares das bebidas geladas: prateleira do meio, depois a de cima
	for i in 6:
		var sy: float = shelves[1] if i < 3 else shelves[2]
		_add_slot(f, "geladeira", i, Vector3(-0.33 + (i % 3) * 0.33, sy + 0.01, 0.12))
	# estoque decorativo na prateleira de baixo
	var stock_x := -0.33
	for bev in BeverageDatabase.drinks():
		if bev.station == &"fridge" and stock_x < 0.4:
			for k in 2:
				var deco := BeverageModels.build_container(bev, false)
				deco.position = Vector3(stock_x - 0.06 + k * 0.12, shelves[0] + 0.01, -0.05 - k * 0.05)
				f.add_child(deco)
			stock_x += 0.33


# =================================================================== cardápio de giz

func _build_menu_board() -> void:
	var n := Node3D.new()
	n.position = Vector3(-1.2, 2.55, -2.56)
	add_child(n)
	Mats.box(n, Vector3(3.2, 0.95, 0.04), Vector3.ZERO, _wood_dark)
	Mats.box(n, Vector3(3.05, 0.82, 0.02), Vector3(0, 0, 0.02), UiTheme.CHALK, false)
	Mats.label3d(n, "CARDÁPIO", Vector3(0, 0.31, 0.035), 64, UiTheme.MUSTARD, 0).pixel_size = 0.0018
	var i := 0
	for bev in BeverageDatabase.all():
		var col := i % 4
		var row := i / 4
		var pos := Vector3(-1.42 + col * 0.76, 0.15 - row * 0.15, 0.035)
		var sym := MeshInstance3D.new()
		sym.mesh = Mats.flat_polygon_mesh(SymbolShapes.polygon(bev.symbol), 0.05)
		sym.material_override = Mats.unshaded(bev.color if bev.color.get_luminance() < 0.85 else Color(0.7, 0.85, 1.0))
		sym.position = pos
		n.add_child(sym)
		var l := Mats.label3d(n, "%s  %s  R$%d" % [bev.letter, bev.display_name, BarProgress.price_of(bev)], pos + Vector3(0.08, 0, 0), 34, Color(0.95, 0.95, 0.9) if not bev.is_food() else Color(1.0, 0.8, 0.5), 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.pixel_size = 0.0013
		i += 1


# =================================================================== salão

const TABLE_SPOTS := [Vector3(-4.6, 0, 2.3), Vector3(-1.7, 0, 4.7), Vector3(5.0, 0, 2.5), Vector3(5.0, 0, 4.6)]
## No quiosque o salão é a areia: as mesas saem de baixo do telhado.
const BEACH_TABLE_SPOTS := [Vector3(-6.6, 0, 5.2), Vector3(6.6, 0, 5.6), Vector3(-3.2, 0, 7.8), Vector3(3.6, 0, 8.4)]


func _table_spots() -> Array:
	return BEACH_TABLE_SPOTS if open_air else TABLE_SPOTS


func _build_customer_area() -> void:
	var spots := _table_spots()
	match int(loc.outside):
		1: # choperia: mesas de madeira, barris e alvo de dardos
			for p: Vector3 in spots:
				_wood_table(p)
			_kegs(Vector3(-4.6, 0, 4.9), 4)
			_kegs(Vector3(5.2, 0, -1.6), 3)
			_kegs(Vector3(-5.3, 0, -0.8), 3)
		2: # quiosque de praia: guarda-sol na areia, espreguiçadeiras e pranchas no pilar
			var umbrellas := [Color(1.0, 0.45, 0.3), Color(0.15, 0.6, 0.7), Color(1.0, 0.8, 0.2), Color(0.95, 0.35, 0.55)]
			for i in spots.size():
				_parasol_table(spots[i], umbrellas[i])
			_lounge_chair(Vector3(-9.0, 0, 6.6), Color(0.15, 0.6, 0.7))
			_lounge_chair(Vector3(-9.0, 0, 7.7), Color(1.0, 0.45, 0.3))
			_lounge_chair(Vector3(9.2, 0, 7.2), Color(1.0, 0.8, 0.2))
			_surfboards(Vector3(room_min.x - 0.3, 0, room_max.z - 1.6))
			_cooler(Vector3(2.3, 0, -1.6))
			_coconuts(Vector3(-3.5, 0, -0.8))
		_: # boteco: mesa de plástico, sinuca e engradado
			for i in spots.size():
				_plastic_table(spots[i], Color(1.0, 0.82, 0.1) if i % 2 == 0 else Color(0.9, 0.15, 0.15))
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
	_table_tops.append(pos + Vector3(0, 0.74, 0))


func _wood_table(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	_plank(n, Vector3(0.95, 0.06, 0.95), Vector3(0, 0.76, 0), 0.75, 0.16)
	for sx in [-0.38, 0.38]:
		for sz in [-0.38, 0.38]:
			Mats.box(n, Vector3(0.07, 0.74, 0.07), Vector3(sx, 0.37, sz), _wood_dark, false)
	# banquinhos de madeira
	for k in 4:
		var a := k * TAU / 4.0
		var st := Vector3(cos(a) * 0.78, 0, sin(a) * 0.78)
		Mats.cylinder(n, 0.19, 0.05, st + Vector3(0, 0.47, 0), _wood)
		Mats.cylinder(n, 0.03, 0.45, st + Vector3(0, 0.225, 0), _wood_dark, false)
	# canecas de chopp
	for k in 3:
		var g := BeverageModels.build_glass(BeverageDatabase.get_beverage(&"cerveja"))
		g.scale = Vector3.ONE * 1.4
		g.position = Vector3(-0.22 + k * 0.22, 0.79, 0.12 - (k % 2) * 0.22)
		n.add_child(g)
	_solid(Vector3(1.0, 0.8, 1.0), pos + Vector3(0, 0.4, 0), PLAYER_BLOCK_LAYER)
	_table_tops.append(pos + Vector3(0, 0.79, 0))


func _kegs(pos: Vector3, count: int) -> void:
	var metal := Color(0.72, 0.74, 0.78)
	for i in count:
		var p := pos + Vector3((i % 2) * 0.42 - 0.21, (i / 2) * 0.56, 0)
		Mats.cylinder(self, 0.2, 0.55, p + Vector3(0, 0.275, 0), metal)
		for ry in [0.08, 0.47]:
			Mats.cylinder(self, 0.205, 0.04, p + Vector3(0, ry, 0), metal.darkened(0.25), false)


func _parasol_table(pos: Vector3, c: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	Mats.cylinder(n, 0.45, 0.04, Vector3(0, 0.72, 0), Color(0.97, 0.97, 0.94))
	Mats.cylinder(n, 0.05, 0.7, Vector3(0, 0.35, 0), Color(0.9, 0.9, 0.88), false, 0.04)
	# guarda-sol listrado: dois cones sobrepostos
	Mats.cylinder(n, 0.03, 2.3, Vector3(0, 1.15, 0), Color(0.85, 0.78, 0.6), false)
	Mats.cylinder(n, 1.15, 0.36, Vector3(0, 2.2, 0), c, true, 0.03)
	Mats.cylinder(n, 0.6, 0.2, Vector3(0, 2.29, 0), Color(0.98, 0.98, 0.95), false, 0.03)
	for k in 3:
		var a := k * TAU / 3.0 + 0.4
		_plastic_chair(n, Vector3(cos(a) * 0.85, 0, sin(a) * 0.85), -a + PI / 2.0, Color(0.85, 0.7, 0.45))
	# coco com canudinho
	Mats.sphere(n, 0.08, Vector3(0.12, 0.82, 0.05), Color(0.45, 0.6, 0.2))
	Mats.cylinder(n, 0.006, 0.16, Vector3(0.12, 0.92, 0.05), Color(1.0, 0.4, 0.5), false).rotation_degrees.z = 15
	_solid(Vector3(1.0, 0.75, 1.0), pos + Vector3(0, 0.375, 0), PLAYER_BLOCK_LAYER)
	_table_tops.append(pos + Vector3(0, 0.74, 0))


func _lounge_chair(pos: Vector3, c: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = 90
	add_child(n)
	Mats.box(n, Vector3(1.3, 0.05, 0.55), Vector3(0, 0.3, 0), Color(0.95, 0.95, 0.92))
	Mats.box(n, Vector3(1.0, 0.06, 0.5), Vector3(-0.15, 0.35, 0), c)
	var back := Mats.box(n, Vector3(0.55, 0.06, 0.5), Vector3(0.6, 0.55, 0), c)
	back.rotation_degrees.z = 40
	for sx in [-0.55, 0.5]:
		for sz in [-0.22, 0.22]:
			Mats.box(n, Vector3(0.04, 0.3, 0.04), Vector3(sx, 0.15, sz), Color(0.95, 0.95, 0.92), false)


func _surfboards(pos: Vector3) -> void:
	var colors := [Color(1.0, 0.45, 0.3), Color(0.2, 0.7, 0.85), Color(1.0, 0.85, 0.25)]
	for i in colors.size():
		var b := Mats.sphere(self, 0.9, pos + Vector3(0.08, 0.95, i * 0.5), colors[i], true, Vector3(0.06, 1.0, 0.27))
		b.rotation_degrees.z = -8
		Mats.box(self, Vector3(0.02, 1.4, 0.04), pos + Vector3(0.14, 0.95, i * 0.5), Color(1, 1, 1), false).rotation_degrees.z = -8


func _cooler(pos: Vector3) -> void:
	Mats.box(self, Vector3(0.7, 0.45, 0.45), pos + Vector3(0, 0.225, 0), Color(0.95, 0.95, 0.95))
	Mats.box(self, Vector3(0.72, 0.08, 0.47), pos + Vector3(0, 0.48, 0), Color(0.15, 0.45, 0.85))
	Mats.box(self, Vector3(0.3, 0.04, 0.06), pos + Vector3(0, 0.54, 0), Color(0.95, 0.95, 0.95), false)


func _coconuts(pos: Vector3) -> void:
	for i in 6:
		var a := i * 1.3
		var r := 0.0 if i == 5 else 0.18
		Mats.sphere(self, 0.12, pos + Vector3(cos(a) * r, 0.12 + (0.18 if i == 5 else 0.0), sin(a) * r), Color(0.4, 0.55, 0.18))


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
	_plank(n, Vector3(2.0, 0.12, 1.1), Vector3(0, 0.78, 0), 0.85, 0.3)
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
	# faces internas das paredes deste ponto (o quiosque só tem a do fundo)
	var wl := room_min.x + 0.03
	var wr := room_max.x - 0.03
	var wf := room_max.z - 0.03
	_build_sign(Vector3(-1.2, room_max.y - 0.7, wf) if not open_air else Vector3(-1.0, room_max.y - 0.52, -2.55))

	if open_air:
		_build_kiosk_decor()
	else:
		# TV no suporte passando o jogo: de tubo no começo, telão depois da reforma
		if BarProgress.level(&"tv") > 0:
			_tv(Vector3(wr - 0.47, 2.3, 1.4), -115, Vector2(1.5, 0.86), false)
			_tv(Vector3(wl + 0.47, 2.3, 0.3), 115, Vector2(1.2, 0.7), false)
		else:
			_tv(Vector3(wr - 0.47, 2.35, 1.4), -115, Vector2(0.5, 0.38), true)
		Mats.box(self, Vector3(0.3, 0.06, 0.06), Vector3(wr - 0.12, 2.35, 1.4), Color(0.3, 0.3, 0.32))
		# cartazes (o texto muda conforme o ponto)
		var posters: Array = loc.posters
		var spots := [
			[Vector3(wl, 1.9, 1.6), 90], [Vector3(wl, 1.85, 3.6), 90], [Vector3(wr, 1.9, 3.6), -90],
			[Vector3(1.3, 1.95, wf), 180], [Vector3(-3.97, 1.95, -1.4), 90],
		]
		for i in mini(posters.size(), spots.size()):
			_poster(spots[i][0], spots[i][1], posters[i][0], posters[i][1], posters[i][2])
		# ventiladores de teto
		for p in [Vector3(-2.5, room_max.y, 3.2), Vector3(2.0, room_max.y, 3.6)]:
			_fan(p)

	_calendar(Vector3(3.93, 1.75, -1.1), -90)
	_wall_clock(Vector3(3.93, minf(2.5, room_max.y - 0.3), -0.9), -90)
	_bead_curtain(Vector3(-3.97, 0, -1.0))

	match int(loc.outside):
		1:
			_dartboard(Vector3(wl, 1.75, 4.9), 90)
			_chopp_tower(Vector3(-3.35, COUNTER_TOP + 0.04, -0.12))
			# luminárias pendentes de cobre no lugar das bandeirinhas
			for x in [-4.5, -1.5, 1.5, 4.5]:
				for z in [2.4, 4.6]:
					_pendant(Vector3(x, 2.5, z))
		2:
			_chopp_tower(Vector3(-3.35, COUNTER_TOP + 0.04, -0.12))
		_:
			_pennant(Vector3(wl, 2.5, 2.6), 90)
			_halloween_decor()


## Letreiro do bar, iluminado por baixo.
func _build_sign(pos: Vector3) -> void:
	var sign := Node3D.new()
	sign.position = pos
	sign.rotation_degrees.y = 180 if pos.z > 0.0 else 0.0
	add_child(sign)
	Mats.box(sign, Vector3(3.6, 0.9, 0.06), Vector3.ZERO, loc.sign_bg)
	# moldura e as lampadinhas em volta, que é o que faz letreiro de bar
	Mats.box(sign, Vector3(3.74, 0.1, 0.1), Vector3(0, 0.5, 0.0), loc.sign_bg.lightened(0.25), false)
	Mats.box(sign, Vector3(3.74, 0.1, 0.1), Vector3(0, -0.5, 0.0), loc.sign_bg.lightened(0.25), false)
	for i in 11:
		var bx := lerpf(-1.75, 1.75, float(i) / 10.0)
		for by: float in [0.52, -0.52]:
			var dot := Mats.sphere(sign, 0.032, Vector3(bx, by, 0.05), Color(1.0, 0.88, 0.6), false)
			dot.material_override = Mats.toon(Color(1.0, 0.86, 0.55), false, 0.5, 4.0)
			dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var title := Mats.label3d(sign, String(loc.name).to_upper(), Vector3(0, 0.07, 0.04), 150, Color(1.0, 0.82, 0.3), 24)
	title.pixel_size = 0.0028 if String(loc.name).length() <= 15 else 0.0022
	title.modulate = loc.sign_fg
	var sub := Mats.label3d(sign, loc.subtitle, Vector3(0, -0.28, 0.04), 60, Color(1.0, 0.45, 0.6), 10)
	sub.pixel_size = 0.0022
	sub.modulate = loc.sign_sub
	var inward: float = -0.6 if pos.z > 0.0 else 0.6
	var sign_light := OmniLight3D.new()
	sign_light.position = pos + Vector3(0, -0.05, inward)
	sign_light.light_color = Color(1.0, 0.6, 0.4)
	sign_light.light_energy = 1.6
	sign_light.omni_range = 3.0
	add_child(sign_light)
	_omni(sign_light)


## Quiosque: nada vai em parede lateral (não há). A decoração pendura no telhado,
## encosta na parede do fundo ou fica na areia.
func _build_kiosk_decor() -> void:
	var y := room_max.y
	_pennant_flags([Color(0.15, 0.6, 0.7), Color(1.0, 0.98, 0.9), Color(1.0, 0.8, 0.2), Color(1.0, 0.45, 0.3)])
	# rede de pesca com estrelas-do-mar e conchas no fundo do quiosque
	_fish_net(Vector3(2.2, 1.9, -2.55))
	_life_ring(Vector3(-3.9, 1.9, -1.9), 90)
	# TV debaixo do telhado, virada para o salão
	if BarProgress.level(&"tv") > 0:
		_tv(Vector3(room_max.x - 0.6, y - 0.55, 0.9), -120, Vector2(1.3, 0.75), false)
	# cartazes de madeira pendurados nos caibros
	var posters: Array = loc.posters
	var spots := [
		[Vector3(room_min.x + 1.1, 1.95, room_max.z - 0.2), 180], [Vector3(room_max.x - 1.1, 1.95, room_max.z - 0.2), 180],
		[Vector3(-3.97, 1.95, -1.4), 90],
	]
	for i in mini(posters.size(), spots.size()):
		_poster(spots[i][0], spots[i][1], posters[i][0], posters[i][1], posters[i][2])
	# tochas na beira da areia e remos cruzados no pilar
	for p in [Vector3(room_min.x - 1.2, 0, room_max.z + 1.4), Vector3(room_max.x + 1.2, 0, room_max.z + 1.4),
			Vector3(room_min.x - 1.6, 0, room_max.z - 1.6), Vector3(room_max.x + 1.6, 0, room_max.z - 1.6)]:
		_tiki_torch(p)
	_oars(Vector3(room_min.x + 0.25, 1.4, room_max.z - 0.3))
	# ventilador de teto preso no caibro do meio
	_fan(Vector3(0.0, y + 0.02, 1.6))


## Rede de pesca pendurada, com estrela-do-mar e conchas presas nela.
func _fish_net(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	var corda := Color(0.82, 0.76, 0.6)
	for i in 9:
		var x := -0.8 + i * 0.2
		Mats.box(n, Vector3(0.012, 1.1, 0.012), Vector3(x, 0.0, 0.0), corda, false).rotation.z = 0.5
		Mats.box(n, Vector3(0.012, 1.1, 0.012), Vector3(x, 0.0, 0.0), corda, false).rotation.z = -0.5
	Mats.merge_children(n)
	# estrela-do-mar
	var star := Node3D.new()
	star.position = Vector3(-0.3, 0.1, 0.03)
	n.add_child(star)
	for k in 5:
		var a := k * TAU / 5.0
		var arm := Mats.box(star, Vector3(0.05, 0.16, 0.02), Vector3(sin(a) * 0.08, cos(a) * 0.08, 0.0),
			Color(0.95, 0.55, 0.3), false)
		arm.rotation.z = -a
	Mats.sphere(star, 0.055, Vector3(0, 0, 0.005), Color(0.95, 0.55, 0.3), false, Vector3(1, 1, 0.4))
	Mats.merge_children(star)
	for c: Array in [[0.35, -0.2], [0.6, 0.15], [-0.65, -0.3]]:
		Mats.sphere(n, 0.05, Vector3(c[0], c[1], 0.03), Color(0.95, 0.9, 0.82), false, Vector3(1, 1, 0.45))


## Dois remos cruzados, de enfeite.
func _oars(pos: Vector3) -> void:
	for side: float in [-1.0, 1.0]:
		var n := Node3D.new()
		n.position = pos
		n.rotation.z = side * 0.5
		add_child(n)
		Mats.cylinder(n, 0.025, 1.7, Vector3.ZERO, Color(0.86, 0.8, 0.66))
		Mats.sphere(n, 0.11, Vector3(0, -0.85, 0), Color(0.2, 0.6, 0.7) if side > 0.0 else Color(0.95, 0.5, 0.3),
			true, Vector3(1.0, 1.8, 0.25))


func _pennant_flags(colors: Array) -> void:
	# bandeirinhas atravessando o teto
	var x := room_max.x - 0.2
	var y := room_max.y - 0.35
	var lines := int((room_max.z - 0.6) / 1.4)
	for line in lines:
		var z := 0.8 + line * 1.4
		_bunting(Vector3(-x, y, z), Vector3(x, y, z + 0.3), colors)


## Decoração de Halloween do boteco: bandeirinhas laranja/preto/roxo, morcegos, abóboras e teias.
func _halloween_decor() -> void:
	_pennant_flags([Color(1.0, 0.5, 0.08), Color(0.08, 0.06, 0.1), Color(0.5, 0.2, 0.65)])
	# morcegos pendurados entre as fileiras de bandeirinhas (longe dos ventiladores)
	for b in [Vector3(-4.2, 2.6, 1.5), Vector3(-0.8, 2.5, 1.6), Vector3(3.3, 2.65, 1.5), Vector3(0.4, 2.55, 2.9),
			Vector3(4.4, 2.5, 3.0), Vector3(-4.6, 2.6, 4.3), Vector3(-1.0, 2.5, 4.4), Vector3(4.2, 2.6, 4.9)]:
		_bat(b)
	# abóboras acesas viradas para o jogador
	_jack_o_lantern(Vector3(-3.55, COUNTER_TOP + 0.04, 0.0), 0.13)
	_jack_o_lantern(Vector3(-3.15, COUNTER_TOP + 0.04, 0.1), 0.09)
	_jack_o_lantern(Vector3(1.9, 0.0, 5.75), 0.17)
	_jack_o_lantern(Vector3(-5.5, 0.0, 5.7), 0.15)
	# teias nos cantos do teto
	var top := room_max.y - 0.02
	_cobweb(Vector3(room_min.x + 0.02, top, room_max.z - 0.02), Vector3.RIGHT, Vector3.DOWN)
	_cobweb(Vector3(room_min.x + 0.02, top, room_max.z - 0.02), Vector3.FORWARD, Vector3.DOWN)
	_cobweb(Vector3(room_max.x - 0.02, top, room_max.z - 0.02), Vector3.LEFT, Vector3.DOWN)
	_cobweb(Vector3(-3.93, top, room_min.z + 0.02), Vector3.RIGHT, Vector3.DOWN)
	_cobweb(Vector3(3.93, top, room_min.z + 0.02), Vector3.LEFT, Vector3.DOWN)


func _bat(pos: Vector3) -> void:
	Mats.cylinder(self, 0.004, room_max.y - pos.y, Vector3(pos.x, (room_max.y + pos.y) / 2.0, pos.z), Color(0.1, 0.1, 0.1), false)
	var bat := MeshInstance3D.new()
	# silhueta com y para baixo (flat_polygon_mesh inverte o y)
	bat.mesh = Mats.flat_polygon_mesh(PackedVector2Array([
		Vector2(0, -0.15), Vector2(0.1, -0.35), Vector2(0.15, -0.1), Vector2(0.5, -0.3), Vector2(1.0, -0.15),
		Vector2(0.85, 0.0), Vector2(0.7, 0.1), Vector2(0.55, 0.0), Vector2(0.4, 0.15), Vector2(0.25, 0.05),
		Vector2(0.12, 0.3), Vector2(0, 0.2), Vector2(-0.12, 0.3), Vector2(-0.25, 0.05), Vector2(-0.4, 0.15),
		Vector2(-0.55, 0.0), Vector2(-0.7, 0.1), Vector2(-0.85, 0.0), Vector2(-1.0, -0.15), Vector2(-0.5, -0.3),
		Vector2(-0.15, -0.1), Vector2(-0.1, -0.35)]), 0.2)
	bat.material_override = Mats.unshaded(Color(0.07, 0.05, 0.09))
	bat.position = pos
	bat.rotation.y = randf_range(-0.6, 0.6)
	bat.rotation.z = randf_range(-0.15, 0.15)
	add_child(bat)
	# olhinhos
	for side in [-1.0, 1.0]:
		var eye := Mats.sphere(bat, 0.008, Vector3(side * 0.018, 0.035, 0.006), Color(1.0, 0.8, 0.2), false)
		eye.material_override = Mats.unshaded(Color(1.0, 0.8, 0.2))


## Abóbora de Halloween com rosto aceso, virada para -z (o lado do jogador).
func _jack_o_lantern(pos: Vector3, r: float) -> void:
	var n := Node3D.new()
	n.position = pos + Vector3(0, r * 0.8, 0)
	n.rotation_degrees.y = randf_range(-15.0, 15.0)
	add_child(n)
	# gomos
	for i in 6:
		var a := i * TAU / 6.0
		Mats.sphere(n, r * 0.62, Vector3(cos(a) * r * 0.42, 0, sin(a) * r * 0.42), Color(1.0, 0.5, 0.1), true, Vector3(1, 1.25, 1))
	Mats.sphere(n, r * 0.75, Vector3.ZERO, Color(0.95, 0.45, 0.08), false, Vector3(1, 1.05, 1))
	Mats.cylinder(n, r * 0.09, r * 0.35, Vector3(0, r * 0.85, 0), Color(0.3, 0.4, 0.15), true, r * 0.06)
	# rosto recortado, brilhando por dentro
	var glow := Mats.unshaded(Color(1.0, 0.85, 0.25))
	var front := -r * 1.06
	var shapes := [
		[PackedVector2Array([Vector2(-1, 0.6), Vector2(1, 0.6), Vector2(0, -0.8)]), Vector3(-r * 0.32, r * 0.22, front)],
		[PackedVector2Array([Vector2(-1, 0.6), Vector2(1, 0.6), Vector2(0, -0.8)]), Vector3(r * 0.32, r * 0.22, front)],
		[PackedVector2Array([Vector2(-1, 0.6), Vector2(1, 0.6), Vector2(0, -0.6)]), Vector3(0, 0.0, front)],
		[PackedVector2Array([Vector2(-3, -0.3), Vector2(-2, 0.2), Vector2(-1, -0.2), Vector2(0, 0.3), Vector2(1, -0.2),
			Vector2(2, 0.2), Vector2(3, -0.3), Vector2(2, 0.9), Vector2(0, 1.2), Vector2(-2, 0.9)]), Vector3(0, -r * 0.3, front)],
	]
	for s in shapes:
		var f := MeshInstance3D.new()
		f.mesh = Mats.flat_polygon_mesh(s[0], r * 0.16)
		f.material_override = glow
		f.position = s[1]
		n.add_child(f)
	var l := OmniLight3D.new()
	l.position = Vector3(0, 0, -r * 1.6)
	l.light_color = Color(1.0, 0.55, 0.15)
	l.light_energy = 0.5
	l.omni_range = 1.2
	n.add_child(l)
	_omni(l)


## Teia no canto: fios saindo do canto entre as direções u e v, com anéis ligando os fios.
func _cobweb(corner: Vector3, u: Vector3, v: Vector3) -> void:
	var color := Color(0.92, 0.92, 0.95)
	var strands := 5
	var length := 0.6
	var rings := [0.18, 0.33, 0.48]
	var dirs: Array[Vector3] = []
	for i in strands:
		var a := float(i) / (strands - 1) * PI / 2.0
		var d := (u * cos(a) + v * sin(a)).normalized()
		dirs.append(d)
		_strand(corner, corner + d * length, color)
	for rr: float in rings:
		for i in strands - 1:
			# anel levemente caído para o canto, como teia de verdade
			var mid := (dirs[i] + dirs[i + 1]).normalized() * rr * 0.9
			_strand(corner + dirs[i] * rr, corner + mid, color)
			_strand(corner + mid, corner + dirs[i + 1] * rr, color)


func _strand(a: Vector3, b: Vector3, color: Color) -> void:
	var dir := b - a
	var seg := Mats.cylinder(self, 0.003, a.distance_to(b), (a + b) / 2.0, color, false)
	seg.look_at_from_position((a + b) / 2.0, b, Vector3.UP if absf(dir.normalized().y) < 0.9 else Vector3.RIGHT)
	seg.rotate_object_local(Vector3.RIGHT, PI / 2.0)


func _tv(pos: Vector3, yaw: float, screen_size: Vector2, crt: bool) -> void:
	var tv := Node3D.new()
	tv.position = pos
	tv.rotation_degrees.y = yaw
	add_child(tv)
	var depth := 0.42 if crt else 0.08
	Mats.box(tv, Vector3(screen_size.x + 0.1, screen_size.y + 0.1, depth), Vector3(0, 0, -depth / 2.0 + 0.04),
		Color(0.55, 0.5, 0.45) if crt else Color(0.08, 0.08, 0.1))
	if crt:
		Mats.box(tv, Vector3(0.12, 0.08, 0.02), Vector3(screen_size.x / 2.0 - 0.02, -screen_size.y / 2.0 - 0.02, 0.05), Color(0.2, 0.2, 0.2), false)
	var screen := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = screen_size
	screen.mesh = q
	screen.position.z = 0.085
	screen.material_override = BarShaders.material(BarShaders.TV)
	tv.add_child(screen)


func _dartboard(pos: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	var rings := [[0.24, Color(0.1, 0.1, 0.1)], [0.2, Color(0.85, 0.15, 0.15)], [0.15, Color(0.95, 0.9, 0.75)],
		[0.1, Color(0.15, 0.5, 0.25)], [0.04, Color(0.85, 0.15, 0.15)]]
	for i in rings.size():
		var d := Mats.cylinder(n, rings[i][0], 0.02, Vector3(0, 0, 0.01 + i * 0.004), rings[i][1], i == 0)
		d.rotation_degrees.x = 90


func _chopp_tower(pos: Vector3) -> void:
	var copper := Color(0.88, 0.52, 0.26)
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	Mats.box(n, Vector3(0.36, 0.04, 0.24), Vector3(0, 0.02, 0), Color(0.75, 0.76, 0.8))
	Mats.cylinder(n, 0.06, 0.45, Vector3(0, 0.26, 0), copper)
	Mats.sphere(n, 0.08, Vector3(0, 0.5, 0), copper)
	for side in [-1.0, 1.0]:
		Mats.box(n, Vector3(0.12, 0.03, 0.03), Vector3(side * 0.1, 0.4, 0.05), copper, false)
		Mats.cylinder(n, 0.012, 0.14, Vector3(side * 0.15, 0.47, 0.05), Color(0.1, 0.1, 0.1), false)


func _pendant(pos: Vector3) -> void:
	Mats.cylinder(self, 0.006, room_max.y - pos.y, Vector3(pos.x, (room_max.y + pos.y) / 2.0, pos.z), Color(0.1, 0.1, 0.1), false)
	Mats.cylinder(self, 0.16, 0.18, pos, Color(0.88, 0.52, 0.26), true, 0.05)
	var bulb := Mats.sphere(self, 0.045, pos - Vector3(0, 0.08, 0), Color(1.0, 0.85, 0.6), false)
	bulb.material_override = Mats.toon(Color(1.0, 0.85, 0.6), false, 0.5, 5.0)


func _life_ring(pos: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	var ring := Mats.torus(n, 0.14, 0.26, Vector3.ZERO, Color(1.0, 0.35, 0.25), true)
	ring.rotation_degrees.x = 90
	for i in 4:
		var band := Mats.box(n, Vector3(0.06, 0.13, 0.13), Vector3(cos(i * PI / 2.0 + PI / 4.0) * 0.2, sin(i * PI / 2.0 + PI / 4.0) * 0.2, 0), Color(0.98, 0.98, 0.95), false)
		band.rotation.z = i * PI / 2.0 + PI / 4.0


func _tiki_torch(pos: Vector3) -> void:
	Mats.cylinder(self, 0.035, 1.6, pos + Vector3(0, 0.8, 0), Color(0.6, 0.45, 0.25))
	Mats.cylinder(self, 0.07, 0.18, pos + Vector3(0, 1.65, 0), Color(0.35, 0.25, 0.15), true, 0.09)
	var flame := Mats.sphere(self, 0.07, pos + Vector3(0, 1.8, 0), Color(1.0, 0.6, 0.2), false, Vector3(1, 1.6, 1))
	flame.material_override = Mats.toon(Color(1.0, 0.6, 0.2), false, 0.5, 6.0)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, 1.9, -0.2)
	l.light_color = Color(1.0, 0.6, 0.3)
	l.light_energy = 0.6
	l.omni_range = 2.5
	add_child(l)
	_omni(l)


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
	if atmosphere:
		atmosphere.set_hour(hours)
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


func _bunting(a: Vector3, b: Vector3, colors: Array) -> void:
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
	_cord(a, b, 0.35, Color(0.9, 0.9, 0.85))


## Fio pendurado entre dois pontos, com barriga para baixo.
func _cord(a: Vector3, b: Vector3, sag: float, color: Color) -> void:
	var dir := b - a
	for i in 12:
		var t0 := float(i) / 12.0
		var t1 := float(i + 1) / 12.0
		var p0 := a.lerp(b, t0) - Vector3(0, sin(t0 * PI) * sag, 0)
		var p1 := a.lerp(b, t1) - Vector3(0, sin(t1 * PI) * sag, 0)
		var seg := Mats.cylinder(self, 0.006, p0.distance_to(p1), (p0 + p1) / 2.0, color, false)
		seg.look_at_from_position((p0 + p1) / 2.0, p1, Vector3.UP if absf(dir.normalized().y) < 0.9 else Vector3.RIGHT)
		seg.rotate_object_local(Vector3.RIGHT, PI / 2.0)


# =================================================================== reformas

## Tudo que o caderninho compra e aparece no salão.
func _build_reforms() -> void:
	var luz := BarProgress.level(&"luz")
	if luz >= 1:
		# varal de lâmpadas atravessando o teto
		var lx := room_max.x - 0.2
		var ly := room_max.y - 0.22
		for line in maxi(int((room_max.z - 0.8) / 1.8), 1):
			var z := 1.2 + line * 1.8
			var a := Vector3(-lx, ly, z + 0.4)
			var b := Vector3(lx, ly, z - 0.4)
			_cord(a, b, 0.22, Color(0.12, 0.12, 0.12))
			for i in 18:
				var t := (i + 0.5) / 18.0
				var p := a.lerp(b, t) - Vector3(0, sin(t * PI) * 0.22 + 0.05, 0)
				var bulb := Mats.sphere(self, 0.035, p, Color(1.0, 0.85, 0.55), false)
				bulb.material_override = Mats.toon([Color(1.0, 0.8, 0.45), Color(1.0, 0.6, 0.4), Color(1.0, 0.92, 0.7)][i % 3], false, 0.5, 5.0)
		for x in [-3.0, 3.0]:
			var l := OmniLight3D.new()
			l.position = Vector3(x, room_max.y - 0.6, minf(3.0, room_max.z - 0.6))
			l.light_color = Color(1.0, 0.78, 0.5)
			l.light_energy = 0.6
			l.omni_range = 5.0
			add_child(l)
			_omni(l)
	if luz >= 2:
		# neon colorido contornando o salão
		var pink := Color(1.0, 0.3, 0.7)
		var cyan := Color(0.3, 0.9, 1.0)
		var nx := room_max.x - 0.05
		var ny := room_max.y - 0.2
		var nz := (room_max.z + 0.4) / 2.0
		var nd := room_max.z - 0.4
		var tube_pink := Mats.box(self, Vector3(0.04, 0.04, nd), Vector3(-nx, ny, nz), pink, false)
		tube_pink.material_override = Mats.toon(pink, false, 0.5, 4.0)
		var tube_cyan := Mats.box(self, Vector3(0.04, 0.04, nd), Vector3(nx, ny, nz), cyan, false)
		tube_cyan.material_override = Mats.toon(cyan, false, 0.5, 4.0)
		var tube_front := Mats.box(self, Vector3(nx * 1.6, 0.04, 0.04), Vector3(-nx * 0.18, ny, room_max.z - 0.08), pink, false)
		tube_front.material_override = Mats.toon(pink, false, 0.5, 4.0)
		for pair in [[Vector3(-nx + 0.4, ny - 0.2, nz), pink], [Vector3(nx - 0.4, ny - 0.2, nz), cyan]]:
			var l := OmniLight3D.new()
			l.position = pair[0]
			l.light_color = pair[1]
			l.light_energy = 0.7
			l.omni_range = 4.0
			add_child(l)
			_omni(l)
	var deco := BarProgress.level(&"decoracao")
	if deco >= 1:
		var px := room_max.x - 0.45
		var pz := room_max.z - 0.45
		for p in [Vector3(-px, 0, pz), Vector3(px, 0, pz), Vector3(px, 0, 0.3)]:
			_plant(p)
		if not open_air:
			for z in [room_max.z - 1.5, room_max.z - 0.7]:
				_frame(Vector3(room_min.x + 0.03, 2.0, z), 90)
			_frame(Vector3(room_max.x - 0.03, 2.0, room_max.z - 0.9), -90)
	if deco >= 2:
		# no quiosque a área de trabalho é apertada: a jukebox vai encostada no pilar do
		# salão, virada para dentro (atrás do balcão ela bateria na geladeira)
		_jukebox(Vector3(0.5, 0, room_max.z - 0.4) if not open_air else Vector3(room_min.x + 0.75, 0, room_max.z - 0.7))
	if BarProgress.level(&"neon") >= 1:
		var neon := Node3D.new()
		var neon_pos := Vector3(4.9, 2.2, room_max.z - 0.04) if not open_air 			else Vector3(room_max.x - 1.3, room_max.y - 0.5, room_max.z - 0.25)
		neon.position = neon_pos
		neon.rotation_degrees.y = 180
		add_child(neon)
		Mats.box(neon, Vector3(1.2, 0.42, 0.03), Vector3.ZERO, Color(0.06, 0.05, 0.08))
		var txt := Mats.label3d(neon, "ABERTO", Vector3(0, 0, 0.025), 110, Color(1.0, 0.35, 0.35), 18)
		txt.pixel_size = 0.0022
		txt.modulate = Color(2.0, 0.5, 0.5)
		var l := OmniLight3D.new()
		l.position = neon_pos - Vector3(0, 0, 0.45)
		l.light_color = Color(1.0, 0.3, 0.3)
		l.light_energy = 0.6
		l.omni_range = 2.2
		add_child(l)
		_omni(l)
	if BarProgress.level(&"mobilia") >= 1:
		for top in _table_tops:
			Mats.cylinder(self, 0.5, 0.012, top + Vector3(0, 0.006, 0), Color(0.95, 0.95, 0.92), false)
			Mats.cylinder(self, 0.36, 0.014, top + Vector3(0, 0.008, 0), UiTheme.RED.darkened(0.1), false)
			Mats.cylinder(self, 0.025, 0.08, top + Vector3(-0.3, 0.05, -0.25), Color(1.0, 0.97, 0.9), false)
			var flame := Mats.sphere(self, 0.014, top + Vector3(-0.3, 0.105, -0.25), Color(1.0, 0.7, 0.3), false, Vector3(1, 1.7, 1))
			flame.material_override = Mats.toon(Color(1.0, 0.7, 0.3), false, 0.5, 6.0)


func _plant(pos: Vector3) -> void:
	Mats.cylinder(self, 0.2, 0.4, pos + Vector3(0, 0.2, 0), Color(0.75, 0.38, 0.22), true, 0.24)
	var greens := [Color(0.2, 0.55, 0.25), Color(0.28, 0.65, 0.3), Color(0.15, 0.45, 0.2)]
	for i in 6:
		var a := i * TAU / 6.0
		var leaf := Mats.sphere(self, 0.16, pos + Vector3(cos(a) * 0.14, 0.62 + (i % 2) * 0.2, sin(a) * 0.14), greens[i % 3], true, Vector3(0.7, 1.4, 0.7))
		leaf.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)
	Mats.sphere(self, 0.18, pos + Vector3(0, 0.95, 0), greens[1], true, Vector3(0.8, 1.3, 0.8))


func _frame(pos: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	Mats.box(n, Vector3(0.5, 0.4, 0.03), Vector3.ZERO, Color(0.8, 0.62, 0.25))
	var sky: Color = [Color(0.45, 0.7, 0.95), Color(1.0, 0.6, 0.35), Color(0.3, 0.3, 0.55)][randi() % 3]
	Mats.box(n, Vector3(0.42, 0.18, 0.01), Vector3(0, 0.07, 0.016), sky, false)
	Mats.box(n, Vector3(0.42, 0.14, 0.01), Vector3(0, -0.09, 0.016), Color(0.3, 0.6, 0.3), false)
	Mats.sphere(n, 0.04, Vector3(0.1, 0.1, 0.02), Color(1.0, 0.9, 0.4), false, Vector3(1, 1, 0.2))


## Jukebox estilo Wurlitzer: arco de cima iluminado, tubos coloridos nas laterais,
## vitrine com a lista de músicas e grade de alto-falante.
func _jukebox(pos: Vector3) -> void:
	has_jukebox = true
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = 180 if pos.z > 0.0 else 0.0
	add_child(n)
	var madeira := _wood_dark
	var cromo := Color(0.82, 0.83, 0.88)
	var ambar := Color(1.0, 0.72, 0.25)
	# corpo e pedestal
	Mats.box(n, Vector3(0.78, 0.62, 0.46), Vector3(0, 0.31, 0), madeira.darkened(0.15))
	_plank(n, Vector3(0.84, 0.56, 0.5), Vector3(0, 0.9, 0), 0.85, 0.3)
	# arco de cima: meia-lua de madeira com a cúpula de vidro
	var arco := Mats.cylinder(n, 0.42, 0.5, Vector3(0, 1.2, 0), madeira)
	arco.rotation_degrees.x = 90
	var cupula := Mats.cylinder(n, 0.37, 0.46, Vector3(0, 1.2, 0.02), Color(1.0, 0.95, 0.85), false)
	cupula.rotation_degrees.x = 90
	cupula.material_override = Mats.glass(ambar, 0.3)
	cupula.set_meta("no_highlight", true)
	# tubos de neon acompanhando o arco
	var cores := [Color(1.0, 0.35, 0.2), Color(1.0, 0.82, 0.2), Color(0.3, 0.8, 1.0), Color(1.0, 0.35, 0.65)]
	for i in 11:
		var ang := PI * (0.06 + 0.88 * float(i) / 10.0)
		var tube := Mats.sphere(n, 0.028, Vector3(cos(ang) * 0.34, 1.2 + sin(ang) * 0.34, 0.25),
			cores[i % cores.size()], false, Vector3(1, 1, 0.5))
		tube.material_override = Mats.toon(cores[i % cores.size()], false, 0.5, 4.5)
		tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# tubos verticais nas laterais
	for side: float in [-1.0, 1.0]:
		var t := Mats.cylinder(n, 0.022, 0.52, Vector3(side * 0.37, 0.9, 0.23), cores[1], false)
		t.material_override = Mats.toon(cores[1], false, 0.5, 3.5)
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Mats.cylinder(n, 0.03, 0.08, Vector3(side * 0.37, 1.18, 0.23), cromo, false)
		Mats.cylinder(n, 0.03, 0.08, Vector3(side * 0.37, 0.62, 0.23), cromo, false)
	# vitrine da lista de músicas, acesa por dentro
	var vitrine := Mats.box(n, Vector3(0.54, 0.26, 0.03), Vector3(0, 1.03, 0.235), Color(0.1, 0.1, 0.12), false)
	vitrine.material_override = Mats.toon(Color(0.98, 0.92, 0.75), false, 0.5, 1.2)
	for i in 5:
		Mats.box(n, Vector3(0.46, 0.012, 0.01), Vector3(0, 1.13 - i * 0.045, 0.252), UiTheme.INK, false)
	Mats.box(n, Vector3(0.6, 0.04, 0.05), Vector3(0, 1.18, 0.24), cromo, false)
	# grade do alto-falante e botões
	for i in 9:
		Mats.box(n, Vector3(0.012, 0.3, 0.02), Vector3(-0.24 + i * 0.06, 0.72, 0.238), cromo.darkened(0.45), false)
	for i in 6:
		Mats.sphere(n, 0.018, Vector3(-0.2 + i * 0.08, 0.5, 0.24), cromo if i % 2 == 0 else Color(0.8, 0.15, 0.15), false)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, 1.1, 0.5 * (-1.0 if pos.z > 0.0 else 1.0))
	l.light_color = Color(1.0, 0.6, 0.35)
	l.light_energy = 2.2
	l.omni_range = 3.2
	l.light_volumetric_fog_energy = 1.8
	add_child(l)
	_omni(l)
	LightFX.pool(self, Vector3(pos.x, 0.03, pos.z + (-0.8 if pos.z > 0.0 else 0.8)), 1.4, Color(1.0, 0.55, 0.35), 0.35)
	_solid(Vector3(0.9, 1.5, 0.6), pos + Vector3(0, 0.75, 0), PLAYER_BLOCK_LAYER)


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
		b.material_override = Mats.wood(_wood.lightened(0.1), _wood.darkened(0.3), 0.6, 0.5)
		b.rotation.x = 0.15
	spinners.append(spinner)


# =================================================================== luzes

## Em GPUs fracas cada OmniLight redesenha a cena; lá usamos uma luz direcional
## quente + ambiente mais forte e mantemos só o brilho visual das lâmpadas.
func _omni(l: Light3D, keep := false) -> void:
	if GameManager.low_end and not keep:
		l.queue_free()


func _build_lights() -> void:
	# No modo leve toda luz pontual é descartada por _omni(): em GPU sem Vulkan cada uma
	# redesenha a cena inteira. Lá o salão é iluminado pela única direcional do
	# BarAtmosphere, e a forma da luz vem das poças do LightFX, que são de graça.
	if open_air:
		_build_kiosk_lights()
		return
	for x in [-2.6, 0.0, 2.6]:
		_bulb(Vector3(x, 2.35, 0.05), Color(1.0, 0.72, 0.42), 2.6, 4.6, true)
	_bulb(Vector3(room_min.x + 2.6, 2.4, 3.5), Color(1.0, 0.7, 0.45), 2.0, 5.0, false)
	_bulb(Vector3(room_max.x - 2.8, 2.4, 3.8), Color(1.0, 0.7, 0.45), 2.0, 5.0, false)
	# luminária fluorescente sobre a bancada (as bebidas precisam ficar legíveis)
	_strip_light(Vector3(-1.0, 3.06, -1.8), 1.8, Color(0.86, 0.94, 1.0), 2.2)
	# luz de serviço atrás do jogador, para a área de trabalho não virar silhueta
	_strip_light(Vector3(1.9, 3.06, -1.8), 1.2, Color(0.9, 0.95, 1.0), 1.4)


## Quiosque: lampadinhas no caibro e dois refletores quentes no balcão. O céu e a lua
## fazem o resto, então aqui a luz artificial é só o aconchego.
func _build_kiosk_lights() -> void:
	var y := room_max.y - 0.16
	for x in [-2.4, 0.0, 2.4]:
		_bulb(Vector3(x, y, 0.1), Color(1.0, 0.78, 0.5), 2.2, 4.0, x == 0.0)
	_strip_light(Vector3(-1.0, y + 0.05, -1.8), 1.8, Color(0.92, 0.96, 1.0), 1.8)
	# lanternas de papel penduradas na beira do telhado
	for i in 5:
		var px := lerpf(room_min.x + 0.8, room_max.x - 0.8, float(i) / 4.0)
		var cor: Color = [Color(1.0, 0.55, 0.35), Color(1.0, 0.85, 0.45), Color(0.45, 0.85, 0.95)][i % 3]
		Mats.cylinder(self, 0.008, 0.3, Vector3(px, y + 0.1, room_max.z - 0.15), Color(0.1, 0.1, 0.1), false)
		var lamp := Mats.sphere(self, 0.13, Vector3(px, y - 0.2, room_max.z - 0.15), cor, false, Vector3(1, 0.85, 1))
		lamp.material_override = Mats.toon(cor, false, 0.5, 3.0)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if i % 2 == 0:
			var l := OmniLight3D.new()
			l.position = Vector3(px, y - 0.3, room_max.z - 0.3)
			l.light_color = cor
			l.light_energy = 1.1
			l.omni_range = 3.4
			l.light_volumetric_fog_energy = 1.4
			add_child(l)
			_omni(l)


## Calha fluorescente: o tubo aceso mais uma luz retangular suave por baixo.
func _strip_light(pos: Vector3, length: float, tint: Color, energy: float) -> void:
	var tube := Mats.box(self, Vector3(length, 0.05, 0.09), pos, tint, false)
	tube.material_override = Mats.toon(tint, false, 0.5, 2.6)
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Mats.box(self, Vector3(length + 0.1, 0.06, 0.16), pos + Vector3(0, 0.06, 0), Color(0.78, 0.78, 0.8), false)
	var l := OmniLight3D.new()
	l.position = pos - Vector3(0, 0.1, 0)
	l.light_color = tint
	l.light_energy = energy
	l.omni_range = 3.6
	l.omni_attenuation = 1.4
	l.light_volumetric_fog_energy = 0.7
	add_child(l)
	_omni(l)
	LightFX.pool(self, Vector3(pos.x, BACK_TOP + 0.07, pos.z + 0.45), length * 0.85, tint, 0.3, 1.5)


## Lâmpada pendurada: fio, cúpula de alumínio, o bulbo aceso e a luz com sombra.
func _bulb(pos: Vector3, color: Color, energy: float, rng: float, shadows: bool) -> void:
	var cord_len := room_max.y - pos.y
	Mats.cylinder(self, 0.008, cord_len, Vector3(pos.x, pos.y + cord_len / 2.0, pos.z), Color(0.1, 0.1, 0.1), false)
	var shade := Mats.cylinder(self, 0.14, 0.11, pos + Vector3(0, 0.1, 0), Color(0.16, 0.36, 0.26), true, 0.045)
	shade.name = "Shade"
	# o avesso da cúpula é claro: é ele que rebate a luz para baixo
	var inner := Mats.cylinder(self, 0.132, 0.015, pos + Vector3(0, 0.047, 0), Color(0.95, 0.9, 0.78), false, 0.05)
	inner.material_override = Mats.toon(Color(1.0, 0.94, 0.8), false, 0.5, 0.8)
	var bulb := Mats.sphere(self, 0.05, pos, color, false)
	bulb.material_override = Mats.toon(Color(1.0, 0.92, 0.75), false, 0.5, 7.0)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a cúpula joga a luz para baixo: spot, não omni — é o que desenha a poça de luz
	var l := SpotLight3D.new()
	l.position = pos - Vector3(0, 0.06, 0)
	l.rotation_degrees.x = -90.0
	l.light_color = color
	l.light_energy = energy
	l.spot_range = rng
	l.spot_angle = 76.0
	l.spot_angle_attenuation = 0.8
	l.spot_attenuation = 1.1
	l.light_size = 0.12
	l.light_volumetric_fog_energy = 2.2
	l.shadow_enabled = shadows and not GameManager.low_end
	l.shadow_blur = 1.6
	l.shadow_normal_bias = 1.4
	add_child(l)
	_omni(l)
	# luz fraca sem sombra para o teto e as paredes não ficarem pretos
	var up := OmniLight3D.new()
	up.position = pos + Vector3(0, 0.12, 0)
	up.light_color = color
	up.light_energy = energy * 0.3
	up.omni_range = rng * 0.7
	up.light_volumetric_fog_energy = 0.6
	add_child(up)
	_omni(up)
	# feixe no ar e a poça no chão: é o que dá volume à luz (e o que sobra no modo leve)
	var drop := pos.y - 0.1
	LightFX.beam(self, pos - Vector3(0, 0.08, 0), 0.13, drop * 0.62, drop, color, 0.1 if not GameManager.low_end else 0.16)
	LightFX.pool(self, Vector3(pos.x, 0.03, pos.z), drop * 0.78, color, 0.22 if not GameManager.low_end else 0.4)
	LightFX.pool(self, Vector3(pos.x, room_max.y - 0.03, pos.z), 0.7, color, 0.3, 1.6, false)


# =================================================================== banquetas

## Banquetas espalhadas pelo balcão; compram-se mais no caderninho de investimentos.
static func seat_xs() -> Array[float]:
	var n := BarProgress.seat_count()
	var spacing := minf(1.6, 6.6 / maxf(n - 1, 1))
	var out: Array[float] = []
	for i in n:
		out.append((i - (n - 1) / 2.0) * spacing)
	return out


func _build_seats() -> void:
	var xs := seat_xs()
	for i in xs.size():
		var x: float = xs[i]
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
		if BarProgress.level(&"mobilia") > 0:
			# estofada, com encosto
			Mats.cylinder(stool, 0.25, 0.12, Vector3(0, 0.79, 0), loc.stool.darkened(0.15), true, 0.24)
			# encosto baixo: não pode tapar a visão do salão de trás do balcão
			Mats.box(stool, Vector3(0.34, 0.12, 0.05), Vector3(0, 0.98, 0.26), loc.stool.darkened(0.15))
			for sx in [-0.14, 0.14]:
				Mats.cylinder(stool, 0.012, 0.14, Vector3(sx, 0.89, 0.25), Color(0.8, 0.8, 0.85), false)
		else:
			Mats.cylinder(stool, 0.22, 0.09, Vector3(0, 0.77, 0), loc.stool, true, 0.21)


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
