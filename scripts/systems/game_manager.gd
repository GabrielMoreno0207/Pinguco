extends Node
## GameManager (autoload): estado global da partida, pontuação e eventos de alto nível.
## Sistemas emitem eventos aqui; o HUD apenas escuta (não faz polling do estado).

## CLOSED = fora do expediente (anda pelo bar sem fregueses); SHOP = caderninho de investimentos.
enum State { MENU, PLAYING, PAUSED, RESULTS, CLOSED, SHOP }

signal state_changed(state: State)
signal stats_changed(stats: Dictionary)
signal feedback(text: String, kind: StringName, world_pos: Vector3)
signal customer_passed_out(customer_name: String, message: String)
signal reputation_changed(value: int)

const MAX_REPUTATION := 5

var state: State = State.MENU
## Para onde a pausa volta (turno ou bar fechado).
var resume_state: State = State.PLAYING
var stats := {}
var reputation := MAX_REPUTATION
## Renderer de compatibilidade (GPUs antigas): menos luzes dinâmicas, sem MSAA.
var low_end := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	low_end = (RenderingServer.get_current_rendering_method() == "gl_compatibility" 		or OS.get_cmdline_user_args().has("--low")) and not OS.get_cmdline_user_args().has("--high")
	if low_end:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		get_viewport().scaling_3d_scale = 0.6
	reset_stats()


func reset_stats() -> void:
	stats = {
		"money": 0,
		"correct": 0,
		"wrong": 0,
		"late": 0,
		"served_customers": 0,
		"passed_out": 0,
		"angry_left": 0,
		"best_combo": 0,
		"combo": 0,
		"food_served": 0,
		"sobered": 0,
	}
	reputation = MAX_REPUTATION
	stats_changed.emit(stats)
	reputation_changed.emit(reputation)


func set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	get_tree().paused = state == State.PAUSED or state == State.RESULTS or state == State.SHOP
	match state:
		State.PLAYING, State.CLOSED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	state_changed.emit(state)


func is_playing() -> bool:
	return state == State.PLAYING


## O jogador pode andar e interagir: durante o turno ou com o bar fechado.
func can_act() -> bool:
	return state == State.PLAYING or state == State.CLOSED


func is_closed() -> bool:
	return state == State.CLOSED


func pause() -> void:
	if can_act():
		resume_state = state
		set_state(State.PAUSED)


func resume() -> void:
	if state == State.PAUSED:
		set_state(resume_state)


func add_money(amount: int) -> void:
	stats.money += amount
	stats_changed.emit(stats)


func register_correct(amount: int, pos: Vector3) -> void:
	stats.correct += 1
	stats.combo += 1
	stats.best_combo = maxi(stats.best_combo, stats.combo)
	stats.money += amount
	var combo_txt := "" if stats.combo < 3 else "  COMBO x%d" % stats.combo
	feedback.emit("Na mosca! +R$ %d%s" % [amount, combo_txt], &"good", pos)
	stats_changed.emit(stats)


func register_wrong(pos: Vector3, text := "Pedido errado!") -> void:
	stats.wrong += 1
	stats.combo = 0
	feedback.emit(text, &"bad", pos)
	stats_changed.emit(stats)


func register_late(pos: Vector3) -> void:
	stats.late += 1
	stats.combo = 0
	feedback.emit("Atrasou!", &"late", pos)
	stats_changed.emit(stats)


## Salgado, água ou refri: o freguês ficou mais sóbrio (ruim pro objetivo de capotar).
func register_sobered(pos: Vector3, food: bool) -> void:
	stats.sobered += 1
	if food:
		stats.food_served += 1
	feedback.emit("Forrou o estômago! Porre ↓" if food else "Rebateu! Porre ↓", &"late", pos + Vector3(0, 0.35, 0))
	stats_changed.emit(stats)


func register_customer_served() -> void:
	stats.served_customers += 1
	stats_changed.emit(stats)


func register_pass_out(customer_name: String, message: String, bonus: int) -> void:
	stats.passed_out += 1
	stats.money += bonus
	customer_passed_out.emit(customer_name, message)
	stats_changed.emit(stats)


func register_angry_leave(pos: Vector3) -> void:
	stats.angry_left += 1
	reputation = maxi(reputation - 1, 0)
	feedback.emit("Freguês foi embora bravo!", &"bad", pos)
	reputation_changed.emit(reputation)
	stats_changed.emit(stats)


func format_money(value: int) -> String:
	return "R$ %d,00" % value
