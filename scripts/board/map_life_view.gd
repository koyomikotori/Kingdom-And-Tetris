class_name MapLifeView
extends Node2D
## Draws MapLife's walkers over the board (GDD §13, M13c), as a child of the BoardView: tiny
## villagers with what they carry, ox carts, patrols in the player's color, horses, deer and birds.
## Hidden when the map effects setting is off. Follows the board and the army by itself. Also the
## quiet map ambience (M14a): birds now and then, hammering while something is being built.

## Soldiers of a patrol walk this far apart (pixels), one behind the other.
const PATROL_SPACING := 9.0
## Walkers stand this far below the cell edge they follow, so their feet are on it.
const FOOT_OFFSET := 3.0
## Walking frames per second.
const STEP_FPS := 6.0
## Birds fly this high above the ground they cross.
const BIRD_HEIGHT := 18.0
const SPRITES: Dictionary[MapLife.Kind, StringName] = {MapLife.Kind.CART: &"cart", MapLife.Kind.SOLDIER: &"soldier",
		MapLife.Kind.HORSE: &"horse", MapLife.Kind.DEER: &"deer", MapLife.Kind.BIRD: &"bird"}

## Seconds between bird calls, and between hammer blows while a building is under construction.
const BIRD_CALL_INTERVAL := Vector2(6.0, 14.0)
const HAMMER_INTERVAL := Vector2(2.5, 5.0)
const AMBIENT_DB := -14.0

var life := MapLife.new(7)
## Off while a battle is on screen (set by the kingdom scene).
var ambient := true
var _bird_call := 3.0
var _hammer := 1.0
var _state: KingdomState
var _dirty := true


func setup(state: KingdomState) -> void:
	_state = state
	state.board.cell_changed.connect(func(_coord: Vector2i) -> void: _dirty = true)
	state.board.resized.connect(func(_shift: Vector2i) -> void: _dirty = true)
	state.army.changed.connect(func() -> void: _dirty = true)


func _process(delta: float) -> void:
	if _state == null or not visible:
		return
	if _dirty:
		_dirty = false
		life.sync(_state.board, _state.army.count_squads())
	life.update(delta)
	queue_redraw()
	if ambient:
		_play_ambience(delta)


func _play_ambience(delta: float) -> void:
	_bird_call -= delta
	if _bird_call <= 0.0:
		_bird_call = randf_range(BIRD_CALL_INTERVAL.x, BIRD_CALL_INTERVAL.y)
		Sfx.play(&"bird_1" if randf() < 0.5 else &"bird_2", AMBIENT_DB, 0.1)
	_hammer -= delta
	if _hammer <= 0.0:
		_hammer = randf_range(HAMMER_INTERVAL.x, HAMMER_INTERVAL.y)
		if not _state.board.get_construction_origins().is_empty() or _state.castle_turns > 0:
			Sfx.play(&"hammer", AMBIENT_DB + 2.0, 0.1)


func _draw() -> void:
	var order := life.walkers.duplicate()
	order.sort_custom(func(a: MapLife.Walker, b: MapLife.Walker) -> bool: return a.pos.y < b.pos.y)
	for walker: MapLife.Walker in order:
		var feet := walker.pos * BoardView.TILE_SIZE + Vector2(0, FOOT_OFFSET)
		var frame := int(walker.age * STEP_FPS) % 2 if walker.is_moving() or walker.kind == MapLife.Kind.BIRD else 0
		match walker.kind:
			MapLife.Kind.VILLAGER:
				var top := _sprite(&"villager_a" if walker.variant == 0 else &"villager_b", feet, frame, walker.facing)
				if walker.carry != &"":
					_sprite(StringName("carry_" + String(walker.carry)), top + Vector2(0, 3), 0, 1.0, false)
			MapLife.Kind.SOLDIER:
				var back := Vector2(-walker.facing, 0) * PATROL_SPACING
				if walker.is_moving() and not walker.path.is_empty():
					back = (walker.pos - walker.path[0]).normalized() * PATROL_SPACING
				for i in range(walker.count - 1, -1, -1):
					_sprite(&"soldier", feet + back * i, frame, walker.facing, true, _state.player_color)
			MapLife.Kind.BIRD:
				_sprite(&"bird", feet - Vector2(0, BIRD_HEIGHT), frame, walker.facing)
			_:
				_sprite(SPRITES[walker.kind], feet, frame, walker.facing)


## Draws frame `frame` of a 2-frame strip ×2 with its bottom middle at `feet` (or its middle when
## not `anchored_at_feet`), mirrored when `facing` < 0, the "_team" layer tinted with `team`.
## Returns the top middle of the drawn sprite.
func _sprite(sprite_id: StringName, feet: Vector2, frame: int, facing: float, anchored_at_feet: bool = true,
		team: Color = Color.TRANSPARENT) -> Vector2:
	var strip := GameArt.map_sprite(sprite_id)
	if strip == null:
		return feet
	var frames := 2 if strip.get_width() > strip.get_height() + 2 else 1
	var size := Vector2(strip.get_width() / float(frames), strip.get_height())
	var region := Rect2(Vector2(size.x * (frame % frames), 0), size)
	var scale := GameArt.ART_SCALE
	var top_left := Vector2(-size.x * 0.5, -size.y if anchored_at_feet else -size.y * 0.5)
	draw_set_transform(feet, 0.0, Vector2(scale * signf(facing if facing != 0.0 else 1.0), scale))
	draw_texture_rect_region(strip, Rect2(top_left, size), region)
	if team.a > 0.0:
		var team_strip := GameArt.map_sprite(sprite_id, "_team")
		if team_strip != null:
			draw_texture_rect_region(team_strip, Rect2(top_left, size), region, team)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return feet + Vector2(0, top_left.y * scale)
