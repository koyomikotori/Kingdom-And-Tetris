extends Node2D
## Kingdom screen: turns input into KingdomState actions and keeps the board view and UI in sync.

const NO_SELECTION := -1
const NO_BUILDING: StringName = &""
const NO_MOVE := Vector2i(-1, -1)
## Short titles: four tabs of equal width share the 340 px side panel (_build_tab_buttons).
const TAB_TITLES: Array[String] = ["Đất", "Xây dựng", "Quân đội", "Tướng sĩ"]

@export var board_size := 12
## 0 = random seed each run. Set a number to replay the same pieces while testing.
@export var piece_seed := 0
## Writes the autosave slot at the start of every turn (GDD §10.1). Previews turn it off so they
## never overwrite the player's saves.
@export var autosave := true

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
## Origin of the building being moved (picked in its BuildingWindow), or NO_MOVE.
var _moving_from := NO_MOVE
## A clicked empty cell whose information stays in the cell info panel.
var _info_cell := BoardView.OFF_BOARD
## The cell info panel shows only its first line.
var _info_collapsed := false
## The resource breakdown opened by clicking a resource (it stays open, unlike the tooltip).
var _resource_popup: PanelContainer
var _resource_popup_text: Label
var _resource_popup_id: StringName = &""
## Open post-battle report; blocks kingdom input while shown.
var _battle_report: BattleReport
## Battle being played; the battle screen swallows input itself.
var _battle_screen: BattleScreen
## Open world map; it swallows input itself.
var _world_map: WorldMapScreen
var _save_system := SaveSystem.new()
## Victory reached while a battle was still to be shown; the end screen waits for its report.
var _pending_victory := Victory.NO_PATH

@onready var board_view: BoardView = $BoardView
## Walkers on the map (M13c), a child of the board view.
var _map_life: MapLifeView
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
## Built in code (_build_officers_tab).
var officers_panel: OfficersPanel
@onready var placement_status: Label = %PlacementStatus
@onready var end_turn_button: Button = %EndTurnButton
@onready var diplomacy_button: Button = %DiplomacyButton
@onready var game_menu_button: Button = %GameMenuButton
@onready var objectives_button: Button = %ObjectivesButton


func _ready() -> void:
	_terrains = TerrainLibrary.load_all()
	_shapes = PieceShapeLibrary.load_all()
	_buildings = BuildingData.load_all()
	_resource_types = ResourceTypeData.load_all()
	var units := UnitData.load_all()
	_build_resource_labels()
	_build_officers_tab()
	_build_tab_buttons()
	_build_resource_popup()
	var info_panel: Control = cell_info_label.get_parent().get_parent()
	info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	info_panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_info_collapsed = not _info_collapsed
			_on_cell_hovered(board_view.get_hovered_cell()))

	# A game picked in the main menu, or a new one.
	var game := GameLaunch.take_pending_game()
	var board := BoardData.from_save(game.board) if not game.is_empty() else BoardData.create_starting_board(board_size)
	board_view.setup(board, _terrains, _buildings)
	board_view.cell_hovered.connect(_on_cell_hovered)
	board_view.cell_tapped.connect(_on_cell_clicked)
	board_view.pan_dragged.connect(camera.pan)
	_focus_camera()

	var seed_value := piece_seed if piece_seed != 0 else randi()
	var hand := PieceHand.new(PieceGenerator.new(_shapes, _terrains, seed_value))
	state = KingdomState.new(board, hand, _terrains, _buildings, units, seed_value)
	if not game.is_empty():
		state.load_save(game)
	state.hand.changed.connect(_rebuild_piece_cards)
	state.stockpile.changed.connect(_refresh_economy)
	state.army.changed.connect(_refresh_economy)
	state.diplomacy.changed.connect(_refresh_economy)
	state.board.resized.connect(func(_shift: Vector2i) -> void:
		board_view.queue_redraw()
		_focus_camera())
	state.turn_started.connect(_on_turn_started)
	_map_life = MapLifeView.new()
	board_view.add_child(_map_life)
	_map_life.setup(state)
	_apply_settings()

	build_panel.setup(_buildings, _resource_types)
	build_panel.build_window_requested.connect(_open_build_window)
	state.castle_changed.connect(_refresh_economy)
	state.generals.changed.connect(_refresh_economy)
	state.advisors.changed.connect(_refresh_economy)
	army_panel.setup(units, _resource_types)
	army_panel.recruit_window_requested.connect(_open_recruit_window)
	army_panel.disband_requested.connect(_on_disband_requested)
	tabs.tab_changed.connect(func(_tab: int) -> void: _clear_selection())
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	diplomacy_button.pressed.connect(_open_world_map)
	game_menu_button.pressed.connect(_open_game_menu)
	objectives_button.pressed.connect(_open_objectives)
	if game.is_empty():
		state.give_starting_resources()
		state.start()
		_autosave()
	else:
		state.resume()
		_continue_turn_start.call_deferred()
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
			if _info_cell != BoardView.OFF_BOARD and not _has_selection():
				_set_info_cell(BoardView.OFF_BOARD)
			else:
				_clear_selection()
		KEY_1, KEY_2, KEY_3:
			tabs.current_tab = 0
			_toggle_selection(event.keycode - KEY_1)
		KEY_ENTER, KEY_KP_ENTER:
			_on_end_turn_pressed()


