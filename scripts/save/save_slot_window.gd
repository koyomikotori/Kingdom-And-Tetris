class_name SaveSlotWindow
extends ModalWindow
## The save slots (GDD §10.1), to save into or to load from. Each row shows the slot's turn,
## territory, soldiers and when it was saved. Overwriting a slot, and loading over a game in
## progress, ask for a second click.

enum Mode { SAVE, LOAD }

## LOAD mode: the player picked this slot; the host loads it (GameLaunch.load_game).
signal load_requested(slot: String)

const ACCENT := UiPalette.ACCENT

var _mode: Mode
var _system: SaveSystem
var _state: KingdomState
var _confirm_load := false
var _rows: VBoxContainer
## Slot whose button was pressed once and now asks for confirmation, or "".
var _confirming := ""


## `state` is the game to save (SAVE mode). `confirm_load`: loading replaces a game in progress.
func open(mode: Mode, system: SaveSystem, state: KingdomState = null, confirm_load: bool = false) -> void:
	_mode = mode
	_system = system
	_state = state
	_confirm_load = confirm_load
	var body := build_frame("Lưu game" if mode == Mode.SAVE else "Tải game", ACCENT, 0.45)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	body.add_child(_rows)
	refresh()


func refresh() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for slot in SaveSystem.all_slots():
		# The autosave is written by the game only.
		if _mode == Mode.SAVE and slot == SaveSystem.AUTO_SLOT:
			continue
		_rows.add_child(_slot_row(slot))


func _slot_row(slot: String) -> Control:
	var info := _system.slot_info(slot)
	var text := _label("", 14)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.text = "%s\n%s" % [SaveSystem.slot_name(slot), describe(info) if not info.is_empty() else "Trống"]
	var button := _button("", _on_slot_pressed.bind(slot))
	button.custom_minimum_size = Vector2(190, 52)
	if _mode == Mode.SAVE:
		button.text = "Lưu" if info.is_empty() else "Ghi đè"
	else:
		button.text = "Tải"
		button.disabled = info.is_empty()
	if slot == _confirming:
		button.text = "Chắc chắn ghi đè?" if _mode == Mode.SAVE else "Bỏ ván đang chơi?"
		button.add_theme_color_override("font_color", UiPalette.WARNING_ON_WOOD)
	var row := _row([text, button])
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"InsetPanel"
	frame.add_child(row)
	return frame


## "Lượt 12 · 34 ô đất · 80 lính · 25/10 14:03" from SaveSystem.slot_info().
static func describe(info: Dictionary) -> String:
	var time := Time.get_datetime_dict_from_unix_time(info.saved_at + _utc_offset_seconds())
	return "Lượt %d · %d ô đất · %d lính · %s · %02d/%02d %02d:%02d" % [info.turn, info.cells, info.soldiers,
			Difficulty.NAMES[clampi(info.get("difficulty", Difficulty.Level.NORMAL), 0, Difficulty.NAMES.size() - 1)],
			time.day, time.month, time.hour, time.minute]


static func _utc_offset_seconds() -> int:
	return int(Time.get_time_zone_from_system().bias) * 60


func _on_slot_pressed(slot: String) -> void:
	var needs_confirm := (_mode == Mode.SAVE and _system.has_save(slot)) or (_mode == Mode.LOAD and _confirm_load)
	if needs_confirm and _confirming != slot:
		_confirming = slot
		refresh()
		return
	_confirming = ""
	if _mode == Mode.LOAD:
		load_requested.emit(slot)
		return
	var error := _system.save(_state, slot)
	refresh()
	if error == OK:
		set_status("Đã lưu vào %s." % SaveSystem.slot_name(slot))
	else:
		set_status("Không lưu được (lỗi %s)." % error_string(error), false)


## A load that could not happen (broken or newer save).
func show_error(message: String) -> void:
	set_status(message, false)
