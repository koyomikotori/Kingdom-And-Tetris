extends "res://tests/test_suite.gd"

var terrains := TerrainLibrary.load_all()


func _piece(offsets: Array[Vector2i], terrain: StringName, key_index: int = LandPiece.NO_KEY) -> LandPiece:
	var piece_terrains: Array[StringName] = []
	for i in offsets.size():
		piece_terrains.append(terrain)
	return LandPiece.new(&"test", offsets, piece_terrains, key_index)


func _row(length: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in length:
		result.append(Vector2i(x, 0))
	return result


func _state(seed_value: int = 3) -> KingdomState:
	var gen := PieceGenerator.new(PieceShapeLibrary.load_all(), terrains, seed_value)
	return KingdomState.new(BoardData.create_starting_board(12), PieceHand.new(gen), terrains)


func test_terrain_yields_from_data() -> void:
	check_eq(Economy.cell_yield(terrains[&"farmland"], false), {&"food": 1}, "Farmland gives 1 food")
	check_eq(Economy.cell_yield(terrains[&"forest"], false), {&"wood": 1}, "Forest gives 1 wood")
	check_eq(Economy.cell_yield(terrains[&"hill"], false), {&"stone": 1}, "Hill gives 1 stone")
	check(Economy.cell_yield(terrains[&"grass"], false).is_empty(), "Grass gives nothing")
	check(Economy.cell_yield(null, false).is_empty(), "Empty land gives nothing")


func test_resource_types_loaded_in_order() -> void:
	var ids := ResourceTypeData.load_all().map(func(t: ResourceTypeData) -> StringName: return t.resource_id)
	check_eq(ids, [&"food", &"wood", &"stone", &"ore", &"hardwood", &"horses"], "Resource bar order")


func test_key_cell_doubles_yield() -> void:
	check_eq(Economy.cell_yield(terrains[&"farmland"], true), {&"food": 2}, "Key farmland gives 2 food")
	check(Economy.cell_yield(terrains[&"grass"], true).is_empty(), "Key grass still gives nothing")


func test_starting_board_yields_nothing() -> void:
	check(Economy.board_yield(BoardData.create_starting_board(12), terrains).is_empty(), "All-grass start yields nothing")


func test_overwrite_example_from_gdd() -> void:
	var board := BoardData.create_starting_board(12)
	PlacementRules.apply(board, _piece(_row(4), &"farmland"), Vector2i(4, 4))
	check_eq(Economy.board_yield(board, terrains), {&"food": 4}, "4 farmland = 4 food")
	PlacementRules.apply(board, _piece(_row(1), &"forest"), Vector2i(5, 4))
	check_eq(Economy.board_yield(board, terrains), {&"food": 3, &"wood": 1}, "Forest over one farm = 3 food + 1 wood")


func test_unowned_cells_do_not_yield() -> void:
	var board := BoardData.create_starting_board(12)
	board.set_terrain(Vector2i(0, 0), &"forest")
	check(Economy.board_yield(board, terrains).is_empty(), "Terrain outside the territory yields nothing")


func test_placement_delta_matches_real_change() -> void:
	var board := BoardData.create_starting_board(12)
	PlacementRules.apply(board, _piece(_row(4), &"farmland"), Vector2i(4, 4))
	# Hill bar with a key cell, half over farms (6,4),(7,4) and half on new land (8,4).
	var piece := _piece(_row(3), &"hill", 2)
	var predicted := Economy.placement_delta(board, piece, Vector2i(6, 4), terrains)
	check_eq(predicted, {&"food": -2, &"stone": 4}, "Predicted: lose 2 food, gain 1+1+2 stone")
	var before := Economy.board_yield(board, terrains)
	PlacementRules.apply(board, piece, Vector2i(6, 4))
	var after := Economy.board_yield(board, terrains)
	for id in [&"food", &"wood", &"stone"]:
		check_eq(after.get(id, 0) - before.get(id, 0), predicted.get(id, 0), "Delta of %s matches" % id)


func test_stockpile_spend_is_all_or_nothing() -> void:
	var stock := Stockpile.new()
	stock.add({&"food": 5, &"wood": 2})
	check(stock.can_afford({&"food": 5}), "Can afford exact amount")
	check(not stock.spend({&"food": 3, &"wood": 3}), "Cannot spend more wood than held")
	check_eq([stock.get_amount(&"food"), stock.get_amount(&"wood")], [5, 2], "Failed spend changes nothing")
	check(stock.spend({&"food": 3, &"wood": 2}), "Affordable spend succeeds")
	check_eq([stock.get_amount(&"food"), stock.get_amount(&"wood")], [2, 0], "Spend subtracts")
	check_eq(stock.get_amount(&"stone"), 0, "Unknown resource is 0")


func test_end_turn_collects_and_deals_new_hand() -> void:
	var state := _state()
	state.start()
	check_eq(state.turn, 1, "Game starts on turn 1")
	check_eq(state.hand.pieces.size(), 3, "First hand has 3 pieces")
	PlacementRules.apply(state.board, _piece(_row(2), &"forest", 0), Vector2i(4, 4))
	var old_pieces := state.hand.pieces.duplicate()
	var report := state.end_turn()
	check_eq(report.collected, {&"wood": 3}, "Collected 2 (key) + 1 wood")
	check_eq(state.stockpile.get_amount(&"wood"), 3, "Stockpile received the yield")
	check_eq(state.turn, 2, "Turn advanced")
	check_eq(state.hand.pieces.size(), 3, "New hand has 3 pieces")
	for piece in state.hand.pieces:
		check(not old_pieces.has(piece), "Unplaced pieces were discarded, not kept")
	state.end_turn()
	check_eq(state.stockpile.get_amount(&"wood"), 6, "Yield is collected again every turn")


func test_place_piece_consumes_only_on_success() -> void:
	var state := _state()
	state.start()
	var bad := state.place_piece(0, Vector2i(0, 0))
	check(bad != PlacementRules.Result.OK, "Far-away placement fails")
	check_eq(state.hand.pieces.size(), 3, "Failed placement keeps the piece")
	# The piece is random, so search the board for any valid origin.
	var placed := false
	for y in range(0, 12):
		for x in range(0, 12):
			if not placed and state.place_piece(0, Vector2i(x, y)) == PlacementRules.Result.OK:
				placed = true
	check(placed, "Some valid spot exists for the first piece")
	check_eq(state.hand.pieces.size(), 2, "Successful placement uses the piece")