## The cell info panel: the hovered cell, else the clicked one; collapsed to its first line when
## the player clicked the panel.
func _on_cell_hovered(coord: Vector2i) -> void:
	var shown := coord if coord != BoardView.OFF_BOARD else _info_cell
	var text := "Rê chuột lên một ô để xem thông tin.\nKéo chuột trái / phải: cuộn · Con lăn: zoom · G: tọa độ\nBấm khung này để thu gọn."
	if shown != BoardView.OFF_BOARD and state.board.is_in_bounds(shown):
		text = _describe_cell(state.board.get_cell(shown))
	cell_info_label.text = text.get_slice("\n", 0) + " ▸" if _info_collapsed else text
	_update_ghost()


## A click on the board (a press and release without dragging the map): places the selected
## piece, building or moved building there; otherwise a building opens its window and any other
## cell keeps its information in the cell info panel.
func _on_cell_clicked(coord: Vector2i) -> void:
	_hide_resource_popup()
	if _moving_from != NO_MOVE:
		_move_building_to(coord)
	elif _selected != NO_SELECTION:
		_place_selected_piece(coord)
	elif _selected_building != NO_BUILDING:
		_build_selected(coord)
	elif state.board.get_cell(coord).has_building():
		_open_building(state.board.get_cell(coord).building_origin)
	else:
		_set_info_cell(coord)


func _has_selection() -> bool:
	return _moving_from != NO_MOVE or _selected != NO_SELECTION or _selected_building != NO_BUILDING


func _set_info_cell(coord: Vector2i) -> void:
	_info_cell = coord
	board_view.selected_cell = coord
	_on_cell_hovered(board_view.get_hovered_cell())


## The small panel under the top bar with one resource's income breakdown.
func _build_resource_popup() -> void:
	_resource_popup = PanelContainer.new()
	_resource_popup.visible = false
	_resource_popup.position = Vector2(16, top_bar.get_combined_minimum_size().y + 6)
	_resource_popup.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_hide_resource_popup())
	$UI.add_child(_resource_popup)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	_resource_popup.add_child(margin)
	_resource_popup_text = Label.new()
	_resource_popup_text.add_theme_font_size_override("font_size", 14)
	margin.add_child(_resource_popup_text)


## Tapping a resource opens its breakdown; tapping it again (or the panel, or the map) closes it.
func _toggle_resource_popup(resource_id: StringName) -> void:
	if _resource_popup.visible and _resource_popup_id == resource_id:
		_hide_resource_popup()
		return
	_resource_popup_id = resource_id
	_resource_popup_text.text = _resource_labels[resource_id].tooltip_text
	_resource_popup.reset_size()
	_resource_popup.visible = true


