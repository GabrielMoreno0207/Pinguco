class_name OutsideBuilder
extends RefCounted
## O mundo lá fora, em 3D de verdade (antes era um quadro pintado atrás da porta).
## Cada ponto tem a sua vista: a rua do bairro, a avenida do Centro e a praia.
## Tudo entra como filho do próprio bar, então a mesclagem por material pega junto
## e o nevoeiro do BarAtmosphere some com o que está longe.

## Camada de colisão das paredes invisíveis (igual à do BarBuilder).
const BLOCK := 16

var bar: Node3D
var loc: Dictionary
var room_min: Vector3
var room_max: Vector3
var lean := false
## Luzes criadas aqui (poste, vitrine, farol): o modo leve descarta.
var lights: Array[Light3D] = []


func build(owner_bar: Node3D, bar_loc: Dictionary, rmin: Vector3, rmax: Vector3, is_lean: bool) -> void:
	bar = owner_bar
	loc = bar_loc
	room_min = rmin
	room_max = rmax
	lean = is_lean
	match int(loc.outside):
		1: _downtown()
		2: _beach()
		_: _neighborhood()


# =================================================================== bairro

## Rua de bairro à noite: calçada rachada, asfalto com poça, poste de luz, fiação
## pendurada, o carro do vizinho e as casas do outro lado.
func _neighborhood() -> void:
	var z0 := room_max.z + 0.1 # onde a calçada começa
	var curb := z0 + 2.9
	var far_curb := curb + 7.0
	var houses := far_curb + 1.6
	_sidewalk(Vector3(1.0, 0.0, (z0 + curb) / 2.0), Vector2(30.0, curb - z0))
	_curb(curb, 30.0)
	_road(Vector3(1.0, 0.0, (curb + far_curb) / 2.0), Vector2(34.0, far_curb - curb), (curb + far_curb) / 2.0)
	_sidewalk(Vector3(1.0, 0.0, (far_curb + houses) / 2.0), Vector2(34.0, houses - far_curb))
	_curb(far_curb, 34.0, -1.0)

	# casas do outro lado: sobrados baixos, cada um de uma cor, com telhado e portão
	var tons := [Color(0.3, 0.14, 0.14), Color(0.16, 0.2, 0.26), Color(0.26, 0.22, 0.14),
		Color(0.2, 0.14, 0.24), Color(0.14, 0.22, 0.2), Color(0.28, 0.18, 0.12)]
	var x := -15.0
	var i := 0
	while x < 18.0:
		var w: float = 4.2 + fmod(i * 1.7, 2.6)
		var h: float = 3.2 + fmod(i * 2.3, 2.4)
		_building(Vector3(x + w / 2.0, 0.0, houses + 2.6), Vector3(w, h, 5.2), tons[i % tons.size()],
			maxf(floorf(h / 1.5), 1.0), maxf(floorf(w / 1.5), 2.0), 0.4, float(i) * 3.7)
		# telhadinho de barro inclinado
		var roof := Mats.box(bar, Vector3(w + 0.5, 0.16, 5.6), Vector3(x + w / 2.0, h + 0.08, houses + 2.6),
			Color(0.42, 0.18, 0.12), false)
		roof.rotation.x = 0.06
		# muro e portão na frente
		Mats.box(bar, Vector3(w - 0.3, 1.6, 0.14), Vector3(x + w / 2.0, 0.8, houses), tons[i % tons.size()].lightened(0.1), false)
		x += w + 0.35
		i += 1
	_skyline(houses + 10.0, 26.0)

	# postes de luz na calçada de cá
	for px: float in [5.6, -6.4]:
		_lamp_post(Vector3(px, 0.0, z0 + 2.2), Color(1.0, 0.76, 0.42), 2.6)
	_lamp_post(Vector3(0.4, 0.0, far_curb + 0.9), Color(1.0, 0.8, 0.5), 1.4)
	# fiação atravessando a rua, com o emaranhado de sempre
	for k in (1 if lean else 3):
		_wire(Vector3(5.6, 4.6 - k * 0.22, z0 + 2.2), Vector3(0.4, 4.4 - k * 0.22, far_curb + 0.9), 0.5)
	_wire(Vector3(5.6, 4.3, z0 + 2.2), Vector3(-6.4, 4.3, z0 + 2.2), 0.7)

	_parked_car(Vector3(-3.2, 0.0, curb + 1.3), Color(0.5, 0.12, 0.12), 0.0)
	_motorcycle(Vector3(1.4, 0.0, curb + 0.9))
	_trash(Vector3(-7.6, 0.0, z0 + 1.0))
	_hydrant(Vector3(7.4, 0.0, z0 + 1.2))
	_bar_facade()


