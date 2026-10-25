class_name BattleView
extends Control
## Draws a battle as it happens (GDD §7.5): back-row units in the side zones, melee units in the
## middle field, the charge at contact, gun and arrow volleys, figures knocked away as soldiers
## fall and broken units fleeing. Placeholder shapes until pixel art (M13).
## Read-only: it looks at the BattleSide units the simulator updates and never changes them.

const SOLDIERS_PER_FIGURE := 4
## Width share of each side zone (18% of the screen out of the 80% this control covers).
const SIDE_ZONE_SHARE := 18.0 / 80.0
## Stick figures are drawn at this scale; spacing is in already-scaled pixels.
const FIGURE_SCALE := 1.8
const FIGURE_SPACING := Vector2(20, 30)
const FIGURES_PER_ROW := 5
## Pixels per battle-second when units walk or charge.
const MOVE_SPEED := 200.0
## Melee units start running this many battle-seconds before contact.
const CHARGE_LEAD := 1.2
## Distance between the clash line and each unit's front figure.
const CLASH_GAP := 14.0
## How far each further rank stands behind the one in front.
const RANK_GAP := 110.0
const GRAVITY := 900.0
## Screen-left side, screen-right side.
const SIDE_COLORS: Array[Color] = [Color(0.4, 0.6, 1.0), Color(0.95, 0.4, 0.35)]
const SKY_COLOR := Color(0.16, 0.2, 0.3)
const GROUND_COLOR := Color(0.26, 0.33, 0.2)
const ZONE_LINE_COLOR := Color(1, 1, 1, 0.08)
const BULLET_COLOR := Color(1.0, 0.9, 0.5)
const ARROW_COLOR := Color(0.85, 0.75, 0.55)


class Figure:
	extends RefCounted
	enum State { STAND, FLY, FLEE, GONE }
	var offset: Vector2
	var state := State.STAND
	## Absolute position while flying or fleeing.
	var pos: Vector2
	var velocity: Vector2
	var rotation := 0.0
	var spin := 0.0
	var phase: float


class UnitView:
	extends RefCounted
	var unit: BattleSide.Unit
	var battle_side: int
	## 0 = drawn on the left, 1 = on the right.
	var screen_side: int
	var lane_y := 0.0
	var pos := Vector2.ZERO
	var figures: Array[Figure] = []


class Projectile:
	extends RefCounted
	var kind: StringName  # &"bullet", &"arrow"
	var from: Vector2
	var to: Vector2
	## Battle-seconds before it appears, then how long it flies.
	var delay := 0.0
	var duration := 0.3
	var age := 0.0


var _simulator: BattleSimulator
var _left_side := BattleRecord.DEFENDER
var _views: Array = [[], []]  # per battle side: Array[UnitView]
var _projectiles: Array[Projectile] = []
var _clock := 0.0
var _rng := RandomNumberGenerator.new()
## Lanes depend on this control's size, which is only known once it is laid out.
var _laid_out := false


## `left_side` is the battle side (BattleRecord.ATTACKER / DEFENDER) drawn on the left.
func setup(simulator: BattleSimulator, left_side: int) -> void:
	_simulator = simulator
	_left_side = left_side
	_rng.seed = 1
	for s in 2:
		var side := simulator.record.sides[s]
		for unit in side.units:
			var view := UnitView.new()
			view.unit = unit
			view.battle_side = s
			view.screen_side = 0 if s == left_side else 1
			for k in ceili(float(unit.start_soldiers) / SOLDIERS_PER_FIGURE):
				var figure := Figure.new()
				figure.offset = _figure_offset(k, view.screen_side)
				figure.phase = _rng.randf() * TAU
				view.figures.append(figure)
			_views[s].append(view)
	resized.connect(_layout)


