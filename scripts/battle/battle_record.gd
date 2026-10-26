class_name BattleRecord
extends RefCounted
## Everything that happened in one battle, for the report screen and (M7) the battle animation.

const ATTACKER := 0
const DEFENDER := 1
const NO_SIDE := -1

## Why the battle ended.
enum EndReason { NO_ARMY, ALL_BROKEN, RETREAT, TIME_LIMIT }

## [attacker, defender]
var sides: Array[BattleSide] = []
## Notable moments, in time order: {"time": float, "type": StringName, "side": int, "unit": int}.
## Types: &"gun_volley", &"arrow_volley", &"charge", &"broken", &"retreat", &"general_fallen",
## &"stratagem" (also has "stratagem": the StratagemData id).
var events: Array[Dictionary] = []
## Taken every BattleSimulator.SNAPSHOT_INTERVAL seconds and at the end:
## {"time": float, "soldiers": [[int...], [int...]], "morale": [[float...], [float...]]}.
## Index i of each inner array matches sides[s].units[i].
var snapshots: Array[Dictionary] = []
var winner: int = DEFENDER
var end_reason: EndReason = EndReason.TIME_LIMIT
## The side that pressed retreat, or NO_SIDE.
var retreated_side: int = NO_SIDE
var duration := 0.0


func _init(attacker: BattleSide, defender: BattleSide) -> void:
	sides = [attacker, defender]


func loser() -> int:
	return 1 - winner
