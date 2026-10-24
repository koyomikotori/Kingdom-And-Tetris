class_name TerrainLibrary
extends RefCounted
## Loads every TerrainData resource in data/terrains/. Add a terrain by adding a .tres file there.

const TERRAIN_DIR := "res://data/terrains/"


static func load_all() -> Dictionary[StringName, TerrainData]:
	var result: Dictionary[StringName, TerrainData] = {}
	result.assign(DataLibrary.load_folder(TERRAIN_DIR, &"terrain_id"))
	return result
