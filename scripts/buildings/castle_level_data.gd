class_name CastleLevelData
extends Resource
## One level of the castle (GDD §8, M11c). One .tres per level in data/castle/. Level N unlocks
## buildings that need it and, later, generals of up to N stars.

@export var level: int = 1
## Paid to reach this level from the one below (nothing for level 1).
@export var cost: Dictionary[StringName, int] = {}
## Extra army squads this level adds (on top of the levels below).
@export var squad_capacity: int = 0
## Clans annexed or allied (Diplomacy.count_united) needed before upgrading to this level
## (GDD §15, M14b).
@export var required_clans: int = 0


## All levels, sorted by level.
static func load_all() -> Array[CastleLevelData]:
	var result: Array[CastleLevelData] = []
	result.assign(DataLibrary.load_folder("res://data/castle/", &"level").values())
	result.sort_custom(func(a: CastleLevelData, b: CastleLevelData) -> bool: return a.level < b.level)
	return result
