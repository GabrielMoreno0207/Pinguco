extends Node
## CustomerDatabase (autoload): perfis de fregueses.
## Para um novo tipo, adicione um dicionário em PROFILES (ou um CustomerProfile .tres
## em res://data/customers/). Em order_templates, {pedido} vira "uma cerveja" e
## {bebida} vira "cerveja".

const EXTRA_DIR := "res://data/customers"

const PROFILES := [
	{
		"id": &"tiozao", "archetype": "O Tiozão", "body": CustomerProfile.Body.TIOZAO,
		"nicknames": ["Seu Juca", "Tio Valdir", "Seu Nonato", "Tio Arlindo"],
		"personality": "Fala muito, conta piada do pavê e aguenta o tranco.",
		"skin_color": Color(0.96, 0.74, 0.58), "shirt_color": Color(0.97, 0.97, 0.92),
		"pants_color": Color(0.32, 0.36, 0.55), "hair_color": Color(0.85, 0.85, 0.85),
		"tolerance": 150.0, "sensitivity": 0.9, "order_delay": 3.5, "patience": 34.0,
		"max_strikes": 4, "fickleness": 0.12, "chatter": 0.35, "voice_pitch": 0.82, "tip": 3,
		"favorites": {&"cerveja": 5, &"pinga": 3, &"caipirinha": 1, &"quentao": 2, &"jurubeba": 1, &"refrigerante": 1},
		"shirt_variants": [Color(0.97, 0.97, 0.92), Color(0.95, 0.9, 0.75), Color(0.75, 0.85, 0.95)],
		"hunger_rate": 0.2,
		"food_templates": ["Ô patrão, desce {pedido} que o estômago tá roncando!", "Me vê {pedido} pra forrar o bucho!"],
		"greetings": ["Boa noite, patrão! É pavê ou pa cumê?", "Opa! Cheguei, pode abrir a conta!"],
		"order_templates": ["Me vê {pedido} bem gelad{a}, patrão!", "Desce {pedido} aí, campeão!",
			"Patrão, manda {pedido}!", "Hoje eu quero {pedido}!"],
		"chatter_lines": ["Sabe por que o pinheiro não se perde? Porque tem uma pinha!",
			"No meu tempo a {bebida} custava um cruzeiro...", "Já te contei do meu Opala?"],
		"happy_lines": ["Ê beleza!", "Isso que é atendimento!", "Rapaz, que capricho!"],
		"wrong_lines": ["Ô, rapaz, isso aqui não é o que eu pedi não!", "Tá me tirando, é?"],
		"late_lines": ["Patrão... tô esperando aqui, viu?", "Vai demorar mais que o Natal?"],
		"angry_leave_lines": ["Vou no bar do Zé, lá é mais rápido!"],
		"pass_out_messages": ["{nome} capotou contando a piada do pavê!",
			"{nome} dormiu abraçado com o balcão!", "{nome} apagou igual vela de aniversário!"],
	},
	{
		"id": &"valentao", "archetype": "O Valentão", "body": CustomerProfile.Body.VALENTAO,
		"nicknames": ["Marretão", "Brutus", "Tonhão", "Pitbull"],
		"personality": "Impaciente, reclama de tudo e bate no balcão.",
		"skin_color": Color(0.62, 0.42, 0.3), "shirt_color": Color(0.12, 0.12, 0.14),
		"pants_color": Color(0.28, 0.3, 0.33), "hair_color": Color(0.08, 0.06, 0.05),
		"tolerance": 115.0, "sensitivity": 1.0, "order_delay": 2.2, "patience": 20.0,
		"max_strikes": 2, "fickleness": 0.1, "chatter": 0.1, "voice_pitch": 0.68, "tip": 1,
		"favorites": {&"pinga": 4, &"cerveja": 3, &"vinho": 1, &"tequila": 2, &"whisky": 1},
		"shirt_variants": [Color(0.12, 0.12, 0.14), Color(0.15, 0.2, 0.35), Color(0.4, 0.1, 0.1)],
		"hunger_rate": 0.22,
		"food_templates": ["{pedido}. Tô com fome. AGORA.", "Bota {pedido} aí, rápido!"],
		"greetings": ["Qual é, vai me atender ou não?", "Rápido que eu tô com pressa."],
		"order_templates": ["{pedido}. AGORA.", "Manda {pedido} e não enrola!",
			"Quero {pedido}. Rápido!", "Bota {pedido} aí, mermão!"],
		"chatter_lines": ["Tá olhando o quê?", "Esse bar já foi melhor."],
		"happy_lines": ["Hmpf. Serve.", "Agora sim.", "...valeu."],
		"wrong_lines": ["TÁ DE BRINCADEIRA?!", "Eu pedi outra coisa, ô zé ruela!"],
		"late_lines": ["VAI DEMORAR?!", "Tô perdendo a paciência, hein!"],
		"angry_leave_lines": ["Bar de quinta! Fui!"],
		"pass_out_messages": ["{nome} caiu feito um saco de batata!",
			"{nome} roncou tão alto que tremeu a prateleira!", "{nome} desmaiou de cara no amendoim!"],
	},
	{
		"id": &"falante", "archetype": "O Falante", "body": CustomerProfile.Body.FALANTE,
		"nicknames": ["Tagarela", "Rádio Peão", "Lero-Lero", "Professor"],
		"personality": "Pede muito, muda de assunto e de ideia o tempo todo.",
		"skin_color": Color(0.85, 0.6, 0.42), "shirt_color": Color(0.15, 0.62, 0.85),
		"pants_color": Color(0.85, 0.82, 0.7), "hair_color": Color(0.35, 0.18, 0.08),
		"tolerance": 90.0, "sensitivity": 1.05, "order_delay": 1.6, "patience": 28.0,
		"max_strikes": 3, "fickleness": 0.35, "chatter": 0.55, "voice_pitch": 1.25, "tip": 2,
		"favorites": {&"caipirinha": 3, &"batida": 3, &"cerveja": 2, &"vinho": 2, &"gin": 2, &"refrigerante": 1, &"agua": 1},
		"shirt_variants": [Color(0.15, 0.62, 0.85), Color(0.95, 0.55, 0.2), Color(0.3, 0.7, 0.4)],
		"hunger_rate": 0.18,
		"greetings": ["E aí, meu querido! Você viu o jogo ontem?", "Cheguei! Deixa eu te contar uma coisa..."],
		"order_templates": ["Ah, me vê {pedido}! Mas então, como eu ia dizendo...",
			"Hoje eu quero {pedido}!", "Sabe o que cai bem agora? {pedido}!",
			"Faz {pedido} pra mim, chefia?"],
		"chatter_lines": ["Você sabia que o polvo tem três corações?", "Meu cunhado jura que viu um ET em Varginha.",
			"Falando nisso, cadê a {bebida}?", "Ô, aumenta essa TV aí!"],
		"happy_lines": ["Maravilha! Igual minha vó fazia!", "Show de bola!", "Perfeito, perfeito!"],
		"wrong_lines": ["Hmm, não era bem isso não...", "Opa, acho que você se confundiu, amigão!"],
		"late_lines": ["Ei, psiu! Lembrou de mim?", "Tô aqui esperando, hein!"],
		"angry_leave_lines": ["Vou contar pra todo mundo que aqui demora!"],
		"pass_out_messages": ["{nome} finalmente ficou quieto!", "{nome} dormiu no meio da frase!",
			"{nome} capotou explicando a teoria do ET!"],
	},
	{
		"id": &"fofoqueira", "archetype": "A Fofoqueira", "body": CustomerProfile.Body.FOFOQUEIRA,
		"nicknames": ["Dona Cida", "Dona Neide", "Tia Zuleide", "Dona Lurdes"],
		"personality": "Sabe da vida de todo mundo. Fraca pra bebida, forte pra fofoca.",
		"skin_color": Color(0.78, 0.53, 0.38), "shirt_color": Color(0.95, 0.35, 0.45),
		"pants_color": Color(0.45, 0.2, 0.5), "hair_color": Color(0.55, 0.3, 0.55),
		"tolerance": 75.0, "sensitivity": 1.1, "order_delay": 2.8, "patience": 30.0,
		"max_strikes": 3, "fickleness": 0.2, "chatter": 0.45, "voice_pitch": 1.45, "tip": 4,
		"favorites": {&"batida": 4, &"vinho": 3, &"caipirinha": 2, &"gin": 2, &"quentao": 1, &"refrigerante": 1},
		"shirt_variants": [Color(0.95, 0.35, 0.45), Color(0.55, 0.35, 0.85), Color(0.2, 0.65, 0.6)],
		"hunger_rate": 0.2,
		"food_templates": ["Ai, querido, me vê {pedido}? Tô fraca!", "Uma fominha... {pedido}, por favor!"],
		"greetings": ["Boa noite, querido! Já soube da vizinha?", "Ai, que calor! Cadê o ventilador?"],
		"order_templates": ["Me vê {pedido}, meu bem!", "Querido, {pedido}, por favor!",
			"Ai, hoje eu mereço {pedido}!"],
		"chatter_lines": ["A filha da Neide fugiu com o moço do gás!", "Não conta pra ninguém, viu?",
			"Diz que o Juca tá devendo aqui, é verdade?"],
		"happy_lines": ["Ai, que delícia!", "Você é um amor!", "Vou recomendar pras amigas!"],
		"wrong_lines": ["Ué, mas eu pedi outra coisa, meu filho!", "Hmm, tá desatento hoje, hein?"],
		"late_lines": ["Psiu! Esqueceu de mim, foi?", "Que demora, minha Nossa Senhora!"],
		"angry_leave_lines": ["Vou contar pro bairro inteiro!"],
		"pass_out_messages": ["{nome} dormiu sonhando com a novela!", "{nome} apagou no meio da fofoca!",
			"{nome} roncou mais alto que o ventilador!"],
	},
	{
		"id": &"universitario", "archetype": "O Universitário", "body": CustomerProfile.Body.UNIVERSITARIO,
		"nicknames": ["Calouro", "Bixo", "Thiaguinho", "Mestrando"],
		"personality": "Duro, fraco pra bebida e com prova amanhã. Pede o mais barato.",
		"skin_color": Color(0.9, 0.7, 0.55), "shirt_color": Color(0.3, 0.35, 0.6),
		"pants_color": Color(0.22, 0.28, 0.45), "hair_color": Color(0.2, 0.12, 0.06),
		"shirt_variants": [Color(0.3, 0.35, 0.6), Color(0.55, 0.55, 0.55), Color(0.6, 0.2, 0.25), Color(0.25, 0.5, 0.35)],
		"tolerance": 70.0, "sensitivity": 1.15, "order_delay": 2.4, "patience": 32.0,
		"max_strikes": 3, "fickleness": 0.25, "chatter": 0.4, "voice_pitch": 1.12, "tip": 0,
		"hunger_rate": 0.3,
		"favorites": {&"cerveja": 4, &"tequila": 3, &"pinga": 2, &"gin": 1, &"agua": 1},
		"greetings": ["E aí, mestre! Aceita Pix, né?", "Cheguei! Só uma, que amanhã tem prova..."],
		"order_templates": ["Me vê {pedido}, a mais barata!", "Solta {pedido} aí, mestre!",
			"Bora de {pedido}!", "Mestre, {pedido}, por favor!"],
		"food_templates": ["Mestre, tem {pedido}? Não almocei...", "Me vê {pedido}, tô só no miojo essa semana!"],
		"chatter_lines": ["Bicho, a {bebida} aqui é mais barata que no DCE!", "Amanhã tem prova de cálculo... ou era hoje?",
			"Tô montando uma startup de {bebida}, quer investir?"],
		"happy_lines": ["Top demais!", "Brabo!", "Valeu, mestre!"],
		"wrong_lines": ["Mestre... não foi isso que eu pedi não.", "Opa, acho que veio trocado!"],
		"late_lines": ["Mestre? Esqueceu do calouro?", "Tô atrasado pro rolê, hein!"],
		"angry_leave_lines": ["Vou fazer um post falando mal daqui!"],
		"pass_out_messages": ["{nome} dormiu em cima da apostila!", "{nome} apagou igual aula das 7h!",
			"{nome} capotou antes da prova!"],
	},
	{
		"id": &"malandro", "archetype": "O Malandro", "body": CustomerProfile.Body.MALANDRO,
		"nicknames": ["Zé Pelintra", "Brizola", "Seu Malaquias", "Bigode"],
		"personality": "Chapéu panamá, samba no pé e muita lábia. Aguenta MUITO.",
		"skin_color": Color(0.55, 0.36, 0.24), "shirt_color": Color(0.95, 0.95, 0.95),
		"pants_color": Color(0.96, 0.96, 0.94), "hair_color": Color(0.1, 0.07, 0.05),
		"shirt_variants": [Color(0.85, 0.15, 0.2), Color(0.15, 0.3, 0.7), Color(0.1, 0.1, 0.12)],
		"tolerance": 170.0, "sensitivity": 0.85, "order_delay": 3.0, "patience": 30.0,
		"max_strikes": 3, "fickleness": 0.15, "chatter": 0.4, "voice_pitch": 0.9, "tip": 5,
		"hunger_rate": 0.12,
		"favorites": {&"whisky": 3, &"jurubeba": 3, &"pinga": 2, &"cerveja": 2, &"quentao": 1},
		"greetings": ["Boa noite, meu camarada! Salve a malandragem!", "Chegou quem faltava, meu rei!"],
		"order_templates": ["Meu rei, capricha {pedido} pro malandro!", "Desce {pedido}, que o samba tá bom!",
			"Me vê {pedido}, na moral!", "Manda {pedido}, que hoje eu tô inspirado!"],
		"food_templates": ["Malandro também come, meu rei: {pedido}!"],
		"chatter_lines": ["Malandro que é malandro não corre, meu rei.", "Esse pagode tá bom, aumenta aí!",
			"Já tomei {bebida} com o Bezerra da Silva, sabia?"],
		"happy_lines": ["Isso é que é categoria!", "Tá aprovado, meu rei!", "Classe!"],
		"wrong_lines": ["Ih, rapaz, trocou as bolas!", "Malandro não aceita gato por lebre, não!"],
		"late_lines": ["Malandro espera, mas não muito...", "Ô meu rei, tô na seca aqui!"],
		"angry_leave_lines": ["Vou sambar em outra freguesia!"],
		"pass_out_messages": ["{nome} dormiu com o chapéu na cara!", "{nome} sambou até cair!",
			"{nome} capotou com estilo!"],
	},
]

var _profiles: Array[CustomerProfile] = []


func _ready() -> void:
	for entry: Dictionary in PROFILES:
		_profiles.append(_from_dict(entry))
	if DirAccess.dir_exists_absolute(EXTRA_DIR):
		for file in DirAccess.get_files_at(EXTRA_DIR):
			var res := load(EXTRA_DIR.path_join(file))
			if res is CustomerProfile:
				_profiles.append(res)


func all() -> Array[CustomerProfile]:
	return _profiles


func get_profile(id: StringName) -> CustomerProfile:
	for p in _profiles:
		if p.id == id:
			return p
	return null


func random_profile(exclude: Array = []) -> CustomerProfile:
	var pool := _profiles.filter(func(p: CustomerProfile) -> bool: return not exclude.has(p.id))
	if pool.is_empty():
		pool = _profiles
	return pool[randi() % pool.size()]


func _from_dict(d: Dictionary) -> CustomerProfile:
	var p := CustomerProfile.new()
	for key: String in d:
		var value: Variant = d[key]
		if key == "shirt_variants":
			value = PackedColorArray(value)
		elif value is Array:
			value = PackedStringArray(value)
		p.set(key, value)
	return p