func _hide_resource_popup() -> void:
	_resource_popup.visible = false
	_resource_popup_id = &""


## Tapping a building opens its window: information, upgrade, move, demolish.
func _open_building(origin: Vector2i) -> void:
	_clear_selection()
	var window := BuildingWindow.new()
	$UI.add_child(window)
	window.open(state, origin)
	window.move_requested.connect(func(from: Vector2i) -> void:
		_moving_from = from
		placement_status.text = "Chọn ô mới cho %s. Esc: hủy." % _moving_building().display_name)
	window.demolished.connect(func(what: String, refund: Dictionary) -> void:
		var amounts: Dictionary[StringName, int] = {}
		amounts.assign(refund)
		var back := UiFormat.amounts(amounts, _resource_types)
		placement_status.text = "%s.%s" % [what, " Hoàn lại %s." % back if not back.is_empty() else ""]
		_refresh_economy())
	window.construction_started.connect(func(text: String) -> void:
		placement_status.text = text
		_refresh_economy())


func _moving_building() -> BuildingData:
	return _buildings[state.board.get_cell(_moving_from).building_id]


func _move_building_to(coord: Vector2i) -> void:
	var building := _moving_building()
	var result := state.move_building(_moving_from, coord - _building_anchor(building))
	if result != BuildRules.Result.OK:
		placement_status.text = BuildRules.describe(result)
		return
	_moving_from = NO_MOVE
	board_view.hide_ghost()
	placement_status.text = "Đã di chuyển %s." % building.display_name
	_refresh_economy()


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
	_refresh_economy()
	placement_status.text = "Đã đặt nền móng %s, xây xong sau %d lượt." % [building.display_name, building.build_turns]
	_on_cell_hovered(coord)


## The build shop in the middle of the screen (GDD §8, M12d); choosing a building enters build mode.
func _open_build_window() -> void:
	_clear_selection()
	var window := BuildWindow.new()
	$UI.add_child(window)
	window.open(state)
	window.building_chosen.connect(func(building_id: StringName) -> void:
		tabs.current_tab = 1
		_toggle_building(building_id))


func _open_recruit_window() -> void:
	_clear_selection()
	var window := RecruitWindow.new()
	$UI.add_child(window)
	window.open(state)


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
	if report.forged != null:
		var forged: Item = report.forged
		lines.append("Xưởng rèn xong %s (%s)." % [forged.display_name, Item.RARITY_NAMES[forged.rarity]])
	for entry: Dictionary in report.completed:
		lines.append("%s đã %s." % [entry.name, "lên cấp %d" % entry.level if entry.upgrade else "xây xong"])
	for unit_id: StringName in report.deserted:
		lines.append("%d %s bỏ đi vì thiếu lương thực!" % [report.deserted[unit_id], state.units[unit_id].display_name])
	var replenished := _unit_amounts(report.replenished)
	if not replenished.is_empty():
		lines.append("Bổ sung quân: %s." % replenished)
	for entry: Dictionary in report.agreements:
		lines.append(_describe_agreement_turn(entry))
	if not report.buildings_supplied:
		lines.append("Không đủ phí duy trì công trình: công trình tạm ngưng tác dụng lượt này.")
	for entry: Dictionary in report.treaties:
		lines.append(_describe_treaty_event(entry))
	for clan_id: StringName in report.war_declared:
		lines.append("%s đã tuyên chiến với vương quốc!" % _clan_name(clan_id))
	for general: General in report.generals_healed:
		lines.append("Tướng %s đã lành vết thương." % general.name)
	for advisor: Advisor in report.advisors_healed:
		lines.append("Mưu sĩ %s đã lành vết thương." % advisor.name)
	if state.generals.candidates_turn == state.turn:
		lines.append("Có ứng viên mới (thành chính, tab Chiêu hiền).")
	var held: int = state.victory.holds[Victory.Path.PROSPERITY]
	if held > 0 and state.victory.won_path == Victory.NO_PATH:
		lines.append("Đang giữ điều kiện chiến thắng %s: %d/%d lượt." % [Victory.PATH_NAMES[Victory.Path.PROSPERITY],
				held, Victory.HOLD_TURNS])
	if report.castle_in_danger:
		lines.append("Thành chính nguy hiểm: chỉ còn %d ô đất ngoài thành!" % state.board.count_land_outside_castle())
	_pending_victory = report.victory
	if report.has("pending_invasion"):
		var invasion: Dictionary = report.pending_invasion
		lines.append("%s kéo quân xâm lược!" % _clan_name(invasion.clan_id))
		_play_invasion(invasion.clan_id, invasion.simulator)
	elif report.has("pending_raid"):
		lines.append("Quân cướp tấn công!")
		_play_raid(report.pending_raid)
	if not report.events.is_empty():
		lines.append("Có %d sự kiện mới." % report.events.size())
	placement_status.text = "\n".join(lines)
	# With a battle at the start of the turn, the autosave, the events and the end screen wait until it is over.
	if not report.has("pending_invasion") and not report.has("pending_raid"):
		_autosave()
		_continue_turn_start()


