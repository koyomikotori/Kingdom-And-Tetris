class_name DiplomacyDialog
extends Control
## Modal window in the middle of the world map for one diplomatic action with one clan (trade,
## gift, treaty, war…), Shogun 2 style: the clan panel only lists the actions and each opens one
## of these. Subclasses fill _build() and _refresh(); every action still goes through Diplomacy /
## Wars / Alliances. Actions that use resources show the kingdom's stockpile at the top.
## Built in code; emits `closed` when dismissed (button or Esc). No hover needed (touch-ready).

signal closed

const MUTED_COLOR := Color(1, 1, 1, 0.65)
const WARNING_COLOR := Color(1, 0.6, 0.5)
const GOOD_COLOR := Color(0.55, 0.95, 0.55)
const DEFAULT_AMOUNT := 5
## Window width as a share of the screen; its height follows the content.
const WIDTH_SHARE := 0.5

var state: KingdomState
var clan_id: StringName
var resource_types: Array[ResourceTypeData] = []
var _stock_label: Label
var _status: Label
var _content: VBoxContainer
var _actions: HBoxContainer


func open(p_state: KingdomState, p_resource_types: Array[ResourceTypeData], p_clan_id: StringName) -> void:
	state = p_state
	resource_types = p_resource_types
	clan_id = p_clan_id
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = (1.0 - WIDTH_SHARE) * 0.5
	panel.anchor_right = 1.0 - panel.anchor_left
	# Centered vertically and as tall as its content.
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.13, 0.14, 0.17)
	background.set_corner_radius_all(6)
	background.border_color = clan_data().color.darkened(0.3)
	background.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", background)
	add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var title := _label(_title(), 22)
	title.add_theme_color_override("font_color", clan_data().color)
	layout.add_child(title)
	_stock_label = _label("", 14)
	_stock_label.add_theme_color_override("font_color", MUTED_COLOR)
	_stock_label.visible = _shows_stockpile()
	layout.add_child(_stock_label)
	layout.add_child(HSeparator.new())
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	layout.add_child(_content)
	_build(_content)
	_status = _label("", 14)
	_status.visible = false
	layout.add_child(_status)
	layout.add_child(HSeparator.new())
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 10)
	_actions.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(_actions)
	_build_actions()
	_actions.add_child(_button("Đóng (Esc)", close))

	state.diplomacy.changed.connect(refresh)
	state.wars.changed.connect(refresh)
	state.stockpile.changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _shows_stockpile():
		var parts: Array[String] = []
		for type in resource_types:
			parts.append("%s %d" % [type.display_name, state.stockpile.get_amount(type.resource_id)])
		_stock_label.text = "Kho của bạn: " + " · ".join(parts)
	_refresh()


func close() -> void:
	closed.emit()
	queue_free()


func clan_data() -> ClanData:
	return state.diplomacy.clans[clan_id].data


# --- For subclasses -----------------------------------------------------------------------

func _title() -> String:
	return clan_data().display_name


func _shows_stockpile() -> bool:
	return false


## Adds the form to `content`.
func _build(_content_box: VBoxContainer) -> void:
	pass


## Adds the action buttons (left of "Đóng") with add_action().
func _build_actions() -> void:
	pass


## Updates previews and which actions are possible.
func _refresh() -> void:
	pass


func add_action(text: String, on_pressed: Callable, danger: bool = false) -> Button:
	var button := _button(text, on_pressed)
	button.custom_minimum_size = Vector2(160, 44)
	if danger:
		button.add_theme_color_override("font_color", WARNING_COLOR)
	_actions.add_child(button)
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
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
	# The world map underneath must not react to keys while a dialog is open.
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


func _amount_box(value: int = DEFAULT_AMOUNT, min_value: int = 0, max_value: int = 999) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = min_value
	box.max_value = max_value
	box.value = value
	box.custom_minimum_size = Vector2(110, 0)
	box.value_changed.connect(func(_value: float) -> void: refresh())
	return box


func _resource_option(selected: int) -> OptionButton:
	var option := OptionButton.new()
	option.focus_mode = Control.FOCUS_NONE
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for type in resource_types:
		option.add_item(type.display_name)
	option.select(mini(selected, resource_types.size() - 1))
	option.item_selected.connect(func(_index: int) -> void: refresh())
	return option


func _selected_resource(option: OptionButton) -> StringName:
	return resource_types[option.selected].resource_id


func _resource_name(resource_id: StringName) -> String:
	for type in resource_types:
		if type.resource_id == resource_id:
			return type.display_name
	return String(resource_id)


func _resource_names(ids: Array[StringName]) -> String:
	var names: Array[String] = []
	for resource_id in ids:
		names.append(_resource_name(resource_id))
	return ", ".join(names) if not names.is_empty() else "—"


func _clan_name(id: StringName) -> String:
	return state.diplomacy.clans[id].data.display_name
