extends Node
## Benchmark de desempenho: liga/desliga recursos e mede FPS.
##   godot --path pinguco -- --bench

func _ready() -> void:
	_run.call_deferred()


func _fps(label: String) -> void:
	await get_tree().create_timer(2.5).timeout
	print("BENCH %-28s FPS=%d prims=%d draws=%d proc=%.1fms phys=%.1fms meshes=%d labels=%d" % [label, Engine.get_frames_per_second(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		get_tree().root.find_children("*", "MeshInstance3D", true, false).size(),
		get_tree().root.find_children("*", "Label3D", true, false).size()])


func _run() -> void:
	var main := get_parent()
	main._start_shift()
	for i in 4:
		main.spawner.spawn()
	main.player.rotation.y = PI
	await _fps("base")
	main.player.rotation.y = 0
	await _fps("olhando prateleiras")
	get_tree().quit()