## "+5 Kiếm sĩ, +4 Cung thủ" from unit_id -> soldiers.
func _unit_amounts(counts: Dictionary) -> String:
	var parts: Array[String] = []
	for unit_id: StringName in counts:
		parts.append("+%d %s" % [counts[unit_id], state.units[unit_id].display_name])
	return ", ".join(parts)


## Plays a battle on the battle screen, then calls `on_finished` with its record.
func _play_battle(simulator: BattleSimulator, player_side: int, title: String, on_finished: Callable) -> void:
	_battle_screen = BattleScreen.new()
	$UI.add_child(_battle_screen)
	_battle_screen.start(simulator, player_side, title)
	_battle_screen.finished.connect(func(record: BattleRecord) -> void:
		_battle_screen = null
		on_finished.call(record))


## Shows the raid on the battle screen, then applies its outcome and opens the report.
func _play_raid(simulator: BattleSimulator) -> void:
	_play_battle(simulator, BattleRecord.DEFENDER, "Quân cướp tấn công vương quốc!", func(record: BattleRecord) -> void:
		var result := state.finish_raid(record)
		_autosave()
		placement_status.text += " %s" % ("Đã đánh lui." if result.won else "Thất thủ.")
		_show_battle_report(result, _ally_lines(result)))


func _play_invasion(clan_id: StringName, simulator: BattleSimulator) -> void:
	var title := "%s xâm lược vương quốc!" % _clan_name(clan_id)
	_play_battle(simulator, BattleRecord.DEFENDER, title, func(record: BattleRecord) -> void:
		var result := state.finish_invasion(clan_id, record)
		# A lost game is not autosaved: Continue goes back to the turn before.
		if not result.castle_fallen:
			_autosave()
		var report := BattleReport.new()
		$UI.add_child(report)
		var lines := report.army_loss_lines(result, state.units)
		lines.append("Quân %s mất %d lính." % [_clan_name(clan_id), result.enemy_lost])
		lines.append_array(_ally_lines(result))
		if not result.lost_cells.is_empty():
			lines.append("Mất %d ô đất %s." % [result.lost_cells.size(),
					ClanData.DIRECTION_NAMES[state.wars.fronts[clan_id].direction].to_lower()])
		var plundered := UiFormat.amounts(result.resources_lost, _resource_types)
		if not plundered.is_empty():
			lines.append("Bị cướp phá: %s." % plundered)
		var title_text := "Đẩy lui quân xâm lược!" if result.won else "Thất thủ trước quân xâm lược!"
		if result.castle_fallen:
			title_text = "Thành chính thất thủ!"
			lines.append("Không còn ô đất nào ngoài thành: quân %s chiếm thành chính." % _clan_name(clan_id))
		report.show_battle(title_text,
				result.won, "%s tấn công đầu lượt." % _clan_name(clan_id), record, BattleRecord.DEFENDER, lines)
		_battle_report = report
		report.closed.connect(_on_battle_report_closed)
		placement_status.text += " %s" % ("Đã đẩy lui." if result.won else "Thất thủ, mất đất."))


