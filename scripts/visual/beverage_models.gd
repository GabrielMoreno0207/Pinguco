class_name BeverageModels
extends RefCounted
## Modelos 3D estilizados das bebidas, salgados e do copo americano.
## Garrafas são geradas por revolução de um perfil (lathe): ombro e gargalo suaves.
## Todos olham para +Z (o rótulo fica na frente). Origem = base apoiada.

static var _lathe_cache: Dictionary = {}


## detailed = false → versão leve (estoque decorativo): sem letra 3D nem contornos.
static func build_container(bev: BeverageData, detailed := true) -> Node3D:
	var root := Node3D.new()
	root.name = "Bev_%s" % bev.id
	match bev.vessel:
		BeverageData.Vessel.LONGNECK:
			_longneck(root, bev, detailed)
		BeverageData.Vessel.BOTTLE:
			_cachaca_bottle(root, bev, detailed)
		BeverageData.Vessel.WINE:
			_wine_bottle(root, bev, detailed)
		BeverageData.Vessel.SQUARE:
			_square_bottle(root, bev, detailed)
		BeverageData.Vessel.JAR:
			_jar(root, bev, detailed)
		BeverageData.Vessel.POT:
			_pot(root, bev, detailed)
		BeverageData.Vessel.CAN:
			_can(root, bev, detailed)
		BeverageData.Vessel.PLATE:
			_plate(root, bev, detailed)
	return root


# ------------------------------------------------------------------ recipientes

static func _longneck(root: Node3D, bev: BeverageData, detailed: bool) -> void:
	var prof := _profile([[0.0, 0.0], [0.04, 0.0], [0.046, 0.008], [0.046, 0.17], [0.042, 0.2],
		[0.028, 0.235], [0.02, 0.26], [0.019, 0.31], [0.022, 0.318], [0.02, 0.328]])
	var clear := bev.bottle_color.get_luminance() > 0.6
	_mesh(root, lathe(prof, 16), Vector3.ZERO, Mats.glass(bev.bottle_color, 0.45 if clear else 0.88, detailed))
	if clear:
		_mesh(root, lathe(_scaled(prof, 0.86, 0.75), 12), Vector3(0, 0.008, 0), Mats.toon(bev.color, false, 0.2))
	# tampinha de metal com serrilhado
	var cap_col := Color(0.88, 0.72, 0.2) if bev.id != &"agua" else Color(0.2, 0.45, 0.95)
	var cap := Mats.cylinder(root, 0.023, 0.014, Vector3(0, 0.335, 0), cap_col, false, 0.021)
	cap.set_meta("cap", true)
	if detailed:
		var teeth := Node3D.new()
		root.add_child(teeth)
		for i in 10:
			var a := i * TAU / 10.0
			Mats.box(teeth, Vector3(0.006, 0.012, 0.004), Vector3(cos(a) * 0.0235, 0.333, sin(a) * 0.0235), cap_col.darkened(0.2), false).rotation.y = -a
		Mats.merge_children(teeth)
	# rótulo do gargalo + rótulo principal
	Mats.cylinder(root, 0.024, 0.03, Vector3(0, 0.27, 0), bev.color.darkened(0.15), false, 0.021)
	_label(root, bev, 0.048, 0.095, 0.1, detailed)
	_shine(root, 0.046, 0.03, 0.17, detailed)
	if detailed and bev.station == &"fridge":
		_droplets(root, 0.047, 0.02, 0.2)


static func _cachaca_bottle(root: Node3D, bev: BeverageData, detailed: bool) -> void:
	var prof := _profile([[0.0, 0.0], [0.05, 0.0], [0.057, 0.01], [0.057, 0.22], [0.05, 0.255],
		[0.03, 0.285], [0.022, 0.3], [0.021, 0.37], [0.025, 0.375], [0.022, 0.385]])
	_mesh(root, lathe(prof, 16), Vector3.ZERO, Mats.glass(bev.bottle_color, 0.55, detailed))
	# líquido (nível até o ombro)
	_mesh(root, lathe(_profile([[0.0, 0.0], [0.05, 0.0], [0.051, 0.21], [0.0, 0.21]]), 12), Vector3(0, 0.008, 0),
		Mats.glass(bev.color, 0.75) if bev.color.get_luminance() > 0.85 else Mats.toon(bev.color, false, 0.2))
	# rolha + lacre
	Mats.cylinder(root, 0.02, 0.035, Vector3(0, 0.395, 0), Color(0.72, 0.5, 0.3), false, 0.022)
	Mats.cylinder(root, 0.026, 0.03, Vector3(0, 0.36, 0), bev.color.darkened(0.35), false)
	_label(root, bev, 0.059, 0.115, 0.13, detailed)
	_shine(root, 0.057, 0.03, 0.22, detailed)


