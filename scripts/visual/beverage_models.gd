class_name BeverageModels
extends RefCounted
## Modelos 3D estilizados das bebidas e do copo americano, montados com primitivas.
## Todos olham para +Z (o rótulo fica na frente).


static func build_container(bev: BeverageData) -> Node3D:
	var root := Node3D.new()
	root.name = "Bev_%s" % bev.id
	match bev.vessel:
		BeverageData.Vessel.LONGNECK:
			var glass := Mats.glass(bev.bottle_color, 0.85)
			_mesh(root, _cyl(0.045, 0.045, 0.2), Vector3(0, 0.1, 0), glass)
			_mesh(root, _cyl(0.045, 0.018, 0.06), Vector3(0, 0.23, 0), glass)
			_mesh(root, _cyl(0.018, 0.018, 0.07), Vector3(0, 0.29, 0), glass)
			Mats.cylinder(root, 0.02, 0.012, Vector3(0, 0.33, 0), Color(0.85, 0.75, 0.2), false)
			_label_band(root, bev, 0.047, 0.09, 0.1)
		BeverageData.Vessel.BOTTLE:
			var glass := Mats.glass(bev.bottle_color, 0.7)
			_mesh(root, _cyl(0.055, 0.055, 0.24), Vector3(0, 0.12, 0), glass)
			_mesh(root, _cyl(0.055, 0.022, 0.07), Vector3(0, 0.275, 0), glass)
			_mesh(root, _cyl(0.022, 0.022, 0.08), Vector3(0, 0.35, 0), glass)
			# líquido visível
			_mesh(root, _cyl(0.048, 0.048, 0.2), Vector3(0, 0.105, 0), Mats.toon(bev.color, false, 0.2))
			Mats.cylinder(root, 0.025, 0.03, Vector3(0, 0.4, 0), Color(0.75, 0.5, 0.3), false)
			_label_band(root, bev, 0.057, 0.11, 0.12)
		BeverageData.Vessel.JAR:
			_mesh(root, _cyl(0.085, 0.075, 0.24), Vector3(0, 0.12, 0), Mats.glass(Color(0.9, 1, 1), 0.3))
			_mesh(root, _cyl(0.078, 0.07, 0.19), Vector3(0, 0.1, 0), Mats.toon(bev.color, false, 0.3))
			Mats.cylinder(root, 0.088, 0.025, Vector3(0, 0.25, 0), Color(0.85, 0.85, 0.82), false)
			if bev.symbol == &"lemon":
				for i in 4:
					var a := i * TAU / 4.0
					Mats.sphere(root, 0.028, Vector3(cos(a) * 0.04, 0.17, sin(a) * 0.04), Color(0.35, 0.75, 0.15), false)
			else:
				for i in 3:
					var a := i * TAU / 3.0
					Mats.sphere(root, 0.022, Vector3(cos(a) * 0.04, 0.18, sin(a) * 0.04), Color(0.85, 0.1, 0.25), false)
			_label_band(root, bev, 0.087, 0.12, 0.07)
		BeverageData.Vessel.CAN:
			Mats.cylinder(root, 0.04, 0.15, Vector3(0, 0.075, 0), bev.bottle_color, false)
			Mats.cylinder(root, 0.036, 0.01, Vector3(0, 0.155, 0), Color(0.8, 0.8, 0.82), false)
			_label_band(root, bev, 0.042, 0.075, 0.07, false)
	return root


static func _label_band(root: Node3D, bev: BeverageData, radius: float, y: float, h: float, band := true) -> void:
	if band:
		var m := Mats.cylinder(root, radius, h, Vector3(0, y, 0), UiTheme.PAPER, false)
		m.set_meta("label", true)
	var letter := Mats.label3d(root, bev.letter, Vector3(radius * 0.38, y + 0.005, radius + 0.004), 34, bev.color.darkened(0.15) if bev.color.get_luminance() > 0.8 else bev.color, 8)
	letter.pixel_size = 0.0016
	var sym := MeshInstance3D.new()
	var sym_color := bev.color if bev.color.get_luminance() < 0.85 else Color(0.45, 0.65, 0.9)
	sym.mesh = Mats.flat_polygon_mesh(SymbolShapes.polygon(bev.symbol), radius * 0.42)
	sym.material_override = Mats.unshaded(sym_color)
	sym.position = Vector3(-radius * 0.4, y, radius + 0.004)
	root.add_child(sym)


## Copo americano. fill_bev = null → vazio.
static func build_glass(fill_bev: BeverageData = null) -> Node3D:
	var root := Node3D.new()
	root.name = "Copo"
	var cup := _mesh(root, _cyl(0.04, 0.032, 0.11, 10), Vector3(0, 0.055, 0), Mats.glass(Color(0.85, 0.95, 1.0), 0.3))
	cup.name = "Cup"
	var base := _mesh(root, _cyl(0.033, 0.033, 0.012, 10), Vector3(0, 0.006, 0), Mats.glass(Color(0.85, 0.95, 1.0), 0.55))
	base.name = "Base"
	var liquid := _mesh(root, _cyl(0.036, 0.029, 0.085, 10), Vector3(0, 0.05, 0), Mats.toon(Color.WHITE, false, 0.2))
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
	liquid.material_override = Mats.toon(bev.color, false, 0.15) if bev.id != &"pinga" else Mats.glass(Color(0.9, 0.97, 1.0), 0.55)
	liquid.scale = Vector3(1, amount, 1)
	liquid.position.y = 0.008 + 0.0425 * amount
	if amount >= 0.99:
		if bev.id == &"cerveja":
			var foam := Mats.cylinder(glass, 0.039, 0.018, Vector3(0, 0.1, 0), Color(1, 0.98, 0.9), false)
			foam.set_meta("garnish", true)
		elif bev.id == &"caipirinha":
			var lime := Mats.sphere(glass, 0.022, Vector3(0.018, 0.09, 0.01), Color(0.4, 0.8, 0.15), false, Vector3(1, 0.6, 1))
			lime.set_meta("garnish", true)
		elif bev.id == &"batida":
			var straw := Mats.cylinder(glass, 0.004, 0.14, Vector3(0.015, 0.11, 0), Color(1, 0.3, 0.5), false)
			straw.rotation.z = -0.25
			straw.set_meta("garnish", true)


static func _cyl(bottom: float, top: float, h: float, seg := 14) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = bottom
	c.top_radius = top
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
