class_name KingdomState
extends RefCounted
## Runtime state of one game: board, piece hand, stockpile, army and turn counter.
## All game actions go through here so the scene script only handles input and display.

signal turn_started(turn: int)

## Squads allowed without any barracks (the castle garrison).
const BASE_SQUAD_CAPACITY := 2
## Each turn, squads below full strength regain this fraction of their full size (rounded up).
const REPLENISH_FRACTION := 0.25

var board: BoardData
var hand: PieceHand
var stockpile := Stockpile.new()
var army := Army.new()
var turn := 1
var terrains: Dictionary[StringName, TerrainData] = {}
var buildings: Dictionary[StringName, BuildingData] = {}
var units: Dictionary[StringName, UnitData] = {}
## Bandit raid tuning; null disables raids.
var raid: RaidData = RaidData.load_bandits()
var enemy_units: Dictionary[StringName, UnitData] = UnitData.load_enemies()
var diplomacy := Diplomacy.new(ClanData.load_all(), ResourceTypeData.load_all())
var wars := Wars.new(diplomacy)
## False when building upkeep could not be paid last turn; building effects pause.
var buildings_supplied := true
var rng := RandomNumberGenerator.new()


func _init(p_board: BoardData, p_hand: PieceHand, p_terrains: Dictionary[StringName, TerrainData],
		p_buildings: Dictionary[StringName, BuildingData] = {}, p_units: Array[UnitData] = [],
		seed_value: int = 0) -> void:
	board = p_board
	hand = p_hand
	terrains = p_terrains
	buildings = p_buildings
	for unit in p_units:
		units[unit.unit_id] = unit
	rng.seed = seed_value


## Deals the first hand. Call once after connecting signals.
func start() -> void:
	hand.deal_new_hand()
	turn_started.emit(turn)


## Places the hand piece at `index`. The piece is used up only when placement succeeds.
func place_piece(index: int, origin: Vector2i) -> PlacementRules.Result:
	var result := PlacementRules.apply(board, hand.pieces[index], origin)
	if result == PlacementRules.Result.OK:
		hand.take(index)
	return result


func build(building_id: StringName, origin: Vector2i) -> BuildRules.Result:
	return BuildRules.apply(board, stockpile, buildings[building_id], origin)


func recruit(unit_id: StringName) -> RecruitmentRules.Result:
	return RecruitmentRules.apply(board, stockpile, army, get_squad_capacity(), units[unit_id])


## Removes a squad for good. Nothing is refunded.
func disband(squad: Army.Squad) -> void:
	army.remove_squad(squad)


## Most squads the kingdom may have: castle garrison plus every building's squad_capacity.
func get_squad_capacity() -> int:
	var capacity := BASE_SQUAD_CAPACITY
	for building_id in buildings:
		capacity += buildings[building_id].squad_capacity * board.count_buildings(building_id)
	return capacity


func can_replenish() -> bool:
	for building_id in buildings:
		if buildings[building_id].enables_replenishment and board.count_buildings(building_id) > 0:
			return true
	return false


func get_turn_yield() -> Dictionary[StringName, int]:
	return Economy.board_yield(board, terrains)


func get_army_upkeep() -> Dictionary[StringName, int]:
	return army.get_upkeep(units)


func get_building_upkeep() -> Dictionary[StringName, int]:
	var total: Dictionary[StringName, int] = {}
	for building_id in buildings:
		for i in board.count_buildings(building_id):
			Economy.add_into(total, buildings[building_id].upkeep)
	return total


func get_upkeep() -> Dictionary[StringName, int]:
	var total := get_army_upkeep()
	Economy.add_into(total, get_building_upkeep())
	return total


## Where each resource's per-turn change comes from: resource_id -> Array of entries
## {"source": &"terrain" | &"army" | &"building" | &"agreement", "id": StringName, "amount": int,
##  "count": int (cells / squads / buildings), "key_count": int (terrain only)}.
## Amounts are signed; they add up to get_net_income().
func get_income_breakdown() -> Dictionary[StringName, Array]:
	var breakdown: Dictionary[StringName, Array] = {}
	var add := func(resource_id: StringName, entry: Dictionary) -> void:
		if entry.amount == 0:
			return
		if not breakdown.has(resource_id):
			breakdown[resource_id] = []
		breakdown[resource_id].append(entry)
	# Terrain: one entry per terrain type and resource.
	var by_terrain := {}  # terrain_id -> {"cells", "key_count", "yield": amounts}
	for cell in board.get_all_cells():
		if not cell.owned or not terrains.has(cell.terrain_id):
			continue
		var cell_yield := Economy.cell_yield(terrains[cell.terrain_id], cell.is_key)
		if cell_yield.is_empty():
			continue
		if not by_terrain.has(cell.terrain_id):
			var empty: Dictionary[StringName, int] = {}
			by_terrain[cell.terrain_id] = {"cells": 0, "key_count": 0, "yield": empty}
		var info: Dictionary = by_terrain[cell.terrain_id]
		info.cells += 1
		info.key_count += 1 if cell.is_key else 0
		Economy.add_into(info.yield, cell_yield)
	for terrain_id in by_terrain:
		var info: Dictionary = by_terrain[terrain_id]
		for resource_id in info.yield:
			add.call(resource_id, {"source": &"terrain", "id": terrain_id, "amount": info.yield[resource_id],
					"count": info.cells, "key_count": info.key_count})
	# Army upkeep, all squads together.
	var army_upkeep := get_army_upkeep()
	for resource_id in army_upkeep:
		add.call(resource_id, {"source": &"army", "id": &"", "amount": -army_upkeep[resource_id],
				"count": army.count_squads()})
	# Building upkeep, per building type.
	for building_id in buildings:
		var count := board.count_buildings(building_id)
		for resource_id in buildings[building_id].upkeep:
			add.call(resource_id, {"source": &"building", "id": building_id,
					"amount": -buildings[building_id].upkeep[resource_id] * count, "count": count})
	# Trade agreements.
	for agreement in diplomacy.agreements:
		add.call(agreement.give_id, {"source": &"agreement", "id": agreement.clan_id, "amount": -agreement.give_amount, "count": 1})
		add.call(agreement.get_id, {"source": &"agreement", "id": agreement.clan_id, "amount": agreement.get_amount, "count": 1})
	return breakdown


