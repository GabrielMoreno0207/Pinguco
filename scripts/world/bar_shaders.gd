class_name BarShaders
extends RefCounted
## Shaders procedurais do cenário: piso de caquinhos vermelhos, pisos alternativos
## (ladrilho, tábua, areia), azulejo + parede pintada (com desgaste), tela da TV passando
## futebol e a vista lá de fora (bairro, centro da cidade ou praia).

const FLOOR := """
shader_type spatial;
render_mode diffuse_toon, specular_toon;
uniform vec3 tile_a : source_color = vec3(0.72, 0.16, 0.12);
uniform vec3 tile_b : source_color = vec3(0.62, 0.12, 0.1);
uniform vec3 tile_c : source_color = vec3(0.85, 0.75, 0.62);
uniform vec3 grout : source_color = vec3(0.86, 0.82, 0.74);
uniform float scale = 3.2;
varying vec3 wpos;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 uv = wpos.xz * scale;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float d1 = 8.0; float d2 = 8.0; vec2 id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 h = hash2(cell + o);
			vec2 r = o + h * 0.85 - f;
			float d = dot(r, r);
			if (d < d1) { d2 = d1; d1 = d; id = cell + o; }
			else if (d < d2) { d2 = d; }
		}
	}
	float edge = sqrt(d2) - sqrt(d1);
	float g = smoothstep(0.035, 0.08, edge);
	float pick = hash2(id * 1.37).x;
	vec3 col = pick < 0.08 ? tile_c : mix(tile_a, tile_b, hash2(id).y);
	col *= 0.9 + 0.2 * hash2(id * 3.1).x;
	ALBEDO = mix(grout, col, g);
	ROUGHNESS = mix(0.9, 0.35, g);
	SPECULAR = 0.4;
}
"""

## Pisos alternativos: 1 = ladrilho hidráulico xadrez, 2 = tábuas de madeira, 3 = areia.
const FLOOR_ALT := """
shader_type spatial;
render_mode diffuse_toon, specular_toon;
uniform int pattern = 1;
uniform vec3 col_a : source_color = vec3(0.9, 0.88, 0.82);
uniform vec3 col_b : source_color = vec3(0.15, 0.15, 0.16);
uniform float grime = 0.0;
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wpos.xz;
	vec3 col;
	float rough = 0.6;
	if (pattern == 1) {
		vec2 uv = p / 0.4;
		vec2 cell = floor(uv);
		vec2 f = fract(uv);
		bool checker = mod(cell.x + cell.y, 2.0) < 1.0;
		col = checker ? col_a : col_b;
		// florzinha do ladrilho no centro de cada peça
		float r = length(f - 0.5);
		col = mix(col, checker ? col_b : col_a, (1.0 - smoothstep(0.1, 0.13, r)) * 0.6);
		col = mix(vec3(0.7, 0.68, 0.62), col, step(0.03, f.x) * step(0.03, f.y));
		rough = 0.3;
	} else if (pattern == 2) {
		vec2 uv = vec2(p.x / 1.6, p.y / 0.18);
		float row = floor(uv.y);
		uv.x += hash(vec2(row, 3.0)) * 3.0;
		vec2 cell = vec2(floor(uv.x), row);
		vec2 f = fract(uv);
		float grain = 0.5 + 0.5 * sin(p.x * 18.0 + hash(cell) * 6.0 + sin(p.y * 40.0) * 0.5);
		col = mix(col_a, col_b, hash(cell) * 0.7 + grain * 0.3);
		col *= 0.92 + 0.12 * hash(cell * 2.3);
		col = mix(col * 0.55, col, step(0.06, f.y) * step(0.008, f.x));
		rough = 0.45;
	} else {
		float n = hash(floor(p * 40.0)) * 0.5 + hash(floor(p * 9.0)) * 0.5;
		col = mix(col_a, col_b, n);
		float ripple = 0.5 + 0.5 * sin(p.x * 3.0 + sin(p.y * 2.0) * 2.0);
		col *= 0.94 + ripple * 0.08;
		rough = 0.95;
	}
	col *= 1.0 - grime * 0.25 * hash(floor(p * 2.0));
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}
"""

