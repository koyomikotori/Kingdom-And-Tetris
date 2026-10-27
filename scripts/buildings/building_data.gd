class_name BuildingData
extends Resource
## Static definition of a building the player can construct. One .tres per building in data/buildings/.

## The build window's tabs (GDD §8, M12d).
enum Category { PRODUCTION, MILITARY, ADMIN }
const CATEGORY_NAMES: Array[String] = ["Sản xuất", "Quân sự", "Hành chính"]

@export var building_id: StringName
@export var display_name: String
@export_multiline var description: String
## Footprint in cells.
@export var size: Vector2i = Vector2i.ONE
@export var cost: Dictionary[StringName, int] = {}
## Every covered cell must have one of these terrains. Empty = any terrain.
@export var allowed_terrains: Array[StringName] = []
## Maximum number the kingdom may have at castle level 1; each castle level above adds
## BuildRules.EXTRA_PER_CASTLE_LEVEL (GDD §8, economy v2). 0 = unlimited.
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
## Produced every turn while the building's upkeep is paid, one entry per level (index 0 = level 1);
## doubled on a key cell (GDD §8, economy v2). The number of entries is the building's max level.
## Each entry maps resource_id -> amount.
@export var level_yields: Array[Dictionary] = []
## Castle level needed to build it.
@export var required_castle_level: int = 1
@export var category: Category = Category.PRODUCTION
## Turns a new one takes to build (GDD §8, M12d). Upgrades take upgrade_turns().
@export var build_turns: int = 2
## The limit stays max_count whatever the castle level (the forge, M12e).
@export var fixed_count: bool = false
## Levels for a building without level_yields (the forge); 0 = from level_yields.
@export var upgrade_levels: int = 0
## Its level stays this far below the castle's (the forge: castle level − 2).
@export var castle_level_gap: int = 0


## Upgrade cost: to level N, N × the build cost; from level 3 also (N − 2) × each UPGRADE_EXTRA.
const UPGRADE_EXTRA: Dictionary[StringName, int] = {&"ore": 2, &"hardwood": 2}
## Upkeep grows by this much for each level above 1.
const UPKEEP_PER_LEVEL: Dictionary[StringName, int] = {&"food": 1}


static func load_all() -> Dictionary[StringName, BuildingData]:
	var result: Dictionary[StringName, BuildingData] = {}
	result.assign(DataLibrary.load_folder("res://data/buildings/", &"building_id"))
	return result


## Levels this building has (1 when it cannot be upgraded).
func max_level() -> int:
	return maxi(1, maxi(level_yields.size(), upgrade_levels))


func is_upgradable() -> bool:
	return max_level() > 1


## Turns an upgrade to `level` takes: as many as the new level.
static func upgrade_turns(level: int) -> int:
	return level


## What one building of this level produces per turn (before the key cell bonus).
func yields_at(level: int) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	if level_yields.is_empty():
		return result
	var entry: Dictionary = level_yields[clampi(level, 1, level_yields.size()) - 1]
	for resource_id in entry:
		result[StringName(resource_id)] = int(entry[resource_id])
	return result


func upkeep_at(level: int) -> Dictionary[StringName, int]:
	var result := upkeep.duplicate()
	for resource_id in UPKEEP_PER_LEVEL:
		if level > 1:
			result[resource_id] = result.get(resource_id, 0) + UPKEEP_PER_LEVEL[resource_id] * (level - 1)
	return result


## What raising one building to `level` costs (before the Nội chính discount).
func upgrade_cost(level: int) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for resource_id in cost:
		result[resource_id] = cost[resource_id] * level
	if level >= 3:
		for resource_id in UPGRADE_EXTRA:
			result[resource_id] = result.get(resource_id, 0) + UPGRADE_EXTRA[resource_id] * (level - 2)
	return result
