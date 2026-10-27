class_name EventOutcomeData
extends Resource
## One possible result of an event choice (GDD §9c). A choice rolls one of its outcomes by weight;
## the player only sees the result after choosing. Every effect is optional.

@export var weight: float = 1.0
## What happened, shown after the choice. "{clan}" is replaced by the event's clan.
@export_multiline var text: String
## Resources gained (positive) or lost (negative, never more than the stockpile holds).
@export var resources: Dictionary[StringName, int] = {}
## Share (0..1) of each listed resource's stock that is lost.
@export var resource_loss: Dictionary[StringName, float] = {}
## Relation change with the event's clan, and with every clan.
@export var relation: int = 0
@export var relation_all: int = 0
## A new squad of this player unit (skipped when the kingdom has no room for another squad).
@export var add_unit: StringName = &""
@export var add_soldiers: int = 0
## Share (0..1) of every squad's soldiers that is lost.
@export var army_loss: float = 0.0
## Every squad below full size regains this share (0..1) of its full size.
@export var replenish: float = 0.0
## Extra land pieces added to the hand right away.
@export var extra_pieces: int = 0
## Soldiers added to (or removed from) the event clan's army.
@export var clan_strength: int = 0
## The event's clan declares war on the kingdom (when it can).
@export var declare_war: bool = false
## A general joins the kingdom, with a random star rank in this range (0 = none; GDD §8, M11d).
@export var general_min_stars: int = 0
@export var general_max_stars: int = 0
## A random item of this rarity (Item.Rarity: 0 Thường … 4 Huyền thoại, a legendary not found yet,
## else an epic one); -1 = none (GDD §8 "Trang bị", M12e).
@export var item_rarity: int = -1
