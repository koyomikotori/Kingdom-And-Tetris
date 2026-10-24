extends "res://tests/test_suite.gd"

var terrains := TerrainLibrary.load_all()
var buildings := BuildingData.load_all()
var units := UnitData.load_all()


func _state() -> KingdomState:
	var gen := PieceGenerator.new(PieceShapeLibrary.load_all(), terrains, 5)
	var state := KingdomState.new(BoardData.create_starting_board(12), PieceHand.new(gen), terrains, buildings, units)
	state.start()
	return state


func _rich_state() -> KingdomState:
	var state := _state()
	state.stockpile.add({&"food": 50, &"wood": 50, &"stone": 50})
	return state


func _paint(board: BoardData, terrain: StringName, coords: Array[Vector2i]) -> void:
	for coord in coords:
		board.set_land(coord, terrain, false)


func test_data_loads() -> void:
	check(buildings.has(&"barracks"), "Barracks is loaded")
	check_eq(units.map(func(u: UnitData) -> StringName: return u.unit_id),
			[&"swordsman", &"spearman", &"archer"], "Units in sort order")
	for unit in units:
		check(not unit.recruit_cost.is_empty(), "%s has a recruit cost" % unit.unit_id)
		check(unit.max_hp > 0 and unit.attack > 0, "%s has combat stats" % unit.unit_id)


func test_build_barracks_pays_cost() -> void:
	var state := _rich_state()
	check_eq(state.build(&"barracks", Vector2i(4, 4)), BuildRules.Result.OK, "Barracks on own grass")
	check_eq(state.board.get_cell(Vector2i(4, 4)).building_id, &"barracks", "Cell holds the barracks")
	check_eq([state.stockpile.get_amount(&"wood"), state.stockpile.get_amount(&"stone")], [44, 48], "Paid 6 wood, 2 stone")
	check_eq(state.build(&"barracks", Vector2i(7, 7)), BuildRules.Result.LIMIT_REACHED, "Only one barracks")


func test_build_rejections_change_nothing() -> void:
	var state := _state()
	check_eq(state.build(&"barracks", Vector2i(4, 4)), BuildRules.Result.CANNOT_AFFORD, "Empty stockpile")
	state.stockpile.add({&"wood": 6, &"stone": 2})
	check_eq(state.build(&"barracks", Vector2i(0, 0)), BuildRules.Result.NOT_OWNED, "Outside territory")
	check_eq(state.build(&"barracks", Vector2i(5, 5)), BuildRules.Result.OCCUPIED, "On the castle")
	check_eq(state.build(&"barracks", Vector2i(-1, 0)), BuildRules.Result.OUT_OF_BOUNDS, "Off the board")
	_paint(state.board, &"forest", [Vector2i(4, 4)])
	check_eq(state.build(&"barracks", Vector2i(4, 4)), BuildRules.Result.WRONG_TERRAIN, "Barracks needs grass")
	check_eq(state.board.count_buildings(&"barracks"), 0, "Nothing was built")
	check_eq([state.stockpile.get_amount(&"wood"), state.stockpile.get_amount(&"stone")], [6, 2], "Nothing was paid")


func test_pieces_cannot_cover_buildings() -> void:
	var state := _rich_state()
	state.build(&"barracks", Vector2i(4, 4))
	var piece := LandPiece.new(&"t", [Vector2i.ZERO] as Array[Vector2i], [&"forest"] as Array[StringName])
	check_eq(PlacementRules.check(state.board, piece, Vector2i(4, 4)), PlacementRules.Result.ON_BUILDING, "Barracks is protected")


func test_recruit_requires_barracks_and_resources() -> void:
	var state := _state()
	state.stockpile.add({&"food": 3, &"stone": 1, &"wood": 6})
	check_eq(state.recruit(&"swordsman"), RecruitmentRules.Result.NEEDS_BUILDING, "No barracks yet")
	state.stockpile.add({&"stone": 2})
	state.build(&"barracks", Vector2i(4, 4))
	check_eq(state.recruit(&"swordsman"), RecruitmentRules.Result.OK, "Recruit with barracks")
	check_eq(state.army.get_count(&"swordsman"), 1, "One swordsman")
	# Stone: 1 + 2 added, 2 for the barracks, 1 for the swordsman.
	check_eq([state.stockpile.get_amount(&"food"), state.stockpile.get_amount(&"stone")], [0, 0], "Paid 3 food, 1 stone")
	check_eq(state.recruit(&"swordsman"), RecruitmentRules.Result.CANNOT_AFFORD, "Out of food")
	check_eq(state.army.get_count(&"swordsman"), 1, "Failed recruit adds nobody")


func test_archers_need_forest() -> void:
	var state := _rich_state()
	state.build(&"barracks", Vector2i(4, 4))
	_paint(state.board, &"forest", [Vector2i(7, 4), Vector2i(7, 5)])
	check_eq(state.recruit(&"archer"), RecruitmentRules.Result.NEEDS_TERRAIN, "2 forest is not enough")
	_paint(state.board, &"forest", [Vector2i(7, 6)])
	check_eq(state.recruit(&"archer"), RecruitmentRules.Result.OK, "3 forest unlocks archers")
	var text := RecruitmentRules.describe(RecruitmentRules.Result.NEEDS_TERRAIN, units[2], buildings, terrains)
	check(text.contains("3 ô Rừng"), "Reason names the terrain (got '%s')" % text)


func test_upkeep_is_paid_each_turn() -> void:
	var state := _rich_state()
	state.build(&"barracks", Vector2i(4, 4))
	state.recruit(&"swordsman")
	state.recruit(&"spearman")
	check_eq(state.get_upkeep(), {&"food": 2}, "2 soldiers eat 2 food")
	_paint(state.board, &"farmland", [Vector2i(7, 4)])
	check_eq(state.get_net_income().get(&"food"), -1, "Net food = 1 farm - 2 upkeep")
	var food_before := state.stockpile.get_amount(&"food")
	var report := state.end_turn()
	check_eq(report.upkeep, {&"food": 2}, "Report shows upkeep")
	check(report.deserted.is_empty(), "Nobody deserts when fed")
	check_eq(state.stockpile.get_amount(&"food"), food_before + 1 - 2, "Stock = before + yield - upkeep")


func test_soldiers_desert_when_food_runs_out() -> void:
	var state := _state()
	state.stockpile.add({&"wood": 6, &"stone": 2})
	state.build(&"barracks", Vector2i(4, 4))
	state.army.add(&"swordsman", 3)
	state.army.add(&"spearman", 1)
	state.stockpile.add({&"food": 2})
	var report := state.end_turn()
	check_eq(report.deserted, {&"swordsman": 2}, "Largest group deserts first until upkeep fits")
	check_eq(state.army.get_total(), 2, "2 soldiers remain")
	check_eq(state.stockpile.get_amount(&"food"), 0, "All food went to upkeep")
	check_eq(report.upkeep, {&"food": 2}, "Paid upkeep for the remaining 2")
