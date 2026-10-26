class_name StratagemData
extends Resource
## One stratagem (mưu kế, GDD §8 M11f): used by the military advisor at the start of a battle.
## Each effect is base + per_point × Mưu lược. One .tres per stratagem in data/stratagems/.

enum Target { ENEMY_LARGEST, ENEMY_ALL, ENEMY_RANGED, OWN_ALL, OWN_FRONT }

const TARGET_NAMES: Array[String] = ["Đơn vị địch đông nhất", "Toàn quân địch", "Xạ thủ địch", "Toàn quân mình",
		"Hàng đầu quân mình"]

@export var stratagem_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var target: Target = Target.ENEMY_ALL

@export_group("Effect")
## Share of the target's current soldiers lost.
@export var soldier_loss_base: float = 0.0
@export var soldier_loss_per_point: float = 0.0
## Morale added (negative lowers it).
@export var morale_base: float = 0.0
@export var morale_per_point: float = 0.0
## Added to the unit's multipliers (BattleSide.Unit): melee attack, melee defense, range attack.
@export var attack_base: float = 0.0
@export var attack_per_point: float = 0.0
@export var defense_base: float = 0.0
@export var defense_per_point: float = 0.0
@export var range_base: float = 0.0
@export var range_per_point: float = 0.0


static func load_all() -> Dictionary[StringName, StratagemData]:
	var result: Dictionary[StringName, StratagemData] = {}
	result.assign(DataLibrary.load_folder("res://data/stratagems/", &"stratagem_id"))
	return result


func targets_enemy() -> bool:
	return target in [Target.ENEMY_LARGEST, Target.ENEMY_ALL, Target.ENEMY_RANGED]


## The effect with `points` of Mưu lược, as plain text for the UI.
func describe(points: int) -> String:
	var parts: Array[String] = []
	var loss := soldier_loss_base + soldier_loss_per_point * points
	if loss != 0.0:
		parts.append("mất %s lính" % _percent(loss))
	var morale := morale_base + morale_per_point * points
	if morale != 0.0:
		parts.append("%+.1f sĩ khí" % morale)
	for entry: Array in [[attack_base + attack_per_point * points, "tấn công cận chiến"],
			[defense_base + defense_per_point * points, "phòng thủ cận chiến"],
			[range_base + range_per_point * points, "tấn công tầm xa"]]:
		if entry[0] != 0.0:
			parts.append("%s%s %s" % ["+" if entry[0] > 0.0 else "−", _percent(absf(entry[0])), entry[1]])
	return "%s: %s" % [TARGET_NAMES[target], ", ".join(parts)]


static func _percent(value: float) -> String:
	return "%s%%" % String.num(snappedf(value * 100.0, 0.1))
