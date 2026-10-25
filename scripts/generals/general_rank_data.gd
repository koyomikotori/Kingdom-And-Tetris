class_name GeneralRankData
extends Resource
## What a general of a given star rank is like (GDD §8, M11d). One .tres per rank in
## data/general_ranks/.

@export var stars: int = 1
## Võ lực + Thống suất add up to a random total in this range.
@export var total_min: int = 3
@export var total_max: int = 5
## Bodyguard cavalry riding with the general in battle.
@export var guards: int = 4
@export var recruit_cost: Dictionary[StringName, int] = {}
## Paid every turn with the army's upkeep.
@export var upkeep: Dictionary[StringName, int] = {}


## All ranks by star count.
static func load_all() -> Dictionary[int, GeneralRankData]:
	var result: Dictionary[int, GeneralRankData] = {}
	result.assign(DataLibrary.load_folder("res://data/general_ranks/", &"stars"))
	return result
