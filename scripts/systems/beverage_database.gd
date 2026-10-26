extends Node
## BeverageDatabase (autoload): registro central de bebidas.
## Para adicionar uma bebida: acrescente um dicionário em CATALOG, ou salve um
## BeverageData como .tres em res://data/beverages/ — ele é carregado automaticamente.

const EXTRA_DIR := "res://data/beverages"

const CATALOG := [
	{
		"id": &"cerveja", "display_name": "Cerveja", "letter": "C", "symbol": &"star",
		"color": Color(1.0, 0.78, 0.16), "bottle_color": Color(0.55, 0.3, 0.08),
		"vessel": BeverageData.Vessel.LONGNECK, "prep_time": 1.0, "strength": 16.0,
		"price": 8, "article": "uma", "station": &"fridge", "prep_verb": "Tirando o colarinho",
		"slang": ["breja", "loira gelada", "gelada", "cerva", "loirinha"],
	},
	{
		"id": &"pinga", "display_name": "Pinga", "letter": "P", "symbol": &"diamond",
		"color": Color(0.86, 0.95, 1.0), "bottle_color": Color(0.72, 0.9, 0.82),
		"vessel": BeverageData.Vessel.BOTTLE, "prep_time": 0.7, "strength": 30.0,
		"price": 6, "article": "uma", "station": &"shelf", "prep_verb": "Servindo a dose",
		"slang": ["branquinha", "marvada", "cana", "caninha", "danada"],
	},
	{
		"id": &"vinho", "display_name": "Vinho", "letter": "V", "symbol": &"circle",
		"color": Color(0.72, 0.06, 0.16), "bottle_color": Color(0.35, 0.05, 0.12),
		"vessel": BeverageData.Vessel.WINE, "prep_time": 1.3, "strength": 22.0,
		"price": 12, "article": "um", "station": &"shelf", "prep_verb": "Servindo o vinho",
		"slang": ["vinhão", "tintão", "vinho de garrafão", "suco de uva adulto"],
	},
	{
		"id": &"caipirinha", "display_name": "Caipirinha", "letter": "K", "symbol": &"lemon",
		"color": Color(0.45, 0.85, 0.2), "bottle_color": Color(0.3, 0.7, 0.2),
		"vessel": BeverageData.Vessel.JAR, "prep_time": 2.4, "strength": 26.0,
		"price": 14, "article": "uma", "station": &"counter", "prep_verb": "Amassando o limão",
		"slang": ["caipira", "limãozinho", "caipa", "aquela de limão"],
	},
	{
		"id": &"batida", "display_name": "Batida", "letter": "B", "symbol": &"heart",
		"color": Color(1.0, 0.45, 0.7), "bottle_color": Color(0.95, 0.4, 0.62),
		"vessel": BeverageData.Vessel.JAR, "prep_time": 1.9, "strength": 20.0,
		"price": 12, "article": "uma", "station": &"counter", "prep_verb": "Batendo a batida",
		"slang": ["batidinha", "a rosinha", "batida de morango", "docinha"],
	},
	{
		"id": &"refrigerante", "display_name": "Refrigerante", "letter": "R", "symbol": &"bolt",
		"color": Color(0.3, 0.15, 0.07), "bottle_color": Color(0.85, 0.1, 0.1),
		"vessel": BeverageData.Vessel.CAN, "prep_time": 0.6, "strength": -6.0,
		"price": 5, "article": "um", "station": &"fridge", "prep_verb": "Abrindo a lata",
		"slang": ["refri", "um refri pra rebater", "guaraná", "coquinha"],
	},
	{
		"id": &"quentao", "display_name": "Quentão", "letter": "Q", "symbol": &"flame",
		"color": Color(0.92, 0.38, 0.12), "bottle_color": Color(0.55, 0.55, 0.58),
		"vessel": BeverageData.Vessel.POT, "prep_time": 1.6, "strength": 18.0,
		"price": 10, "article": "um", "station": &"counter", "prep_verb": "Servindo da panela",
		"slang": ["quentinho", "aquele de gengibre", "esquenta-peito", "quentãozinho"],
	},
	{
		"id": &"whisky", "display_name": "Whisky", "letter": "W", "symbol": &"crown",
		"color": Color(0.66, 0.4, 0.13), "bottle_color": Color(0.82, 0.62, 0.3),
		"vessel": BeverageData.Vessel.SQUARE, "prep_time": 1.1, "strength": 28.0,
		"price": 18, "article": "um", "station": &"shelf", "prep_verb": "Servindo com gelo",
		"slang": ["uísque", "uisquinho", "o importado", "o de rico", "doze anos"],
	},
	{
		"id": &"tequila", "display_name": "Tequila", "letter": "T", "symbol": &"sun",
		"color": Color(0.97, 0.93, 0.5), "bottle_color": Color(0.9, 0.95, 0.85),
		"vessel": BeverageData.Vessel.BOTTLE, "prep_time": 0.8, "strength": 32.0,
		"price": 14, "article": "uma", "station": &"shelf", "prep_verb": "Servindo a dose com sal",
		"slang": ["tequilinha", "a mexicana", "a do limão e sal", "arriba"],
	},
	{
		"id": &"gin", "display_name": "Gin Tônica", "letter": "G", "symbol": &"moon",
		"color": Color(0.55, 0.88, 0.95), "bottle_color": Color(0.45, 0.7, 0.9),
		"vessel": BeverageData.Vessel.SQUARE, "prep_time": 1.8, "strength": 22.0,
		"price": 16, "article": "um", "station": &"counter", "prep_verb": "Montando o gin",
		"slang": ["gin", "gim", "aquele chique", "o tônica", "o de pepino"],
	},
	{
		"id": &"jurubeba", "display_name": "Jurubeba", "letter": "J", "symbol": &"leaf",
		"color": Color(0.5, 0.2, 0.55), "bottle_color": Color(0.25, 0.12, 0.08),
		"vessel": BeverageData.Vessel.BOTTLE, "prep_time": 0.9, "strength": 25.0,
		"price": 7, "article": "uma", "station": &"shelf", "prep_verb": "Servindo a jurubeba",
		"slang": ["jurú", "a Leão do Norte", "o remédio", "a amarguinha"],
	},
	{
		"id": &"agua", "display_name": "Água", "letter": "A", "symbol": &"drop",
		"color": Color(0.3, 0.58, 1.0), "bottle_color": Color(0.55, 0.78, 1.0),
		"vessel": BeverageData.Vessel.LONGNECK, "prep_time": 0.5, "strength": -10.0,
		"price": 3, "article": "uma", "station": &"fridge", "prep_verb": "Enchendo de água",
		"slang": ["aguinha", "uma água pra rebater", "água de torneira", "H2O"],
	},
	# ---------------------------------------------------------------- salgados (estufa)
	# Matam a fome e cortam o barato: o freguês fica MAIS sóbrio.
	{
		"id": &"coxinha", "display_name": "Coxinha", "letter": "X", "symbol": &"coxinha",
		"category": BeverageData.Category.FOOD,
		"color": Color(0.88, 0.52, 0.16), "bottle_color": Color(0.88, 0.52, 0.16),
		"vessel": BeverageData.Vessel.PLATE, "prep_time": 0.0, "strength": -22.0,
		"price": 7, "article": "uma", "station": &"snack", "prep_verb": "Pegando a coxinha",
		"slang": ["coxa", "coxinhazinha", "a de frango", "um negócio pra forrar"],
	},
	{
		"id": &"pastel", "display_name": "Pastel", "letter": "L", "symbol": &"pastel",
		"category": BeverageData.Category.FOOD,
		"color": Color(0.98, 0.8, 0.38), "bottle_color": Color(0.98, 0.8, 0.38),
		"vessel": BeverageData.Vessel.PLATE, "prep_time": 0.0, "strength": -18.0,
		"price": 6, "article": "um", "station": &"snack", "prep_verb": "Pegando o pastel",
		"slang": ["pastelzinho", "o de queijo", "pastel de vento", "um treco pra comer"],
	},
]

