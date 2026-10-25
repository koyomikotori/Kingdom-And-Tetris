extends "res://tests/test_suite.gd"

var terrains := TerrainLibrary.load_all()


func _state() -> KingdomState:
	var gen := PieceGenerator.new(PieceShapeLibrary.load_all(), terrains, 1)
	var state := KingdomState.new(BoardData.create_starting_board(12), PieceHand.new(gen), terrains,
			BuildingData.load_all(), UnitData.load_all(), 3)
	state.start()
	return state


func _rich(state: KingdomState) -> void:
	state.stockpile.add({&"food": 500, &"wood": 500, &"stone": 500, &"ore": 500, &"hardwood": 500, &"horses": 500})


func test_new_resources_and_buildings_load() -> void:
	var types := ResourceTypeData.load_all()
	var basic := types.filter(func(t: ResourceTypeData) -> bool: return t.basic).map(
			func(t: ResourceTypeData) -> StringName: return t.resource_id)
	check_eq(basic, [&"food", &"wood", &"stone"], "Basic resources")
	var buildings := BuildingData.load_all()
	check_eq([buildings[&"mine"].required_castle_level, buildings[&"lumber_mill"].required_castle_level,
			buildings[&"stable"].required_castle_level], [2, 2, 3], "Castle levels needed")
	check_eq(CastleLevelData.load_all().size(), 6, "Six castle levels")


func test_production_buildings_need_the_castle_level_and_their_terrain() -> void:
	var state := _state()
	_rich(state)
	state.board.set_land(Vector2i(4, 4), &"hill", false)
	check_eq(state.build(&"mine", Vector2i(4, 4)), BuildRules.Result.CASTLE_TOO_LOW, "Castle level 1")
	state.upgrade_castle()
	check_eq(state.build(&"mine", Vector2i(4, 5)), BuildRules.Result.WRONG_TERRAIN, "Not on grass")
	check_eq(state.build(&"mine", Vector2i(4, 4)), BuildRules.Result.OK, "On a hill at level 2")
	state.board.set_land(Vector2i(7, 4), &"farmland", false)
	check_eq(state.build(&"stable", Vector2i(7, 4)), BuildRules.Result.CASTLE_TOO_LOW, "Stables need level 3")


func test_buildings_add_production_doubled_on_key_cells() -> void:
	var state := _state()
	_rich(state)
	state.upgrade_castle()
	state.board.set_land(Vector2i(4, 4), &"hill", false)
	state.board.set_land(Vector2i(7, 4), &"hill", true)
	var before := state.get_turn_yield()
	state.build(&"mine", Vector2i(4, 4))
	state.build(&"mine", Vector2i(7, 4))
	var after := state.get_turn_yield()
	check_eq(after.get(&"stone", 0) - before.get(&"stone", 0), 2 + 4, "+2 stone, +4 on the key cell")
	check_eq(after.get(&"ore", 0), 1 + 2, "+1 ore, +2 on the key cell")
	var net := state.get_net_income()
	var sum := 0
	for entry: Dictionary in state.get_income_breakdown()[&"ore"]:
		check_eq(entry.source, &"production", "Ore comes from production")
		sum += entry.amount
	check_eq(sum, net[&"ore"], "Breakdown adds up")
	state.buildings_supplied = false
	check_eq(state.get_turn_yield().get(&"ore", 0), 0, "No production while upkeep is unpaid")


func test_end_turn_collects_new_resources() -> void:
	var state := _state()
	_rich(state)
	state.upgrade_castle()
	state.board.set_land(Vector2i(4, 4), &"forest", false)
	state.build(&"lumber_mill", Vector2i(4, 4))
	var hardwood := state.stockpile.get_amount(&"hardwood")
	state.end_turn()
	check_eq(state.stockpile.get_amount(&"hardwood"), hardwood + 1, "Hardwood collected")


