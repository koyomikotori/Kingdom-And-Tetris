class_name UnitData
extends Resource
## Static definition of a soldier type. One .tres per unit in data/units/.
## Combat stats are used by the auto-battle in M5.

@export var unit_id: StringName
@export var display_name: String
## Position in the army list, lowest first.
@export var sort_order: int = 0

@export_group("Combat")
@export var max_hp: int = 100
@export var attack: int = 10
## Subtracted from each incoming hit.
@export var defense: int = 0
## In battlefield tiles. 1 = melee.
@export var attack_range: float = 1.0
## Seconds between attacks.
@export var attack_interval: float = 1.0
## Battlefield tiles per second.
@export var move_speed: float = 1.0

@export_group("Recruitment")
@export var recruit_cost: Dictionary[StringName, int] = {}
## Paid every turn per soldier.
@export var upkeep: Dictionary[StringName, int] = {}
## The kingdom needs at least one of this building. Empty = no building needed.
@export var required_building: StringName
## Minimum owned cells per terrain, e.g. {&"forest": 3} for archers.
@export var required_terrain: Dictionary[StringName, int] = {}


## All unit types, sorted by sort_order.
static func load_all() -> Array[UnitData]:
	var result: Array[UnitData] = []
	result.assign(DataLibrary.load_folder("res://data/units/", &"unit_id").values())
	result.sort_custom(func(a: UnitData, b: UnitData) -> bool: return a.sort_order < b.sort_order)
	return result