const WALL := """
shader_type spatial;
render_mode diffuse_toon, specular_toon;
uniform vec3 tile_a : source_color = vec3(0.93, 0.95, 0.92);
uniform vec3 tile_b : source_color = vec3(0.35, 0.7, 0.62);
uniform vec3 paint : source_color = vec3(0.98, 0.84, 0.45);
uniform vec3 stripe : source_color = vec3(0.16, 0.5, 0.36);
uniform float tile_top = 1.25;
uniform float tile_size = 0.16;
// 0 = parede nova; 1 = manchada e descascando
uniform float grime = 0.0;
varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float u = abs(wnorm.x) > 0.5 ? wpos.z : wpos.x;
	if (abs(wnorm.y) > 0.5) { u = wpos.x; }
	vec2 uv = vec2(u, wpos.y) / tile_size;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float grout = step(0.06, f.x) * step(0.06, f.y);
	bool checker = mod(cell.x + cell.y, 2.0) < 1.0;
	vec3 tile = checker ? tile_a : tile_b;
	tile *= 0.94 + 0.08 * hash(cell);
	vec3 tiled = mix(vec3(0.78, 0.78, 0.74), tile, grout);
	float n = hash(floor(vec2(u, wpos.y) * 6.0)) * 0.05;
	vec3 painted = paint * (0.95 + n);
	// desgaste: manchas de umidade e reboco aparecendo onde a tinta descascou
	vec2 wp = vec2(u, wpos.y);
	float blot = vnoise(wp * 1.6) * 0.65 + vnoise(wp * 5.0) * 0.35;
	float peel = smoothstep(0.66, 0.7, blot) * grime;
	painted *= 1.0 - grime * 0.22 * vnoise(wp * 0.7 + 3.0);
	painted = mix(painted, vec3(0.82, 0.76, 0.66), peel);
	painted = mix(painted, painted * 0.7, smoothstep(0.62, 0.66, blot) * (1.0 - smoothstep(0.66, 0.7, blot)) * grime);
	tiled *= 1.0 - grime * 0.18 * step(0.8, hash(cell * 1.7));
	float band = step(tile_top, wpos.y);
	vec3 col = mix(tiled, painted, band);
	// faixa de acabamento entre azulejo e pintura
	float trim = step(tile_top, wpos.y) * (1.0 - step(tile_top + 0.06, wpos.y));
	col = mix(col, stripe, trim);
	ALBEDO = col;
	ROUGHNESS = mix(0.25, 0.85, band);
	SPECULAR = mix(0.6, 0.2, band);
}
"""

const TV := """
shader_type spatial;
render_mode unshaded;
void fragment() {
	vec2 uv = UV;
	vec3 grass = mix(vec3(0.15, 0.55, 0.2), vec3(0.2, 0.62, 0.25), step(0.5, fract(uv.x * 6.0)));
	float lines = step(abs(uv.x - 0.5), 0.006) + step(abs(length((uv - 0.5) * vec2(1.6, 1.0)) - 0.18), 0.008);
	lines += step(uv.y, 0.04) + step(0.96, uv.y);
	vec3 col = mix(grass, vec3(0.95), clamp(lines, 0.0, 1.0));
	vec2 ball = vec2(0.5 + 0.35 * sin(TIME * 0.7), 0.5 + 0.3 * sin(TIME * 1.3));
	col = mix(col, vec3(1.0), step(length((uv - ball) * vec2(1.6, 1.0)), 0.018));
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		vec2 p = vec2(0.5 + 0.38 * sin(TIME * 0.5 + fi * 1.7), 0.5 + 0.35 * cos(TIME * 0.6 + fi * 2.3));
		vec3 team = i < 3 ? vec3(1.0, 0.85, 0.1) : vec3(0.1, 0.2, 0.8);
		col = mix(col, team, step(length((uv - p) * vec2(1.6, 1.0)), 0.025));
	}
	float scan = 0.92 + 0.08 * sin(uv.y * 300.0 + TIME * 10.0);
	ALBEDO = col * scan;
	EMISSION = col * 0.6;
}
"""

