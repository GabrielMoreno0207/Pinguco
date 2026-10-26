class_name HUDController
extends CanvasLayer
## Interface do jogo. Escuta sinais do GameManager / ShiftManager / InteractionSystem;
## só os balões e o texto flutuante acompanham a câmera por frame.

signal start_requested
signal restart_requested
signal resume_requested

var _root: Control
var _money: Label
var _served: Label
var _passed: Label
var _score: Label
var _clock: Label
var _time_bar: ProgressBar
var _stars: StarRow
var _crosshair: Crosshair
var _prompt_panel: PanelContainer
var _prompt: Label
var _hint: Label
var _held_panel: PanelContainer
var _held_chip: BeverageChip
var _held_label: Label
var _customer_panel: PanelContainer
var _cust_name: Label
var _cust_type: Label
var _cust_stage: Label
var _cust_last: Label
var _meter: DrunkMeter
var _bubbles: Control
var _toasts: Control
var _banner: PanelContainer
var _banner_title: Label
var _banner_msg: Label
var _menu: Control
var _pause: Control
var _results: Control
var _results_body: VBoxContainer
var _results_reason: Label
var _focused_customer: CustomerController
var _hud_layer: Control
var _cust_cache := ""


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_bubbles = _full_rect_layer()
	_toasts = _full_rect_layer()
	_hud_layer = _full_rect_layer()
	_build_top_bar()
	_build_center()
	_build_held()
	_build_customer_panel()
	_build_banner()
	_build_menu()
	_build_pause()
	_build_results()
	GameManager.stats_changed.connect(_on_stats_changed)
	GameManager.feedback.connect(_on_feedback)
	GameManager.customer_passed_out.connect(_on_passed_out)
	GameManager.reputation_changed.connect(_on_reputation)
	GameManager.state_changed.connect(_on_state_changed)
	_on_stats_changed(GameManager.stats)
	_on_reputation(GameManager.reputation)
	_on_state_changed(GameManager.state)


func _full_rect_layer() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(c)
	return c


# ------------------------------------------------------------------ construção

func _build_top_bar() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_hud_layer.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	# placa de madeira: dinheiro e contadores
	var plaque := PanelContainer.new()
	plaque.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.WOOD, UiTheme.INK, 12, 4))
	row.add_child(plaque)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	plaque.add_child(pv)
	_money = UiTheme.outlined(UiTheme.label("R$ 0,00", 38, UiTheme.MUSTARD), UiTheme.INK, 8)
	pv.add_child(_money)
	var counters := HBoxContainer.new()
	counters.add_theme_constant_override("separation", 16)
	pv.add_child(counters)
	_served = UiTheme.label("Atendidos 0", 18, UiTheme.CREAM, false)
	_passed = UiTheme.label("Capotados 0", 18, UiTheme.CREAM, false)
	counters.add_child(_served)
	counters.add_child(_passed)
	_score = UiTheme.label("Acertos 0 · Erros 0", 16, UiTheme.CREAM.darkened(0.15), false)
	pv.add_child(_score)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	# quadro-negro do relógio
	var board := PanelContainer.new()
	board.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.CHALK, UiTheme.WOOD, 8, 6))
	row.add_child(board)
	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	board.add_child(bv)
	_clock = UiTheme.label("18:00", 40, Color(0.95, 0.95, 0.9))
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_clock)
	_time_bar = ProgressBar.new()
	_time_bar.show_percentage = false
	_time_bar.custom_minimum_size = Vector2(170, 10)
	_time_bar.max_value = 1.0
	_time_bar.value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.MUSTARD
	fill.set_corner_radius_all(5)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.35)
	bg.set_corner_radius_all(5)
	_time_bar.add_theme_stylebox_override("fill", fill)
	_time_bar.add_theme_stylebox_override("background", bg)
	bv.add_child(_time_bar)
	var until := UiTheme.label("fecha às 02:00", 14, Color(0.8, 0.85, 0.8), false)
	until.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(until)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer2)

	var rep := PanelContainer.new()
	rep.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.WOOD, UiTheme.INK, 12, 4))
	row.add_child(rep)
	var rv := VBoxContainer.new()
	rep.add_child(rv)
	rv.add_child(UiTheme.label("Fama do bar", 16, UiTheme.CREAM, false))
	_stars = StarRow.new()
	rv.add_child(_stars)


