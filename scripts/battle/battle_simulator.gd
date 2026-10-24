class_name BattleSimulator
extends RefCounted
## Phase-based auto-battle (GDD §7.4). Pure logic: no nodes, no animation.
## Order: gun volley -> arrow volley -> melee rounds (archers and guns keep supporting).
## Both sides strike at the same time in every step. Same seed + same armies = same result.

const PHASE_GUNS: StringName = &"guns"
const PHASE_ARROWS: StringName = &"arrows"
const PHASE_MELEE: StringName = &"melee"

const MAX_MELEE_ROUNDS := 8
## A side whose alive soldiers fall below this fraction of its starting count breaks and loses.
const ROUT_FRACTION := 0.4
## Ranged units keep shooting during melee rounds at this strength.
const RANGED_SUPPORT_MULTIPLIER := 0.5
## Each hit is scaled by a random factor in [1 - VARIANCE, 1 + VARIANCE].
const VARIANCE := 0.1

var _rng := RandomNumberGenerator.new()


static func run(attacker: BattleSide, defender: BattleSide, seed_value: int) -> BattleRecord:
	return BattleSimulator.new()._run(attacker, defender, seed_value)


func _run(attacker: BattleSide, defender: BattleSide, seed_value: int) -> BattleRecord:
	_rng.seed = seed_value
	var record := BattleRecord.new(attacker, defender)
	if attacker.alive_total() == 0 or defender.alive_total() == 0:
		record.winner = BattleRecord.ATTACKER if defender.alive_total() == 0 else BattleRecord.DEFENDER
		record.end_reason = BattleRecord.EndReason.NO_ARMY
		return record
	if attacker.has_attack_kind(UnitData.AttackKind.GUN) or defender.has_attack_kind(UnitData.AttackKind.GUN):
		if _step_and_check(record, PHASE_GUNS, 0):
			return record
	if attacker.has_attack_kind(UnitData.AttackKind.BOW) or defender.has_attack_kind(UnitData.AttackKind.BOW):
		if _step_and_check(record, PHASE_ARROWS, 0):
			return record
	for round_number in range(1, MAX_MELEE_ROUNDS + 1):
		if _step_and_check(record, PHASE_MELEE, round_number):
			return record
	record.end_reason = BattleRecord.EndReason.ROUND_LIMIT
	record.winner = _better_side(record)
	return record


## Runs one step and records it. Returns true when the battle is over.
func _step_and_check(record: BattleRecord, phase: StringName, round_number: int) -> bool:
	_strike(record.sides, phase)
	record.steps.append(_snapshot(record.sides, phase, round_number))
	var lost := [_has_lost(record.sides[0]), _has_lost(record.sides[1])]
	if not lost[0] and not lost[1]:
		return false
	if lost[0] and lost[1]:
		record.winner = _better_side(record)
	else:
		record.winner = BattleRecord.DEFENDER if lost[0] else BattleRecord.ATTACKER
	var loser_side := record.sides[record.loser()]
	record.end_reason = BattleRecord.EndReason.WIPED_OUT if loser_side.alive_total() == 0 else BattleRecord.EndReason.ROUTED
	return true


## Both sides deal damage based on the state before the step, then all damage is applied.
func _strike(sides: Array[BattleSide], phase: StringName) -> void:
	# hits[target_side][target_group] = Array of [source_group, damage]
	var hits: Array = [[], []]
	for s in 2:
		for group in sides[1 - s].groups:
			hits[1 - s].append([])
	for s in 2:
		var target_side := sides[1 - s]
		for source in sides[s].groups:
			var multiplier := _phase_multiplier(phase, source.unit.attack_kind)
			if multiplier <= 0.0 or source.alive() == 0:
				continue
			var targets := _pick_targets(target_side, source.unit.attack_kind)
			for target_index in targets:
				var target := target_side.groups[target_index]
				var per_soldier := maxi(1, source.unit.attack - target.unit.defense)
				var damage: float = source.alive() * per_soldier * multiplier * targets[target_index] \
						* _rng.randf_range(1.0 - VARIANCE, 1.0 + VARIANCE)
				hits[1 - s][target_index].append([source, damage])
	for s in 2:
		for target_index in sides[s].groups.size():
			_apply_hits(sides[s].groups[target_index], hits[s][target_index])


## Damage beyond the target's remaining HP is not counted as damage dealt.
func _apply_hits(target: BattleSide.Group, group_hits: Array) -> void:
	var total := 0.0
	for hit in group_hits:
		total += hit[1]
	if total <= 0.0:
		return
	var effective := minf(1.0, target.hp / total)
	for hit in group_hits:
		hit[0].damage_dealt += hit[1] * effective
	target.hp = maxf(0.0, target.hp - total)


func _phase_multiplier(phase: StringName, kind: UnitData.AttackKind) -> float:
	match phase:
		PHASE_GUNS:
			return 1.0 if kind == UnitData.AttackKind.GUN else 0.0
		PHASE_ARROWS:
			return 1.0 if kind == UnitData.AttackKind.BOW else 0.0
		PHASE_MELEE:
			return 1.0 if kind == UnitData.AttackKind.MELEE else RANGED_SUPPORT_MULTIPLIER
	return 0.0


## Returns {group_index: share of the attack}, shares summing to 1.
## Arrows rain on every row equally; bullets and melee hit the front-most row still standing.
## Within a row, damage is split by how many soldiers each group has.
func _pick_targets(side: BattleSide, kind: UnitData.AttackKind) -> Dictionary:
	var rows := {}  # row -> Array of group indices with soldiers
	for i in side.groups.size():
		if side.groups[i].alive() > 0:
			var row: int = side.groups[i].unit.row
			if not rows.has(row):
				rows[row] = []
			rows[row].append(i)
	var result := {}
	if rows.is_empty():
		return result
	var row_keys := rows.keys()
	row_keys.sort()
	var chosen_rows: Array = row_keys if kind == UnitData.AttackKind.BOW else [row_keys[0]]
	for row in chosen_rows:
		var row_alive := 0
		for i in rows[row]:
			row_alive += side.groups[i].alive()
		for i in rows[row]:
			result[i] = float(side.groups[i].alive()) / row_alive / chosen_rows.size()
	return result


func _has_lost(side: BattleSide) -> bool:
	return side.alive_total() == 0 or side.fraction_alive() < ROUT_FRACTION


## Higher fraction of soldiers left wins; ties go to the defender.
func _better_side(record: BattleRecord) -> int:
	if record.sides[0].fraction_alive() > record.sides[1].fraction_alive():
		return BattleRecord.ATTACKER
	return BattleRecord.DEFENDER


func _snapshot(sides: Array[BattleSide], phase: StringName, round_number: int) -> Dictionary:
	var alive := [[], []]
	var hp := [[], []]
	for s in 2:
		for group in sides[s].groups:
			alive[s].append(group.alive())
			hp[s].append(group.hp)
	return {"phase": phase, "round": round_number, "alive": alive, "hp": hp}
