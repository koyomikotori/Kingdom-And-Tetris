class_name BuildingWindow
extends ModalWindow
## Opens when a building on the board is tapped (Kairosoft style): its information and upgrade
## tabs (the castle also has "Chiêu hiền" to recruit generals and "Tướng" to manage them, GDD §8
## M11d), and the actions below (upgrade the castle, move, demolish). Every action first explains
## what it will do and waits for "Xác nhận".

## The player confirmed moving the building at `origin`; the kingdom scene lets them pick the spot.
signal move_requested(origin: Vector2i)
## The building was demolished; `refund` is what came back.
signal demolished(building_name: String, refund: Dictionary)

const ACCENT := Color(1.0, 0.85, 0.35)

enum Action { NONE, UPGRADE, MOVE, DEMOLISH, CUSTOM }

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
## What CUSTOM does once confirmed (recruit, refresh, appoint, dismiss).
var _custom: Callable
var _recruit_box: VBoxContainer
var _generals_box: VBoxContainer


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
	if _is_castle:
		_recruit_box = _tab_box("Chiêu hiền")
		_generals_box = _tab_box("Tướng")
		state.generals.changed.connect(_refresh)
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


func _tab_box(title: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = title
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 10)
	_tabs.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	return box


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
		lines.append("Tướng tuyển được: tới %d sao (tab Chiêu hiền)." % _state.castle_level)
		var commander := _state.generals.commander
		lines.append("Tổng tướng: %s." % ("%s %s" % [commander.name, commander.star_text()] if commander != null else "chưa có"))
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
	_refresh_generals()
	var next := _state.next_castle_level()
	if next == null:
		_upgrade.text = "Thành chính đã đạt cấp cao nhất (%d)." % _state.castle_level
		_upgrade_button.disabled = true
		return
	var result := _state.check_castle_upgrade()
	_upgrade.text = "Lên cấp %d: %s.\nCấp mới: thêm %d chỗ cho đơn vị lính, mở khóa công trình cần cấp %d, tuyển được tướng tới %d sao.%s" % [
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
		Action.CUSTOM:
			_custom.call()


## Like _ask, for the generals tabs: `text` says what will happen, `on_confirm` does it.
func _ask_custom(text: String, on_confirm: Callable) -> void:
	_pending = Action.CUSTOM
	_custom = on_confirm
	_confirm_text.text = text
	_confirm_box.visible = true


# --- Generals (castle only) ---------------------------------------------------------------

func _refresh_generals() -> void:
	var generals := _state.generals
	for box in [_recruit_box, _generals_box]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	var room := generals.generals.size() < Generals.MAX_GENERALS
	_recruit_box.add_child(_muted("Ứng viên tới %d sao (cấp thành). Đang có %d/%d tướng. Danh sách mới sau %d lượt." % [
			_state.castle_level, generals.generals.size(), Generals.MAX_GENERALS,
			maxi(0, Generals.CANDIDATE_TURNS - (_state.turn - generals.candidates_turn))]))
	for i in generals.candidates.size():
		var candidate := generals.candidates[i]
		var cost := generals.cost_of(candidate)
		var result := generals.check_recruit(_state.stockpile, i)
		var button := _button("Tuyển", _ask_custom.bind("Tuyển %s %s? Trả %s; phí nuôi %s mỗi lượt." % [candidate.name,
				candidate.star_text(), UiFormat.amounts(cost, _resource_types),
				UiFormat.amounts(generals.ranks[candidate.stars].upkeep, _resource_types)], _recruit.bind(i)))
		button.disabled = result != Generals.RecruitResult.OK
		button.custom_minimum_size = Vector2(110, 44)
		var reason := "" if result == Generals.RecruitResult.OK else (" Đã đủ %d tướng." % Generals.MAX_GENERALS
				if not room else " Chưa đủ tài nguyên.")
		_recruit_box.add_child(_general_row(candidate, "Giá: %s.%s" % [UiFormat.amounts(cost, _resource_types), reason], [button]))
	var refresh := _button("Làm mới ngay (%s)" % UiFormat.amounts(Generals.REFRESH_COST, _resource_types),
			_ask_custom.bind("Đổi danh sách ứng viên ngay? Trả %s." % UiFormat.amounts(Generals.REFRESH_COST, _resource_types),
			_buy_refresh))
	refresh.disabled = not _state.stockpile.can_afford(Generals.REFRESH_COST)
	_recruit_box.add_child(refresh)

	if generals.generals.is_empty():
		_generals_box.add_child(_muted("Chưa có tướng nào. Tuyển ở tab Chiêu hiền."))
	for general in generals.generals:
		var status := "Tổng tướng" if general == generals.commander else "Dự bị"
		if not general.is_ready():
			status += ", bị thương (còn %d lượt)" % general.wounded_turns
		var buttons: Array = []
		if general != generals.commander:
			buttons.append(_button("Làm tổng tướng", _ask_custom.bind("Giao quyền tổng tướng cho %s?" % general.name,
					generals.set_commander.bind(general))))
		var dismiss := _button("Sa thải", _ask_custom.bind("Sa thải %s %s? Không hoàn tác được." % [general.name,
				general.star_text()], generals.dismiss.bind(general)))
		dismiss.add_theme_color_override("font_color", WARNING_COLOR)
		buttons.append(dismiss)
		_generals_box.add_child(_general_row(general, "%s. Phí nuôi: %s mỗi lượt." % [status,
				UiFormat.amounts(generals.ranks[general.stars].upkeep, _resource_types)], buttons))


## Name, stars, stats and trait (with whether its condition holds), plus a line and buttons.
func _general_row(general: General, extra: String, buttons: Array) -> Control:
	var text := "%s %s · Võ lực %d · Thống suất %d" % [general.name, general.star_text(), general.might, general.command]
	var trait_data: GeneralTraitData = _state.generals.traits.get(general.trait_id)
	if trait_data != null:
		var active := trait_data.is_active(_state.board, trait_data.defending_only)
		text += "\nĐặc tính %s: %s (%s%s)" % [trait_data.display_name, trait_data.description,
				trait_data.describe_condition(_state.terrains, _state.buildings), " — đang có tác dụng" if active else " — chưa đạt"]
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_label(text, 14))
	column.add_child(_muted(extra))
	var row := _row([column])
	for button: Button in buttons:
		row.add_child(button)
	return row


func _muted(text: String) -> Label:
	var label := _label(text, 13)
	label.add_theme_color_override("font_color", MUTED_COLOR)
	return label


func _recruit(index: int) -> void:
	var name := _state.generals.candidates[index].name
	if _state.generals.recruit(_state.stockpile, index) == Generals.RecruitResult.OK:
		set_status("%s đã gia nhập!" % name)


func _buy_refresh() -> void:
	_state.generals.buy_refresh(_state.stockpile, _state.castle_level, _state.turn)
