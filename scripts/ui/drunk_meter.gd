class_name DrunkMeter
extends Control
## "Bafômetro": barra em quatro faixas (Sóbrio → Chumbado) com marcador animado.

var value := 0.0
var stage := 0
var _shown := 0.0


func set_value(v: float, s: int) -> void:
	value = v
	stage = s


func _process(delta: float) -> void:
	_shown = lerpf(_shown, value, 1.0 - exp(-8.0 * delta))
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r.grow(2), UiTheme.INK)
	var seg := size.x / 4.0
	for i in 4:
		var col: Color = DrunkennessSystem.STAGE_COLORS[i]
		var a := 1.0 if i <= stage else 0.35
		draw_rect(Rect2(Vector2(i * seg, 0), Vector2(seg - (2 if i < 3 else 0), size.y)), Color(col, a))
	var x := clampf(_shown, 0.0, 1.0) * size.x
	var wob := sin(Time.get_ticks_msec() * 0.01) * stage * 1.2
	draw_rect(Rect2(Vector2(x - 3 + wob, -5), Vector2(6, size.y + 10)), UiTheme.PAPER)
	draw_rect(Rect2(Vector2(x - 3 + wob, -5), Vector2(6, size.y + 10)), UiTheme.INK, false, 2.0)
