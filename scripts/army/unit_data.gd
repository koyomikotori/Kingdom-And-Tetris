class_name UnitData
extends Resource
## Static definition of a soldier type. Player units live in data/units/, enemy-only units
## (bandits, …) in data/enemy_units/. Combat rules: GDD §7.4.

## Formation row. Melee and gun fire hit the front-most row that still has soldiers.
enum Row { FRONT, MIDDLE, BACK }
## Which battle phase the unit acts in.
enum AttackKind { MELEE, BOW, GUN }

const ROW_NAMES: Array[String] = ["Hàng trước", "Hàng giữa", "Hàng sau"]
const ATTACK_KIND_NAMES: Array[String] = ["Cận chiến", "Cung", "Súng"]

@export var unit_id: StringName
@export var display_name: String
## Position in the army list, lowest first.
@export var sort_order: int = 0

@export_group("Combat")
@export var max_hp: int = 100
@export var attack: int = 10
## Subtracted from each soldier's attack against this unit (minimum 1 damage per soldier).
@export var defense: int = 0
@export var row: Row = Row.FRONT
@export var attack_kind: AttackKind = AttackKind.MELEE

@export_group("Recruitment")
@export var recruit_cost: Dictionary[StringName, int] = {}
## Paid every turn per soldier.
@export var upkeep: Dictionary[StringName, int] = {}
## The kingdom needs at least one of this building. Empty = no building needed.
@export var required_building: StringName
## Minimum owned cells per terrain, e.g. {&"forest": 3} for archers.
@export var required_terrain: Dictionary[StringName, int] = {}


## Player unit types, sorted by sort_order.
static func load_all() -> Array[UnitData]:
	return _load_sorted("res://data/units/")


## Enemy-only unit types (bandits, …), sorted by sort_order.
static func load_enemies() -> Dictionary[StringName, UnitData]:
	var result: Dictionary[StringName, UnitData] = {}
	for unit in _load_sorted("res://data/enemy_units/"):
		result[unit.unit_id] = unit
	return result


static func _load_sorted(folder: String) -> Array[UnitData]:
	var result: Array[UnitData] = []
	result.assign(DataLibrary.load_folder(folder, &"unit_id").values())
	result.sort_custom(func(a: UnitData, b: UnitData) -> bool: return a.sort_order < b.sort_order)
	return result
