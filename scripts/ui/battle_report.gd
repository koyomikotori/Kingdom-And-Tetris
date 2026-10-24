class_name BattleReport
extends Control
## Modal post-battle summary: winner, losses and damage per unit type for both sides,
## and what the kingdom gained or lost. Built in code; emits `closed` when dismissed.

signal closed

const WIN_COLOR := Color(0.55, 0.95, 0.55)
const LOSS_COLOR := Color(1.0, 0.5, 0.45)


## `raid` is the dictionary returned by RaidSystem.resolve.
func show_raid(raid: Dictionary, resource_types: Array[ResourceTypeData], units: Dictionary[StringName, UnitData]) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.13, 0.14, 0.17)
	background.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", background)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var record: BattleRecord = raid.record
	var won: bool = raid.won
	var title := Label.new()
	title.text = "Đánh lui quân cướp!" if won else "Thất thủ trước quân cướp!"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", WIN_COLOR if won else LOSS_COLOR)
	box.add_child(title)
	box.add_child(_label("Quân cướp tấn công đầu lượt. Phe %s %s (sau %d giây)." % [
			record.sides[record.loser()].display_name.to_lower(), _end_reason_text(record.end_reason),
			roundi(record.duration)]))

	for side in [record.sides[BattleRecord.DEFENDER], record.sides[BattleRecord.ATTACKER]]:
		box.add_child(_side_table(side))

	var outcome: Array[String] = []
	if not raid.casualties.is_empty():
		outcome.append("Tử trận: %s." % _unit_counts(raid.casualties, units))
	if not raid.scattered.is_empty():
		outcome.append("Tan rã (đơn vị bị vỡ): %s." % _unit_counts(raid.scattered, units))
	if not raid.retreat_losses.is_empty():
		outcome.append("Mất khi rút lui (50%%): %s." % _unit_counts(raid.retreat_losses, units))
	var lost := UiFormat.amounts(raid.resources_lost, resource_types)
	if not lost.is_empty():
		outcome.append("Bị cướp mất: %s." % lost)
	var reward := UiFormat.amounts(raid.reward, resource_types)
	if not reward.is_empty():
		outcome.append("Chiến lợi phẩm: %s." % reward)
	if not outcome.is_empty():
		box.add_child(_label("\n".join(outcome)))

	var button := Button.new()
	button.text = "Tiếp tục (Enter)"
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(close)
	box.add_child(button)


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
	grid.add_theme_constant_override("h_separation", 18)
	box.add_child(grid)
	for text in ["Đơn vị", "Đầu trận", "Tử trận", "Còn lại", "Hạ được", "Trạng thái"]:
		var cell := _label(text, false)
		cell.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		grid.add_child(cell)
	for unit in side.units:
		var status := "Bị vỡ" if unit.broken else ("Tử trận hết" if unit.alive() == 0 else "Giữ vững")
		for text in [unit.data.display_name, str(unit.start_soldiers), str(unit.lost()), str(unit.alive()),
				str(roundi(unit.kills)), status]:
			grid.add_child(_label(text, false))
	return box


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
