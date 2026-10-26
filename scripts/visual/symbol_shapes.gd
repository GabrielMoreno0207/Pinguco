class_name SymbolShapes
extends RefCounted
## Polígonos dos símbolos das bebidas em coordenadas unitárias (-1..1, y para baixo).
## Usados tanto no HUD (draw_colored_polygon) quanto em 3D (Mats.flat_polygon_mesh),
## para que o símbolo seja idêntico em todo lugar.
## Bebidas: mug (cerveja), barrel (pinga), grapes (vinho), lime (caipirinha),
## strawberry (batida), bolt, flame, crown, sun, moon, leaf, drop, coxinha e pastel.
## star, heart, diamond, circle e lemon continuam disponíveis (fama, tatuagem, .tres antigos).

static var _cache: Dictionary = {}
static var _outline_cache: Dictionary = {}


static func polygon(symbol: StringName) -> PackedVector2Array:
	if _cache.has(symbol):
		return _cache[symbol]
	var pts := PackedVector2Array()
	match symbol:
		&"mug":
			# caneca de chope: corpo, espuma transbordando em bolhas e alça cheia
			var body := _rounded_rect(Rect2(-0.62, -0.42, 0.98, 1.3), 0.12)
			var handle := _ellipse(Vector2(0.4, 0.14), Vector2(0.42, 0.42), 24)
			var parts: Array = [body, handle]
			for i in 4:
				parts.append(_ellipse(Vector2(-0.56 + i * 0.3, -0.52 - (0.08 if i % 2 == 1 else 0.0)), Vector2(0.24, 0.22), 16))
			parts.append(_ellipse(Vector2(-0.62, -0.3), Vector2(0.14, 0.2), 12)) # espuma escorrendo
			pts = _union(parts)
		&"barrel":
			# barril de cachaça: barriga abaulada, tampos retos e torneirinha
			for i in 17:
				var y := lerpf(-0.88, 0.88, i / 16.0)
				pts.append(Vector2(0.58 + 0.24 * (1.0 - pow(y / 0.88, 2.0)), y))
			for i in 17:
				var y := lerpf(0.88, -0.88, i / 16.0)
				pts.append(Vector2(-(0.58 + 0.24 * (1.0 - pow(y / 0.88, 2.0))), y))
			pts = _union([pts, _rounded_rect(Rect2(-0.12, 0.22, 0.24, 0.2), 0.04)])
		&"grapes":
			# cacho de uva: bagos em triângulo, cabinho e folha
			var parts: Array = []
			var rows := [[-0.48, 0.0, 0.48], [-0.24, 0.24], [0.0]]
			for row in 3:
				for x: float in rows[row]:
					parts.append(_ellipse(Vector2(x, -0.22 + row * 0.4), Vector2(0.3, 0.3), 18))
			parts.append(_rounded_rect(Rect2(-0.05, -0.92, 0.1, 0.45), 0.03))
			var leaf := PackedVector2Array()
			for i in 16:
				var a := i * TAU / 16.0
				leaf.append(Vector2(0.24, -0.74) + Vector2(cos(a) * 0.3, sin(a) * 0.13).rotated(-0.35))
			parts.append(leaf)
			pts = _union(parts)
		&"lime":
			# meia rodela de limão (casca + gomos)
			for i in 25:
				var a := lerpf(0.0, PI, i / 24.0)
				pts.append(Vector2(cos(a) * 0.95, -0.38 + sin(a) * 0.95))
			pts.append(Vector2(-0.95, -0.46))
			pts.append(Vector2(0.95, -0.46))
		&"strawberry":
			# morango: corpo de "coração" com ponta, coroa de folhinhas e cabinho
			var body := PackedVector2Array()
			for i in 36:
				var a := i * TAU / 36.0
				var s := sin(a)
				var p := Vector2(cos(a) * 0.78, s * 0.62)
				if s > 0.0:
					p = Vector2(cos(a) * 0.78 * (1.0 - 0.45 * s), s * 0.95)
				body.append(p + Vector2(0, 0.0))
			var crown := PackedVector2Array()
			for i in 12:
				var a := PI + i * PI / 11.0
				var rr := 0.62 if i % 2 == 0 else 0.3
				crown.append(Vector2(0, -0.42) + Vector2(cos(a) * rr, sin(a) * rr * 0.55))
			crown.append(Vector2(0.4, -0.3))
			crown.append(Vector2(-0.4, -0.3))
			var stem := _rounded_rect(Rect2(-0.05, -0.92, 0.1, 0.45), 0.03)
			pts = _union([body, crown, stem])
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
			pts = PackedVector2Array([Vector2(-0.35, -0.85), Vector2(0.35, -0.85), Vector2(0.85, -0.3),
				Vector2(0, 1), Vector2(-0.85, -0.3)])
		&"circle":
			pts = _ellipse(Vector2.ZERO, Vector2(0.9, 0.9), 36)
		&"lemon":
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
			# raio gordinho, com quina chanfrada
			pts = PackedVector2Array([Vector2(0.12, -1.0), Vector2(-0.62, 0.18), Vector2(-0.08, 0.18),
				Vector2(-0.34, 1.0), Vector2(0.66, -0.26), Vector2(0.1, -0.26), Vector2(0.5, -1.0)])
		&"flame":
			# chama: gota com a ponta torcida para o lado e uma "língua" extra
			for i in 44:
				var t := i / 44.0 * TAU
				var x := sin(t) * 0.62
				var y := -cos(t)
				if y < 0.0:
					var k := -y
					x = x * (1.0 - k * 0.85) + sin(k * 2.6) * 0.28 * k
				else:
					y = 0.25 + y * 0.72
					x = sin(t) * 0.68
				pts.append(Vector2(x, y + 0.02))
			var tongue := PackedVector2Array([Vector2(-0.55, 0.1), Vector2(-0.72, -0.45), Vector2(-0.3, -0.1)])
			pts = _union([pts, tongue])
		&"crown":
			# coroa com três pontas, bolinhas nas pontas e faixa na base
			var base := PackedVector2Array([Vector2(-0.85, 0.72), Vector2(-0.95, -0.45), Vector2(-0.45, 0.0),
				Vector2(0, -0.68), Vector2(0.45, 0.0), Vector2(0.95, -0.45), Vector2(0.85, 0.72)])
			pts = _union([base, _ellipse(Vector2(-0.95, -0.55), Vector2(0.15, 0.15), 12),
				_ellipse(Vector2(0, -0.8), Vector2(0.16, 0.16), 12), _ellipse(Vector2(0.95, -0.55), Vector2(0.15, 0.15), 12)])
		&"sun":
			# sol: miolo redondo + 8 raios triangulares separados
			var parts: Array = [_ellipse(Vector2.ZERO, Vector2(0.58, 0.58), 28)]
			for i in 8:
				var a := -PI / 2.0 + i * TAU / 8.0
				parts.append(PackedVector2Array([Vector2(cos(a - 0.2), sin(a - 0.2)) * 0.5,
					Vector2(cos(a), sin(a)) * 1.0, Vector2(cos(a + 0.2), sin(a + 0.2)) * 0.5]))
			pts = _union(parts)
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
					x *= pow(1.0 + y, 1.6) * 0.72
					y *= 1.05
				else:
					x *= 0.72
					y = y * 0.72
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
			# coxinha: base gorducha e achatada, bico fino e torto no alto
			for i in 44:
				var t := i / 44.0 * TAU
				var y := -cos(t)
				var x := sin(t)
				if y < 0.0:
					var k := -y
					x *= pow(1.0 - k, 1.35) * 0.9
					x += k * k * 0.12
					y *= 1.0
				else:
					x *= 0.9
					y = minf(y * 0.82, 0.6)
				pts.append(Vector2(x, y + 0.24))
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


