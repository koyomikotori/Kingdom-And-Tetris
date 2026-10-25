class_name BuildingData
extends Resource
## Static definition of a building the player can construct. One .tres per building in data/buildings/.

@export var building_id: StringName
@export var display_name: String
@export_multiline var description: String
## Footprint in cells.
@export var size: Vector2i = Vector2i.ONE
@export var cost: Dictionary[StringName, int] = {}
## Every covered cell must have one of these terrains. Empty = any terrain.
@export var allowed_terrains: Array[StringName] = []
## Maximum number the kingdom may have. 0 = unlimited.
@export var max_count: int = 0
## Placeholder color until pixel-art sprites exist.
@export var color: Color = Color.WHITE
## Paid every turn per building. When it cannot be paid, the building's effects pause that turn.
@export var upkeep: Dictionary[StringName, int] = {}
## Subtracted from the per-turn bandit raid chance (0.04 = 4 percentage points).
@export var raid_chance_reduction: float = 0.0
## Extra army squads the kingdom may have per building of this type.
@export var squad_capacity: int = 0
## Squads below full strength regain soldiers each turn while the kingdom has this building.
@export var enables_replenishment: bool = false
## Produced every turn while the building's upkeep is paid; doubled on a key cell (GDD §8, M11c).
@export var yields: Dictionary[StringName, int] = {}
## Castle level needed to build it.
@export var required_castle_level: int = 1


static func load_all() -> Dictionary[StringName, BuildingData]:
	var result: Dictionary[StringName, BuildingData] = {}
	result.assign(DataLibrary.load_folder("res://data/buildings/", &"building_id"))
	return result
