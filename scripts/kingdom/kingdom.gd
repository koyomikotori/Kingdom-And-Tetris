extends Node2D
## Kingdom screen: turns input into KingdomState actions and keeps the board view and UI in sync.

const NO_SELECTION := -1
const NO_BUILDING: StringName = &""
const TAB_TITLES: Array[String] = ["Mảnh đất", "Xây dựng", "Quân đội"]

@export var board_size := 12
## 0 = random seed each run. Set a number to replay the same pieces while testing.
@export var piece_seed := 0

var state: KingdomState
var _terrains: Dictionary[StringName, TerrainData] = {}
var _shapes: Dictionary[StringName, PieceShapeData] = {}
var _buildings: Dictionary[StringName, BuildingData] = {}
var _resource_types: Array[ResourceTypeData] = []
var _resource_labels: Dictionary[StringName, Label] = {}
## Hand index of the selected piece, or NO_SELECTION.
var _selected := NO_SELECTION
## Building chosen in the build tab, or NO_BUILDING. Never set together with _selected.
var _selected_building := NO_BUILDING
## Open post-battle report; blocks kingdom input while shown.
var _battle_report: BattleReport
## Battle being played; the battle screen swallows input itself.
var _battle_screen: BattleScreen
## Open world map; it swallows input itself.
var _world_map: WorldMapScreen

@onready var board_view: BoardView = $BoardView
@onready var camera: CameraController = $Camera
@onready var cell_info_label: Label = %CellInfo
@onready var side_panel: Control = %SidePanel
@onready var top_bar: Control = %TopBar
@onready var resource_bar: Container = %ResourceBar
@onready var turn_label: Label = %TurnLabel
@onready var tabs: TabContainer = %Tabs
@onready var piece_list: Container = %PieceList
@onready var build_panel: BuildPanel = %BuildPanel
@onready var army_panel: ArmyPanel = %ArmyPanel
@onready var placement_status: Label = %PlacementStatus
@onready var end_turn_button: Button = %EndTurnButton
@onready var diplomacy_button: Button = %DiplomacyButton


func _ready() -> void:
	_terrains = TerrainLibrary.load_all()
	_shapes = PieceShapeLibrary.load_all()
	_buildings = BuildingData.load_all()
	_resource_types = ResourceTypeData.load_all()
	var units := UnitData.load_all()
	_build_resource_labels()
	for i in TAB_TITLES.size():
		tabs.set_tab_title(i, TAB_TITLES[i])

	var board := BoardData.create_starting_board(board_size)
	board_view.setup(board, _terrains, _buildings)
	board_view.cell_hovered.connect(_on_cell_hovered)
	board_view.cell_clicked.connect(_on_cell_clicked)
	# Container sizes are only sorted next frame, so use the top bar's minimum height.
	camera.focus_on(board_view.get_board_rect(), side_panel.size.x, top_bar.get_combined_minimum_size().y)

	var seed_value := piece_seed if piece_seed != 0 else randi()
	var hand := PieceHand.new(PieceGenerator.new(_shapes, _terrains, seed_value))
	state = KingdomState.new(board, hand, _terrains, _buildings, units, seed_value)
	state.hand.changed.connect(_rebuild_piece_cards)
	state.stockpile.changed.connect(_refresh_economy)
	state.army.changed.connect(_refresh_economy)
	state.diplomacy.changed.connect(_refresh_economy)
	state.turn_started.connect(_on_turn_started)

	build_panel.setup(_buildings, _resource_types)
	build_panel.building_toggled.connect(_toggle_building)
	army_panel.setup(units, _resource_types)
	army_panel.recruit_requested.connect(_on_recruit_requested)
	army_panel.disband_requested.connect(_on_disband_requested)
	tabs.tab_changed.connect(func(_tab: int) -> void: _clear_selection())
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	diplomacy_button.pressed.connect(_open_world_map)
	state.start()
	_on_cell_hovered(BoardView.OFF_BOARD)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if _battle_report != null:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
			_battle_report.close()
			get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_G:
			board_view.show_coords = not board_view.show_coords
		KEY_ESCAPE:
			_clear_selection()
		KEY_1, KEY_2, KEY_3:
			tabs.current_tab = 0
			_toggle_selection(event.keycode - KEY_1)
		KEY_ENTER, KEY_KP_ENTER:
			_on_end_turn_pressed()