const STREET := """
shader_type spatial;
render_mode unshaded;
// 0 = rua do bairro, 1 = prédios do centro, 2 = praia à noite
uniform int scene = 0;

float h1(float x) { return fract(sin(x * 91.7) * 43758.5); }

vec3 city(vec2 uv) {
	vec3 sky = mix(vec3(0.08, 0.06, 0.16), vec3(0.3, 0.14, 0.22), 1.0 - uv.y);
	float bx = floor(uv.x * 9.0);
	float top = 0.45 + h1(bx) * 0.5;
	float b = step(uv.y, top);
	vec3 bcol = mix(vec3(0.1, 0.1, 0.14), vec3(0.16, 0.14, 0.2), h1(bx + 4.0));
	vec2 w = vec2(fract(uv.x * 54.0), fract(uv.y * 40.0));
	float win = step(0.35, w.x) * step(0.4, w.y) * step(0.5, h1(floor(uv.x * 54.0) * 3.1 + floor(uv.y * 40.0) * 7.7));
	bcol = mix(bcol, mix(vec3(1.0, 0.85, 0.5), vec3(0.6, 0.85, 1.0), h1(bx + 9.0)), win * step(0.16, uv.y));
	vec3 col = mix(sky, bcol, b);
	// rua com faróis passando
	col = mix(col, vec3(0.18, 0.18, 0.2), step(uv.y, 0.12));
	float car = step(abs(fract(uv.x * 2.0 - TIME * 0.15) - 0.5), 0.03) * step(uv.y, 0.07) * step(0.03, uv.y);
	return mix(col, vec3(1.0, 0.9, 0.6), car);
}

vec3 beach(vec2 uv) {
	vec3 sky = mix(vec3(0.03, 0.05, 0.14), vec3(0.16, 0.12, 0.3), 1.0 - uv.y);
	float stars = step(0.996, fract(sin(dot(floor(uv * 160.0), vec2(12.9, 78.2))) * 43758.5));
	vec3 col = sky + stars * uv.y;
	vec2 moon = vec2(0.72, 0.78);
	col = mix(col, vec3(1.0, 0.97, 0.85), 1.0 - smoothstep(0.045, 0.05, length((uv - moon) * vec2(2.2, 1.0))));
	// mar com o reflexo da lua
	float sea = step(uv.y, 0.42);
	vec3 water = mix(vec3(0.02, 0.1, 0.2), vec3(0.05, 0.2, 0.32), uv.y / 0.42);
	float shimmer = step(0.75, fract(uv.y * 60.0 + sin(uv.x * 30.0 + TIME) * 0.6)) * (1.0 - smoothstep(0.0, 0.07, abs(uv.x - moon.x)));
	water += shimmer * 0.5;
	col = mix(col, water, sea);
	// faixa de areia e espuma
	col = mix(col, vec3(0.75, 0.66, 0.48), step(uv.y, 0.14));
	col = mix(col, vec3(0.85, 0.92, 0.95), step(abs(uv.y - 0.145 - sin(uv.x * 20.0 + TIME) * 0.006), 0.006));
	// coqueiros em silhueta
	for (int i = 0; i < 3; i++) {
		float px = 0.12 + float(i) * 0.38;
		float trunk = step(abs(uv.x - px - (uv.y - 0.14) * 0.15), 0.008) * step(uv.y, 0.62) * step(0.14, uv.y);
		vec2 c = vec2(px + 0.07, 0.62);
		float leaves = 0.0;
		for (int k = 0; k < 5; k++) {
			float a = float(k) * 1.25 + 0.3;
			vec2 d = (uv - c) * vec2(1.8, 1.0);
			vec2 dir = vec2(cos(a), sin(a) * 0.5);
			float along = clamp(dot(d, dir), 0.0, 0.12);
			leaves += step(length(d - dir * along), 0.012 + along * 0.05);
		}
		col = mix(col, vec3(0.02, 0.03, 0.05), clamp(trunk + leaves, 0.0, 1.0));
	}
	return col;
}

vec3 street(vec2 uv) {
	vec3 sky = mix(vec3(0.05, 0.06, 0.16), vec3(0.12, 0.1, 0.25), uv.y);
	float stars = step(0.997, fract(sin(dot(floor(uv * 160.0), vec2(12.9, 78.2))) * 43758.5));
	vec3 col = sky + stars * (1.0 - uv.y) * 0.8;
	// casas do outro lado da rua
	float houses = step(uv.y, 0.55 + 0.08 * step(0.5, fract(uv.x * 3.0)));
	vec3 house_col = mix(vec3(0.12, 0.08, 0.12), vec3(0.18, 0.1, 0.1), step(0.5, fract(uv.x * 1.5)));
	float win = step(0.6, fract(uv.x * 14.0)) * step(0.7, fract(uv.y * 9.0)) * step(uv.y, 0.5) * step(0.25, uv.y);
	house_col = mix(house_col, vec3(1.0, 0.8, 0.4), win * step(0.5, fract(sin(floor(uv.x * 14.0) * 7.0) * 99.0)));
	col = mix(col, house_col, houses);
	col = mix(col, vec3(0.2, 0.2, 0.22), step(uv.y, 0.12));
	return col;
}

void fragment() {
	if (scene == 1) {
		ALBEDO = city(UV);
	} else if (scene == 2) {
		ALBEDO = beach(UV);
	} else {
		ALBEDO = street(UV);
	}
}
"""


