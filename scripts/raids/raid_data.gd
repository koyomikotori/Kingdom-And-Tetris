class_name RaidData
extends Resource
## Tuning for random bandit raids (GDD §7.2). Lives in data/raids/bandits.tres.

## No raids before this turn.
@export var first_turn: int = 6
## Chance per turn before watchtowers, 0..1.
@export var base_chance: float = 0.15
## Bandit count = base_size + floor(turn * size_per_turn).
@export var base_size: int = 2
@export var size_per_turn: float = 0.34
## Enemy unit id -> relative weight when picking each bandit's type.
@export var unit_weights: Dictionary[StringName, float] = {}
## Fraction of each resource lost when the raid wins.
@export var resource_loss_on_defeat: float = 0.3
## Fraction of each surviving soldier type lost when the raid wins (they flee).
@export var soldier_loss_on_defeat: float = 0.3
## Reward per defeated bandit when the kingdom wins.
@export var reward_per_bandit: Dictionary[StringName, int] = {}


static func load_bandits() -> RaidData:
	return load("res://data/raids/bandits.tres")
