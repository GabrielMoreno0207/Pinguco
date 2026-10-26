class_name SnackTray
extends Interactable
## Bandeja de salgados dentro da estufa. Pegar = salgado no pratinho, pronto pra entregar.
## Salgado mata a fome do freguês mas CORTA O PORRE (embriaguez cai) — use com moderação.

var beverage: BeverageData
var visual: Node3D


static func create(bev: BeverageData) -> SnackTray:
	var t := SnackTray.new()
	t.beverage = bev
	t.name = "Snack_%s" % bev.id
	t.visual = Node3D.new()
	t.add_child(t.visual)
	Mats.box(t.visual, Vector3(0.3, 0.012, 0.38), Vector3(0, 0.006, 0), Color(0.85, 0.85, 0.88))
	Mats.box(t.visual, Vector3(0.28, 0.006, 0.36), Vector3(0, 0.014, 0), Color(1.0, 0.95, 0.85), false)
	var spots := [Vector3(-0.07, 0, -0.1), Vector3(0.07, 0, -0.1), Vector3(-0.07, 0, 0.03),
		Vector3(0.07, 0, 0.03), Vector3(0.0, 0, 0.13)]
	for i in spots.size():
		var s := BeverageModels.build_snack(t.visual, bev, spots[i] + Vector3(0, 0.016, 0))
		s.rotation.y = i * 1.3
	t.highlight_root = t.visual
	t.setup_shape(Vector3(0.3, 0.2, 0.4), Vector3(0, 0.08, 0))
	return t


func get_prompt(player: PlayerController) -> String:
	if player.held.is_empty():
		return "Pegar %s" % beverage.display_name
	if player.held.is_food() and player.held.beverage == beverage:
		return "Devolver %s" % beverage.display_name
	return ""


func get_hint(player: PlayerController) -> String:
	if not player.held.is_empty():
		return "%s  (mãos ocupadas)" % beverage.display_name
	return "Salgado corta o porre!"


func interact(player: PlayerController) -> void:
	if player.held.is_empty():
		player.set_held(HeldItem.food(beverage, self))
		AudioManager.play_at("clink", global_position, 0.7, -4.0)
	elif player.held.is_food() and player.held.beverage == beverage:
		player.set_held(HeldItem.empty())
