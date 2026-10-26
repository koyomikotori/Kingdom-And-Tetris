class_name BuildRules
extends RefCounted
## Decides whether a building may be constructed, and constructs it (paying its cost).

enum Result { OK, OUT_OF_BOUNDS, NOT_OWNED, OCCUPIED, WRONG_TERRAIN, LIMIT_REACHED, CANNOT_AFFORD, CASTLE_TOO_LOW }

## Each castle level above 1 allows this many more of every building (GDD §8, economy v2).
const EXTRA_PER_CASTLE_LEVEL := 1


## How many of this building the kingdom may have at this castle level; 0 = unlimited.
static func limit(building: BuildingData, castle_level: int) -> int:
	if building.max_count <= 0:
		return 0
	return building.max_count + EXTRA_PER_CASTLE_LEVEL * (castle_level - 1)


## `cost`: what building it costs right now (KingdomState.building_cost); empty = building.cost.
static func check(board: BoardData, stockpile: Stockpile, building: BuildingData, origin: Vector2i,
		castle_level: int = 1, cost: Dictionary[StringName, int] = {}) -> Result:
	if castle_level < building.required_castle_level:
		return Result.CASTLE_TOO_LOW
	for y in building.size.y:
		for x in building.size.x:
			var cell := board.get_cell(origin + Vector2i(x, y))
			if cell == null:
				return Result.OUT_OF_BOUNDS
			if not cell.owned:
				return Result.NOT_OWNED
			if cell.has_building():
				return Result.OCCUPIED
			if not building.allowed_terrains.is_empty() and not building.allowed_terrains.has(cell.terrain_id):
				return Result.WRONG_TERRAIN
	var most := limit(building, castle_level)
	if most > 0 and board.count_buildings(building.building_id) >= most:
		return Result.LIMIT_REACHED
	if not stockpile.can_afford(building.cost if cost.is_empty() else cost):
		return Result.CANNOT_AFFORD
	return Result.OK


## Whether the building whose origin is `from_origin` may move to `to_origin`: the same rules as
## building it there (but no cost), with its own current cells counting as free.
static func check_move(board: BoardData, building: BuildingData, from_origin: Vector2i, to_origin: Vector2i) -> Result:
	if to_origin == from_origin:
		return Result.OCCUPIED
	for y in building.size.y:
		for x in building.size.x:
			var cell := board.get_cell(to_origin + Vector2i(x, y))
			if cell == null:
				return Result.OUT_OF_BOUNDS
			if not cell.owned:
				return Result.NOT_OWNED
			if cell.has_building() and cell.building_origin != from_origin:
				return Result.OCCUPIED
			if not building.allowed_terrains.is_empty() and not building.allowed_terrains.has(cell.terrain_id):
				return Result.WRONG_TERRAIN
	return Result.OK


## Builds only when check() is OK; otherwise nothing changes and nothing is paid.
static func apply(board: BoardData, stockpile: Stockpile, building: BuildingData, origin: Vector2i,
		castle_level: int = 1, cost: Dictionary[StringName, int] = {}) -> Result:
	var result := check(board, stockpile, building, origin, castle_level, cost)
	if result != Result.OK:
		return result
	stockpile.spend(building.cost if cost.is_empty() else cost)
	board.place_building(building.building_id, origin, building.size)
	return Result.OK


static func describe(result: Result) -> String:
	match result:
		Result.OK:
			return "Có thể xây ở đây."
		Result.OUT_OF_BOUNDS:
			return "Công trình nằm ngoài bản đồ."
		Result.NOT_OWNED:
			return "Chỉ xây được trong lãnh thổ."
		Result.OCCUPIED:
			return "Ô này đã có công trình."
		Result.WRONG_TERRAIN:
			return "Không xây được trên địa hình này."
		Result.LIMIT_REACHED:
			return "Đã đạt số lượng tối đa của công trình này."
		Result.CANNOT_AFFORD:
			return "Không đủ tài nguyên."
		Result.CASTLE_TOO_LOW:
			return "Cần nâng cấp thành chính."
	return ""
