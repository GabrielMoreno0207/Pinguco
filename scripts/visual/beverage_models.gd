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
	var cap := Mats.cylinder(root, 0.023, 0.014, Vector3(0, 0.335, 0), Color(0.88, 0.72, 0.2), false, 0.021)
	cap.set_meta("cap", true)
	# rótulo do gargalo + rótulo principal
	Mats.cylinder(root, 0.024, 0.03, Vector3(0, 0.27, 0), bev.color.darkened(0.15), false, 0.021)
	_label(root, bev, 0.048, 0.095, 0.1, detailed)


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


static func _wine_bottle(root: Node3D, bev: BeverageData, detailed: bool) -> void:
	var prof := _profile([[0.0, 0.0], [0.046, 0.0], [0.052, 0.012], [0.052, 0.22], [0.046, 0.25],
		[0.026, 0.27], [0.019, 0.29], [0.018, 0.38], [0.021, 0.385]])
	_mesh(root, lathe(prof, 16), Vector3.ZERO, Mats.glass(bev.bottle_color, 0.92, detailed))
	# cápsula de alumínio no gargalo
	Mats.cylinder(root, 0.021, 0.07, Vector3(0, 0.355, 0), Color(0.6, 0.06, 0.12), false, 0.02)
	Mats.cylinder(root, 0.022, 0.012, Vector3(0, 0.335, 0), Color(0.9, 0.75, 0.3), false)
	_label(root, bev, 0.054, 0.11, 0.11, detailed)


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


static func _jar(root: Node3D, bev: BeverageData, detailed: bool) -> void:
	# jarra de vidro com bico e alça
	var prof := _profile([[0.0, 0.0], [0.07, 0.0], [0.078, 0.01], [0.084, 0.2], [0.09, 0.235], [0.088, 0.24]])
	_mesh(root, lathe(prof, 18), Vector3.ZERO, Mats.glass(Color(0.9, 1, 1), 0.28, detailed))
	_mesh(root, lathe(_profile([[0.0, 0.0], [0.072, 0.0], [0.078, 0.17], [0.0, 0.17]]), 14), Vector3(0, 0.01, 0),
		Mats.toon(bev.color, false, 0.3))
	var handle := Mats.torus(root, 0.045, 0.06, Vector3(-0.09, 0.13, 0), Color(0.9, 1, 1))
	handle.material_override = Mats.glass(Color(0.9, 1, 1), 0.5)
	handle.rotation_degrees.x = 90
	handle.scale = Vector3(1.0, 1.0, 1.4)
	if bev.symbol == &"lemon":
		for i in 5:
			var a := i * TAU / 5.0
			var lime := Mats.sphere(root, 0.026, Vector3(cos(a) * 0.045, 0.165 + (i % 2) * 0.012, sin(a) * 0.045), Color(0.35, 0.75, 0.15), false, Vector3(1, 0.6, 1))
			lime.rotation.z = a
		# gelo
		for i in 3:
			Mats.box(root, Vector3(0.03, 0.03, 0.03), Vector3(-0.02 + i * 0.025, 0.18, -0.03 + i * 0.02), Color(0.88, 0.97, 1.0), false).rotation = Vector3(i, i * 0.7, 0)
	else:
		for i in 3:
			var a := i * TAU / 3.0
			Mats.sphere(root, 0.022, Vector3(cos(a) * 0.04, 0.185, sin(a) * 0.04), Color(0.85, 0.1, 0.25), false)
		Mats.cylinder(root, 0.005, 0.2, Vector3(0.03, 0.22, 0.0), Color(1, 0.3, 0.5), false).rotation.z = -0.3
	_label(root, bev, 0.086, 0.09, 0.07, detailed)


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
	_sign(root, bev, Vector3(0, 0.0, 0.115), detailed)


