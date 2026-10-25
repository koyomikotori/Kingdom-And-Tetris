class_name General
extends RefCounted
## One general (GDD §8, M11d): name, stars, Võ lực (might) and Thống suất (command), an optional
## trait, and how many turns a wound still keeps them out of battle.

const NO_TRAIT: StringName = &""

var name: String
var stars: int
var might: int
var command: int
var trait_id: StringName = NO_TRAIT
var wounded_turns := 0


func is_ready() -> bool:
	return wounded_turns <= 0


func star_text() -> String:
	return "★".repeat(stars)


func to_save() -> Dictionary:
	return {"name": name, "stars": stars, "might": might, "command": command, "trait_id": String(trait_id),
			"wounded_turns": wounded_turns}


static func from_save(data: Dictionary) -> General:
	var general := General.new()
	general.name = data.name
	general.stars = int(data.stars)
	general.might = int(data.might)
	general.command = int(data.command)
	general.trait_id = StringName(data.trait_id)
	general.wounded_turns = int(data.wounded_turns)
	return general
