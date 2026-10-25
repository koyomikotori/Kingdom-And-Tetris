class_name Victory
extends RefCounted
## Win and loss conditions (GDD §9b): two victory paths (conquest, and peace with a strong
## economy) and the fall of the castle. Owned by KingdomState; takes the state as an argument instead of
## holding it, so there is no reference cycle.

enum Path { CONQUEST, PROSPERITY }

const NO_PATH := -1
const PATH_NAMES: Array[String] = ["Chinh phục", "Hòa bình thịnh vượng"]
const PATH_DESCRIPTIONS: Array[String] = [
	"Sáp nhập mọi gia tộc.",
	"Mọi gia tộc còn lại đều là đồng minh, lãnh thổ rộng và thu nhập dồi dào, giữ %d lượt liền.",
]
## Turns in a row the prosperity goal must hold.
const HOLD_TURNS := 10
const MIN_ALLIES := 1
const PROSPERITY_CELLS := 120
const PROSPERITY_INCOME := 50
## Warn when this little land is left outside the castle.
const DANGER_CELLS := 6

## End-of-turn counts the goal of each path has held in a row (conquest wins at once).
var holds: Array[int] = [0, 0]
## The path already won (the player kept playing), or NO_PATH.
var won_path := NO_PATH
## The castle fell: the game is over.
var lost := false
var _resource_types: Array[ResourceTypeData] = ResourceTypeData.load_all()


## Each path's goal right now: {"path", "met": bool, "held", "fraction" (0..1, for a progress bar),
## "conditions": [{"text", "current", "needed", "met"}]}.
func progress(state: KingdomState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path in Path.values():
		var conditions := _conditions(state, path)
		var met := conditions.all(func(c: Dictionary) -> bool: return c.met)
		var fraction := 0.0
		for condition in conditions:
			fraction += clampf(float(condition.current) / condition.needed, 0.0, 1.0) / conditions.size()
		if path != Path.CONQUEST:
			# The hold counts for the last part of the bar.
			fraction = fraction * 0.8 + 0.2 * float(holds[path]) / HOLD_TURNS
		result.append({"path": path, "met": met, "held": holds[path], "fraction": fraction, "conditions": conditions})
	return result


func _conditions(state: KingdomState, path: Path) -> Array[Dictionary]:
	var clans := state.diplomacy.clans
	match path:
		Path.CONQUEST:
			var annexed := 0
			for clan_id in clans:
				annexed += 1 if clans[clan_id].annexed else 0
			return [_condition("Gia tộc đã sáp nhập", annexed, clans.size())]
		_:
			var remaining := 0
			var allies := 0
			for clan_id in clans:
				if not clans[clan_id].annexed:
					remaining += 1
					allies += 1 if clans[clan_id].is_allied() else 0
			var conditions: Array[Dictionary] = [
				_condition("Gia tộc còn lại là đồng minh", allies, maxi(remaining, MIN_ALLIES)),
				_condition("Lãnh thổ (ô)", state.board.count_owned_cells(), PROSPERITY_CELLS)]
			var income := state.get_net_income()
			for type in _resource_types:
				conditions.append(_condition("Thu nhập %s mỗi lượt" % type.display_name.to_lower(),
						income.get(type.resource_id, 0), PROSPERITY_INCOME))
			return conditions


func _condition(text: String, current: int, needed: int) -> Dictionary:
	return {"text": text, "current": current, "needed": needed, "met": current >= needed}


func is_achieved(state: KingdomState, path: Path) -> bool:
	if path == Path.CONQUEST:
		return _conditions(state, path).all(func(c: Dictionary) -> bool: return c.met)
	return holds[path] >= HOLD_TURNS


## End of every turn: hold counters move on (or reset), then check(). Returns a path won now, or NO_PATH.
func end_turn(state: KingdomState) -> int:
	var met := _conditions(state, Path.PROSPERITY).all(func(c: Dictionary) -> bool: return c.met)
	holds[Path.PROSPERITY] = holds[Path.PROSPERITY] + 1 if met else 0
	return check(state)


## The path won right now, or NO_PATH. Only the first victory is reported: after it the player
## keeps playing without being told again.
func check(state: KingdomState) -> int:
	if won_path != NO_PATH or lost:
		return NO_PATH
	for path in Path.values():
		if is_achieved(state, path):
			won_path = path
			return path
	return NO_PATH


## Little land is left around the castle: one more lost invasion may end the game.
func castle_in_danger(state: KingdomState) -> bool:
	return state.board.count_land_outside_castle() <= DANGER_CELLS


func to_save() -> Dictionary:
	return {"holds": holds.duplicate(), "won_path": won_path, "lost": lost}


func load_save(data: Dictionary) -> void:
	for i in mini(holds.size(), data.holds.size()):
		holds[i] = int(data.holds[i])
	won_path = int(data.won_path)
	lost = bool(data.lost)
