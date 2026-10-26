class_name BeverageData
extends Resource
## Definição de uma bebida. Instâncias são registradas no BeverageDatabase.
## Cor, letra e símbolo são pistas redundantes: nenhuma depende só da cor.

enum Vessel { BOTTLE, LONGNECK, JAR, CAN }

@export var id: StringName = &""
@export var display_name: String = ""
@export var color: Color = Color.WHITE
## Cor do rótulo/garrafa (pode diferir do líquido, ex.: pinga em garrafa verde-clara).
@export var bottle_color: Color = Color.WHITE
@export var letter: String = "?"
## Chave de SymbolShapes: star, diamond, circle, lemon, heart, bolt.
@export var symbol: StringName = &"circle"
@export var vessel: Vessel = Vessel.BOTTLE
## Segundos segurando E para servir/preparar.
@export var prep_time: float = 1.0
## Quanto sobe a embriaguez (antes do multiplicador do perfil do cliente).
@export var strength: float = 20.0
@export var price: int = 8
## Gírias usadas por clientes mais bêbados (o nome formal é usado quando sóbrios).
@export var slang: PackedStringArray = []
## Artigo para frases ("uma cerveja", "um vinho").
@export var article: String = "uma"
## Verbo da preparação mostrado ao jogador ("Servindo", "Amassando limão").
@export var prep_verb: String = "Servindo"
## Onde o dispenser fica no cenário: "fridge", "shelf", "counter".
@export var station: StringName = &"shelf"
