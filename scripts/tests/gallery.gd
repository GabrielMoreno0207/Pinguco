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
	# ---- bebidas (duas fileiras: garrafas atrás, copos servidos na frente)
	var all := BeverageDatabase.all()
	var holder := Node3D.new()
	add_child(holder)
	var n := all.size()
	for i in n:
		var bev := all[i]
		var row := i / 7
		var col := i % 7
		var x := (col - 3) * 0.3
		var z := -row * 0.55
		var m := BeverageModels.build_container(bev)
		m.position = Vector3(x, 0, z)
		holder.add_child(m)
		var g := BeverageModels.build_glass(bev)
		g.position = Vector3(x + 0.1, 0, z + 0.16)
		holder.add_child(g)
	cam.position = Vector3(0, 0.62, 1.55)
	cam.look_at(Vector3(0, 0.12, -0.3))
	await _shot("gallery_bottles")
	cam.position = Vector3(-0.6, 0.28, 0.85)
	cam.look_at(Vector3(-0.6, 0.15, 0))
	await _shot("gallery_bottles_zoom_a")
	cam.position = Vector3(0.45, 0.28, 0.85)
	cam.look_at(Vector3(0.45, 0.15, 0))
	await _shot("gallery_bottles_zoom_b")
	cam.position = Vector3(0.0, 0.32, 0.4)
	cam.look_at(Vector3(0.0, 0.15, -0.55))
	await _shot("gallery_bottles_zoom_c")
	holder.queue_free()

	# ---- mãos em primeira pessoa (vazia, copo, garrafa, servindo)
	var fp := Camera3D.new()
	fp.fov = 75
	fp.position = Vector3(0, 1.6, 6.0)
	add_child(fp)
	var floor_mesh := Mats.box(self, Vector3(4, 0.05, 4), Vector3(0, 1.0, 5.2), Color(0.55, 0.3, 0.15), false)
	fp.current = true
	var hands := Hands.new()
	fp.add_child(hands)
	await get_tree().process_frame
	var items := [HeldItem.empty(), HeldItem.glass(BeverageDatabase.get_beverage(&"caipirinha")),
		HeldItem.bottle(BeverageDatabase.get_beverage(&"cerveja"), null), HeldItem.bottle(BeverageDatabase.get_beverage(&"vinho"), null)]
	items[1].filled = true
	var k := 0
	for it: HeldItem in items:
		hands.show_item(it)
		hands.set_pouring(k == 3)
		for f in 90:
			hands.update_motion(1.0 / 60.0, 0.0, 0.0)
		await _shot("gallery_hands_%d" % k)
		k += 1
	hands.queue_free()
	floor_mesh.queue_free()
	fp.queue_free()
	cam.current = true

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
	cam.position = Vector3(2.6, 1.6, 3.6)
	cam.look_at(Vector3(0, 1.0, 0))
	await _shot("gallery_people_34")
	var i := 0
	for rig: CustomerRig in people.get_children():
		var hp := rig.head.global_position + Vector3(0, 0.25, 0)
		cam.position = hp + Vector3(0, 0.05, 1.1)
		cam.look_at(hp)
		await _shot("gallery_face_%d" % i)
		i += 1
	# expressões: neutro, feliz, bravo, bêbado (de frente) + perfil e 3/4
	var exprs := ["neutro", "feliz", "bravo", "bebado"]
	i = 0
	for rig: CustomerRig in people.get_children():
		var hp := rig.head.global_position + Vector3(0, 0.25, 0)
		for e in exprs:
			_pose_face(rig, e)
			cam.position = hp + Vector3(0, 0.03, 0.95)
			cam.look_at(hp)
			await _shot("gallery_expr_%d_%s" % [i, e])
		_pose_face(rig, "neutro")
		for other: Node3D in people.get_children():
			other.visible = other == rig
		cam.position = hp + Vector3(1.05, 0.03, 0.0)
		cam.look_at(hp)
		await _shot("gallery_expr_%d_perfil" % i)
		cam.position = hp + Vector3(0.7, 0.1, 0.75)
		cam.look_at(hp)
		await _shot("gallery_expr_%d_34" % i)
		for other: Node3D in people.get_children():
			other.visible = true
		i += 1
	# sentados no balcão (pernas e braços como no jogo), bêbados
	for rig: CustomerRig in people.get_children():
		rig.leg_l.rotation.x = 1.25
		rig.leg_r.rotation.x = 1.25
		rig.set_knees(1.3, 1.3)
		rig.arm_l.rotation = Vector3(1.05, 0, -0.08)
		rig.arm_r.rotation = Vector3(1.05, 0, 0.08)
		rig.position.y = 0.32
		rig.apply_drunk_look(1.0, 0.6)
		rig.set_eyelids(0.6)
		rig.set_mouth(0.5, 0.6)
	cam.position = Vector3(1.8, 1.7, 3.6)
	cam.look_at(Vector3(0, 1.1, 0))
	await _shot("gallery_people_drunk")
	var hr: CustomerRig = people.get_child(0)
	cam.position = hr.hand_r.global_position + Vector3(0.25, 0.15, 0.35)
	cam.look_at(hr.hand_r.global_position)
	await _shot("gallery_customer_hand")
	get_tree().quit()


func _pose_face(rig: CustomerRig, e: String) -> void:
	match e:
		"feliz":
			rig.set_expression(1.0, 0.0, 0.0)
			rig.set_eyelids(0.0)
			rig.set_brows(-0.15, 0.02)
			rig.set_mouth(0.35, 1.0)
			rig.look_pupils(Vector2.ZERO)
			rig.apply_drunk_look(0.0, 0.2)
		"bravo":
			rig.set_expression(0.0, 1.0, 0.0)
			rig.set_eyelids(0.0)
			rig.set_brows(0.5, -0.015)
			rig.set_mouth(0.0, -0.6)
			rig.look_pupils(Vector2.ZERO)
			rig.apply_drunk_look(0.0, 0.8)
		"bebado":
			rig.set_expression(0.0, 0.0, 1.0)
			rig.set_eyelids(0.55)
			rig.set_brows(0.12, 0.0)
			rig.set_mouth(0.2, 0.4)
			rig.look_pupils(Vector2(0.9, -0.1))
			rig.apply_drunk_look(1.0, 0.6)
		_:
			rig.set_expression(0.0, 0.0, 0.0)
			rig.set_eyelids(0.0)
			rig.set_brows(0.0, 0.0)
			rig.set_mouth(0.0, 0.0)
			rig.look_pupils(Vector2.ZERO)
			rig.apply_drunk_look(0.0, 0.0)


func _shot(file: String) -> void:
	for k in 3:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_dir.path_join(file + ".png"))
	print("[shot] ", file)
