extends "res://tests/test_suite.gd"

const TEST_FOLDER := "user://test_saves"

var terrains := TerrainLibrary.load_all()
var shapes := PieceShapeLibrary.load_all()


func _state(seed_value: int = 3) -> KingdomState:
	return _state_on(BoardData.create_starting_board(12), seed_value)


func _state_on(board: BoardData, seed_value: int) -> KingdomState:
	var gen := PieceGenerator.new(shapes, terrains, seed_value)
	return KingdomState.new(board, PieceHand.new(gen), terrains, BuildingData.load_all(), UnitData.load_all(), seed_value)


## A game with something in every part of the state.
func _busy_state() -> KingdomState:
	var state := _state()
	state.start()
	state.stockpile.add({&"food": 50, &"wood": 30, &"stone": 12})
	state.place_piece(0, Vector2i(3, 2))
	state.board.set_land(Vector2i(8, 8), &"forest", true)
	state.build(&"barracks", Vector2i(4, 7))
	state.army.add_squad(&"swordsman", 20)
	state.army.add_squad(&"archer", 7)
	state.diplomacy.change_relation(&"south_farmers", 50, Diplomacy.MEMORY_GIFT)
	state.alliances.propose_alliance(_low_rng(), &"south_farmers")
	state.diplomacy.propose(_low_rng(), &"east_merchants", &"wood", 5, &"food", 4, 10)
	state.wars.declare_war(&"north_wolves")
	state.wars.lose_soldiers(&"north_wolves", 25)
	state.wars.declare_war(&"west_fortress")
	state.wars.fronts[&"west_fortress"].strength = 1
	state.board.expand(state.wars.annex(&"west_fortress"), Wars.ANNEX_EXPANSION)
	state.diplomacy.threat = state.get_threat()
	state.end_turn()
	state.diplomacy.give_gift(state.stockpile, &"steppe_tribes", {&"food": 10} as Dictionary[StringName, int])
	return state


func _low_rng() -> RandomNumberGenerator:
	for seed_value in 10000:
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if probe.randf() < 0.01:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			return rng
	return RandomNumberGenerator.new()


## Loads to_save() data the way the game does: through JSON, onto a fresh state with a new seed.
func _reload(data: Dictionary, seed_value: int = 99) -> KingdomState:
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	var state := _state_on(BoardData.from_save(parsed.board), seed_value)
	state.load_save(parsed)
	return state


func _system() -> SaveSystem:
	var system := SaveSystem.new(TEST_FOLDER)
	for slot in SaveSystem.all_slots():
		system.delete(slot)
	return system


# --- Round trip ---------------------------------------------------------------------------

func test_save_and_load_give_the_same_game() -> void:
	var state := _busy_state()
	var saved := state.to_save()
	var loaded := _reload(saved)
	check_eq(JSON.stringify(loaded.to_save()), JSON.stringify(saved), "Saving the loaded game gives the same data")
	check_eq([loaded.board.width, loaded.board.height], [state.board.width, state.board.height], "Expanded board size")
	check_eq(loaded.turn, 2, "Turn")
	check_eq(loaded.army.count_soldiers(&"archer"), state.army.count_soldiers(&"archer"), "Squads")
	check(loaded.wars.at_war_with(&"north_wolves") and loaded.wars.fronts[&"west_fortress"].annexed, "Wars")
	check_eq(loaded.wars.fronts[&"north_wolves"].strength, state.wars.fronts[&"north_wolves"].strength, "Clan army")
	check(loaded.diplomacy.clans[&"south_farmers"].is_allied(), "Alliance")
	check_eq(loaded.diplomacy.clans[&"east_merchants"].relation, state.diplomacy.clans[&"east_merchants"].relation,
			"Relation rebuilt from its factors")
	check(loaded.diplomacy.get_agreement(&"east_merchants") != null, "Agreement")
	check_eq(loaded.diplomacy.clans[&"steppe_tribes"].gift_gain_this_turn, 3, "This turn's gift limit is kept (10 / 5 x 1.5)")
	check_eq(loaded.get_turn_yield(), state.get_turn_yield(), "Same income")


func test_loaded_hand_is_the_same_but_later_draws_reroll() -> void:
	var state := _state(5)
	state.start()
	var loaded := _reload(state.to_save(), 6)
	check_eq(JSON.stringify(loaded.hand.to_save()), JSON.stringify(state.hand.to_save()), "Hand kept")
	state.end_turn()
	loaded.end_turn()
	check(JSON.stringify(loaded.hand.to_save()) != JSON.stringify(state.hand.to_save()), "Next hand is drawn anew")


func test_loading_skips_content_that_no_longer_exists() -> void:
	var data := _busy_state().to_save()
	data.army.append({"unit": "dragon", "soldiers": 5})
	data.diplomacy.clans["lost_clan"] = {"wariness": 3, "memories": {}}
	data.wars["lost_clan"] = {"at_war": true}
	data.diplomacy.clans.erase("golden_eagle")
	var loaded := _reload(data)
	check_eq(loaded.army.count_squads(), 2, "Unknown unit type dropped")
	check(not loaded.diplomacy.clans.has(&"lost_clan"), "Unknown clan ignored")
	check_eq(loaded.diplomacy.clans[&"golden_eagle"].relation, 0, "Clan missing from the save keeps its start")


# --- Slots on disk ------------------------------------------------------------------------

func test_slots_save_list_and_load() -> void:
	var system := _system()
	check_eq(system.latest_slot(), "", "No saves yet")
	check(system.slot_info("slot_1").is_empty(), "Empty slot")
	var state := _busy_state()
	check_eq(system.save(state, "slot_1"), OK, "Saved")
	check_eq(system.save(state, "slot_1"), OK, "Overwriting works")
	var info := system.slot_info("slot_1")
	check_eq([info.turn, info.cells, info.soldiers], [2, state.board.count_owned_cells(), state.army.count_soldiers()], "Summary")
	check_eq(system.latest_slot(), "slot_1", "Latest")
	var result := system.load_slot("slot_1")
	check(result.has("game"), "Loads")
	check_eq(JSON.stringify(_reload(result.game).to_save()), JSON.stringify(state.to_save()), "Same game from disk")
	check(not FileAccess.file_exists(system.path("slot_1") + ".tmp"), "No temp file left")


func test_bad_and_newer_saves_are_refused() -> void:
	var system := _system()
	DirAccess.make_dir_recursive_absolute(TEST_FOLDER)
	var file := FileAccess.open(system.path("slot_2"), FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	check(system.load_slot("slot_2").has("error"), "Broken file")
	check(system.slot_info("slot_2").is_empty(), "Broken file shows as empty")
	file = FileAccess.open(system.path("slot_3"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"save_version": SaveSystem.SAVE_VERSION + 1, "summary": {}, "game": {}}))
	file.close()
	check(system.load_slot("slot_3").has("error"), "Newer version refused")
	check(system.load_slot("auto").has("error"), "Missing slot")
	_system()
