extends "res://tests/test_suite.gd"


func _piece(offsets: Array[Vector2i], terrain: StringName = &"forest", key_index: int = LandPiece.NO_KEY) -> LandPiece:
	var terrains: Array[StringName] = []
	for i in offsets.size():
		terrains.append(terrain)
	return LandPiece.new(&"test", offsets, terrains, key_index)


## Snapshot of everything placement may change, to prove failed placements change nothing.
func _snapshot(board: BoardData) -> Array:
	var result := []
	for cell in board.get_all_cells():
		result.append([cell.terrain_id, cell.owned, cell.is_key, cell.building_id])
	return result


func test_orientation_counts() -> void:
	var shapes := PieceShapeLibrary.load_all()
	var expected := {&"single": 1, &"bar2": 2, &"bar3": 2, &"square": 1, &"l_left": 4, &"l_right": 4}
	for id in expected:
		check(shapes.has(id), "Shape '%s' is loaded" % id)
		if shapes.has(id):
			check_eq(shapes[id].get_orientations().size(), expected[id], "Orientations of %s" % id)


func test_l_left_and_l_right_are_mirror_shapes() -> void:
	var shapes := PieceShapeLibrary.load_all()
	var left := shapes[&"l_left"].get_orientations()
	var right := shapes[&"l_right"].get_orientations()
	for orientation in left:
		check(not right.has(orientation), "L left orientation %s is not an L right one" % [orientation])


func test_orientations_are_normalized() -> void:
	for shape in PieceShapeLibrary.load_all().values():
		for orientation in shape.get_orientations():
			var min_corner: Vector2i = orientation[0]
			for p: Vector2i in orientation:
				min_corner = min_corner.min(p)
			check_eq(min_corner, Vector2i.ZERO, "%s orientation starts at (0,0)" % shape.shape_id)


func test_generator_is_deterministic_and_uses_known_data() -> void:
	var shapes := PieceShapeLibrary.load_all()
	var terrains := TerrainLibrary.load_all()
	var a := PieceGenerator.new(shapes, terrains, 42)
	var b := PieceGenerator.new(shapes, terrains, 42)
	check_eq(a.get_orientation_count(), 14, "1+2+2+1+4+4 orientations in the pool")
	var key_pieces := 0
	for i in 200:
		var pa := a.generate()
		var pb := b.generate()
		check_eq([pa.shape_id, pa.offsets, pa.terrains, pa.key_index], [pb.shape_id, pb.offsets, pb.terrains, pb.key_index],
				"Same seed gives the same piece #%d" % i)
		check(shapes.has(pa.shape_id), "Generated shape is known")
		for t in pa.terrains:
			check(terrains.has(t), "Generated terrain '%s' is known" % t)
		if pa.key_index != LandPiece.NO_KEY:
			key_pieces += 1
			check(pa.key_index >= 0 and pa.key_index < pa.offsets.size(), "Key index inside the piece")
	check(key_pieces > 10 and key_pieces < 80, "Roughly 20%% of pieces have a key cell (got %d/200)" % key_pieces)


func test_hand_take_and_refill() -> void:
	var gen := PieceGenerator.new(PieceShapeLibrary.load_all(), TerrainLibrary.load_all(), 1)
	var hand := PieceHand.new(gen)
	hand.refill()
	check_eq(hand.pieces.size(), 3, "Hand starts with 3 pieces")
	var second := hand.pieces[1]
	check(hand.take(1) == second, "take returns the chosen piece")
	check_eq(hand.pieces.size(), 2, "take removes the piece")
	hand.take(0)
	hand.take(0)
	check(hand.is_empty(), "Hand is empty after taking all")
	hand.refill()
	check_eq(hand.pieces.size(), 3, "Refill tops up to 3")


func test_anchor_is_inside_piece_bounds() -> void:
	check_eq(_piece([Vector2i(0, 0)]).get_anchor(), Vector2i(0, 0), "Single cell anchor")
	check_eq(_piece([Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]).get_anchor(), Vector2i(0, 1), "Vertical bar3 anchor is middle")
	check_eq(_piece([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]).get_anchor(), Vector2i(0, 0), "Square anchor")


