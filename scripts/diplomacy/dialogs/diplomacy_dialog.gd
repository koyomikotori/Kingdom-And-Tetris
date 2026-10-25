class_name DiplomacyDialog
extends ModalWindow
## Window for one diplomatic action with one clan (trade, gift, treaty, war…), Shogun 2 style:
## the clan panel only lists the actions and each opens one of these. Subclasses fill _build(),
## _build_actions() and _refresh(); every action still goes through Diplomacy / Wars / Alliances.
## Actions that use resources show the kingdom's stockpile at the top.

const DEFAULT_AMOUNT := 5

var state: KingdomState
var clan_id: StringName
var resource_types: Array[ResourceTypeData] = []
var _stock_label: Label


func open(p_state: KingdomState, p_resource_types: Array[ResourceTypeData], p_clan_id: StringName) -> void:
	state = p_state
	resource_types = p_resource_types
	clan_id = p_clan_id
	var body := build_frame(_title(), clan_data().color)
	_stock_label = _label("", 14)
	_stock_label.add_theme_color_override("font_color", MUTED_COLOR)
	_stock_label.visible = _shows_stockpile()
	body.add_child(_stock_label)
	body.add_child(HSeparator.new())
	_build(body)
	_build_actions()
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


func clan_data() -> ClanData:
	return state.diplomacy.clans[clan_id].data


# --- For subclasses -----------------------------------------------------------------------

func _title() -> String:
	return clan_data().display_name


func _shows_stockpile() -> bool:
	return false


## Adds the form to `content`.
func _build(_content: VBoxContainer) -> void:
	pass


## Adds the action buttons (left of "Đóng") with add_action().
func _build_actions() -> void:
	pass


## Updates previews and which actions are possible.
func _refresh() -> void:
	pass


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
