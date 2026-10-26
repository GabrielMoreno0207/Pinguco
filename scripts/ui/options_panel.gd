class_name OptionsPanel
extends VBoxContainer
## Opções do jogo (volumes, sensibilidade, tela cheia). Usado no menu principal e na pausa.
## Mexer num controle já aplica; VOLTAR grava em disco.

signal closed

var _first: Control


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var t := UiTheme.label("OPÇÕES", 52, UiTheme.INK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(t)
	_first = _slider("Volume geral", Settings.master, 0.0, 1.0, func(v: float) -> void: Settings.master = v)
	_slider("Música", Settings.music, 0.0, 1.0, func(v: float) -> void: Settings.music = v)
	_slider("Efeitos e vozes", Settings.effects, 0.0, 1.0, func(v: float) -> void: Settings.effects = v)
	_slider("Sensibilidade do mouse", Settings.mouse, 0.2, 3.0, func(v: float) -> void: Settings.mouse = v)
	var fs := CheckButton.new()
	fs.text = "Tela cheia"
	fs.button_pressed = Settings.fullscreen
	fs.add_theme_font_override("font", UiTheme.title_font())
	fs.add_theme_font_size_override("font_size", 24)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		fs.add_theme_color_override(c, UiTheme.INK)
	fs.toggled.connect(func(on: bool) -> void:
		Settings.fullscreen = on
		Settings.apply())
	add_child(fs)
	var back := UiTheme.button("VOLTAR")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		AudioManager.play("ui_click")
		Settings.save()
		closed.emit())
	add_child(back)


func focus_first() -> void:
	if _first:
		_first.grab_focus()


func _slider(text: String, value: float, lo: float, hi: float, setter: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	var l := UiTheme.label(text, 24, UiTheme.INK)
	l.custom_minimum_size.x = 300
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(300, 32)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = UiTheme.WOOD.lightened(0.3)
	track.set_corner_radius_all(6)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = UiTheme.MUSTARD
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	row.add_child(s)
	var pct := UiTheme.label("", 20, UiTheme.INK, false)
	pct.custom_minimum_size.x = 64
	row.add_child(pct)
	var show := func(v: float) -> void:
		pct.text = "%d%%" % roundi(v * 100.0) if hi <= 1.0 else "%.1fx" % v
	show.call(value)
	s.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		show.call(v)
		Settings.apply())
	return s
