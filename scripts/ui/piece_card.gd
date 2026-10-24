class_name PieceCard
extends Button
## Side-panel button showing a small picture of one land piece. Toggled on while selected.

const PREVIEW_CELL := 18
const CARD_HEIGHT := 96
const SELECTED_BORDER_COLOR := Color(1.0, 0.92, 0.55)

var _piece: LandPiece
var _terrains: Dictionary[StringName, TerrainData] = {}


func setup(piece: LandPiece, terrains: Dictionary[StringName, TerrainData], shape_name: String) -> void:
	_piece = piece
	_terrains = terrains
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0, CARD_HEIGHT)
	tooltip_text = _build_tooltip(shape_name)
	queue_redraw()


func _draw() -> void:
	if _piece == null:
		return
	var piece_px := Vector2(_piece.get_size() * PREVIEW_CELL)
	var top_left := (size - piece_px) * 0.5
	for i in _piece.offsets.size():
		var rect := Rect2(top_left + Vector2(_piece.offsets[i] * PREVIEW_CELL), Vector2.ONE * PREVIEW_CELL)
		var terrain: TerrainData = _terrains.get(_piece.terrains[i])
		draw_rect(rect, terrain.color if terrain != null else Color.MAGENTA)
		draw_rect(rect, Color(0, 0, 0, 0.6), false, 1.0)
		if _piece.is_key_cell(i):
			BoardView.draw_key_marker(self, rect)
	if button_pressed:
		draw_rect(Rect2(Vector2.ZERO, size).grow(-1), SELECTED_BORDER_COLOR, false, 2.0)


func _build_tooltip(shape_name: String) -> String:
	var names: Array[String] = []
	for i in _piece.terrains.size():
		var terrain: TerrainData = _terrains.get(_piece.terrains[i])
		var label := terrain.display_name if terrain != null else String(_piece.terrains[i])
		if _piece.is_key_cell(i):
			label += " ◆"
		names.append(label)
	return "%s: %s" % [shape_name, ", ".join(names)]
