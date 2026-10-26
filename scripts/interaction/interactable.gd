class_name Interactable
extends Area3D
## Base de tudo que responde à tecla E. O InteractionSystem encontra estes nós por raycast.
## Subclasses sobrescrevem get_prompt / interact / (opcional) interact_hold.

const LAYER := 4 # bit da camada 3 ("interactable")

## Nó cujas malhas recebem o destaque quando o jogador mira.
var highlight_root: Node3D


func _init() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true


func setup_shape(size: Vector3, offset := Vector3.ZERO) -> Interactable:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = offset
	add_child(cs)
	return self


## Texto mostrado ao mirar. "" = nada a fazer agora (sem destaque).
func get_prompt(_player: PlayerController) -> String:
	return ""


## Texto curto secundário (ex.: "mãos ocupadas"), mostrado mesmo sem ação.
func get_hint(_player: PlayerController) -> String:
	return ""


func interact(_player: PlayerController) -> void:
	pass


## true = a ação exige segurar E (interact_hold é chamado a cada frame).
func is_hold_action(_player: PlayerController) -> bool:
	return false


## Retorna o progresso 0..1 da ação contínua.
func interact_hold(_player: PlayerController, _delta: float) -> float:
	return 0.0


func interact_release(_player: PlayerController) -> void:
	pass


func set_focused(on: bool) -> void:
	var root := highlight_root if highlight_root else get_parent() as Node3D
	if root:
		Mats.set_highlight(root, on)
