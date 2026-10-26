class_name WorldMapView
extends Control
## Draws the world map (GDD §9.1) as an old map on paper (GDD §13, M12c): the kingdom in the
## middle, each clan a fort flying its banner color on a patch tinted by the relation tier, dirt
## roads between them, mountains, woods and a river around, pixel icons for war, alliance and
## pact. Tapping or clicking a clan selects it. Read-only.

signal clan_selected(clan_id: StringName)

const KINGDOM_ID: StringName = &"kingdom"
const KINGDOM_POSITION := Vector2(0.5, 0.5)
const NODE_RADIUS := 26.0
const BACKGROUND_COLOR := Color(0.91, 0.84, 0.66)
const ROAD_COLOR := Color(0.47, 0.32, 0.18, 0.75)
const KINGDOM_COLOR := Color(1.0, 0.85, 0.35)
const SELECTED_COLOR := Color(0.85, 0.6, 0.12)
const LABEL_OUTLINE := Color(0.96, 0.92, 0.8, 0.9)
const RIVER_COLOR := Color(0.45, 0.66, 0.8)
const RIVER_EDGE_COLOR := Color(0.29, 0.2, 0.13, 0.6)
## Normalized points of the river across the map.
const RIVER: Array[Vector2] = [Vector2(0.0, 0.18), Vector2(0.12, 0.22), Vector2(0.22, 0.34), Vector2(0.3, 0.38),
		Vector2(0.36, 0.62), Vector2(0.28, 0.78), Vector2(0.34, 1.0)]
## Map art is drawn ×2.
const ART_SCALE := 2.0
const EDGE_BANDS := 6
const EDGE_BAND_WIDTH := 10.0
const EDGE_COLOR := Color(0.45, 0.3, 0.15, 0.22)
const DECORATION_SEED := 7
const DECORATION_TRIES := 60
## Decorations keep this far (pixels) from clans and roads.
const NODE_CLEARANCE := 80.0
const ROAD_CLEARANCE := 30.0
## HOSTILE, TENSE, NEUTRAL, FRIENDLY, CLOSE
const TIER_COLORS: Array[Color] = [Color(0.9, 0.2, 0.2), Color(0.95, 0.55, 0.25), Color(0.75, 0.75, 0.75),
		Color(0.45, 0.85, 0.45), Color(0.3, 1.0, 0.6)]
const LABEL_FONT_SIZE := 14

var _diplomacy: Diplomacy
var _wars: Wars
var _selected: StringName = &""
## [piece, position] placed for the current size (_place_decorations).
var _decorations: Array = []
var _decor_size := Vector2.ZERO


func setup(diplomacy: Diplomacy) -> void:
	_diplomacy = diplomacy
	_diplomacy.changed.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The parchment is a tiled texture.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


## Shows war markers, annexed clans and clans that became neighbours.
func setup_wars(wars: Wars) -> void:
	_wars = wars
	_wars.changed.connect(queue_redraw)
	queue_redraw()


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
	_draw_parchment()
	if _diplomacy == null:
		return
	_draw_decorations()
	for clan_id in _diplomacy.clans:
		for other in _diplomacy.clans[clan_id].data.roads:
			# Draw each road once: from the kingdom, or from the clan with the smaller id.
			if other == KINGDOM_ID or String(clan_id) < String(other):
				_draw_road(_position_of(clan_id), _position_of(other))
	_draw_node(_point(KINGDOM_POSITION), KingdomState.PLAYER_COLOR, KINGDOM_COLOR, "Vương quốc của bạn", false)
	for clan_id in _diplomacy.clans:
		var clan := _diplomacy.clans[clan_id]
		var center := _point(clan.data.map_position)
		var front: Wars.Front = _wars.fronts[clan_id] if _wars != null else null
		if front != null and front.annexed:
			_draw_node(center, KingdomState.PLAYER_COLOR, KINGDOM_COLOR, clan.data.display_name + " (đã sáp nhập)",
					clan_id == _selected)
			continue
		var tier_color := TIER_COLORS[Diplomacy.tier_for(clan.relation)]
		var neighbor := front.is_neighbor() if front != null else clan.data.is_neighbor()
		var label := clan.data.display_name + ("" if neighbor else " (xa)")
		if clan.is_allied():
			label += " · đồng minh"
		_draw_node(center, clan.data.color, tier_color, label, clan_id == _selected)
		var corner := Vector2(NODE_RADIUS + 4, -NODE_RADIUS - 4)
		if front != null and front.at_war:
			_draw_icon(&"icon_war", center + corner)
		if clan.is_allied():
			_draw_icon(&"icon_alliance", center + Vector2(-corner.x, corner.y))
		elif clan.has_pact():
			_draw_icon(&"icon_pact", center + Vector2(-corner.x, corner.y))


