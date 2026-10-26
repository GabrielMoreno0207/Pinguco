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
		"vessel": BeverageData.Vessel.BOTTLE, "prep_time": 1.3, "strength": 22.0,
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


func all() -> Array[BeverageData]:
	return _ordered


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for b in _ordered:
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
