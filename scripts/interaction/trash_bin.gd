class_name TrashBin
extends Interactable
## Pia/lixeira: descarta o copo (ou devolve a garrafa). Q faz o mesmo de qualquer lugar.


static func create() -> TrashBin:
	var t := TrashBin.new()
	t.name = "Sink"
	var v := Node3D.new()
	t.add_child(v)
	Mats.box(v, Vector3(0.5, 0.06, 0.4), Vector3(0, 0, 0), Color(0.75, 0.77, 0.8), true)
	Mats.box(v, Vector3(0.42, 0.02, 0.32), Vector3(0, 0.025, 0), Color(0.35, 0.38, 0.42), false)
	Mats.cylinder(v, 0.015, 0.25, Vector3(0, 0.15, -0.16), Color(0.8, 0.8, 0.85), false)
	Mats.cylinder(v, 0.012, 0.12, Vector3(0, 0.27, -0.11), Color(0.8, 0.8, 0.85), false).rotation_degrees.x = 90
	var lbl := Mats.label3d(t, "PIA", Vector3(0, 0.32, -0.16), 24, UiTheme.PAPER, 6)
	lbl.pixel_size = 0.0015
	t.highlight_root = v
	t.setup_shape(Vector3(0.5, 0.3, 0.4), Vector3(0, 0.1, 0))
	return t


func get_prompt(player: PlayerController) -> String:
	match player.held.kind:
		HeldItem.Kind.GLASS:
			return "Jogar fora"
		HeldItem.Kind.BOTTLE:
			return "Devolver %s" % player.held.beverage.display_name
	return ""


func interact(player: PlayerController) -> void:
	player.discard_held()
