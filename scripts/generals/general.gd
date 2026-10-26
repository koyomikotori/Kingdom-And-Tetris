class_name General
extends Officer
## One general (GDD §8, M11d): Võ lực (might), Thống suất (command) and an optional trait, on top
## of what every officer has (name, stars, wounds, level).

const NO_TRAIT: StringName = &""

var might: int
var command: int
var trait_id: StringName = NO_TRAIT


func to_save() -> Dictionary:
	var data := _officer_save()
	data.merge({"might": might, "command": command, "trait_id": String(trait_id)})
	return data


static func from_save(data: Dictionary) -> General:
	var general := General.new()
	general._officer_load(data)
	general.might = int(data.might)
	general.command = int(data.command)
	general.trait_id = StringName(data.trait_id)
	return general
