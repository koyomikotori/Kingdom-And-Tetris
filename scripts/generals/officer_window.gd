class_name OfficerWindow
extends ModalWindow
## One general's or advisor's details (GDD §13, M12c): their portrait, a "Chỉ số" tab (stats with
## bars and level points, level and XP, trait or stratagems, post and what it gives, upkeep) and a
## "Trang bị" tab (empty slots until equipment exists, M12d), with Làm tổng tướng / Sa thải below.

const STAT_BAR_WIDTH := 160
const EQUIPMENT_SLOTS: Array[String] = ["Vũ khí", "Giáp", "Phụ kiện"]

var _state: KingdomState
var _officer: Officer
var _resource_types: Array[ResourceTypeData] = ResourceTypeData.load_all()
var _stats: VBoxContainer
var _role: Label
var _commander_button: Button
var _dismiss_button: Button


func open(state: KingdomState, officer: Officer) -> void:
	_state = state
	_officer = officer
	var body := build_frame("%s %s" % [officer.name, officer.star_text()], UiPalette.ACCENT, 0.6)
	var row := _row([])
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	var left := VBoxContainer.new()
	row.add_child(left)
	var portrait := PortraitView.new()
	portrait.setup(officer, 3)
	left.add_child(portrait)
	_role = _label("", 14)
	_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role.custom_minimum_size = Vector2(PortraitView.SIZE * 3, 0)
	left.add_child(_role)
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size = Vector2(0, 300)
	row.add_child(tabs)
	_stats = _tab(tabs, "Chỉ số")
	_build_equipment(_tab(tabs, "Trang bị"))
	if officer is General:
		_commander_button = add_action("Làm tổng tướng", _make_commander)
	_dismiss_button = add_action("Sa thải", _dismiss, true)
	state.generals.changed.connect(_refresh)
	state.advisors.changed.connect(_refresh)
	_refresh()


func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = title
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 10)
	tabs.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	return box


func _refresh() -> void:
	if not _is_still_here():
		close()
		return
	for child in _stats.get_children():
		_stats.remove_child(child)
		child.queue_free()
	if _officer is General:
		_fill_general(_officer as General)
	else:
		_fill_advisor(_officer as Advisor)
	_stats.add_child(_muted(_officer.level_text()))
	if _officer.points > 0:
		var points := _label("Còn %d điểm cộng: bấm +1 cạnh một chỉ số." % _officer.points, 13)
		points.add_theme_color_override("font_color", UiPalette.ACCENT)
		_stats.add_child(points)
	_stats.add_child(_muted("Phí nuôi: %s mỗi lượt." % UiFormat.amounts(_state.generals.ranks[_officer.stars].upkeep,
			_resource_types)))


func _fill_general(general: General) -> void:
	var generals := _state.generals
	var role := "Tổng tướng" if general == generals.commander else "Dự bị"
	_role.text = role + ("" if general.is_ready() else "\nBị thương, còn %d lượt" % general.wounded_turns)
	_commander_button.disabled = general == generals.commander
	_stat_row("Võ lực", general.might, Generals.STAT_MAX, generals.can_spend_point(general, &"might"),
			generals.spend_point.bind(general, &"might"))
	_stat_row("Thống suất", general.command, Generals.STAT_MAX, generals.can_spend_point(general, &"command"),
			generals.spend_point.bind(general, &"command"))
	var trait_data: GeneralTraitData = generals.traits.get(general.trait_id)
	if trait_data != null:
		var active := trait_data.is_active(_state.board, trait_data.defending_only)
		_stats.add_child(_label("Đặc tính %s: %s (%s%s)" % [trait_data.display_name, trait_data.description,
				trait_data.describe_condition(_state.terrains, _state.buildings),
				" — đang có tác dụng" if active else " — chưa đạt"], 13))


func _fill_advisor(advisor: Advisor) -> void:
	var advisors := _state.advisors
	var post := Advisors.POST_NAMES[advisor.post] if advisor.post != Advisor.NO_POST else "Chưa giữ chức"
	_role.text = post + ("" if advisor.is_ready() else "\nBị thương, còn %d lượt" % advisor.wounded_turns)
	for stat in Advisors.STAT_IDS:
		_stat_row(Advisors.STAT_NAMES[stat], advisor.get_stat(stat), Advisors.STAT_MAX,
				advisors.can_spend_point(advisor, stat), advisors.spend_point.bind(advisor, stat))
	if advisor.post != Advisor.NO_POST:
		_stats.add_child(_label(Advisors.describe_post(advisor.post, advisor.stat_for(advisor.post)), 13))
	var posts := _row([_label("Giao chức:", 13, false)])
	for post_id in Advisors.POSTS:
		var button := _button(Advisors.POST_NAMES[post_id], advisors.assign.bind(advisor, post_id))
		button.disabled = advisor.post == post_id
		posts.add_child(button)
	_stats.add_child(posts)
	_stats.add_child(_label("Mưu kế (dùng khi giữ chức Quân sự):", 13))
	for id in advisor.stratagems:
		var stratagem: StratagemData = advisors.stratagems.get(id)
		if stratagem != null:
			_stats.add_child(_muted("%s — %s" % [stratagem.display_name, stratagem.describe(advisor.strategy)]))


## "Name  [bar]  7/10  [+1]".
func _stat_row(stat_name: String, value: int, most: int, can_add: bool, add: Callable) -> void:
	var name_label := _label(stat_name, 14, false)
	name_label.custom_minimum_size = Vector2(96, 0)
	var bar := ProgressBar.new()
	bar.max_value = most
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(STAT_BAR_WIDTH, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value_label := _label("%d/%d" % [value, most], 14, false)
	var row := _row([name_label, bar, value_label])
	if _officer.points > 0:
		var plus := _button("+1", add)
		plus.custom_minimum_size = Vector2(56, 36)
		plus.disabled = not can_add
		row.add_child(plus)
	_stats.add_child(row)


## Three empty slots until equipment exists (M12d).
func _build_equipment(box: VBoxContainer) -> void:
	var slots := _row([])
	for slot_name in EQUIPMENT_SLOTS:
		var slot := PanelContainer.new()
		slot.theme_type_variation = &"InsetPanel"
		slot.custom_minimum_size = Vector2(110, 90)
		var label := _label("%s\nTrống" % slot_name, 13)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", UiPalette.MUTED)
		slot.add_child(label)
		slots.add_child(slot)
	box.add_child(slots)
	box.add_child(_muted("Hệ thống trang bị sắp có: tướng và mưu sĩ sẽ mang vũ khí, giáp và phụ kiện ở đây."))


func _muted(text: String) -> Label:
	var label := _label(text, 13)
	label.add_theme_color_override("font_color", UiPalette.MUTED)
	return label


func _is_still_here() -> bool:
	if _officer is General:
		return _state.generals.generals.has(_officer)
	return _state.advisors.advisors.has(_officer)


func _make_commander() -> void:
	_state.generals.set_commander(_officer as General)
	set_status("%s giờ là tổng tướng." % _officer.name)


## Dismissal cannot be undone: the first press asks, the second dismisses.
func _dismiss() -> void:
	if _dismiss_button.text == "Sa thải":
		_dismiss_button.text = "Chắc chắn?"
		set_status("Bấm lần nữa để sa thải %s. Không hoàn tác được." % _officer.name, false)
		return
	if _officer is General:
		_state.generals.dismiss(_officer as General)
	else:
		_state.advisors.dismiss(_officer as Advisor)
