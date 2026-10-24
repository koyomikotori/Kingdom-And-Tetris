class_name RaidSystem
extends RefCounted
## Random bandit raids (GDD §7.2): chance per turn, bandit army, battle and its consequences.

## Unbroken squads on the losing side keep this fraction of their soldiers (GDD §7.6).
const RETREAT_KEEP_FRACTION := 0.5


## Chance (0..1) that bandits raid at the start of `state.turn`.
## Watchtowers only help when their upkeep was paid at the end of the previous turn.
static func get_raid_chance(state: KingdomState, raid: RaidData) -> float:
	if state.turn < raid.first_turn:
		return 0.0
	var chance := raid.base_chance
	if state.buildings_supplied:
		for building_id in state.buildings:
			var building := state.buildings[building_id]
			chance -= building.raid_chance_reduction * state.board.count_buildings(building_id)
	return maxf(0.0, chance)


static func create_bandit_side(raid: RaidData, enemy_units: Dictionary[StringName, UnitData],
		turn: int, rng: RandomNumberGenerator) -> BattleSide:
	var squad_count := raid.base_squads + floori(turn * raid.squads_per_turn)
	var ids: Array[StringName] = []
	var weights := PackedFloat32Array()
	for unit_id in raid.unit_weights:
		ids.append(unit_id)
		weights.append(raid.unit_weights[unit_id])
	var picked := {}
	for i in squad_count:
		var unit_id := ids[rng.rand_weighted(weights)]
		picked[unit_id] = picked.get(unit_id, 0) + 1
	var side := BattleSide.new("Quân cướp")
	for unit_id in enemy_units:  # enemy_units is in sort order
		for i in picked.get(unit_id, 0):
			side.add_unit(enemy_units[unit_id], enemy_units[unit_id].squad_size)
	return side


## The kingdom's whole army as a battle side, one battle unit per squad.
static func create_kingdom_side(state: KingdomState) -> BattleSide:
	var side := BattleSide.new("Vương quốc")
	for squad in state.army.squads:
		side.add_unit(state.units[squad.unit_id], squad.soldiers, squad)
	return side


## Fights the raid with nobody retreating. The bandits attack, the kingdom defends.
static func resolve(state: KingdomState, raid: RaidData, bandits: BattleSide, seed_value: int) -> Dictionary:
	var kingdom := create_kingdom_side(state)
	return apply_outcome(state, raid, BattleSimulator.simulate(bandits, kingdom, seed_value))


## Applies a finished raid battle to the kingdom (GDD §7.6):
## - kingdom wins: every squad keeps its survivors; reward per bandit squad;
## - kingdom loses: broken or wiped squads are lost, the others keep 50%; 30% of resources lost.
## Returns {"record", "won", "casualties", "scattered", "retreat_losses" (unit_id -> soldiers each),
##          "resources_lost", "reward"}.
static func apply_outcome(state: KingdomState, raid: RaidData, record: BattleRecord) -> Dictionary:
	var won := record.winner == BattleRecord.DEFENDER
	var casualties: Dictionary[StringName, int] = {}
	var scattered: Dictionary[StringName, int] = {}
	var retreat_losses: Dictionary[StringName, int] = {}
	for unit in record.sides[BattleRecord.DEFENDER].units:
		var unit_id := unit.data.unit_id
		if unit.lost() > 0:
			casualties[unit_id] = casualties.get(unit_id, 0) + unit.lost()
		var keep := unit.alive()
		if not won:
			if unit.broken:
				scattered[unit_id] = scattered.get(unit_id, 0) + keep
				keep = 0
			else:
				var kept := roundi(keep * RETREAT_KEEP_FRACTION)
				if keep - kept > 0:
					retreat_losses[unit_id] = retreat_losses.get(unit_id, 0) + keep - kept
				keep = kept
		if unit.squad != null:
			state.army.set_soldiers(unit.squad, keep)
	var resources_lost: Dictionary[StringName, int] = {}
	var reward: Dictionary[StringName, int] = {}
	if won:
		for resource_id in raid.reward_per_squad:
			reward[resource_id] = raid.reward_per_squad[resource_id] * record.sides[BattleRecord.ATTACKER].units.size()
		state.stockpile.add(reward)
	else:
		for resource_id in state.stockpile.get_all():
			var amount := floori(state.stockpile.get_amount(resource_id) * raid.resource_loss_on_defeat)
			if amount > 0:
				resources_lost[resource_id] = amount
		state.stockpile.spend(resources_lost)
	return {"record": record, "won": won, "casualties": casualties, "scattered": scattered,
			"retreat_losses": retreat_losses, "resources_lost": resources_lost, "reward": reward}
