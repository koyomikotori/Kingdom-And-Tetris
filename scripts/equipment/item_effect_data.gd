class_name ItemEffectData
extends Resource
## One special effect an item can carry (GDD §8 "Trang bị", M12e). One .tres per effect in
## data/item_effects/. Rare items roll 1, epic 2, legendary items list theirs (strong: ×2).

@export var effect_id: StringName
## &"general" or &"advisor": which officers' items may roll it.
@export var kind: StringName = &"general"
## How it reads, "%s" being the amount (e.g. "+%s sĩ khí toàn quân").
@export var text: String
## Base amount (shares are 0..1 and shown as percents).
@export var amount: float = 0.0
@export var is_share: bool = false
## Advisors: the post the effect works in (&"admin", &"military"); empty = any.
@export var post: StringName = &""


static func load_all() -> Dictionary[StringName, ItemEffectData]:
	var result: Dictionary[StringName, ItemEffectData] = {}
	result.assign(DataLibrary.load_folder("res://data/item_effects/", &"effect_id"))
	return result


## "+10% sát thương cận vệ" for this multiplier (2 on legendary items).
func describe(multiplier: int = 1) -> String:
	var value := amount * multiplier
	return text % ("%d%%" % roundi(value * 100) if is_share else str(roundi(value)))
