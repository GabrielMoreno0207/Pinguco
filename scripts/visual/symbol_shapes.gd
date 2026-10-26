class_name SymbolShapes
extends RefCounted
## Polígonos dos símbolos das bebidas em coordenadas unitárias (-1..1, y para baixo).
## Usados tanto no HUD (draw_colored_polygon) quanto em 3D (Mats.flat_polygon_mesh),
## para que o símbolo seja idêntico em todo lugar.

static var _cache: Dictionary = {}
static var _outline_cache: Dictionary = {}


static func polygon(symbol: StringName) -> PackedVector2Array:
	if _cache.has(symbol):
		return _cache[symbol]
	var pts := PackedVector2Array()
	match symbol:
		&"star":
			# estrela de 5 pontas com as pontas levemente arredondadas
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				if i % 2 == 0:
					for k in [-1, 0, 1]:
						var aa: float = a + k * 0.07
						pts.append(Vector2(cos(aa), sin(aa)) * (0.97 if k == 0 else 0.9))
				else:
					pts.append(Vector2(cos(a), sin(a)) * 0.47)
		&"diamond":
			# losango lapidado (topo achatado como uma gema)
			pts = PackedVector2Array([Vector2(-0.35, -0.85), Vector2(0.35, -0.85), Vector2(0.85, -0.3),
				Vector2(0, 1), Vector2(-0.85, -0.3)])
		&"circle":
			for i in 36:
				var a := i * TAU / 36.0
				pts.append(Vector2(cos(a), sin(a)) * 0.9)
		&"lemon":
			# limão: elipse com pontinhas nas laterais
			for i in 40:
				var a := i * TAU / 40.0
				var tip := pow(absf(cos(a)), 12.0) * 0.2
				pts.append(Vector2(cos(a) * (0.8 + tip), sin(a) * 0.62))
		&"heart":
			for i in 48:
				var t := i * TAU / 48.0
				var x := 16.0 * pow(sin(t), 3.0)
				var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
				pts.append(Vector2(x, -y - 2.5) / 17.0)
		&"bolt":
			pts = PackedVector2Array([Vector2(0.2, -1), Vector2(-0.6, 0.15), Vector2(-0.05, 0.15),
				Vector2(-0.3, 1), Vector2(0.62, -0.22), Vector2(0.08, -0.22), Vector2(0.45, -1)])
		&"flame":
			# chama: gota com a ponta torcida para o lado
			for i in 44:
				var t := i / 44.0 * TAU
				var r := 0.62
				var x := sin(t) * r
				var y := -cos(t)
				# metade de cima afina e entorta
				if y < 0.0:
					var k := -y
					x = x * (1.0 - k * 0.85) + sin(k * 2.6) * 0.28 * k
					y = y * 1.0
				else:
					y = 0.25 + y * 0.72
					x = sin(t) * 0.68
				pts.append(Vector2(x, y + 0.02))
		&"crown":
			pts = PackedVector2Array([Vector2(-0.85, 0.7), Vector2(-0.95, -0.55), Vector2(-0.45, -0.05),
				Vector2(0, -0.8), Vector2(0.45, -0.05), Vector2(0.95, -0.55), Vector2(0.85, 0.7)])
		&"sun":
			# sol de 12 raios
			for i in 24:
				var a := -PI / 2.0 + i * PI / 12.0
				pts.append(Vector2(cos(a), sin(a)) * (1.0 if i % 2 == 0 else 0.68))
		&"moon":
			# lua crescente: arco do círculo grande fora do pequeno + arco do pequeno dentro do grande
			var big := 0.92
			var small := 0.74
			var off := Vector2(0.42, -0.22)
			var outer := PackedVector2Array()
			var start := off.angle()
			for i in 72:
				var a := start + i * TAU / 72.0
				var p := Vector2(cos(a), sin(a)) * big
				if p.distance_to(off) > small:
					outer.append(p)
			var inner := PackedVector2Array()
			var start2 := (-off).angle() + PI
			for i in 72:
				var a := start2 + i * TAU / 72.0
				var p := off + Vector2(cos(a), sin(a)) * small
				if p.length() < big:
					inner.append(p)
			if inner.size() > 0 and outer.size() > 0 and inner[0].distance_to(outer[outer.size() - 1]) > inner[inner.size() - 1].distance_to(outer[outer.size() - 1]):
				inner.reverse()
			pts = outer
			pts.append_array(inner)
		&"drop":
			for i in 40:
				var t := i / 40.0 * TAU
				var y := -cos(t)
				var x := sin(t)
				if y < 0.0:
					x *= pow(1.0 + y, 1.6) * 0.72 + 0.0
					y *= 1.05
				else:
					x *= 0.72
					y = y * 0.72 + 0.0
				pts.append(Vector2(x, y + 0.22))
		&"leaf":
			# folha pontuda (vesica) levemente curvada, com cabinho
			for i in 20:
				var t := float(i) / 19.0
				var y := lerpf(-0.95, 0.75, t)
				pts.append(Vector2(sin(t * PI) * 0.62 + sin(t * PI) * 0.1, y))
			for i in 20:
				var t := 1.0 - float(i) / 19.0
				var y := lerpf(-0.95, 0.75, t)
				pts.append(Vector2(-sin(t * PI) * 0.62 + sin(t * PI) * 0.1, y))
			pts.insert(20, Vector2(0.05, 0.98))
			pts.insert(20, Vector2(0.12, 0.98))
		&"coxinha":
			# coxinha: gota gorducha com a base achatada
			for i in 40:
				var t := i / 40.0 * TAU
				var y := -cos(t)
				var x := sin(t)
				if y < 0.0:
					x *= pow(1.0 + y, 1.2) * 0.85
					y *= 0.95
				else:
					x *= 0.85
					y = minf(y * 0.8, 0.62)
				pts.append(Vector2(x, y + 0.2))
		&"pastel":
			# pastel retangular com a borda "pinçada" de garfo
			var w := 0.95
			var h := 0.6
			var n := 9
			for i in n:
				var x := lerpf(-w, w, float(i) / (n - 1))
				pts.append(Vector2(x, -h - (0.06 if i % 2 == 0 else 0.0)))
			for i in 5:
				pts.append(Vector2(w + (0.06 if i % 2 == 1 else 0.0), lerpf(-h, h, float(i + 1) / 6.0)))
			for i in n:
				var x := lerpf(w, -w, float(i) / (n - 1))
				pts.append(Vector2(x, h + (0.06 if i % 2 == 0 else 0.0)))
			for i in 5:
				pts.append(Vector2(-w - (0.06 if i % 2 == 1 else 0.0), lerpf(h, -h, float(i + 1) / 6.0)))
		_:
			pts = PackedVector2Array([Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(0.8, 0.8), Vector2(-0.8, 0.8)])
	_cache[symbol] = pts
	return pts


