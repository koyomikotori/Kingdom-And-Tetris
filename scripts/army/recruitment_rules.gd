class_name RecruitmentRules
extends RefCounted
## Decides whether a soldier may be recruited, and recruits it (paying its cost).

enum Result { OK, NEEDS_BUILDING, NEEDS_TERRAIN, CANNOT_AFFORD }


static func check(board: BoardData, stockpile: Stockpile, unit: UnitData) -> Result:
	if unit.required_building != &"" and board.count_buildings(unit.required_building) == 0:
		return Result.NEEDS_BUILDING
	for terrain_id in unit.required_terrain:
		if board.count_owned_terrain(terrain_id) < unit.required_terrain[terrain_id]:
			return Result.NEEDS_TERRAIN
	if not stockpile.can_afford(unit.recruit_cost):
		return Result.CANNOT_AFFORD
	return Result.OK


## Recruits only when check() is OK; otherwise nothing changes and nothing is paid.
static func apply(board: BoardData, stockpile: Stockpile, army: Army, unit: UnitData) -> Result:
	var result := check(board, stockpile, unit)
	if result != Result.OK:
		return result
	stockpile.spend(unit.recruit_cost)
	army.add(unit.unit_id)
	return Result.OK


## Player-facing reason. Needs the data dictionaries to name the missing building / terrain.
static func describe(result: Result, unit: UnitData, buildings: Dictionary[StringName, BuildingData],
		terrains: Dictionary[StringName, TerrainData]) -> String:
	match result:
		Result.OK:
			return "Có thể tuyển."
		Result.NEEDS_BUILDING:
			var building: BuildingData = buildings.get(unit.required_building)
			return "Cần xây %s." % (building.display_name if building != null else String(unit.required_building))
		Result.NEEDS_TERRAIN:
			var parts: Array[String] = []
			for terrain_id in unit.required_terrain:
				var terrain: TerrainData = terrains.get(terrain_id)
				parts.append("%d ô %s" % [unit.required_terrain[terrain_id],
						terrain.display_name if terrain != null else String(terrain_id)])
			return "Cần lãnh thổ có ít nhất %s." % ", ".join(parts)
		Result.CANNOT_AFFORD:
			return "Không đủ tài nguyên."
	return ""