# =================================================================== centro

## Avenida do Centro: prédios altos com janelas acesas, faixa de pedestre, semáforo,
## ponto de ônibus e a luz fria dos postes de LED.
func _downtown() -> void:
	var z0 := room_max.z + 0.1
	var curb := z0 + 3.4
	var far_curb := curb + 11.0
	var towers := far_curb + 2.0
	_sidewalk(Vector3(1.0, 0.0, (z0 + curb) / 2.0), Vector2(34.0, curb - z0), true)
	_curb(curb, 34.0)
	_road(Vector3(1.0, 0.0, (curb + far_curb) / 2.0), Vector2(40.0, far_curb - curb), (curb + far_curb) / 2.0)
	_crosswalk(Vector3(6.5, 0.0, (curb + far_curb) / 2.0), far_curb - curb)
	_sidewalk(Vector3(1.0, 0.0, (far_curb + towers) / 2.0), Vector2(40.0, towers - far_curb), true)
	_curb(far_curb, 40.0, -1.0)

	# torres de escritório: muitas janelas, luz fria, altura variada
	var tons := [Color(0.1, 0.11, 0.14), Color(0.13, 0.13, 0.16), Color(0.09, 0.1, 0.13)]
	var x := -18.0
	var i := 0
	while x < 20.0:
		var w: float = 5.0 + fmod(i * 2.1, 3.4)
		var h: float = 9.0 + fmod(i * 5.3, 13.0)
		_building(Vector3(x + w / 2.0, 0.0, towers + 4.0), Vector3(w, h, 8.0), tons[i % tons.size()],
			maxf(floorf(h / 1.1), 4.0), maxf(floorf(w / 1.2), 3.0), 0.55, float(i) * 5.1)
		# marquise iluminada no térreo
		Mats.box(bar, Vector3(w + 0.4, 0.18, 1.2), Vector3(x + w / 2.0, 3.1, towers - 0.6), Color(0.2, 0.2, 0.24), false)
		x += w + 0.5
		i += 1
	_skyline(towers + 16.0, 40.0, 22.0)

	for px: float in [7.2, -5.0, -14.0]:
		_lamp_post(Vector3(px, 0.0, z0 + 2.6), Color(0.85, 0.92, 1.0), 3.0)
	for px: float in [2.0, -9.0]:
		_lamp_post(Vector3(px, 0.0, far_curb + 1.0), Color(0.85, 0.92, 1.0), 2.0)
	_traffic_light(Vector3(8.6, 0.0, curb + 0.4))
	_bus_stop(Vector3(-2.0, 0.0, z0 + 1.6))
	_parked_car(Vector3(-8.5, 0.0, curb + 1.5), Color(0.1, 0.1, 0.12), 0.0)
	_parked_car(Vector3(4.0, 0.0, far_curb - 1.5), Color(0.72, 0.72, 0.75), PI)
	_bar_facade()


# =================================================================== praia

