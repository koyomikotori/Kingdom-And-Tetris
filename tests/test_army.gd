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
		check(unit.squad_size > 0 and unit.melee_attack > 0 and unit.morale > 0, "%s has combat stats" % unit.unit_id)


func test_build_barracks_pays_cost() -> void:
	var state := _rich_state()
	check_eq(state.build(&"barracks", Vector2i(4, 4)), BuildRules.Result.OK, "Barracks on own grass")
	check_eq(state.board.get_cell(Vector2i(4, 4)).building_id, &"barracks", "Cell holds the barracks")
	check_eq([state.stockpile.get_amount(&"wood"), state.stockpile.get_amount(&"stone")], [44, 48], "Paid 6 wood, 2 stone")
	check_eq(state.build(&"barracks", Vector2i(7, 7)), BuildRules.Result.OK, "Second barracks")
	check_eq(state.build(&"barracks", Vector2i(4, 7)), BuildRules.Result.OK, "Third barracks")
	check_eq(state.build(&"barracks", Vector2i(7, 4)), BuildRules.Result.LIMIT_REACHED, "At most three barracks")


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
	check_eq(state.army.count_squads(&"swordsman"), 1, "One swordsman squad")
	check_eq(state.army.count_soldiers(&"swordsman"), 20, "A squad brings 20 swordsmen")
	# Stone: 1 + 2 added, 2 for the barracks, 1 for the swordsman.
	check_eq([state.stockpile.get_amount(&"food"), state.stockpile.get_amount(&"stone")], [0, 0], "Paid 3 food, 1 stone")
	check_eq(state.recruit(&"swordsman"), RecruitmentRules.Result.CANNOT_AFFORD, "Out of food")
	check_eq(state.army.count_squads(), 1, "Failed recruit adds nobody")


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
	check_eq(state.get_upkeep(), {&"food": 2}, "2 squads eat 2 food")
	_paint(state.board, &"farmland", [Vector2i(7, 4)])
	state.build(&"farm", Vector2i(7, 4))
	check_eq(state.get_net_income().get(&"food"), 3, "Net food = 5 from the farm - 2 upkeep")
	var food_before := state.stockpile.get_amount(&"food")
	var report := state.end_turn()
	check_eq(report.upkeep, {&"food": 2}, "Report shows upkeep")
	check(report.deserted.is_empty(), "Nobody deserts when fed")
	check_eq(state.stockpile.get_amount(&"food"), food_before + 5 - 2, "Stock = before + yield - upkeep")


func test_squads_desert_when_food_runs_out() -> void:
	var state := _state()
	state.army.add_squad(&"swordsman", 20)
	state.army.add_squad(&"spearman", 20)
	state.army.add_squad(&"swordsman", 7)
	state.army.add_squad(&"archer", 15)
	state.stockpile.add({&"food": 2})
	var report := state.end_turn()
	check_eq(report.deserted, {&"archer": 15, &"swordsman": 7}, "Most recently recruited squads leave first")
	check_eq(state.army.count_squads(), 2, "2 squads remain")
	check_eq(state.army.count_soldiers(), 40, "The two full squads stay")
	check_eq(state.stockpile.get_amount(&"food"), 0, "All food went to upkeep")


func test_army_squads() -> void:
	var army := Army.new()
	army.add_squad(&"swordsman", 20)
	army.add_squad(&"swordsman", 12)
	army.add_squad(&"archer", 0)
	check_eq([army.count_squads(), army.count_soldiers(&"swordsman")], [2, 32], "Empty squads are ignored")
	army.set_soldiers(army.squads[1], 0)
	check_eq(army.count_squads(), 1, "A squad reduced to 0 is removed")


func test_squad_capacity_from_castle_and_barracks() -> void:
	var state := _rich_state()
	check_eq(state.get_squad_capacity(), 2, "Castle garrison: 2 squads")
	state.build(&"barracks", Vector2i(4, 4))
	check_eq(state.get_squad_capacity(), 6, "Barracks adds 4")
	state.build(&"barracks", Vector2i(7, 7))
	check_eq(state.get_squad_capacity(), 10, "Second barracks adds 4 more")


func test_recruit_stops_at_capacity() -> void:
	var state := _rich_state()
	state.stockpile.add({&"food": 100, &"stone": 100})
	state.build(&"barracks", Vector2i(4, 4))
	for i in 6:
		check_eq(state.recruit(&"spearman"), RecruitmentRules.Result.OK, "Recruit squad %d of 6" % (i + 1))
	var food := state.stockpile.get_amount(&"food")
	check_eq(state.recruit(&"spearman"), RecruitmentRules.Result.ARMY_FULL, "Seventh squad refused")
	check_eq([state.army.count_squads(), state.stockpile.get_amount(&"food")], [6, food], "Refusal adds and charges nothing")
	state.disband(state.army.squads[0])
	check_eq(state.recruit(&"spearman"), RecruitmentRules.Result.OK, "Disbanding frees a slot")


func test_replenish_is_free_and_needs_barracks() -> void:
	var state := _state()
	state.army.add_squad(&"swordsman", 5)
	state.army.add_squad(&"archer", 14)
	state.stockpile.add({&"food": 10})
	var report := state.end_turn()
	check(report.replenished.is_empty(), "No barracks: no replenishment")
	check_eq(state.army.squads[0].soldiers, 5, "Squad unchanged")
	state.stockpile.add({&"wood": 6, &"stone": 2})
	state.build(&"barracks", Vector2i(4, 4))
	var food_before := state.stockpile.get_amount(&"food")
	report = state.end_turn()
	check_eq(report.replenished, {&"swordsman": 5, &"archer": 1}, "25% of 20 = +5; archer only needs 1")
	check_eq([state.army.squads[0].soldiers, state.army.squads[1].soldiers], [10, 15], "Squads grew, never past full size")
	check_eq(state.stockpile.get_amount(&"food"), food_before - 2, "Only the usual upkeep was paid")
	for i in 3:
		state.stockpile.add({&"food": 2})
		state.end_turn()
	check_eq(state.army.squads[0].soldiers, 20, "Back to full strength after a few turns")


func test_disband_removes_squad_and_its_upkeep() -> void:
	var state := _state()
	state.army.add_squad(&"swordsman", 3)
	state.army.add_squad(&"spearman", 20)
	state.disband(state.army.squads[0])
	check_eq(state.army.count_squads(), 1, "One squad left")
	check_eq(state.army.squads[0].unit_id, &"spearman", "The right squad was removed")
	check_eq(state.get_army_upkeep(), {&"food": 1}, "Upkeep drops with it")