static func material(code: String, params := {}) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	return m


## Versão pré-calculada do piso de caquinhos (mesmo algoritmo do shader FLOOR), para
## GPUs fracas: uma textura 256² que repete a cada 2,5 m (8 células, bordas cíclicas).
static func floor_texture_material() -> StandardMaterial3D:
	var cells := 8
	var res := 256
	var rng := RandomNumberGenerator.new()
	rng.seed = 1987
	var pts := []
	var cols := []
	for y in cells:
		for x in cells:
			pts.append(Vector2(x + rng.randf_range(0.08, 0.92), y + rng.randf_range(0.08, 0.92)))
			var c := Color(0.72, 0.16, 0.12).lerp(Color(0.6, 0.11, 0.09), rng.randf())
			if rng.randf() < 0.08:
				c = Color(0.85, 0.75, 0.62)
			cols.append(c * rng.randf_range(0.9, 1.1))
	var img := Image.create(res, res, false, Image.FORMAT_RGB8)
	var grout := Color(0.86, 0.82, 0.74)
	for py in res:
		for px in res:
			var uv := Vector2(px, py) * cells / float(res)
			var cx := int(uv.x)
			var cy := int(uv.y)
			var d1 := 99.0
			var d2 := 99.0
			var id := 0
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var gx := posmod(cx + ox, cells)
					var gy := posmod(cy + oy, cells)
					var p: Vector2 = pts[gy * cells + gx] + Vector2(cx + ox - gx, cy + oy - gy)
					var d := uv.distance_squared_to(p)
					if d < d1:
						d2 = d1
						d1 = d
						id = gy * cells + gx
					elif d < d2:
						d2 = d
			var edge := sqrt(d2) - sqrt(d1)
			img.set_pixel(px, py, grout.lerp(cols[id], smoothstep(0.035, 0.08, edge)))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_world_triplanar = true
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * (3.2 / cells)
	m.roughness = 0.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	return m