## Orla: a areia continua para todo lado, o mar ondula até o horizonte, coqueiros,
## guarda-sóis, a torre do salva-vidas e um barquinho com lanterna lá longe.
func _beach() -> void:
	var shore := room_max.z + 7.5
	# areia: um tabuleiro grande que passa por baixo do quiosque
	var sand := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(90.0, 0.4, 44.0)
	sand.mesh = sm
	sand.position = Vector3(0.0, -0.21, room_max.z - 6.0)
	sand.material_override = BarShaders.material(BarShaders.SAND, {
		"dry": Color(loc.sidewalk), "wet": Color(loc.sidewalk).darkened(0.42), "shore": shore})
	bar.add_child(sand)
	# chão sólido para o freguês não cair no vazio ao vir da areia
	_block(Vector3(60.0, 0.4, 30.0), Vector3(0.0, -0.2, room_max.z + 6.0), 1)

	# mar: plano subdividido (a onda sobe no vertex) indo até o horizonte
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160.0, 90.0)
	pm.subdivide_width = 24 if lean else 60
	pm.subdivide_depth = 16 if lean else 40
	sea.mesh = pm
	sea.position = Vector3(0.0, -0.04, shore + 45.0)
	sea.material_override = BarShaders.material(BarShaders.SEA, {"shore": shore, "depth_span": 40.0})
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar.add_child(sea)

	# deck de tábuas na frente do quiosque, descendo para a areia
	var deck := Mats.box(bar, Vector3(room_max.x - room_min.x + 1.6, 0.12, 3.0),
		Vector3(0.0, 0.06, room_max.z + 1.3), Color(loc.wood).darkened(0.12), false)
	deck.set_meta("deck", true)
	for i in int((room_max.x - room_min.x + 1.6) / 0.28):
		Mats.box(bar, Vector3(0.02, 0.13, 3.0), Vector3(room_min.x - 0.8 + i * 0.28, 0.065, room_max.z + 1.3),
			Color(loc.wood).darkened(0.4), false)
	# degrauzinho para a areia
	Mats.box(bar, Vector3(room_max.x - room_min.x + 1.0, 0.1, 0.5), Vector3(0.0, 0.03, room_max.z + 3.0),
		Color(loc.wood).darkened(0.2), false)

	# coqueiros de alturas diferentes, inclinados para o mar
	for p: Array in [[-7.4, 1.2, 4.6], [8.2, 2.0, 5.1], [-10.0, 6.5, 4.0], [11.6, 7.4, 4.4],
			[-6.0, 10.5, 3.6], [9.0, 12.0, 3.9], [-13.5, -1.0, 4.8]]:
		_palm(Vector3(p[0], 0.0, p[1]), p[2], p[0] * 0.07)
	# moitas de capim da praia
	for i in (8 if lean else 22):
		var gx := -22.0 + fmod(i * 7.3, 44.0)
		var gz := room_max.z - 2.0 + fmod(i * 3.1, 9.0)
		if absf(gx) < room_max.x + 1.5 and gz < room_max.z + 3.5:
			continue
		_dune_grass(Vector3(gx, 0.0, gz))

	# guarda-sóis e espreguiçadeiras espalhados na areia
	for p: Array in [[-5.5, 9.0, Color(1.0, 0.45, 0.3)], [6.4, 10.4, Color(0.15, 0.6, 0.72)],
			[-9.5, 12.2, Color(1.0, 0.8, 0.2)]]:
		_beach_umbrella(Vector3(p[0], 0.0, p[1]), p[2])
	_lifeguard_tower(Vector3(13.0, 0.0, shore - 2.2))
	# pedras na ponta da praia, com a espuma batendo
	for i in 7:
		var rx := -19.0 - fmod(i * 2.3, 5.0)
		Mats.sphere(bar, 0.7 + fmod(i * 0.37, 0.6), Vector3(rx, 0.1, shore - 1.0 + fmod(i * 3.1, 4.0)),
			Color(0.17, 0.16, 0.18), true, Vector3(1.3, 0.7, 1.1))
	_boat(Vector3(-16.0, 0.0, shore + 22.0))
	_island(Vector3(26.0, 0.0, shore + 62.0), 16.0, 5.0)
	_island(Vector3(-34.0, 0.0, shore + 70.0), 22.0, 3.4)
	_bar_facade()


# =================================================================== peças comuns

func _sidewalk(pos: Vector3, size: Vector2, paved := false) -> void:
	var slab := Mats.box(bar, Vector3(size.x, 0.14, size.y), pos + Vector3(0, 0.07, 0), Color(loc.sidewalk), false)
	if paved:
		# ladrilho português: desenho em xadrez claro/escuro
		slab.material_override = BarShaders.material(BarShaders.FLOOR_ALT, {
			"pattern": 1, "col_a": Color(loc.sidewalk), "col_b": Color(loc.sidewalk).darkened(0.45), "grime": 0.35})
	else:
		slab.material_override = BarShaders.material(BarShaders.FLOOR_ALT, {
			"pattern": 1, "col_a": Color(loc.sidewalk), "col_b": Color(loc.sidewalk).darkened(0.12), "grime": 0.55})
	_block(Vector3(size.x, 0.3, size.y), pos + Vector3(0, 0.0, 0), 1)