func _build_center() -> void:
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_hud_layer.add_child(_crosshair)

	_prompt_panel = PanelContainer.new()
	_prompt_panel.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.PAPER, UiTheme.INK, 10, 3))
	_prompt_panel.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_prompt_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	_prompt_panel.add_child(h)
	var key := UiTheme.label("E", 22, UiTheme.PAPER)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.custom_minimum_size = Vector2(34, 34)
	var key_bg := PanelContainer.new()
	var ksb := UiTheme.panel(UiTheme.INK, UiTheme.INK, 8, 0, false)
	ksb.content_margin_left = 4
	ksb.content_margin_right = 4
	ksb.content_margin_top = 0
	ksb.content_margin_bottom = 0
	key_bg.add_theme_stylebox_override("panel", ksb)
	key_bg.add_child(key)
	h.add_child(key_bg)
	_prompt = UiTheme.label("", 24, UiTheme.INK)
	h.add_child(_prompt)
	_prompt_panel.visible = false

	_hint = UiTheme.outlined(UiTheme.label("", 20, UiTheme.CREAM, false), UiTheme.INK, 6)
	_hint.set_anchors_preset(Control.PRESET_CENTER)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_layer.add_child(_hint)


func _build_held() -> void:
	_held_panel = PanelContainer.new()
	_held_panel.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.PAPER, UiTheme.INK, 12, 3))
	_held_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_held_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_held_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud_layer.add_child(_held_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	_held_panel.add_child(h)
	_held_chip = BeverageChip.new()
	_held_chip.custom_minimum_size = Vector2(52, 52)
	h.add_child(_held_chip)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	h.add_child(v)
	v.add_child(UiTheme.label("Na mão", 15, Color(0.45, 0.3, 0.22), false))
	_held_label = UiTheme.label("", 24, UiTheme.INK)
	v.add_child(_held_label)
	var help := UiTheme.label("Q: descartar", 13, Color(0.5, 0.4, 0.35), false)
	v.add_child(help)
	_held_panel.visible = false


func _build_customer_panel() -> void:
	_customer_panel = PanelContainer.new()
	_customer_panel.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.PAPER, UiTheme.INK, 12, 3))
	_customer_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_customer_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud_layer.add_child(_customer_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_customer_panel.add_child(v)
	_cust_name = UiTheme.label("", 26, UiTheme.INK)
	v.add_child(_cust_name)
	_cust_type = UiTheme.label("", 15, Color(0.45, 0.3, 0.22), false)
	v.add_child(_cust_type)
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 8)
	v.add_child(mrow)
	mrow.add_child(UiTheme.label("Bafômetro", 15, UiTheme.INK, false))
	_meter = DrunkMeter.new()
	_meter.custom_minimum_size = Vector2(200, 22)
	mrow.add_child(_meter)
	_cust_stage = UiTheme.label("", 20, UiTheme.INK)
	v.add_child(_cust_stage)
	_cust_last = UiTheme.label("", 15, Color(0.45, 0.3, 0.22), false)
	v.add_child(_cust_last)
	_customer_panel.visible = false


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.MUSTARD, UiTheme.INK, 18, 5))
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hud_layer.add_child(_banner)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.add_child(v)
	_banner_title = UiTheme.outlined(UiTheme.label("CAPOTOU!", 54, UiTheme.RED), UiTheme.INK, 10)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_banner_title)
	_banner_msg = UiTheme.label("", 24, UiTheme.INK, false)
	_banner_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_banner_msg)
	_banner.visible = false


func _screen_base(bg_alpha := 0.72) -> Control:
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(screen)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.04, 0.03, bg_alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(dim)
	return screen


func _center_card(screen: Control, min_w := 640.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var card := PanelContainer.new()
	var sb := UiTheme.panel(UiTheme.CREAM, UiTheme.INK, 22, 6)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	sb.shadow_offset = Vector2(10, 12)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size.x = min_w
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)
	return v


func _build_menu() -> void:
	_menu = _screen_base(0.45)
	var v := _center_card(_menu, 760)
	var title := UiTheme.outlined(UiTheme.label("PINGUÇO", 110, UiTheme.MUSTARD), UiTheme.INK, 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var tag := UiTheme.label("Encha o copo. Esvazie o juízo.", 26, UiTheme.RED)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	var how := UiTheme.label(
		"Você é dono do Bar do Pinguço. Sirva cada freguês até ele capotar no balcão!\n\n" +
		"1. Pegue um COPO e apoie numa área de PREPARO.\n" +
		"2. Pegue a garrafa certa e SEGURE E sobre o copo para servir.\n" +
		"3. Pegue o copo pronto e entregue (E) ao freguês certo.\n\n" +
		"Quanto mais bêbado, mais enrolado o pedido: confie na COR, na LETRA, no SÍMBOLO\n" +
		"e no contexto (\"mais uma daquela!\"). O cardápio fica na parede atrás de você.",
		19, UiTheme.INK, false)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size.x = 680
	v.add_child(how)
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 14)
	v.add_child(chips)
	for bev in BeverageDatabase.all():
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		var chip := BeverageChip.new()
		chip.custom_minimum_size = Vector2(58, 58)
		chip.setup(bev)
		col.add_child(chip)
		var n := UiTheme.label(bev.display_name, 14, UiTheme.INK, false)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(n)
		chips.add_child(col)
	var controls := UiTheme.label("WASD andar · Mouse olhar · E interagir (segure para servir) · Q descartar · Shift correr · Esc pausar", 15, Color(0.4, 0.3, 0.25), false)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(controls)
	var btn := UiTheme.button("ABRIR O BAR")
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func() -> void:
		AudioManager.play("ui_click")
		start_requested.emit())
	v.add_child(btn)
	_menu.set_meta("focus", btn)


