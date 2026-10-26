class_name BuildPanel
extends VBoxContainer
## Constructible buildings. Clicking one toggles build mode for it; buildings that need a higher
## castle level, or that reached their limit, are disabled with the reason. Everything else about a
## building (information, castle upgrade, move, demolish) is in its BuildingWindow, opened by
## tapping it on the board.

signal building_toggled(building_id: StringName)

const MUTED_COLOR := Color(1, 1, 1, 0.65)
const WARNING_COLOR := Color(1, 0.6, 0.5)

var _buildings: Dictionary[StringName, BuildingData] = {}
var _resource_types: Array[ResourceTypeData] = []
var _buttons: Dictionary[StringName, Button] = {}
var _info_labels: Dictionary[StringName, Label] = {}
var _castle_label: Label


func setup(buildings: Dictionary[StringName, BuildingData], resource_types: Array[ResourceTypeData]) -> void:
	_buildings = buildings
	_resource_types = resource_types
	_castle_label = _label("", 15)
	add_child(_castle_label)
	add_child(_label("Bấm vào công trình trên bản đồ để xem thông tin, di chuyển hoặc phá hủy. Bấm vào thành chính để nâng cấp thành.", 12))
	add_child(HSeparator.new())
	var ids := buildings.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var level_a := buildings[a].required_castle_level
		var level_b := buildings[b].required_castle_level
		return level_a < level_b if level_a != level_b else String(a) < String(b))
	for building_id: StringName in ids:
		var building := buildings[building_id]
		var button := Button.new()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = building.display_name
		button.pressed.connect(func() -> void: building_toggled.emit(building_id))
		add_child(button)
		_buttons[building_id] = button
		var info := _label(_info_text(building, building.cost), 12)
		add_child(info)
		_info_labels[building_id] = info


## Cost (as it is right now, see KingdomState.building_cost), description, yield and upkeep.
func _info_text(building: BuildingData, cost: Dictionary[StringName, int]) -> String:
	var text := "Giá: %s. %s" % [UiFormat.amounts(cost, _resource_types), building.description]
	if building.is_upgradable():
		text += "\nMỗi lượt (cấp 1): %s. Nâng cấp được tới cấp %d (không vượt cấp thành)." % [
				UiFormat.amounts(building.yields_at(1), _resource_types, true), building.max_level()]
		if not building.upkeep.is_empty():
			text += " Phí duy trì: %s." % UiFormat.amounts(building.upkeep, _resource_types)
	return text


## Castle level, and which buildings the castle level and the limits allow.
func refresh(state: KingdomState) -> void:
	_castle_label.text = "Thành chính cấp %d/%d" % [state.castle_level, state.castle_levels.size()]
	for building_id in _buttons:
		var building := _buildings[building_id]
		var count := state.board.count_buildings(building_id)
		var text := building.display_name
		var most := BuildRules.limit(building, state.castle_level)
		if most > 0:
			text += " (%d/%d)" % [count, most]
		var locked := state.castle_level < building.required_castle_level
		if locked:
			text += " — cần thành cấp %d" % building.required_castle_level
		_buttons[building_id].text = text
		_info_labels[building_id].text = _info_text(building, state.building_cost(building))
		_buttons[building_id].disabled = locked or (most > 0 and count >= most)


## Highlights the selected building, or none for &"".
func set_selected(building_id: StringName) -> void:
	for id in _buttons:
		_buttons[id].set_pressed_no_signal(id == building_id)


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	if font_size < 14:
		label.add_theme_color_override("font_color", MUTED_COLOR)
	return label
