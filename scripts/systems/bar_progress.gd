extends Node
## BarProgress (autoload): o que sobrevive de um turno pro outro — dia, ponto do bar,
## dinheiro guardado, o que ficou na gaveta da caixa registradora, melhorias e reformas
## compradas e onde cada garrafa mora. Salvo em user://bar_progress.json.
## Nos modos de teste nada é lido nem gravado.

signal changed

const SAVE_PATH := "user://bar_progress.json"

## Ordem de exibição no caderninho. "costs" = preço base de cada nível (multiplicado
## pelo cost_mult do ponto). kind: "service" mexe no atendimento, "reform" muda o visual
## do bar e cada nível rende +R$ 1 de gorjeta por pedido (o freguês gosta do ambiente).
const UPGRADES := [
	{
		"id": &"banqueta", "kind": &"service", "name": "Banqueta extra",
		"desc": "+1 lugar no balcão: mais um pinguço por vez.",
		"costs": [150, 320],
	},
	{
		"id": &"cardapio", "kind": &"service", "name": "Cardápio reajustado",
		"desc": "Bebidas 15% mais caras (e ninguém reclama).",
		"costs": [100, 220, 380],
	},
	{
		"id": &"preparo", "kind": &"service", "name": "Equipamento novo",
		"desc": "Servir e preparar 15% mais rápido.",
		"costs": [120, 250, 420],
	},
	{
		"id": &"amendoim", "kind": &"service", "name": "Amendoim de cortesia",
		"desc": "Fregueses 15% mais pacientes com o pedido.",
		"costs": [80, 170, 300],
	},
	{
		"id": &"neon", "kind": &"service", "name": "Letreiro de neon",
		"desc": "Placa ABERTO na fachada: fregueses chegam 12% mais rápido.",
		"costs": [120, 250, 420],
	},
	{
		"id": &"pintura", "kind": &"reform", "name": "Pintura nova",
		"desc": "Parede descascada nunca mais: cores novas e azulejo limpinho.",
		"costs": [140],
	},
	{
		"id": &"piso", "kind": &"reform", "name": "Piso novo",
		"desc": "Troca o chão inteiro do salão.",
		"costs": [180],
	},
	{
		"id": &"luz", "kind": &"reform", "name": "Iluminação",
		"desc": "Nível 1: varal de lâmpadas no teto. Nível 2: neon colorido nas paredes.",
		"costs": [120, 260],
	},
	{
		"id": &"tv", "kind": &"reform", "name": "TV de tela grande",
		"desc": "Aposenta a TV de tubo: telão pro jogo e uma segunda TV no salão.",
		"costs": [200],
	},
	{
		"id": &"decoracao", "kind": &"reform", "name": "Decoração",
		"desc": "Nível 1: plantas e quadros. Nível 2: jukebox iluminada.",
		"costs": [110, 280],
	},
	{
		"id": &"mobilia", "kind": &"reform", "name": "Mobília nova",
		"desc": "Banquetas estofadas com encosto e toalha com vela nas mesas.",
		"costs": [220],
	},
]

## Dia do próximo turno (começa no 1).
var day := 1
## Ponto atual do bar (ver BarLocations).
var location: StringName = &"boteco"
## Dinheiro já recolhido, disponível para investir.
var bank := 0
## Dinheiro do último turno que ainda está na gaveta da caixa.
var register_cash := 0
var levels: Dictionary = {} # upgrade id -> nível (vale só para o ponto atual)
var layout: Dictionary = {} # bev id -> slot id

## Os testes apontam para outro arquivo para não mexer no save do jogador.
var save_path := SAVE_PATH
var _ephemeral := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_ephemeral = args.has("--autotest") or args.has("--bench") or args.has("--gallery") or args.has("--views")
	if not _ephemeral:
		_load()


func loc() -> Dictionary:
	return BarLocations.get_location(location)


# ------------------------------------------------------------------ dinheiro

## Fim de turno: a féria vai pra gaveta e o calendário anda.
func deposit_shift(amount: int) -> void:
	register_cash += maxi(amount, 0)
	day += 1
	_commit()


## Recolhe a gaveta e devolve quanto veio.
func collect_register() -> int:
	var amount := register_cash
	if amount <= 0:
		return 0
	bank += amount
	register_cash = 0
	_commit()
	return amount


func has_progress() -> bool:
	return day > 1 or bank > 0 or register_cash > 0 or not levels.is_empty() or location != &"boteco"


# ------------------------------------------------------------------ melhorias e reformas

func upgrade_info(id: StringName) -> Dictionary:
	for u: Dictionary in UPGRADES:
		if u.id == id:
			return u
	return {}