func _build_pause() -> void:
	_pause = _screen_base()
	var v := _center_card(_pause, 480)
	var t := UiTheme.label("PAUSA PRO CAFEZINHO", 44, UiTheme.INK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var resume := UiTheme.button("VOLTAR AO BALCÃO")
	resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume.pressed.connect(func() -> void: resume_requested.emit())
	v.add_child(resume)
	var restart := UiTheme.button("RECOMEÇAR TURNO")
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.pressed.connect(func() -> void: restart_requested.emit())
	v.add_child(restart)
	var quit := UiTheme.button("FECHAR O BAR (SAIR)")
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(func() -> void: get_tree().quit())
	v.add_child(quit)
	_pause.set_meta("focus", resume)
	_pause.visible = false


func _build_results() -> void:
	_results = _screen_base(0.6)
	var v := _center_card(_results, 620)
	var t := UiTheme.outlined(UiTheme.label("FIM DO TURNO", 64, UiTheme.MUSTARD), UiTheme.INK, 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_results_reason = UiTheme.label("", 20, UiTheme.RED, false)
	_results_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_results_reason)
	_results_body = VBoxContainer.new()
	_results_body.add_theme_constant_override("separation", 4)
	v.add_child(_results_body)
	var again := UiTheme.button("ABRIR DE NOVO")
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(func() -> void: restart_requested.emit())
	v.add_child(again)
	_results.set_meta("focus", again)
	_results.visible = false


# ------------------------------------------------------------------ API pública

func connect_player(player: PlayerController) -> void:
	player.interaction.focus_changed.connect(_on_focus_changed)
	player.interaction.progress_changed.connect(_crosshair.set_progress)
	player.held_changed.connect(_on_held_changed)


func connect_shift(shift: ShiftManager) -> void:
	shift.tick.connect(_on_tick.bind(shift))


func add_customer_bubble(c: CustomerController) -> void:
	_bubbles.add_child(SpeechBubble.new(c))


func show_results(reason: String) -> void:
	_results_reason.text = reason
	for c in _results_body.get_children():
		c.queue_free()
	var s := GameManager.stats
	var rows := [
		["Dinheiro no caixa", GameManager.format_money(s.money)],
		["Pedidos certos", str(s.correct)],
		["Erros", str(s.wrong)],
		["Atrasos", str(s.late)],
		["Fregueses atendidos", str(s.served_customers)],
		["Fregueses que capotaram", str(s.passed_out)],
		["Foram embora bravos", str(s.angry_left)],
		["Maior combo", "x%d" % s.best_combo],
	]
	for r in rows:
		var h := HBoxContainer.new()
		var k := UiTheme.label(r[0], 24, UiTheme.INK, false)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(k)
		h.add_child(UiTheme.label(r[1], 26, UiTheme.INK))
		_results_body.add_child(h)
	var title := _rank_title(s)
	var rank := UiTheme.outlined(UiTheme.label(title, 30, UiTheme.MUSTARD), UiTheme.INK, 8)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_body.add_child(rank)


func _rank_title(s: Dictionary) -> String:
	if s.passed_out >= 8:
		return "Lenda do Boteco"
	if s.passed_out >= 5:
		return "Rei do Balcão"
	if s.passed_out >= 2:
		return "Botequeiro de Respeito"
	if s.correct >= 3:
		return "Aprendiz de Garçom"
	return "Estagiário do Copo Sujo"


# ------------------------------------------------------------------ eventos

func _on_state_changed(state: GameManager.State) -> void:
	_menu.visible = state == GameManager.State.MENU
	_pause.visible = state == GameManager.State.PAUSED
	_results.visible = state == GameManager.State.RESULTS
	_hud_layer.visible = state == GameManager.State.PLAYING or state == GameManager.State.PAUSED
	_bubbles.visible = state != GameManager.State.MENU
	for screen in [_menu, _pause, _results]:
		if screen.visible and screen.has_meta("focus"):
			(screen.get_meta("focus") as Control).call_deferred("grab_focus")


func _on_stats_changed(s: Dictionary) -> void:
	_money.text = GameManager.format_money(s.money)
	_served.text = "Atendidos %d" % s.served_customers
	_passed.text = "Capotados %d" % s.passed_out
	_score.text = "Acertos %d · Erros %d · Atrasos %d" % [s.correct, s.wrong, s.late]
	_pulse(_money)


func _on_reputation(value: int) -> void:
	_stars.set_value(value)
	_pulse(_stars)


func _on_tick(seconds_left: float, clock: String, shift: ShiftManager) -> void:
	_clock.text = clock
	_time_bar.value = seconds_left / shift.duration
	var urgent := seconds_left < 30.0
	if urgent != _clock.has_meta("urgent"):
		if urgent:
			_clock.set_meta("urgent", true)
		else:
			_clock.remove_meta("urgent")
		_clock.add_theme_color_override("font_color", UiTheme.RED.lightened(0.3) if urgent else Color(0.95, 0.95, 0.9))


func _on_focus_changed(target: Interactable, prompt: String, hint: String) -> void:
	_prompt_panel.visible = prompt != ""
	_prompt.text = prompt
	_hint.text = hint
	_hint.visible = hint != ""
	_place_center(_prompt_panel, 120.0)
	_place_center(_hint, 120.0 if prompt == "" else 178.0)
	_crosshair.active = prompt != ""
	if target is CustomerHitbox:
		_focused_customer = (target as CustomerHitbox).customer
	else:
		_focused_customer = null


func _on_held_changed(item: HeldItem) -> void:
	_held_panel.visible = not item.is_empty()
	if item.is_empty():
		return
	_held_label.text = item.describe()
	_held_chip.visible = item.beverage != null
	if item.beverage:
		_held_chip.setup(item.beverage, {"color": true, "letter": true, "symbol": true})
	_held_panel.reset_size()
	_held_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_pulse(_held_panel)


func _on_feedback(text: String, kind: StringName, world_pos: Vector3) -> void:
	var color := UiTheme.GREEN
	match kind:
		&"bad":
			color = UiTheme.RED
		&"late":
			color = Color(1.0, 0.55, 0.1)
	var l := UiTheme.outlined(UiTheme.label(text, 34, color), UiTheme.INK, 10)
	_toasts.add_child(l)
	var cam := get_viewport().get_camera_3d()
	var pos := get_viewport().get_visible_rect().size / 2.0 + Vector2(0, -90)
	if cam and not cam.is_position_behind(world_pos):
		pos = cam.unproject_position(world_pos) + Vector2(0, -150)
	l.reset_size()
	l.position = pos - l.size / 2.0
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(0.4, 0.4)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 60, 1.0)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.tween_callback(l.queue_free)


