class_name OrderSystem
extends Node
## Cria pedidos, controla paciência e valida entregas (bebida certa + cliente certo).

signal order_created(order: Order)
signal order_changed(order: Order)
signal order_expired(order: Order)
signal order_closed(order: Order, success: bool)

enum Result { CORRECT, WRONG_DRINK, NO_ORDER, NOT_SERVED }


class Order extends RefCounted:
	var id: int
	var customer: Node
	## A referência verdadeira — nunca é distorcida.
	var beverage_id: StringName
	var text: String
	var clues: Dictionary
	var stage: int
	var patience_total: float
	var patience_left: float
	var expired_count := 0

	func patience_fraction() -> float:
		return clampf(patience_left / maxf(patience_total, 0.01), 0.0, 1.0)


var _orders: Dictionary = {} # customer instance id -> Order
var _next_id := 1
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


func create_order(customer: CustomerController, bev_id: StringName, patience: float) -> Order:
	var bev := BeverageDatabase.get_beverage(bev_id)
	assert(bev != null, "Bebida inexistente: %s" % bev_id)
	var o := Order.new()
	o.id = _next_id
	_next_id += 1
	o.customer = customer
	o.beverage_id = bev_id
	o.stage = customer.stage()
	var composed := DrunkennessSystem.compose_order(customer.profile, bev, o.stage, customer.last_beverage, rng)
	o.text = composed.text
	o.clues = composed.clues
	o.patience_total = patience
	o.patience_left = patience
	_orders[customer.get_instance_id()] = o
	order_created.emit(o)
	return o


## Freguês muda de ideia: nova bebida, novo texto, mesma paciência restante (+ um respiro).
func change_order(customer: CustomerController, new_bev: StringName) -> Order:
	var o := get_order(customer)
	if o == null:
		return null
	var bev := BeverageDatabase.get_beverage(new_bev)
	o.beverage_id = new_bev
	o.stage = customer.stage()
	var composed := DrunkennessSystem.compose_order(customer.profile, bev, o.stage, &"", rng)
	o.text = "Não, pera... " + composed.text
	o.clues = composed.clues
	o.patience_left = minf(o.patience_left + 6.0, o.patience_total)
	order_changed.emit(o)
	return o


func get_order(customer: Node) -> Order:
	return _orders.get(customer.get_instance_id())


func has_order(customer: Node) -> bool:
	return _orders.has(customer.get_instance_id())


func cancel(customer: Node) -> void:
	var o := get_order(customer)
	if o:
		_orders.erase(customer.get_instance_id())
		order_closed.emit(o, false)


## Valida uma entrega. Só é sucesso se ESTE cliente tem um pedido aberto e a bebida bate.
func validate(customer: Node, item: HeldItem) -> Result:
	if not item.is_served_glass():
		return Result.NOT_SERVED
	var o := get_order(customer)
	if o == null or o.customer != customer:
		return Result.NO_ORDER
	if item.beverage.id != o.beverage_id:
		return Result.WRONG_DRINK
	return Result.CORRECT


## Fecha o pedido como entregue e devolve o valor ganho (preço + gorjeta por rapidez).
func complete(customer: CustomerController) -> int:
	var o := get_order(customer)
	if o == null:
		return 0
	_orders.erase(customer.get_instance_id())
	var bev := BeverageDatabase.get_beverage(o.beverage_id)
	var speed_tip := int(round(o.patience_fraction() * 4.0)) if o.expired_count == 0 else 0
	var drunk_tip := o.stage # bêbado é generoso
	var total := bev.price + customer.profile.tip + speed_tip + drunk_tip
	order_closed.emit(o, true)
	return total


func _process(delta: float) -> void:
	if not GameManager.is_playing():
		return
	for key in _orders.keys():
		var o: Order = _orders[key]
		if not is_instance_valid(o.customer):
			_orders.erase(key)
			continue
		o.patience_left -= delta
		if o.patience_left <= 0.0:
			o.expired_count += 1
			o.patience_left = o.patience_total * 0.7
			order_expired.emit(o)