## The player attacks a clan (from the world map): whole army against theirs.
func _attack_clan(clan_id: StringName) -> void:
	var simulator := state.start_attack(clan_id)
	if simulator == null:
		return
	if _world_map != null:
		_world_map.close()
	var title := "Tấn công %s!" % _clan_name(clan_id)
	_play_battle(simulator, BattleRecord.ATTACKER, title, func(record: BattleRecord) -> void:
		var result := state.finish_attack(clan_id, record)
		_pending_victory = state.victory.check(state)
		var report := BattleReport.new()
		$UI.add_child(report)
		var lines := report.army_loss_lines(result, state.units)
		lines.append("Quân %s mất %d lính, còn %d." % [_clan_name(clan_id), result.enemy_lost,
				state.wars.fronts[clan_id].strength])
		lines.append_array(_ally_lines(result))
		var loot := UiFormat.amounts(result.loot, _resource_types)
		if not loot.is_empty():
			lines.append("Chiến lợi phẩm: %s." % loot)
		var compensation := UiFormat.amounts(result.compensation, _resource_types)
		if not compensation.is_empty():
			lines.append("Bồi thường chiến phí: %s." % compensation)
		if result.annexed:
			var direction := state.wars.fronts[clan_id].direction
			var line_name := "cột" if direction in [ClanData.Direction.EAST, ClanData.Direction.WEST] else "hàng"
			lines.append("%s đầu hàng và sáp nhập vào vương quốc! Bản đồ mở rộng thêm %d %s đất hoang %s." % [
					_clan_name(clan_id), Wars.ANNEX_EXPANSION, line_name,
					ClanData.DIRECTION_NAMES[direction].to_lower()])
		var title_text := "Chiến thắng!" if result.won else "Thất bại!"
		if result.annexed:
			title_text = "%s đã bị sáp nhập!" % _clan_name(clan_id)
		report.show_battle(title_text, result.won, "Vương quốc tấn công %s." % _clan_name(clan_id), record,
				BattleRecord.ATTACKER, lines)
		_battle_report = report
		report.closed.connect(_on_battle_report_closed))


