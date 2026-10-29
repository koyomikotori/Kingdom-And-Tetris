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
	check(not buildings.has(&"stable"), "The stable became the farm")
	for id: StringName in [&"farm", &"lumber_mill", &"mine"]:
		check_eq(buildings[id].required_castle_level, 1, "%s from castle level 1" % id)
		check_eq(buildings[id].max_level(), 6, "%s has 6 levels" % id)
	check_eq(buildings[&"farm"].yields_at(1), {&"food": 5} as Dictionary[StringName, int], "Farm level 1")
	check_eq(buildings[&"farm"].yields_at(3), {&"food": 11, &"horses": 1} as Dictionary[StringName, int], "Farm level 3: horses")
	check_eq(buildings[&"lumber_mill"].yields_at(2), {&"wood": 8, &"hardwood": 1} as Dictionary[StringName, int], "Mill level 2")
	check_eq(buildings[&"mine"].yields_at(6), {&"stone": 17, &"ore": 5} as Dictionary[StringName, int], "Mine level 6")
	check_eq(buildings[&"barracks"].max_level(), 6, "Barracks have 6 levels (M13)")
	check_eq(CastleLevelData.load_all().size(), 6, "Six castle levels")


func test_production_buildings_need_their_terrain() -> void:
	var state := _state()
	_rich(state)
	state.board.set_land(Vector2i(4, 3), &"hill", false)
	check_eq(state.build(&"mine", Vector2i(4, 4)), BuildRules.Result.WRONG_TERRAIN, "Not on grass")
	check_eq(state.build(&"mine", Vector2i(4, 3)), BuildRules.Result.OK, "On a hill at castle level 1")
	state.board.set_land(Vector2i(5, 3), &"farmland", false)
	check_eq(state.build(&"farm", Vector2i(5, 3)), BuildRules.Result.OK, "Farm on farmland")


func test_buildings_add_production_doubled_on_key_cells() -> void:
	var state := _state()
	_rich(state)
	state.board.set_land(Vector2i(4, 3), &"hill", false)
	state.board.set_land(Vector2i(5, 3), &"hill", true)
	check(state.get_turn_yield().is_empty(), "No buildings, no production")
	state.build(&"mine", Vector2i(4, 3))
	state.build(&"mine", Vector2i(5, 3))
	check_eq(state.get_turn_yield().get(&"stone", 0), 4 + 8, "+4 stone (5 - 1 on its own cell), +8 on the key cell")
	var net := state.get_net_income()
	var sum := 0
	for entry: Dictionary in state.get_income_breakdown()[&"stone"]:
		check_eq(entry.source, &"production", "Stone comes from production")
		sum += entry.amount
	check_eq(sum, net[&"stone"], "Breakdown adds up")
	state.buildings_supplied = false
	check(state.get_turn_yield().is_empty(), "No production while upkeep is unpaid")


func test_buildings_level_up_with_the_castle() -> void:
	var state := _state()
	_rich(state)
	state.board.set_land(Vector2i(4, 3), &"hill", false)
	state.build(&"mine", Vector2i(4, 3))
	var origin := Vector2i(4, 3)
	check_eq(state.board.get_building_level(origin), 1, "Built at level 1")
	check_eq(state.check_building_upgrade(origin), KingdomState.UpgradeResult.CASTLE_TOO_LOW, "Castle level 1")
	check_eq(state.check_building_upgrade(Vector2i(5, 5)), KingdomState.UpgradeResult.NOT_UPGRADABLE, "Not the castle")
	state.upgrade_castle()
	var stock := state.stockpile.get_all()
	check_eq(state.upgrade_building(origin), KingdomState.UpgradeResult.OK, "Level 2")
	check_eq(stock[&"wood"] - state.stockpile.get_amount(&"wood"), 16, "2 × 8 wood")
	check_eq(stock[&"ore"], state.stockpile.get_amount(&"ore"), "No ore below level 3")
	check_eq(state.get_turn_yield(), {&"stone": 7, &"ore": 1} as Dictionary[StringName, int], "Level 2 output (8 - 1 stone)")
	check_eq(state.get_building_upkeep(), {&"food": 2} as Dictionary[StringName, int], "Upkeep +1 food per level")
	check_eq(state.upgrade_building(origin), KingdomState.UpgradeResult.CASTLE_TOO_LOW, "Never above the castle")
	state.upgrade_castle()
	check_eq(state.building_upgrade_cost(origin), {&"wood": 24, &"stone": 12, &"ore": 2, &"hardwood": 2} as Dictionary[StringName, int],
			"Level 3: 3 × cost + 2 ore + 2 hardwood")
	check_eq(state.upgrade_building(origin), KingdomState.UpgradeResult.OK, "Level 3")
	state.board.set_building_level(origin, 6)
	check_eq(state.check_building_upgrade(origin), KingdomState.UpgradeResult.MAX_LEVEL, "Six levels")


