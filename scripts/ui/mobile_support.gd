class_name MobileSupport
extends RefCounted
## Phone and tablet details (GDD §10.2, M13): larger UI on small screens and Android's Back button.

## The UI is enlarged on phones by at most this much (more would not fit the landscape layout).
const MAX_UI_SCALE := 1.15
## A button 44 px tall in the design should be about this many millimetres on the screen.
const BUTTON_MM := 7.0
const BUTTON_PX := 44.0
## Design height (project.godot viewport_height).
const DESIGN_HEIGHT := 720.0


## Enlarges the UI on phones so buttons are big enough for a finger (no change on computers).
static func apply_ui_scale(window: Window) -> void:
	if not OS.has_feature("mobile"):
		return
	window.content_scale_factor = ui_scale(DisplayServer.screen_get_dpi(), DisplayServer.screen_get_size().y)


## The content scale for a screen of `dpi` and `height` pixels (landscape), between 1 and MAX_UI_SCALE.
static func ui_scale(dpi: int, height: int) -> float:
	if dpi <= 0 or height <= 0:
		return 1.0
	var button_mm := BUTTON_PX * height / DESIGN_HEIGHT / dpi * 25.4
	return clampf(BUTTON_MM / button_mm, 1.0, MAX_UI_SCALE)


## Shrinks `control` (a window's panel) around its center when it is bigger than `viewport_size`
## less `margin` on each side, so nothing is cut off on small screens. Call it after layout.
static func shrink_to_fit(control: Control, viewport_size: Vector2, margin: float = 12.0) -> void:
	var room := viewport_size - Vector2.ONE * margin * 2.0
	var factor := minf(1.0, minf(room.x / maxf(1.0, control.size.x), room.y / maxf(1.0, control.size.y)))
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * factor


## Acts like an Esc key press, so every window's and screen's own Esc handling runs.
static func send_escape() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)