func _on_cell_hovered(coord: Vector2i) -> void:
	if coord == BoardView.OFF_BOARD:
		cell_info_label.text = "Rê chuột lên một ô để xem thông tin.\nCuộn: zoom · Chuột phải/giữa: kéo · G: bật/tắt tọa độ"
	else:
		cell_info_label.text = _describe_cell(state.board.get_cell(coord))
	_update_ghost()


func _on_cell_clicked(coord: Vector2i) -> void:
	if _selected != NO_SELECTION:
		_place_selected_piece(coord)
	elif _selected_building != NO_BUILDING:
		_build_selected(coord)
	else:
		print(_describe_cell(state.board.get_cell(coord)).replace("\n", " | "))


func _place_selected_piece(coord: Vector2i) -> void:
	var piece := state.hand.pieces[_selected]
	var result := state.place_piece(_selected, coord - piece.get_anchor())
	if result != PlacementRules.Result.OK:
		placement_status.text = PlacementRules.describe(result)
		return
	_select(NO_SELECTION)
	_refresh_economy()
	placement_status.text = "Đã đặt mảnh đất."
	_on_cell_hovered(coord)


func _build_selected(coord: Vector2i) -> void:
	var building := _buildings[_selected_building]
	var result := state.build(_selected_building, coord - _building_anchor(building))
	if result != BuildRules.Result.OK:
		placement_status.text = BuildRules.describe(result)
		return
	_toggle_building(NO_BUILDING)
	placement_status.text = "Đã xây %s." % building.display_name
	_on_cell_hovered(coord)


func _on_recruit_requested(unit_id: StringName) -> void:
	var unit := state.units[unit_id]
	var result := state.recruit(unit_id)
	placement_status.text = "Đã tuyển 1 đơn vị %s (+%d lính)." % [unit.display_name, unit.squad_size] \
			if result == RecruitmentRules.Result.OK \
			else RecruitmentRules.describe(result, unit, _buildings, _terrains)


func _on_disband_requested(squad: Army.Squad) -> void:
	var unit_name := state.units[squad.unit_id].display_name
	var soldiers := squad.soldiers
	state.disband(squad)
	placement_status.text = "Đã giải tán đơn vị %s (%d lính)." % [unit_name, soldiers]


func _on_end_turn_pressed() -> void:
	_clear_selection()
	var report := state.end_turn()
	var lines: Array[String] = []
	var collected := UiFormat.amounts(report.collected, _resource_types)
	lines.append("Đã thu: %s." % collected if not collected.is_empty() else "Lượt trước không thu được tài nguyên nào.")
	var upkeep := UiFormat.amounts(report.upkeep, _resource_types)
	if not upkeep.is_empty():
		lines.append("Nuôi quân: %s." % upkeep)
	for unit_id: StringName in report.deserted:
		lines.append("%d %s bỏ đi vì thiếu lương thực!" % [report.deserted[unit_id], state.units[unit_id].display_name])
	var replenished := _unit_amounts(report.replenished)
	if not replenished.is_empty():
		lines.append("Bổ sung quân: %s." % replenished)
	for entry: Dictionary in report.agreements:
		lines.append(_describe_agreement_turn(entry))
	if not report.buildings_supplied:
		lines.append("Không đủ phí duy trì công trình: công trình tạm ngưng tác dụng lượt này.")
	if report.has("pending_raid"):
		lines.append("Quân cướp tấn công!")
		_play_raid(report.pending_raid)
	placement_status.text = "\n".join(lines)


## "+5 Kiếm sĩ, +4 Cung thủ" from unit_id -> soldiers.
func _unit_amounts(counts: Dictionary) -> String:
	var parts: Array[String] = []
	for unit_id: StringName in counts:
		parts.append("+%d %s" % [counts[unit_id], state.units[unit_id].display_name])
	return ", ".join(parts)


## Shows the raid on the battle screen, then applies its outcome and opens the report.
func _play_raid(simulator: BattleSimulator) -> void:
	_battle_screen = BattleScreen.new()
	$UI.add_child(_battle_screen)
	_battle_screen.start(simulator, BattleRecord.DEFENDER, "Quân cướp tấn công vương quốc!")
	_battle_screen.finished.connect(func(record: BattleRecord) -> void:
		_battle_screen = null
		var result := state.finish_raid(record)
		placement_status.text += " %s" % ("Đã đánh lui." if result.won else "Thất thủ.")
		_show_battle_report(result))