## Report lines for the soldiers other clans lent to this battle (Alliances.apply_battle) and for
## the commander (Generals.after_battle).
func _ally_lines(result: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var general: Dictionary = result.get("general", {})
	var loot: Dictionary = result.get("item", {})
	if not loot.is_empty():
		var item: Item = loot.item
		var refund: Dictionary[StringName, int] = loot.refund
		lines.append("Chiến lợi phẩm: %s (%s)%s." % [item.display_name, Item.RARITY_NAMES[item.rarity],
				", kho đầy nên đã phân rã lấy %s" % UiFormat.amounts(refund, _resource_types) if not refund.is_empty()
				else " — xem ở tab Trang bị của tướng sĩ"])
	match general.get("fate", &"none"):
		&"dead":
			lines.append("Tổng tướng %s đã tử trận, mất luôn trang bị đang đeo!" % general.name)
		&"wounded":
			lines.append("Tổng tướng %s ngã ngựa, bị thương, nghỉ %d lượt." % [general.name, Generals.WOUND_TURNS])
	var advisor: Dictionary = result.get("advisor", {})
	if advisor.get("fate", &"none") == &"wounded":
		lines.append("Mưu sĩ %s bị thương khi rút chạy, nghỉ %d lượt." % [advisor.name, Advisors.WOUND_TURNS])
	for clan_id: StringName in result.allies:
		var entry: Dictionary = result.allies[clan_id]
		lines.append("Đồng minh %s gửi %d lính, mất %d (quan hệ %+d)." % [_clan_name(clan_id), entry.sent,
				entry.lost, entry.relation])
	for clan_id: StringName in result.helpers:
		var entry: Dictionary = result.helpers[clan_id]
		lines.append("%s gửi %d lính sang giúp đối phương, mất %d." % [_clan_name(clan_id), entry.sent, entry.lost])
	return lines


func _describe_treaty_event(entry: Dictionary) -> String:
	var clan_name := _clan_name(entry.clan_id)
	match entry.event:
		&"alliance_expired":
			return "Liên minh với %s đã hết hạn. Có thể ký lại trên bản đồ thế giới." % clan_name
		&"alliance_broken":
			return "%s rời bỏ liên minh vì quan hệ đi xuống." % clan_name
		_:
			return "Hiệp ước bất tương xâm với %s đã hết hạn." % clan_name


func _clan_name(clan_id: StringName) -> String:
	return state.diplomacy.clans[clan_id].data.display_name


## Fits the whole board in the free screen area (again after the board grows).
func _focus_camera() -> void:
	# Container sizes are only sorted next frame, so use the top bar's minimum height.
	camera.focus_on(board_view.get_board_rect(), side_panel.size.x, top_bar.get_combined_minimum_size().y)


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
	_world_map.attack_requested.connect(_attack_clan)


func _on_battle_report_closed() -> void:
	_battle_report = null
	_continue_turn_start()


## After the turn's battle: answer the pending events one by one (autosaving after each, so a
## reload cannot reroll an answer), then the end screen if the game was won or lost.
func _continue_turn_start() -> void:
	if state.events.current_event() == null:
		_show_end_game_if_any()
		return
	_clear_selection()
	var window := EventWindow.new()
	$UI.add_child(window)
	window.open(state, state.rng)
	window.closed.connect(func() -> void:
		_autosave()
		_continue_turn_start())


## Shows the defeat screen once the castle has fallen, or the victory screen for a path just won.
func _show_end_game_if_any() -> void:
	var path := _pending_victory
	_pending_victory = Victory.NO_PATH
	if not state.victory.lost and path == Victory.NO_PATH:
		return
	_clear_selection()
	var window := EndGameWindow.new()
	$UI.add_child(window)
	window.open(state, Victory.NO_PATH if state.victory.lost else path, _save_system, $UI)


func _open_objectives() -> void:
	_clear_selection()
	var window := ObjectivesWindow.new()
	$UI.add_child(window)
	window.open(state)


## Saves into the autosave slot (start of a game and of every turn).
func _autosave() -> void:
	if not autosave:
		return
	var error := _save_system.save(state, SaveSystem.AUTO_SLOT)
	if error != OK:
		placement_status.text += "\nKhông tự lưu được (lỗi %s)." % error_string(error)


func _open_game_menu() -> void:
	_clear_selection()
	var menu := GameMenuWindow.new()
	$UI.add_child(menu)
	menu.open(state, _save_system, $UI)
	menu.settings_changed.connect(_apply_settings)


## Map effects on or off (GameSettings, M13c): building animations and the walkers.
func _apply_settings() -> void:
	board_view.animate = GameSettings.map_effects()
	_map_life.visible = GameSettings.map_effects()


func _show_battle_report(raid: Dictionary, extra_lines: Array[String] = []) -> void:
	_battle_report = BattleReport.new()
	$UI.add_child(_battle_report)
	_battle_report.show_raid(raid, _resource_types, state.units, extra_lines)
	_battle_report.closed.connect(_on_battle_report_closed)


func _on_turn_started(turn: int) -> void:
	turn_label.text = "Lượt %d" % turn
	# Each turn starts on the new land pieces, so they are never forgotten.
	tabs.current_tab = 0
	_refresh_economy()


func _clear_selection() -> void:
	if _moving_from != NO_MOVE:
		_moving_from = NO_MOVE
		placement_status.text = "Đã hủy di chuyển."
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
	for i in piece_list.get_child_count():
		(piece_list.get_child(i) as PieceCard).set_pressed_no_signal(i == _selected)
	placement_status.text = "" if _selected == NO_SELECTION else "Bấm lên bản đồ để đặt. Esc: bỏ chọn."
	_update_ghost()


## Selecting the already-selected building (or NO_BUILDING) leaves build mode.
func _toggle_building(building_id: StringName) -> void:
	_selected_building = NO_BUILDING if building_id == _selected_building else building_id
	if _selected_building != NO_BUILDING and _selected != NO_SELECTION:
		_select(NO_SELECTION)
	placement_status.text = "" if _selected_building == NO_BUILDING \
			else "Bấm lên bản đồ để xây. Esc: bỏ chọn."
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


## The ghost under the pointer, and what placing it there would do.
func _update_ghost() -> void:
	var coord := board_view.get_hovered_cell()
	if coord == BoardView.OFF_BOARD or not _has_selection():
		board_view.hide_ghost()
		return
	if _has_selection() and _info_cell != BoardView.OFF_BOARD:
		_set_info_cell(BoardView.OFF_BOARD)
	if _moving_from != NO_MOVE:
		var moving := _moving_building()
		var target := coord - _building_anchor(moving)
		var check := BuildRules.check_move(state.board, moving, _moving_from, target)
		board_view.show_building_ghost(moving, target, check == BuildRules.Result.OK)
		placement_status.text = "Di chuyển %s: %s Esc: hủy." % [moving.display_name,
				"bấm để đặt ở đây." if check == BuildRules.Result.OK else BuildRules.describe(check)]
		return
	if _selected_building != NO_BUILDING:
		var building := _buildings[_selected_building]
		var origin := coord - _building_anchor(building)
		var result := BuildRules.check(state.board, state.stockpile, building, origin, state.castle_level,
				state.building_cost(building), state.has_free_builder())
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
	# Economy v2: land yields nothing by itself, so the delta is usually empty.
	if delta.is_empty():
		placement_status.text = "Có thể đặt. Đất không tự cho tài nguyên: xây công trình khai thác lên đất để có sản lượng."
	else:
		placement_status.text = "Có thể đặt. Sản lượng mỗi lượt: %s." % delta


## The cell of a building that sits under the mouse cursor.
func _building_anchor(building: BuildingData) -> Vector2i:
	return (building.size - Vector2i.ONE) / 2


## Tab buttons of equal width above the tab pages (GDD §8, M12d), drawn like the theme's tabs.
func _build_tab_buttons() -> void:
	tabs.tabs_visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var parent := tabs.get_parent()
	parent.add_child(row)
	parent.move_child(row, tabs.get_index())
	var group := ButtonGroup.new()
	var buttons: Array[Button] = []
	for i in TAB_TITLES.size():
		var button := Button.new()
		button.text = TAB_TITLES[i]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		# The wooden buttons' text outline smudges the dark ink of the selected (paper) tab.
		button.add_theme_constant_override("outline_size", 0)
		var selected := tabs.get_theme_stylebox("tab_selected")
		var unselected := tabs.get_theme_stylebox("tab_unselected")
		for style in ["normal", "hover", "disabled"]:
			button.add_theme_stylebox_override(style, unselected)
		button.add_theme_stylebox_override("pressed", selected)
		button.add_theme_stylebox_override("hover_pressed", selected)
		button.add_theme_color_override("font_color", tabs.get_theme_color("font_unselected_color"))
		button.add_theme_color_override("font_hover_color", tabs.get_theme_color("font_hovered_color"))
		button.add_theme_color_override("font_pressed_color", tabs.get_theme_color("font_selected_color"))
		button.add_theme_color_override("font_hover_pressed_color", tabs.get_theme_color("font_selected_color"))
		button.pressed.connect(func() -> void: tabs.current_tab = i)
		row.add_child(button)
		buttons.append(button)
	var sync := func(tab: int) -> void:
		for i in buttons.size():
			buttons[i].set_pressed_no_signal(i == tab)
	tabs.tab_changed.connect(sync)
	sync.call(tabs.current_tab)


## The "Tướng sĩ" tab (GDD §13, M12c): built in code after the scene's three tabs.
func _build_officers_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "OfficersTab"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	officers_panel = OfficersPanel.new()
	officers_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	officers_panel.add_theme_constant_override("separation", 6)
	officers_panel.officer_selected.connect(_open_officer)
	scroll.add_child(officers_panel)


func _open_officer(officer: Officer) -> void:
	var window := OfficerWindow.new()
	$UI.add_child(window)
	window.open(state, officer)


## One icon + amount per resource on the wooden top bar; the name is in the tooltip.
func _build_resource_labels() -> void:
	for type in _resource_types:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		resource_bar.add_child(row)
		var icon := TextureRect.new()
		icon.texture = GameArt.icon(type.resource_id)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var label := Label.new()
		label.theme_type_variation = &"WoodLabel"
		# Hovering shows where the per-turn change comes from (tooltip filled in _refresh_economy);
		# clicking opens the same text in a panel that stays open.
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var resource_id := type.resource_id
		row.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_toggle_resource_popup(resource_id))
		row.add_child(label)
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
		label.text = "%d (%+d)" % [amount, change]
		var lines: Array[String] = ["%s: %d (%+d mỗi lượt)" % [type.display_name, amount, change]]
		for entry: Dictionary in breakdown.get(type.resource_id, []):
			lines.append("  %+d  %s" % [entry.amount, _income_source_text(entry)])
		if lines.size() == 1:
			lines.append("  Chưa có nguồn thu hay chi nào.")
		label.tooltip_text = "\n".join(lines)
		if _resource_popup_id == type.resource_id:
			_resource_popup_text.text = label.tooltip_text
	army_panel.refresh(state)
	build_panel.refresh(state)
	officers_panel.refresh(state)
	board_view.castle_level = state.castle_level
	board_view.castle_turns = state.castle_turns


