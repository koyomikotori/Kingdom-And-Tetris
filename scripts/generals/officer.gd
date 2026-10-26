class_name Officer
extends RefCounted
## What generals and advisors share (GDD §8): name, stars, wounds, and the level they grow
## through (M11e): XP toward the next level and points not yet added to a stat.

var name: String
var stars: int
var wounded_turns := 0
var level := 1
## XP gathered toward the next level (reset on each level up).
var xp := 0
## Unspent level points.
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


func _officer_save() -> Dictionary:
	return {"name": name, "stars": stars, "wounded_turns": wounded_turns, "level": level, "xp": xp, "points": points}


func _officer_load(data: Dictionary) -> void:
	name = data.name
	stars = int(data.stars)
	wounded_turns = int(data.wounded_turns)
	level = int(data.level)
	xp = int(data.xp)
	points = int(data.points)
