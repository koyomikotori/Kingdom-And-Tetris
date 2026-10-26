class_name ArmyPanel
extends VBoxContainer
## Army tab: the kingdom's squads (with a disband button each), then every unit type with stats,
## cost and a recruit button.

signal recruit_requested(unit_id: StringName)
signal disband_requested(squad: Army.Squad)

const HEADER_COLOR := Color(1.0, 0.92, 0.55)
const WARNING_COLOR := Color(1, 0.6, 0.5)
const XP_COLOR := Color(0.55, 0.8, 1.0)

var _units: Array[UnitData] = []
var _resource_types: Array[ResourceTypeData] = []
var _count_labels: Dictionary[StringName, Label] = {}
var _reason_labels: Dictionary[StringName, Label] = {}
var _buttons: Dictionary[StringName, Button] = {}
var _summary_label: Label
var _squad_list: VBoxContainer


func setup(units: Array[UnitData], resource_types: Array[ResourceTypeData]) -> void:
	_units = units
	_resource_types = resource_types
	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_summary_label)
	add_child(_section_label("Đơn vị của bạn"))
	_squad_list = VBoxContainer.new()
	add_child(_squad_list)
	add_child(_section_label("Tuyển quân"))
	for unit in units:
		add_child(HSeparator.new())
		var header := HBoxContainer.new()
		add_child(header)
		var name_label := Label.new()
		name_label.text = unit.display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(name_label)
		var button := Button.new()
		button.text = "Tuyển (+%d)" % unit.squad_size
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: recruit_requested.emit(unit.unit_id))
		header.add_child(button)
		_buttons[unit.unit_id] = button
		var count_label := _small_label("")
		count_label.add_theme_color_override("font_color", HEADER_COLOR)
		add_child(count_label)
		_count_labels[unit.unit_id] = count_label
		add_child(_small_label("%s · %s · %d lính/đơn vị · Sĩ khí %d" % [UnitData.ROW_NAMES[unit.row],
				UnitData.ATTACK_KIND_NAMES[unit.attack_kind], unit.squad_size, unit.morale]))
		add_child(_small_label("Cận chiến %d · Phòng thủ %d · Giáp %d · Xung kích %d" % [
				unit.melee_attack, unit.melee_defense, unit.armor, unit.charge_attack]))
		if unit.attack_kind == UnitData.AttackKind.BOW:
			add_child(_small_label("Bắn xa %d · Nạp tên %s giây" % [unit.range_attack, str(unit.reload_time)]))
		elif unit.attack_kind == UnitData.AttackKind.GUN:
			add_child(_small_label("Bắn xa %d · Chỉ nã 1 loạt đầu trận" % unit.range_attack))
		add_child(_small_label("Giá: %s · Nuôi: %s/lượt mỗi đơn vị" % [
				UiFormat.amounts(unit.recruit_cost, resource_types), UiFormat.amounts(unit.upkeep, resource_types)]))
		var reason := _small_label("")
		reason.add_theme_color_override("font_color", WARNING_COLOR)
		add_child(reason)
		_reason_labels[unit.unit_id] = reason


## Rebuilds the squad list and enables only the units that can be recruited right now.
func refresh(state: KingdomState) -> void:
	var upkeep := UiFormat.amounts(state.get_army_upkeep(), _resource_types)
	var replenish := "Tự bổ sung %d%% quân mỗi lượt." % roundi(KingdomState.REPLENISH_FRACTION * 100) \
			if state.can_replenish() else "Cần doanh trại để bổ sung quân."
	var commander := state.generals.commander
	var leader := "Tổng tướng: chưa có (tuyển ở thành chính, tab Chiêu hiền)."
	if commander != null:
		leader = "Tổng tướng: %s %s · Võ lực %d · Thống suất %d%s" % [commander.name, commander.star_text(),
				commander.might, commander.command,
				"" if commander.is_ready() else " · bị thương, còn %d lượt" % commander.wounded_turns]
	var strategist := "Mưu sĩ Quân sự: chưa có (giao chức ở thành chính, tab Mưu sĩ)."
	var advisor := state.advisors.holder(&"military")
	if advisor != null:
		strategist = "Mưu sĩ Quân sự: %s %s · Mưu lược %d · %d mưu kế%s" % [advisor.name, advisor.star_text(),
				advisor.strategy, advisor.stratagems.size(),
				"" if advisor.is_ready() else " · bị thương, còn %d lượt" % advisor.wounded_turns]
	_summary_label.text = "Đơn vị: %d/%d · %d lính · Nuôi quân, tướng, mưu sĩ: %s/lượt\n%s\n%s\n%s" % [
			state.army.count_squads(), state.get_squad_capacity(), state.army.count_soldiers(),
			upkeep if not upkeep.is_empty() else "0", replenish, leader, strategist]
	_rebuild_squad_list(state)
	for unit in _units:
		_count_labels[unit.unit_id].text = "Đang có: %d đơn vị · %d lính" % [
				state.army.count_squads(unit.unit_id), state.army.count_soldiers(unit.unit_id)]
		var result := RecruitmentRules.check(state.board, state.stockpile, state.army, state.get_squad_capacity(), unit)
		_buttons[unit.unit_id].disabled = result != RecruitmentRules.Result.OK
		_reason_labels[unit.unit_id].text = "" if result == RecruitmentRules.Result.OK \
				else RecruitmentRules.describe(result, unit, state.buildings, state.terrains)
		_reason_labels[unit.unit_id].visible = result != RecruitmentRules.Result.OK


func _rebuild_squad_list(state: KingdomState) -> void:
	for child in _squad_list.get_children():
		_squad_list.remove_child(child)
		child.queue_free()
	if state.army.squads.is_empty():
		_squad_list.add_child(_small_label("(chưa có đơn vị nào)"))
		return
	for squad in state.army.squads:
		var unit := state.units[squad.unit_id]
		var row := HBoxContainer.new()
		_squad_list.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 1)
		row.add_child(info)
		var level := squad.level()
		var level_text := Experience.SQUAD_LEVEL_NAMES[level]
		if level > 0:
			level_text = Experience.SQUAD_LEVEL_MARKS[level] + " " + level_text
		var label := _small_label("%s · %s — %d/%d lính" % [unit.display_name, level_text, squad.soldiers, unit.squad_size])
		if squad.soldiers < unit.squad_size:
			label.add_theme_color_override("font_color", WARNING_COLOR)
		info.add_child(label)
		info.add_child(_xp_bar(Experience.squad_progress(squad.xp)))
		var button := Button.new()
		button.text = "Giải tán"
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 12)
		# Disbanding cannot be undone: the first click asks for confirmation.
		button.pressed.connect(func() -> void:
			if button.text == "Giải tán":
				button.text = "Chắc chắn?"
			else:
				disband_requested.emit(squad))
		row.add_child(button)


## A thin bar showing progress toward the squad's next level.
func _xp_bar(progress: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.value = progress
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = XP_COLOR
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0, 0, 0, 0.35)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", background)
	return bar


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", HEADER_COLOR)
	return label


func _small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	return label
