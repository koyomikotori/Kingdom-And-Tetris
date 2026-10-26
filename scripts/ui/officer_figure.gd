class_name OfficerFigure
extends Control
## An officer's battle sprite standing (and breathing) in lists: the same picture as on the
## battlefield (GameArt.officer_sprite). Read-only.

## Idle animation speed (frames per second).
const FPS := 2.0

var art_scale := 2
var _sprite_id: StringName
var _tints: Dictionary = {}
var _frame := 0


func setup(officer: Officer, scale: int = 2, team: Color = KingdomState.PLAYER_COLOR) -> void:
	art_scale = scale
	var kind := BattleView.ADVISOR_KIND if officer is Advisor else BattleView.GENERAL_KIND
	_sprite_id = GameArt.officer_sprite(kind, officer.look)
	_tints = GameArt.unit_tints(team, officer.look)
	var sheet := GameArt.unit_sheet(_sprite_id)
	var frame_size := GameArt.unit_frame(sheet, &"stand", 0).size if sheet != null else Vector2(16, 16)
	custom_minimum_size = frame_size * scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(_delta: float) -> void:
	var frame := int(Time.get_ticks_msec() / 1000.0 * FPS) % GameArt.UNIT_FRAMES
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _draw() -> void:
	if _sprite_id != &"":
		GameArt.draw_unit(self, _sprite_id, Vector2(size.x * 0.5, size.y), 0.0, Vector2.ONE * art_scale, &"stand",
				_frame, _tints)
