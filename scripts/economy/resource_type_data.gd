class_name ResourceTypeData
extends Resource
## Static definition of a resource the kingdom collects (food, wood, …).
## One .tres per resource in data/resources/.

@export var resource_id: StringName
@export var display_name: String
## Position in the resource bar, lowest first.
@export var sort_order: int = 0
## Worth of one unit when trading or gifting to clans (GDD §9.4).
@export var trade_value: int = 1
## Food, wood and stone: the resources every kingdom lives on (the prosperity victory counts these).
@export var basic: bool = false


## All resource types, sorted by sort_order.
static func load_all() -> Array[ResourceTypeData]:
	var result: Array[ResourceTypeData] = []
	result.assign(DataLibrary.load_folder("res://data/resources/", &"resource_id").values())
	result.sort_custom(func(a: ResourceTypeData, b: ResourceTypeData) -> bool: return a.sort_order < b.sort_order)
	return result
