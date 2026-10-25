class_name General
extends RefCounted
## One general (GDD §8, M11d): name, stars, Võ lực (might) and Thống suất (command), an optional
## trait, how many turns a wound still keeps them out of battle, and their level (GDD §8, M11e):
## XP toward the next level and points not yet added to Võ lực / Thống suất.

const NO_TRAIT: StringName = &""

var name: String
var stars: int
var might: int
var command: int
var trait_id: StringName = NO_TRAIT
var wounded_turns := 0
var level := 1
## XP gathered toward the next level (reset on each level up).
var xp := 0
## Unspent level points (Generals.spend_point).
var points := 0


func is_ready() -> bool:
	return wounded_turns <= 0


func star_text() -> String:
	return "★".repeat(stars)


func max_level() -> int:
	return Experience.general_max_level(stars)


func xp_to_next() -> int:
	return Experience.general_xp_to_next(level)


## Adds XP and levels up (1 point per level) until the max level, where extra XP is dropped.
## Returns how many levels were gained.
func gain_xp(amount: int) -> int:
	var gained := 0
	xp += maxi(0, amount)
	while level < max_level() and xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		points += 1
		gained += 1
	if level >= max_level():
		xp = 0
	return gained


func to_save() -> Dictionary:
	return {"name": name, "stars": stars, "might": might, "command": command, "trait_id": String(trait_id),
			"wounded_turns": wounded_turns, "level": level, "xp": xp, "points": points}


static func from_save(data: Dictionary) -> General:
	var general := General.new()
	general.name = data.name
	general.stars = int(data.stars)
	general.might = int(data.might)
	general.command = int(data.command)
	general.trait_id = StringName(data.trait_id)
	general.wounded_turns = int(data.wounded_turns)
	general.level = int(data.level)
	general.xp = int(data.xp)
	general.points = int(data.points)
	return general