func test_place_next_to_territory() -> void:
	var board := BoardData.create_starting_board(12)
	var bar := _piece([Vector2i(0, 0), Vector2i(1, 0)])
	# Territory is x,y in 4..7. (8,4)-(9,4) touches (7,4) on its left edge.
	check_eq(PlacementRules.apply(board, bar, Vector2i(8, 4)), PlacementRules.Result.OK, "Edge-touching placement is OK")
	for coord in [Vector2i(8, 4), Vector2i(9, 4)]:
		var cell := board.get_cell(coord)
		check(cell.owned, "%s becomes owned" % coord)
		check_eq(cell.terrain_id, &"forest", "%s gets the piece terrain" % coord)
	check_eq(board.count_owned_cells(), 18, "Territory grew by 2")


func test_diagonal_only_is_not_connected() -> void:
	var board := BoardData.create_starting_board(12)
	var before := _snapshot(board)
	# (8,8) only touches the territory corner (7,7) diagonally.
	check_eq(PlacementRules.apply(board, _piece([Vector2i(0, 0)]), Vector2i(8, 8)),
			PlacementRules.Result.NOT_CONNECTED, "Diagonal contact is not a connection")
	check_eq(PlacementRules.apply(board, _piece([Vector2i(0, 0)]), Vector2i(0, 0)),
			PlacementRules.Result.NOT_CONNECTED, "Far away placement is rejected")
	check_eq(_snapshot(board), before, "Rejected placements change nothing")


func test_out_of_bounds_and_castle_are_rejected() -> void:
	var board := BoardData.create_starting_board(12)
	var before := _snapshot(board)
	var bar3 := _piece([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	check_eq(PlacementRules.apply(board, bar3, Vector2i(10, 4)), PlacementRules.Result.OUT_OF_BOUNDS, "Sticking out right")
	check_eq(PlacementRules.apply(board, bar3, Vector2i(-1, 4)), PlacementRules.Result.OUT_OF_BOUNDS, "Sticking out left")
	check_eq(PlacementRules.apply(board, bar3, Vector2i(4, 5)), PlacementRules.Result.ON_BUILDING, "Covering the castle")
	check_eq(_snapshot(board), before, "Rejected placements change nothing")


func test_overwrite_replaces_terrain() -> void:
	var board := BoardData.create_starting_board(12)
	# Put 4 farmland cells in a row inside the territory, then cover one with forest.
	var farms := _piece([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)], &"farmland")
	check_eq(PlacementRules.apply(board, farms, Vector2i(4, 4)), PlacementRules.Result.OK, "Place farms over own grass")
	check_eq(PlacementRules.apply(board, _piece([Vector2i(0, 0)], &"forest"), Vector2i(5, 4)),
			PlacementRules.Result.OK, "Overwrite one farm")
	var farm_count := 0
	var forest_count := 0
	for x in range(4, 8):
		match board.get_cell(Vector2i(x, 4)).terrain_id:
			&"farmland": farm_count += 1
			&"forest": forest_count += 1
	check_eq([farm_count, forest_count], [3, 1], "3 farms + 1 forest after overwrite")
	check_eq(board.count_owned_cells(), 16, "Overwriting does not grow territory")


func test_key_cell_is_placed_and_lost_when_covered() -> void:
	var board := BoardData.create_starting_board(12)
	var keyed := _piece([Vector2i(0, 0), Vector2i(1, 0)], &"hill", 1)
	PlacementRules.apply(board, keyed, Vector2i(8, 4))
	check(not board.get_cell(Vector2i(8, 4)).is_key, "Non-key cell stays normal")
	check(board.get_cell(Vector2i(9, 4)).is_key, "Key cell is marked")
	PlacementRules.apply(board, _piece([Vector2i(0, 0)], &"farmland"), Vector2i(9, 4))
	check(not board.get_cell(Vector2i(9, 4)).is_key, "Covering a key cell removes it")
	check_eq(board.get_cell(Vector2i(9, 4)).terrain_id, &"farmland", "Covered cell gets the new terrain")
