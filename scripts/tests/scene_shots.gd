extends Node3D
## Vitrine do cenário: monta cada ponto (original e reformado) e salva fotos de
## ângulos fixos em user://shots/view_*.png. Serve para conferir iluminação,
## materiais e a vista lá de fora sem jogar.
##   godot --path . -- --views
## Opções: --loc=praia limita a um ponto; --full só a versão reformada.

var shot_dir := "user://shots"
var cam: Camera3D

## Ângulos fixos: nome, posição da câmera, para onde olha, FOV.
const VIEWS := [
	["atende", Vector3(0.0, 1.62, -1.2), Vector3(0.0, 1.15, 1.6), 70.0],
	["salao", Vector3(-0.2, 1.75, 2.2), Vector3(1.2, 1.0, 5.6), 75.0],
	["balcao", Vector3(2.6, 1.5, 2.6), Vector3(-1.4, 1.0, -0.6), 60.0],
	["bancada", Vector3(-1.0, 1.55, -0.9), Vector3(-1.2, 1.1, -2.5), 60.0],
	["porta", Vector3(-2.0, 1.7, 3.4), Vector3(3.0, 1.4, 7.5), 70.0],
	["bebidas", Vector3(-2.1, 1.35, -1.75), Vector3(-2.1, 1.45, -2.45), 35.0],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(shot_dir)
	cam = Camera3D.new()
	cam.near = 0.04
	add_child(cam)
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var only := ""
	for a in args:
		if a.begins_with("--loc="):
			only = a.trim_prefix("--loc=")
	var states := [true] if args.has("--full") else [false, true]
	for loc_id: StringName in BarLocations.ORDER:
		if only != "" and String(loc_id) != only:
			continue
		for full: bool in states:
			BarProgress.location = loc_id
			BarProgress.levels = {}
			if full:
				for u: Dictionary in BarProgress.UPGRADES:
					BarProgress.levels[u.id] = BarProgress.max_level(u.id)
			BarProgress.layout = {}
			var bar := BarBuilder.new()
			add_child(bar)
			bar.build()
			bar.set_clock(21.0)
			await get_tree().process_frame
			var tag := "%s_%s" % [loc_id, "full" if full else "base"]
			for v in VIEWS:
				cam.fov = v[3]
				cam.position = v[1]
				cam.look_at(v[2])
				await _shot("view_%s_%s" % [tag, v[0]])
			bar.queue_free()
			await get_tree().process_frame
	print("[views] fim — ", ProjectSettings.globalize_path(shot_dir))
	get_tree().quit()


func _shot(file: String) -> void:
	for _k in 4:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_dir.path_join(file + ".png"))
	print("[view] ", file)
