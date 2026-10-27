class_name MapLife
extends RefCounted
## The little life on the kingdom map (GDD §13, M13c): villagers walking between the castle and the
## production buildings and carrying their goods home, ox carts from the mines and lumber mills,
## soldier patrols marching out of the military buildings to the border, horses around the war
## stable and the horse farms, deer in the forests outside the kingdom and birds crossing the sky.
## Pure logic in cell units (1.0 = one cell, (0, 0) = the board's top-left corner). Walkers keep to
## the cell edges, the gaps between the buildings; MapLifeView draws them. Nothing here touches the
## game state.

enum Kind { VILLAGER, CART, SOLDIER, HORSE, DEER, BIRD }

const MAX_VILLAGERS := 8
const MAX_CARTS := 2
const MAX_PATROLS := 3
const MAX_HORSES := 4
const MAX_DEER := 2
## One patrol per this many squads in the army.
const SQUADS_PER_PATROL := 3
## Cells per second.
const SPEEDS: Dictionary[Kind, float] = {Kind.VILLAGER: 0.55, Kind.CART: 0.35, Kind.SOLDIER: 0.45,
		Kind.HORSE: 0.3, Kind.DEER: 0.25, Kind.BIRD: 1.6}
## What villagers bring home from each building.
const GOODS: Dictionary[StringName, StringName] = {&"farm": &"food", &"lumber_mill": &"wood", &"mine": &"stone"}
const CART_SOURCES: Array[StringName] = [&"mine", &"lumber_mill"]
## Patrols march out of these (or the castle when there is none).
const PATROL_SOURCES: Array[StringName] = [&"barracks", &"war_stable", &"archery_range", &"martial_hall",
		&"military_academy", &"watchtower"]
## Horses graze around the war stable, and around farms from the level that breeds horses.
const HORSE_FARM_LEVEL := 3
## Seconds between flocks of birds.
const BIRD_INTERVAL := Vector2(6.0, 14.0)


class Walker:
	extends RefCounted
	var kind: Kind
	var pos := Vector2.ZERO
	## Waypoints still ahead, in cell units.
	var path: Array[Vector2] = []
	## Seconds left standing still.
	var wait := 0.0
	## The resource carried home (villagers, carts), or &"".
	var carry: StringName = &""
	## Heading out to `target` (true) or back home (false).
	var outbound := false
	## The building origin this walker works at or comes from.
	var home := Vector2i.ZERO
	var target := Vector2i.ZERO
	## Where horses and deer wander (cell units).
	var area := Rect2()
	## Soldiers in a patrol.
	var count := 1
	## 1 facing right, -1 facing left.
	var facing := 1.0
	var age := 0.0
	## Villager look (0 or 1).
	var variant := 0

	func is_moving() -> bool:
		return wait <= 0.0 and not path.is_empty()


var walkers: Array[Walker] = []
var _board: BoardData
var _rng := RandomNumberGenerator.new()
var _signature := ""
var _bird_timer := 0.0
## Building origins by building id (finished buildings only), and the castle's origin.
var _origins: Dictionary[StringName, Array] = {}
var _castle := Vector2i(-1, -1)
var _border: Array[Vector2i] = []


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


## Rebuilds the walkers when the buildings, the territory or the army size changed; otherwise
## everyone carries on where they are.
func sync(board: BoardData, squads: int) -> void:
	var signature := _signature_of(board, squads)
	if signature == _signature and board == _board:
		return
	var first := _board == null
	_board = board
	_signature = signature
	_scan()
	var old := walkers
	walkers = []
	_spawn_workers()
	_spawn_patrols(squads)
	_spawn_horses()
	_spawn_deer()
	_keep_old_walkers(old)
	if first:
		_bird_timer = _rng.randf_range(1.0, BIRD_INTERVAL.x)


## After a change, walkers already on the map stay where they are and only take their new role:
## each freshly spawned one is replaced by an old one of the same kind (horses and deer only at
## the same place). New ones appear only for what is new; birds fly on.
func _keep_old_walkers(old: Array[Walker]) -> void:
	for i in walkers.size():
		var fresh := walkers[i]
		for walker in old:
			if walker.kind != fresh.kind:
				continue
			if walker.kind in [Kind.HORSE, Kind.DEER] and walker.area != fresh.area:
				continue
			if walker.kind == Kind.SOLDIER:
				walker.home = fresh.home
			old.erase(walker)
			walkers[i] = walker
			break
	for walker in old:
		if walker.kind == Kind.BIRD:
			walkers.append(walker)


