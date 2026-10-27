extends "res://tests/test_suite.gd"
## M12d: building and upgrading take turns, builder teams, cancelling (GDD §8).

var terrains := TerrainLibrary.load_all()


func _state() -> KingdomState:
	KingdomState.instant_construction = false
	var gen := PieceGenerator.new(PieceShapeLibrary.load_all(), terrains, 1)
	var state := KingdomState.new(BoardData.create_starting_board(12), PieceHand.new(gen), terrains,
			BuildingData.load_all(), UnitData.load_all(), 3)
	state.start()
	state.stockpile.add({&"food": 900, &"wood": 900, &"stone": 900, &"ore": 200, &"hardwood": 200, &"horses": 200})
	# Owned rows of grass (y 2), forest (y 9) and farmland (y 10) around the castle.
	for x in range(2, 10):
		state.board.set_land(Vector2i(x, 2), &"grass", false)
		state.board.set_land(Vector2i(x, 9), &"forest", false)
		state.board.set_land(Vector2i(x, 10), &"farmland", false)
	return state


func _done() -> void:
	KingdomState.instant_construction = true


func test_a_new_building_works_only_once_finished() -> void:
	var state := _state()
	check_eq(state.build(&"lumber_mill", Vector2i(2, 9)), BuildRules.Result.OK, "Foundation laid")
	var cell := state.board.get_cell(Vector2i(2, 9))
	check_eq(cell.building_turns, 2, "Mills take 2 turns")
	check(state.get_turn_yield().is_empty(), "A foundation produces nothing")
	check(state.get_building_upkeep().is_empty(), "…and costs no upkeep")
	check_eq(state.board.count_buildings(&"lumber_mill"), 0, "Not counted for effects")
	check_eq(state.board.count_buildings(&"lumber_mill", true), 1, "Counted for the limit")
	var report := state.end_turn()
	check_eq(cell.building_turns, 1, "One turn closer")
	check(report.completed.is_empty(), "Not finished yet")
	report = state.end_turn()
	check_eq(cell.building_turns, 0, "Finished")
	check_eq(report.completed.size(), 1, "Reported as finished")
	check(not state.get_turn_yield().is_empty(), "Produces from now on")
	_done()


func test_watchtowers_take_one_turn_and_barracks_count_after_building() -> void:
	var state := _state()
	state.build(&"watchtower", Vector2i(2, 2))
	check_eq(state.board.get_cell(Vector2i(2, 2)).building_turns, 1, "Towers take 1 turn")
	state.build(&"barracks", Vector2i(3, 2))
	var capacity := state.get_squad_capacity()
	state.end_turn()
	state.end_turn()
	check(state.get_squad_capacity() > capacity, "The barracks adds squad room once finished")
	_done()


func test_upgrades_stop_the_building_and_take_the_new_level_in_turns() -> void:
	var state := _state()
	state.upgrade_castle()
	state.end_turn()
	state.end_turn()
	state.end_turn()
	check_eq(state.castle_level, 2, "The castle reached level 2 after 3 turns")
	state.build(&"lumber_mill", Vector2i(2, 9))
	state.end_turn()
	state.end_turn()
	check_eq(state.upgrade_building(Vector2i(2, 9)), KingdomState.UpgradeResult.OK, "Upgrade started")
	var cell := state.board.get_cell(Vector2i(2, 9))
	check_eq([cell.building_level, cell.building_turns, cell.building_upgrading], [1, 2, true], "Level 2 takes 2 turns")
	check(state.get_turn_yield().is_empty(), "No production while upgrading")
	check_eq(state.check_building_upgrade(Vector2i(2, 9)), KingdomState.UpgradeResult.UNDER_CONSTRUCTION,
			"One upgrade at a time")
	check_eq(state.move_building(Vector2i(2, 9), Vector2i(3, 9)), BuildRules.Result.UNDER_CONSTRUCTION, "Cannot move")
	state.end_turn()
	state.end_turn()
	check_eq([cell.building_level, cell.building_turns], [2, 0], "Level 2 now")
	_done()


