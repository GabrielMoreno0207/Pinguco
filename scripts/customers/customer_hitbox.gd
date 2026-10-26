class_name CustomerHitbox
extends Interactable
## Área clicável do freguês: entregar bebida e mostrar o bafômetro no HUD.

var customer: CustomerController


func get_prompt(player: PlayerController) -> String:
	if customer == null or not customer.can_receive():
		return ""
	if player.held.is_served_glass():
		return "Entregar %s para %s" % [player.held.beverage.display_name, customer.nickname]
	return ""


func get_hint(player: PlayerController) -> String:
	if customer == null:
		return ""
	if customer.can_receive() and player.held.is_empty_glass():
		return "O copo está vazio!"
	return ""


func interact(player: PlayerController) -> void:
	customer.receive(player)


func set_focused(on: bool) -> void:
	if customer:
		Mats.set_highlight(customer.rig, on)