func _signature_of(board: BoardData, squads: int) -> String:
	var parts: PackedStringArray = ["%dx%d" % [board.width, board.height], str(squads)]
	var owned := 0
	for cell in board.get_all_cells():
		if cell.owned:
			owned += 1
		if cell.has_building() and cell.coord == cell.building_origin:
			parts.append("%s@%d,%d:%d:%d" % [cell.building_id, cell.coord.x, cell.coord.y, cell.building_level,
					int(cell.is_constructing())])
	parts.append(str(owned))
	return ",".join(parts)


func _scan() -> void:
	_origins.clear()
	_castle = Vector2i(-1, -1)
	for cell in _board.get_all_cells():
		if not cell.has_building() or cell.coord != cell.building_origin:
			continue
		if cell.building_id == BoardData.CASTLE_ID:
			_castle = cell.coord
		elif not cell.is_constructing():
			if not _origins.has(cell.building_id):
				_origins[cell.building_id] = []
			_origins[cell.building_id].append(cell.coord)
	_border.clear()
	for y in _board.height + 1:
		for x in _board.width + 1:
			var corner := Vector2i(x, y)
			var owned := 0
			for cell_coord in _cells_around(corner):
				var cell := _board.get_cell(cell_coord)
				if cell != null and cell.owned:
					owned += 1
			if owned > 0 and owned < 4:
				_border.append(corner)


func _cells_around(corner: Vector2i) -> Array[Vector2i]:
	return [corner + Vector2i(-1, -1), corner + Vector2i(0, -1), corner + Vector2i(-1, 0), corner]


# --- Spawning -------------------------------------------------------------------------------