## Advances animations by `battle_delta` battle-seconds (0 while paused) and spawns effects for
## the simulator events that just happened.
func update_view(battle_delta: float, new_events: Array[Dictionary]) -> void:
	if not _laid_out:
		_layout()
	_clock += battle_delta
	for event in new_events:
		_spawn_effects(event)
	for s in 2:
		for view: UnitView in _views[s]:
			_move_unit(view, battle_delta)
			_update_figures(view, battle_delta)
	for projectile in _projectiles:
		projectile.age += battle_delta
	_projectiles = _projectiles.filter(func(p: Projectile) -> bool: return p.age < p.delay + p.duration)
	queue_redraw()


## After a skip: jump every unit to its final place and drop pending effects.
func snap_to_end() -> void:
	_projectiles.clear()
	for s in 2:
		for view: UnitView in _views[s]:
			view.pos.x = _target_x(view)
			var keep := _figures_wanted(view)
			for figure in view.figures:
				if figure.state == Figure.State.STAND and keep > 0:
					keep -= 1
				elif figure.state == Figure.State.STAND:
					figure.state = Figure.State.GONE
			if view.unit.broken:
				for figure in view.figures:
					if figure.state == Figure.State.STAND:
						figure.state = Figure.State.GONE
	queue_redraw()


# --- Layout -------------------------------------------------------------------------------

func _zone_width() -> float:
	return size.x * SIDE_ZONE_SHARE


func _ground_top() -> float:
	return size.y * 0.32


func _is_in_side_zone(unit: BattleSide.Unit) -> bool:
	return unit.data.row == UnitData.Row.BACK


## Places every unit at its lane and current target. Runs again when the control is resized.
func _layout() -> void:
	if size.x <= 0.0:
		return
	_laid_out = true
	_assign_lanes()
	for s in 2:
		for view: UnitView in _views[s]:
			view.pos = Vector2(_target_x(view), view.lane_y)


## Spreads each group (side zone / each field row) evenly over the ground band.
func _assign_lanes() -> void:
	var top := _ground_top() + 50.0
	var bottom := size.y - 30.0
	for s in 2:
		var groups := {}
		for view: UnitView in _views[s]:
			var key := -1 if _is_in_side_zone(view.unit) else int(view.unit.data.row)
			if not groups.has(key):
				groups[key] = []
			groups[key].append(view)
		for key in groups:
			var members: Array = groups[key]
			for i in members.size():
				members[i].lane_y = top + (i + 0.5) * (bottom - top) / members.size()


func _home_x(view: UnitView) -> float:
	var zone := _zone_width()
	var x: float
	if _is_in_side_zone(view.unit):
		x = zone * 0.5 + FIGURE_SPACING.x * (FIGURES_PER_ROW - 1) * 0.5
	else:
		x = zone + (FIGURES_PER_ROW * FIGURE_SPACING.x + (90.0 if view.unit.data.row == UnitData.Row.FRONT else 0.0))
	return x if view.screen_side == 0 else size.x - x


## Where the unit wants to stand right now: home before the charge, the clash line once melee
## starts (units behind the front line queue up behind it).
func _target_x(view: UnitView) -> float:
	if _simulator.time < BattleSimulator.CONTACT_TIME - CHARGE_LEAD:
		return _home_x(view)
	var side := _simulator.record.sides[view.battle_side]
	var rank := maxi(0, int(view.unit.data.row) - maxi(0, side.front_row()))
	if view.unit.data.is_ranged() and rank > 0:
		return _home_x(view)
	var offset := CLASH_GAP + rank * RANK_GAP
	return size.x * 0.5 - offset if view.screen_side == 0 else size.x * 0.5 + offset


## Left side faces right (+1), right side faces left (-1).
func _facing(screen_side: int) -> float:
	return 1.0 if screen_side == 0 else -1.0


