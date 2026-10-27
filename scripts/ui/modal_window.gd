class_name ModalWindow
extends Control
## A window in the middle of the screen over a dimmed background: title, body, a status line and
## a row of action buttons ending with "Đóng (Esc)". Blocks everything underneath (keys too)
## until closed. Subclasses call build_frame() and fill the body. Built in code, touch-ready.

signal closed

const MUTED_COLOR := UiPalette.MUTED
const WARNING_COLOR := UiPalette.WARNING
const GOOD_COLOR := UiPalette.GOOD
## Default window width as a share of the screen; its height follows the content.
const WIDTH_SHARE := 0.5

var _status: Label
var _actions: HBoxContainer
var _close_button: Button
var _closable := true


## Builds the window and returns the body to fill (between the title and the status line).
## A window that is not `closable` has no close button and ignores Esc: one of its actions must
## lead on (the end-of-game screen).
func build_frame(title_text: String, accent: Color, width_share: float = WIDTH_SHARE, closable: bool = true) -> VBoxContainer:
	_closable = closable
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = UiPalette.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = (1.0 - width_share) * 0.5
	panel.anchor_right = 1.0 - panel.anchor_left
	# Centered vertically and as tall as its content.
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	# The paper panel comes from the project theme (GDD §13).
	add_child(panel)
	# Small screens (phones): a window taller or wider than the screen shrinks to fit (GDD §10.2).
	panel.resized.connect(func() -> void: MobileSupport.shrink_to_fit(panel, get_viewport_rect().size))
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var title := _label(title_text, 22)
	title.add_theme_color_override("font_color", UiPalette.ink(accent))
	layout.add_child(title)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	layout.add_child(body)
	_status = _label("", 14)
	_status.visible = false
	layout.add_child(_status)
	layout.add_child(HSeparator.new())
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 10)
	_actions.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(_actions)
	_close_button = _button("Đóng (Esc)", close)
	_close_button.visible = closable
	_actions.add_child(_close_button)
	return body


## `preferred` px, or less when the screen is short: what is left after `reserved` px of the rest
## of the window (title, tabs, buttons). For lists and tab pages that scroll.
func fit_height(preferred: float, reserved: float) -> float:
	return clampf(get_viewport_rect().size.y - reserved, 160.0, preferred)


func close() -> void:
	closed.emit()
	queue_free()


## Adds a button to the action row, left of "Đóng".
func add_action(text: String, on_pressed: Callable, danger: bool = false) -> Button:
	var button := _button(text, on_pressed)
	button.custom_minimum_size = Vector2(160, 44)
	if danger:
		button.add_theme_color_override("font_color", UiPalette.WARNING_ON_WOOD)
	_actions.add_child(button)
	_actions.move_child(button, _close_button.get_index())
	return button


## Result of the last action, green when it went well.
func set_status(text: String, good: bool = true) -> void:
	_status.text = text
	_status.visible = not text.is_empty()
	_status.add_theme_color_override("font_color", GOOD_COLOR if good else WARNING_COLOR)


## A preview line: plain when the action is possible, in the warning color when it is not.
func set_preview(label: Label, text: String, ok: bool) -> void:
	label.text = text
	if ok:
		label.remove_theme_color_override("font_color")
	else:
		label.add_theme_color_override("font_color", WARNING_COLOR)


func _unhandled_key_input(event: InputEvent) -> void:
	if _closable and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
	# Whatever is underneath must not react to keys while the window is open.
	get_viewport().set_input_as_handled()


## Labels inside a row must not wrap: a wrapping label in an HBoxContainer collapses to zero width.
func _label(text: String, font_size: int, wrap: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(on_pressed)
	return button


func _row(children: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for child: Control in children:
		row.add_child(child)
	return row
