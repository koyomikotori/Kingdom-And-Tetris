class_name Victory
extends RefCounted
## Win and loss conditions (GDD §9b, campaign rules §15): one victory, uniting the land (every clan
## annexed or allied), and the fall of the castle. Owned by KingdomState; takes the state as an
## argument instead of holding it, so there is no reference cycle.

enum Path { CONQUEST }

const NO_PATH := -1
const PATH_NAMES: Array[String] = ["Thống nhất thiên hạ"]
const PATH_DESCRIPTIONS: Array[String] = ["Mọi gia tộc trên bản đồ đều đã bị thôn tính hoặc là đồng minh."]
## Warn when this little land is left outside the castle.
const DANGER_CELLS := 6

## The path already won (the player kept playing), or NO_PATH.
var won_path := NO_PATH
## The castle fell: the game is over.
var lost := false


## {"united": clans annexed or allied, "total": clans on the map}.
func progress(state: KingdomState) -> Dictionary:
	return {"united": state.diplomacy.count_united(), "total": state.diplomacy.clans.size()}


func is_achieved(state: KingdomState) -> bool:
	var counts := progress(state)
	return counts.total > 0 and counts.united >= counts.total


## End of every turn: check().
func end_turn(state: KingdomState) -> int:
	return check(state)


## The path won right now, or NO_PATH. Only the first victory is reported: after it the player
## keeps playing without being told again.
func check(state: KingdomState) -> int:
	if won_path != NO_PATH or lost:
		return NO_PATH
	if is_achieved(state):
		won_path = Path.CONQUEST
		return won_path
	return NO_PATH


## Little land is left around the castle: one more lost invasion may end the game.
func castle_in_danger(state: KingdomState) -> bool:
	return state.board.count_land_outside_castle() <= DANGER_CELLS


func to_save() -> Dictionary:
	return {"won_path": won_path, "lost": lost}


func load_save(data: Dictionary) -> void:
	won_path = int(data.won_path)
	lost = bool(data.lost)