func test_the_castle_keeps_its_level_while_upgrading() -> void:
	var state := _state()
	check_eq(state.castle_upgrade_turns(), 3, "Level 2 takes 2 + 1 turns")
	check_eq(state.upgrade_castle(), KingdomState.CastleResult.OK, "Upgrade started")
	check_eq([state.castle_level, state.castle_turns], [1, 3], "Still level 1")
	check_eq(state.check_castle_upgrade(), KingdomState.CastleResult.IN_PROGRESS, "Already upgrading")
	var stone := state.stockpile.get_amount(&"stone")
	var refund := state.cancel_castle_upgrade()
	check(not refund.is_empty() and state.stockpile.get_amount(&"stone") > stone, "Half the cost back")
	check_eq([state.castle_level, state.castle_turns], [1, 0], "Called off")
	_done()


func test_builder_teams_follow_the_castle_level() -> void:
	var state := _state()
	check_eq(state.builder_limit(), 2, "1 + castle level")
	check_eq(state.build(&"watchtower", Vector2i(2, 2)), BuildRules.Result.OK, "First team")
	check_eq(state.build(&"farm", Vector2i(3, 10)), BuildRules.Result.OK, "Second team")
	check_eq(state.builders_busy(), 2, "Both teams busy")
	check_eq(state.build(&"farm", Vector2i(4, 10)), BuildRules.Result.NO_BUILDERS, "No team left")
	check_eq(state.check_castle_upgrade(), KingdomState.CastleResult.NO_BUILDERS, "The castle needs a team too")
	state.end_turn()
	check_eq(state.builders_busy(), 1, "The tower is done")
	check_eq(state.build(&"farm", Vector2i(4, 10)), BuildRules.Result.OK, "A team is free again")
	_done()


func test_demolishing_or_cancelling_gives_half_back() -> void:
	var state := _state()
	state.build(&"farm", Vector2i(2, 10))
	var wood := state.stockpile.get_amount(&"wood")
	var refund := state.demolish(Vector2i(2, 10))
	check_eq(refund, state.demolish_refund(&"farm"), "Half the farm's cost")
	check_eq(state.stockpile.get_amount(&"wood"), wood + refund.get(&"wood", 0), "Paid back")
	check(not state.board.get_cell(Vector2i(2, 10)).has_building(), "Foundation gone")
	state.upgrade_castle()
	KingdomState.instant_construction = true
	state.cancel_castle_upgrade()
	state.upgrade_castle()
	state.build(&"farm", Vector2i(2, 10))
	KingdomState.instant_construction = false
	state.upgrade_building(Vector2i(2, 10))
	refund = state.demolish(Vector2i(2, 10))
	var cell := state.board.get_cell(Vector2i(2, 10))
	check(not refund.is_empty(), "Half the upgrade's cost back")
	check(cell.building_id == &"farm" and cell.building_level == 1 and not cell.is_constructing(),
			"Cancelling an upgrade keeps the building at its level")
	_done()


func test_construction_is_saved_and_old_saves_are_finished() -> void:
	var state := _state()
	state.build(&"farm", Vector2i(2, 10))
	state.upgrade_castle()
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_save()))
	var board := BoardData.from_save(data.board)
	check_eq(board.get_cell(Vector2i(2, 10)).building_turns, 2, "Turns left kept")
	var loaded := KingdomState.new(board, PieceHand.new(PieceGenerator.new(PieceShapeLibrary.load_all(), terrains, 1)),
			terrains, BuildingData.load_all(), UnitData.load_all(), 3)
	loaded.load_save(data)
	check_eq(loaded.castle_turns, 3, "Castle upgrade kept")
	for entry: Dictionary in data.board.cells:
		entry.erase("turns")
		entry.erase("upgrading")
	data.erase("castle_turns")
	var old := BoardData.from_save(data.board)
	check(not old.get_cell(Vector2i(2, 10)).is_constructing(), "Old saves: buildings are finished")
	_done()


func test_buildings_have_categories() -> void:
	var buildings := BuildingData.load_all()
	check_eq(buildings[&"barracks"].category, BuildingData.Category.MILITARY, "Barracks: military")
	check_eq(buildings[&"watchtower"].category, BuildingData.Category.ADMIN, "Watchtower: administration")
	check_eq(buildings[&"farm"].category, BuildingData.Category.PRODUCTION, "Farm: production")


func test_construction_art_exists() -> void:
	check(GameArt.construction("foundation") != null and GameArt.construction("scaffold") != null, "Foundation and scaffold")
	for turns in range(1, 8):
		check(GameArt.turns_badge(turns) != null, "Turns plate %d" % turns)
