class_name BoardView
extends Node2D
## Draws a BoardData and turns mouse input into cell coordinates.
## Read-only: it never modifies the board, it only emits signals.

signal cell_hovered(coord: Vector2i)
signal cell_clicked(coord: Vector2i)

const TILE_SIZE := 32
const OFF_BOARD := Vector2i(-1, -1)

const EMPTY_COLOR := Color(0.10, 0.11, 0.14)
const GRID_COLOR := Color(0, 0, 0, 0.35)
const TERRITORY_BORDER_COLOR := Color(1.0, 0.92, 0.55)
const HOVER_COLOR := Color(1, 1, 1, 0.9)
const CASTLE_COLOR := Color(0.62, 0.22, 0.2)
const CASTLE_ROOF_COLOR := Color(0.85, 0.4, 0.3)
const COORD_TEXT_COLOR := Color(1, 1, 1, 0.55)
const COORD_FONT_SIZE := 8

## Shows "x,y" in every cell. Toggled with G in the kingdom scene.
var show_coords := true:
	set(value):
		show_coords = value
		queue_redraw()

var _board: BoardData
var _terrains: Dictionary[StringName, TerrainData] = {}
var _hovered := OFF_BOARD


func setup(board: BoardData, terrains: Dictionary[StringName, TerrainData]) -> void:
	_board = board
	_terrains = terrains
	_board.cell_changed.connect(func(_coord: Vector2i) -> void: queue_redraw())
	queue_redraw()


## Floor division so that positions left of / above the board map to negative cells.
static func local_to_cell(local_pos: Vector2) -> Vector2i:
	return Vector2i(floori(local_pos.x / TILE_SIZE), floori(local_pos.y / TILE_SIZE))


## Top-left corner of the cell in this node's local space.
static func cell_to_local(coord: Vector2i) -> Vector2:
	return Vector2(coord * TILE_SIZE)


## Returns null for unknown ids.
func get_terrain(terrain_id: StringName) -> TerrainData:
	return _terrains.get(terrain_id)


func get_board_rect() -> Rect2:
	return Rect2(global_position, Vector2(_board.width, _board.height) * TILE_SIZE)


func _unhandled_input(event: InputEvent) -> void:
	if _board == null:
		return
	if event is InputEventMouseMotion:
		_update_hover()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var coord := local_to_cell(get_local_mouse_position())
		if _board.is_in_bounds(coord):
			cell_clicked.emit(coord)


func _update_hover() -> void:
	var coord := local_to_cell(get_local_mouse_position())
	if not _board.is_in_bounds(coord):
		coord = OFF_BOARD
	if coord == _hovered:
		return
	_hovered = coord
	cell_hovered.emit(coord)
	queue_redraw()


func _draw() -> void:
	if _board == null:
		return
	for cell in _board.get_all_cells():
		_draw_cell(cell)
	_draw_territory_border()
	_draw_buildings()
	if show_coords:
		_draw_coords()
	if _hovered != OFF_BOARD:
		draw_rect(_cell_rect(_hovered), HOVER_COLOR, false, 2.0)


func _draw_cell(cell: CellData) -> void:
	var color := EMPTY_COLOR
	if cell.has_terrain():
		var terrain := get_terrain(cell.terrain_id)
		color = terrain.color if terrain != null else Color.MAGENTA
	draw_rect(_cell_rect(cell.coord), color)
	draw_rect(_cell_rect(cell.coord), GRID_COLOR, false, 1.0)


## Draws an edge wherever an owned cell touches a non-owned cell or the board edge.
func _draw_territory_border() -> void:
	for cell in _board.get_all_cells():
		if not cell.owned:
			continue
		var top_left := cell_to_local(cell.coord)
		var corners := [
			top_left,
			top_left + Vector2(TILE_SIZE, 0),
			top_left + Vector2(TILE_SIZE, TILE_SIZE),
			top_left + Vector2(0, TILE_SIZE),
		]
		# NEIGHBOR_OFFSETS order is up, right, down, left, matching corner pairs (i, i+1).
		for i in BoardData.NEIGHBOR_OFFSETS.size():
			var neighbor := _board.get_cell(cell.coord + BoardData.NEIGHBOR_OFFSETS[i])
			if neighbor == null or not neighbor.owned:
				draw_line(corners[i], corners[(i + 1) % 4], TERRITORY_BORDER_COLOR, 2.0)


func _draw_buildings() -> void:
	for cell in _board.get_all_cells():
		if not cell.has_building() or cell.coord != cell.building_origin:
			continue
		var bounds := _cell_rect(cell.coord)
		for covered in _board.get_building_cells(cell.building_origin):
			bounds = bounds.merge(_cell_rect(covered.coord))
		var inner := bounds.grow(-4)
		if cell.building_id == BoardData.CASTLE_ID:
			draw_rect(inner, CASTLE_COLOR)
			draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.35)), CASTLE_ROOF_COLOR)
		else:
			draw_rect(inner, Color.WHITE)
		draw_rect(inner, Color.BLACK, false, 1.0)


func _draw_coords() -> void:
	var font := ThemeDB.fallback_font
	for cell in _board.get_all_cells():
		var pos := cell_to_local(cell.coord) + Vector2(2, COORD_FONT_SIZE + 1)
		draw_string(font, pos, "%d,%d" % [cell.coord.x, cell.coord.y],
				HORIZONTAL_ALIGNMENT_LEFT, -1, COORD_FONT_SIZE, COORD_TEXT_COLOR)


func _cell_rect(coord: Vector2i) -> Rect2:
	return Rect2(cell_to_local(coord), Vector2(TILE_SIZE, TILE_SIZE))
