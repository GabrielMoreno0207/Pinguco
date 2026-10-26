class_name HeldItem
extends RefCounted
## O que o jogador carrega na mão: nada, uma garrafa ou um copo (vazio ou servido).

enum Kind { NONE, BOTTLE, GLASS }

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


func describe() -> String:
	match kind:
		Kind.BOTTLE:
			return beverage.display_name
		Kind.GLASS:
			return "Copo de %s" % beverage.display_name if filled else "Copo vazio"
	return ""
