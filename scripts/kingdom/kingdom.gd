extends Node2D
## Kingdom screen: wires the board data, its view, the camera and the UI together.

@export var board_size := 12

var board: BoardData

@onready var board_view: BoardView = $BoardView
@onready var camera: CameraController = $Camera
@onready var cell_info_label: Label = %CellInfo
@onready var side_panel: Control = %SidePanel


func _ready() -> void:
	board = BoardData.create_starting_board(board_size)
	board_view.setup(board, TerrainLibrary.load_all())
	board_view.cell_hovered.connect(_on_cell_hovered)
	board_view.cell_clicked.connect(_on_cell_clicked)
	camera.focus_on(board_view.get_board_rect(), side_panel.size.x)
	_on_cell_hovered(BoardView.OFF_BOARD)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_G:
		board_view.show_coords = not board_view.show_coords


func _on_cell_hovered(coord: Vector2i) -> void:
	if coord == BoardView.OFF_BOARD:
		cell_info_label.text = "Rê chuột lên một ô để xem thông tin.\nCuộn: zoom · Chuột phải/giữa: kéo · G: bật/tắt tọa độ"
	else:
		cell_info_label.text = _describe_cell(board.get_cell(coord))


func _on_cell_clicked(coord: Vector2i) -> void:
	print(_describe_cell(board.get_cell(coord)).replace("\n", " | "))


func _describe_cell(cell: CellData) -> String:
	var terrain := "Đất hoang"
	if cell.has_terrain():
		var data := board_view.get_terrain(cell.terrain_id)
		terrain = data.display_name if data != null else String(cell.terrain_id)
	var building := "Không"
	if cell.has_building():
		building = "%s (gốc %d,%d)" % [cell.building_id, cell.building_origin.x, cell.building_origin.y]
	return "Ô (%d, %d)\nĐịa hình: %s\nSở hữu: %s\nCông trình: %s" % [
		cell.coord.x, cell.coord.y, terrain, "Có" if cell.owned else "Không", building]
