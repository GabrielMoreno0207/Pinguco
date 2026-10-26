class_name MainMenu
extends Control
## Tela de abertura + menu principal. O bar 3D fica ao fundo, com a câmera passeando
## (controlada pelo main.gd). Páginas: abertura → menu → como jogar / opções / novo jogo.

signal start_requested
signal arrange_requested
signal new_game_requested

## A abertura só aparece quando o jogo é aberto, não a cada volta pro menu.
static var _splash_done := false

var _splash: Control
var _splash_logo: Label
var _splash_press: Label
var _main: Control
var _howto: Control
var _options: Control
var _options_panel: OptionsPanel
var _confirm: Control
var _info: Label
var _start_btn: Button
var _arrange_btn: Button
var _new_btn: Button
var _page := &"main"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_main()
	_build_howto()
	_build_options()
	_build_confirm()
	_build_splash()
	if GameManager.has_meta("autotest"):
		_splash_done = true
	show_page(&"main" if _splash_done else &"splash")
	visibility_changed.connect(func() -> void:
		if visible and _page == &"main":
			refresh()
			_start_btn.call_deferred("grab_focus")
		elif not visible and _splash_done:
			show_page(&"main"))


func show_page(page: StringName) -> void:
	_page = page
	_splash.visible = page == &"splash"
	_main.visible = page == &"main"
	_howto.visible = page == &"howto"
	_options.visible = page == &"options"
	_confirm.visible = page == &"confirm"
	match page:
		&"splash":
			_play_splash()
		&"main":
			refresh()
			_start_btn.call_deferred("grab_focus")
		&"options":
			_options_panel.call_deferred("focus_first")
		_:
			var focus: Control = (_howto if page == &"howto" else _confirm).get_meta("focus")
			focus.call_deferred("grab_focus")


func refresh() -> void:
	var loc := BarProgress.loc()
	var started := BarProgress.has_progress()
	_info.text = "%s · %s\nDia %d · Saldo %s" % [loc.name, loc.place, BarProgress.day, GameManager.format_money(BarProgress.bank)]
	if BarProgress.register_cash > 0:
		_info.text += " · %s na gaveta" % GameManager.format_money(BarProgress.register_cash)
	_info.visible = started
	_start_btn.text = "CONTINUAR · DIA %d" % BarProgress.day if started else "ABRIR O BAR"
	_new_btn.visible = started


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _page == &"splash":
		var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventJoypadButton and event.pressed)
		if pressed:
			get_viewport().set_input_as_handled()
			_finish_splash()
	elif _page != &"main" and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		AudioManager.play("ui_click")
		show_page(&"main")


# ------------------------------------------------------------------ abertura

func _build_splash() -> void:
	_splash = Control.new()
	_splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_splash)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.035, 0.025, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_splash.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_splash.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	var pre := UiTheme.label("UM JOGO DE BUTECO", 24, UiTheme.CREAM.darkened(0.2))
	pre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pre)
	_splash_logo = UiTheme.outlined(UiTheme.label("PINGUÇO", 190, UiTheme.MUSTARD), UiTheme.INK, 26)
	_splash_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_splash_logo)
	var tag := UiTheme.outlined(UiTheme.label("Encha o copo. Esvazie o juízo.", 34, UiTheme.RED.lightened(0.15)), UiTheme.INK, 8)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size.y = 70
	v.add_child(gap)
	_splash_press = UiTheme.label("APERTE QUALQUER TECLA", 28, UiTheme.CREAM)
	_splash_press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_splash_press)
	_splash.set_meta("parts", [pre, tag, _splash_press])