static func _wine_bottle(root: Node3D, bev: BeverageData, detailed: bool) -> void:
	var prof := _profile([[0.0, 0.0], [0.046, 0.0], [0.052, 0.012], [0.052, 0.22], [0.046, 0.25],
		[0.026, 0.27], [0.019, 0.29], [0.018, 0.38], [0.021, 0.385]])
	_mesh(root, lathe(prof, 16), Vector3.ZERO, Mats.glass(bev.bottle_color, 0.92, detailed))
	# cápsula de alumínio no gargalo
	Mats.cylinder(root, 0.021, 0.07, Vector3(0, 0.355, 0), Color(0.6, 0.06, 0.12), false, 0.02)
	Mats.cylinder(root, 0.022, 0.012, Vector3(0, 0.335, 0), Color(0.9, 0.75, 0.3), false)
	_label(root, bev, 0.054, 0.11, 0.11, detailed)
	_shine(root, 0.052, 0.04, 0.22, detailed)


static func _square_bottle(root: Node3D, bev: BeverageData, detailed: bool) -> void:
	var body := BoxMesh.new()
	body.size = Vector3(0.1, 0.2, 0.075)
	_mesh(root, body, Vector3(0, 0.1, 0), Mats.glass(bev.bottle_color, 0.5, detailed))
	var liq := BoxMesh.new()
	liq.size = Vector3(0.088, 0.17, 0.064)
	_mesh(root, liq, Vector3(0, 0.09, 0), Mats.toon(bev.color, false, 0.15))
	# ombro + gargalo curtinho + tampa de rosca
	_mesh(root, lathe(_profile([[0.05, 0.0], [0.04, 0.02], [0.022, 0.04], [0.02, 0.07], [0.0, 0.07]]), 4, PI / 4.0),
		Vector3(0, 0.2, 0), Mats.glass(bev.bottle_color, 0.5))
	Mats.cylinder(root, 0.025, 0.04, Vector3(0, 0.285, 0), Color(0.12, 0.1, 0.1) if bev.id != &"gin" else Color(0.85, 0.85, 0.88), false)
	# selo diagonal (garrafa de "importado")
	var seal := Mats.box(root, Vector3(0.012, 0.16, 0.002), Vector3(0.0, 0.17, 0.0385), bev.color.darkened(0.3), false)
	seal.rotation.z = 0.6
	_flat_label(root, bev, Vector3(0, 0.1, 0.0385), Vector2(0.085, 0.09), detailed)
	if detailed:
		var streak := Mats.box(root, Vector3(0.008, 0.15, 0.002), Vector3(-0.038, 0.11, 0.0386), Color.WHITE, false)
		streak.material_override = Mats.unshaded(Color(1, 1, 1, 0.45), true)
		streak.set_meta("no_highlight", true)


static func _jar(root: Node3D, bev: BeverageData, detailed: bool) -> void:
	# jarra de vidro com bico e alça; líquido translúcido com superfície mais clara
	var prof := _profile([[0.0, 0.0], [0.07, 0.0], [0.078, 0.01], [0.084, 0.2], [0.09, 0.235], [0.088, 0.24]])
	_mesh(root, lathe(prof, 18), Vector3.ZERO, Mats.glass(Color(0.9, 1, 1), 0.22, detailed))
	_mesh(root, lathe(_profile([[0.0, 0.0], [0.072, 0.0], [0.078, 0.17], [0.0, 0.17]]), 14), Vector3(0, 0.01, 0),
		Mats.glass(bev.color, 0.82))
	var top := Mats.cylinder(root, 0.077, 0.003, Vector3(0, 0.181, 0), bev.color.lightened(0.3), false)
	top.material_override = Mats.toon(bev.color.lightened(0.3), false, 0.2, 0.2)
	# bico
	var spout := Mats.box(root, Vector3(0.03, 0.012, 0.03), Vector3(0.088, 0.236, 0), Color(0.9, 1, 1), false)
	spout.material_override = Mats.glass(Color(0.9, 1, 1), 0.35)
	spout.rotation = Vector3(0, PI / 4.0, 0.25)
	var handle := Mats.torus(root, 0.045, 0.06, Vector3(-0.09, 0.13, 0), Color(0.9, 1, 1))
	handle.material_override = Mats.glass(Color(0.9, 1, 1), 0.5)
	handle.rotation_degrees.x = 90
	handle.scale = Vector3(1.0, 1.0, 1.4)
	if bev.id == &"caipirinha":
		# rodelas de limão (casca, polpa e gomos) + gelo picado
		for i in 4:
			var ang := i * TAU / 4.0 + 0.3
			_lime_wheel(root, Vector3(cos(ang) * 0.04, 0.184 + (i % 2) * 0.006, sin(ang) * 0.04), 0.024, Vector3(0.3 * cos(ang), ang, 0.3 * sin(ang)))
		for i in 4:
			_ice(root, Vector3(-0.025 + i * 0.018, 0.186, -0.03 + i * 0.02), 0.026, i)
	else:
		# morangos com folhinha + canudo
		for i in 3:
			var ang := i * TAU / 3.0
			_strawberry(root, Vector3(cos(ang) * 0.04, 0.19, sin(ang) * 0.04), 0.022)
		var straw := Mats.cylinder(root, 0.005, 0.22, Vector3(0.03, 0.23, 0.0), Color(1, 0.3, 0.5), false)
		straw.rotation.z = -0.3
	_shine(root, 0.085, 0.03, 0.2, detailed)
	_label(root, bev, 0.086, 0.09, 0.07, detailed)


