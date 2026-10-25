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
## Most soldiers the clan can field (its army regrows to this). GDD §9.6.
@export var military_strength: int = 50
## Player unit id -> relative weight of that unit type in the clan's army.
@export var army_units: Dictionary[StringName, float] = {}
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
## Clans that send soldiers to defend this one when the kingdom attacks it (GDD §9.7).
## Keep it mutual: list each pair in both files.
@export var friends: Array[StringName] = []


func is_neighbor() -> bool:
	return direction != Direction.NONE


## Board side a clan in `direction` borders: NORTH = Vector2i.UP (top edge), … NONE = ZERO.
static func direction_vector(dir: Direction) -> Vector2i:
	match dir:
		Direction.NORTH:
			return Vector2i.UP
		Direction.EAST:
			return Vector2i.RIGHT
		Direction.SOUTH:
			return Vector2i.DOWN
		Direction.WEST:
			return Vector2i.LEFT
	return Vector2i.ZERO


## All clans, sorted by clan_id.
static func load_all() -> Array[ClanData]:
	var result: Array[ClanData] = []
	result.assign(DataLibrary.load_folder("res://data/clans/", &"clan_id").values())
	return result
