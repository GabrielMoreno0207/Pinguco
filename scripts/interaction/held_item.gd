class_name HeldItem
extends RefCounted
## O que o jogador carrega na mão: nada, uma garrafa, um copo (vazio ou servido) ou um salgado.

enum Kind { NONE, BOTTLE, GLASS, FOOD }

var kind: Kind = Kind.NONE
var beverage: BeverageData = null
## Para copos: true quando já contém a bebida preparada.
var filled := false
## Dispenser de origem (para devolver a garrafa automaticamente).
var source: Node = null


static func empty() -> HeldItem:
	return HeldItem.new()


static func bottle(bev: BeverageData, from: Node) -> HeldItem:
	var h := HeldItem.new()
	h.kind = Kind.BOTTLE
	h.beverage = bev
	h.source = from
	return h


static func glass(bev: BeverageData = null) -> HeldItem:
	var h := HeldItem.new()
	h.kind = Kind.GLASS
	h.beverage = bev
	h.filled = bev != null
	return h


static func food(bev: BeverageData, from: Node = null) -> HeldItem:
	var h := HeldItem.new()
	h.kind = Kind.FOOD
	h.beverage = bev
	h.filled = true
	h.source = from
	return h


func is_empty() -> bool:
	return kind == Kind.NONE


func is_bottle() -> bool:
	return kind == Kind.BOTTLE


func is_empty_glass() -> bool:
	return kind == Kind.GLASS and not filled


func is_glass_any() -> bool:
	return kind == Kind.GLASS


func is_served_glass() -> bool:
	return kind == Kind.GLASS and filled


func is_food() -> bool:
	return kind == Kind.FOOD


## Pode ser entregue a um freguês (copo servido ou salgado).
func is_deliverable() -> bool:
	return is_served_glass() or is_food()


func describe() -> String:
	match kind:
		Kind.BOTTLE:
			return beverage.display_name
		Kind.GLASS:
			return "Copo de %s" % beverage.display_name if filled else "Copo vazio"
		Kind.FOOD:
			return beverage.display_name
	return ""
