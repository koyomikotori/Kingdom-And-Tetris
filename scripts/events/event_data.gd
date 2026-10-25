class_name EventData
extends Resource
## A random event (GDD §9c), one .tres per event in data/events/: when it may happen, which clan it
## is about (if any), and the choices it offers. Conditions left at their defaults are not checked.

enum Category { ECONOMY, DIPLOMACY, MILITARY, KINGDOM }

const CATEGORY_NAMES: Array[String] = ["Kinh tế", "Ngoại giao", "Quân sự", "Trong vương quốc"]

@export var event_id: StringName
@export var title: String
## "{clan}" is replaced by the event's clan.
@export_multiline var text: String
@export var category: Category = Category.ECONOMY
## Relative chance among the events that can happen this turn.
@export var weight: float = 1.0
## Turns before the same event can happen again.
@export var cooldown: int = 8

@export_group("Conditions")
@export var min_turn: int = 3
## Resource id -> least amount in the stockpile.
@export var min_stock: Dictionary[StringName, int] = {}
## Terrain id -> least number of owned cells of it.
@export var min_terrain: Dictionary[StringName, int] = {}
@export var required_building: StringName = &""
@export var min_squads: int = 0
## There is room for one more squad.
@export var needs_free_squad_slot: bool = false
## Some squad is below full size.
@export var needs_wounded_squad: bool = false
## The kingdom beat bandits at the start of the previous turn.
@export var needs_raid_won_last_turn: bool = false

@export_group("Clan")
## The event is about one clan, picked among those that match the filters below.
@export var needs_clan: bool = false
## Relation tier range (Diplomacy.Tier: 0 Hostile … 4 Close).
@export var clan_min_tier: int = 0
@export var clan_max_tier: int = 4
@export var clan_must_be_allied: bool = false
## The clan has more soldiers than the kingdom.
@export var clan_must_be_stronger: bool = false
## Clans at war with the kingdom are skipped unless this is set.
@export var clan_may_be_at_war: bool = false

@export_group("")
@export var choices: Array[EventChoiceData] = []


## All events, sorted by event_id.
static func load_all() -> Dictionary[StringName, EventData]:
	var result: Dictionary[StringName, EventData] = {}
	result.assign(DataLibrary.load_folder("res://data/events/", &"event_id"))
	return result
