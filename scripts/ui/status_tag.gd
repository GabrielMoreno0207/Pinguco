class_name StatusTag
extends Control
## Plaquinha sempre visível sobre a cabeça do freguês: bafômetro em 4 faixas
## (Sóbrio → Chumbado) e o ícone de fome (coxinha que enche; "!" quando vai pedir salgado).

const SIZE := Vector2(150, 30)

var customer: CustomerController
var _shown := 0.0
var _flash := 0.0
var _last_level := 0.0
var _style := StyleBoxFlat.new()


func _init(c: CustomerController) -> void:
	customer = c
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	pivot_offset = Vector2(SIZE.x / 2.0, SIZE.y)
	_style.border_color = UiTheme.INK
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(10)


func _process(delta: float) -> void:
	if not is_instance_valid(customer):
		return
	var f := customer.drunk_fraction()
	# pisca quando o porre cai (salgado/água): o jogador vê que perdeu terreno
	if customer.drunk_level < _last_level - 0.5:
		_flash = 1.0
	_last_level = customer.drunk_level
	_flash = maxf(_flash - delta * 1.2, 0.0)
	_shown = lerpf(_shown, f, 1.0 - exp(-6.0 * delta))
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(customer):
		return
	var st := customer.stage()
	var bg := UiTheme.PAPER.lerp(Color(0.6, 0.85, 1.0), _flash)
	_style.bg_color = bg
	draw_style_box(_style, Rect2(Vector2.ZERO, SIZE))
	# carinha do estágio
	var face_c := Vector2(15, SIZE.y / 2.0)
	var col: Color = DrunkennessSystem.STAGE_COLORS[st]
	draw_circle(face_c, 10, UiTheme.INK)
	draw_circle(face_c, 8.5, col)
	var asleep := customer.state == CustomerController.State.ASLEEP or customer.state == CustomerController.State.PASSING_OUT
	if asleep or st >= 3:
		draw_line(face_c + Vector2(-5, -3), face_c + Vector2(-1, -1), UiTheme.INK, 1.5)
		draw_line(face_c + Vector2(5, -3), face_c + Vector2(1, -1), UiTheme.INK, 1.5)
	else:
		draw_circle(face_c + Vector2(-3, -2), 1.4, UiTheme.INK)
		draw_circle(face_c + Vector2(3, -2), 1.4, UiTheme.INK)
	draw_arc(face_c + Vector2(0, 1), 4.0, 0.3, PI - 0.3, 6, UiTheme.INK, 1.5)
	# barra do bafômetro
	var bar := Rect2(Vector2(30, 9), Vector2(84, 12))
	draw_rect(bar.grow(1.5), UiTheme.INK)
	var seg := bar.size.x / 4.0
	for i in 4:
		var c: Color = DrunkennessSystem.STAGE_COLORS[i]
		draw_rect(Rect2(bar.position + Vector2(i * seg, 0), Vector2(seg - (1 if i < 3 else 0), bar.size.y)), Color(c, 1.0 if i <= st else 0.3))
	var x := bar.position.x + clampf(_shown, 0.0, 1.0) * bar.size.x
	draw_rect(Rect2(Vector2(x - 2, 5), Vector2(4, 20)), UiTheme.PAPER)
	draw_rect(Rect2(Vector2(x - 2, 5), Vector2(4, 20)), UiTheme.INK, false, 1.5)
	# fome: coxinha que vai enchendo
	var hc := Vector2(SIZE.x - 18, SIZE.y / 2.0 + 1)
	var hungry := customer.is_hungry()
	var hunger_col := Color(0.75, 0.72, 0.68).lerp(Color(0.95, 0.55, 0.15), clampf(customer.hunger / DrunkennessSystem.HUNGRY_AT, 0.0, 1.0))
	SymbolShapes.draw(self, &"coxinha", hc, 11.0, hunger_col, UiTheme.INK, 1.5)
	if hungry:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		draw_circle(hc + Vector2(9, -9), 6.5, UiTheme.RED.lerp(UiTheme.MUSTARD, pulse))
		draw_string(UiTheme.title_font(), hc + Vector2(6.5, -4.5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.PAPER)

