class_name BuildPanel
extends VBoxContainer
## Lists constructible buildings. Clicking one toggles build mode for it.

signal building_toggled(building_id: StringName)

var _buttons: Dictionary[StringName, Button] = {}


func setup(buildings: Dictionary[StringName, BuildingData], resource_types: Array[ResourceTypeData]) -> void:
	var ids := buildings.keys()
	ids.sort()
	for building_id: StringName in ids:
		var building := buildings[building_id]
		var button := Button.new()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s — %s" % [building.display_name, UiFormat.amounts(building.cost, resource_types)]
		button.pressed.connect(func() -> void: building_toggled.emit(building_id))
		add_child(button)
		_buttons[building_id] = button
		var info := Label.new()
		info.text = building.description
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", 12)
		add_child(info)


## Highlights the selected building, or none for &"".
func set_selected(building_id: StringName) -> void:
	for id in _buttons:
		_buttons[id].set_pressed_no_signal(id == building_id)
