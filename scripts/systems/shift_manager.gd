class_name ShiftManager
extends Node
## O turno: relógio do bar (18h → 2h), tempo restante e condições de encerramento.

signal tick(seconds_left: float, clock_text: String)
signal shift_ended(reason: String)

@export var duration := 300.0
const START_HOUR := 18.0
const END_HOUR := 26.0 # 2h da manhã

var time_left := 0.0
var running := false


func start() -> void:
	time_left = duration
	running = true
	GameManager.reputation_changed.connect(_on_reputation_changed)


func progress() -> float:
	return 1.0 - time_left / duration


func clock_text() -> String:
	var hours := lerpf(START_HOUR, END_HOUR, progress())
	var h := int(hours) % 24
	var m := int((hours - floor(hours)) * 60.0)
	m = m - m % 5
	return "%02d:%02d" % [h, m]


func _process(delta: float) -> void:
	if not running or not GameManager.is_playing():
		return
	time_left = maxf(time_left - delta, 0.0)
	tick.emit(time_left, clock_text())
	if time_left <= 0.0:
		end("Fechou o buteco às 2h. Hora de baixar a porta!")


func end(reason: String) -> void:
	if not running:
		return
	running = false
	shift_ended.emit(reason)


func _on_reputation_changed(value: int) -> void:
	if value <= 0:
		end("A fama do bar foi pro brejo... ninguém mais quer beber aqui!")