## Tiled paper, darker toward the edges like an old map.
func _draw_parchment() -> void:
	var paper := GameArt.world(&"parchment")
	if paper == null:
		draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ART_SCALE)
	draw_texture_rect(paper, Rect2(Vector2.ZERO, size / ART_SCALE + Vector2.ONE), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in EDGE_BANDS:
		var inset := i * EDGE_BAND_WIDTH
		var shade := Color(EDGE_COLOR, EDGE_COLOR.a * (1.0 - float(i) / EDGE_BANDS))
		var rect := Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2.0)
		draw_rect(rect, shade, false, EDGE_BAND_WIDTH)


## Mountains, woods and a river scattered where they do not cover a clan or a road.
func _draw_decorations() -> void:
	if _decor_size != size:
		_place_decorations()
	var river := PackedVector2Array()
	for point in RIVER:
		river.append(_point(point))
	draw_polyline(river, RIVER_EDGE_COLOR, 10.0)
	draw_polyline(river, RIVER_COLOR, 6.0)
	for item: Array in _decorations:
		var texture := GameArt.world(item[0])
		if texture != null:
			var draw_size := texture.get_size() * ART_SCALE
			draw_texture_rect(texture, Rect2(item[1] - draw_size * 0.5, draw_size), false)


func _place_decorations() -> void:
	_decor_size = size
	_decorations.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = DECORATION_SEED
	var nodes: Array[Vector2] = [_point(KINGDOM_POSITION)]
	var roads: Array = []
	for clan_id in _diplomacy.clans:
		nodes.append(_position_of(clan_id))
		for other in _diplomacy.clans[clan_id].data.roads:
			roads.append([_position_of(clan_id), _position_of(other)])
	for i in DECORATION_TRIES:
		var at := Vector2(rng.randf_range(0.05, 0.95), rng.randf_range(0.06, 0.94)) * size
		var clear := nodes.all(func(n: Vector2) -> bool: return n.distance_to(at) > NODE_CLEARANCE)
		for road: Array in roads:
			if Geometry2D.get_closest_point_to_segment(at, road[0], road[1]).distance_to(at) < ROAD_CLEARANCE:
				clear = false
		if clear:
			_decorations.append([&"mountain" if rng.randf() < 0.45 else &"trees", at])


func _draw_icon(icon: StringName, center: Vector2) -> void:
	var texture := GameArt.world(icon)
	if texture != null:
		var draw_size := texture.get_size() * ART_SCALE
		draw_texture_rect(texture, Rect2(center - draw_size * 0.5, draw_size), false)


func _draw_road(from: Vector2, to: Vector2) -> void:
	var direction := (to - from).normalized()
	draw_dashed_line(from + direction * NODE_RADIUS, to - direction * NODE_RADIUS, ROAD_COLOR, 4.0, 12.0)


## A fort with its banner in `banner` color, standing on a patch tinted by the relation tier.
func _draw_node(center: Vector2, banner: Color, tier: Color, label: String, selected: bool) -> void:
	var ground := Rect2(center + Vector2(-NODE_RADIUS - 6, NODE_RADIUS * 0.2), Vector2(NODE_RADIUS * 2 + 12, 18))
	draw_set_transform(ground.get_center(), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, NODE_RADIUS + 8, Color(tier, 0.55))
	if selected:
		draw_circle(Vector2.ZERO, NODE_RADIUS + 14, SELECTED_COLOR, false, 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var fort := GameArt.world(&"fort")
	if fort != null:
		var draw_size := fort.get_size() * ART_SCALE
		var rect := Rect2(center - Vector2(draw_size.x * 0.5, draw_size.y * 0.7), draw_size)
		draw_texture_rect(fort, rect, false)
		var team := GameArt.world(&"fort_team")
		if team != null:
			draw_texture_rect(team, rect, false, banner)
	else:
		draw_circle(center, NODE_RADIUS, banner)
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x
	var text_pos := center + Vector2(-width * 0.5, NODE_RADIUS + 26)
	draw_string_outline(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, 5, LABEL_OUTLINE)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, UiPalette.TEXT)
