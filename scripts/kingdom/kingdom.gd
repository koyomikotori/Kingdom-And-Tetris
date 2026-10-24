extends Node2D
## Kingdom screen: wires the board data, its view, the piece hand, the camera and the UI together.

const NO_SELECTION := -1

@export var board_size := 12
## 0 = random seed each run. Set a number to replay the same pieces while testing.
@export var piece_seed := 0

var board: BoardData
var hand: PieceHand
var _terrains: Dictionary[StringName, TerrainData] = {}
var _shapes: Dictionary[StringName, PieceShapeData] = {}
var _selected := NO_SELECTION

@onready var board_view: BoardView = $BoardView
@onready var camera: CameraController = $Camera
@onready var cell_info_label: Label = %CellInfo
@onready var side_panel: Control = %SidePanel
@onready var piece_list: Container = %PieceList
@onready var placement_status: Label = %PlacementStatus


func _ready() -> void:
	_terrains = TerrainLibrary.load_all()
	_shapes = PieceShapeLibrary.load_all()
	board = BoardData.create_starting_board(board_size)
	board_view.setup(board, _terrains)
	board_view.cell_hovered.connect(_on_cell_hovered)
	board_view.cell_clicked.connect(_on_cell_clicked)
	camera.focus_on(board_view.get_board_rect(), side_panel.size.x)

	var seed_value := piece_seed if piece_seed != 0 else randi()
	hand = PieceHand.new(PieceGenerator.new(_shapes, _terrains, seed_value))
	hand.changed.connect(_rebuild_piece_cards)
	hand.refill()
	_on_cell_hovered(BoardView.OFF_BOARD)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_G:
			board_view.show_coords = not board_view.show_coords
		KEY_ESCAPE:
			_select(NO_SELECTION)
		KEY_1, KEY_2, KEY_3:
			_toggle_selection(event.keycode - KEY_1)


func _on_cell_hovered(coord: Vector2i) -> void:
	if coord == BoardView.OFF_BOARD:
		cell_info_label.text = "Rê chuột lên một ô để xem thông tin.\nCuộn: zoom · Chuột phải/giữa: kéo · G: bật/tắt tọa độ"
	else:
		cell_info_label.text = _describe_cell(board.get_cell(coord))
	_update_ghost()


func _on_cell_clicked(coord: Vector2i) -> void:
	if _selected == NO_SELECTION:
		print(_describe_cell(board.get_cell(coord)).replace("\n", " | "))
		return
	var piece := hand.pieces[_selected]
	var result := PlacementRules.apply(board, piece, coord - piece.get_anchor())
	if result != PlacementRules.Result.OK:
		placement_status.text = PlacementRules.describe(result)
		return
	var placed_index := _selected
	_selected = NO_SELECTION
	hand.take(placed_index)
	# Temporary until M3 adds turns: a new hand arrives once all pieces are placed.
	if hand.is_empty():
		hand.refill()
	placement_status.text = "Đã đặt mảnh đất."
	_on_cell_hovered(coord)


func _toggle_selection(index: int) -> void:
	_select(NO_SELECTION if index == _selected else index)


func _select(index: int) -> void:
	if index >= hand.pieces.size():
		return
	_selected = index
	for i in piece_list.get_child_count():
		(piece_list.get_child(i) as PieceCard).set_pressed_no_signal(i == _selected)
	placement_status.text = "" if _selected == NO_SELECTION else "Nhấn chuột trái lên bản đồ để đặt. Esc: bỏ chọn."
	_update_ghost()


func _rebuild_piece_cards() -> void:
	for child in piece_list.get_children():
		piece_list.remove_child(child)
		child.queue_free()
	for i in hand.pieces.size():
		var piece := hand.pieces[i]
		var card := PieceCard.new()
		var shape := _shapes.get(piece.shape_id) as PieceShapeData
		card.setup(piece, _terrains, shape.display_name if shape != null else String(piece.shape_id))
		card.pressed.connect(_toggle_selection.bind(i))
		piece_list.add_child(card)
	_select(_selected if _selected < hand.pieces.size() else NO_SELECTION)


func _update_ghost() -> void:
	var coord := board_view.get_hovered_cell()
	if _selected == NO_SELECTION or coord == BoardView.OFF_BOARD:
		board_view.hide_ghost()
		return
	var piece := hand.pieces[_selected]
	var origin := coord - piece.get_anchor()
	var result := PlacementRules.check(board, piece, origin)
	board_view.show_ghost(piece, origin, result == PlacementRules.Result.OK)
	placement_status.text = PlacementRules.describe(result)


func _describe_cell(cell: CellData) -> String:
	var terrain := "Đất hoang"
	if cell.has_terrain():
		var data := board_view.get_terrain(cell.terrain_id)
		terrain = data.display_name if data != null else String(cell.terrain_id)
	if cell.is_key:
		terrain += " ◆ (ô quan trọng)"
	var building := "Không"
	if cell.has_building():
		building = "%s (gốc %d,%d)" % [cell.building_id, cell.building_origin.x, cell.building_origin.y]
	return "Ô (%d, %d)\nĐịa hình: %s\nSở hữu: %s\nCông trình: %s" % [
		cell.coord.x, cell.coord.y, terrain, "Có" if cell.owned else "Không", building]