func _play_splash() -> void:
	_splash.modulate.a = 1.0
	for part: Control in _splash.get_meta("parts"):
		part.modulate.a = 0.0
	_splash_logo.modulate.a = 0.0
	await get_tree().process_frame
	_splash_logo.pivot_offset = _splash_logo.size / 2.0
	_splash_logo.scale = Vector2(0.3, 0.3)
	_splash_logo.rotation = -0.12
	var parts: Array = _splash.get_meta("parts")
	var tw := create_tween()
	tw.tween_property(parts[0], "modulate:a", 1.0, 0.5)
	tw.tween_property(_splash_logo, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(_splash_logo, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_splash_logo, "rotation", 0.0, 0.9).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: AudioManager.play("coin", 0.8))
	tw.tween_property(parts[1], "modulate:a", 1.0, 0.4)
	tw.tween_property(parts[2], "modulate:a", 1.0, 0.3)
	# "aperte qualquer tecla" piscando e o logo balançando de leve, como bêbado
	var blink := _splash_press.create_tween().set_loops()
	blink.tween_interval(2.3)
	blink.tween_property(_splash_press, "modulate:a", 0.25, 0.6)
	blink.tween_property(_splash_press, "modulate:a", 1.0, 0.6)
	var sway := _splash_logo.create_tween().set_loops()
	sway.tween_interval(1.0)
	sway.tween_property(_splash_logo, "rotation", 0.035, 1.4).set_trans(Tween.TRANS_SINE)
	sway.tween_property(_splash_logo, "rotation", -0.035, 1.4).set_trans(Tween.TRANS_SINE)


func _finish_splash() -> void:
	if _splash_done:
		return
	_splash_done = true
	AudioManager.play("ui_click")
	var tw := create_tween()
	tw.tween_property(_splash, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void: show_page(&"main"))


# ------------------------------------------------------------------ menu principal

func _build_main() -> void:
	_main = Control.new()
	_main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_main)
	# escurece o lado esquerdo para o texto ler bem com o bar ao fundo
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.07, 0.035, 0.025, 0.9))
	grad.set_color(1, Color(0.07, 0.035, 0.025, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.25, 0)
	gt.fill_to = Vector2(0.75, 0)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 50)
	_main.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(v)
	var title := UiTheme.outlined(UiTheme.label("PINGUÇO", 128, UiTheme.MUSTARD), UiTheme.INK, 20)
	v.add_child(title)
	var tag := UiTheme.outlined(UiTheme.label("Encha o copo. Esvazie o juízo.", 28, UiTheme.RED.lightened(0.15)), UiTheme.INK, 8)
	v.add_child(tag)
	_info = UiTheme.outlined(UiTheme.label("", 22, UiTheme.CREAM, false), UiTheme.INK, 6)
	v.add_child(_info)
	var gap := Control.new()
	gap.custom_minimum_size.y = 16
	v.add_child(gap)
	_start_btn = _menu_button(v, "ABRIR O BAR", func() -> void: start_requested.emit())
	_arrange_btn = _menu_button(v, "BAR FECHADO", func() -> void: arrange_requested.emit())
	_arrange_btn.tooltip_text = "Entra sem abrir o turno: recolha o caixa, invista e arrume as garrafas."
	_menu_button(v, "COMO JOGAR", func() -> void: show_page(&"howto"))
	_menu_button(v, "OPÇÕES", func() -> void: show_page(&"options"))
	_new_btn = _menu_button(v, "NOVO JOGO", func() -> void: show_page(&"confirm"))
	_menu_button(v, "SAIR", func() -> void: get_tree().quit())
	var foot := UiTheme.label("protótipo · feito em Godot 4.7 · tudo procedural", 14, UiTheme.CREAM.darkened(0.35), false)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	foot.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	foot.position -= Vector2(24, 16)
	_main.add_child(foot)


func _menu_button(parent: Control, text: String, action: Callable) -> Button:
	var b := UiTheme.button(text, 28)
	b.custom_minimum_size = Vector2(380, 58)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void:
		AudioManager.play("ui_click")
		action.call())
	# empurrãozinho ao passar o mouse/foco
	var nudge := func(on: bool) -> void:
		b.create_tween().tween_property(b, "position:x", 14.0 if on else 0.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.mouse_entered.connect(nudge.bind(true))
	b.mouse_exited.connect(nudge.bind(false))
	b.focus_entered.connect(nudge.bind(true))
	b.focus_exited.connect(nudge.bind(false))
	parent.add_child(b)
	return b


# ------------------------------------------------------------------ páginas

func _card_page(min_w: float) -> Array:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.04, 0.03, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(center)
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
	card.add_child(v)
	return [page, v]


func _back_button(parent: Control) -> Button:
	var back := UiTheme.button("VOLTAR")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		AudioManager.play("ui_click")
		show_page(&"main"))
	parent.add_child(back)
	return back


