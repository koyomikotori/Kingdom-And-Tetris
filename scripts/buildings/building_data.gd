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


static func load_all() -> Dictionary[StringName, BuildingData]:
	var result: Dictionary[StringName, BuildingData] = {}
	result.assign(DataLibrary.load_folder("res://data/buildings/", &"building_id"))
	return result