func _income_source_text(entry: Dictionary) -> String:
	match entry.source:
		&"terrain":
			var terrain := _terrains[entry.id].display_name
			var keys := ", %d ô ◆" % entry.key_count if entry.key_count > 0 else ""
			return "%s (%d ô%s)" % [terrain, entry.count, keys]
		&"army":
			return "Nuôi quân (%d đơn vị)" % entry.count
		&"generals":
			return "Nuôi tướng (%d)" % entry.count
		&"advisors":
			return "Nuôi mưu sĩ (%d)" % entry.count
		&"admin_upkeep":
			return "Mưu sĩ Nội chính (giảm phí nuôi)"
		&"admin_yield":
			return "Mưu sĩ Nội chính (thêm sản lượng)"
		&"production":
			return "%s ×%d (khai thác)" % [_buildings[entry.id].display_name, entry.count]
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
		var cell_amounts := Economy.cell_yield(_terrains.get(cell.terrain_id), cell.is_key)
		# A production building counts once, on its origin cell.
		if cell.has_building() and cell.coord == cell.building_origin and _buildings.has(cell.building_id):
			Economy.add_into(cell_amounts, Economy.building_yield(_buildings[cell.building_id], cell.is_key, cell.building_level))
		var amounts := UiFormat.amounts(cell_amounts, _resource_types, true)
		production = amounts if not amounts.is_empty() else "Không"
	var building := "Không"
	if cell.building_id == BoardData.CASTLE_ID:
		building = "Thành chính" + (" (đang nâng cấp, còn %d lượt)" % state.castle_turns if state.castle_turns > 0 else "")
	elif cell.has_building():
		var data: BuildingData = _buildings.get(cell.building_id)
		building = data.display_name if data != null else String(cell.building_id)
		if cell.is_constructing():
			building += " (%s, còn %d lượt)" % ["đang nâng cấp" if cell.building_upgrading else "đang xây", cell.building_turns]
	return "Ô (%d, %d)\nĐịa hình: %s\nSở hữu: %s\nSản lượng mỗi lượt: %s\nCông trình: %s" % [
		cell.coord.x, cell.coord.y, terrain, "Có" if cell.owned else "Không", production, building]