## Contorno "inflado" do símbolo (para a borda escura em 3D).
static func outline_polygon(symbol: StringName, amount := 0.14) -> PackedVector2Array:
	var key := "%s|%s" % [symbol, amount]
	if _outline_cache.has(key):
		return _outline_cache[key]
	var grown := Geometry2D.offset_polygon(polygon(symbol), amount, Geometry2D.JOIN_ROUND)
	var out: PackedVector2Array = grown[0] if grown.size() > 0 else polygon(symbol)
	_outline_cache[key] = out
	return out


## Desenha o símbolo em um CanvasItem (Control._draw), com sombra, contorno e detalhes.
static func draw(ci: CanvasItem, symbol: StringName, center: Vector2, radius: float, color: Color, outline := Color(0.12, 0.07, 0.05), outline_w := 3.0) -> void:
	var src := polygon(symbol)
	var pts := PackedVector2Array()
	for p in src:
		pts.append(center + p * radius)
	if outline_w > 0.0:
		var shadow := PackedVector2Array()
		for p in pts:
			shadow.append(p + Vector2(1.5, 2.0) * maxf(radius / 20.0, 0.6))
		ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.25))
	ci.draw_colored_polygon(pts, color)
	_details(ci, symbol, center, radius, color, outline)
	if outline_w > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, outline, outline_w, true)


