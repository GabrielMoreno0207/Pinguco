class_name GlassStack
extends Interactable
## Pilha de copos americanos no balcão. Estoque infinito (é protótipo, o patrão é rico).

var visual: Node3D


static func create() -> GlassStack:
	var g := GlassStack.new()
	g.name = "GlassStack"
	g.visual = Node3D.new()
	g.add_child(g.visual)
	# bandeja + copos empilhados de boca pra baixo
	Mats.cylinder(g.visual, 0.16, 0.015, Vector3(0, 0.008, 0), Color(0.75, 0.75, 0.78), true)
	var offsets := [Vector3(-0.06, 0, -0.05), Vector3(0.06, 0, -0.05), Vector3(0, 0, 0.06),
		Vector3(-0.08, 0, 0.06), Vector3(0.08, 0, 0.06)]
	for o: Vector3 in offsets:
		var cup := BeverageModels.build_glass()
		cup.position = o + Vector3(0, 0.015, 0)
		g.visual.add_child(cup)
	var top := BeverageModels.build_glass()
	top.position = Vector3(0, 0.125, 0.0)
	g.visual.add_child(top)
	g.highlight_root = g.visual
	g.setup_shape(Vector3(0.36, 0.26, 0.36), Vector3(0, 0.12, 0))
	var tag := Mats.label3d(g, "COPOS", Vector3(0, 0.3, 0), 26, UiTheme.MUSTARD, 6)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.0015
	return g


func get_prompt(player: PlayerController) -> String:
	if player.held.is_empty():
		return "Pegar copo"
	if player.held.is_empty_glass():
		return "Guardar copo"
	return ""


func get_hint(player: PlayerController) -> String:
	if not player.held.is_empty():
		return "Copos  (mãos ocupadas)"
	return ""


func interact(player: PlayerController) -> void:
	if player.held.is_empty():
		player.set_held(HeldItem.glass())
		AudioManager.play_at("clink", global_position)
	elif player.held.is_empty_glass():
		player.set_held(HeldItem.empty())
		AudioManager.play_at("clink", global_position, 0.9, -4.0)