func _curb(z: float, width: float, facing := 1.0) -> void:
	Mats.box(bar, Vector3(width, 0.16, 0.16), Vector3(1.0, 0.08, z - facing * 0.08), Color(0.72, 0.7, 0.66), false)


func _road(pos: Vector3, size: Vector2, lane_z: float) -> void:
	var road := Mats.box(bar, Vector3(size.x, 0.1, size.y), pos + Vector3(0, 0.0, 0), Color(0.08, 0.08, 0.09), false)
	road.material_override = BarShaders.material(BarShaders.ASPHALT, {"lane_z": lane_z})


func _crosswalk(pos: Vector3, depth: float) -> void:
	for i in 7:
		Mats.box(bar, Vector3(0.45, 0.02, depth - 1.0), pos + Vector3(-1.8 + i * 0.6, 0.06, 0.0),
			Color(0.88, 0.86, 0.8), false)


## Prédio/casa com a fachada de janelas acesas do shader FACADE.
func _building(pos: Vector3, size: Vector3, tone: Color, floors: float, cols: float, lit: float, seed: float) -> void:
	var b := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	b.mesh = m
	b.position = pos + Vector3(0, size.y / 2.0, 0)
	b.material_override = BarShaders.material(BarShaders.FACADE, {
		"wall": tone, "trim": tone.darkened(0.35), "floors": floors, "cols": cols,
		"lit_chance": lit, "seed": seed})
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar.add_child(b)


## Silhueta do que está muito longe: caixas escuras que o nevoeiro come quase todas.
func _skyline(z: float, half_width: float, tall := 9.0) -> void:
	var dark := Mats.toon(Color(0.06, 0.055, 0.08), false)
	for i in (10 if lean else 26):
		var w := 2.4 + fmod(i * 1.9, 4.0)
		var h := tall * (0.45 + fmod(i * 0.37, 0.55))
		var mi := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(w, h, 6.0)
		mi.mesh = m
		mi.position = Vector3(-half_width + fmod(i * 5.7, half_width * 2.0), h / 2.0, z + fmod(i * 3.3, 12.0))
		mi.material_override = dark
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bar.add_child(mi)


func _lamp_post(pos: Vector3, tint: Color, energy: float) -> void:
	Mats.cylinder(bar, 0.07, 4.4, pos + Vector3(0, 2.2, 0), Color(0.22, 0.22, 0.24), true, 0.05)
	# braço curvo e a luminária
	Mats.box(bar, Vector3(0.9, 0.07, 0.07), pos + Vector3(0.45, 4.35, 0), Color(0.22, 0.22, 0.24), false)
	var head := Mats.box(bar, Vector3(0.44, 0.1, 0.26), pos + Vector3(0.86, 4.26, 0), tint, false)
	head.material_override = Mats.toon(tint, false, 0.4, 3.0)
	Mats.box(bar, Vector3(0.5, 0.08, 0.3), pos + Vector3(0.86, 4.35, 0), Color(0.3, 0.3, 0.32), false)
	var l := SpotLight3D.new()
	l.position = pos + Vector3(0.86, 4.2, 0)
	l.rotation_degrees.x = -90.0
	l.light_color = tint
	l.light_energy = energy
	l.spot_range = 11.0
	l.spot_angle = 62.0
	l.spot_angle_attenuation = 0.9
	l.light_volumetric_fog_energy = 1.6
	l.shadow_enabled = false
	bar.add_child(l)
	lights.append(l)
	# o cone de luz do poste e a mancha no asfalto: é o que faz a rua parecer noite
	LightFX.beam(bar, pos + Vector3(0.86, 4.1, 0), 0.26, 2.6, 4.1, tint, 0.12)
	LightFX.pool(bar, pos + Vector3(0.86, 0.17, 0), 3.2, tint, 0.3, 1.8)


func _wire(a: Vector3, b: Vector3, sag: float) -> void:
	var color := Color(0.06, 0.06, 0.07)
	for i in 10:
		var t0 := float(i) / 10.0
		var t1 := float(i + 1) / 10.0
		var p0 := a.lerp(b, t0) - Vector3(0, sin(t0 * PI) * sag, 0)
		var p1 := a.lerp(b, t1) - Vector3(0, sin(t1 * PI) * sag, 0)
		Mats.limb(bar, p0, p1, 0.015, color)


