class_name BarAtmosphere
extends Node3D
## Céu, luz do lado de fora e pós-processamento do ponto atual.
##
## O turno vai das 18h às 2h, e o `set_hour()` (chamado pelo relógio do bar) leva o céu
## do fim de tarde até a noite fechada: o sol poente baixa e esfria virando lua, o
## nevoeiro troca de cor e a luz que entra pela porta acompanha. Isso dá a "hora" do
## bar sem nenhum custo por frame.
##
## No renderer de compatibilidade (GPU sem Vulkan) os efeitos de tela saem — SSAO e
## nevoeiro volumétrico custavam metade do frame na GT 210 —, mas o céu, o nevoeiro
## simples e a luz de fora continuam, porque são de graça.

## Fração do turno em que a noite já fechou de vez.
const NIGHT_AT := 0.42

var env: Environment
var sky_mat: ProceduralSkyMaterial
## Sol poente que vira lua: a luz direcional que vem de fora.
var sun: DirectionalLight3D
## Luz fraca de preenchimento, da cor do céu, para os cantos não ficarem chapados.
var fill: DirectionalLight3D

var _loc: Dictionary
var _sky: Dictionary
## Quiosque aberto (praia): o céu e o sol fazem a iluminação principal.
var _open := false
var _lean := false
## Última hora aplicada: o relógio do turno avisa todo frame, e mexer no material do
## céu obriga a re-gerar o mapa de radiância — caríssimo em GPU fraca.
var _last_hour := -99.0


func setup(loc: Dictionary, lean: bool) -> void:
	_loc = loc
	_lean = lean
	_open = bool(loc.get("open", false))
	_sky = loc.get("sky", {})

	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_energy_multiplier = 1.0
	sky_mat.ground_energy_multiplier = 0.6
	sky_mat.sun_angle_max = 24.0
	sky_mat.sun_curve = 0.1
	var sky := Sky.new()
	sky.sky_material = sky_mat
	# o céu do bar é quase só um gradiente; não precisa de resolução nem reflexo caros
	sky.radiance_size = Sky.RADIANCE_SIZE_128 if _open else Sky.RADIANCE_SIZE_64
	# o céu muda a cada tique do relógio, então tem que ser o modo que atualiza barato
	sky.process_mode = Sky.PROCESS_MODE_REALTIME

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# dentro do bar quem manda é a luz das lâmpadas: o céu entra só pelo vão da porta.
	# no quiosque aberto o céu é a luz principal, então vira a fonte do ambiente.
	if _open:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 0.85
		env.ambient_light_color = _loc.ambient
		env.ambient_light_energy = 0.55 if _lean else 0.4
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = _loc.ambient
		# com as luzes pontuais de volta o ambiente pode ser bem mais baixo: é ele que
		# achatava o bar inteiro no modo leve antigo.
		env.ambient_light_energy = 0.5 if _lean else 0.22
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# Filmic, não ACES: ACES lava as cores saturadas de desenho e deixa tudo "lavado".
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.tonemap_white = 2.6

	# Correção de cor leve, só para as sombras não serem cinza morto. Em GPU fraca sai:
	# é mais uma passada de tela cheia e o ganho é pequeno.
	env.adjustment_enabled = not _lean
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.02
	env.adjustment_brightness = 1.0
	if not _lean:
		env.adjustment_color_correction = _grade()

	# Halo só no que é luz de verdade (lâmpada, neon, letreiro): limiar alto e intensidade
	# baixa. Glow forte é o que deixava a cena "brilhosa" — e em GPU sem Vulkan ele é uma
	# sequência de borrões de tela cheia, caro demais, então lá fica desligado.
	env.glow_enabled = not _lean
	env.glow_normalized = true
	env.glow_intensity = 0.42
	env.glow_strength = 0.9
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.35
	env.glow_hdr_scale = 1.6
	var levels := [0.0, 0.6, 1.0, 0.45, 0.15, 0.0, 0.0]
	for i in levels.size():
		env.set_glow_level(i, levels[i])

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 0.016 if not _open else 0.009
	env.fog_depth_begin = 3.0
	env.fog_depth_end = 26.0
	env.fog_sun_scatter = 0.25
	env.fog_sky_affect = 0.0 if not _open else 0.35

	if not _lean:
		# oclusão de contato: o que dá "peso" ao balcão, às garrafas e aos cantos
		env.ssao_enabled = true
		env.ssao_radius = 0.7
		env.ssao_intensity = 1.4
		env.ssao_power = 1.1
		env.ssao_detail = 0.6
		env.ssao_light_affect = 0.15
		env.ssao_ao_channel_affect = 0.0
		# fumaça de boteco: é ela que transforma as lâmpadas em feixes de luz
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.028 if not _open else 0.012
		env.volumetric_fog_albedo = Color(0.85, 0.8, 0.78)
		env.volumetric_fog_emission = _loc.fog
		env.volumetric_fog_emission_energy = 0.04
		env.volumetric_fog_length = 32.0
		env.volumetric_fog_gi_inject = 0.0
		env.volumetric_fog_anisotropy = 0.35
		env.volumetric_fog_ambient_inject = 0.1

	var we := WorldEnvironment.new()
	we.name = "Atmosphere"
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = not _lean
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 26.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = 1.4
	sun.light_angular_distance = 1.2
	sun.light_specular = 0.4
	add_child(sun)

	# No renderer de compatibilidade cada luz a mais redesenha a cena inteira, então
	# lá existe o sol e mais nada: o preenchimento vira luz de ambiente, de graça.
	if not _lean:
		fill = DirectionalLight3D.new()
		fill.name = "SkyFill"
		fill.rotation_degrees = Vector3(-62.0, 28.0, 0.0)
		fill.light_specular = 0.0
		fill.shadow_enabled = false
		add_child(fill)

	set_hour(18.0)


