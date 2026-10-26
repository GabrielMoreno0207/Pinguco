class_name SpeechBubble
extends Control
## Balão de fala ancorado na cabeça de um freguês (projeção 3D → tela).
## Mostra o texto (distorcido conforme a bebedeira), a ficha da bebida com as pistas
## visíveis e a paciência restante. Embaixo do balão fica a StatusTag (bafômetro + fome),
## sempre visível enquanto o freguês está no bar.

var customer: CustomerController
var _panel: PanelContainer
var _label: Label
var _chip: BeverageChip
var _patience: ProgressBar
var _name_tag: Label
var _shown_text := ""
var _shown_kind: StringName = &""
var _style_cache: Dictionary = {}
var _pop := 0.0
var _fill := StyleBoxFlat.new()
var _tag: StatusTag


func _init(c: CustomerController) -> void:
	customer = c
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag = StatusTag.new(c)
	add_child(_tag)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_panel.add_child(v)
	_name_tag = UiTheme.label(c.nickname, 15, Color(0.45, 0.3, 0.22), false)
	v.add_child(_name_tag)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	_chip = BeverageChip.new()
	_chip.custom_minimum_size = Vector2(54, 54)
	_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_chip)
	_label = UiTheme.label("", 21, UiTheme.INK, false)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(220, 0)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_label)
	_patience = ProgressBar.new()
	_patience.show_percentage = false
	_patience.custom_minimum_size = Vector2(0, 8)
	_patience.max_value = 1.0
	_patience.step = 0.0
	_fill.set_corner_radius_all(4)
	_patience.add_theme_stylebox_override("fill", _fill)
	v.add_child(_patience)


func _process(delta: float) -> void:
	if not is_instance_valid(customer):
		queue_free()
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var order := customer.current_order()
	var text := ""
	var kind: StringName = &""
	if customer.bubble_timer > 0.0 and customer.bubble_text != "":
		text = customer.bubble_text
		kind = customer.bubble_kind
	elif order:
		text = order.text
		kind = &"order"
	var head := customer.head_position()
	if cam.is_position_behind(head):
		visible = false
		return
	visible = true
	# posição: acima da cabeça, escala com a distância
	var screen := cam.unproject_position(head)
	var dist := cam.global_position.distance_to(head)
	var s := clampf(2.2 / maxf(dist, 0.5), 0.55, 1.15)
	_tag.visible = customer.state not in [CustomerController.State.ENTERING, CustomerController.State.LEAVING, CustomerController.State.ANGRY_LEAVING]
	_tag.scale = Vector2.ONE * s
	_tag.position = screen - Vector2(StatusTag.SIZE.x / 2.0, StatusTag.SIZE.y)
	var tag_h := (StatusTag.SIZE.y + 8.0) * s if _tag.visible else 0.0
	if text == "":
		_panel.visible = false
		_shown_text = ""
		queue_redraw()
		return
	_panel.visible = true
	if text != _shown_text or kind != _shown_kind:
		_shown_text = text
		_shown_kind = kind
		_label.text = text
		_pop = 1.0
		_apply_style(kind)
		var show_chip := kind == &"order" and order != null
		_chip.visible = show_chip
		_patience.visible = show_chip
		if show_chip:
			_chip.setup(BeverageDatabase.get_beverage(order.beverage_id), order.clues, 1.0 if order.stage >= 2 else 0.0)
		_panel.reset_size()
	if order and kind == &"order":
		var pf := order.patience_fraction()
		_patience.value = pf
		_fill.bg_color = UiTheme.GREEN.lerp(UiTheme.RED, 1.0 - pf)
	_pop = maxf(_pop - delta * 4.0, 0.0)
	var pop_scale := 1.0 + sin(_pop * PI) * 0.15
	var stage := customer.stage()
	var wobble := 0.0
	if stage >= 2 and kind == &"order":
		wobble = sin(Time.get_ticks_msec() * 0.003 + customer.get_instance_id()) * 0.03 * (stage - 1)
	_panel.pivot_offset = Vector2(_panel.size.x / 2.0, _panel.size.y)
	_panel.scale = Vector2.ONE * s * pop_scale
	_panel.rotation = wobble
	_panel.position = screen - Vector2(_panel.size.x / 2.0, _panel.size.y + 18.0 + tag_h)
	queue_redraw()


func _draw() -> void:
	if not visible or _shown_text == "" or not _panel.visible:
		return
	# rabinho do balão apontando para a cabeça
	var base := _panel.position + Vector2(_panel.size.x / 2.0, _panel.size.y)
	var s := _panel.scale.x
	var bg: Color = _style_cache.get(_shown_kind, UiTheme.PAPER)
	var tip := base + Vector2(-6, 20) * s
	var pts := PackedVector2Array([base + Vector2(-14, -3) * s, base + Vector2(10, -3) * s, tip])
	draw_colored_polygon(pts, bg)
	draw_polyline(PackedVector2Array([base + Vector2(-14, 0) * s, tip, base + Vector2(10, 0) * s]), UiTheme.INK, 3.0 * s, true)


func _apply_style(kind: StringName) -> void:
	var bg := UiTheme.PAPER
	match kind:
		&"angry":
			bg = Color(1.0, 0.78, 0.72)
		&"happy":
			bg = Color(0.85, 1.0, 0.8)
		&"chat":
			bg = Color(0.95, 0.95, 1.0)
	_style_cache[kind] = bg
	var sb := UiTheme.panel(bg, UiTheme.INK, 18, 3)
	_panel.add_theme_stylebox_override("panel", sb)
	_label.add_theme_font_size_override("font_size", 21 if kind == &"order" else 18)
	var bg_bar := StyleBoxFlat.new()
	bg_bar.bg_color = Color(0, 0, 0, 0.15)
	bg_bar.set_corner_radius_all(4)
	_patience.add_theme_stylebox_override("background", bg_bar)
