extends "res://tests/test_suite.gd"


func test_cells_have_matching_coords() -> void:
	var board := BoardData.new(12, 12)
	check_eq(board.get_all_cells().size(), 144, "12x12 board has 144 cells")
	for y in 12:
		for x in 12:
			var coord := Vector2i(x, y)
			check_eq(board.get_cell(coord).coord, coord, "Cell at %s stores its own coord" % coord)


func test_bounds() -> void:
	var board := BoardData.new(12, 12)
	check(board.is_in_bounds(Vector2i(0, 0)), "Top-left is in bounds")
	check(board.is_in_bounds(Vector2i(11, 11)), "Bottom-right is in bounds")
	for outside in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(12, 0), Vector2i(0, 12)]:
		check(not board.is_in_bounds(outside), "%s is out of bounds" % outside)
		check(board.get_cell(outside) == null, "get_cell(%s) returns null" % outside)


func test_neighbors_are_edge_only() -> void:
	var board := BoardData.new(12, 12)
	check_eq(board.get_neighbors(Vector2i(0, 0)).size(), 2, "Corner has 2 neighbors")
	check_eq(board.get_neighbors(Vector2i(5, 0)).size(), 3, "Edge cell has 3 neighbors")
	check_eq(board.get_neighbors(Vector2i(5, 5)).size(), 4, "Inner cell has 4 neighbors")


func test_castle_occupies_exactly_four_centered_cells() -> void:
	var board := BoardData.create_starting_board(12)
	var castle_cells: Array[Vector2i] = []
	for cell in board.get_all_cells():
		if cell.building_id == BoardData.CASTLE_ID:
			castle_cells.append(cell.coord)
			check_eq(cell.building_origin, Vector2i(5, 5), "Castle cell %s points to origin" % cell.coord)
			check(cell.owned, "Castle cell %s is owned" % cell.coord)
	castle_cells.sort()
	check_eq(castle_cells, [Vector2i(5, 5), Vector2i(5, 6), Vector2i(6, 5), Vector2i(6, 6)],
			"Castle covers exactly the 4 center cells")
	check_eq(board.get_building_cells(Vector2i(5, 5)).size(), 4, "get_building_cells finds 4 cells")


func test_starting_territory_is_4x4_grass() -> void:
	var board := BoardData.create_starting_board(12)
	check_eq(board.count_owned_cells(), 16, "Start owns a 4x4 area")
	for cell in board.get_all_cells():
		var inside := Rect2i(4, 4, 4, 4).has_point(cell.coord)
		check_eq(cell.owned, inside, "Ownership of %s" % cell.coord)
		check_eq(cell.terrain_id, &"grass" if inside else CellData.NO_TERRAIN, "Terrain of %s" % cell.coord)


func test_starting_board_other_sizes() -> void:
	var board := BoardData.create_starting_board(15)
	check_eq(board.get_building_cells(Vector2i(6, 6)).size(), 4, "15x15 castle at (6,6)")
	check_eq(board.count_owned_cells(), 16, "15x15 start owns 16 cells")


func test_invalid_building_placement_changes_nothing() -> void:
	var board := BoardData.create_starting_board(12)
	var changes := []
	board.cell_changed.connect(func(coord: Vector2i) -> void: changes.append(coord))
	check(not board.place_building(&"farm", Vector2i(6, 6), Vector2i.ONE), "Cannot build on the castle")
	check(not board.place_building(&"farm", Vector2i(0, 0), Vector2i.ONE), "Cannot build on unowned land")
	check(not board.place_building(&"farm", Vector2i(7, 7), Vector2i(2, 2)), "Cannot build partly outside territory")
	check(not board.place_building(&"farm", Vector2i(-1, 4), Vector2i.ONE), "Cannot build off the board")
	check(changes.is_empty(), "Failed placements emit no cell_changed")
	check(board.place_building(&"farm", Vector2i(4, 4), Vector2i.ONE), "Can build on free owned cell")


func test_local_to_cell_round_trip() -> void:
	var size := BoardView.TILE_SIZE
	check_eq(BoardView.local_to_cell(Vector2(0, 0)), Vector2i(0, 0), "Origin maps to (0,0)")
	check_eq(BoardView.local_to_cell(Vector2(size - 0.01, size - 0.01)), Vector2i(0, 0), "Inside first cell")
	check_eq(BoardView.local_to_cell(Vector2(size, 0)), Vector2i(1, 0), "Exact edge belongs to next cell")
	check_eq(BoardView.local_to_cell(Vector2(-0.5, -0.5)), Vector2i(-1, -1), "Negative positions floor to -1")
	for coord in [Vector2i(0, 0), Vector2i(3, 7), Vector2i(11, 11)]:
		var center := BoardView.cell_to_local(coord) + Vector2(size, size) * 0.5
		check_eq(BoardView.local_to_cell(center), coord, "Round trip for %s" % coord)


func test_terrain_library_loads_all_terrains() -> void:
	var terrains := TerrainLibrary.load_all()
	for id in [&"grass", &"farmland", &"forest", &"hill"]:
		check(terrains.has(id), "Terrain '%s' is loaded" % id)
	for id in terrains:
		check(not terrains[id].display_name.is_empty(), "Terrain '%s' has a display name" % id)
