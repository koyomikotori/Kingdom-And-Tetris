class_name BattleOutcome
extends RefCounted
## What each battle unit keeps after a battle (GDD §7.6), shared by bandit raids and clan wars:
## - winning side: every survivor stays;
## - losing side: broken units are lost; unbroken units keep 50% (they retreat), unless
##   `lose_everything` (a failed attack on a clan, GDD §9.6) and the player did not retreat.
## Units lent by other clans (BattleSide.Unit.ally) never count as the side's own losses.

const RETREAT_KEEP_FRACTION := 0.5


static func soldiers_kept(unit: BattleSide.Unit, won: bool, retreated: bool, lose_everything: bool = false) -> int:
	if won:
		return unit.alive()
	if unit.broken or (lose_everything and not retreated):
		return 0
	return roundi(unit.alive() * RETREAT_KEEP_FRACTION)


## Soldiers of `side`'s own army (units lent by other clans excluded) that it ends the battle
## without (dead, scattered or lost while retreating).
static func soldiers_lost(record: BattleRecord, side: int, lose_everything: bool = false) -> int:
	var lost := 0
	for unit in record.sides[side].units:
		if unit.ally == null:
			lost += unit_lost(record, side, unit, lose_everything)
	return lost


static func unit_lost(record: BattleRecord, side: int, unit: BattleSide.Unit, lose_everything: bool = false) -> int:
	var won := record.winner == side
	var retreated := record.retreated_side == side
	return unit.start_soldiers - soldiers_kept(unit, won, retreated, lose_everything)


## Soldiers each lending clan on `side` lost: clan_id -> {"sent", "lost"}. Lent units follow the
## normal loss rules, never `lose_everything`: they go home when the battle is lost.
static func ally_losses(record: BattleRecord, side: int) -> Dictionary[StringName, Dictionary]:
	var result: Dictionary[StringName, Dictionary] = {}
	for unit in record.sides[side].units:
		if unit.ally == null:
			continue
		var entry: Dictionary = result.get_or_add(unit.ally.clan_id, {"sent": 0, "lost": 0})
		entry.sent += unit.start_soldiers
		entry.lost += unit_lost(record, side, unit)
	return result


## Applies the result to the kingdom squads that fought on `side` and returns what was lost,
## each as unit_id -> soldiers: {"casualties" (died in battle), "scattered" (broken units, or the
## whole army after a failed attack), "retreat_losses" (half of the units that pulled back)}.
static func apply_to_army(army: Army, record: BattleRecord, side: int, lose_everything: bool = false) -> Dictionary:
	var won := record.winner == side
	var retreated := record.retreated_side == side
	var casualties: Dictionary[StringName, int] = {}
	var scattered: Dictionary[StringName, int] = {}
	var retreat_losses: Dictionary[StringName, int] = {}
	for unit in record.sides[side].units:
		if unit.ally != null:
			continue
		var unit_id := unit.data.unit_id
		if unit.lost() > 0:
			casualties[unit_id] = casualties.get(unit_id, 0) + unit.lost()
		var keep := soldiers_kept(unit, won, retreated, lose_everything)
		var gone := unit.alive() - keep
		if gone > 0:
			var bucket := retreat_losses if keep > 0 else scattered
			bucket[unit_id] = bucket.get(unit_id, 0) + gone
		if unit.squad != null:
			army.set_soldiers(unit.squad, keep)
	return {"casualties": casualties, "scattered": scattered, "retreat_losses": retreat_losses}
