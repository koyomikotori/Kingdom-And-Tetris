class_name ObjectivesWindow
extends ModalWindow
## "Mục tiêu" from the top bar (GDD §9b): progress on each victory path, condition by condition,
## and how safe the castle is.

const ACCENT := UiPalette.ACCENT
const BAR_COLOR := UiPalette.GOLD
const DONE_COLOR := UiPalette.GOOD


func open(state: KingdomState) -> void:
	var body := build_frame("Mục tiêu", ACCENT, 0.66)
	var victory := state.victory
	if victory.won_path != Victory.NO_PATH:
		var won := _label("Bạn đã chiến thắng (%s) và đang chơi tiếp." % Victory.PATH_NAMES[victory.won_path], 15)
		won.add_theme_color_override("font_color", DONE_COLOR)
		body.add_child(won)
	var intro := _label("Đạt một trong hai đường dưới đây để chiến thắng.", 14)
	intro.add_theme_color_override("font_color", MUTED_COLOR)
	body.add_child(intro)
	# One column per path, side by side, so the window fits the screen.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	body.add_child(columns)
	for entry in victory.progress(state):
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.size_flags_stretch_ratio = 1.0
		column.add_theme_constant_override("separation", 6)
		columns.add_child(column)
		_add_path(column, entry)
	body.add_child(HSeparator.new())
	_add_castle(body, state)


func _add_path(body: VBoxContainer, entry: Dictionary) -> void:
	var path: int = entry.path
	var title := _label(Victory.PATH_NAMES[path], 18)
	title.add_theme_color_override("font_color", ACCENT)
	body.add_child(title)
	var description := Victory.PATH_DESCRIPTIONS[path]
	if path == Victory.Path.PROSPERITY:
		description = description % Victory.HOLD_TURNS
	var about := _label(description, 13)
	about.add_theme_color_override("font_color", MUTED_COLOR)
	body.add_child(about)
	body.add_child(_bar(entry.fraction))
	for condition: Dictionary in entry.conditions:
		var line := _label("%s: %d / %d%s" % [condition.text, condition.current, condition.needed,
				"  (đạt)" if condition.met else ""], 14)
		if condition.met:
			line.add_theme_color_override("font_color", DONE_COLOR)
		body.add_child(line)
	if path != Victory.Path.CONQUEST:
		var held := _label("Đã giữ %d / %d lượt liền%s" % [entry.held, Victory.HOLD_TURNS,
				"" if entry.met else " (chưa đạt đủ điều kiện)"], 14)
		if entry.met:
			held.add_theme_color_override("font_color", DONE_COLOR)
		body.add_child(held)


func _add_castle(body: VBoxContainer, state: KingdomState) -> void:
	var title := _label("Thành chính", 18)
	title.add_theme_color_override("font_color", ACCENT)
	body.add_child(title)
	var land := state.board.count_land_outside_castle()
	var text := "Còn %d ô đất ngoài thành. Thua một trận xâm lược khi không còn ô nào thì thành thất thủ và thua cả ván." % land
	var line := _label(text, 14)
	if state.victory.castle_in_danger(state):
		line.text = "Nguy hiểm! " + text
		line.add_theme_color_override("font_color", WARNING_COLOR)
	body.add_child(line)


func _bar(fraction: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.value = fraction
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = BAR_COLOR
	bar.add_theme_stylebox_override("fill", fill)
	return bar
