extends Node
## Autoload (GDD §10.2, M13): drag anywhere on a scrolling list to scroll it, with a finger or the
## mouse, even when the drag starts on a button or a card. Once the pointer moved more than
## DEADZONE the press is a drag: the button underneath never counts it as a press.

## Screen pixels the pointer may move before a press becomes a drag.
const DEADZONE := 10.0
## Godot's own touch drag-scrolling is switched off (it does not start on buttons) so lists never
## scroll twice.
const NATIVE_DEADZONE := 1000000
## Where the pointer is sent when a drag ends, so the pressed control lets go without a click.
const AWAY := Vector2(-100000, -100000)

var _scroll: ScrollContainer
var _start := Vector2.ZERO
var _dragging := false
## A press is down and the list under it is not looked up yet (Godot updates the control under the
## pointer once per frame, so it is found on the first move).
var _armed := false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_scroll = null
			_armed = true
			_start = event.position
			_dragging = false
			return
		_armed = false
		if _scroll != null:
			var was_dragging := _dragging
			_scroll = null
			_dragging = false
			if was_dragging:
				# The pressed control sees the pointer leave, then the release far away: no click.
				get_viewport().set_input_as_handled()
				var leave := InputEventMouseMotion.new()
				leave.position = AWAY
				leave.global_position = AWAY
				leave.button_mask = MOUSE_BUTTON_MASK_LEFT
				get_viewport().push_input(leave, true)
				var away: InputEventMouseButton = event.duplicate()
				away.position = AWAY
				away.global_position = AWAY
				get_viewport().push_input(away, true)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if _armed:
			_armed = false
			_scroll = _scroll_under_pointer()
		if _scroll == null:
			return
		if not _dragging and event.position.distance_to(_start) > DEADZONE:
			_dragging = true
		if _dragging:
			_scroll.scroll_vertical -= roundi(event.relative.y)
			get_viewport().set_input_as_handled()


## The innermost list under the pointer that has something to scroll, or null.
func _scroll_under_pointer() -> ScrollContainer:
	var control := get_viewport().gui_get_hovered_control()
	while control != null:
		if control is ScrollContainer:
			var scroll := control as ScrollContainer
			scroll.scroll_deadzone = NATIVE_DEADZONE
			var bar := scroll.get_v_scroll_bar()
			if bar != null and bar.max_value > bar.page:
				return scroll
		control = control.get_parent() as Control
	return null
