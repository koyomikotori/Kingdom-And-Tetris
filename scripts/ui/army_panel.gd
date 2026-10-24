class_name ArmyPanel
extends VBoxContainer
## Lists unit types with stats, cost and owned count, plus a recruit button per type.

signal recruit_requested(unit_id: StringName)

var _units: Array[UnitData] = []
var _resource_types: Array[ResourceTypeData] = []
var _count_labels: Dictionary[StringName, Label] = {}
var _reason_labels: Dictionary[StringName, Label] = {}
var _buttons: Dictionary[StringName, Button] = {}
var _upkeep_label: Label


func setup(units: Array[UnitData], resource_types: Array[ResourceTypeData]) -> void:
	_units = units
	_resource_types = resource_types
	_upkeep_label = Label.new()
	_upkeep_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_upkeep_label)
	for unit in units:
		add_child(HSeparator.new())
		var header := HBoxContainer.new()
		add_child(header)
		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(name_label)
		_count_labels[unit.unit_id] = name_label
		var button := Button.new()
		button.text = "Tuyển"
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: recruit_requested.emit(unit.unit_id))
		header.add_child(button)
		_buttons[unit.unit_id] = button
		add_child(_small_label("Máu %d · Công %d · Thủ %d · %s · %s" % [unit.max_hp, unit.attack, unit.defense,
				UnitData.ROW_NAMES[unit.row], UnitData.ATTACK_KIND_NAMES[unit.attack_kind]]))
		add_child(_small_label("Giá: %s · Nuôi: %s/lượt" % [
				UiFormat.amounts(unit.recruit_cost, resource_types), UiFormat.amounts(unit.upkeep, resource_types)]))
		var reason := _small_label("")
		reason.add_theme_color_override("font_color", Color(1, 0.6, 0.5))
		add_child(reason)
		_reason_labels[unit.unit_id] = reason


## Updates counts and enables only the units that can be recruited right now.
func refresh(state: KingdomState) -> void:
	var upkeep := UiFormat.amounts(state.get_army_upkeep(), _resource_types)
	_upkeep_label.text = "Quân số: %d · Nuôi quân: %s/lượt" % [
			state.army.get_total(), upkeep if not upkeep.is_empty() else "0"]
	for unit in _units:
		_count_labels[unit.unit_id].text = "%s ×%d" % [unit.display_name, state.army.get_count(unit.unit_id)]
		var result := RecruitmentRules.check(state.board, state.stockpile, unit)
		_buttons[unit.unit_id].disabled = result != RecruitmentRules.Result.OK
		_reason_labels[unit.unit_id].text = "" if result == RecruitmentRules.Result.OK \
				else RecruitmentRules.describe(result, unit, state.buildings, state.terrains)
		_reason_labels[unit.unit_id].visible = result != RecruitmentRules.Result.OK


func _small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	return label