func upgrades_of_kind(kind: StringName) -> Array:
	return UPGRADES.filter(func(u: Dictionary) -> bool: return u.kind == kind)


func level(id: StringName) -> int:
	return int(levels.get(id, 0))


func max_level(id: StringName) -> int:
	return upgrade_info(id).get("costs", []).size()


## Preço do próximo nível neste ponto; -1 se já está no máximo.
func next_cost(id: StringName) -> int:
	var costs: Array = upgrade_info(id).get("costs", [])
	var lvl := level(id)
	if lvl >= costs.size():
		return -1
	return int(round(costs[lvl] * float(loc().cost_mult) / 10.0)) * 10


func can_buy(id: StringName) -> bool:
	var cost := next_cost(id)
	return cost >= 0 and bank >= cost


func buy(id: StringName) -> bool:
	if not can_buy(id):
		return false
	bank -= next_cost(id)
	levels[id] = level(id) + 1
	_commit()
	return true


## Total de níveis de reforma comprados no ponto atual.
func reform_count() -> int:
	var n := 0
	for u: Dictionary in upgrades_of_kind(&"reform"):
		n += level(u.id)
	return n


func seat_count() -> int:
	return int(loc().base_seats) + level(&"banqueta")


func price_of(bev: BeverageData) -> int:
	return int(round(bev.price * float(loc().price_mult) * (1.0 + 0.15 * level(&"cardapio"))))


## Gorjeta extra por pedido: o freguês gosta de bar bem cuidado.
func ambience_tip() -> int:
	return reform_count()


func prep_time_of(bev: BeverageData) -> float:
	return bev.prep_time * (1.0 - 0.15 * level(&"preparo"))


func patience_multiplier() -> float:
	return 1.0 + 0.15 * level(&"amendoim")


func spawn_interval_multiplier() -> float:
	return float(loc().spawn_mult) * (1.0 - 0.12 * level(&"neon"))


# ------------------------------------------------------------------ mudança de ponto

func next_location() -> StringName:
	return BarLocations.next_after(location)


## Lista de requisitos do próximo ponto: [{text, ok}]. Vazia se não há próximo.
func move_requirements() -> Array:
	var id := next_location()
	if id == &"":
		return []
	var target := BarLocations.get_location(id)
	return [
		{"text": "Chegar ao dia %d (hoje: dia %d)" % [target.min_day, day], "ok": day >= int(target.min_day)},
		{"text": "%d reformas no bar atual (feitas: %d)" % [target.min_reforms, reform_count()], "ok": reform_count() >= int(target.min_reforms)},
		{"text": "Saldo de %s (tem: %s)" % [GameManager.format_money(target.cost), GameManager.format_money(bank)], "ok": bank >= int(target.cost)},
	]


func can_move() -> bool:
	var reqs := move_requirements()
	return not reqs.is_empty() and reqs.all(func(r: Dictionary) -> bool: return r.ok)


## Bar novo, vida nova: paga o ponto e começa sem melhorias nem arrumação.
func move_to_next() -> bool:
	if not can_move():
		return false
	var id := next_location()
	bank -= int(BarLocations.get_location(id).cost)
	location = id
	levels = {}
	layout = {}
	_commit()
	return true


# ------------------------------------------------------------------ arrumação

func slot_of(bev_id: StringName) -> StringName:
	return StringName(layout.get(bev_id, ""))


func set_slot(bev_id: StringName, slot_id: StringName) -> void:
	layout[bev_id] = slot_id


func save_layout() -> void:
	_commit()


# ------------------------------------------------------------------ disco

func reset() -> void:
	day = 1
	location = &"boteco"
	bank = 0
	register_cash = 0
	levels = {}
	layout = {}
	_commit()


func _commit() -> void:
	changed.emit()
	if _ephemeral:
		return
	var data := {
		"day": day,
		"location": location,
		"bank": bank,
		"register_cash": register_cash,
		"levels": levels,
		"layout": layout,
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("Não deu pra salvar o progresso: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "\t"))


func _load() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary:
		push_warning("Save do bar corrompido; começando do zero.")
		return
	day = maxi(int(parsed.get("day", 1)), 1)
	var loc_id := StringName(str(parsed.get("location", "boteco")))
	location = loc_id if BarLocations.DATA.has(loc_id) else &"boteco"
	bank = maxi(int(parsed.get("bank", 0)), 0)
	register_cash = maxi(int(parsed.get("register_cash", 0)), 0)
	levels = {}
	for k: String in parsed.get("levels", {}):
		var id := StringName(k)
		levels[id] = clampi(int(parsed.levels[k]), 0, max_level(id))
	layout = {}
	for k: String in parsed.get("layout", {}):
		layout[StringName(k)] = StringName(str(parsed.layout[k]))
