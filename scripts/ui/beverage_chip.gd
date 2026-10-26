class_name BeverageChip
extends Control
## Ficha visual de uma bebida (cor + letra + símbolo). Pode esconder pistas,
## como acontece nos pedidos de fregueses bêbados.

var beverage: BeverageData
var clues := {"color": true, "letter": true, "symbol": true}
var wobble := 0.0
var _t := 0.0


func setup(bev: BeverageData, clue_mask: Dictionary = {}, wobble_amount := 0.0) -> BeverageChip:
	beverage = bev
	if not clue_mask.is_empty():
		clues = clue_mask
	wobble = wobble_amount
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(64, 64)
	queue_redraw()
	return self


func _process(delta: float) -> void:
	if wobble > 0.0:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if beverage == null:
		return
	var s := minf(size.x, size.y)
	var c := size / 2.0
	var r := s * 0.46
	if wobble > 0.0:
		draw_set_transform(c, sin(_t * 3.1) * 0.12 * wobble, Vector2.ONE)
		c = Vector2.ZERO
	var bg := beverage.color if clues.color else Color(0.82, 0.8, 0.76)
	# moeda/ficha com borda
	draw_circle(c + Vector2(2, 3), r, Color(0, 0, 0, 0.3))
	draw_circle(c, r, UiTheme.INK)
	draw_circle(c, r - 3.0, bg)
	if not clues.color:
		# hachura para indicar "cor desconhecida"
		for i in range(-3, 4):
			draw_line(c + Vector2(i * r * 0.28 - r * 0.4, -r * 0.6), c + Vector2(i * r * 0.28 + r * 0.4, r * 0.6), Color(0.7, 0.68, 0.64), 2.0, true)
	var fg := UiTheme.PAPER if bg.get_luminance() < 0.55 else UiTheme.INK
	if clues.symbol:
		var sym_center := c + (Vector2(-r * 0.32, r * 0.3) if clues.letter else Vector2.ZERO)
		var sym_r := r * (0.38 if clues.letter else 0.62)
		SymbolShapes.draw(self, beverage.symbol, sym_center, sym_r, fg, UiTheme.INK if fg == UiTheme.PAPER else UiTheme.PAPER, 2.0)
	if clues.letter:
		var font := UiTheme.title_font()
		var fs := int(r * (1.05 if clues.symbol else 1.35))
		var txt := beverage.letter
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := c + (Vector2(r * 0.12, -r * 0.05) if clues.symbol else Vector2(-ts.x / 2.0, 0)) + Vector2(0, ts.y * 0.32)
		draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, UiTheme.INK if fg == UiTheme.PAPER else UiTheme.PAPER)
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)
	if not clues.letter and not clues.symbol:
		var font := UiTheme.title_font()
		draw_string(font, c + Vector2(-r * 0.22, r * 0.35), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r), fg)