func _build_howto() -> void:
	var parts := _card_page(800)
	_howto = parts[0]
	var v: VBoxContainer = parts[1]
	var t := UiTheme.label("COMO JOGAR", 52, UiTheme.INK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var how := UiTheme.label(
		"Você é dono do bar. Sirva cada freguês até ele capotar no balcão!\n\n" +
		"1. Pegue um COPO e apoie numa área de PREPARO.\n" +
		"2. Pegue a garrafa certa e SEGURE E sobre o copo para servir.\n" +
		"3. Pegue o copo pronto e entregue (E) ao freguês certo.\n\n" +
		"Quanto mais bêbado, mais enrolado o pedido: confie na COR, na LETRA, no SÍMBOLO e no " +
		"contexto (\"mais uma daquela!\"). O cardápio fica na parede atrás de você.\n\n" +
		"De olho no BAFÔMETRO: bebendo, o freguês fica com FOME e pede salgado da estufa. " +
		"Atender corta o porre; recusar deixa ele bravo. Água e refri também rebatem.\n\n" +
		"No fim do turno a féria fica na CAIXA REGISTRADORA. Com o bar fechado, recolha e abra o " +
		"caderninho: melhore o atendimento, REFORME o bar (pintura, piso, luz, TV, decoração, mobília) " +
		"e, depois de alguns dias, MUDE DE PONTO para um bar novo e mais chique. Dá também para " +
		"arrumar as garrafas onde quiser.",
		19, UiTheme.INK, false)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size.x = 720
	v.add_child(how)
	var chips_center := CenterContainer.new()
	v.add_child(chips_center)
	var chips := GridContainer.new()
	chips.columns = 7
	chips.add_theme_constant_override("h_separation", 14)
	chips.add_theme_constant_override("v_separation", 6)
	chips_center.add_child(chips)
	for bev in BeverageDatabase.all():
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		var chip := BeverageChip.new()
		chip.custom_minimum_size = Vector2(50, 50)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		chip.setup(bev)
		col.add_child(chip)
		var n := UiTheme.label(bev.display_name, 13, UiTheme.INK if not bev.is_food() else UiTheme.RED, false)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(n)
		chips.add_child(col)
	var controls := UiTheme.label("WASD andar · Mouse olhar · E interagir (segure para servir) · Q descartar · Shift correr · Esc pausar", 15, Color(0.4, 0.3, 0.25), false)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(controls)
	_howto.set_meta("focus", _back_button(v))


func _build_options() -> void:
	var parts := _card_page(760)
	_options = parts[0]
	_options_panel = OptionsPanel.new()
	_options_panel.closed.connect(func() -> void: show_page(&"main"))
	(parts[1] as VBoxContainer).add_child(_options_panel)


func _build_confirm() -> void:
	var parts := _card_page(620)
	_confirm = parts[0]
	var v: VBoxContainer = parts[1]
	var t := UiTheme.label("COMEÇAR DO ZERO?", 46, UiTheme.RED)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var msg := UiTheme.label("O bar volta pra Vila Esperança e todo o progresso é apagado: dias, dinheiro, reformas e arrumação.", 20, UiTheme.INK, false)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.custom_minimum_size.x = 540
	v.add_child(msg)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	var cancel := UiTheme.button("CANCELAR")
	cancel.custom_minimum_size.x = 240
	cancel.pressed.connect(func() -> void:
		AudioManager.play("ui_click")
		show_page(&"main"))
	row.add_child(cancel)
	var yes := UiTheme.button("APAGAR TUDO")
	yes.custom_minimum_size.x = 240
	yes.add_theme_stylebox_override("normal", UiTheme.panel(UiTheme.RED.lightened(0.2), UiTheme.INK, 16, 4))
	yes.add_theme_stylebox_override("hover", UiTheme.panel(UiTheme.RED.lightened(0.4), UiTheme.INK, 16, 4))
	yes.pressed.connect(func() -> void:
		AudioManager.play("ui_click")
		new_game_requested.emit())
	row.add_child(yes)
	_confirm.set_meta("focus", cancel)