## 18h → 2h. Interpola céu, sol, nevoeiro e preenchimento entre o fim de tarde e a noite.
## Só recalcula a cada ~1 minuto de bar: o turno inteiro são 8 horas, então dá uns 400
## passos, imperceptíveis em movimento e quase de graça.
func set_hour(hour: float) -> void:
	if sky_mat == null or absf(hour - _last_hour) < 0.02:
		return
	_last_hour = hour
	var t := clampf((hour - 18.0) / 8.0, 0.0, 1.0)
	# o pôr do sol é rápido: a maior parte do turno é noite
	var n := smoothstep(0.0, NIGHT_AT, t)

	sky_mat.sky_top_color = _lerp_sky("top", n)
	sky_mat.sky_horizon_color = _lerp_sky("horizon", n)
	sky_mat.ground_horizon_color = _lerp_sky("horizon", n).darkened(0.45)
	sky_mat.ground_bottom_color = _lerp_sky("top", n).darkened(0.7)
	sky_mat.sun_angle_max = lerpf(28.0, 9.0, n)

	var sun_col := _lerp_sky("sun", n)
	sun.light_color = sun_col
	sun.light_energy = lerpf(float(_sky.get("sun_energy", 1.1)), float(_sky.get("moon_energy", 0.28)), n)
	# o sol poente rasante sobe para o alto virando lua
	sun.rotation_degrees = Vector3(lerpf(-7.0, -58.0, n), float(_sky.get("sun_yaw", 150.0)), 0.0)
	if _lean and _open:
		# quiosque em GPU fraca: a lua é a única luz do lugar, e as lampadinhas do
		# telhado foram descartadas — então ela carrega um tom quente de "luz do bar"
		sun.light_color = sun_col.lerp(Color(1.0, 0.86, 0.62), 0.45)
		sun.light_energy = maxf(sun.light_energy, 0.95)
	if _lean and not _open:
		# salão fechado em GPU fraca: esta é a única luz, então ela faz o papel das
		# lâmpadas — quente, vindo de cima e um pouco de lado, para dar relevo
		sun.light_color = _loc.ambient.lerp(Color(1.0, 0.82, 0.55), 0.6)
		sun.light_energy = 1.0
		sun.rotation_degrees = Vector3(-64.0, 152.0, 0.0)
	sky_mat.sun_curve = lerpf(0.08, 0.25, n)

	if fill != null:
		if _open:
			# quiosque: o preenchimento é o próprio céu, frio e vindo de cima
			fill.light_color = _lerp_sky("top", n).lerp(Color(0.55, 0.68, 1.0), 0.4)
			fill.light_energy = lerpf(0.44, 0.2, n)
		else:
			# salão fechado: o preenchimento é a cor das lâmpadas, senão o bar fica azulado
			fill.light_color = _loc.ambient
			fill.light_energy = 0.12

	env.fog_light_color = _loc.fog.lerp(_lerp_sky("horizon", n), 0.45)
	env.fog_light_energy = lerpf(1.2, 0.55, n)
	if not _lean:
		env.volumetric_fog_emission_energy = lerpf(0.07, 0.03, n)
	# no quiosque aberto o ambiente escurece junto com o céu
	if _open:
		env.ambient_light_energy = lerpf(0.9, 0.45, n) * (2.0 if _lean else 1.0)


func _lerp_sky(key: String, n: float) -> Color:
	var a: Color = _sky.get("%s_dusk" % key, Color(0.1, 0.12, 0.26))
	var b: Color = _sky.get("%s_night" % key, Color(0.03, 0.035, 0.08))
	return a.lerp(b, n)


## Correção de cor leve: sombras puxadas para o marrom do boteco e luzes para o âmbar.
## Um degradê 1D (luminância → cor) custa uma textura de 64 pixels.
func _grade() -> GradientTexture1D:
	var shadow: Color = _loc.get("grade_shadow", Color(0.1, 0.09, 0.13))
	var light: Color = _loc.get("grade_light", Color(1.0, 0.97, 0.9))
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([
		shadow.lerp(Color.BLACK, 0.55),
		Color(0.5, 0.5, 0.5).lerp(shadow.lerp(light, 0.5), 0.35),
		light])
	var tex := GradientTexture1D.new()
	tex.gradient = g
	tex.width = 64
	return tex
