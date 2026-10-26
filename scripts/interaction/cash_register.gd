class_name CashRegister
extends Interactable
## Caixa registradora da bancada. No fim do turno a féria cai na gaveta; fora do expediente
## o jogador recolhe o dinheiro e abre o caderninho de investimentos.

signal shop_requested

var visual: Node3D
var _drawer: MeshInstance3D
var _display: Label3D


static func create() -> CashRegister:
	var r := CashRegister.new()
	r.name = "CashRegister"
	r.visual = Node3D.new()
	r.add_child(r.visual)
	Mats.box(r.visual, Vector3(0.36, 0.14, 0.3), Vector3(0, 0.07, 0), Color(0.75, 0.2, 0.18))
	var top := Mats.box(r.visual, Vector3(0.34, 0.12, 0.16), Vector3(0, 0.18, -0.05), Color(0.8, 0.25, 0.2))
	top.rotation_degrees.x = -25
	Mats.box(r.visual, Vector3(0.18, 0.06, 0.02), Vector3(0, 0.27, -0.1), Color(0.15, 0.3, 0.15), false)
	r._drawer = Mats.box(r.visual, Vector3(0.3, 0.05, 0.02), Vector3(0, 0.035, 0.152), Color(0.6, 0.15, 0.13), false)
	Mats.label3d(r.visual, "R$", Vector3(0, 0.095, 0.152), 40, UiTheme.MUSTARD, 6).pixel_size = 0.0015
	r._display = Mats.label3d(r.visual, "", Vector3(0, 0.27, -0.088), 30, Color(0.55, 1.0, 0.55), 0)
	r._display.pixel_size = 0.0011
	r.highlight_root = r.visual
	r.setup_shape(Vector3(0.38, 0.32, 0.32), Vector3(0, 0.15, 0))
	return r


func _ready() -> void:
	BarProgress.changed.connect(_refresh)
	GameManager.stats_changed.connect(func(_s: Dictionary) -> void: _refresh())
	GameManager.state_changed.connect(func(_s: GameManager.State) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	# no turno mostra a féria correndo; fechado, o que sobrou na gaveta
	var value: int = GameManager.stats.get("money", 0) if GameManager.is_playing() else BarProgress.register_cash
	_display.text = "%d,00" % value


func get_prompt(_player: PlayerController) -> String:
	if not GameManager.is_closed():
		return ""
	if BarProgress.register_cash > 0:
		return "Recolher %s da gaveta" % GameManager.format_money(BarProgress.register_cash)
	return "Abrir o caderninho de investimentos"


func get_hint(_player: PlayerController) -> String:
	if GameManager.is_playing():
		return "Caixa: a féria sai no fim do turno"
	return ""


func interact(_player: PlayerController) -> void:
	if BarProgress.register_cash > 0:
		var got := BarProgress.collect_register()
		AudioManager.play_at("coin", global_position)
		GameManager.feedback.emit("+%s pro bolso!" % GameManager.format_money(got), &"good", global_position + Vector3(0, 0.4, 0))
		_drawer.position.z = 0.152
		var tw := create_tween()
		tw.tween_property(_drawer, "position:z", 0.26, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.5)
		tw.tween_property(_drawer, "position:z", 0.152, 0.2)
	else:
		AudioManager.play("ui_click")
		shop_requested.emit()
