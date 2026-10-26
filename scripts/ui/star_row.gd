class_name StarRow
extends Control
## Estrelas da fama do bar (desenhadas com o mesmo polígono do símbolo da cerveja).

var max_stars := 5
var value := 5


func _init() -> void:
	custom_minimum_size = Vector2(170, 34)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(v: int) -> void:
	value = v
	queue_redraw()


func _draw() -> void:
	var r := size.y * 0.46
	for i in max_stars:
		var c := Vector2(r + i * (r * 2.2), size.y / 2.0)
		var col := UiTheme.MUSTARD if i < value else Color(0.3, 0.2, 0.15)
		SymbolShapes.draw(self, &"star", c, r, col, UiTheme.INK, 2.5)
