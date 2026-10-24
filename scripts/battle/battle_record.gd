class_name BattleRecord
extends RefCounted
## Everything that happened in one battle, for the report screen and (M6) the battle animation.

const ATTACKER := 0
const DEFENDER := 1

## Why the battle ended.
enum EndReason { NO_ARMY, WIPED_OUT, ROUTED, ROUND_LIMIT }

## [attacker, defender]
var sides: Array[BattleSide] = []
## One entry per step: {"phase": StringName, "round": int, "alive": [[int...], [int...]], "hp": [[float...], [float...]]}.
## Index i of "alive"/"hp" matches sides[i].groups.
var steps: Array[Dictionary] = []
var winner: int = DEFENDER
var end_reason: EndReason = EndReason.ROUND_LIMIT


func _init(attacker: BattleSide, defender: BattleSide) -> void:
	sides = [attacker, defender]


func loser() -> int:
	return 1 - winner