## How the stockpile changes at the end of this turn: yield, upkeep and trade agreements
## (assuming upkeep and deliveries can be paid).
func get_net_income() -> Dictionary[StringName, int]:
	var net: Dictionary[StringName, int] = {}
	var breakdown := get_income_breakdown()
	for resource_id in breakdown:
		for entry: Dictionary in breakdown[resource_id]:
			net[resource_id] = net.get(resource_id, 0) + entry.amount
	return net


## Ends the turn:
## 1. collect yield;
## 2. pay army upkeep; squads desert (most recently recruited first) until it can be paid;
## 3. pay building upkeep if possible, otherwise building effects pause next turn;
## 4. trade agreements exchange goods (Diplomacy.run_agreements);
##    squads below full strength regain soldiers for free (needs a barracks); clan relations drift;
## 5. advance the turn and deal a fresh hand (unplaced pieces are discarded);
## 6. bandits may raid at the start of the new turn.
## Returns {"collected", "upkeep", "deserted", "buildings_supplied", "replenished", "agreements"} plus
## "war_declared" (clan ids that declared war this turn) and, at most one battle per turn:
## "pending_invasion" ({"clan_id", "simulator"}, finish with finish_invasion()) or
## "pending_raid" (a BattleSimulator, not yet run) when bandits attack. Play it (battle screen or
## BattleSimulator.step()) and then call finish_raid() with its record.
func end_turn() -> Dictionary:
	var collected := get_turn_yield()
	stockpile.add(collected)
	var deserted: Dictionary[StringName, int] = {}  # unit_id -> soldiers
	while army.count_squads() > 0 and not stockpile.can_afford(get_army_upkeep()):
		var squad: Army.Squad = army.squads.back()
		deserted[squad.unit_id] = deserted.get(squad.unit_id, 0) + squad.soldiers
		army.remove_squad(squad)
	var upkeep := get_army_upkeep()
	stockpile.spend(upkeep)
	var building_upkeep := get_building_upkeep()
	buildings_supplied = stockpile.spend(building_upkeep)
	if buildings_supplied:
		Economy.add_into(upkeep, building_upkeep)
	var agreements := diplomacy.run_agreements(stockpile)
	var replenished := _replenish()
	diplomacy.threat = get_threat()
	diplomacy.end_turn()
	var declared := wars.end_turn(rng)
	turn += 1
	hand.deal_new_hand()
	var report := {"collected": collected, "upkeep": upkeep, "deserted": deserted,
			"buildings_supplied": buildings_supplied, "replenished": replenished, "agreements": agreements}
	report["war_declared"] = declared
	var invader := wars.pick_invader(rng)
	if invader != &"":
		var invaders := wars.create_clan_side(invader, wars.invasion_size(invader), units)
		report["pending_invasion"] = {"clan_id": invader,
				"simulator": BattleSimulator.new(invaders, RaidSystem.create_kingdom_side(self), rng.randi())}
	elif raid != null and rng.randf() < RaidSystem.get_raid_chance(self, raid):
		var bandits := RaidSystem.create_bandit_side(raid, enemy_units, turn, rng)
		report["pending_raid"] = BattleSimulator.new(bandits, RaidSystem.create_kingdom_side(self), rng.randi())
	turn_started.emit(turn)
	return report


## Applies a finished raid battle (see end_turn) to the kingdom. Returns RaidSystem.apply_outcome's report.
func finish_raid(record: BattleRecord) -> Dictionary:
	return RaidSystem.apply_outcome(self, raid, record)


## Returns unit_id -> soldiers added.
func _replenish() -> Dictionary[StringName, int]:
	var added: Dictionary[StringName, int] = {}
	if not can_replenish():
		return added
	for squad in army.squads.duplicate():
		var full := units[squad.unit_id].squad_size
		var gain := mini(ceili(full * REPLENISH_FRACTION), full - squad.soldiers)
		if gain > 0:
			army.set_soldiers(squad, squad.soldiers + gain)
			added[squad.unit_id] = added.get(squad.unit_id, 0) + gain
	return added


