extends Node3D
## Vitrine para conferir os modelos sem jogar:
##   godot --path pinguco -- --gallery
## Salva screenshots em user://shots/gallery_*.png e fecha.

var cam: Camera3D
var shot_dir := "user://shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.22, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.7, 0.55)
	env.ambient_light_energy = 0.5
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	sun.light_energy = 1.1
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 40
	add_child(cam)
	_run.call_deferred()


func _run() -> void:
	# ---- bebidas
	var all := BeverageDatabase.all()
	var x := 0.0
	var holder := Node3D.new()
	add_child(holder)
	for bev in all:
		var m := BeverageModels.build_container(bev)
		m.position = Vector3(x, 0, 0)
		holder.add_child(m)
		var g := BeverageModels.build_glass(bev)
		g.position = Vector3(x, 0, 0.25)
		holder.add_child(g)
		x += 0.26
	holder.position.x = -x / 2.0 + 0.13
	cam.position = Vector3(0, 0.45, 1.9)
	cam.look_at(Vector3(0, 0.15, 0))
	await _shot("gallery_bottles")
	cam.position = Vector3(-0.9, 0.25, 0.75)
	cam.look_at(Vector3(-0.9, 0.15, 0))
	await _shot("gallery_bottles_zoom_a")
	cam.position = Vector3(0.75, 0.25, 0.75)
	cam.look_at(Vector3(0.75, 0.15, 0))
	await _shot("gallery_bottles_zoom_b")
	holder.queue_free()

	# ---- símbolos e fichas (HUD)
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = UiTheme.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.position = Vector2(40, 40)
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 20)
	layer.add_child(grid)
	for bev in all:
		var v := VBoxContainer.new()
		var chip := BeverageChip.new()
		chip.custom_minimum_size = Vector2(150, 150)
		chip.setup(bev)
		v.add_child(chip)
		var l := UiTheme.label(bev.display_name, 22, UiTheme.INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		grid.add_child(v)
	await _shot("gallery_chips")
	layer.queue_free()

	# ---- fregueses
	var people := Node3D.new()
	add_child(people)
	var profiles := CustomerDatabase.all()
	var px := 0.0
	for p in profiles:
		var rig := CustomerRig.new()
		people.add_child(rig)
		rig.build(p)
		rig.position = Vector3(px, 0, 0)
		rig.rotation.y = PI
		px += 0.85
	people.position.x = -px / 2.0 + 0.42
	cam.fov = 40
	cam.position = Vector3(0, 1.3, 4.6)
	cam.look_at(Vector3(0, 1.0, 0))
	await _shot("gallery_people")
	var i := 0
	for rig: CustomerRig in people.get_children():
		var hp := rig.head.global_position + Vector3(0, 0.25, 0)
		cam.position = hp + Vector3(0, 0.05, 1.1)
		cam.look_at(hp)
		await _shot("gallery_face_%d" % i)
		i += 1
	# bêbados
	for rig: CustomerRig in people.get_children():
		rig.apply_drunk_look(1.0, 0.6)
		rig.set_eyelids(0.6)
	cam.position = Vector3(0, 1.3, 4.6)
	cam.look_at(Vector3(0, 1.0, 0))
	await _shot("gallery_people_drunk")
	get_tree().quit()


func _shot(file: String) -> void:
	for k in 3:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_dir.path_join(file + ".png"))
	print("[shot] ", file)