func _buildings_of(ids: Array[StringName]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for id in ids:
		for origin: Vector2i in _origins.get(id, []):
			result.append(origin)
	return result


func _spawn_workers() -> void:
	if _castle.x < 0:
		return
	var sources: Array[StringName] = []
	sources.assign(GOODS.keys())
	var workplaces := _buildings_of(sources)
	for i in mini(MAX_VILLAGERS, 2 + workplaces.size()):
		var walker := _new_walker(Kind.VILLAGER, _castle_corner())
		walker.variant = i % 2
		walker.wait = _rng.randf_range(0.0, 6.0)
	for i in mini(MAX_CARTS, _buildings_of(CART_SOURCES).size()):
		var cart := _new_walker(Kind.CART, _castle_corner())
		cart.wait = _rng.randf_range(0.0, 8.0)


func _spawn_patrols(squads: int) -> void:
	if _castle.x < 0 or squads <= 0:
		return
	var sources := _buildings_of(PATROL_SOURCES)
	if sources.is_empty():
		sources.append(_castle)
	for i in mini(MAX_PATROLS, ceili(float(squads) / SQUADS_PER_PATROL)):
		var home: Vector2i = sources[i % sources.size()]
		var patrol := _new_walker(Kind.SOLDIER, _any(_corners_of(home)))
		patrol.home = home
		patrol.count = 2 + _rng.randi() % 2
		patrol.wait = _rng.randf_range(0.0, 5.0)


func _spawn_horses() -> void:
	var pastures := _buildings_of([&"war_stable"])
	var stables := pastures.size()
	for origin in _buildings_of([&"farm"]):
		if _board.get_building_level(origin) >= HORSE_FARM_LEVEL:
			pastures.append(origin)
	var spawned := 0
	for i in pastures.size():
		# Two horses at a stable, one at a farm.
		for n in (2 if i < stables else 1):
			if spawned >= MAX_HORSES:
				return
			var area := _building_rect(pastures[i])
			var horse := _new_walker(Kind.HORSE, Vector2(_point_on_edge(area)))
			horse.area = area
			horse.wait = _rng.randf_range(0.0, 3.0)
			spawned += 1


func _spawn_deer() -> void:
	var forests: Array[Vector2i] = []
	for cell in _board.get_all_cells():
		if not cell.owned and cell.terrain_id == &"forest" and not cell.has_building():
			forests.append(cell.coord)
	for i in mini(MAX_DEER, forests.size()):
		var coord: Vector2i = forests[_rng.randi() % forests.size()]
		var area := Rect2(Vector2(coord) + Vector2(0.2, 0.3), Vector2(0.6, 0.5))
		var deer := _new_walker(Kind.DEER, area.get_center())
		deer.area = area
		deer.wait = _rng.randf_range(0.0, 4.0)


func _new_walker(kind: Kind, at: Vector2) -> Walker:
	var walker := Walker.new()
	walker.kind = kind
	walker.pos = at
	walker.facing = 1.0 if _rng.randf() < 0.5 else -1.0
	walkers.append(walker)
	return walker


# --- Moving ---------------------------------------------------------------------------------

func update(delta: float) -> void:
	if _board == null:
		return
	for walker in walkers.duplicate():
		walker.age += delta
		if walker.wait > 0.0:
			walker.wait -= delta
			continue
		if walker.path.is_empty():
			_next_leg(walker)
			continue
		var step: float = SPEEDS[walker.kind] * delta
		while step > 0.0 and not walker.path.is_empty():
			var to: Vector2 = walker.path[0]
			var gap: float = walker.pos.distance_to(to)
			if absf(to.x - walker.pos.x) > 0.001:
				walker.facing = signf(to.x - walker.pos.x)
			if gap <= step:
				walker.pos = to
				walker.path.pop_front()
				step -= gap
			else:
				walker.pos = walker.pos.move_toward(to, step)
				step = 0.0
		if walker.kind == Kind.BIRD and walker.path.is_empty():
			walkers.erase(walker)
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		_bird_timer = _rng.randf_range(BIRD_INTERVAL.x, BIRD_INTERVAL.y)
		_spawn_birds()


## A walker that reached the end of its path decides where to go next.
func _next_leg(walker: Walker) -> void:
	match walker.kind:
		Kind.VILLAGER, Kind.CART:
			_next_trip(walker)
		Kind.SOLDIER:
			_next_patrol(walker)
		Kind.HORSE:
			walker.path = [Vector2(_point_on_edge(walker.area))]
			walker.wait = _rng.randf_range(1.0, 4.0)
		Kind.DEER:
			walker.path = [Vector2(_rng.randf_range(walker.area.position.x, walker.area.end.x),
					_rng.randf_range(walker.area.position.y, walker.area.end.y))]
			walker.wait = _rng.randf_range(1.5, 5.0)


## Villagers and carts: castle → a workplace → back with its goods → …
func _next_trip(walker: Walker) -> void:
	var from := Vector2i(walker.pos.round())
	if walker.outbound:
		# Arrived at work: load up and head home.
		walker.outbound = false
		var cell := _board.get_cell(walker.target)
		walker.carry = GOODS.get(cell.building_id, &"food") if cell != null else &""
		walker.path = find_path(from, _corners_of(_castle))
		walker.wait = _rng.randf_range(1.5, 3.0)
		return
	walker.carry = &""
	var sources: Array[StringName] = []
	if walker.kind == Kind.CART:
		sources = CART_SOURCES
	else:
		sources.assign(GOODS.keys())
	var workplaces := _buildings_of(sources)
	walker.wait = _rng.randf_range(1.0, 2.5)
	if workplaces.is_empty():
		# Nothing to work at yet: a stroll to a random spot of the territory and back.
		if _border.is_empty():
			return
		walker.path = find_path(from, [_border[_rng.randi() % _border.size()]])
		walker.target = _castle
		walker.outbound = false
		return
	walker.target = workplaces[_rng.randi() % workplaces.size()]
	walker.path = find_path(from, _corners_of(walker.target))
	walker.outbound = true


## Patrols: out to a random spot on the border, back to their building, rest, again.
func _next_patrol(walker: Walker) -> void:
	var from := Vector2i(walker.pos.round())
	if walker.outbound or _border.is_empty():
		walker.outbound = false
		walker.path = find_path(from, _corners_of(walker.home))
		walker.wait = _rng.randf_range(0.5, 1.5)
	else:
		walker.outbound = true
		walker.path = find_path(from, [_border[_rng.randi() % _border.size()]])
		walker.wait = _rng.randf_range(2.0, 5.0)


func _spawn_birds() -> void:
	var y := _rng.randf_range(0.5, maxf(0.6, _board.height - 0.5))
	var left_to_right := _rng.randf() < 0.5
	var start := Vector2(-1.0 if left_to_right else _board.width + 1.0, y)
	var end := Vector2(_board.width + 1.0 if left_to_right else -1.0, y + _rng.randf_range(-2.0, 2.0))
	for i in 1 + _rng.randi() % 3:
		var offset := Vector2(-0.4 * i * (1.0 if left_to_right else -1.0), 0.25 * i * (1 if i % 2 else -1))
		var bird := _new_walker(Kind.BIRD, start + offset)
		bird.path = [end + offset]
		bird.facing = 1.0 if left_to_right else -1.0


# --- Paths along the cell edges --------------------------------------------------------------

## Shortest walk along the cell edges from corner `from` to the nearest of `goals`, as the corners
## after `from` (empty when there is no way or `from` is a goal). An edge can be walked when a cell
## beside it belongs to the kingdom and it does not cut through a building.
func find_path(from: Vector2i, goals: Array[Vector2i]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if goals.has(from) or _board == null:
		return result
	var came: Dictionary[Vector2i, Vector2i] = {from: from}
	var queue: Array[Vector2i] = [from]
	var found := Vector2i(-1, -1)
	while not queue.is_empty():
		var corner: Vector2i = queue.pop_front()
		if goals.has(corner):
			found = corner
			break
		for offset in BoardData.NEIGHBOR_OFFSETS:
			var next: Vector2i = corner + offset
			if came.has(next) or next.x < 0 or next.y < 0 or next.x > _board.width or next.y > _board.height:
				continue
			if edge_open(corner, next):
				came[next] = corner
				queue.append(next)
	if found.x < 0:
		return result
	var corner := found
	while corner != from:
		result.push_front(Vector2(corner))
		corner = came[corner]
	return result


## Whether walkers may go along the edge between two neighboring corners.
func edge_open(a: Vector2i, b: Vector2i) -> bool:
	var low := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var sides: Array[CellData]
	if a.y == b.y:
		sides = [_board.get_cell(low + Vector2i(0, -1)), _board.get_cell(low)]
	else:
		sides = [_board.get_cell(low + Vector2i(-1, 0)), _board.get_cell(low)]
	var owned := false
	for cell in sides:
		if cell != null and cell.owned:
			owned = true
	if not owned:
		return false
	# Between two cells of one building (inside the castle) is not a way through.
	return not (sides[0] != null and sides[1] != null and sides[0].has_building()
			and sides[0].building_origin == sides[1].building_origin and sides[1].has_building())


## The corners around a building (its outer edge, every cell corner on it).
func _corners_of(origin: Vector2i) -> Array[Vector2i]:
	var rect := _building_rect(origin)
	var result: Array[Vector2i] = []
	for y in range(int(rect.position.y), int(rect.end.y) + 1):
		for x in range(int(rect.position.x), int(rect.end.x) + 1):
			if x == int(rect.position.x) or x == int(rect.end.x) or y == int(rect.position.y) or y == int(rect.end.y):
				result.append(Vector2i(x, y))
	return result


func _building_rect(origin: Vector2i) -> Rect2:
	var rect := Rect2(Vector2(origin), Vector2.ONE)
	for cell in _board.get_building_cells(origin):
		rect = rect.merge(Rect2(Vector2(cell.coord), Vector2.ONE))
	return rect


func _castle_corner() -> Vector2:
	var corners := _corners_of(_castle)
	return Vector2(corners[_rng.randi() % corners.size()])


func _any(corners: Array[Vector2i]) -> Vector2:
	return Vector2(corners[_rng.randi() % corners.size()])


## A random point on the edge of `rect` (horses walk around their stable, in the gap).
func _point_on_edge(rect: Rect2) -> Vector2:
	var t := _rng.randf() * 2.0 * (rect.size.x + rect.size.y)
	if t < rect.size.x:
		return rect.position + Vector2(t, 0)
	t -= rect.size.x
	if t < rect.size.y:
		return rect.position + Vector2(rect.size.x, t)
	t -= rect.size.y
	if t < rect.size.x:
		return rect.end - Vector2(t, 0)
	return rect.position + Vector2(0, rect.size.y - (t - rect.size.x))


func count(kind: Kind) -> int:
	return walkers.filter(func(w: Walker) -> bool: return w.kind == kind).size()
