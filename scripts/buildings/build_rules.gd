class_name BuildRules
extends RefCounted
## Decides whether a building may be constructed, and constructs it (paying its cost).

enum Result { OK, OUT_OF_BOUNDS, NOT_OWNED, OCCUPIED, WRONG_TERRAIN, LIMIT_REACHED, CANNOT_AFFORD }


static func check(board: BoardData, stockpile: Stockpile, building: BuildingData, origin: Vector2i) -> Result:
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
	if building.max_count > 0 and board.count_buildings(building.building_id) >= building.max_count:
		return Result.LIMIT_REACHED
	if not stockpile.can_afford(building.cost):
		return Result.CANNOT_AFFORD
	return Result.OK


## Builds only when check() is OK; otherwise nothing changes and nothing is paid.
static func apply(board: BoardData, stockpile: Stockpile, building: BuildingData, origin: Vector2i) -> Result:
	var result := check(board, stockpile, building, origin)
	if result != Result.OK:
		return result
	stockpile.spend(building.cost)
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
	return ""
