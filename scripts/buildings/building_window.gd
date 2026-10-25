class_name BuildingWindow
extends ModalWindow
## Opens when a building on the board is tapped (Kairosoft style): its information and upgrade
## tabs, and the actions below (upgrade the castle, move, demolish). An action first explains what
## it will do and waits for "Xác nhận".

## The player confirmed moving the building at `origin`; the kingdom scene lets them pick the spot.
signal move_requested(origin: Vector2i)
## The building was demolished; `refund` is what came back.
signal demolished(building_name: String, refund: Dictionary)

const ACCENT := Color(1.0, 0.85, 0.35)

enum Action { NONE, UPGRADE, MOVE, DEMOLISH }

var _state: KingdomState
var _origin: Vector2i
var _resource_types: Array[ResourceTypeData] = ResourceTypeData.load_all()
var _is_castle := false
var _building: BuildingData
var _tabs: TabContainer
var _info: Label
var _upgrade: Label
var _upgrade_button: Button
var _confirm_box: VBoxContainer
var _confirm_text: Label
var _pending := Action.NONE


func open(state: KingdomState, origin: Vector2i) -> void:
	_state = state
	_origin = origin
	var cell := state.board.get_cell(origin)
	_is_castle = cell.building_id == BoardData.CASTLE_ID
	_building = state.buildings.get(cell.building_id)
	var body := build_frame(_title(), ACCENT, 0.42)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(0, 180)
	body.add_child(_tabs)
	_info = _tab_label("Thông tin")
	_upgrade = _tab_label("Nâng cấp")
	_confirm_box = VBoxContainer.new()
	_confirm_box.visible = false
	body.add_child(_confirm_box)
	_confirm_text = _label("", 15)
	_confirm_text.add_theme_color_override("font_color", ACCENT)
	_confirm_box.add_child(_confirm_text)
	var confirm := _button("Xác nhận", _on_confirm_pressed)
	confirm.custom_minimum_size = Vector2(140, 44)
	var cancel := _button("Hủy", _cancel_action)
	cancel.custom_minimum_size = Vector2(140, 44)
	_confirm_box.add_child(_row([confirm, cancel]))
	if _is_castle:
		_upgrade_button = add_action("Nâng cấp", _ask.bind(Action.UPGRADE))
	else:
		add_action("Di chuyển", _ask.bind(Action.MOVE))
		add_action("Phá hủy", _ask.bind(Action.DEMOLISH), true)
	state.stockpile.changed.connect(_refresh)
	_refresh()


func _title() -> String:
	if _is_castle:
		return "Thành chính cấp %d" % _state.castle_level
	return _building.display_name if _building != null else "Công trình"


func _tab_label(title: String) -> Label:
	var margin := MarginContainer.new()
	margin.name = title
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 10)
	_tabs.add_child(margin)
	var label := _label("", 14)
	margin.add_child(label)
	return label


func _refresh() -> void:
	var cell := _state.board.get_cell(_origin)
	var terrain: TerrainData = _state.terrains.get(cell.terrain_id)
	var lines: Array[String] = []
	if _is_castle:
		lines.append("Trung tâm của vương quốc. Không thể phá hủy hay di chuyển; mất hết đất xung quanh mà thua thêm một trận xâm lược thì thành thất thủ.")
		lines.append("Chỗ cho đơn vị lính: %d (gồm doanh trại và cấp thành)." % _state.get_squad_capacity())
		lines.append("Tướng tuyển được: tới %d sao (sắp có)." % _state.castle_level)
	elif _building != null:
		lines.append(_building.description)
		lines.append("Vị trí: ô (%d, %d), %s%s." % [_origin.x, _origin.y, terrain.display_name if terrain != null else "đất hoang",
				" ◆" if cell.is_key else ""])
		var produced := Economy.building_yield(_building, cell.is_key)
		if not produced.is_empty():
			lines.append("Mỗi lượt: %s%s." % [UiFormat.amounts(produced, _resource_types, true),
					"" if _state.buildings_supplied else " (đang ngừng vì thiếu phí duy trì)"])
		if not _building.upkeep.is_empty():
			lines.append("Phí duy trì: %s mỗi lượt." % UiFormat.amounts(_building.upkeep, _resource_types))
		if _building.max_count > 0:
			lines.append("Đang có %d/%d." % [_state.board.count_buildings(_building.building_id), _building.max_count])
	_info.text = "\n".join(lines)
	if not _is_castle:
		_upgrade.text = "Công trình này chưa có nâng cấp."
		return
	var next := _state.next_castle_level()
	if next == null:
		_upgrade.text = "Thành chính đã đạt cấp cao nhất (%d)." % _state.castle_level
		_upgrade_button.disabled = true
		return
	var result := _state.check_castle_upgrade()
	_upgrade.text = "Lên cấp %d: %s.\nCấp mới: thêm %d chỗ cho đơn vị lính, mở khóa công trình cần cấp %d, tuyển được tướng tới %d sao (sắp có).%s" % [
			next.level, UiFormat.amounts(next.cost, _resource_types), next.squad_capacity, next.level, next.level,
			"\nChưa đủ tài nguyên." if result == KingdomState.CastleResult.CANNOT_AFFORD else ""]
	_upgrade_button.disabled = result != KingdomState.CastleResult.OK


## First step of an action: say what it will do and wait for confirmation.
func _ask(action: Action) -> void:
	_pending = action
	match action:
		Action.UPGRADE:
			_tabs.current_tab = 1
			_confirm_text.text = "Nâng thành chính lên cấp %d? Trả %s." % [_state.castle_level + 1,
					UiFormat.amounts(_state.next_castle_level().cost, _resource_types)]
		Action.MOVE:
			_confirm_text.text = "Di chuyển %s? Bảng sẽ đóng; chọn ô mới trên bản đồ (miễn phí, đúng địa hình, trong lãnh thổ). Esc để hủy." % _building.display_name
		Action.DEMOLISH:
			var refund := UiFormat.amounts(_state.demolish_refund(_building.building_id), _resource_types)
			_confirm_text.text = "Phá hủy %s? Hoàn lại %s. Không thể hoàn tác." % [_building.display_name,
					refund if not refund.is_empty() else "không gì"]
	_confirm_box.visible = true


func _cancel_action() -> void:
	_pending = Action.NONE
	_confirm_box.visible = false


func _on_confirm_pressed() -> void:
	var action := _pending
	_cancel_action()
	match action:
		Action.UPGRADE:
			if _state.upgrade_castle() == KingdomState.CastleResult.OK:
				set_status("Thành chính đã lên cấp %d!" % _state.castle_level)
			_refresh()
		Action.MOVE:
			move_requested.emit(_origin)
			close()
		Action.DEMOLISH:
			demolished.emit(_building.display_name, _state.demolish(_origin))
			close()
