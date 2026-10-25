class_name UnitData
extends Resource
## Static definition of a soldier type. Player units live in data/units/, enemy-only units
## (bandits, …) in data/enemy_units/. Combat rules: GDD §7.6.
## One recruitment gives one squad of `squad_size` soldiers.

## Formation row. Melee and gun fire hit the front-most row that still has soldiers.
enum Row { FRONT, MIDDLE, BACK }
## How the unit fights at range. MELEE units have no ranged attack.
enum AttackKind { MELEE, BOW, GUN }

const ROW_NAMES: Array[String] = ["Hàng trước", "Hàng giữa", "Hàng sau"]
const ATTACK_KIND_NAMES: Array[String] = ["Cận chiến", "Cung", "Súng"]

@export var unit_id: StringName
@export var display_name: String
## Position in the army list, lowest first.
@export var sort_order: int = 0
## Soldiers per recruited squad (HP / Number at full strength).
@export var squad_size: int = 20

@export_group("Combat")
@export var row: Row = Row.FRONT
@export var attack_kind: AttackKind = AttackKind.MELEE
@export var melee_attack: int = 5
## Reduces casualties taken in melee.
@export var melee_defense: int = 5
## Reduces casualties taken from bullets and arrows.
@export var armor: int = 0
## Extra melee damage on the first clash only.
@export var charge_attack: int = 0
## Starting morale. Drops as the squad takes losses; at 0 the squad breaks.
@export var morale: int = 6
## Ranged damage. Only BOW and GUN units use it.
@export var range_attack: int = 0
## Seconds between arrow volleys. Guns fire a single volley and ignore this.
@export var reload_time: float = 5.0
## Casualties one soldier deals compared with an ordinary soldier (heroes and their guards hit like
## several men; GDD §8, M11d).
@export var damage_per_soldier: float = 1.0
## Casualties needed to bring one soldier down.
@export var hit_points: float = 1.0

@export_group("Recruitment")
## Paid per squad.
@export var recruit_cost: Dictionary[StringName, int] = {}
## Paid every turn per squad.
@export var upkeep: Dictionary[StringName, int] = {}
## The kingdom needs at least one of this building. Empty = no building needed.
@export var required_building: StringName
## Minimum owned cells per terrain, e.g. {&"forest": 3} for archers.
@export var required_terrain: Dictionary[StringName, int] = {}


func is_ranged() -> bool:
	return attack_kind != AttackKind.MELEE


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
