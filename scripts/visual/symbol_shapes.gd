class_name SymbolShapes
extends RefCounted
## Polígonos dos símbolos das bebidas em coordenadas unitárias (-1..1, y para baixo).
## Usados tanto no HUD (draw_colored_polygon) quanto em 3D (Mats.flat_polygon_mesh),
## para que o símbolo seja idêntico em todo lugar.

static var _cache: Dictionary = {}


static func polygon(symbol: StringName) -> PackedVector2Array:
	if _cache.has(symbol):
		return _cache[symbol]
	var pts := PackedVector2Array()
	match symbol:
		&"star":
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				var r := 1.0 if i % 2 == 0 else 0.45
				pts.append(Vector2(cos(a), sin(a)) * r)
		&"diamond":
			pts = PackedVector2Array([Vector2(0, -1), Vector2(0.68, 0), Vector2(0, 1), Vector2(-0.68, 0)])
		&"circle":
			for i in 28:
				var a := i * TAU / 28.0
				pts.append(Vector2(cos(a), sin(a)) * 0.9)
		&"lemon":
			# limão: elipse com pontinhas nas laterais
			for i in 32:
				var a := i * TAU / 32.0
				var tip := pow(absf(cos(a)), 10.0) * 0.22
				pts.append(Vector2(cos(a) * (0.82 + tip), sin(a) * 0.62))
		&"heart":
			for i in 40:
				var t := i * TAU / 40.0
				var x := 16.0 * pow(sin(t), 3.0)
				var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
				pts.append(Vector2(x, -y - 2.5) / 17.0)
		&"bolt":
			pts = PackedVector2Array([Vector2(0.25, -1), Vector2(-0.55, 0.12), Vector2(-0.02, 0.12),
				Vector2(-0.3, 1), Vector2(0.6, -0.2), Vector2(0.05, -0.2), Vector2(0.4, -1)])
		_:
			pts = PackedVector2Array([Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(0.8, 0.8), Vector2(-0.8, 0.8)])
	_cache[symbol] = pts
	return pts


## Desenha o símbolo em um CanvasItem (Control._draw).
static func draw(ci: CanvasItem, symbol: StringName, center: Vector2, radius: float, color: Color, outline := Color(0.12, 0.07, 0.05), outline_w := 3.0) -> void:
	var src := polygon(symbol)
	var pts := PackedVector2Array()
	for p in src:
		pts.append(center + p * radius)
	ci.draw_colored_polygon(pts, color)
	if outline_w > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, outline, outline_w, true)
	if symbol == &"lemon":
		# gominhos do limão
		for i in 6:
			var a := i * TAU / 6.0
			ci.draw_line(center, center + Vector2(cos(a) * 0.62, sin(a) * 0.45) * radius, outline.lerp(color, 0.4), 1.5, true)
