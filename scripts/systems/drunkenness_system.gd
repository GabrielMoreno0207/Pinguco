class_name DrunkennessSystem
extends RefCounted
## Regras de embriaguez: estágio por nível e distorção dos pedidos.
## A distorção sempre parte do pedido verdadeiro; o id da bebida nunca se perde
## (ele vive no OrderSystem.Order). Aqui só se decide o TEXTO e quais PISTAS aparecem.

enum Stage { SOBER, TIPSY, DRUNK, WASTED }

const STAGE_NAMES := ["Sóbrio", "Alegre", "Bêbado", "Chumbado"]
const STAGE_COLORS := [Color(0.45, 0.8, 0.35), Color(1.0, 0.8, 0.2), Color(1.0, 0.5, 0.15), Color(0.9, 0.2, 0.25)]
## Limiares (fração da tolerância) que iniciam cada estágio.
const THRESHOLDS := [0.0, 0.25, 0.5, 0.75]

const HICCUPS := ["*hic*", "*HIC*", "*hip*"]
const LAUGHS := ["hehe", "hihihi", "kkkk", "hahaha"]
const ABSURD := ["cadê meu cavalo?", "o chão tá mexendo", "eu te amo, cara", "quem apagou a lua?",
	"tô de boa, tô de boa", "isso aqui é um pato?", "minha ex...", "canta comigo!",
	"cê é meu melhor amigo", "o banquinho fugiu", "zzz... hã?", "eu sou o rei do pagode"]
const CONTEXT_LINES := ["Mais uma daquela!", "O mesmo de antes, patrão!", "Repete a dose!",
	"Aquela lá de novo!"]
## Pedidos de salgado quando o perfil não tem frases próprias.
const FOOD_TEMPLATES := ["Tô com uma fome... me vê {pedido}!", "Patrão, {pedido} pra forrar o estômago!",
	"Bateu a larica: {pedido}, por favor!", "Me vê {pedido} que o estômago tá roncando!"]
## Fome (0..1) a partir da qual o freguês pode pedir salgado.
const HUNGRY_AT := 0.6


static func fraction(level: float, tolerance: float) -> float:
	return clampf(level / maxf(tolerance, 1.0), 0.0, 1.0)


static func stage_for(level: float, tolerance: float) -> int:
	var f := fraction(level, tolerance)
	var s := 0
	for i in THRESHOLDS.size():
		if f >= THRESHOLDS[i]:
			s = i
	return s


## Retorna {"text": String, "clues": {"color","letter","symbol"}: bool, "stage": int}.
static func compose_order(profile: CustomerProfile, bev: BeverageData, stage: int,
		last_bev: StringName, rng: RandomNumberGenerator) -> Dictionary:
	var uses_context := not bev.is_food() and last_bev == bev.id and stage >= Stage.TIPSY and rng.randf() < 0.4
	var text := ""
	if uses_context:
		text = _pick(CONTEXT_LINES, rng)
	else:
		var templates: PackedStringArray = profile.order_templates
		if bev.is_food():
			templates = profile.food_templates if not profile.food_templates.is_empty() else PackedStringArray(FOOD_TEMPLATES)
		var template: String = _pick(templates, rng)
		var name_part := _name_for_stage(bev, stage, rng)
		var article := "" if stage >= Stage.DRUNK else bev.article + " "
		text = template.replace("{pedido}", article + name_part).replace("{bebida}", name_part)
		text = text.replace("{a}", "o" if bev.article == "um" else "a")
		if stage >= Stage.DRUNK:
			text = _simplify_template(text, name_part, stage, rng)
	text = distort(text, stage, rng)
	return {"text": text, "clues": _clues_for_stage(stage, uses_context, rng), "stage": stage}


## Aplica a distorção de fala ao texto conforme o estágio.
static func distort(text: String, stage: int, rng: RandomNumberGenerator) -> String:
	match stage:
		Stage.SOBER:
			return text
		Stage.TIPSY:
			var t := _stretch_vowels(text, 0.18, 2, rng)
			t = _duplicate_letters(t, 0.07, rng)
			if rng.randf() < 0.5:
				t += " " + _pick(LAUGHS, rng)
			return t
		Stage.DRUNK:
			var t := _slur(text, rng)
			t = _typos(t, 0.10, rng)
			t = _stretch_vowels(t, 0.15, 3, rng)
			return _insert_random(t, HICCUPS, rng)
		_:
			var t := _slur(text, rng)
			t = _typos(t, 0.16, rng)
			t = _stretch_vowels(t, 0.2, 4, rng)
			t = _insert_random(t, HICCUPS, rng)
			return t


