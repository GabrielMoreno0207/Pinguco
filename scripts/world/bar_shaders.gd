class_name BarShaders
extends RefCounted
## Shaders procedurais do cenário: piso de caquinhos vermelhos, pisos alternativos
## (ladrilho, tábua, areia), azulejo + parede pintada (com desgaste), madeira com veio e
## verniz, tela da TV passando futebol e as peças do lado de fora — mar com ondas, areia
## de praia, fachada de prédio com janelas acesas e asfalto.
##
## A vista de fora já foi um quadro pintado num *quad* atrás da porta; hoje é geometria
## de verdade, montada pelo OutsideBuilder com estes shaders.

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
	// trilha de passagem na frente do balcão: encardido e sem brilho
	float path = 1.0 - smoothstep(0.6, 2.6, abs(wpos.z - 1.1));
	col *= 1.0 - path * 0.13 * (0.6 + 0.4 * hash2(id * 5.3).y);
	ALBEDO = mix(grout, col, g);
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
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
	// trilha de passagem gasta na frente do balcão
	float path = 1.0 - smoothstep(0.6, 2.6, abs(p.y - 1.1));
	col *= 1.0 - path * 0.1;
	ALBEDO = col;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
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
	// rejunte com profundidade: o sulco escurece e ganha relevo na normal
	vec2 groove = smoothstep(vec2(0.0), vec2(0.055), f) * smoothstep(vec2(0.0), vec2(0.055), 1.0 - f);
	float grout = min(groove.x, groove.y);
	bool checker = mod(cell.x + cell.y, 2.0) < 1.0;
	vec3 tile = checker ? tile_a : tile_b;
	tile *= 0.97 + 0.05 * hash(cell);
	// leve degradê dentro da peça, só para o azulejo não virar um quadrado chapado
	tile *= 1.0 + 0.05 * (1.0 - length(f - 0.5) * 1.6);
	vec3 tiled = mix(vec3(0.78, 0.78, 0.74), tile, grout);
	float n = hash(floor(vec2(u, wpos.y) * 6.0)) * 0.05;
	vec3 painted = paint * (0.95 + n);
	// marca de rolo de pintura, na vertical
	painted *= 0.97 + 0.05 * vnoise(vec2(u * 7.0, wpos.y * 0.6));
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
	// encardido subindo do chão e sombra onde a parede encontra o teto
	col *= mix(1.0, 0.82, (1.0 - smoothstep(0.0, 0.45, wpos.y)) * (0.4 + grime * 0.6));
	ALBEDO = col;
	// visual de desenho: superfície lisa e fosca, sem relevo nem reflexo de azulejo
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}
"""

## Madeira: tábuas com veio, nós e verniz. Serve de tampo de balcão, mesa, prateleira
## e viga — antes tudo isso era uma cor chapada, que é o que mais entregava o "sem
## textura" do cenário.
const WOOD := """
shader_type spatial;
render_mode diffuse_toon, specular_schlick_ggx;
uniform vec3 col_a : source_color = vec3(0.55, 0.3, 0.16);
uniform vec3 col_b : source_color = vec3(0.36, 0.19, 0.1);
uniform float plank = 0.3;
// 0 = madeira seca; 1 = envernizada e espelhando a luz
uniform float varnish = 0.7;
// 0 = veio ao longo de X; 1 = ao longo de Z
uniform float along_z = 0.0;
uniform float wear = 0.25;
varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// o veio corre no comprimento da peça; nas faces de topo usa a outra direção
	vec2 p = abs(wnorm.y) > 0.5 ? wpos.xz : (abs(wnorm.x) > 0.5 ? wpos.zy : wpos.xy);
	if (along_z > 0.5) { p = p.yx; }
	float row = floor(p.y / plank);
	// cada tábua começa num ponto diferente do veio
	float off = hash(vec2(row, 7.1)) * 12.0;
	float grain = sin((p.x + off) * 5.0 + vnoise(vec2((p.x + off) * 1.6, p.y * 5.0)) * 3.0);
	grain = grain * 0.5 + 0.5;
	// fibra fina por cima do veio largo, bem de leve
	grain = grain * 0.88 + vnoise(vec2((p.x + off) * 26.0, p.y * 40.0)) * 0.12;
	// o veio só desloca a cor um pouco: a tábua continua sendo uma cor só
	vec3 col = mix(col_b, col_a, 0.4 + grain * 0.6);
	// cada tábua com um tom
	col *= 0.95 + 0.1 * hash(vec2(row, 3.3));
	// nós da madeira
	vec2 kcell = floor(vec2((p.x + off) / 1.1, row));
	vec2 kpos = vec2((kcell.x + hash(kcell) ) * 1.1 - off, (kcell.y + 0.5) * plank);
	float kd = length((vec2(p.x, p.y) - kpos) / vec2(1.0, 0.55));
	float knot = (1.0 - smoothstep(0.03, 0.075, kd)) * step(0.85, hash(kcell + 5.0));
	col = mix(col, col_b * 0.72, knot);
	// fresta entre as tábuas
	float seam = smoothstep(0.0, 0.035, fract(p.y / plank)) * smoothstep(0.0, 0.035, 1.0 - fract(p.y / plank));
	col *= mix(0.45, 1.0, seam);
	// marcas de uso: copo, risco, desbotado
	float used = vnoise(p * 1.7);
	col *= 1.0 - wear * 0.16 * smoothstep(0.55, 0.9, used);
	ALBEDO = col;
	// o verniz só clareia um pouco a madeira; brilho de espelho estragaria o cartoon
	ALBEDO *= 1.0 + varnish * 0.06;
	ROUGHNESS = mix(0.95, 0.72, varnish);
	SPECULAR = mix(0.08, 0.2, varnish);
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

