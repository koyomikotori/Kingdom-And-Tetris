class_name GameMenuWindow
extends ModalWindow
## In-game menu from the top bar (GDD §10.1): keep playing, save, load, turn the map effects on or
## off (GameSettings, M13c) or go back to the main menu.

## The map effects setting changed: the kingdom scene applies it at once.
signal settings_changed

const ACCENT := UiPalette.ACCENT
const TO_MENU_TEXT := "Về menu chính"

var _state: KingdomState
var _system: SaveSystem
var _host: Node
var _last_save: Label
var _to_menu_button: Button


## `host` is where the save / load window opens (over this one).
func open(state: KingdomState, system: SaveSystem, host: Node) -> void:
	_state = state
	_system = system
	_host = host
	var body := build_frame("Menu", ACCENT, 0.3)
	body.add_child(_menu_button("Tiếp tục chơi", close))
	body.add_child(_menu_button("Lưu game", _open_slots.bind(SaveSlotWindow.Mode.SAVE)))
	body.add_child(_menu_button("Tải game", _open_slots.bind(SaveSlotWindow.Mode.LOAD)))
	var effects := _menu_button("", func() -> void: pass)
	effects.text = _effects_text()
	effects.pressed.connect(func() -> void:
		GameSettings.set_map_effects(not GameSettings.map_effects())
		effects.text = _effects_text()
		settings_changed.emit())
	body.add_child(effects)
	_to_menu_button = _menu_button(TO_MENU_TEXT, _on_to_menu_pressed)
	_to_menu_button.add_theme_color_override("font_color", UiPalette.WARNING_ON_WOOD)
	body.add_child(_to_menu_button)
	_last_save = _label("", 13)
	_last_save.add_theme_color_override("font_color", MUTED_COLOR)
	body.add_child(_last_save)
	_refresh_last_save()


func _effects_text() -> String:
	return "Hiệu ứng bản đồ: %s" % ("Bật" if GameSettings.map_effects() else "Tắt")


func _menu_button(text: String, on_pressed: Callable) -> Button:
	var button := _button(text, on_pressed)
	button.custom_minimum_size = Vector2(0, 52)
	return button


func _refresh_last_save() -> void:
	var slot := _system.latest_slot()
	_last_save.text = "Chưa có bản lưu nào." if slot == "" else "Lần lưu gần nhất: %s, %s." % [
			SaveSystem.slot_name(slot), SaveSlotWindow.describe(_system.slot_info(slot))]


func _open_slots(mode: SaveSlotWindow.Mode) -> void:
	var window := SaveSlotWindow.new()
	_host.add_child(window)
	window.open(mode, _system, _state, true)
	window.closed.connect(_refresh_last_save)
	window.load_requested.connect(func(slot: String) -> void:
		var error := GameLaunch.load_game(get_tree(), _system, slot)
		if error != "":
			window.show_error(error))


## Leaving drops what was not saved: the first click asks for confirmation.
func _on_to_menu_pressed() -> void:
	if _to_menu_button.text == TO_MENU_TEXT:
		_to_menu_button.text = "Chắc chắn? Tiến trình chưa lưu sẽ mất"
		return
	GameLaunch.to_menu(get_tree())
