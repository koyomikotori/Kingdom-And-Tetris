extends Control
## Main menu (GDD §10.1): continue the latest save, start a new game, load a slot, quit.
## Placeholder look until the art pass (M13). Built in code.

const BACKGROUND_COLOR := Color(0.09, 0.1, 0.13)
const TITLE_COLOR := Color(1.0, 0.85, 0.35)
const WARNING_COLOR := Color(1, 0.6, 0.5)
const NEW_GAME_TEXT := "Ván mới"

var _system := SaveSystem.new()
var _continue_button: Button
var _continue_info: Label
var _new_game_button: Button
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.custom_minimum_size = Vector2(420, 0)
	center.add_child(column)

	var title := _label("Kingdom Tiles", 48)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	column.add_child(title)
	var subtitle := _label("Rise Of Realms", 22)
	subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	column.add_child(subtitle)
	column.add_child(_spacer(24))

	_continue_button = _button("Tiếp tục", _on_continue_pressed)
	column.add_child(_continue_button)
	_continue_info = _label("", 13)
	_continue_info.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	column.add_child(_continue_info)
	_new_game_button = _button(NEW_GAME_TEXT, _on_new_game_pressed)
	column.add_child(_new_game_button)
	column.add_child(_button("Tải game", _on_load_pressed))
	column.add_child(_button("Thoát", func() -> void: get_tree().quit()))
	_status = _label("", 14)
	_status.add_theme_color_override("font_color", WARNING_COLOR)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_refresh()


func _refresh() -> void:
	var slot := _system.latest_slot()
	_continue_button.disabled = slot == ""
	_continue_info.text = "Chưa có bản lưu nào." if slot == "" else "%s: %s" % [SaveSystem.slot_name(slot),
			SaveSlotWindow.describe(_system.slot_info(slot))]


func _on_continue_pressed() -> void:
	_status.text = GameLaunch.load_game(get_tree(), _system, _system.latest_slot())


## A new game soon overwrites the autosave: the first click warns when there is one.
func _on_new_game_pressed() -> void:
	if _system.has_save(SaveSystem.AUTO_SLOT) and _new_game_button.text == NEW_GAME_TEXT:
		_new_game_button.text = "Bản tự động sẽ bị ghi đè. Bấm lần nữa để bắt đầu"
		_new_game_button.add_theme_color_override("font_color", WARNING_COLOR)
		return
	GameLaunch.new_game(get_tree())


func _on_load_pressed() -> void:
	var window := SaveSlotWindow.new()
	add_child(window)
	window.open(SaveSlotWindow.Mode.LOAD, _system)
	window.load_requested.connect(func(slot: String) -> void:
		var error := GameLaunch.load_game(get_tree(), _system, slot)
		if error != "":
			window.show_error(error))


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(on_pressed)
	return button


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