## Um Shader compilado por código (antes cada chamada compilava de novo) e, em
## `shared()`, um material por conjunto de parâmetros — sem isso cada garrafa teria o
## seu, e a mesclagem de malhas por material não teria o que juntar.
static var _shader_cache: Dictionary = {}
static var _material_cache: Dictionary = {}


static func shader_for(code: String) -> Shader:
	var sh: Shader = _shader_cache.get(code)
	if sh == null:
		sh = Shader.new()
		sh.code = code
		_shader_cache[code] = sh
	return sh


static func material(code: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader_for(code)
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	return m


## O mesmo material para os mesmos parâmetros.
static func shared(code: String, params := {}) -> ShaderMaterial:
	var key := "%d|%s" % [code.hash(), var_to_str(params)]
	var m: ShaderMaterial = _material_cache.get(key)
	if m == null:
		m = material(code, params)
		_material_cache[key] = m
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
	m.metallic_specular = 0.45
	return m


# =================================================================== lado de fora

## Mar: a malha ondula no vertex (três senoides cruzadas) e a normal sai por diferenças
## finitas, então a luz da lua corre nas cristas. Do raso para o fundo a cor escurece;
## na beira sai espuma, com a língua d'água indo e vindo.
const SEA := """
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_back;
uniform vec3 deep : source_color = vec3(0.015, 0.07, 0.16);
uniform vec3 shallow : source_color = vec3(0.06, 0.26, 0.34);
uniform vec3 foam : source_color = vec3(0.86, 0.93, 0.96);
// z (mundo) onde a água encosta na areia
uniform float shore = 12.0;
uniform float depth_span = 34.0;
uniform float wave_height = 0.075;
varying vec3 wpos;
varying float crest;

float wave_at(vec2 p, float t) {
	return sin(p.y * 0.75 - t * 1.05) * 0.5
		+ sin(p.y * 1.9 + p.x * 0.35 - t * 1.6) * 0.3
		+ sin(p.x * 1.45 + t * 0.7) * 0.2;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = wave_at(wpos.xz, TIME);
	crest = w;
	VERTEX.y += w * wave_height;
	float e = 0.4;
	float dx = wave_at(wpos.xz + vec2(e, 0.0), TIME) - wave_at(wpos.xz - vec2(e, 0.0), TIME);
	float dz = wave_at(wpos.xz + vec2(0.0, e), TIME) - wave_at(wpos.xz - vec2(0.0, e), TIME);
	float k = wave_height / (2.0 * e);
	NORMAL = normalize(vec3(-dx * k, 1.0, -dz * k));
}

void fragment() {
	float d = clamp((wpos.z - shore) / depth_span, 0.0, 1.0);
	vec3 col = mix(shallow, deep, smoothstep(0.0, 0.75, d));
	// espuma das cristas
	float cap = smoothstep(0.72, 0.95, crest);
	// língua d'água: a beira avança e recua
	float tide = shore + 1.1 + sin(TIME * 0.55) * 0.7 + sin(wpos.x * 0.8 + TIME * 0.4) * 0.35;
	float edge = 1.0 - smoothstep(0.0, 1.6, wpos.z - tide);
	float lace = smoothstep(0.45, 0.9, sin(wpos.x * 5.5 + TIME * 1.3) * 0.5 + 0.5) * edge;
	float f = clamp(cap * 0.7 + edge * edge * 0.8 + lace * 0.5, 0.0, 1.0);
	ALBEDO = mix(col, foam, f);
	// água de desenho animado: um caminho de luz largo no lugar da cintilância fina
	ROUGHNESS = mix(0.45, 0.85, f);
	SPECULAR = mix(0.35, 0.1, f);
}
"""

## Areia da praia: grão fino, marcas de maré e a faixa molhada perto da água.
const SAND := """
shader_type spatial;
render_mode diffuse_lambert, specular_toon;
uniform vec3 dry : source_color = vec3(0.9, 0.79, 0.57);
uniform vec3 wet : source_color = vec3(0.56, 0.47, 0.34);
uniform float shore = 12.0;
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wpos.xz;
	float grain = hash(floor(p * 70.0)) * 0.5 + vnoise(p * 14.0) * 0.5;
	// ondulações de maré, paralelas à praia
	float ripple = 0.5 + 0.5 * sin(p.y * 3.4 + sin(p.x * 0.7) * 1.6);
	vec3 col = dry * (0.93 + grain * 0.1 + ripple * 0.07);
	// faixa molhada: escurece e fica lisa onde a água alcança
	float damp = 1.0 - smoothstep(0.0, 3.2, p.y - shore + 2.4);
	col = mix(col, wet, damp * 0.85);
	// conchinhas e pedrinhas
	float shell = step(0.9965, hash(floor(p * 26.0)));
	col = mix(col, vec3(0.97, 0.94, 0.88), shell);
	ALBEDO = col;
	ROUGHNESS = mix(0.98, 0.7, damp);
	SPECULAR = mix(0.05, 0.2, damp);
}
"""

## Fachada de prédio/casa: grade de janelas com umas acesas (quentes e frias), peitoril
## e reboco manchado. `seed` troca o sorteio, `floors`/`cols` a quantidade de janelas.
const FACADE := """
shader_type spatial;
render_mode diffuse_lambert, specular_toon;
uniform vec3 wall : source_color = vec3(0.14, 0.12, 0.16);
uniform vec3 trim : source_color = vec3(0.1, 0.09, 0.11);
uniform float floors = 6.0;
uniform float cols = 5.0;
uniform float lit_chance = 0.45;
uniform float seed = 1.0;
varying vec3 wnorm;

float hash(vec2 p) { return fract(sin(dot(p + seed, vec2(12.9898, 78.233))) * 43758.5453); }

void vertex() { wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }

void fragment() {
	// o topo e a base do prédio não levam janela
	if (abs(wnorm.y) > 0.5) {
		ALBEDO = trim;
		ROUGHNESS = 0.9;
		EMISSION = vec3(0.0);
	} else {
		vec2 uv = UV * vec2(cols, floors);
		vec2 cell = floor(uv);
		vec2 f = fract(uv);
		float r = hash(cell);
		// janela com moldura
		float win = (step(0.2, f.x) - step(0.8, f.x)) * (step(0.18, f.y) - step(0.74, f.y));
		float on = step(1.0 - lit_chance, r) * win;
		vec3 glow = mix(vec3(1.0, 0.82, 0.48), vec3(0.62, 0.84, 1.0), step(0.72, hash(cell + 7.3)));
		// cortina: metade das janelas acesas fica mais fraca
		glow *= mix(0.45, 1.0, hash(cell + 3.1));
		vec3 col = mix(wall * (0.88 + 0.24 * hash(cell * 1.7)), vec3(0.05, 0.05, 0.07), win * (1.0 - on));
		// peitoril claro embaixo de cada janela
		float sill = (step(0.74, f.y) - step(0.86, f.y)) * (step(0.12, f.x) - step(0.88, f.x));
		col = mix(col, trim * 1.7, sill);
		ALBEDO = mix(col, glow, on);
		EMISSION = glow * on * 0.9;
		ROUGHNESS = 0.95;
		SPECULAR = 0.05;
	}
}
"""

## Asfalto da rua: pedrinha fina, remendos, poça refletindo e a faixa central tracejada.
const ASPHALT := """
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
uniform vec3 base : source_color = vec3(0.075, 0.072, 0.082);
uniform vec3 paint : source_color = vec3(0.82, 0.76, 0.3);
// z (mundo) da faixa central
uniform float lane_z = 10.6;
uniform float lane_on = 1.0;
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wpos.xz;
	float grit = hash(floor(p * 55.0)) * 0.5 + vnoise(p * 12.0) * 0.5;
	vec3 col = base * (0.82 + grit * 0.38);
	// remendos de recapeamento
	col = mix(col, base * 1.5, smoothstep(0.62, 0.68, vnoise(p * 0.55)));
	// poças: lisas e escuras, espelham a luz do poste
	float puddle = smoothstep(0.7, 0.78, vnoise(p * 0.9 + 11.0));
	// faixa central tracejada
	float dash = step(0.5, fract(p.x * 0.35)) * (1.0 - smoothstep(0.06, 0.1, abs(p.y - lane_z))) * lane_on;
	col = mix(col, paint * (0.6 + grit * 0.5), dash);
	ALBEDO = col;
	ROUGHNESS = mix(0.9, 0.5, puddle);
	SPECULAR = mix(0.08, 0.3, puddle);
}
"""