func _describe_agreement_turn(entry: Dictionary) -> String:
	var agreement: Diplomacy.Agreement = entry.agreement
	var clan_name := state.diplomacy.clans[agreement.clan_id].data.display_name
	var text: String
	match entry.event:
		&"delivered":
			text = "Hợp đồng với %s: đưa %s, nhận %s." % [clan_name,
					_amount_text(agreement.give_id, agreement.give_amount), _amount_text(agreement.get_id, agreement.get_amount)]
		&"missed":
			text = "Không đủ %s để giao cho %s (quan hệ -%d)." % [_amount_text(agreement.give_id, agreement.give_amount),
					clan_name, Diplomacy.AGREEMENT_MISSED_PENALTY]
		_:
			text = "%s đã hủy hợp đồng vì quan hệ thù địch." % clan_name
	if entry.completed:
		text += " Hợp đồng đã hoàn thành."
	return text


func _amount_text(resource_id: StringName, amount: int) -> String:
	var amounts: Dictionary[StringName, int] = {resource_id: amount}
	return UiFormat.amounts(amounts, _resource_types)


func _open_world_map() -> void:
	if _world_map != null:
		return
	_clear_selection()
	_world_map = WorldMapScreen.new()
	$UI.add_child(_world_map)
	_world_map.open(state, _resource_types)
	_world_map.closed.connect(func() -> void: _world_map = null)


func _show_battle_report(raid: Dictionary) -> void:
	_battle_report = BattleReport.new()
	$UI.add_child(_battle_report)
	_battle_report.show_raid(raid, _resource_types, state.units)
	_battle_report.closed.connect(func() -> void: _battle_report = null)


func _on_turn_started(turn: int) -> void:
	turn_label.text = "Lượt %d" % turn
	_refresh_economy()


func _clear_selection() -> void:
	_select(NO_SELECTION)
	if _selected_building != NO_BUILDING:
		_toggle_building(NO_BUILDING)


func _toggle_selection(index: int) -> void:
	_select(NO_SELECTION if index == _selected else index)


func _select(index: int) -> void:
	if index >= state.hand.pieces.size():
		return
	_selected = index
	if index != NO_SELECTION and _selected_building != NO_BUILDING:
		_selected_building = NO_BUILDING
		build_panel.set_selected(NO_BUILDING)
	for i in piece_list.get_child_count():
		(piece_list.get_child(i) as PieceCard).set_pressed_no_signal(i == _selected)
	placement_status.text = "" if _selected == NO_SELECTION else "Nhấn chuột trái lên bản đồ để đặt. Esc: bỏ chọn."
	_update_ghost()


## Selecting the already-selected building (or NO_BUILDING) leaves build mode.
func _toggle_building(building_id: StringName) -> void:
	_selected_building = NO_BUILDING if building_id == _selected_building else building_id
	if _selected_building != NO_BUILDING and _selected != NO_SELECTION:
		_select(NO_SELECTION)
	build_panel.set_selected(_selected_building)
	placement_status.text = "" if _selected_building == NO_BUILDING \
			else "Nhấn chuột trái lên bản đồ để xây. Esc: bỏ chọn."
	_update_ghost()


func _rebuild_piece_cards() -> void:
	for child in piece_list.get_children():
		piece_list.remove_child(child)
		child.queue_free()
	for i in state.hand.pieces.size():
		var piece := state.hand.pieces[i]
		var card := PieceCard.new()
		var shape := _shapes.get(piece.shape_id) as PieceShapeData
		card.setup(piece, _terrains, shape.display_name if shape != null else String(piece.shape_id))
		card.pressed.connect(_toggle_selection.bind(i))
		piece_list.add_child(card)
	_select(_selected if _selected < state.hand.pieces.size() else NO_SELECTION)