## The unit's position is its front figure; the rest of the block stands behind it.
func _figure_offset(index: int, screen_side: int) -> Vector2:
	var column := index % FIGURES_PER_ROW
	var row := index / FIGURES_PER_ROW
	var back := -(column * FIGURE_SPACING.x + (row % 2) * FIGURE_SPACING.x * 0.5)
	return Vector2(back * _facing(screen_side), (row - 0.5) * FIGURE_SPACING.y)


# --- Animation ----------------------------------------------------------------------------

func _move_unit(view: UnitView, delta: float) -> void:
	view.pos.x = move_toward(view.pos.x, _target_x(view), MOVE_SPEED * delta)


func _figures_wanted(view: UnitView) -> int:
	return ceili(float(view.unit.alive()) / SOLDIERS_PER_FIGURE)


func _update_figures(view: UnitView, delta: float) -> void:
	var standing := view.figures.filter(func(f: Figure) -> bool: return f.state == Figure.State.STAND)
	var back := -_facing(view.screen_side)
	# Fallen soldiers: knock figures backwards out of the formation.
	for i in maxi(0, standing.size() - _figures_wanted(view)):
		var figure: Figure = standing[standing.size() - 1 - i]
		figure.state = Figure.State.FLY
		figure.pos = view.pos + figure.offset
		figure.velocity = Vector2(back * _rng.randf_range(120, 220), -_rng.randf_range(220, 360))
		figure.spin = back * _rng.randf_range(6, 12)
	# Broken unit: everyone left runs for their own edge.
	if view.unit.broken:
		for figure in view.figures:
			if figure.state == Figure.State.STAND:
				figure.state = Figure.State.FLEE
				figure.pos = view.pos + figure.offset
				figure.velocity = Vector2(back * _rng.randf_range(160, 220), 0)
	for figure in view.figures:
		match figure.state:
			Figure.State.FLY:
				figure.velocity.y += GRAVITY * delta
				figure.pos += figure.velocity * delta
				figure.rotation += figure.spin * delta
				if figure.pos.y > size.y + 40 or figure.pos.x < -40 or figure.pos.x > size.x + 40:
					figure.state = Figure.State.GONE
			Figure.State.FLEE:
				figure.pos += figure.velocity * delta
				if figure.pos.x < -40 or figure.pos.x > size.x + 40:
					figure.state = Figure.State.GONE


func _spawn_effects(event: Dictionary) -> void:
	if event.type != &"gun_volley" and event.type != &"arrow_volley":
		return
	var shooter: UnitView = _views[event.side][event.unit]
	var enemy_side := 1 - int(event.side)
	var targets: Array = []
	var front := _simulator.record.sides[enemy_side].front_row()
	for view: UnitView in _views[enemy_side]:
		if view.unit.is_active() and (event.type == &"arrow_volley" or int(view.unit.data.row) == front):
			targets.append(view)
	if targets.is_empty():
		return
	var count := clampi(_figures_wanted(shooter) * 2, 4, 16)
	for i in count:
		var target: UnitView = targets[_rng.randi() % targets.size()]
		var land := target.pos + Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-20, 20))
		var start := shooter.pos + Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-15, 5))
		if event.type == &"gun_volley":
			_add_projectile(&"bullet", start, land, _rng.randf_range(0.0, 0.15), 0.22)
		else:
			# Up and out of the frame, then down onto the target from above.
			var apex := Vector2(start.x + _facing(shooter.screen_side) * _rng.randf_range(60, 140), -30)
			var delay := _rng.randf_range(0.0, 0.25)
			_add_projectile(&"arrow", start, apex, delay, 0.45)
			_add_projectile(&"arrow", Vector2(land.x - _facing(shooter.screen_side) * 60, -30), land, delay + 0.75, 0.4)


func _add_projectile(kind: StringName, from: Vector2, to: Vector2, delay: float, duration: float) -> void:
	var projectile := Projectile.new()
	projectile.kind = kind
	projectile.from = from
	projectile.to = to
	projectile.delay = delay
	projectile.duration = duration
	_projectiles.append(projectile)


