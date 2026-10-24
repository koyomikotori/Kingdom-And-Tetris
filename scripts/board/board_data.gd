class_name BoardData
extends RefCounted
## Authoritative grid state. Knows nothing about rendering.
## Coordinates: Vector2i(x, y), x grows right, y grows down, (0, 0) is the top-left cell.

signal cell_changed(coord: Vector2i)

const CASTLE_ID: StringName = &"castle"
const NEIGHBOR_OFFSETS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var width: int
var height: int
var _cells: Array[CellData] = []


func _init(p_width: int, p_height: int) -> void:
	assert(p_width > 0 and p_height > 0, "Board size must be positive")
	width = p_width
	height = p_height
	for y in height:
		for x in width:
			_cells.append(CellData.new(Vector2i(x, y)))


## Creates a square board with a castle in the middle and a ring of owned grass around it.
static func create_starting_board(size: int, castle_size: int = 2, start_margin: int = 1) -> BoardData:
	var board := BoardData.new(size, size)
	var castle_origin := Vector2i((size - castle_size) / 2, (size - castle_size) / 2)
	var start_area := Rect2i(castle_origin, Vector2i(castle_size, castle_size)).grow(start_margin)
	for y in range(start_area.position.y, start_area.end.y):
		for x in range(start_area.position.x, start_area.end.x):
			var coord := Vector2i(x, y)
			if board.is_in_bounds(coord):
				board.set_terrain(coord, &"grass")
				board.set_owned(coord, true)
	var placed := board.place_building(CASTLE_ID, castle_origin, Vector2i(castle_size, castle_size))
	assert(placed, "Castle must fit on the starting board")
	return board


func is_in_bounds(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 and coord.x < width and coord.y < height


## Returns null for coordinates outside the board.
func get_cell(coord: Vector2i) -> CellData:
	if not is_in_bounds(coord):
		return null
	return _cells[coord.y * width + coord.x]


func get_all_cells() -> Array[CellData]:
	return _cells


## Edge-adjacent cells only (no diagonals), skipping cells outside the board.
func get_neighbors(coord: Vector2i) -> Array[CellData]:
	var result: Array[CellData] = []
	for offset in NEIGHBOR_OFFSETS:
		var cell := get_cell(coord + offset)
		if cell != null:
			result.append(cell)
	return result


func set_terrain(coord: Vector2i, terrain_id: StringName) -> void:
	var cell := get_cell(coord)
	if cell == null or cell.terrain_id == terrain_id:
		return
	cell.terrain_id = terrain_id
	cell_changed.emit(coord)


func set_owned(coord: Vector2i, owned: bool) -> void:
	var cell := get_cell(coord)
	if cell == null or cell.owned == owned:
		return
	cell.owned = owned
	cell_changed.emit(coord)


## Claims a cell with new land, replacing whatever terrain and key cell it had.
## Validation is the caller's job (see PlacementRules).
func set_land(coord: Vector2i, terrain_id: StringName, is_key: bool) -> void:
	var cell := get_cell(coord)
	if cell == null:
		return
	cell.terrain_id = terrain_id
	cell.is_key = is_key
	cell.owned = true
	cell_changed.emit(coord)


## A building fits when every cell is on the board, owned and free of other buildings.
func can_place_building(origin: Vector2i, size: Vector2i) -> bool:
	if size.x <= 0 or size.y <= 0:
		return false
	for coord in _rect_coords(Rect2i(origin, size)):
		var cell := get_cell(coord)
		if cell == null or not cell.owned or cell.has_building():
			return false
	return true


## Returns false and leaves the board untouched when the building does not fit.
func place_building(building_id: StringName, origin: Vector2i, size: Vector2i) -> bool:
	if not can_place_building(origin, size):
		return false
	for coord in _rect_coords(Rect2i(origin, size)):
		var cell := get_cell(coord)
		cell.building_id = building_id
		cell.building_origin = origin
		cell_changed.emit(coord)
	return true


## All cells covered by the building whose top-left cell is `origin`.
func get_building_cells(origin: Vector2i) -> Array[CellData]:
	var result: Array[CellData] = []
	for cell in _cells:
		if cell.has_building() and cell.building_origin == origin:
			result.append(cell)
	return result


func count_owned_cells() -> int:
	var count := 0
	for cell in _cells:
		if cell.owned:
			count += 1
	return count


func count_owned_terrain(terrain_id: StringName) -> int:
	var count := 0
	for cell in _cells:
		if cell.owned and cell.terrain_id == terrain_id:
			count += 1
	return count


## Number of separate buildings of this type (counted by their top-left cell).
func count_buildings(building_id: StringName) -> int:
	var count := 0
	for cell in _cells:
		if cell.building_id == building_id and cell.coord == cell.building_origin:
			count += 1
	return count


func _rect_coords(rect: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			result.append(Vector2i(x, y))
	return result
