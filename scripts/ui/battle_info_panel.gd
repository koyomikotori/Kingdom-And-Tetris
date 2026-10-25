class_name BattleInfoPanel
extends VBoxContainer
## One side's column on the battle screen: total soldiers, then per unit its name, soldier count,
## a soldiers bar and a morale bar. Units lent by another clan carry its name and banner tint;
## experienced squads carry their level mark (Experience.SQUAD_LEVEL_MARKS).
## Always visible (no hover needed, for touch screens later).

const MORALE_COLOR := Color(1.0, 0.85, 0.3)
const BAR_BACKGROUND := Color(0, 0, 0, 0.45)

var _side: BattleSide
var _total_label: Label
var _rows: Array = []  # [name Label, count Label, soldiers ProgressBar, morale ProgressBar, container]


## `screen_side`: 0 = left, 1 = right (picks the colors, see BattleView.SIDE_COLORS).
func setup(side: BattleSide, screen_side: int) -> void:
	var color := BattleView.SIDE_COLORS[screen_side]
	_side = side
	add_theme_constant_override("separation", 6)
	var title := _label(side.display_name, 15)
	title.add_theme_color_override("font_color", color)
	add_child(title)
	_total_label = _label("", 12)
	add_child(_total_label)
	for unit in side.units:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 1)
		add_child(box)
		var unit_name := unit.data.display_name
		if unit.ally != null:
			unit_name += " · " + unit.ally.display_name
		elif unit.is_general_guard:
			unit_name += " · " + side.general_name
		elif unit.level > 0:
			unit_name += " " + Experience.SQUAD_LEVEL_MARKS[unit.level]
		var name_label := _label(unit_name, 12)
		if unit.ally != null:
			name_label.add_theme_color_override("font_color", unit.ally.color.lightened(0.3))
		box.add_child(name_label)
		var count_label := _label("", 11)
		box.add_child(count_label)
		var soldiers := _bar(BattleView.unit_color(unit, screen_side), unit.start_soldiers)
		box.add_child(soldiers)
		var morale := _bar(MORALE_COLOR, maxf(unit.data.morale, unit.morale))
		box.add_child(morale)
		_rows.append([name_label, count_label, soldiers, morale, box])
	refresh()


func refresh() -> void:
	_total_label.text = "%d/%d lính" % [_side.alive_total(), _side.start_total()]
	for i in _side.units.size():
		var unit := _side.units[i]
		var row: Array = _rows[i]
		row[1].text = "%d/%d%s" % [unit.alive(), unit.start_soldiers, " · VỠ" if unit.broken else ""]
		row[2].value = unit.alive()
		row[3].value = maxf(0.0, unit.morale)
		row[4].modulate.a = 1.0 if unit.is_active() else 0.4


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	return label


func _bar(color: Color, max_value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = max_value
	bar.value = max_value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var background := StyleBoxFlat.new()
	background.bg_color = BAR_BACKGROUND
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", background)
	return bar
