class_name RaidData
extends Resource
## Tuning for random bandit raids (GDD §7.2). Lives in data/raids/bandits.tres.

## No raids before this turn.
@export var first_turn: int = 6
## Chance per turn before watchtowers, 0..1.
@export var base_chance: float = 0.15
## Bandit squads = base_squads + floor(turn * squads_per_turn).
@export var base_squads: int = 1
@export var squads_per_turn: float = 0.12
## Enemy unit id -> relative weight when picking each bandit squad's type.
@export var unit_weights: Dictionary[StringName, float] = {}
## Fraction of each resource lost when the raid wins.
@export var resource_loss_on_defeat: float = 0.3
## Reward per bandit squad when the kingdom wins.
@export var reward_per_squad: Dictionary[StringName, int] = {}


static func load_bandits() -> RaidData:
	return load("res://data/raids/bandits.tres")