static func _can(root: Node3D, bev: BeverageData, detailed: bool) -> void:
	var prof := _profile([[0.0, 0.0], [0.034, 0.0], [0.04, 0.008], [0.04, 0.14], [0.034, 0.152], [0.032, 0.156]])
	_mesh(root, lathe(prof, 16), Vector3.ZERO, Mats.toon(bev.bottle_color, detailed, 0.3))
	Mats.cylinder(root, 0.032, 0.004, Vector3(0, 0.157, 0), Color(0.82, 0.82, 0.85), false)
	Mats.box(root, Vector3(0.012, 0.002, 0.022), Vector3(0, 0.16, 0.008), Color(0.7, 0.7, 0.75), false)
	# faixa branca ondulada estilo refri
	Mats.cylinder(root, 0.0405, 0.018, Vector3(0, 0.11, 0), UiTheme.PAPER, false)
	_label(root, bev, 0.041, 0.065, 0.06, detailed, false)


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
		var dough := bev.color
		var prof := _profile([[0.0, 0.0], [0.035, 0.0], [0.045, 0.015], [0.044, 0.04], [0.032, 0.07],
			[0.016, 0.095], [0.006, 0.11], [0.0, 0.113]])
		_mesh(n, lathe(prof, 14), Vector3.ZERO, Mats.toon(dough, true, 0.9))
		# farelo de empanado
		for i in 7:
			var a := i * 2.3
			var y := 0.015 + (i % 4) * 0.018
			var r := 0.044 - y * 0.25
			Mats.sphere(n, 0.006, Vector3(cos(a) * r, y, sin(a) * r), dough.darkened(0.25), false)
	else:
		# pastel: travesseirinho com borda de garfo
		var body := Mats.box(n, Vector3(0.12, 0.025, 0.075), Vector3(0, 0.014, 0), bev.color)
		body.scale = Vector3(1, 1, 1)
		Mats.sphere(n, 0.05, Vector3(0, 0.02, 0), bev.color, false, Vector3(1.15, 0.35, 0.7))
		for i in 7:
			var x := -0.05 + i * 0.0166
			Mats.box(n, Vector3(0.006, 0.004, 0.012), Vector3(x, 0.027, 0.032), bev.color.darkened(0.25), false)
	return n


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
	var fg := UiTheme.PAPER if bg.get_luminance() < 0.6 else UiTheme.INK
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
		edge.material_override = Mats.unshaded(UiTheme.INK if fg == UiTheme.PAPER else UiTheme.PAPER)
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
	# perfil do copo americano: base grossa, cintura e boca levemente aberta
	var prof := _profile([[0.0, 0.0], [0.031, 0.0], [0.033, 0.012], [0.03, 0.016], [0.033, 0.06],
		[0.037, 0.095], [0.04, 0.11], [0.038, 0.112], [0.035, 0.098], [0.03, 0.016], [0.0, 0.016]])
	var cup := _mesh(root, lathe(prof, 12), Vector3.ZERO, Mats.glass(Color(0.85, 0.95, 1.0), 0.32))
	cup.name = "Cup"
	var liquid := _mesh(root, lathe(_profile([[0.0, 0.0], [0.029, 0.0], [0.035, 0.085], [0.0, 0.085]]), 12), Vector3(0, 0.016, 0), Mats.toon(Color.WHITE, false, 0.2))
	liquid.name = "Liquid"
	liquid.set_meta("no_highlight", true)
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
	liquid.material_override = Mats.glass(bev.color.lerp(Color.WHITE, 0.3), 0.6) if clear else Mats.toon(bev.color, false, 0.15)
	liquid.scale = Vector3(1, amount, 1)
	if amount < 0.99:
		return
	var top := 0.016 + 0.085
	match bev.id:
		&"cerveja":
			_garnish(Mats.cylinder(glass, 0.0375, 0.016, Vector3(0, top + 0.004, 0), Color(1, 0.98, 0.9), false, 0.039))
		&"caipirinha":
			_garnish(Mats.sphere(glass, 0.02, Vector3(0.015, top - 0.008, 0.01), Color(0.4, 0.8, 0.15), false, Vector3(1, 0.6, 1)))
			_garnish(Mats.box(glass, Vector3(0.02, 0.02, 0.02), Vector3(-0.01, top - 0.005, -0.01), Color(0.9, 0.97, 1.0), false))
		&"batida":
			var straw := Mats.cylinder(glass, 0.004, 0.14, Vector3(0.015, 0.11, 0), Color(1, 0.3, 0.5), false)
			straw.rotation.z = -0.25
			_garnish(straw)
		&"whisky", &"gin":
			for i in 2:
				var ice := Mats.box(glass, Vector3(0.022, 0.022, 0.022), Vector3(-0.01 + i * 0.018, top - 0.006, 0.005 - i * 0.01), Color(0.88, 0.97, 1.0), false)
				ice.rotation = Vector3(0.3 * i, 0.6, 0.2)
				_garnish(ice)
			if bev.id == &"gin":
				var cuc := Mats.cylinder(glass, 0.018, 0.004, Vector3(0.02, top - 0.003, -0.012), Color(0.45, 0.75, 0.3), false)
				cuc.rotation.x = 1.3
				_garnish(cuc)
		&"tequila":
			_garnish(Mats.torus(glass, 0.036, 0.042, Vector3(0, 0.11, 0), Color(1, 1, 1)))
			_garnish(Mats.sphere(glass, 0.02, Vector3(0.035, 0.105, 0), Color(0.45, 0.8, 0.2), false, Vector3(1, 0.5, 0.6)))
		&"quentao":
			var stick := Mats.cylinder(glass, 0.005, 0.1, Vector3(0.012, 0.11, 0), Color(0.5, 0.25, 0.1), false)
			stick.rotation.z = -0.3
			_garnish(stick)
		&"refrigerante":
			for i in 3:
				_garnish(Mats.sphere(glass, 0.004, Vector3(-0.012 + i * 0.012, top - 0.002, 0.01), Color(1, 1, 1), false))


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
