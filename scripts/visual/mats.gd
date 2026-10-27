class_name Mats
extends RefCounted
## Fábrica de materiais cartunescos (toon + contorno por casca invertida) e helpers
## para montar modelos estilizados a partir de primitivas.

static var _cache: Dictionary = {}
## Enquanto true, toon() devolve plástico liso sem contorno (estilo dos fregueses).
static var plastic := false
static var _outline: StandardMaterial3D
static var _highlight: ShaderMaterial

const HIGHLIGHT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec4 rim_color : source_color = vec4(1.0, 0.85, 0.25, 1.0);
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float pulse = 0.55 + 0.45 * sin(TIME * 7.0);
	ALBEDO = rim_color.rgb;
	ALPHA = clamp(rim * 1.4 + 0.12, 0.0, 1.0) * pulse;
}
"""


static func toon(color: Color, outline := true, rough := 0.8, emission := 0.0) -> StandardMaterial3D:
	if plastic:
		return plastic_mat(color, rough, emission)
	var key := "%s|%s|%s|%s" % [color.to_html(), outline, rough, emission]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	if GameManager.low_end:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if outline:
		m.next_pass = outline_mat()
	_cache[key] = m
	return m


## Plástico liso de boneco: sombreado suave, brilho especular e sem contorno.
static func plastic_mat(color: Color, rough := 0.8, emission := 0.0) -> StandardMaterial3D:
	var key := "plastic|%s|%s|%s" % [color.to_html(), rough, emission]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = clampf(rough, 0.35, 0.6)
	m.metallic_specular = 0.35
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	m.rim_enabled = true
	m.rim = 0.12
	m.rim_tint = 0.4
	# sempre por pixel: por vértice o brilho do plástico vira estrelinhas
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_cache[key] = m
	return m


static func glass(color: Color, alpha := 0.35, outline := false) -> StandardMaterial3D:
	var key := "glass|%s|%s|%s" % [color.to_html(), alpha, outline]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic_specular = 1.0
	m.rim_enabled = true
	m.rim = 0.8
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if outline:
		m.next_pass = outline_mat()
	_cache[key] = m
	return m


static func unshaded(color: Color, transparent := false) -> StandardMaterial3D:
	var key := "unshaded|%s|%s" % [color.to_html(), transparent]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cache[key] = m
	return m


static func outline_mat() -> StandardMaterial3D:
	if _outline == null:
		_outline = StandardMaterial3D.new()
		_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline.albedo_color = Color(0.12, 0.07, 0.05)
		_outline.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline.grow = true
		_outline.grow_amount = 0.012
	return _outline


static func highlight() -> ShaderMaterial:
	if _highlight == null:
		var sh := Shader.new()
		sh.code = HIGHLIGHT_SHADER
		_highlight = ShaderMaterial.new()
		_highlight.shader = sh
	return _highlight


# ---------------------------------------------------------------- primitivas

static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, outline := true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, toon(color, outline))


static func sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, outline := true, scale := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	# tesselação proporcional ao tamanho (GPUs fracas agradecem)
	mesh.radial_segments = 6 if radius < 0.03 else (10 if radius < 0.09 else 16)
	mesh.rings = 3 if radius < 0.03 else (5 if radius < 0.09 else 8)
	var mi := _add(parent, mesh, pos, toon(color, outline and radius >= 0.05))
	mi.scale = scale
	return mi


static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, outline := true, top_radius := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 6 if radius < 0.03 else (10 if radius < 0.1 else 16)
	mesh.rings = 1
	return _add(parent, mesh, pos, toon(color, outline and radius >= 0.05))


static func capsule(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, outline := true) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	# peças miúdas (dedos, lábios, cílios) não precisam de tesselação
	mesh.radial_segments = 6 if radius < 0.02 else (8 if radius < 0.05 else 12)
	mesh.rings = 1 if radius < 0.02 else (2 if radius < 0.05 else 4)
	return _add(parent, mesh, pos, toon(color, outline))


static func torus(parent: Node3D, inner: float, outer: float, pos: Vector3, color: Color, outline := false) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 12
	mesh.ring_segments = 6
	return _add(parent, mesh, pos, toon(color, outline))


## Cápsula de `a` até `b` (dedos, alças, tiras, sobrancelhas...).
static func limb(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color, outline := false) -> MeshInstance3D:
	var d := b - a
	var mi := capsule(parent, radius, d.length() + radius * 2.0, (a + b) * 0.5, color, outline)
	mi.basis = orient(d)
	return mi


## Base que aponta o eixo Y local na direção `d`.
static func orient(d: Vector3) -> Basis:
	var n := d.normalized()
	var k := n.dot(Vector3.UP)
	if k > 0.9999:
		return Basis()
	if k < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, n))


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func label3d(parent: Node3D, text: String, pos: Vector3, size := 48, color := Color.WHITE, outline_size := 10) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UiTheme.title_font()
	l.font_size = size
	l.pixel_size = 0.002
	l.modulate = color
	l.outline_size = outline_size
	l.outline_modulate = Color(0.12, 0.07, 0.05)
	l.position = pos
	l.shaded = false
	l.double_sided = false
	parent.add_child(l)
	return l


## Malha plana a partir de um polígono 2D (usada para os símbolos das bebidas em 3D).
static func flat_polygon_mesh(points: PackedVector2Array, scale: float) -> ArrayMesh:
	var idx := Geometry2D.triangulate_polygon(points)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in idx:
		var p := points[i] * scale
		verts.append(Vector3(p.x, -p.y, 0.0))
		normals.append(Vector3(0, 0, 1))
	# triangulate_polygon devolve horário/anti-horário conforme o polígono; garante frente +Z.
	if verts.size() >= 3:
		var n := (verts[1] - verts[0]).cross(verts[2] - verts[0])
		if n.z < 0.0:
			for t in range(0, verts.size(), 3):
				var tmp := verts[t + 1]
				verts[t + 1] = verts[t + 2]
				verts[t + 2] = tmp
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	if verts.size() >= 3:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Liga/desliga o destaque de interação em todas as malhas de um nó.
static func set_highlight(root: Node, on: bool) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		if child.has_meta("no_highlight"):
			continue
		(child as MeshInstance3D).material_overlay = highlight() if on else null


## Junta as malhas filhas diretas de `node` (mesmo material → uma malha só).
## Filhos com meta "dynamic" ficam separados (são animados individualmente).
static func merge_children(node: Node3D) -> void:
	var groups: Dictionary = {}
	for c in node.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.has_meta("dynamic") or mi.mesh == null or mi.material_override == null:
			continue
		if not groups.has(mi.material_override):
			groups[mi.material_override] = []
		groups[mi.material_override].append(mi)
	for mat: Material in groups:
		var list: Array = groups[mat]
		if list.size() < 2:
			continue
		var st := SurfaceTool.new()
		for mi: MeshInstance3D in list:
			for surf in mi.mesh.get_surface_count():
				st.append_from(mi.mesh, surf, mi.transform)
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = mat
		if list[0].has_meta("no_highlight"):
			merged.set_meta("no_highlight", true)
		node.add_child(merged)
		for mi: MeshInstance3D in list:
			node.remove_child(mi)
			mi.queue_free()