## Detalhes internos que deixam cada símbolo mais "desenhado".
static func _details(ci: CanvasItem, symbol: StringName, c: Vector2, r: float, color: Color, outline: Color) -> void:
	var line := outline.lerp(color, 0.45)
	var w := maxf(r * 0.07, 1.0)
	var light := color.lightened(0.45)
	match symbol:
		&"lemon":
			ci.draw_circle(c, r * 0.48, color.lightened(0.35))
			for i in 6:
				var a := i * TAU / 6.0
				ci.draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.46, line, w, true)
		&"star", &"diamond", &"heart", &"drop", &"bolt", &"coxinha":
			# brilho de desenho animado
			var hl := c + Vector2(-0.3, -0.25) * r
			if symbol == &"drop":
				hl = c + Vector2(-0.25, 0.25) * r
			elif symbol == &"coxinha":
				hl = c + Vector2(-0.3, 0.2) * r
			ci.draw_circle(hl, r * 0.13, Color(1, 1, 1, 0.55))
			if symbol == &"diamond":
				ci.draw_line(c + Vector2(-0.85, -0.3) * r, c + Vector2(0.85, -0.3) * r, line, w, true)
				ci.draw_line(c + Vector2(-0.35, -0.85) * r, c + Vector2(-0.2, -0.3) * r, line, w, true)
				ci.draw_line(c + Vector2(0.35, -0.85) * r, c + Vector2(0.2, -0.3) * r, line, w, true)
				ci.draw_line(c + Vector2(-0.2, -0.3) * r, c + Vector2(0, 1) * r, line, w, true)
				ci.draw_line(c + Vector2(0.2, -0.3) * r, c + Vector2(0, 1) * r, line, w, true)
			if symbol == &"coxinha":
				# farelinhos de empanado
				for i in 5:
					var a := i * 1.9
					ci.draw_circle(c + Vector2(cos(a) * 0.32, 0.35 + sin(a) * 0.2) * r, r * 0.05, color.darkened(0.3))
		&"circle":
			ci.draw_arc(c, r * 0.62, -2.6, -1.2, 10, light, w * 1.4, true)
		&"flame":
			var inner := PackedVector2Array()
			for p in polygon(&"flame"):
				inner.append(c + Vector2(p.x * 0.5, p.y * 0.5 + 0.32) * r)
			ci.draw_colored_polygon(inner, Color(1.0, 0.9, 0.35))
		&"crown":
			for x in [-0.95, 0.0, 0.95]:
				var y := -0.55 if absf(x) > 0.5 else -0.8
				ci.draw_circle(c + Vector2(x, y) * r, r * 0.13, Color(1.0, 0.92, 0.5))
			ci.draw_line(c + Vector2(-0.8, 0.42) * r, c + Vector2(0.8, 0.42) * r, line, w, true)
			ci.draw_circle(c + Vector2(0, 0.15) * r, r * 0.12, Color(0.85, 0.15, 0.2))
		&"sun":
			ci.draw_circle(c, r * 0.55, color.lightened(0.25))
			ci.draw_circle(c + Vector2(-0.18, -0.1) * r, r * 0.06, line)
			ci.draw_circle(c + Vector2(0.18, -0.1) * r, r * 0.06, line)
			ci.draw_arc(c + Vector2(0, 0.02) * r, r * 0.25, 0.4, PI - 0.4, 8, line, w, true)
		&"moon":
			ci.draw_circle(c + Vector2(-0.55, 0.1) * r, r * 0.09, color.darkened(0.2))
			ci.draw_circle(c + Vector2(-0.35, 0.5) * r, r * 0.06, color.darkened(0.2))
		&"leaf":
			ci.draw_line(c + Vector2(0.05, 0.95) * r, c + Vector2(0.1, -0.8) * r, line, w, true)
			for i in 3:
				var y := -0.45 + i * 0.4
				ci.draw_line(c + Vector2(0.09, y) * r, c + Vector2(0.45, y - 0.2) * r, line, w * 0.8, true)
				ci.draw_line(c + Vector2(0.09, y + 0.1) * r, c + Vector2(-0.3, y - 0.12) * r, line, w * 0.8, true)
		&"pastel":
			# marquinhas do garfo na borda
			for i in 8:
				var x := lerpf(-0.8, 0.8, i / 7.0)
				ci.draw_line(c + Vector2(x, -0.62) * r, c + Vector2(x, -0.45) * r, line, w * 0.7, true)
				ci.draw_line(c + Vector2(x, 0.62) * r, c + Vector2(x, 0.45) * r, line, w * 0.7, true)
			ci.draw_circle(c + Vector2(-0.4, -0.1) * r, r * 0.08, Color(1, 1, 1, 0.5))
