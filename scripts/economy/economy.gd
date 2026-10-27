class_name Economy
extends RefCounted
## Per-turn production. Economy v2 (GDD §8): only production buildings produce, by level
## (BuildingData.yields_at); terrain `yields` are empty in the data now but still counted if set.
## Key cells double both. Amount dictionaries map resource_id -> int.

const KEY_CELL_MULTIPLIER := 2


static func cell_yield(terrain: TerrainData, is_key: bool) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	if terrain == null:
		return result
	var multiplier := KEY_CELL_MULTIPLIER if is_key else 1
	for resource_id in terrain.yields:
		result[resource_id] = terrain.yields[resource_id] * multiplier
	return result


## Total produced by the player's territory in one turn.
static func board_yield(board: BoardData, terrains: Dictionary[StringName, TerrainData]) -> Dictionary[StringName, int]:
	var total: Dictionary[StringName, int] = {}
	for cell in board.get_all_cells():
		if cell.owned:
			add_into(total, cell_yield(terrains.get(cell.terrain_id), cell.is_key))
	return total


## What one building of `level` produces per turn, doubled when its origin cell is a key cell.
static func building_yield(building: BuildingData, on_key_cell: bool, level: int = 1) -> Dictionary[StringName, int]:
	var result := building.yields_at(level)
	if on_key_cell:
		for resource_id in result:
			result[resource_id] *= KEY_CELL_MULTIPLIER
	return result


## Total produced by every production building in one turn (each counted once, at its origin).
## Buildings under construction produce nothing (GDD §8, M12d).
static func buildings_yield(board: BoardData, buildings: Dictionary[StringName, BuildingData]) -> Dictionary[StringName, int]:
	var total: Dictionary[StringName, int] = {}
	for cell in board.get_all_cells():
		if cell.has_building() and cell.coord == cell.building_origin and buildings.has(cell.building_id) \
				and not cell.is_constructing():
			add_into(total, building_yield(buildings[cell.building_id], cell.is_key, cell.building_level))
	return total


## How the per-turn yield would change if `piece` were placed at `origin`.
## Assumes the placement is valid; covered cells lose their old yield.
static func placement_delta(board: BoardData, piece: LandPiece, origin: Vector2i,
		terrains: Dictionary[StringName, TerrainData]) -> Dictionary[StringName, int]:
	var delta: Dictionary[StringName, int] = {}
	var coords := piece.get_board_coords(origin)
	for i in coords.size():
		var cell := board.get_cell(coords[i])
		if cell.owned:
			add_into(delta, cell_yield(terrains.get(cell.terrain_id), cell.is_key), -1)
		add_into(delta, cell_yield(terrains.get(piece.terrains[i]), piece.is_key_cell(i)))
	for resource_id in delta.keys():
		if delta[resource_id] == 0:
			delta.erase(resource_id)
	return delta


## Adds `amounts` (times `sign`) into `target` in place.
static func add_into(target: Dictionary[StringName, int], amounts: Dictionary[StringName, int], sign: int = 1) -> void:
	for resource_id in amounts:
		target[resource_id] = target.get(resource_id, 0) + amounts[resource_id] * sign