## The top bar refreshes on stockpile.changed: by then the new level must already count.
func test_paying_for_an_upgrade_sees_the_new_level() -> void:
	var state := _state()
	_rich(state)
	state.castle_level = 2
	state.board.set_land(Vector2i(4, 3), &"hill", true)
	state.build(&"mine", Vector2i(4, 3))
	var seen: Array[int] = []
	var watch := func() -> void: seen.append(state.get_turn_yield().get(&"stone", 0))
	state.stockpile.changed.connect(watch)
	state.upgrade_building(Vector2i(4, 3))
	# The lambda holds the state: disconnect it, or the cycle leaks at exit.
	state.stockpile.changed.disconnect(watch)
	check_eq(seen, [14] as Array[int], "Income seen while paying is the level 2 income ((8 - 1) × 2 on the key cell)")


func test_upgrades_need_resources() -> void:
	var state := _state()
	state.castle_level = 2
	state.board.set_land(Vector2i(4, 3), &"hill", false)
	state.board.place_building(&"mine", Vector2i(4, 3), Vector2i.ONE)
	check_eq(state.upgrade_building(Vector2i(4, 3)), KingdomState.UpgradeResult.CANNOT_AFFORD, "Empty stockpile")
	check_eq(state.board.get_building_level(Vector2i(4, 3)), 1, "Nothing changed")


func test_end_turn_collects_new_resources() -> void:
	var state := _state()
	_rich(state)
	state.castle_level = 2
	state.board.set_land(Vector2i(4, 3), &"forest", false)
	state.build(&"lumber_mill", Vector2i(4, 3))
	state.upgrade_building(Vector2i(4, 3))
	var hardwood := state.stockpile.get_amount(&"hardwood")
	state.end_turn()
	check_eq(state.stockpile.get_amount(&"hardwood"), hardwood + 1, "Hardwood from a level 2 mill")


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
	check_eq(state.board.get_building_cells(Vector2i(5, 5)).size(), 4, "The castle stays 2×2")


func test_castle_level_is_saved() -> void:
	var state := _state()
	_rich(state)
	state.upgrade_castle()
	state.upgrade_castle()
	check_eq(state.castle_level, 3, "Reached level 3")
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_save()))
	var loaded := _state()
	loaded.load_save(data)
	check_eq(loaded.castle_level, 3, "Level 3")
	data.erase("castle_level")
	var old := _state()
	old.load_save(data)
	check_eq(old.castle_level, 1, "Saves from before M11c start at level 1")


func test_building_levels_are_saved_and_old_stables_become_farms() -> void:
	var state := _state()
	state.castle_level = 3
	state.board.set_land(Vector2i(4, 3), &"farmland", false)
	state.board.place_building(&"farm", Vector2i(4, 3), Vector2i.ONE)
	state.board.set_building_level(Vector2i(4, 3), 3)
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_save()))
	var loaded := _state()
	loaded.load_save(data)
	loaded.board = BoardData.from_save(data.board)
	check_eq(loaded.board.get_building_level(Vector2i(4, 3)), 3, "Level kept")
	# A v2 save: stables, no levels.
	for cell: Dictionary in data.board.cells:
		if cell.building == "farm":
			cell.building = "stable"
		cell.erase("level")
	var upgraded := SaveSystem.migrate(data, 2)
	var board := BoardData.from_save(upgraded.board)
	check_eq(board.get_cell(Vector2i(4, 3)).building_id, &"farm", "Stable → farm")
	check_eq(board.get_building_level(Vector2i(4, 3)), 1, "Old buildings start at level 1")


# --- Building window actions --------------------------------------------------------------

func test_building_limits_grow_with_the_castle() -> void:
	var state := _state()
	_rich(state)
	for x in 5:
		state.board.set_land(Vector2i(x, 0), &"hill", false)
	for x in 3:
		check_eq(state.build(&"mine", Vector2i(x, 0)), BuildRules.Result.OK, "Mine %d" % (x + 1))
	check_eq(state.build(&"mine", Vector2i(3, 0)), BuildRules.Result.LIMIT_REACHED, "3 at castle level 1")
	check_eq(BuildRules.limit(state.buildings[&"barracks"], 4), 6, "Every building: +1 per castle level")
	state.upgrade_castle()
	check_eq(state.build(&"mine", Vector2i(3, 0)), BuildRules.Result.OK, "A fourth at level 2")
	check_eq(state.build(&"mine", Vector2i(4, 0)), BuildRules.Result.LIMIT_REACHED, "But not a fifth")


func test_demolishing_refunds_half_and_spares_the_castle() -> void:
	var state := _state()
	_rich(state)
	state.board.set_land(Vector2i(4, 3), &"hill", false)
	state.build(&"mine", Vector2i(4, 3))
	var wood := state.stockpile.get_amount(&"wood")
	check_eq(state.demolish(Vector2i(4, 3)), {&"wood": 4, &"stone": 2} as Dictionary[StringName, int], "Half of 8 wood, 4 stone")
	check_eq(state.stockpile.get_amount(&"wood"), wood + 4, "Refunded")
	check(not state.board.get_cell(Vector2i(4, 3)).has_building(), "Gone")
	check(state.demolish(Vector2i(5, 5)).is_empty(), "The castle stays")
	check_eq(state.board.get_cell(Vector2i(5, 5)).building_id, BoardData.CASTLE_ID, "Castle still there")