func _on_passed_out(customer_name: String, message: String) -> void:
	_banner_title.text = ["CAPOTOU!", "APAGOU!", "JÁ ERA!", "BOA NOITE!"][randi() % 4]
	_banner_msg.text = message
	_banner.visible = true
	_place_center(_banner, 0.0)
	_banner.anchor_top = 0.0
	_banner.anchor_bottom = 0.0
	_banner.offset_top = 150.0
	_banner.offset_bottom = 150.0 + _banner.size.y
	_banner.pivot_offset = _banner.size / 2.0
	_banner.scale = Vector2(0.2, 0.2)
	_banner.modulate.a = 1.0
	var tw := _banner.create_tween()
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.4)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: _banner.visible = false)
	AudioManager.play("coin", 0.8)


func _place_center(c: Control, y: float) -> void:
	c.reset_size()
	var sz := c.get_combined_minimum_size()
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = -sz.x / 2.0
	c.offset_right = sz.x / 2.0
	c.offset_top = y
	c.offset_bottom = y + sz.y


func _pulse(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.12, 1.12), 0.08)
	tw.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	# painel do freguês em foco (bafômetro) — só reconstrói quando algo muda
	var c := _focused_customer
	if not (c and is_instance_valid(c) and GameManager.is_playing()):
		if _customer_panel.visible:
			_customer_panel.visible = false
			_cust_cache = ""
		return
	var st := c.stage()
	_meter.set_value(c.drunk_fraction(), st)
	var asleep := c.state == CustomerController.State.ASLEEP
	var key := "%s|%d|%s|%s|%d" % [c.nickname, st, asleep, c.last_beverage, c.strikes]
	if key == _cust_cache:
		return
	_cust_cache = key
	_customer_panel.visible = true
	_cust_name.text = c.nickname
	_cust_type.text = "%s — %s" % [c.profile.archetype, c.profile.personality]
	_cust_stage.text = DrunkennessSystem.STAGE_NAMES[st] + ("  (dormindo)" if asleep else "")
	_cust_stage.add_theme_color_override("font_color", DrunkennessSystem.STAGE_COLORS[st].darkened(0.25))
	var last := BeverageDatabase.get_beverage(c.last_beverage) if c.last_beverage != &"" else null
	_cust_last.text = "Última: %s  ·  Vacilos: %d/%d" % [last.display_name if last else "nada ainda", c.strikes, c.profile.max_strikes]
	_customer_panel.reset_size()
	_customer_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)