func _parked_car(pos: Vector3, body: Color, yaw: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	bar.add_child(n)
	Mats.box(n, Vector3(1.75, 0.5, 4.2), Vector3(0, 0.62, 0), body)
	Mats.box(n, Vector3(1.6, 0.46, 2.0), Vector3(0, 1.05, -0.15), body.darkened(0.12))
	# vidros
	Mats.box(n, Vector3(1.52, 0.34, 0.06), Vector3(0, 1.08, 0.86), Color(0.07, 0.09, 0.12), false)
	Mats.box(n, Vector3(1.52, 0.34, 0.06), Vector3(0, 1.08, -1.14), Color(0.07, 0.09, 0.12), false)
	for sx: float in [-0.81, 0.81]:
		Mats.box(n, Vector3(0.06, 0.3, 1.7), Vector3(sx, 1.08, -0.15), Color(0.07, 0.09, 0.12), false)
	# rodas
	for sx: float in [-0.88, 0.88]:
		for sz: float in [-1.45, 1.45]:
			var w := Mats.cylinder(n, 0.33, 0.2, Vector3(sx, 0.33, sz), Color(0.07, 0.07, 0.08))
			w.rotation_degrees.z = 90.0
			Mats.cylinder(n, 0.16, 0.22, Vector3(sx, 0.33, sz), Color(0.6, 0.6, 0.64), false).rotation_degrees.z = 90.0
	# lanternas
	for sx: float in [-0.6, 0.6]:
		var tail := Mats.box(n, Vector3(0.3, 0.14, 0.05), Vector3(sx, 0.75, -2.1), Color(0.8, 0.1, 0.1), false)
		tail.material_override = Mats.toon(Color(0.9, 0.12, 0.12), false, 0.4, 1.6)
		Mats.box(n, Vector3(0.32, 0.16, 0.05), Vector3(sx, 0.75, 2.1), Color(0.95, 0.92, 0.8), false)
	Mats.box(n, Vector3(0.4, 0.12, 0.03), Vector3(0, 0.6, 2.12), Color(0.9, 0.9, 0.85), false)
	_block(Vector3(2.0, 1.4, 4.4), pos + Vector3(0, 0.7, 0), BLOCK)


func _motorcycle(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = 0.3
	bar.add_child(n)
	for sz: float in [-0.62, 0.62]:
		var w := Mats.cylinder(n, 0.27, 0.1, Vector3(0, 0.27, sz), Color(0.07, 0.07, 0.08))
		w.rotation_degrees.z = 90.0
	Mats.box(n, Vector3(0.18, 0.22, 1.1), Vector3(0, 0.56, 0), Color(0.55, 0.12, 0.12))
	Mats.box(n, Vector3(0.3, 0.12, 0.5), Vector3(0, 0.72, -0.2), Color(0.1, 0.1, 0.11))
	Mats.cylinder(n, 0.035, 0.7, Vector3(0, 0.62, 0.6), Color(0.3, 0.3, 0.32), false).rotation.x = 0.35
	Mats.box(n, Vector3(0.52, 0.05, 0.05), Vector3(0, 0.95, 0.72), Color(0.2, 0.2, 0.22), false)
	Mats.sphere(n, 0.1, Vector3(0, 0.84, 0.76), Color(0.9, 0.88, 0.8), false, Vector3(1, 1, 0.5))


func _trash(pos: Vector3) -> void:
	Mats.cylinder(bar, 0.27, 0.72, pos + Vector3(0, 0.36, 0), Color(0.18, 0.3, 0.22), true, 0.3)
	for i in 4:
		var a := i * 1.7
		Mats.sphere(bar, 0.21 + fmod(i * 0.09, 0.1), pos + Vector3(0.5 + cos(a) * 0.3, 0.19, sin(a) * 0.28),
			Color(0.1, 0.1, 0.11), true, Vector3(1.2, 0.9, 1.1))
	# caixa de papelão amassada
	var box := Mats.box(bar, Vector3(0.44, 0.3, 0.34), pos + Vector3(-0.55, 0.15, 0.2), Color(0.5, 0.36, 0.22))
	box.rotation.y = 0.5


func _hydrant(pos: Vector3) -> void:
	Mats.cylinder(bar, 0.12, 0.6, pos + Vector3(0, 0.3, 0), Color(0.72, 0.12, 0.1))
	Mats.sphere(bar, 0.13, pos + Vector3(0, 0.63, 0), Color(0.72, 0.12, 0.1))
	for sx: float in [-0.14, 0.14]:
		Mats.cylinder(bar, 0.05, 0.1, pos + Vector3(sx, 0.44, 0), Color(0.6, 0.1, 0.08), false).rotation_degrees.z = 90.0


func _traffic_light(pos: Vector3) -> void:
	Mats.cylinder(bar, 0.08, 3.6, pos + Vector3(0, 1.8, 0), Color(0.16, 0.17, 0.18))
	var head := Node3D.new()
	head.position = pos + Vector3(0, 3.3, -0.2)
	bar.add_child(head)
	Mats.box(head, Vector3(0.3, 0.84, 0.26), Vector3.ZERO, Color(0.12, 0.13, 0.14))
	var cores := [Color(0.9, 0.15, 0.12), Color(0.95, 0.75, 0.1), Color(0.2, 0.8, 0.3)]
	for i in 3:
		var lamp := Mats.sphere(head, 0.09, Vector3(0, 0.28 - i * 0.28, -0.14), cores[i], false)
		# só o vermelho fica aceso
		lamp.material_override = Mats.toon(cores[i], false, 0.4, 3.0 if i == 0 else 0.0)


func _bus_stop(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	bar.add_child(n)
	for sx: float in [-1.4, 1.4]:
		Mats.cylinder(n, 0.05, 2.4, Vector3(sx, 1.2, 0.5), Color(0.2, 0.21, 0.23), false)
		Mats.cylinder(n, 0.05, 2.4, Vector3(sx, 1.2, -0.5), Color(0.2, 0.21, 0.23), false)
	Mats.box(n, Vector3(3.1, 0.08, 1.3), Vector3(0, 2.42, 0), Color(0.22, 0.23, 0.26))
	# painel de propaganda iluminado (o que mais ilumina um ponto de ônibus)
	var panel := Mats.box(n, Vector3(1.2, 1.7, 0.06), Vector3(1.4, 1.1, 0), Color(0.9, 0.85, 0.7), false)
	panel.material_override = Mats.toon(Color(0.95, 0.88, 0.72), false, 0.4, 1.8)
	Mats.box(n, Vector3(2.6, 0.08, 0.4), Vector3(-0.2, 0.5, -0.4), Color(0.3, 0.3, 0.34))
	Mats.box(n, Vector3(2.6, 0.5, 0.06), Vector3(-0.2, 0.75, -0.58), Color(0.3, 0.3, 0.34), false)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(1.2, 1.2, 0.3)
	l.light_color = Color(1.0, 0.95, 0.85)
	l.light_energy = 1.2
	l.omni_range = 4.0
	bar.add_child(l)
	lights.append(l)


## Fachada do próprio bar vista de fora: a parte da parede acima da porta, com
## o reboco encardido e o letreiro batendo nela.
func _bar_facade() -> void:
	if bool(loc.get("open", false)):
		return
	var z := room_max.z + 0.22
	var w := room_max.x - room_min.x + 0.6
	Mats.box(bar, Vector3(w, 0.3, 0.3), Vector3((room_max.x + room_min.x) / 2.0, room_max.y + 0.1, z),
		Color(loc.wood_dark), false)
	# toldo listrado em cima da porta
	for i in 8:
		var cor: Color = Color(0.75, 0.15, 0.15) if i % 2 == 0 else Color(0.92, 0.9, 0.84)
		var slat := Mats.box(bar, Vector3(0.42, 0.06, 1.3), Vector3(1.5 + i * 0.42, 2.72, z + 0.6), cor, false)
		slat.rotation.x = -0.22


# =================================================================== praia

func _palm(pos: Vector3, height: float, tilt: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.z = tilt
	n.rotation.y = pos.x * 0.3
	bar.add_child(n)
	# tronco em gomos, afinando e curvando
	var segs := int(height / 0.55)
	for i in segs:
		var t := float(i) / segs
		var r := lerpf(0.17, 0.1, t)
		var px := sin(t * 1.5) * height * 0.08
		Mats.cylinder(n, r, height / segs + 0.04, Vector3(px, height * t + height / segs / 2.0, 0.0),
			Color(0.42, 0.3, 0.19) if i % 2 == 0 else Color(0.46, 0.33, 0.21), i % 2 == 0, r * 0.92)
	var top := Vector3(sin(1.5) * height * 0.08, height, 0.0)
	# cocos
	for i in 3:
		var a := i * 2.1
		Mats.sphere(n, 0.1, top + Vector3(cos(a) * 0.16, -0.1, sin(a) * 0.16), Color(0.36, 0.44, 0.16))
	# folhas: cada uma é uma fieira de peças que acompanha a curva da palma, com a
	# nervura por dentro. Peça solta na ponta vira caco — por isso cada segmento é
	# girado para a tangente da curva e os segmentos se sobrepõem.
	for i in 8:
		var a := i * TAU / 8.0 + 0.3
		var leaf := Node3D.new()
		leaf.position = top
		leaf.rotation.y = a
		# umas palmas mais caídas que outras
		var droop := 1.1 + fmod(i * 0.47, 0.8)
		n.add_child(leaf)
		var verde := Color(0.16, 0.42, 0.2).lerp(Color(0.3, 0.58, 0.24), fmod(i * 0.37, 1.0))
		var verde_escuro := verde.darkened(0.22)
		var ribs := 11
		var reach := 2.3
		for k in ribs:
			var t := float(k) / (ribs - 1)
			var t2 := float(k + 1) / (ribs - 1)
			var p0 := Vector3(0.22 + t * reach, -t * t * droop, 0.0)
			var p1 := Vector3(0.22 + t2 * reach, -t2 * t2 * droop, 0.0)
			var mid := (p0 + p1) * 0.5
			var seg := Mats.box(leaf, Vector3(p0.distance_to(p1) * 1.5, 0.03, lerpf(0.46, 0.08, t)),
				mid, verde, false)
			seg.rotation.z = atan2(p1.y - p0.y, p1.x - p0.x)
			# recortes da palma: os folíolos saindo da nervura
			if k % 2 == 0 and t < 0.92:
				for side: float in [-1.0, 1.0]:
					var fol := Mats.box(leaf, Vector3(0.1, 0.02, 0.3), mid + Vector3(0, 0, side * 0.22),
						verde_escuro, false)
					fol.rotation = Vector3(side * 0.5, 0.0, seg.rotation.z)
		# nervura
		for k in ribs - 1:
			var t := float(k) / (ribs - 1)
			var t2 := float(k + 1) / (ribs - 1)
			Mats.limb(leaf, Vector3(0.22 + t * reach, -t * t * droop, 0.0),
				Vector3(0.22 + t2 * reach, -t2 * t2 * droop, 0.0), 0.018, Color(0.3, 0.4, 0.16))
		Mats.merge_children(leaf)
	_block(Vector3(0.5, height, 0.5), pos + Vector3(0, height / 2.0, 0), BLOCK)


func _dune_grass(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	bar.add_child(n)
	for i in 9:
		var a := i * 1.4
		var h := 0.4 + fmod(i * 0.21, 0.35)
		var blade := Mats.box(n, Vector3(0.035, h, 0.012), Vector3(cos(a) * 0.1, h / 2.0, sin(a) * 0.1),
			Color(0.46, 0.5, 0.26).darkened(fmod(i * 0.19, 0.2)), false)
		blade.rotation = Vector3(sin(a) * 0.5, a, cos(a) * 0.5)
	Mats.merge_children(n)


func _beach_umbrella(pos: Vector3, tint: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.z = 0.12
	n.rotation.y = pos.x
	bar.add_child(n)
	Mats.cylinder(n, 0.035, 2.3, Vector3(0, 1.15, 0), Color(0.85, 0.8, 0.62), false)
	# dois cones listrados
	Mats.cylinder(n, 1.05, 0.32, Vector3(0, 2.15, 0), tint, true, 0.04)
	Mats.cylinder(n, 0.58, 0.2, Vector3(0, 2.25, 0), Color(0.98, 0.97, 0.92), false, 0.04)
	Mats.sphere(n, 0.06, Vector3(0, 2.4, 0), tint.darkened(0.2), false)
	# canga esticada na areia
	var towel := Mats.box(n, Vector3(1.1, 0.02, 1.7), Vector3(0.9, 0.01, 0.2), tint.lightened(0.25), false)
	towel.rotation.y = 0.3
	_block(Vector3(0.4, 2.3, 0.4), pos + Vector3(0, 1.15, 0), BLOCK)


func _lifeguard_tower(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = PI
	bar.add_child(n)
	var branco := Color(0.92, 0.9, 0.85)
	for sx: float in [-0.8, 0.8]:
		for sz: float in [-0.8, 0.8]:
			Mats.cylinder(n, 0.07, 2.2, Vector3(sx, 1.1, sz), Color(0.6, 0.45, 0.28), false)
	Mats.box(n, Vector3(2.0, 0.12, 2.0), Vector3(0, 2.2, 0), Color(0.62, 0.47, 0.3))
	Mats.box(n, Vector3(2.0, 1.0, 0.1), Vector3(0, 2.7, -0.95), branco)
	for sx: float in [-0.95, 0.95]:
		Mats.box(n, Vector3(0.1, 1.0, 2.0), Vector3(sx, 2.7, 0), branco)
	var roof := Mats.box(n, Vector3(2.4, 0.1, 2.4), Vector3(0, 3.3, 0), Color(0.85, 0.3, 0.2))
	roof.rotation.x = 0.1
	for sx: float in [-0.95, 0.95]:
		Mats.cylinder(n, 0.05, 0.6, Vector3(sx, 3.0, 0.9), branco, false)
	# escada
	for i in 5:
		Mats.box(n, Vector3(1.4, 0.06, 0.22), Vector3(0, 0.35 + i * 0.42, 1.3 + i * 0.1), Color(0.6, 0.45, 0.28), false)
	# bandeira vermelha na haste
	Mats.cylinder(n, 0.03, 2.0, Vector3(1.4, 1.0, -0.6), branco, false)
	var flag := Mats.box(n, Vector3(0.02, 0.4, 0.6), Vector3(1.4, 1.75, -0.92), Color(0.85, 0.12, 0.12), false)
	flag.rotation.y = 0.2
	_block(Vector3(2.2, 2.4, 2.2), pos + Vector3(0, 1.2, 0), BLOCK)


func _boat(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = 0.5
	bar.add_child(n)
	var hull := Mats.sphere(n, 1.5, Vector3(0, 0.1, 0), Color(0.82, 0.8, 0.74), true, Vector3(0.34, 0.3, 1.0))
	hull.name = "Casco"
	Mats.box(n, Vector3(0.9, 0.1, 1.2), Vector3(0, 0.3, 0), Color(0.3, 0.22, 0.14), false)
	Mats.cylinder(n, 0.05, 2.6, Vector3(0, 1.4, -0.2), Color(0.75, 0.7, 0.6), false)
	var lantern := Mats.sphere(n, 0.11, Vector3(0, 2.6, -0.2), Color(1.0, 0.85, 0.5), false)
	lantern.material_override = Mats.toon(Color(1.0, 0.82, 0.45), false, 0.4, 5.0)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, 2.6, -0.2)
	l.light_color = Color(1.0, 0.8, 0.45)
	l.light_energy = 2.0
	l.omni_range = 6.0
	bar.add_child(l)
	lights.append(l)


## Morro no horizonte: só a silhueta, que o nevoeiro quase apaga.
func _island(pos: Vector3, width: float, height: float) -> void:
	var n := Node3D.new()
	n.position = pos
	bar.add_child(n)
	var dark := Mats.toon(Color(0.05, 0.07, 0.11), false)
	for i in 4:
		var m := Mats.sphere(n, width * 0.3, Vector3(-width * 0.3 + i * width * 0.2, 0.0, 0.0),
			Color(0.05, 0.07, 0.11), false, Vector3(1.0, height / (width * 0.3) * (0.5 + fmod(i * 0.37, 0.5)), 0.6))
		m.material_override = dark
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# =================================================================== util

## Corpo de colisão invisível (chão de fora e obstáculos da rua/areia).
func _block(size: Vector3, pos: Vector3, layer: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	bar.add_child(body)
