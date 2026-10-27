class_name RecruitWindow
extends CatalogWindow
## The "Tuyển lính" shop (GDD §8, M12d): unit types by formation row (Tất cả / Tiền tuyến /
## Hậu tuyến) with their sprite, stats, cost and upkeep. Recruiting is instant; the window stays
## open to recruit more.

const CATEGORIES: Array[String] = ["Tất cả", "Tiền tuyến", "Hậu tuyến"]
const FIGURE_SCALE := 5

var _state: KingdomState
var _resource_types: Array[ResourceTypeData] = ResourceTypeData.load_all()


func open(state: KingdomState) -> void:
	_state = state
	build_catalog("Tuyển lính", CATEGORIES, "Tuyển")
	state.stockpile.changed.connect(refresh)
	state.army.changed.connect(refresh)


func _entries(index: int) -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _state.units:
		var front := _state.units[id].row == UnitData.Row.FRONT
		if index == 0 or (index == 1) == front:
			ids.append(id)
	return ids


func _entry_icon(id: StringName) -> Texture2D:
	var sheet := GameArt.unit_sheet(_state.units[id].get_sprite_id())
	if sheet == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = GameArt.unit_frame(sheet, &"stand", 0)
	return atlas


func _entry_name(id: StringName) -> String:
	return _state.units[id].display_name


func _entry_text(id: StringName) -> String:
	return "%s  ×%d" % [_entry_name(id), _state.army.count_squads(id)]


func _picture(id: StringName) -> Control:
	var figure := OfficerFigure.new()
	figure.setup_unit(_state.units[id], FIGURE_SCALE)
	return figure


func _entry_details(id: StringName) -> String:
	var unit := _state.units[id]
	var lines: Array[String] = [
		"%s · %s · %d lính/đơn vị · Sĩ khí %d" % [UnitData.ROW_NAMES[unit.row], UnitData.ATTACK_KIND_NAMES[unit.attack_kind],
				unit.squad_size, unit.morale],
		"Cận chiến %d · Phòng thủ %d · Giáp %d · Xung kích %d" % [unit.melee_attack, unit.melee_defense, unit.armor,
				unit.charge_attack],
	]
	if unit.attack_kind == UnitData.AttackKind.BOW:
		lines.append("Bắn xa %d · Nạp tên %s giây" % [unit.range_attack, str(unit.reload_time)])
	elif unit.attack_kind == UnitData.AttackKind.GUN:
		lines.append("Bắn xa %d · Chỉ nã 1 loạt đầu trận" % unit.range_attack)
	lines.append("Giá: %s. Nuôi: %s mỗi lượt mỗi đơn vị." % [UiFormat.amounts(unit.recruit_cost, _resource_types),
			UiFormat.amounts(unit.upkeep, _resource_types)])
	lines.append("Đang có %d đơn vị · %d lính. Chỗ cho đơn vị: %d/%d." % [_state.army.count_squads(id),
			_state.army.count_soldiers(id), _state.army.count_squads(), _state.get_squad_capacity()])
	return "\n".join(lines)


func _block_reason(id: StringName) -> String:
	var unit := _state.units[id]
	var result := RecruitmentRules.check(_state.board, _state.stockpile, _state.army, _state.get_squad_capacity(), unit)
	return "" if result == RecruitmentRules.Result.OK else RecruitmentRules.describe(result, unit, _state.buildings, _state.terrains)


func _on_action(id: StringName) -> void:
	var unit := _state.units[id]
	var result := _state.recruit(id)
	if result == RecruitmentRules.Result.OK:
		set_status("Đã tuyển 1 đơn vị %s (+%d lính)." % [unit.display_name, unit.squad_size])
	else:
		set_status(RecruitmentRules.describe(result, unit, _state.buildings, _state.terrains), false)
	refresh()