func test_moving_follows_the_building_rules_for_free() -> void:
	var state := _state()
	_rich(state)
	state.castle_level = 2
	state.board.set_land(Vector2i(4, 3), &"hill", false)
	state.board.set_land(Vector2i(7, 8), &"hill", true)
	state.build(&"mine", Vector2i(4, 3))
	state.upgrade_building(Vector2i(4, 3))
	var stock := state.stockpile.get_all()
	check_eq(state.move_building(Vector2i(4, 3), Vector2i(4, 5)), BuildRules.Result.WRONG_TERRAIN, "Not onto grass")
	check_eq(state.move_building(Vector2i(4, 3), Vector2i(0, 0)), BuildRules.Result.NOT_OWNED, "Not outside the land")
	check_eq(state.move_building(Vector2i(4, 3), Vector2i(5, 5)), BuildRules.Result.OCCUPIED, "Not onto the castle")
	check_eq(state.move_building(Vector2i(5, 5), Vector2i(7, 8)), BuildRules.Result.OCCUPIED, "The castle never moves")
	check_eq(state.move_building(Vector2i(4, 3), Vector2i(7, 8)), BuildRules.Result.OK, "Onto the key hill")
	check(not state.board.get_cell(Vector2i(4, 3)).has_building(), "Old cell free")
	check_eq(state.board.get_cell(Vector2i(7, 8)).building_id, &"mine", "Moved")
	check_eq(state.board.get_building_level(Vector2i(7, 8)), 2, "Keeps its level")
	check_eq(state.stockpile.get_all(), stock, "Free")
	check_eq(state.get_turn_yield().get(&"ore", 0), 2, "Level 2 ore, doubled on the key cell")


func test_fields_around_a_production_building() -> void:
	var state := _state()
	_rich(state)
	var farm := state.buildings[&"farm"]
	var origin := Vector2i(2, 2)
	state.board.set_land(origin, &"farmland", false)
	state.build(&"farm", origin)
	check_eq(state.get_turn_yield().get(&"food", 0), 4, "Alone: 5 - 1 on its own cell")
	state.board.set_land(Vector2i(1, 1), &"farmland", false)
	state.board.set_land(Vector2i(3, 2), &"farmland", true)
	state.board.set_land(Vector2i(2, 3), &"forest", false)
	check_eq(Economy.field_yield(state.board, farm, origin), {&"food": 2 + 4} as Dictionary[StringName, int],
			"+2 per farmland neighbor, +4 on a key cell, other terrain nothing")
	check_eq(state.get_turn_yield().get(&"food", 0), 4 + 6, "Fields come on top")
	check_eq(Economy.cell_field_yield(state.board, state.buildings, Vector2i(3, 2)), {&"food": 4} as Dictionary[StringName, int],
			"The cell info shows what a field gives")
	# A second farm two cells away shares the field between them.
	state.board.set_land(Vector2i(4, 2), &"farmland", false)
	state.build(&"farm", Vector2i(4, 2))
	check_eq(Economy.field_yield(state.board, farm, Vector2i(4, 2)), {&"food": 4} as Dictionary[StringName, int],
			"The key field feeds the other farm too")
	check_eq(Economy.cell_field_yield(state.board, state.buildings, Vector2i(3, 2)), {&"food": 8} as Dictionary[StringName, int],
			"…and the cell says so")
	# A building on a neighbor cell, or land outside the territory, is no field.
	state.board.set_land(Vector2i(1, 2), &"farmland", false)
	state.board.place_building(&"watchtower", Vector2i(1, 2), Vector2i.ONE)
	state.board.get_cell(Vector2i(1, 1)).owned = false
	check_eq(Economy.field_yield(state.board, farm, origin), {&"food": 4} as Dictionary[StringName, int],
			"Built-on and unowned cells give nothing")
	state.board.set_construction(Vector2i(4, 2), 2, true)
	check_eq(Economy.cell_field_yield(state.board, state.buildings, Vector2i(3, 2)), {&"food": 4} as Dictionary[StringName, int],
			"A building under construction takes no fields")


func test_placement_preview_counts_fields() -> void:
	var state := _state()
	_rich(state)
	var terrains := state.terrains
	state.board.set_land(Vector2i(4, 3), &"hill", false)
	state.build(&"mine", Vector2i(4, 3))
	var piece := LandPiece.new(&"test", [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i],
			[&"hill", &"forest"] as Array[StringName], 0)
	var delta := Economy.placement_delta(state.board, piece, Vector2i(5, 3), terrains, state.buildings)
	check_eq(delta, {&"stone": 4} as Dictionary[StringName, int], "A key hill next to the mine: +4 stone")
	check(Economy.placement_delta(state.board, piece, Vector2i(5, 3), terrains).is_empty(), "Without buildings: land alone")
