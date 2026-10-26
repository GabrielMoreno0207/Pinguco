extends Node
## Settings (autoload): opções do jogador — volumes, sensibilidade do mouse e tela cheia.
## Salvas em user://settings.cfg. Carrega depois do AudioManager (que cria os buses).

signal changed

const PATH := "user://settings.cfg"
## Volume base de cada bus (o AudioManager mixa assim); o slider soma em cima disso.
const BUS_BASE_DB := {"Music": -10.0, "Ambience": -8.0, "Voice": -3.0, "SFX": 0.0}

var master := 0.8
var music := 0.8
var effects := 0.9
## Multiplicador da sensibilidade padrão do PlayerController.
var mouse := 1.0
var fullscreen := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var testing := args.has("--autotest") or args.has("--bench") or args.has("--gallery")
	var cfg := ConfigFile.new()
	if not testing and cfg.load(PATH) == OK:
		master = clampf(cfg.get_value("audio", "master", master), 0.0, 1.0)
		music = clampf(cfg.get_value("audio", "music", music), 0.0, 1.0)
		effects = clampf(cfg.get_value("audio", "effects", effects), 0.0, 1.0)
		mouse = clampf(cfg.get_value("input", "mouse", mouse), 0.2, 3.0)
		fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	apply()


func apply() -> void:
	_set_bus("Master", 0.0, master)
	_set_bus("Music", BUS_BASE_DB.Music, music)
	for bus: String in ["Ambience", "Voice", "SFX"]:
		_set_bus(bus, BUS_BASE_DB[bus], effects)
	if not OS.get_cmdline_user_args().has("--autotest"):
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode and DisplayServer.get_name() != "headless":
			DisplayServer.window_set_mode(mode)
	changed.emit()


func save() -> void:
	apply()
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "effects", effects)
	cfg.set_value("input", "mouse", mouse)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(PATH)


func _set_bus(bus: String, base_db: float, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, base_db + linear_to_db(maxf(linear, 0.001)))
