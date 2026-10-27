class_name LegendaryItemData
extends Resource
## A named legendary item (GDD §8 "Trang bị", M12e): fixed slot, weapon type and two strong
## effects. One .tres per item in data/legendary_items/; each can be found once per game.

@export var item_id: StringName
@export var display_name: String
@export_multiline var description: String
## &"general" or &"advisor".
@export var kind: StringName = &"general"
## &"weapon", &"armor" or &"accessory".
@export var slot: StringName = &"weapon"
## Generals' weapons: Item.WEAPON_TYPES entry.
@export var weapon_type: StringName = &""
@export var effects: Array[StringName] = []


static func load_all() -> Dictionary[StringName, LegendaryItemData]:
	var result: Dictionary[StringName, LegendaryItemData] = {}
	result.assign(DataLibrary.load_folder("res://data/legendary_items/", &"item_id"))
	return result
