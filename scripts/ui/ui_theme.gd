class_name UiTheme
extends RefCounted
## Fontes, cores e estilos da interface — inspirada em placa de boteco pintada à mão
## (madeira, giz, papel de comanda).

const INK := Color(0.16, 0.09, 0.06)
const CREAM := Color(1.0, 0.95, 0.82)
const PAPER := Color(1.0, 0.98, 0.9)
const WOOD := Color(0.42, 0.22, 0.12)
const WOOD_DARK := Color(0.28, 0.14, 0.08)
const MUSTARD := Color(1.0, 0.76, 0.18)
const GREEN := Color(0.16, 0.6, 0.3)
const RED := Color(0.86, 0.2, 0.2)
const CHALK := Color(0.16, 0.22, 0.18)

static var _title: Font
static var _body: Font


static func title_font() -> Font:
	if _title == null:
		_title = load("res://assets/fonts/LilitaOne-Regular.ttf")
	return _title


static func body_font() -> Font:
	if _body == null:
		var base: FontFile = load("res://assets/fonts/Fredoka.ttf")
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
		_body = fv
	return _body


static func panel(bg: Color, border: Color = INK, radius := 14, border_w := 4, shadow := true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 0
		sb.shadow_offset = Vector2(4, 5)
	return sb


static func label(text: String, size := 24, color := INK, title := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font() if title else body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func outlined(l: Label, outline := INK, size := 8) -> Label:
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", size)
	return l


static func button(text: String, size := 30) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", title_font())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_stylebox_override("normal", panel(MUSTARD, INK, 16, 4))
	b.add_theme_stylebox_override("hover", panel(MUSTARD.lightened(0.25), INK, 16, 4))
	b.add_theme_stylebox_override("pressed", panel(MUSTARD.darkened(0.15), INK, 16, 4, false))
	b.add_theme_stylebox_override("focus", panel(Color(0, 0, 0, 0), CREAM, 16, 4, false))
	b.custom_minimum_size = Vector2(280, 64)
	return b
