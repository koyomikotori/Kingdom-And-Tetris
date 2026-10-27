extends "res://tests/test_suite.gd"
## M13c: bigger cells, building idle loops, walkers on the map, the map effects setting.


func _board() -> BoardData:
	var board := BoardData.create_starting_board(12)
	# Two rows of grass above the starting land (rows 4–7), joined to it.
	for y in [2, 3]:
		for x in range(2, 10):
			board.set_land(Vector2i(x, y), &"grass", false)
	return board


func _castle(board: BoardData) -> Vector2i:
	for cell in board.get_all_cells():
		if cell.building_id == BoardData.CASTLE_ID:
			return cell.building_origin
	return Vector2i(-1, -1)


func test_buildings_have_room_around_them() -> void:
	check_eq(BoardView.TILE_SIZE, 48, "Cells are 48 px")
	var rect := BoardView.art_rect(Vector2i(2, 3), Vector2i.ONE, Vector2(16, 16))
	var cell := Rect2(BoardView.cell_to_local(Vector2i(2, 3)), Vector2.ONE * BoardView.TILE_SIZE)
	check_eq(rect.size, Vector2(32, 32), "A 16×16 building is drawn 32 px")
	check(cell.encloses(rect), "…inside its cell")
	check(rect.position.x - cell.position.x >= 8.0, "…with room on the sides")
	var castle := BoardView.art_rect(Vector2i.ZERO, Vector2i(2, 2), Vector2(32, 32))
	check_eq(castle.size, Vector2(64, 64), "The castle (32×32 art) is drawn 64 px in its 96 px")


func test_every_building_has_an_idle_loop() -> void:
	for id in BuildingData.load_all():
		var strip := GameArt.building_anim(id)
		var still := GameArt.building(id)
		check(strip != null, "%s has an idle loop" % id)
		if strip != null and still != null:
			check_eq(strip.get_size(), still.get_size() * Vector2(GameArt.BUILDING_ANIM_FRAMES, 1),
					"%s: %d frames of its size" % [id, GameArt.BUILDING_ANIM_FRAMES])
	for level in range(1, 7):
		check(GameArt.castle_anim(level) != null, "Castle %d has an idle loop" % level)
	for sprite in [&"villager_a", &"villager_b", &"soldier", &"horse", &"cart", &"deer", &"bird", &"carry_food"]:
		check(GameArt.map_sprite(sprite) != null, "%s walker art" % sprite)


func test_paths_follow_the_edges_of_the_territory() -> void:
	var board := _board()
	var life := MapLife.new(1)
	life.sync(board, 0)
	var castle := _castle(board)
	# Inside the castle (between its own cells) is no way through.
	check(not life.edge_open(castle + Vector2i(1, 0), castle + Vector2i(1, 1)), "No walking through the castle")
	check(not life.edge_open(Vector2i(0, 0), Vector2i(1, 0)), "No walking outside the territory")
	var path := life.find_path(castle, [Vector2i(9, 2)])
	check(not path.is_empty(), "There is a way to the far grass")
	check_eq(path.back(), Vector2(9, 2), "…ending at the goal")
	var prev := Vector2(castle)
	for point in path:
		check_eq(prev.distance_to(point), 1.0, "Steps of one cell edge")
		prev = point


func test_population_follows_the_kingdom() -> void:
	KingdomState.instant_construction = true
	var board := _board()
	var life := MapLife.new(2)
	life.sync(board, 0)
	check_eq(life.count(MapLife.Kind.VILLAGER), 2, "Two villagers with no workplace")
	check_eq(life.count(MapLife.Kind.SOLDIER), 0, "No army, no patrol")
	board.place_building(&"lumber_mill", Vector2i(3, 2), Vector2i.ONE)
	board.place_building(&"war_stable", Vector2i(5, 2), Vector2i.ONE)
	life.sync(board, 5)
	check_eq(life.count(MapLife.Kind.VILLAGER), 3, "One more villager per workplace")
	check_eq(life.count(MapLife.Kind.CART), 1, "A cart for the lumber mill")
	check_eq(life.count(MapLife.Kind.SOLDIER), 2, "One patrol per three squads, rounded up")
	check_eq(life.count(MapLife.Kind.HORSE), 2, "Two horses at the war stable")
	var walkers := life.walkers.duplicate()
	life.sync(board, 5)
	check_eq(life.walkers, walkers, "Nothing changed: everyone carries on")


func test_walkers_carry_on_when_the_kingdom_changes() -> void:
	KingdomState.instant_construction = true
	var board := _board()
	board.place_building(&"lumber_mill", Vector2i(3, 2), Vector2i.ONE)
	board.place_building(&"war_stable", Vector2i(5, 2), Vector2i.ONE)
	var life := MapLife.new(5)
	life.sync(board, 3)
	for i in 100:
		life.update(0.1)
	var before: Array[MapLife.Walker] = life.walkers.filter(func(w: MapLife.Walker) -> bool:
			return w.kind != MapLife.Kind.BIRD)
	var spots := before.map(func(w: MapLife.Walker) -> Vector2: return w.pos)
	board.set_building_level(Vector2i(3, 2), 2)
	board.set_land(Vector2i(1, 4), &"grass", false)
	board.place_building(&"farm", Vector2i(7, 2), Vector2i.ONE)
	life.sync(board, 3)
	for i in before.size():
		check(life.walkers.has(before[i]), "Walker %d is still on the map" % i)
		check_eq(before[i].pos, spots[i], "…where it was")
	check_eq(life.count(MapLife.Kind.VILLAGER), 4, "One new villager for the new farm")
	check(life.count(MapLife.Kind.VILLAGER) <= MapLife.MAX_VILLAGERS, "…within the cap")


func test_villagers_bring_goods_home() -> void:
	var board := _board()
	board.place_building(&"lumber_mill", Vector2i(3, 2), Vector2i.ONE)
	var life := MapLife.new(3)
	life.sync(board, 0)
	var villager: MapLife.Walker = life.walkers.filter(func(w: MapLife.Walker) -> bool:
			return w.kind == MapLife.Kind.VILLAGER)[0]
	var carried := false
	for i in 1200:
		life.update(0.1)
		if villager.carry == &"wood":
			carried = true
			break
	check(carried, "A villager came back from the mill with wood")


func test_birds_fly_across_and_leave() -> void:
	var life := MapLife.new(4)
	life.sync(_board(), 0)
	var seen := false
	for i in 600:
		life.update(0.1)
		seen = seen or life.count(MapLife.Kind.BIRD) > 0
	check(seen, "Birds come by")
	check(life.count(MapLife.Kind.BIRD) <= 6, "…and fly away again")
