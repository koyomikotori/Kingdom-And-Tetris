class_name Economy
extends RefCounted
## Per-turn production (GDD §5): every owned cell yields its terrain's `yields`;
## key cells yield double. Amount dictionaries map resource_id -> int.

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
