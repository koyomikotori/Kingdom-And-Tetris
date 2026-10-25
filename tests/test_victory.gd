extends "res://tests/test_suite.gd"

var terrains := TerrainLibrary.load_all()


func _state() -> KingdomState:
	var gen := PieceGenerator.new(PieceShapeLibrary.load_all(), terrains, 1)
	var state := KingdomState.new(BoardData.create_starting_board(12), PieceHand.new(gen), terrains,
			BuildingData.load_all(), UnitData.load_all(), 3)
	state.start()
	return state


func _annex(state: KingdomState, clan_ids: Array[StringName]) -> void:
	for clan_id in clan_ids:
		state.wars.fronts[clan_id].annexed = true
		state.diplomacy.clans[clan_id].annexed = true


func _ally(state: KingdomState, clan_ids: Array[StringName]) -> void:
	for clan_id in clan_ids:
		state.diplomacy.clans[clan_id].alliance_turns = 99


## 51 farmland, forest and hill cells each: +51 of every resource per turn.
func _prosperous(state: KingdomState) -> void:
	state.board.expand(Vector2i.RIGHT, 4)
	var plan: Array[StringName] = []
	for terrain_id: StringName in [&"farmland", &"forest", &"hill"]:
		for i in 51:
			plan.append(terrain_id)
	for cell in state.board.get_all_cells():
		if cell.building_id != BoardData.CASTLE_ID and not plan.is_empty():
			state.board.set_land(cell.coord, plan.pop_back(), false)


func _end_turns(state: KingdomState, count: int) -> int:
	var won := Victory.NO_PATH
	for i in count:
		var path := state.victory.end_turn(state)
		if path != Victory.NO_PATH:
			won = path
	return won


func test_conquest_wins_once_every_clan_is_annexed() -> void:
	var state := _state()
	_annex(state, [&"north_wolves", &"east_merchants", &"south_farmers", &"west_fortress", &"golden_eagle"])
	check_eq(state.victory.check(state), Victory.NO_PATH, "5 of 6")
	_annex(state, [&"steppe_tribes"])
	check_eq(state.victory.check(state), Victory.Path.CONQUEST, "All 6")
	check_eq(state.victory.check(state), Victory.NO_PATH, "Reported only once")
	check_eq(state.victory.won_path, Victory.Path.CONQUEST, "Remembered")


func test_prosperity_needs_allies_land_and_income_for_ten_turns() -> void:
	var state := _state()
	_prosperous(state)
	_annex(state, [&"north_wolves", &"west_fortress", &"golden_eagle", &"steppe_tribes", &"south_farmers"])
	var prosperity: Dictionary = state.victory.progress(state)[Victory.Path.PROSPERITY]
	check(not prosperity.met, "Rich, but the merchants are not allied")
	check_eq(prosperity.conditions.size(), 5, "Allies + land + 3 resources")
	_ally(state, [&"east_merchants"])
	check(state.victory.progress(state)[Victory.Path.PROSPERITY].met, "One ally is enough")
	check_eq(_end_turns(state, 9), Victory.NO_PATH, "Not yet")
	check_eq(state.victory.holds[Victory.Path.PROSPERITY], 9, "Counter")
	check_eq(_end_turns(state, 1), Victory.Path.PROSPERITY, "Held 10 turns")


func test_prosperity_needs_every_remaining_clan_allied_and_resets() -> void:
	var state := _state()
	_prosperous(state)
	_ally(state, [&"north_wolves", &"west_fortress", &"golden_eagle", &"steppe_tribes", &"south_farmers"])
	_end_turns(state, 12)
	check_eq(state.victory.holds[Victory.Path.PROSPERITY], 0, "The merchants are not allied")
	_ally(state, [&"east_merchants"])
	_end_turns(state, 5)
	state.diplomacy.clans[&"golden_eagle"].alliance_turns = 0
	_end_turns(state, 1)
	check_eq(state.victory.holds[Victory.Path.PROSPERITY], 0, "Losing an ally resets the count")


func test_prosperity_needs_land_and_income_too() -> void:
	var state := _state()
	_ally(state, [&"north_wolves", &"west_fortress", &"golden_eagle", &"steppe_tribes", &"south_farmers", &"east_merchants"])
	_end_turns(state, 12)
	check_eq(state.victory.holds[Victory.Path.PROSPERITY], 0, "Allied with everyone but small and poor")


func test_prosperity_progress_shows_what_is_missing() -> void:
	var state := _state()
	var prosperity: Dictionary = state.victory.progress(state)[Victory.Path.PROSPERITY]
	check(not prosperity.met, "Starting kingdom is not prosperous")
	check_eq([prosperity.conditions[0].current, prosperity.conditions[0].needed], [0, 6], "Allies 0/6")
	check_eq([prosperity.conditions[1].current, prosperity.conditions[1].needed], [16, 120], "Land 16/120")
	check(prosperity.fraction > 0.0 and prosperity.fraction < 0.2, "Some progress from the land")


func test_castle_falls_when_an_invasion_wins_with_no_land_left() -> void:
	var state := _state()
	state.wars.declare_war(&"north_wolves")
	var first := state.finish_invasion(&"north_wolves", _lost_battle(state))
	check(not first.castle_fallen and not state.victory.lost, "Land left: only cells are lost")
	state.board.lose_edge_cells(Vector2i.UP, 100)
	check(state.victory.castle_in_danger(state), "Warned")
	var second := state.finish_invasion(&"north_wolves", _lost_battle(state))
	check(second.castle_fallen and state.victory.lost, "Castle falls")
	check_eq(state.victory.check(state), Victory.NO_PATH, "No victory after a loss")
	check_eq(state.stats, {"battles_won": 0, "battles_lost": 2}, "Battles counted")


func _lost_battle(state: KingdomState) -> BattleRecord:
	var invaders := state.wars.create_clan_side(&"north_wolves", 40, state.units)
	var simulator := BattleSimulator.new(invaders, RaidSystem.create_kingdom_side(state), 1)
	while not simulator.finished:
		simulator.step()
	return simulator.record


func test_victory_state_is_saved() -> void:
	var state := _state()
	state.victory.holds[Victory.Path.PROSPERITY] = 4
	state.victory.won_path = Victory.Path.PROSPERITY
	state.stats.battles_won = 3
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_save()))
	var loaded := _state()
	loaded.load_save(data)
	check_eq(loaded.victory.holds, [0, 4] as Array[int], "Hold counters")
	check_eq(loaded.victory.won_path, Victory.Path.PROSPERITY, "Won path")
	check_eq(loaded.stats.battles_won, 3, "Stats")
	data.erase("victory")
	data.erase("stats")
	var old := _state()
	old.load_save(data)
	check_eq(old.victory.won_path, Victory.NO_PATH, "Saves from before M11a still load")