# --- War (GDD §9.6) -----------------------------------------------------------------------

## Starting territory: cells beyond this count make the clans wary.
const START_TERRITORY := 16
const THREAT_CELLS_PER_POINT := 4
const THREAT_PER_ANNEXED_CLAN := 15
const THREAT_SOLDIERS_PER_POINT := 20


## How threatening the kingdom looks to the clans (GDD §9.3): territory beyond the start,
## annexed clans and army size. Lowers every clan's relation target (Diplomacy.target_relation).
func get_threat() -> int:
	var annexed := 0
	for front in wars.fronts.values():
		if front.annexed:
			annexed += 1
	return maxi(0, board.count_owned_cells() - START_TERRITORY) / THREAT_CELLS_PER_POINT \
			+ annexed * THREAT_PER_ANNEXED_CLAN + army.count_soldiers() / THREAT_SOLDIERS_PER_POINT

## Applies a finished invasion battle: the kingdom defended. Losing costs squads (§7.6), up to
## Wars.LAND_LOST_PER_DEFEAT cells on the clan's edge and Wars.INVASION_RESOURCE_LOSS of every
## resource. The clan loses the soldiers it lost.
## Returns {"record", "won", "clan_id", "casualties", "scattered", "retreat_losses",
##          "lost_cells": Array[Vector2i], "resources_lost", "enemy_lost": int}.
func finish_invasion(clan_id: StringName, record: BattleRecord) -> Dictionary:
	var won := record.winner == BattleRecord.DEFENDER
	var result := BattleOutcome.apply_to_army(army, record, BattleRecord.DEFENDER)
	var enemy_lost := BattleOutcome.soldiers_lost(record, BattleRecord.ATTACKER)
	wars.lose_soldiers(clan_id, enemy_lost)
	var lost_cells: Array[Vector2i] = []
	var resources_lost: Dictionary[StringName, int] = {}
	if not won:
		var edge := ClanData.direction_vector(wars.fronts[clan_id].direction)
		lost_cells = board.lose_edge_cells(edge, Wars.LAND_LOST_PER_DEFEAT)
		for resource_id in stockpile.get_all():
			var amount := floori(stockpile.get_amount(resource_id) * Wars.INVASION_RESOURCE_LOSS)
			if amount > 0:
				resources_lost[resource_id] = amount
		stockpile.spend(resources_lost)
	result.merge({"record": record, "won": won, "clan_id": clan_id, "lost_cells": lost_cells,
			"resources_lost": resources_lost, "enemy_lost": enemy_lost})
	return result


## Starts the player's attack on a clan at war: the whole army against the clan's whole army.
## Returns null (and changes nothing) unless Wars.check_attack() is OK.
func start_attack(clan_id: StringName) -> BattleSimulator:
	if wars.check_attack(clan_id, army.count_squads() > 0) != Wars.AttackResult.OK:
		return null
	wars.mark_attacked(clan_id)
	var defenders := wars.create_clan_side(clan_id, wars.fronts[clan_id].strength, units)
	return BattleSimulator.new(RaidSystem.create_kingdom_side(self), defenders, rng.randi())


## Applies a finished attack. Winning loots resources and may make the clan surrender: it is
## annexed and the board grows toward it. Losing costs the whole army (half of the unbroken
## squads if the player retreated) and a compensation of every resource.
## Returns {"record", "won", "clan_id", "casualties", "scattered", "retreat_losses", "enemy_lost",
##          "loot", "compensation", "annexed": bool}.
func finish_attack(clan_id: StringName, record: BattleRecord) -> Dictionary:
	var won := record.winner == BattleRecord.ATTACKER
	var result := BattleOutcome.apply_to_army(army, record, BattleRecord.ATTACKER, true)
	var enemy_lost := BattleOutcome.soldiers_lost(record, BattleRecord.DEFENDER)
	wars.lose_soldiers(clan_id, enemy_lost)
	var loot: Dictionary[StringName, int] = {}
	var compensation: Dictionary[StringName, int] = {}
	var annexed := false
	if won:
		for resource_id in Wars.LOOT_PER_SOLDIER:
			loot[resource_id] = Wars.LOOT_PER_SOLDIER[resource_id] * enemy_lost
		stockpile.add(loot)
		if wars.should_annex(clan_id):
			board.expand(wars.annex(clan_id), Wars.ANNEX_EXPANSION)
			annexed = true
	else:
		for resource_id in stockpile.get_all():
			var amount := floori(stockpile.get_amount(resource_id) * Wars.ATTACK_DEFEAT_COMPENSATION)
			if amount > 0:
				compensation[resource_id] = amount
		stockpile.spend(compensation)
	result.merge({"record": record, "won": won, "clan_id": clan_id, "enemy_lost": enemy_lost,
			"loot": loot, "compensation": compensation, "annexed": annexed})
	return result
