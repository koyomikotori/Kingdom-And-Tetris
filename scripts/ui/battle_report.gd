class_name BattleReport
extends Control
## Modal post-battle summary: winner, losses and damage per unit type for both sides,
## and what the kingdom gained or lost. Built in code; emits `closed` when dismissed.

signal closed

const WIN_COLOR := Color(0.55, 0.95, 0.55)
const LOSS_COLOR := Color(1.0, 0.5, 0.45)
## Gap around the panel as a share of the screen: 15% left/right, 6% top/bottom.
const PANEL_MARGIN := Vector2(0.15, 0.06)


## `raid` is the dictionary returned by RaidSystem.apply_outcome.
func show_raid(raid: Dictionary, resource_types: Array[ResourceTypeData], units: Dictionary[StringName, UnitData]) -> void:
	var lines := army_loss_lines(raid, units)
	var lost := UiFormat.amounts(raid.resources_lost, resource_types)
	if not lost.is_empty():
		lines.append("Bị cướp mất: %s." % lost)
	var reward := UiFormat.amounts(raid.reward, resource_types)
	if not reward.is_empty():
		lines.append("Chiến lợi phẩm: %s." % reward)
	show_battle("Đánh lui quân cướp!" if raid.won else "Thất thủ trước quân cướp!", raid.won,
			"Quân cướp tấn công đầu lượt.", raid.record, BattleRecord.DEFENDER, lines)


## Generic report: `player_side` is the BattleRecord side the kingdom fought on (its table comes
## first); `lines` describe what the kingdom gained or lost.
func show_battle(title_text: String, won: bool, intro: String, record: BattleRecord, player_side: int,
		lines: Array[String]) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	# Sized as a share of the screen so it grows and shrinks with the window like the battle screen.
	var panel := PanelContainer.new()
	panel.anchor_left = PANEL_MARGIN.x
	panel.anchor_right = 1.0 - PANEL_MARGIN.x
	panel.anchor_top = PANEL_MARGIN.y
	panel.anchor_bottom = 1.0 - PANEL_MARGIN.y
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.13, 0.14, 0.17)
	background.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", background)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", WIN_COLOR if won else LOSS_COLOR)
	layout.add_child(title)
	# Tables and outcome scroll when there are many units; the title and button stay in place.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	box.add_child(_label("%s Phe %s %s (sau %d giây)." % [intro,
			record.sides[record.loser()].display_name.to_lower(), _end_reason_text(record.end_reason),
			roundi(record.duration)]))

	for side in [record.sides[player_side], record.sides[1 - player_side]]:
		box.add_child(_side_table(side))
	if not lines.is_empty():
		box.add_child(_label("\n".join(lines)))

	var button := Button.new()
	button.text = "Tiếp tục (Enter)"
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(close)
	layout.add_child(button)


## Lines for the kingdom's losses from a BattleOutcome.apply_to_army result.
func army_loss_lines(losses: Dictionary, units: Dictionary[StringName, UnitData]) -> Array[String]:
	var lines: Array[String] = []
	if not losses.casualties.is_empty():
		lines.append("Tử trận: %s." % _unit_counts(losses.casualties, units))
	if not losses.scattered.is_empty():
		lines.append("Mất (đơn vị bị vỡ hoặc tan rã): %s." % _unit_counts(losses.scattered, units))
	if not losses.retreat_losses.is_empty():
		lines.append("Mất khi rút lui (50%%): %s." % _unit_counts(losses.retreat_losses, units))
	return lines


static func _end_reason_text(reason: BattleRecord.EndReason) -> String:
	match reason:
		BattleRecord.EndReason.NO_ARMY:
			return "không có quân để chiến đấu"
		BattleRecord.EndReason.ALL_BROKEN:
			return "bị vỡ hoặc tiêu diệt toàn bộ"
		BattleRecord.EndReason.RETREAT:
			return "rút lui"
	return "rút lui khi hết giờ vì còn ít quân hơn"


func close() -> void:
	closed.emit()
	queue_free()


func _side_table(side: BattleSide) -> Control:
	var box := VBoxContainer.new()
	var header := _label("%s — còn %d/%d" % [side.display_name, side.alive_total(), side.start_total()])
	header.add_theme_font_size_override("font_size", 17)
	box.add_child(header)
	if side.units.is_empty():
		box.add_child(_label("(không có quân)"))
		return box
	var grid := GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	box.add_child(grid)
	for text in ["Đơn vị", "Đầu trận", "Tử trận", "Còn lại", "Hạ được", "Trạng thái"]:
		var cell := _cell(text)
		cell.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		grid.add_child(cell)
	for unit in side.units:
		var status := "Bị vỡ" if unit.broken else ("Tử trận hết" if unit.alive() == 0 else "Giữ vững")
		for text in [unit.data.display_name, str(unit.start_soldiers), str(unit.lost()), str(unit.alive()),
				str(roundi(unit.kills)), status]:
			grid.add_child(_cell(text))
	return box


## Table cell that shares the panel width with the other columns.
func _cell(text: String) -> Label:
	var label := _label(text, false)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _unit_counts(counts: Dictionary, units: Dictionary[StringName, UnitData]) -> String:
	var parts: Array[String] = []
	for unit_id in counts:
		var unit: UnitData = units.get(unit_id)
		parts.append("%d %s" % [counts[unit_id], unit.display_name if unit != null else String(unit_id)])
	return ", ".join(parts)


## Table cells must not wrap: a wrapping label inside a GridContainer collapses to zero width.
func _label(text: String, wrap: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
