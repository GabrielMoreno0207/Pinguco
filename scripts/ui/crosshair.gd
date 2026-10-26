class_name Crosshair
extends Control
## Mira discreta: ponto central; vira anel quando há interação e mostra o progresso
## de ações de segurar (servir).

var active := false:
	set(v):
		active = v
		queue_redraw()
var progress := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_progress(v: float) -> void:
	progress = v
	queue_redraw()


func _process(_delta: float) -> void:
	if active:
		queue_redraw()


func _draw() -> void:
	var c := Vector2.ZERO
	if active:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.08
		draw_arc(c, 13.0 * pulse, 0, TAU, 32, Color(0, 0, 0, 0.45), 5.0, true)
		draw_arc(c, 13.0 * pulse, 0, TAU, 32, UiTheme.MUSTARD, 2.5, true)
	draw_circle(c, 3.5, Color(0, 0, 0, 0.5))
	draw_circle(c, 2.2, UiTheme.PAPER)
	if progress > 0.0:
		draw_arc(c, 24.0, -PI / 2.0, -PI / 2.0 + TAU, 48, Color(0, 0, 0, 0.4), 8.0, true)
		draw_arc(c, 24.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(progress, 0.0, 1.0), 48, UiTheme.GREEN.lightened(0.2), 6.0, true)
