class_name RaidSystem
extends RefCounted
## Random bandit raids (GDD §7.2): chance per turn, bandit army, battle and its consequences.


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
	var size := raid.base_size + floori(turn * raid.size_per_turn)
	var ids: Array[StringName] = []
	var weights := PackedFloat32Array()
	for unit_id in raid.unit_weights:
		ids.append(unit_id)
		weights.append(raid.unit_weights[unit_id])
	var counts := {}
	for i in size:
		var unit_id := ids[rng.rand_weighted(weights)]
		counts[unit_id] = counts.get(unit_id, 0) + 1
	var side := BattleSide.new("Quân cướp")
	for unit_id in enemy_units:  # enemy_units is in sort order
		side.add_group(enemy_units[unit_id], counts.get(unit_id, 0))
	return side


## The kingdom's whole army as a battle side, in unit sort order.
static func create_kingdom_side(state: KingdomState) -> BattleSide:
	var side := BattleSide.new("Vương quốc")
	for unit_id in state.units:
		side.add_group(state.units[unit_id], state.army.get_count(unit_id))
	return side


## Fights the raid and applies the outcome to the kingdom. The bandits attack, the kingdom defends.
## Returns {"record": BattleRecord, "won": bool, "casualties": {unit_id: n}, "fled": {unit_id: n},
##          "resources_lost": amounts, "reward": amounts}.
static func resolve(state: KingdomState, raid: RaidData, bandits: BattleSide, seed_value: int) -> Dictionary:
	var kingdom := create_kingdom_side(state)
	var record := BattleSimulator.run(bandits, kingdom, seed_value)
	var won := record.winner == BattleRecord.DEFENDER
	var casualties: Dictionary[StringName, int] = {}
	for group in kingdom.groups:
		if group.lost() > 0:
			casualties[group.unit.unit_id] = state.army.remove(group.unit.unit_id, group.lost())
	var fled: Dictionary[StringName, int] = {}
	var resources_lost: Dictionary[StringName, int] = {}
	var reward: Dictionary[StringName, int] = {}
	if won:
		for resource_id in raid.reward_per_bandit:
			reward[resource_id] = raid.reward_per_bandit[resource_id] * bandits.start_total()
		state.stockpile.add(reward)
	else:
		for group in kingdom.groups:
			var fleeing := roundi(group.alive() * raid.soldier_loss_on_defeat)
			if fleeing > 0:
				fled[group.unit.unit_id] = state.army.remove(group.unit.unit_id, fleeing)
		for resource_id in state.stockpile.get_all():
			var amount := floori(state.stockpile.get_amount(resource_id) * raid.resource_loss_on_defeat)
			if amount > 0:
				resources_lost[resource_id] = amount
		state.stockpile.spend(resources_lost)
	return {"record": record, "won": won, "casualties": casualties, "fled": fled,
			"resources_lost": resources_lost, "reward": reward}
