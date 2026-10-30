class_name LightFX
extends RefCounted
## Luz "de mentira": o feixe que desce da lâmpada e a poça clara que ele deixa no chão.
##
## São malhas aditivas, sem sombreamento e sem escrever profundidade — custam quase
## nada e aparecem igual nos dois renderers. No Forward+ elas somam com o nevoeiro
## volumétrico; no renderer de compatibilidade, onde não há nevoeiro nenhum e sobram
## poucas luzes pontuais, são elas que fazem o trabalho de dar volume ao ar do bar.

## Feixe cônico de luz. Clareia onde a superfície olha para a câmera e some para baixo.
const BEAM := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.78, 0.45, 1.0);
uniform float strength = 0.35;
varying float along;

void vertex() {
	// UV.y do cilindro corre na altura: 0 em cima (na lâmpada), 1 lá embaixo
	along = UV.y;
}

void fragment() {
	float facing = pow(clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 1.5);
	float fade = pow(clamp(1.0 - along, 0.0, 1.0), 1.4);
	ALBEDO = tint.rgb * strength * facing * fade;
}
"""

## Poça de luz no chão (ou no tampo do balcão): degradê radial aditivo.
const POOL := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.78, 0.45, 1.0);
uniform float strength = 0.5;
uniform float sharpness = 2.2;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = tint.rgb * strength * pow(clamp(1.0 - d, 0.0, 1.0), sharpness);
}
"""


## Cone de luz descendo de `pos` até `pos.y - height`, abrindo de `top` para `bottom`.
## O cone ocupa muito espaço de tela e soma por cima de tudo que está atrás: em GPU
## fraca isso é caro, então lá fica só a poça no chão.
static func beam(parent: Node3D, pos: Vector3, top: float, bottom: float, height: float,
		tint: Color, strength := 0.3) -> MeshInstance3D:
	if GameManager.low_end:
		return null
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 14
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos - Vector3(0, height / 2.0, 0)
	mi.material_override = BarShaders.shared(BEAM, {"tint": tint, "strength": strength})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# não é peça de cenário: não entra na mesclagem nem no destaque de interação
	mi.set_meta("no_highlight", true)
	mi.set_meta("dynamic", true)
	parent.add_child(mi)
	return mi


## Mancha clara no chão, logo abaixo de uma luz. `up` false deita a poça para cima
## (teto), que é o que a lâmpada faz quando tem cúpula.
static func pool(parent: Node3D, pos: Vector3, radius: float, tint: Color,
		strength := 0.5, sharpness := 2.2, up := true) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(radius * 2.0, radius * 2.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees.x = -90.0 if up else 90.0
	mi.material_override = BarShaders.shared(POOL, {"tint": tint, "strength": strength, "sharpness": sharpness})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_highlight", true)
	mi.set_meta("dynamic", true)
	parent.add_child(mi)
	return mi