# --- Drawing ------------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SKY_COLOR)
	draw_rect(Rect2(0, _ground_top(), size.x, size.y - _ground_top()), GROUND_COLOR)
	var zone := _zone_width()
	for x in [zone, size.x - zone]:
		draw_line(Vector2(x, 0), Vector2(x, size.y), ZONE_LINE_COLOR, 2.0)
	if _simulator == null:
		return
	for s in 2:
		for view: UnitView in _views[s]:
			_draw_unit(view)
	for projectile in _projectiles:
		_draw_projectile(projectile)


func _draw_unit(view: UnitView) -> void:
	var color := SIDE_COLORS[view.screen_side]
	var facing := _facing(view.screen_side)
	var fighting := _simulator.is_melee_started() and absf(view.pos.x - _target_x(view)) < 1.0 \
			and not _is_in_side_zone(view.unit)
	var running := absf(view.pos.x - _target_x(view)) >= 1.0
	for figure in view.figures:
		match figure.state:
			Figure.State.STAND:
				var bob := 0.0
				if running:
					bob = absf(sin(_clock * 14.0 + figure.phase)) * -3.0
				elif fighting:
					bob = sin(_clock * 10.0 + figure.phase) * 1.5
				_draw_figure(view.pos + figure.offset + Vector2(0, bob), 0.0, facing, color, view.unit.data)
			Figure.State.FLY:
				_draw_figure(figure.pos, figure.rotation, facing, color.darkened(0.3), view.unit.data)
			Figure.State.FLEE:
				var bob := absf(sin(_clock * 16.0 + figure.phase)) * -3.0
				_draw_figure(figure.pos + Vector2(0, bob), 0.0, -facing, color.darkened(0.45), view.unit.data)


## A stick soldier standing on `foot`, facing right when facing > 0.
func _draw_figure(foot: Vector2, rotation: float, facing: float, color: Color, data: UnitData) -> void:
	draw_set_transform(foot, rotation, Vector2.ONE * FIGURE_SCALE)
	draw_line(Vector2(-2, 0), Vector2(-1, -5), color.darkened(0.4), 1.5)
	draw_line(Vector2(2, 0), Vector2(1, -5), color.darkened(0.4), 1.5)
	draw_rect(Rect2(-3, -13, 6, 8), color)
	draw_circle(Vector2(0, -16), 3.0, Color(0.95, 0.82, 0.68))
	var hand := Vector2(3 * facing, -9)
	if data.attack_kind == UnitData.AttackKind.BOW:
		var start_angle := -PI / 2 if facing > 0 else PI / 2
		draw_arc(hand + Vector2(2 * facing, 0), 5.0, start_angle, start_angle + PI, 8, ARROW_COLOR, 1.2)
	elif data.attack_kind == UnitData.AttackKind.GUN:
		draw_line(hand, hand + Vector2(10 * facing, -1), Color(0.3, 0.3, 0.3), 2.0)
	elif data.row == UnitData.Row.MIDDLE:
		draw_line(hand + Vector2(-4 * facing, 4), hand + Vector2(14 * facing, -10), Color(0.75, 0.75, 0.8), 1.2)
	else:
		draw_line(hand, hand + Vector2(7 * facing, -5), Color(0.85, 0.85, 0.9), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_projectile(projectile: Projectile) -> void:
	var t := (projectile.age - projectile.delay) / projectile.duration
	if t < 0.0 or t > 1.0:
		return
	var direction := (projectile.to - projectile.from).normalized()
	var pos := projectile.from.lerp(projectile.to, t)
	if projectile.kind == &"bullet":
		draw_line(pos, pos - direction * 14.0, BULLET_COLOR, 1.5)
	else:
		draw_line(pos, pos - direction * 10.0, ARROW_COLOR, 1.2)
		draw_circle(pos, 1.2, ARROW_COLOR)