static func _lime_wheel(parent: Node3D, pos: Vector3, r: float, rot: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation = rot
	parent.add_child(n)
	Mats.cylinder(n, r, 0.006, Vector3.ZERO, Color(0.3, 0.65, 0.12), false)
	Mats.cylinder(n, r * 0.84, 0.0065, Vector3.ZERO, Color(0.95, 0.97, 0.8), false)
	Mats.cylinder(n, r * 0.76, 0.007, Vector3.ZERO, Color(0.62, 0.88, 0.3), false)
	for k in 4:
		Mats.box(n, Vector3(r * 1.5, 0.0072, 0.0015), Vector3.ZERO, Color(0.9, 0.97, 0.75), false).rotation.y = k * PI / 4.0
	Mats.merge_children(n)
	return n


static func _strawberry(parent: Node3D, pos: Vector3, r: float) -> void:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	Mats.sphere(n, r, Vector3.ZERO, Color(0.88, 0.1, 0.2), false, Vector3(1.0, 1.15, 1.0))
	for k in 5:
		var ang := k * TAU / 5.0
		var leaf := Mats.sphere(n, r * 0.5, Vector3(cos(ang) * r * 0.5, r * 1.05, sin(ang) * r * 0.5), Color(0.2, 0.6, 0.2), false, Vector3(1.0, 0.3, 0.5))
		leaf.rotation.y = -ang
	for k in 6:
		var ang := k * 2.2
		Mats.sphere(n, r * 0.12, Vector3(cos(ang) * r * 0.98, sin(k * 1.3) * r * 0.5, sin(ang) * r * 0.98), Color(1.0, 0.9, 0.4), false)
	Mats.merge_children(n)


static func _ice(parent: Node3D, pos: Vector3, size: float, seed: int) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	var ice := _mesh(parent, mesh, pos, Mats.glass(Color(0.85, 0.97, 1.0), 0.6))
	ice.rotation = Vector3(0.4 * seed, 0.7 * seed + 0.3, 0.2 * seed)
	return ice


static func _pot(root: Node3D, bev: BeverageData, detailed: bool) -> void:
	# panela de alumínio no fogareiro
	var alu := Color(0.75, 0.76, 0.8)
	Mats.cylinder(root, 0.1, 0.03, Vector3(0, 0.015, 0), Color(0.2, 0.2, 0.22), false)
	Mats.cylinder(root, 0.06, 0.006, Vector3(0, 0.033, 0), Color(1.0, 0.45, 0.1), false).material_override = Mats.toon(Color(1.0, 0.5, 0.1), false, 0.5, 2.0)
	var pot := lathe(_profile([[0.0, 0.0], [0.085, 0.0], [0.095, 0.01], [0.095, 0.13], [0.1, 0.135], [0.09, 0.135], [0.088, 0.03], [0.0, 0.03]]), 18)
	_mesh(root, pot, Vector3(0, 0.035, 0), Mats.toon(alu, detailed, 0.35))
	Mats.cylinder(root, 0.088, 0.01, Vector3(0, 0.15, 0), bev.color, false)
	for side in [-1.0, 1.0]:
		Mats.box(root, Vector3(0.05, 0.012, 0.025), Vector3(side * 0.12, 0.15, 0), Color(0.15, 0.12, 0.1), false)
	# canela e rodelas de laranja boiando
	Mats.cylinder(root, 0.006, 0.09, Vector3(0.02, 0.158, 0.02), Color(0.5, 0.25, 0.1), false).rotation.z = 1.4
	for i in 2:
		var o := Mats.cylinder(root, 0.02, 0.006, Vector3(-0.03 + i * 0.05, 0.157, -0.025 + i * 0.03), Color(1.0, 0.6, 0.1), false)
		o.rotation.x = 0.1
	# concha apoiada na borda
	var ladle := Mats.cylinder(root, 0.005, 0.2, Vector3(-0.06, 0.2, 0.0), Color(0.75, 0.76, 0.8), false)
	ladle.rotation.z = 0.6
	_sign(root, bev, Vector3(0, 0.0, 0.115), detailed)


static func _can(root: Node3D, bev: BeverageData, detailed: bool) -> void:
	var prof := _profile([[0.0, 0.0], [0.034, 0.0], [0.04, 0.008], [0.04, 0.14], [0.034, 0.152], [0.032, 0.156]])
	_mesh(root, lathe(prof, 16), Vector3.ZERO, Mats.toon(bev.bottle_color, detailed, 0.3))
	Mats.cylinder(root, 0.032, 0.004, Vector3(0, 0.157, 0), Color(0.82, 0.82, 0.85), false)
	Mats.box(root, Vector3(0.012, 0.002, 0.022), Vector3(0, 0.16, 0.008), Color(0.7, 0.7, 0.75), false)
	# faixa branca ondulada estilo refri
	Mats.cylinder(root, 0.0405, 0.018, Vector3(0, 0.11, 0), UiTheme.PAPER, false)
	_label(root, bev, 0.041, 0.065, 0.06, detailed, false)
	if detailed:
		Mats.torus(root, 0.006, 0.01, Vector3(0, 0.161, 0.018), Color(0.75, 0.75, 0.8))
		_droplets(root, 0.041, 0.02, 0.13)
		_shine(root, 0.0405, 0.015, 0.14, detailed)


static func _plate(root: Node3D, bev: BeverageData, detailed: bool) -> void:
	Mats.cylinder(root, 0.09, 0.012, Vector3(0, 0.006, 0), Color(0.97, 0.97, 0.95), detailed, 0.1)
	Mats.cylinder(root, 0.07, 0.004, Vector3(0, 0.013, 0), Color(0.85, 0.88, 0.95), false)
	# guardanapo
	Mats.box(root, Vector3(0.08, 0.003, 0.08), Vector3(0.0, 0.016, 0.0), Color.WHITE, false).rotation.y = 0.4
	build_snack(root, bev, Vector3(0, 0.018, 0))
	if detailed:
		_sign(root, bev, Vector3(0, 0.0, 0.1), detailed, 0.7)


## Só o salgado (sem prato) — usado também na estufa e na mão do freguês.
static func build_snack(parent: Node3D, bev: BeverageData, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	if bev.symbol == &"coxinha":
		# gota gorducha com bico torto, empanado com farelo e base achatada
		var dough := bev.color
		var prof := _profile([[0.0, 0.0], [0.036, 0.0], [0.047, 0.012], [0.048, 0.03], [0.04, 0.055],
			[0.026, 0.08], [0.013, 0.1], [0.006, 0.112], [0.0, 0.116]])
		var body := _mesh(n, lathe(prof, 16), Vector3.ZERO, Mats.toon(dough, true, 0.9))
		body.rotation.z = 0.08
		var crumbs := Node3D.new()
		n.add_child(crumbs)
		for i in 16:
			var ang := i * 2.4
			var y := 0.008 + (i % 6) * 0.015
			var r := _radius_on(prof, y)
			Mats.sphere(crumbs, 0.0055, Vector3(cos(ang) * r, y, sin(ang) * r), dough.darkened(0.3 if i % 2 == 0 else 0.15), false)
		Mats.merge_children(crumbs)
		# pontinha de recheio aparecendo
		Mats.sphere(n, 0.012, Vector3(0.02, 0.045, -0.034), Color(0.98, 0.9, 0.6), false, Vector3(1, 1, 0.4))
	else:
		# pastel: travesseirinho estufado, borda fininha com marca de garfo e bolhas de fritura
		var body := Mats.sphere(n, 0.06, Vector3(0, 0.017, 0), bev.color, true, Vector3(1.05, 0.28, 0.65))
		body.name = "Pastel"
		Mats.box(n, Vector3(0.135, 0.006, 0.09), Vector3(0, 0.006, 0), bev.color.darkened(0.08), false)
		var marks := Node3D.new()
		n.add_child(marks)
		for i in 9:
			var x := -0.06 + i * 0.015
			for z: float in [-0.042, 0.042]:
				Mats.box(marks, Vector3(0.004, 0.008, 0.01), Vector3(x, 0.008, z), bev.color.darkened(0.3), false)
		for i in 5:
			var ang := i * 1.7
			Mats.sphere(marks, 0.007, Vector3(cos(ang) * 0.035, 0.03, sin(ang) * 0.018), bev.color.lightened(0.15), false, Vector3(1, 0.5, 1))
		Mats.merge_children(marks)
	return n


## Reflexo de vidro: faixa clara vertical no lado esquerdo da garrafa.
static func _shine(root: Node3D, radius: float, y0: float, y1: float, detailed: bool) -> void:
	if not detailed:
		return
	var a := -0.75
	var p0 := Vector3(sin(a) * (radius + 0.001), y0, cos(a) * (radius + 0.001))
	var p1 := Vector3(sin(a) * (radius + 0.001), y1, cos(a) * (radius + 0.001))
	var s := Mats.limb(root, p0, p1, 0.005, Color.WHITE)
	s.material_override = Mats.unshaded(Color(1, 1, 1, 0.5), true)
	s.scale = Vector3(1.0, 1.0, 0.35)
	s.set_meta("no_highlight", true)
	var dot := Mats.sphere(root, 0.005, p1 + Vector3(0, 0.018, 0), Color.WHITE, false)
	dot.material_override = s.material_override
	dot.set_meta("no_highlight", true)


## Gotinhas de condensação (bebida gelada), numa malha só.
static func _droplets(root: Node3D, radius: float, y0: float, y1: float) -> void:
	var n := Node3D.new()
	n.name = "Droplets"
	root.add_child(n)
	for i in 9:
		var a := -1.3 + i * 0.6 + sin(i * 3.1) * 0.15
		var y := lerpf(y0, y1, fmod(i * 0.618, 1.0))
		var r := 0.0025 + fmod(i * 0.37, 1.0) * 0.002
		Mats.sphere(n, r, Vector3(sin(a) * (radius + r * 0.4), y, cos(a) * (radius + r * 0.4)), Color.WHITE, false, Vector3(1.0, 1.3, 1.0))
	Mats.merge_children(n)
	for c in n.get_children():
		(c as MeshInstance3D).material_override = Mats.glass(Color(0.8, 0.92, 1.0), 0.4)
		c.set_meta("no_highlight", true)


static func _radius_on(prof: PackedVector2Array, y: float) -> float:
	for i in range(1, prof.size()):
		if prof[i].y >= y:
			return lerpf(prof[i - 1].x, prof[i].x, (y - prof[i - 1].y) / maxf(prof[i].y - prof[i - 1].y, 0.0001))
	return prof[prof.size() - 1].x


# ------------------------------------------------------------------ rótulos

## Rótulo cilíndrico: faixa de papel com listras na cor da bebida + medalhão (símbolo) + letra.
static func _label(root: Node3D, bev: BeverageData, radius: float, y: float, h: float, detailed: bool, band := true) -> void:
	var accent := _accent(bev)
	if band:
		var paper := Mats.cylinder(root, radius, h, Vector3(0, y, 0), UiTheme.PAPER, false)
		paper.set_meta("label", true)
		Mats.cylinder(root, radius + 0.0008, h * 0.12, Vector3(0, y + h * 0.44, 0), accent, false)
		Mats.cylinder(root, radius + 0.0008, h * 0.12, Vector3(0, y - h * 0.44, 0), accent, false)
	# medalhão e letra "abraçam" o cilindro (giram em volta do eixo para colar na curva)
	var badge_r := minf(h * 0.36, radius * 0.46)
	var a_badge := -0.42
	var a_letter := 0.5
	var b := _badge(root, bev, Vector3(sin(a_badge) * (radius + 0.002), y, cos(a_badge) * (radius + 0.002)), badge_r, detailed)
	b.rotation.y = a_badge
	if detailed:
		var l := _letter(root, bev, Vector3(sin(a_letter) * (radius + 0.003), y, cos(a_letter) * (radius + 0.003)), badge_r)
		l.rotation.y = a_letter


## Rótulo chapado (garrafa quadrada).
static func _flat_label(root: Node3D, bev: BeverageData, pos: Vector3, size: Vector2, detailed: bool) -> void:
	var paper := BoxMesh.new()
	paper.size = Vector3(size.x, size.y, 0.002)
	_mesh(root, paper, pos, Mats.toon(UiTheme.PAPER, false))
	var stripe := BoxMesh.new()
	stripe.size = Vector3(size.x, size.y * 0.12, 0.003)
	_mesh(root, stripe, pos + Vector3(0, size.y * 0.42, 0), Mats.toon(_accent(bev), false))
	var badge_r := size.y * 0.3
	_badge(root, bev, pos + Vector3(-size.x * 0.2, -size.y * 0.03, 0.002), badge_r, detailed)
	if detailed:
		_letter(root, bev, pos + Vector3(size.x * 0.25, -size.y * 0.03, 0.003), badge_r)


## Plaquinha de pé (panela, pratos): fundo de papel com medalhão e letra.
static func _sign(root: Node3D, bev: BeverageData, pos: Vector3, detailed: bool, s := 1.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.scale = Vector3.ONE * s
	root.add_child(n)
	Mats.box(n, Vector3(0.11, 0.065, 0.006), Vector3(0, 0.04, 0), UiTheme.PAPER, detailed).rotation.x = -0.25
	Mats.box(n, Vector3(0.11, 0.008, 0.007), Vector3(0, 0.07, -0.007), _accent(bev), false).rotation.x = -0.25
	_badge(n, bev, Vector3(-0.025, 0.04, 0.009), 0.024, detailed).rotation.x = -0.25
	if detailed:
		_letter(n, bev, Vector3(0.028, 0.04, 0.01), 0.024).rotation.x = -0.25


static func _accent(bev: BeverageData) -> Color:
	return bev.color if bev.color.get_luminance() < 0.8 else bev.color.darkened(0.35)


## Medalhão: disco na cor da bebida com o símbolo em destaque e borda escura.
static func _badge(root: Node3D, bev: BeverageData, pos: Vector3, r: float, detailed: bool) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	root.add_child(n)
	var bg := bev.color
	var fg := UiTheme.PAPER
	var ring := MeshInstance3D.new()
	ring.mesh = _disc(r * 1.12)
	ring.material_override = Mats.unshaded(UiTheme.INK)
	n.add_child(ring)
	var disc := MeshInstance3D.new()
	disc.mesh = _disc(r)
	disc.material_override = Mats.unshaded(bg)
	disc.position.z = 0.0006
	n.add_child(disc)
	var scale := r * 0.72
	if detailed:
		var edge := MeshInstance3D.new()
		edge.mesh = Mats.flat_polygon_mesh(SymbolShapes.outline_polygon(bev.symbol), scale)
		edge.material_override = Mats.unshaded(UiTheme.INK)
		edge.position.z = 0.0012
		n.add_child(edge)
	var sym := MeshInstance3D.new()
	sym.mesh = Mats.flat_polygon_mesh(SymbolShapes.polygon(bev.symbol), scale)
	sym.material_override = Mats.unshaded(fg)
	sym.position.z = 0.0018
	n.add_child(sym)
	return n


static func _letter(root: Node3D, bev: BeverageData, pos: Vector3, r: float) -> Label3D:
	var l := Mats.label3d(root, bev.letter, pos, 64, _accent(bev), 14)
	l.pixel_size = r * 2.3 / 64.0
	l.outline_modulate = UiTheme.INK
	return l


static func _disc(r: float) -> Mesh:
	var key := "disc|%s" % r
	if _lathe_cache.has(key):
		return _lathe_cache[key]
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 0.0005
	c.radial_segments = 20
	c.rings = 1
	# deitado para olhar +Z
	var st := SurfaceTool.new()
	st.append_from(c, 0, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO))
	var m := st.commit()
	_lathe_cache[key] = m
	return m


# ------------------------------------------------------------------ copo

## Copo americano. fill_bev = null → vazio.
static func build_glass(fill_bev: BeverageData = null) -> Node3D:
	var root := Node3D.new()
	root.name = "Copo"
	# perfil do copo americano: base grossa, cintura, gomos e boca levemente aberta
	var prof := _profile([[0.0, 0.0], [0.031, 0.0], [0.033, 0.012], [0.03, 0.016], [0.033, 0.06],
		[0.037, 0.095], [0.04, 0.11], [0.038, 0.112], [0.035, 0.098], [0.03, 0.016], [0.0, 0.016]])
	var cup := _mesh(root, lathe(prof, 12), Vector3.ZERO, Mats.glass(Color(0.88, 0.96, 1.0), 0.2))
	cup.name = "Cup"
	# frisos dos gomos (o "americano" tem a cintura facetada)
	var rim := Mats.torus(root, 0.0385, 0.0405, Vector3(0, 0.108, 0), Color.WHITE)
	rim.material_override = Mats.glass(Color(0.95, 1.0, 1.0), 0.45)
	rim.set_meta("no_highlight", true)
	var liquid := _mesh(root, lathe(_profile([[0.0, 0.0], [0.029, 0.0], [0.035, 0.085], [0.0, 0.085]]), 12), Vector3(0, 0.016, 0), Mats.toon(Color.WHITE, false, 0.2))
	liquid.name = "Liquid"
	liquid.set_meta("no_highlight", true)
	# superfície do líquido (um tom mais claro); escala junto com o nível
	var surface := Mats.cylinder(liquid, 0.0345, 0.002, Vector3(0, 0.0845, 0), Color.WHITE, false)
	surface.name = "Surface"
	surface.set_meta("no_highlight", true)
	set_glass_fill(root, fill_bev, 1.0 if fill_bev else 0.0)
	return root


static func set_glass_fill(glass: Node3D, bev: BeverageData, amount: float) -> void:
	var liquid := glass.get_node_or_null("Liquid") as MeshInstance3D
	if liquid == null:
		return
	for c in glass.get_children():
		if c.has_meta("garnish"):
			c.queue_free()
	if bev == null or amount <= 0.01:
		liquid.visible = false
		return
	liquid.visible = true
	var clear := bev.color.get_luminance() > 0.85 or bev.id == &"agua"
	liquid.material_override = Mats.glass(bev.color.lerp(Color(0.7, 0.9, 1.0), 0.3), 0.32) if clear else Mats.toon(bev.color, false, 0.15, 0.25)
	var surface := liquid.get_node_or_null("Surface") as MeshInstance3D
	if surface:
		surface.material_override = Mats.glass(bev.color.lerp(Color.WHITE, 0.4), 0.5) if clear else Mats.toon(bev.color.lightened(0.28), false, 0.1, 0.35)
	liquid.scale = Vector3(1, amount, 1)
	if amount < 0.99:
		return
	var top := 0.016 + 0.085
	match bev.id:
		&"cerveja":
			# colarinho cremoso transbordando um pouco + bolhinhas subindo
			_garnish(Mats.cylinder(glass, 0.0375, 0.018, Vector3(0, top + 0.005, 0), Color(1, 0.98, 0.9), false, 0.04))
			for i in 4:
				var ang := i * 1.6
				_garnish(Mats.sphere(glass, 0.012, Vector3(cos(ang) * 0.022, top + 0.016, sin(ang) * 0.022), Color(1, 0.98, 0.92), false, Vector3(1, 0.6, 1)))
			for i in 5:
				_garnish(Mats.sphere(glass, 0.0025, Vector3(-0.015 + i * 0.008, 0.035 + (i % 3) * 0.02, 0.026), Color(1, 0.95, 0.7), false))
		&"caipirinha":
			_garnish(_lime_wheel(glass, Vector3(0.012, top - 0.004, 0.008), 0.017, Vector3(0.4, 0.3, 0.2)))
			_garnish(_lime_wheel(glass, Vector3(-0.012, top - 0.01, -0.006), 0.016, Vector3(-0.5, 1.2, 0.3)))
			for i in 3:
				_garnish(_ice(glass, Vector3(-0.012 + i * 0.012, top - 0.004, 0.012 - i * 0.01), 0.016, i))
			var stir := Mats.cylinder(glass, 0.0035, 0.13, Vector3(0.012, 0.11, -0.005), Color(0.95, 0.85, 0.2), false)
			stir.rotation.z = -0.22
			_garnish(stir)
		&"batida":
			var straw := Mats.cylinder(glass, 0.004, 0.14, Vector3(0.015, 0.11, 0), Color(1, 0.3, 0.5), false)
			straw.rotation.z = -0.25
			_garnish(straw)
			var berry := Node3D.new()
			glass.add_child(berry)
			_strawberry(berry, Vector3(-0.034, 0.112, 0.0), 0.012)
			_garnish(berry)
			_garnish(Mats.sphere(glass, 0.02, Vector3(-0.004, top + 0.004, 0.004), bev.color.lightened(0.45), false, Vector3(1.3, 0.45, 1.3)))
		&"whisky", &"gin", &"refrigerante":
			for i in 2:
				_garnish(_ice(glass, Vector3(-0.01 + i * 0.018, top - 0.005, 0.005 - i * 0.01), 0.022, i + 1))
			if bev.id == &"gin":
				var cuc := Node3D.new()
				glass.add_child(cuc)
				Mats.cylinder(cuc, 0.02, 0.004, Vector3.ZERO, Color(0.25, 0.55, 0.2), false)
				Mats.cylinder(cuc, 0.017, 0.0045, Vector3.ZERO, Color(0.75, 0.92, 0.6), false)
				cuc.position = Vector3(0.018, top - 0.002, -0.012)
				cuc.rotation.x = 1.3
				_garnish(cuc)
			elif bev.id == &"refrigerante":
				for i in 6:
					_garnish(Mats.sphere(glass, 0.003, Vector3(-0.015 + i * 0.006, 0.03 + (i % 3) * 0.022, 0.027), Color(1, 1, 1), false))
				var straw := Mats.cylinder(glass, 0.004, 0.14, Vector3(-0.012, 0.11, 0.0), Color(0.95, 0.95, 0.95), false)
				straw.rotation.z = 0.22
				_garnish(straw)
		&"tequila":
			# borda com sal + gomo de limão espetado
			var salt := Mats.torus(glass, 0.036, 0.043, Vector3(0, 0.11, 0), Color(1, 1, 1))
			_garnish(salt)
			for i in 10:
				var ang := i * TAU / 10.0
				_garnish(Mats.box(glass, Vector3(0.004, 0.004, 0.004), Vector3(cos(ang) * 0.043, 0.107, sin(ang) * 0.043), Color(1, 1, 1), false))
			var wedge := _lime_wheel(glass, Vector3(0.04, 0.108, 0), 0.02, Vector3(0, 0, PI / 2.0))
			wedge.scale = Vector3(1, 1, 0.5)
			_garnish(wedge)
		&"quentao":
			var stick := Mats.cylinder(glass, 0.005, 0.1, Vector3(0.012, 0.11, 0), Color(0.5, 0.25, 0.1), false)
			stick.rotation.z = -0.3
			_garnish(stick)
			var orange := Mats.cylinder(glass, 0.016, 0.004, Vector3(-0.01, top + 0.001, 0.008), Color(1.0, 0.6, 0.1), false)
			_garnish(orange)
			for i in 3:
				_garnish(Mats.sphere(glass, 0.004, Vector3(0.008 - i * 0.008, top + 0.002, -0.01), Color(0.35, 0.18, 0.08), false))
		&"agua":
			_garnish(_ice(glass, Vector3(0.006, top - 0.006, 0.0), 0.02, 2))
			_garnish(_lime_wheel(glass, Vector3(-0.01, top - 0.002, 0.008), 0.014, Vector3(0.2, 0.0, 0.1)))


static func _garnish(n: Node3D) -> void:
	n.set_meta("garnish", true)
	n.set_meta("no_highlight", true)


# ------------------------------------------------------------------ geometria

## Malha de revolução a partir de um perfil (x = raio, y = altura), com normais suaves.
static func lathe(profile: PackedVector2Array, segments := 16, angle_offset := 0.0) -> ArrayMesh:
	var key := "%s|%d|%s" % [profile, segments, angle_offset]
	if _lathe_cache.has(key):
		return _lathe_cache[key]
	var n := profile.size()
	var normals2: PackedVector2Array = []
	for i in n:
		var a := profile[maxi(i - 1, 0)]
		var b := profile[mini(i + 1, n - 1)]
		var t := (b - a).normalized()
		normals2.append(Vector2(t.y, -t.x))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		for j in segments + 1:
			var ang := angle_offset + j * TAU / segments
			var c := cos(ang)
			var s := sin(ang)
			var p := profile[i]
			st.set_normal(Vector3(normals2[i].x * c, normals2[i].y, normals2[i].x * s).normalized())
			st.set_uv(Vector2(float(j) / segments, p.y))
			st.add_vertex(Vector3(p.x * c, p.y, p.x * s))
	var row := segments + 1
	for i in n - 1:
		for j in segments:
			var a := i * row + j
			var b := a + row
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(b + 1)
			st.add_index(b)
	var mesh := st.commit()
	_lathe_cache[key] = mesh
	return mesh


static func _profile(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Array in pts:
		out.append(Vector2(p[0], p[1]))
	return out


static func _scaled(prof: PackedVector2Array, sx: float, sy: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in prof:
		out.append(Vector2(p.x * sx, p.y * sy))
	return out


static func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
