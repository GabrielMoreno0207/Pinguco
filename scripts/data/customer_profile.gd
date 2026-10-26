class_name CustomerProfile
extends Resource
## Perfil configurável de freguês. Novos perfis são adicionados no CustomerDatabase.

enum Body { TIOZAO, VALENTAO, FALANTE, FOFOQUEIRA, UNIVERSITARIO, MALANDRO }

@export var id: StringName = &""
@export var archetype: String = ""
@export var nicknames: PackedStringArray = []
@export var personality: String = ""
@export var body: Body = Body.TIOZAO

## Visual
@export var skin_color: Color = Color(0.93, 0.72, 0.56)
@export var shirt_color: Color = Color.WHITE
@export var pants_color: Color = Color(0.2, 0.25, 0.45)
@export var hair_color: Color = Color(0.15, 0.1, 0.08)
## Variações de roupa sorteadas por freguês (vazio = usa shirt_color).
@export var shirt_variants: PackedColorArray = []

## Comportamento
## Pontos de embriaguez até capotar.
@export var tolerance: float = 100.0
## Multiplicador da força das bebidas.
@export var sensitivity: float = 1.0
## Segundos entre terminar uma bebida e pedir a próxima (sóbrio).
@export var order_delay: float = 3.0
## Segundos de paciência por pedido.
@export var patience: float = 30.0
## Quantos vacilos (atraso/erro) antes de ir embora bravo.
@export var max_strikes: int = 3
## Chance (0..1) de mudar de ideia no meio do pedido quando bêbado.
@export var fickleness: float = 0.15
## Chance de soltar conversa fiada antes do pedido.
@export var chatter: float = 0.2
## Tom de voz (1.0 = normal).
@export var voice_pitch: float = 1.0
## Gorjeta base.
@export var tip: int = 2
## Quanto a fome sobe a cada bebida (fome alta = pede salgado, que corta o porre).
@export var hunger_rate: float = 0.25

## Bebidas preferidas: id -> peso.
@export var favorites: Dictionary = {}

## Falas
@export var greetings: PackedStringArray = []
@export var order_templates: PackedStringArray = []
## Pedidos de salgado (fome). Vazio = usa as frases genéricas do DrunkennessSystem.
@export var food_templates: PackedStringArray = []
@export var chatter_lines: PackedStringArray = []
@export var happy_lines: PackedStringArray = []
@export var wrong_lines: PackedStringArray = []
@export var late_lines: PackedStringArray = []
@export var angry_leave_lines: PackedStringArray = []
@export var pass_out_messages: PackedStringArray = []
