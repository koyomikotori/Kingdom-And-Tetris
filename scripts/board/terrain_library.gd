class_name TerrainLibrary
extends RefCounted
## Loads every TerrainData resource in data/terrains/. Add a terrain by adding a .tres file there.

const TERRAIN_DIR := "res://data/terrains/"


static func load_all() -> Dictionary[StringName, TerrainData]:
	var result: Dictionary[StringName, TerrainData] = {}
	for file_name in ResourceLoader.list_directory(TERRAIN_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var terrain := load(TERRAIN_DIR + file_name) as TerrainData
		if terrain == null:
			push_error("Not a TerrainData resource: %s" % file_name)
			continue
		if result.has(terrain.terrain_id):
			push_error("Duplicate terrain_id '%s' in %s" % [terrain.terrain_id, file_name])
			continue
		result[terrain.terrain_id] = terrain
	return result