var _by_id: Dictionary = {}
var _ordered: Array[BeverageData] = []


func _ready() -> void:
	for entry: Dictionary in CATALOG:
		register(_from_dict(entry))
	_load_extra_resources()


func register(bev: BeverageData) -> void:
	if bev.id == &"" or _by_id.has(bev.id):
		push_warning("BeverageDatabase: id inválido ou duplicado: %s" % bev.id)
		return
	_by_id[bev.id] = bev
	_ordered.append(bev)


func get_beverage(id: StringName) -> BeverageData:
	return _by_id.get(id)


func has_beverage(id: StringName) -> bool:
	return _by_id.has(id)


## Tudo do cardápio (bebidas + salgados).
func all() -> Array[BeverageData]:
	return _ordered


func drinks() -> Array[BeverageData]:
	return _of_category(false)


func foods() -> Array[BeverageData]:
	return _of_category(true)


func _of_category(food: bool) -> Array[BeverageData]:
	var out: Array[BeverageData] = []
	for b in _ordered:
		if b.is_food() == food:
			out.append(b)
	return out


## Ids de bebidas (salgados ficam de fora: são pedidos por fome, não por gosto).
func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for b in drinks():
		out.append(b.id)
	return out


func food_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for b in foods():
		out.append(b.id)
	return out


func _from_dict(d: Dictionary) -> BeverageData:
	var b := BeverageData.new()
	for key: String in d:
		if key == "slang":
			b.slang = PackedStringArray(d[key])
		else:
			b.set(key, d[key])
	return b


func _load_extra_resources() -> void:
	if not DirAccess.dir_exists_absolute(EXTRA_DIR):
		return
	for file in DirAccess.get_files_at(EXTRA_DIR):
		if file.ends_with(".tres") or file.ends_with(".res"):
			var res := load(EXTRA_DIR.path_join(file))
			if res is BeverageData:
				register(res)
