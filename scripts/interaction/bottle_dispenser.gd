class_name BottleDispenser
extends Interactable
## Garrafa/jarra de uma bebida na prateleira, geladeira ou bancada.
## Pegar = levar a garrafa na mão; ela volta sozinha depois de servir.
## Fora do expediente dá para trocar duas garrafas de lugar (ou usar um BottleSlot vazio).

var beverage: BeverageData
## Lugar onde a garrafa mora agora (é o nó pai).
var slot: BottleSlot
var model: Node3D
var _home_scale := Vector3.ONE


static func create(bev: BeverageData) -> BottleDispenser:
	var d := BottleDispenser.new()
	d.beverage = bev
	d.name = "Dispenser_%s" % bev.id
	d.model = BeverageModels.build_container(bev)
	d.add_child(d.model)
	d.highlight_root = d.model
	d.setup_shape(Vector3(0.2, 0.45, 0.2), Vector3(0, 0.2, 0))
	# plaquinha com o nome logo abaixo
	var tag := Mats.label3d(d, bev.display_name.to_upper(), Vector3(0, -0.035, 0.12), 22, UiTheme.PAPER, 6)
	tag.pixel_size = 0.0015
	return d


func get_prompt(player: PlayerController) -> String:
	if player.held.is_empty():
		return "Pegar %s" % beverage.display_name
	if player.held.is_bottle() and player.held.source == self:
		return "Devolver %s" % beverage.display_name
	if _can_swap(player):
		return "Trocar de lugar com %s" % beverage.display_name
	return ""


func get_hint(player: PlayerController) -> String:
	if not player.held.is_empty() and not _can_swap(player):
		return "%s  (mãos ocupadas)" % beverage.display_name
	return ""


func interact(player: PlayerController) -> void:
	if player.held.is_empty():
		player.set_held(HeldItem.bottle(beverage, self))
		set_taken(true)
		AudioManager.play_at("bottle", global_position)
	elif player.held.is_bottle() and player.held.source == self:
		player.set_held(HeldItem.empty())
		set_taken(false)
	elif _can_swap(player):
		var other := player.held.source as BottleDispenser
		var other_slot := other.slot
		var my_slot := slot
		my_slot.place(other)
		other_slot.place(self)
		player.set_held(HeldItem.empty())
		other.set_taken(false)
		BarProgress.save_layout()


func _can_swap(player: PlayerController) -> bool:
	if not GameManager.is_closed() or not player.held.is_bottle():
		return false
	var other := player.held.source as BottleDispenser
	return other != null and other != self and other.slot != null and slot != null


func set_taken(taken: bool) -> void:
	if taken:
		model.visible = false
	else:
		model.visible = true
		model.scale = Vector3(0.6, 1.3, 0.6)
		var tw := create_tween()
		tw.tween_property(model, "scale", _home_scale, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		AudioManager.play_at("bottle", global_position, 1.2, -6.0)