static func _ellipse(c: Vector2, r: Vector2, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := i * TAU / n
		out.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return out


static func _rounded_rect(rect: Rect2, rad: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var corners := [rect.position + Vector2(rect.size.x - rad, rad), rect.end - Vector2(rad, rad),
		Vector2(rect.position.x + rad, rect.end.y - rad), rect.position + Vector2(rad, rad)]
	for k in 4:
		for i in 5:
			var a := -PI / 2.0 + k * PI / 2.0 + i * (PI / 2.0) / 4.0
			out.append(corners[k] + Vector2(cos(a), sin(a)) * rad)
	return out


## Junta vários polígonos num contorno só (fica o maior pedaço, sem furos).
static func _union(parts: Array) -> PackedVector2Array:
	var acc: PackedVector2Array = parts[0]
	for i in range(1, parts.size()):
		var merged := Geometry2D.merge_polygons(acc, parts[i])
		var best := acc
		var best_area := -1.0
		# furos e pedaços soltos são sempre menores que o contorno de fora
		for poly: PackedVector2Array in merged:
			var area := _area(poly)
			if area > best_area:
				best_area = area
				best = poly
		acc = best
	return acc


static func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	return absf(s) * 0.5


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
	if radius >= 7.0:
		_details(ci, symbol, center, radius, color, outline)
	if outline_w > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, outline, outline_w, true)


static func _poly_at(c: Vector2, r: float, pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + p * r)
	return out


## Detalhes internos que deixam cada símbolo mais "desenhado". Usam só tons derivados
## de `color` e do contorno (não entregam a cor da bebida quando a pista de cor some).
static func _details(ci: CanvasItem, symbol: StringName, c: Vector2, r: float, color: Color, outline: Color) -> void:
	var line := outline.lerp(color, 0.35)
	var w := maxf(r * 0.07, 1.0)
	var shade := color.darkened(0.16)
	var shine := Color(1, 1, 1, 0.6)
	match symbol:
		&"mug":
			# vidro um tom abaixo da espuma, nervuras, furo da alça e bolhas
			ci.draw_colored_polygon(_poly_at(c, r, _rounded_rect(Rect2(-0.52, -0.3, 0.78, 1.08), 0.08)), shade)
			for x: float in [-0.3, -0.06, 0.18]:
				ci.draw_line(c + Vector2(x, -0.12) * r, c + Vector2(x, 0.68) * r, line, w * 0.8, true)
			ci.draw_colored_polygon(_poly_at(c, r, _ellipse(Vector2(0.52, 0.14), Vector2(0.16, 0.22), 14)), outline)
			ci.draw_circle(c + Vector2(-0.18, 0.36) * r, r * 0.05, shine)
			ci.draw_circle(c + Vector2(0.02, 0.12) * r, r * 0.04, shine)
			ci.draw_circle(c + Vector2(-0.42, -0.6) * r, r * 0.08, shine)
		&"barrel":
			# aduelas e aros
			for y: float in [-0.5, 0.5]:
				var hoop := PackedVector2Array()
				var half := 0.58 + 0.24 * (1.0 - pow(y / 0.88, 2.0))
				for i in 9:
					var x := lerpf(-half, half, i / 8.0)
					hoop.append(c + Vector2(x, y + (1.0 - pow(x / half, 2.0)) * 0.07) * r)
				ci.draw_polyline(hoop, outline, w * 1.6, true)
			for x: float in [-0.32, 0.0, 0.32]:
				var stave := PackedVector2Array()
				for i in 7:
					var y := lerpf(-0.82, 0.82, i / 6.0)
					stave.append(c + Vector2(x * (1.0 + 0.3 * (1.0 - pow(y / 0.88, 2.0))), y) * r)
				ci.draw_polyline(stave, line, w * 0.7, true)
			ci.draw_circle(c + Vector2(0, 0.38) * r, r * 0.07, outline)
			ci.draw_circle(c + Vector2(-0.45, -0.3) * r, r * 0.07, shine)
		&"grapes":
			var rows := [[-0.48, 0.0, 0.48], [-0.24, 0.24], [0.0]]
			for row in 3:
				for x: float in rows[row]:
					var g := c + Vector2(x, -0.22 + row * 0.4) * r
					ci.draw_arc(g, r * 0.29, 0.3, 2.6, 10, line, w * 0.8, true)
					ci.draw_circle(g + Vector2(-0.1, -0.1) * r, r * 0.06, shine)
			ci.draw_line(c + Vector2(0.02, -0.66) * r, c + Vector2(0.48, -0.86) * r, line, w * 0.8, true)
		&"lime":
			var lc := c + Vector2(0, -0.38) * r
			ci.draw_arc(lc, r * 0.78, 0.05, PI - 0.05, 18, line, w * 1.2, true)
			for a: float in [0.42, 0.95, 1.57, 2.19, 2.72]:
				ci.draw_line(lc + Vector2(cos(a), sin(a)) * r * 0.1, lc + Vector2(cos(a), sin(a)) * r * 0.7, line, w * 0.9, true)
			for a: float in [0.68, 1.26, 1.88, 2.46]:
				ci.draw_circle(lc + Vector2(cos(a), sin(a)) * r * 0.45, r * 0.05, shade)
			ci.draw_circle(lc, r * 0.08, line)
		&"strawberry":
			ci.draw_line(c + Vector2(-0.55, -0.34) * r, c + Vector2(0.55, -0.34) * r, line, w, true)
			var seeds := [Vector2(-0.4, -0.1), Vector2(0.0, -0.12), Vector2(0.4, -0.1), Vector2(-0.22, 0.18),
				Vector2(0.22, 0.18), Vector2(-0.4, 0.3), Vector2(0.4, 0.3), Vector2(0.0, 0.42), Vector2(-0.14, 0.62), Vector2(0.14, 0.62)]
			for s: Vector2 in seeds:
				ci.draw_line(c + s * r, c + (s + Vector2(0, 0.07)) * r, line, w * 1.1, true)
			ci.draw_circle(c + Vector2(-0.38, 0.0) * r, r * 0.08, shine)
		&"star", &"diamond", &"heart", &"drop", &"bolt", &"coxinha":
			# brilho de desenho animado
			var hl := c + Vector2(-0.3, -0.25) * r
			if symbol == &"drop":
				hl = c + Vector2(-0.25, 0.3) * r
				ci.draw_arc(c + Vector2(0, 0.35) * r, r * 0.42, 0.3, PI - 0.3, 10, line, w, true)
			elif symbol == &"coxinha":
				hl = c + Vector2(-0.32, 0.3) * r
			elif symbol == &"bolt":
				hl = c + Vector2(0.12, -0.55) * r
				ci.draw_line(c + Vector2(0.2, -0.8) * r, c + Vector2(-0.3, 0.05) * r, Color(1, 1, 1, 0.5), w * 1.2, true)
			ci.draw_circle(hl, r * 0.13, shine)
			if symbol == &"diamond":
				ci.draw_line(c + Vector2(-0.85, -0.3) * r, c + Vector2(0.85, -0.3) * r, line, w, true)
				ci.draw_line(c + Vector2(-0.2, -0.3) * r, c + Vector2(0, 1) * r, line, w, true)
				ci.draw_line(c + Vector2(0.2, -0.3) * r, c + Vector2(0, 1) * r, line, w, true)
			if symbol == &"coxinha":
				# casquinha de empanado mais escura embaixo + farelinhos
				ci.draw_arc(c + Vector2(0, 0.2) * r, r * 0.6, 0.35, PI - 0.35, 12, shade, w * 2.2, true)
				for i in 7:
					var a := i * 1.9
					ci.draw_circle(c + Vector2(cos(a) * 0.4, 0.4 + sin(a) * 0.18) * r, r * 0.05, line)
		&"circle":
			ci.draw_arc(c, r * 0.62, -2.6, -1.2, 10, shine, w * 1.4, true)
		&"lemon":
			ci.draw_circle(c, r * 0.48, shade)
			for i in 6:
				var a := i * TAU / 6.0
				ci.draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.46, line, w, true)
		&"flame":
			var inner := PackedVector2Array()
			var src := polygon(&"drop")
			for p in src:
				inner.append(c + Vector2(p.x * 0.38, p.y * 0.45 + 0.28) * r)
			ci.draw_colored_polygon(inner, shade)
			ci.draw_circle(c + Vector2(-0.12, 0.42) * r, r * 0.07, shine)
		&"crown":
			for x: float in [-0.95, 0.0, 0.95]:
				var y := -0.55 if absf(x) > 0.5 else -0.8
				ci.draw_circle(c + Vector2(x - 0.04, y - 0.04) * r, r * 0.05, shine)
			ci.draw_colored_polygon(_poly_at(c, r, PackedVector2Array([Vector2(-0.86, 0.36), Vector2(0.86, 0.36),
				Vector2(0.85, 0.72), Vector2(-0.85, 0.72)])), shade)
			ci.draw_line(c + Vector2(-0.86, 0.36) * r, c + Vector2(0.86, 0.36) * r, line, w, true)
			for x: float in [-0.5, 0.0, 0.5]:
				ci.draw_circle(c + Vector2(x, 0.54) * r, r * (0.1 if x == 0.0 else 0.07), outline)
		&"sun":
			ci.draw_arc(c, r * 0.45, 0.0, TAU, 20, shade, w * 1.1, true)
			ci.draw_circle(c + Vector2(-0.18, -0.1) * r, r * 0.06, line)
			ci.draw_circle(c + Vector2(0.18, -0.1) * r, r * 0.06, line)
			ci.draw_arc(c + Vector2(0, 0.02) * r, r * 0.25, 0.4, PI - 0.4, 8, line, w, true)
		&"moon":
			ci.draw_circle(c + Vector2(-0.55, 0.1) * r, r * 0.09, shade)
			ci.draw_circle(c + Vector2(-0.35, 0.5) * r, r * 0.06, shade)
			ci.draw_circle(c + Vector2(-0.55, -0.4) * r, r * 0.05, shine)
		&"leaf":
			ci.draw_line(c + Vector2(0.05, 0.95) * r, c + Vector2(0.1, -0.8) * r, line, w, true)
			for i in 3:
				var y := -0.45 + i * 0.4
				ci.draw_line(c + Vector2(0.09, y) * r, c + Vector2(0.45, y - 0.2) * r, line, w * 0.8, true)
				ci.draw_line(c + Vector2(0.09, y + 0.1) * r, c + Vector2(-0.3, y - 0.12) * r, line, w * 0.8, true)
		&"pastel":
			# marquinhas do garfo na borda + bolhas de fritura
			for i in 8:
				var x := lerpf(-0.8, 0.8, i / 7.0)
				ci.draw_line(c + Vector2(x, -0.62) * r, c + Vector2(x, -0.45) * r, line, w * 0.7, true)
				ci.draw_line(c + Vector2(x, 0.62) * r, c + Vector2(x, 0.45) * r, line, w * 0.7, true)
			for b: Vector2 in [Vector2(-0.45, -0.05), Vector2(0.1, 0.12), Vector2(0.5, -0.12)]:
				ci.draw_arc(c + b * r, r * 0.09, 0, TAU, 8, shade, w * 0.9, true)
			ci.draw_circle(c + Vector2(-0.6, -0.25) * r, r * 0.07, shine)
