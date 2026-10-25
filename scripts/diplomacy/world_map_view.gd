class_name WorldMapView
extends Control
## Draws the world map (GDD §9.1): the kingdom in the middle, clans as points joined by roads,
## each ringed in the color of its relation tier. Tapping or clicking a clan selects it.
## Placeholder drawing until pixel art (M13). Read-only.

signal clan_selected(clan_id: StringName)

const KINGDOM_ID: StringName = &"kingdom"
const KINGDOM_POSITION := Vector2(0.5, 0.5)
const NODE_RADIUS := 26.0
const BACKGROUND_COLOR := Color(0.23, 0.27, 0.2)
const ROAD_COLOR := Color(0.75, 0.65, 0.45, 0.6)
const KINGDOM_COLOR := Color(1.0, 0.85, 0.35)
const SELECTED_COLOR := Color(1, 1, 1)
## HOSTILE, TENSE, NEUTRAL, FRIENDLY, CLOSE
const TIER_COLORS: Array[Color] = [Color(0.9, 0.2, 0.2), Color(0.95, 0.55, 0.25), Color(0.75, 0.75, 0.75),
		Color(0.45, 0.85, 0.45), Color(0.3, 1.0, 0.6)]
const LABEL_FONT_SIZE := 14

var _diplomacy: Diplomacy
var _selected: StringName = &""


func setup(diplomacy: Diplomacy) -> void:
	_diplomacy = diplomacy
	_diplomacy.changed.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_STOP


func select(clan_id: StringName) -> void:
	_selected = clan_id
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	for clan_id in _diplomacy.clans:
		if event.position.distance_to(_point(_diplomacy.clans[clan_id].data.map_position)) <= NODE_RADIUS + 8:
			select(clan_id)
			clan_selected.emit(clan_id)
			accept_event()
			return


func _point(normalized: Vector2) -> Vector2:
	return normalized * size


func _position_of(id: StringName) -> Vector2:
	if id == KINGDOM_ID:
		return _point(KINGDOM_POSITION)
	return _point(_diplomacy.clans[id].data.map_position)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	if _diplomacy == null:
		return
	for clan_id in _diplomacy.clans:
		for other in _diplomacy.clans[clan_id].data.roads:
			# Draw each road once: from the kingdom, or from the clan with the smaller id.
			if other == KINGDOM_ID or String(clan_id) < String(other):
				_draw_road(_position_of(clan_id), _position_of(other))
	_draw_node(_point(KINGDOM_POSITION), KINGDOM_COLOR, KINGDOM_COLOR, "Vương quốc của bạn", false)
	for clan_id in _diplomacy.clans:
		var clan := _diplomacy.clans[clan_id]
		var ring := TIER_COLORS[Diplomacy.tier_for(clan.relation)]
		var label := clan.data.display_name + ("" if clan.data.is_neighbor() else " (xa)")
		_draw_node(_point(clan.data.map_position), clan.data.color, ring, label, clan_id == _selected)


func _draw_road(from: Vector2, to: Vector2) -> void:
	var direction := (to - from).normalized()
	draw_dashed_line(from + direction * NODE_RADIUS, to - direction * NODE_RADIUS, ROAD_COLOR, 3.0, 10.0)


func _draw_node(center: Vector2, fill: Color, ring: Color, label: String, selected: bool) -> void:
	if selected:
		draw_circle(center, NODE_RADIUS + 8, SELECTED_COLOR, false, 2.0)
	draw_circle(center, NODE_RADIUS, fill)
	draw_circle(center, NODE_RADIUS, ring, false, 4.0)
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x
	var text_pos := center + Vector2(-width * 0.5, NODE_RADIUS + 20)
	draw_string_outline(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, 4, Color(0, 0, 0, 0.8))
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, Color.WHITE)
