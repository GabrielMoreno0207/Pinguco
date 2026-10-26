class_name Seat
extends RefCounted
## Posição de atendimento no balcão (banqueta).

var index := 0
var position := Vector3.ZERO
## Ponto onde o freguês para antes de sentar (no salão, de frente pro balcão).
var approach := Vector3.ZERO
var occupant: CustomerController = null


func is_free() -> bool:
	return occupant == null