static func _name_for_stage(bev: BeverageData, stage: int, rng: RandomNumberGenerator) -> String:
	var formal := bev.display_name.to_lower()
	match stage:
		Stage.SOBER:
			return formal
		Stage.TIPSY:
			return _pick(bev.slang, rng) if rng.randf() < 0.3 and bev.slang.size() > 0 else formal
		Stage.DRUNK:
			if rng.randf() < 0.55 and bev.slang.size() > 0:
				return _pick(bev.slang, rng)
			return _truncate(formal, 0.65)
		_:
			# Sempre resta um pedaço reconhecível: início do nome ou uma gíria.
			if rng.randf() < 0.5 and bev.slang.size() > 0:
				return _pick(bev.slang, rng)
			return _truncate(formal, 0.45)


static func _truncate(word: String, keep: float) -> String:
	var n := maxi(2, int(ceil(word.length() * keep)))
	return word.substr(0, n) + "..."


## Nos estágios 3–4 o pedido vira fragmentos: palavras somem e entra conversa absurda.
static func _simplify_template(text: String, name_part: String, stage: int, rng: RandomNumberGenerator) -> String:
	var words := text.split(" ", false)
	var name_words := name_part.split(" ", false)
	var drop_chance := 0.25 if stage == Stage.DRUNK else 0.5
	var kept: PackedStringArray = []
	for w in words:
		var is_name := false
		for nw in name_words:
			if w.to_lower().contains(nw.to_lower().trim_suffix("...")):
				is_name = true
		if is_name or rng.randf() > drop_chance:
			kept.append(w)
	var out := " ".join(kept)
	if not out.contains(name_words[0]):
		out = name_part + "... " + out
	if stage >= Stage.WASTED:
		var absurd: String = _pick(ABSURD, rng)
		out = (absurd + "... " + out) if rng.randf() < 0.5 else (out + "... " + absurd)
	return out


static func _clues_for_stage(stage: int, uses_context: bool, rng: RandomNumberGenerator) -> Dictionary:
	var keys := ["color", "letter", "symbol"]
	var count := 3
	if stage == Stage.DRUNK:
		count = 2
	elif stage >= Stage.WASTED:
		count = 2 if uses_context else 1
	var shuffled := keys.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	if count == 1 and shuffled[0] == "color":
		# com tantas bebidas, só a cor fica ambígua demais: a pista única é letra ou símbolo
		shuffled.reverse()
	var clues := {"color": false, "letter": false, "symbol": false}
	for i in count:
		clues[shuffled[i]] = true
	return clues


static func _stretch_vowels(text: String, chance: float, max_extra: int, rng: RandomNumberGenerator) -> String:
	var out := ""
	for i in text.length():
		var c := text[i]
		out += c
		var next_is_space := i == text.length() - 1 or text[i + 1] == " " or not text[i + 1].is_valid_identifier()
		if "aeiouáéíóúãõ".contains(c.to_lower()) and next_is_space and rng.randf() < chance * 3.0:
			out += c.repeat(rng.randi_range(1, max_extra))
		elif "aeiou".contains(c.to_lower()) and rng.randf() < chance * 0.4:
			out += c.repeat(rng.randi_range(1, max_extra))
	return out


static func _duplicate_letters(text: String, chance: float, rng: RandomNumberGenerator) -> String:
	var out := ""
	for c in text:
		out += c
		if c != " " and c.is_valid_identifier() and rng.randf() < chance:
			out += c
	return out


## Fala "enrolada": s→x, r→rr e algumas consoantes amolecem.
static func _slur(text: String, rng: RandomNumberGenerator) -> String:
	var out := ""
	for c in text:
		var lower := c.to_lower()
		if lower == "s" and rng.randf() < 0.5:
			out += "x" if c == lower else "X"
		elif lower == "r" and rng.randf() < 0.35:
			out += c + "r"
		elif lower == "v" and rng.randf() < 0.2:
			out += "b" if c == lower else "B"
		else:
			out += c
	return out


static func _typos(text: String, chance: float, rng: RandomNumberGenerator) -> String:
	var chars := []
	for c in text:
		chars.append(c)
	var i := 0
	while i < chars.size() - 1:
		if chars[i] != " " and chars[i + 1] != " " and rng.randf() < chance:
			var roll := rng.randf()
			if roll < 0.5:
				var tmp: String = chars[i]
				chars[i] = chars[i + 1]
				chars[i + 1] = tmp
				i += 1
			elif roll < 0.8 and chars.size() > 4:
				chars.remove_at(i)
			else:
				chars.insert(i, chars[i])
				i += 1
		i += 1
	return "".join(PackedStringArray(chars))


static func _insert_random(text: String, pool: Array, rng: RandomNumberGenerator) -> String:
	var words := text.split(" ", false)
	if words.size() < 2:
		return text + " " + _pick(pool, rng)
	var idx := rng.randi_range(1, words.size() - 1)
	words.insert(idx, _pick(pool, rng))
	return " ".join(words)


static func _pick(arr: Variant, rng: RandomNumberGenerator) -> String:
	if arr.size() == 0:
		return ""
	return arr[rng.randi_range(0, arr.size() - 1)]
