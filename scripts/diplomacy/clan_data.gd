class_name ClanData
extends Resource
## Static definition of a neighbouring clan on the world map (GDD §9). One .tres per clan in data/clans/.

## Which edge of the kingdom board the clan borders. NONE = far away, trade only.
enum Direction { NONE, NORTH, EAST, SOUTH, WEST }
enum Personality { PEACEFUL, AGGRESSIVE, MERCHANT, ISOLATED }

const DIRECTION_NAMES: Array[String] = ["Ở xa", "Phía Bắc", "Phía Đông", "Phía Nam", "Phía Tây"]
const PERSONALITY_NAMES: Array[String] = ["Ôn hòa", "Hiếu chiến", "Thương nhân", "Cô lập"]

@export var clan_id: StringName
@export var display_name: String
@export_multiline var description: String
## Banner color on the world map.
@export var color: Color = Color.WHITE
## Position on the world map, 0..1 in both axes (the kingdom sits at 0.5, 0.5).
@export var map_position: Vector2 = Vector2(0.5, 0.2)
@export var direction: Direction = Direction.NONE
@export var personality: Personality = Personality.PEACEFUL
## Rough army size, shown to the player; used by invasions in M9.
@export var military_strength: int = 50
## Resources this clan has plenty of (sells them cheaply).
@export var surplus: Array[StringName] = []
## Resources this clan lacks (pays more for them).
@export var deficit: Array[StringName] = []
## Relation at the start of a game, -100..100.
@export var start_relation: int = 0
## Relation drifts back toward this value every turn.
@export var base_relation: int = 0
## Other clans this one shares a road with; &"kingdom" is the player.
@export var roads: Array[StringName] = []


func is_neighbor() -> bool:
	return direction != Direction.NONE


## All clans, sorted by clan_id.
static func load_all() -> Array[ClanData]:
	var result: Array[ClanData] = []
	result.assign(DataLibrary.load_folder("res://data/clans/", &"clan_id").values())
	return result