func test_castle_upgrades_cost_and_add_squad_room() -> void:
	var state := _state()
	check_eq(state.check_castle_upgrade(), KingdomState.CastleResult.CANNOT_AFFORD, "Level 2 costs wood and stone")
	check_eq(state.upgrade_castle(), KingdomState.CastleResult.CANNOT_AFFORD, "Nothing happens")
	check_eq(state.castle_level, 1, "Still level 1")
	var capacity := state.get_squad_capacity()
	state.stockpile.add({&"wood": 20, &"stone": 20})
	check_eq(state.upgrade_castle(), KingdomState.CastleResult.OK, "Level 2")
	check_eq([state.stockpile.get_amount(&"wood"), state.stockpile.get_amount(&"stone")], [0, 0], "Paid 20 + 20")
	check_eq(state.get_squad_capacity(), capacity + 1, "+1 squad")
	_rich(state)
	for i in 4:
		state.upgrade_castle()
	check_eq(state.castle_level, 6, "Top level")
	check_eq(state.get_squad_capacity(), capacity + 5, "+1 per level")
	check_eq(state.upgrade_castle(), KingdomState.CastleResult.MAX_LEVEL, "No level 7")


func test_castle_level_is_saved() -> void:
	var state := _state()
	_rich(state)
	state.upgrade_castle()
	state.upgrade_castle()
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_save()))
	var loaded := _state()
	loaded.load_save(data)
	check_eq(loaded.castle_level, 3, "Level 3")
	data.erase("castle_level")
	var old := _state()
	old.load_save(data)
	check_eq(old.castle_level, 1, "Saves from before M11c start at level 1")


# --- Building window actions --------------------------------------------------------------

func test_production_buildings_are_limited() -> void:
	var state := _state()
	_rich(state)
	state.upgrade_castle()
	for x in 4:
		state.board.set_land(Vector2i(x, 0), &"hill", false)
	for x in 3:
		check_eq(state.build(&"mine", Vector2i(x, 0)), BuildRules.Result.OK, "Mine %d" % (x + 1))
	check_eq(state.build(&"mine", Vector2i(3, 0)), BuildRules.Result.LIMIT_REACHED, "No fourth mine")


func test_demolishing_refunds_half_and_spares_the_castle() -> void:
	var state := _state()
	_rich(state)
	state.upgrade_castle()
	state.board.set_land(Vector2i(4, 4), &"hill", false)
	state.build(&"mine", Vector2i(4, 4))
	var wood := state.stockpile.get_amount(&"wood")
	check_eq(state.demolish(Vector2i(4, 4)), {&"wood": 4, &"stone": 2} as Dictionary[StringName, int], "Half of 8 wood, 4 stone")
	check_eq(state.stockpile.get_amount(&"wood"), wood + 4, "Refunded")
	check(not state.board.get_cell(Vector2i(4, 4)).has_building(), "Gone")
	check(state.demolish(Vector2i(5, 5)).is_empty(), "The castle stays")
	check_eq(state.board.get_cell(Vector2i(5, 5)).building_id, BoardData.CASTLE_ID, "Castle still there")


func test_moving_follows_the_building_rules_for_free() -> void:
	var state := _state()
	_rich(state)
	state.upgrade_castle()
	state.board.set_land(Vector2i(4, 4), &"hill", false)
	state.board.set_land(Vector2i(7, 7), &"hill", true)
	state.build(&"mine", Vector2i(4, 4))
	var stock := state.stockpile.get_all()
	check_eq(state.move_building(Vector2i(4, 4), Vector2i(4, 5)), BuildRules.Result.WRONG_TERRAIN, "Not onto grass")
	check_eq(state.move_building(Vector2i(4, 4), Vector2i(0, 0)), BuildRules.Result.NOT_OWNED, "Not outside the land")
	check_eq(state.move_building(Vector2i(4, 4), Vector2i(5, 5)), BuildRules.Result.OCCUPIED, "Not onto the castle")
	check_eq(state.move_building(Vector2i(5, 5), Vector2i(7, 7)), BuildRules.Result.OCCUPIED, "The castle never moves")
	check_eq(state.move_building(Vector2i(4, 4), Vector2i(7, 7)), BuildRules.Result.OK, "Onto the key hill")
	check(not state.board.get_cell(Vector2i(4, 4)).has_building(), "Old cell free")
	check_eq(state.board.get_cell(Vector2i(7, 7)).building_id, &"mine", "Moved")
	check_eq(state.stockpile.get_all(), stock, "Free")
	check_eq(state.get_turn_yield().get(&"ore", 0), 2, "Now doubled on the key cell")
