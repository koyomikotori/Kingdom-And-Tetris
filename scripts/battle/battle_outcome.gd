class_name BattleOutcome
extends RefCounted
## What each battle unit keeps after a battle (GDD §7.6), shared by bandit raids and clan wars:
## - winning side: every survivor stays;
## - losing side: broken units are lost; unbroken units keep 50% (they retreat), unless
##   `lose_everything` (a failed attack on a clan, GDD §9.6) and the player did not retreat.

const RETREAT_KEEP_FRACTION := 0.5


static func soldiers_kept(unit: BattleSide.Unit, won: bool, retreated: bool, lose_everything: bool = false) -> int:
	if won:
		return unit.alive()
	if unit.broken or (lose_everything and not retreated):
		return 0
	return roundi(unit.alive() * RETREAT_KEEP_FRACTION)


## Soldiers `side` ends the battle without (dead, scattered or lost while retreating).
static func soldiers_lost(record: BattleRecord, side: int, lose_everything: bool = false) -> int:
	var won := record.winner == side
	var retreated := record.retreated_side == side
	var lost := 0
	for unit in record.sides[side].units:
		lost += unit.start_soldiers - soldiers_kept(unit, won, retreated, lose_everything)
	return lost


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
