class_name DrinkShaders
extends RefCounted
## Shaders das bebidas: vidro, líquido, gelo e colarinho.
##
## O vidro antes era um StandardMaterial transparente com as duas faces desenhadas
## (`CULL_DISABLED`), o que fazia a garrafa aparecer por dentro de si mesma e o líquido
## brigar com o copo na ordenação. Aqui o vidro desenha só a face da frente e lê como
## vidro por dois sinais suaves: a borda acesa por Fresnel e uma mancha clara fixa na
## lateral de cima. O especular fica baixo de propósito — o jogo é cartoon, e vidro
## espelhado puxaria tudo para o realista.

## Vidro de garrafa e de copo. `tint` é a cor do vidro, `clarity` vai de fosco (0) a
## cristal (1). Serve também para o gelo, com `facet` ligado.
const GLASS := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(0.88, 0.96, 1.0, 1.0);
uniform float base_alpha = 0.26;
// quanto a borda fecha a cor (vidro é mais escuro de lado: é mais vidro no caminho)
uniform float thickness = 0.8;
uniform float facet = 0.0;
varying vec3 lnorm;

void vertex() { lnorm = NORMAL; }

void fragment() {
	vec3 n = normalize(NORMAL);
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 2.2);
	// brilho de estúdio: uma faixa clara fixa na lateral de cima, que é o que o olho
	// lê como "isso é vidro" mesmo sem reflexo do ambiente
	float key = smoothstep(0.62, 0.99, dot(n, normalize(vec3(-0.6, 0.62, 0.5))));
	float fillk = smoothstep(0.75, 1.0, dot(n, normalize(vec3(0.7, 0.25, 0.45))));
	vec3 col = tint.rgb * mix(1.0, 0.62, fres * thickness);
	// brilho de desenho: uma mancha clara macia, não um ponto de luz estourado
	col += vec3(key * 0.3 + fillk * 0.12);
	// gelo: facetas quebrando a luz
	if (facet > 0.5) {
		vec3 f = abs(lnorm);
		col *= 0.88 + 0.22 * max(f.x, max(f.y, f.z));
	}
	ALBEDO = col;
	ALPHA = clamp(base_alpha + fres * 0.7 + key * 0.3, 0.0, 1.0) * tint.a;
	ROUGHNESS = mix(0.45, 0.6, facet);
	SPECULAR = 0.25;
	METALLIC = 0.0;
	RIM = 0.5;
	RIM_TINT = 0.5;
}
"""

## Líquido dentro do copo ou da garrafa. O fundo fica mais concentrado, o topo mais
## claro, e as bebidas com gás ganham bolhinhas subindo (a malha de revolução já manda
## UV.x = volta e UV.y = altura em metros, então as bolhas sobem de verdade).
const LIQUID := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;
uniform vec4 liquid : source_color = vec4(0.9, 0.65, 0.1, 1.0);
uniform float base_alpha = 1.0;
// 0 = opaco (leite, batida); 1 = translúcido (cachaça, água, refri)
uniform float clarity = 0.0;
// bolhinhas subindo (cerveja, refrigerante)
uniform float fizz = 0.0;
// altura do líquido, para o degradê de concentração
uniform float height = 0.09;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec3 n = normalize(NORMAL);
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 2.0);
	// mais líquido no caminho = cor mais forte; em cima clareia
	float depth = 1.0 - clamp(UV.y / max(height, 0.001), 0.0, 1.0);
	vec3 col = liquid.rgb * (0.78 + depth * 0.32);
	col = mix(col, liquid.rgb + vec3(0.22), fres * 0.6 * clarity);
	// bolhas: fileiras que sobem e somem perto da superfície
	if (fizz > 0.5) {
		vec2 b = vec2(UV.x * 22.0, UV.y * 90.0 - TIME * 1.6);
		vec2 cell = floor(b);
		float r = hash(cell);
		float d = length(fract(b) - vec2(0.5));
		float bub = (1.0 - smoothstep(0.14, 0.24, d)) * step(0.68, r);
		col = mix(col, col + vec3(0.45), bub * (0.4 + 0.6 * depth));
	}
	ALBEDO = col;
	ALPHA = mix(base_alpha, 0.78, clarity);
	ROUGHNESS = mix(0.85, 0.6, clarity);
	SPECULAR = mix(0.08, 0.2, clarity);
	RIM = 0.35;
}
"""

## Colarinho da cerveja e creme da batida: espuma de bolhas miúdas.
const FOAM := """
shader_type spatial;
render_mode diffuse_lambert, specular_toon;
uniform vec4 cream : source_color = vec4(1.0, 0.98, 0.9, 1.0);

float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }

void fragment() {
	// células de espuma em volume: o copo pode girar que as bolhas acompanham
	vec3 p = floor(VERTEX * 170.0);
	float a = hash(p);
	float b = hash(p + 1.7);
	vec3 col = cream.rgb * (0.86 + 0.18 * a);
	// bolha estourada aqui e ali, mais escura
	col *= 1.0 - 0.18 * step(0.86, b);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.03;
	RIM = 0.45;
	RIM_TINT = 0.0;
}
"""


static func glass(tint: Color, alpha: float, thickness := 0.8, facet := false) -> ShaderMaterial:
	return BarShaders.shared(GLASS, {
		"tint": tint, "base_alpha": alpha, "thickness": thickness, "facet": 1.0 if facet else 0.0})


static func liquid(color: Color, clarity: float, fizz: bool, height: float, alpha := 1.0) -> ShaderMaterial:
	return BarShaders.shared(LIQUID, {
		"liquid": color, "clarity": clarity, "fizz": 1.0 if fizz else 0.0,
		"height": height, "base_alpha": alpha})


static func foam(cream: Color) -> ShaderMaterial:
	return BarShaders.shared(FOAM, {"cream": cream})
