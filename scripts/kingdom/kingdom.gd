extends Node2D
## Kingdom screen: turns input into KingdomState actions and keeps the board view and UI in sync.

const NO_SELECTION := -1

@export var board_size := 12
## 0 = random seed each run. Set a number to replay the same pieces while testing.
@export var piece_seed := 0

var state: KingdomState
var _terrains: Dictionary[StringName, TerrainData] = {}
var _shapes: Dictionary[StringName, PieceShapeData] = {}
var _resource_types: Array[ResourceTypeData] = []
var _resource_labels: Dictionary[StringName, Label] = {}
var _selected := NO_SELECTION

@onready var board_view: BoardView = $BoardView
@onready var camera: CameraController = $Camera
@onready var cell_info_label: Label = %CellInfo
@onready var side_panel: Control = %SidePanel
@onready var top_bar: Control = %TopBar
@onready var resource_bar: Container = %ResourceBar
@onready var turn_label: Label = %TurnLabel
@onready var piece_list: Container = %PieceList
@onready var placement_status: Label = %PlacementStatus
@onready var end_turn_button: Button = %EndTurnButton


func _ready() -> void:
	_terrains = TerrainLibrary.load_all()
	_shapes = PieceShapeLibrary.load_all()
	_resource_types = ResourceTypeData.load_all()
	_build_resource_labels()

	var board := BoardData.create_starting_board(board_size)
	board_view.setup(board, _terrains)
	board_view.cell_hovered.connect(_on_cell_hovered)
	board_view.cell_clicked.connect(_on_cell_clicked)
	# Container sizes are only sorted next frame, so use the top bar's minimum height.
	camera.focus_on(board_view.get_board_rect(), side_panel.size.x, top_bar.get_combined_minimum_size().y)

	var seed_value := piece_seed if piece_seed != 0 else randi()
	var hand := PieceHand.new(PieceGenerator.new(_shapes, _terrains, seed_value))
	state = KingdomState.new(board, hand, _terrains)
	state.hand.changed.connect(_rebuild_piece_cards)
	state.stockpile.changed.connect(_refresh_resource_bar)
	state.turn_started.connect(_on_turn_started)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	state.start()
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
		KEY_ENTER, KEY_KP_ENTER:
			_on_end_turn_pressed()


func _on_cell_hovered(coord: Vector2i) -> void:
	if coord == BoardView.OFF_BOARD:
		cell_info_label.text = "Rê chuột lên một ô để xem thông tin.\nCuộn: zoom · Chuột phải/giữa: kéo · G: bật/tắt tọa độ"
	else:
		cell_info_label.text = _describe_cell(state.board.get_cell(coord))
	_update_ghost()


func _on_cell_clicked(coord: Vector2i) -> void:
	if _selected == NO_SELECTION:
		print(_describe_cell(state.board.get_cell(coord)).replace("\n", " | "))
		return
	var piece := state.hand.pieces[_selected]
	var result := state.place_piece(_selected, coord - piece.get_anchor())
	if result != PlacementRules.Result.OK:
		placement_status.text = PlacementRules.describe(result)
		return
	_select(NO_SELECTION)
	_refresh_resource_bar()
	placement_status.text = "Đã đặt mảnh đất."
	_on_cell_hovered(coord)


func _on_end_turn_pressed() -> void:
	_select(NO_SELECTION)
	var collected := state.end_turn()
	var text := _format_amounts(collected, false)
	placement_status.text = "Đã thu: %s." % text if not text.is_empty() else "Lượt trước không thu được tài nguyên nào."


func _on_turn_started(turn: int) -> void:
	turn_label.text = "Lượt %d" % turn
	_refresh_resource_bar()


func _toggle_selection(index: int) -> void:
	_select(NO_SELECTION if index == _selected else index)


func _select(index: int) -> void:
	if index >= state.hand.pieces.size():
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
	for i in state.hand.pieces.size():
		var piece := state.hand.pieces[i]
		var card := PieceCard.new()
		var shape := _shapes.get(piece.shape_id) as PieceShapeData
		card.setup(piece, _terrains, shape.display_name if shape != null else String(piece.shape_id))
		card.pressed.connect(_toggle_selection.bind(i))
		piece_list.add_child(card)
	_select(_selected if _selected < state.hand.pieces.size() else NO_SELECTION)


func _update_ghost() -> void:
	var coord := board_view.get_hovered_cell()
	if _selected == NO_SELECTION or coord == BoardView.OFF_BOARD:
		board_view.hide_ghost()
		return
	var piece := state.hand.pieces[_selected]
	var origin := coord - piece.get_anchor()
	var result := PlacementRules.check(state.board, piece, origin)
	board_view.show_ghost(piece, origin, result == PlacementRules.Result.OK)
	if result != PlacementRules.Result.OK:
		placement_status.text = PlacementRules.describe(result)
		return
	var delta := _format_amounts(Economy.placement_delta(state.board, piece, origin, _terrains), true)
	placement_status.text = "Có thể đặt. Sản lượng mỗi lượt: %s." % (delta if not delta.is_empty() else "không đổi")


func _build_resource_labels() -> void:
	for type in _resource_types:
		var label := Label.new()
		resource_bar.add_child(label)
		_resource_labels[type.resource_id] = label


func _refresh_resource_bar() -> void:
	var income := state.get_turn_yield()
	for type in _resource_types:
		_resource_labels[type.resource_id].text = "%s: %d (+%d)" % [
			type.display_name, state.stockpile.get_amount(type.resource_id), income.get(type.resource_id, 0)]


## "+2 Lương thực, -1 Gỗ" in resource-bar order; zero amounts are skipped.
func _format_amounts(amounts: Dictionary[StringName, int], signed: bool) -> String:
	var parts: Array[String] = []
	for type in _resource_types:
		var amount: int = amounts.get(type.resource_id, 0)
		if amount != 0:
			parts.append(("%+d %s" if signed else "%d %s") % [amount, type.display_name])
	return ", ".join(parts)


func _describe_cell(cell: CellData) -> String:
	var terrain := "Đất hoang"
	if cell.has_terrain():
		var data := board_view.get_terrain(cell.terrain_id)
		terrain = data.display_name if data != null else String(cell.terrain_id)
	if cell.is_key:
		terrain += " ◆ (ô quan trọng, x%d sản lượng)" % Economy.KEY_CELL_MULTIPLIER
	var production := "Không"
	if cell.owned:
		var amounts := _format_amounts(Economy.cell_yield(_terrains.get(cell.terrain_id), cell.is_key), true)
		production = amounts if not amounts.is_empty() else "Không"
	var building := "Không"
	if cell.has_building():
		building = "%s (gốc %d,%d)" % [cell.building_id, cell.building_origin.x, cell.building_origin.y]
	return "Ô (%d, %d)\nĐịa hình: %s\nSở hữu: %s\nSản lượng mỗi lượt: %s\nCông trình: %s" % [
		cell.coord.x, cell.coord.y, terrain, "Có" if cell.owned else "Không", production, building]