func _update_ghost() -> void:
	var coord := board_view.get_hovered_cell()
	if coord == BoardView.OFF_BOARD or (_selected == NO_SELECTION and _selected_building == NO_BUILDING):
		board_view.hide_ghost()
		return
	if _selected_building != NO_BUILDING:
		var building := _buildings[_selected_building]
		var origin := coord - _building_anchor(building)
		var result := BuildRules.check(state.board, state.stockpile, building, origin)
		board_view.show_building_ghost(building, origin, result == BuildRules.Result.OK)
		placement_status.text = BuildRules.describe(result)
		return
	var piece := state.hand.pieces[_selected]
	var piece_origin := coord - piece.get_anchor()
	var placement := PlacementRules.check(state.board, piece, piece_origin)
	board_view.show_ghost(piece, piece_origin, placement == PlacementRules.Result.OK)
	if placement != PlacementRules.Result.OK:
		placement_status.text = PlacementRules.describe(placement)
		return
	var delta := UiFormat.amounts(Economy.placement_delta(state.board, piece, piece_origin, _terrains), _resource_types, true)
	placement_status.text = "Có thể đặt. Sản lượng mỗi lượt: %s." % (delta if not delta.is_empty() else "không đổi")


## The cell of a building that sits under the mouse cursor.
func _building_anchor(building: BuildingData) -> Vector2i:
	return (building.size - Vector2i.ONE) / 2


func _build_resource_labels() -> void:
	for type in _resource_types:
		var label := Label.new()
		# Hovering shows where the per-turn change comes from (tooltip filled in _refresh_economy).
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		resource_bar.add_child(label)
		_resource_labels[type.resource_id] = label


## Resource bar (stock, net income per turn and its breakdown) and the army tab depend on stock,
## army, territory and trade agreements.
func _refresh_economy() -> void:
	var net := state.get_net_income()
	var breakdown := state.get_income_breakdown()
	for type in _resource_types:
		var label := _resource_labels[type.resource_id]
		var amount := state.stockpile.get_amount(type.resource_id)
		var change: int = net.get(type.resource_id, 0)
		label.text = "%s: %d (%+d)" % [type.display_name, amount, change]
		var lines: Array[String] = ["%s: %d (%+d mỗi lượt)" % [type.display_name, amount, change]]
		for entry: Dictionary in breakdown.get(type.resource_id, []):
			lines.append("  %+d  %s" % [entry.amount, _income_source_text(entry)])
		if lines.size() == 1:
			lines.append("  Chưa có nguồn thu hay chi nào.")
		label.tooltip_text = "\n".join(lines)
	army_panel.refresh(state)


func _income_source_text(entry: Dictionary) -> String:
	match entry.source:
		&"terrain":
			var terrain := _terrains[entry.id].display_name
			var keys := ", %d ô ◆" % entry.key_count if entry.key_count > 0 else ""
			return "%s (%d ô%s)" % [terrain, entry.count, keys]
		&"army":
			return "Nuôi quân (%d đơn vị)" % entry.count
		&"building":
			return "%s ×%d (phí duy trì)" % [_buildings[entry.id].display_name, entry.count]
		&"agreement":
			return "Hợp đồng với %s" % state.diplomacy.clans[entry.id].data.display_name
	return String(entry.source)


func _describe_cell(cell: CellData) -> String:
	var terrain := "Đất hoang"
	if cell.has_terrain():
		var data := board_view.get_terrain(cell.terrain_id)
		terrain = data.display_name if data != null else String(cell.terrain_id)
	if cell.is_key:
		terrain += " ◆ (ô quan trọng, x%d sản lượng)" % Economy.KEY_CELL_MULTIPLIER
	var production := "Không"
	if cell.owned:
		var amounts := UiFormat.amounts(Economy.cell_yield(_terrains.get(cell.terrain_id), cell.is_key), _resource_types, true)
		production = amounts if not amounts.is_empty() else "Không"
	var building := "Không"
	if cell.building_id == BoardData.CASTLE_ID:
		building = "Thành chính"
	elif cell.has_building():
		var data: BuildingData = _buildings.get(cell.building_id)
		building = data.display_name if data != null else String(cell.building_id)
	return "Ô (%d, %d)\nĐịa hình: %s\nSở hữu: %s\nSản lượng mỗi lượt: %s\nCông trình: %s" % [
		cell.coord.x, cell.coord.y, terrain, "Có" if cell.owned else "Không", production, building]
