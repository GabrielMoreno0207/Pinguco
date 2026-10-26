class_name BottleSlot
extends Interactable
## Um lugar onde uma garrafa pode morar (geladeira, prateleira ou bancada).
## Fora do expediente o jogador leva garrafas de um lugar para outro; o arranjo é salvo
## no BarProgress e recriado no próximo turno.

var id: StringName
## Nome do móvel para o prompt ("geladeira", "prateleira", "bancada").
var area_name := ""
var occupant: BottleDispenser

var _marker: Node3D
var _player: PlayerController


static func create(slot_id: StringName, area: String) -> BottleSlot:
	var s := BottleSlot.new()
	s.id = slot_id
	s.area_name = area
	s.name = "Slot_%s" % slot_id
	s._marker = Node3D.new()
	s._marker.name = "Marker"
	s._marker.visible = false
	s.add_child(s._marker)
	Mats.torus(s._marker, 0.065, 0.085, Vector3(0, 0.008, 0), UiTheme.MUSTARD)
	Mats.cylinder(s._marker, 0.065, 0.004, Vector3(0, 0.004, 0), UiTheme.MUSTARD.darkened(0.3), false)
	s.highlight_root = s._marker
	s.setup_shape(Vector3(0.2, 0.45, 0.2), Vector3(0, 0.2, 0))
	return s


func place(d: BottleDispenser) -> void:
	if d.slot and d.slot != self and d.slot.occupant == d:
		d.slot.occupant = null
	occupant = d
	d.slot = self
	if d.get_parent() != self:
		if d.get_parent():
			d.get_parent().remove_child(d)
		add_child(d)
	d.position = Vector3.ZERO
	# a área vazia só existe para o raycast quando não tem garrafa em cima
	collision_layer = 0
	BarProgress.set_slot(d.beverage.id, id)


func _process(_delta: float) -> void:
	if occupant and occupant.slot != self:
		occupant = null
	collision_layer = 0 if occupant else LAYER
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as PlayerController
	_marker.visible = occupant == null and _can_receive(_player)


func _can_receive(player: PlayerController) -> bool:
	return player != null and GameManager.is_closed() and player.held.is_bottle() \
		and player.held.source is BottleDispenser


func get_prompt(player: PlayerController) -> String:
	if occupant == null and _can_receive(player):
		return "Guardar %s aqui (%s)" % [player.held.beverage.display_name, area_name]
	return ""


func interact(player: PlayerController) -> void:
	if not _can_receive(player) or occupant:
		return
	var d := player.held.source as BottleDispenser
	place(d)
	player.set_held(HeldItem.empty())
	d.set_taken(false)
	BarProgress.save_layout()
