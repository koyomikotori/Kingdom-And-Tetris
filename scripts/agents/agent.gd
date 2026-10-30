class_name Agent
extends Officer
## A spy hired at the Sở cảnh sát (GDD §8 M14e): name, stars, level and XP, no items. Sent on a
## mission to one clan for Agents.MISSION_TURNS turns.

const NO_MISSION: StringName = &""
const RELATIONS: StringName = &"relations"
const SABOTAGE: StringName = &"sabotage"
const MISSION_NAMES: Dictionary[StringName, String] = {RELATIONS: "Tăng quan hệ", SABOTAGE: "Phá hoại"}
const MAX_LEVEL := 10
## Regrowth taken off the clan per level 1–10 by a sabotage mission (percentage points).
const SABOTAGE_BY_LEVEL: Array[float] = [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 6.0]

var mission: StringName = NO_MISSION
var target: StringName = &""
var turns_left := 0


func is_busy() -> bool:
	return mission != NO_MISSION


## 4 + stars: a 1★ agent reaches level 5, a 6★ one level 10.
func max_level() -> int:
	return mini(MAX_LEVEL, 4 + stars)


func xp_to_next() -> int:
	return 100 * level


## Relation points a relations mission adds each turn.
func relation_gain() -> int:
	return level


## Share of the clan's maximum strength a sabotage mission takes off its regrowth each turn.
func sabotage_share() -> float:
	return SABOTAGE_BY_LEVEL[clampi(level, 1, MAX_LEVEL) - 1] / 100.0


func to_save() -> Dictionary:
	var data := _officer_save()
	data.erase("items")
	data.merge({"mission": String(mission), "target": String(target), "turns_left": turns_left})
	return data


static func from_save(data: Dictionary) -> Agent:
	var agent := Agent.new()
	agent._officer_load(data)
	agent.mission = StringName(data.get("mission", ""))
	agent.target = StringName(data.get("target", ""))
	agent.turns_left = int(data.get("turns_left", 0))
	return agent
