class_name KingdomState
extends RefCounted
## Runtime state of one game: board, piece hand, stockpile, army and turn counter.
## All game actions go through here so the scene script only handles input and display.

signal turn_started(turn: int)
signal castle_changed

## The player's main color: the kingdom's soldiers wear it in battle. Later the player picks it
## (with a commander and a banner) when starting a new game (GDD §13).
const PLAYER_COLOR := Color(0.27, 0.45, 0.82)
## Squads allowed without any barracks (the castle garrison).
const BASE_SQUAD_CAPACITY := 2
## What a new game starts with (GDD §8, economy v2): land no longer yields, so the first
## buildings are paid from this.
const STARTING_RESOURCES: Dictionary[StringName, int] = {&"food": 80, &"wood": 80, &"stone": 80, &"ore": 10,
		&"hardwood": 10, &"horses": 10}
## Each turn, squads below full strength regain this fraction of their full size (rounded up);
## the new soldiers dilute the squad's XP (Army.add_soldiers).
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
var alliances := Alliances.new(diplomacy, wars)
var victory := Victory.new()
var events := EventSystem.new()
var generals := Generals.new()
var advisors := Advisors.new()
var equipment := Equipment.new()
## Counters for the end-of-game screen: {"battles_won", "battles_lost"}.
var stats := {"battles_won": 0, "battles_lost": 0}
## False when building upkeep could not be paid last turn; building effects pause.
var buildings_supplied := true
## Castle level, 1..castle_levels.size() (GDD §8, M11c).
var castle_level := 1
## Turns left on the castle's upgrade to castle_level + 1 (GDD §8, M12d); 0 = none.
var castle_turns := 0
## Tests and previews: building and upgrading finish at once instead of taking turns.
static var instant_construction := false
var castle_levels: Array[CastleLevelData] = CastleLevelData.load_all()
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
	generals.rng.seed = seed_value + 1
	advisors.rng.seed = seed_value + 2
	equipment.rng.seed = seed_value + 3
	generals.advisors = advisors
	advisors.changed.connect(_sync_advisors)
	equipment.changed.connect(_sync_advisors)


## The diplomacy advisor's skill lives in Diplomacy (its rules use it); keep it current.
func _sync_advisors() -> void:
	diplomacy.envoy = advisors.post_stat(&"diplomacy")
	diplomacy.gift_bonus = advisors.post_effect(&"diplomacy", &"relation_gain")


## A new game's stockpile (KingdomState.STARTING_RESOURCES). The kingdom scene calls it for new
## games only; tests start from an empty stockpile.
func give_starting_resources() -> void:
	stockpile.add(STARTING_RESOURCES)


## Deals the first hand. Call once after connecting signals.
func start() -> void:
	generals.refresh_candidates(castle_level, turn)
	hand.deal_new_hand()
	turn_started.emit(turn)


## Continues a loaded game (load_save) mid-turn: keeps its hand. Call once after connecting signals.
func resume() -> void:
	hand.changed.emit()
	turn_started.emit(turn)


# --- Save (GDD §10.1) ---------------------------------------------------------------------

func _record_battle(won: bool) -> void:
	stats["battles_won" if won else "battles_lost"] += 1


## The whole game as JSON-safe data. The board is restored separately (BoardData.from_save),
## because the state is built around it.
func to_save() -> Dictionary:
	return {"turn": turn, "buildings_supplied": buildings_supplied, "castle_level": castle_level,
			"castle_turns": castle_turns, "board": board.to_save(),
			"hand": hand.to_save(), "stockpile": stockpile.to_save(), "army": army.to_save(),
			"diplomacy": diplomacy.to_save(), "wars": wars.to_save(), "victory": victory.to_save(), "stats": stats.duplicate(),
			"events": events.to_save(), "generals": generals.to_save(), "advisors": advisors.to_save(),
			"equipment": equipment.to_save()}


## Restores everything but the board from to_save() data. Random rolls are not saved: they come
## out differently after loading (GDD §10.1).
func load_save(data: Dictionary) -> void:
	turn = int(data.turn)
	buildings_supplied = bool(data.buildings_supplied)
	# Saves from before M11c have no castle level.
	castle_level = clampi(int(data.get("castle_level", 1)), 1, castle_levels.size())
	castle_turns = int(data.get("castle_turns", 0)) if castle_level < castle_levels.size() else 0
	hand.load_save(data.hand)
	stockpile.load_save(data.stockpile)
	army.load_save(data.army, units)
	diplomacy.load_save(data.diplomacy)
	wars.load_save(data.wars)
	# Saves from before M11a have no victory state or stats.
	if data.has("victory"):
		victory.load_save(data.victory)
	for key in stats:
		stats[key] = int(data.get("stats", {}).get(key, 0))
	if data.has("events"):
		events.load_save(data.events)
	# Saves from before M11d have no generals; a new candidate list is made.
	if data.has("generals"):
		generals.load_save(data.generals)
	else:
		generals.refresh_candidates(castle_level, turn)
	# Saves from before M11f have no advisors.
	advisors.load_save(data.get("advisors", []))
	# Saves from before M12e have no items.
	equipment.load_save(data.get("equipment", {}))


## What a save slot shows: {"turn", "cells", "soldiers"}.
func save_summary() -> Dictionary:
	return {"turn": turn, "cells": board.count_owned_cells(), "soldiers": army.count_soldiers()}


## Places the hand piece at `index`. The piece is used up only when placement succeeds.
func place_piece(index: int, origin: Vector2i) -> PlacementRules.Result:
	var result := PlacementRules.apply(board, hand.pieces[index], origin)
	if result == PlacementRules.Result.OK:
		hand.take(index)
	return result


## Lays the foundation; the building is finished after its build_turns (GDD §8, M12d).
func build(building_id: StringName, origin: Vector2i) -> BuildRules.Result:
	var building := buildings[building_id]
	var result := BuildRules.apply(board, stockpile, building, origin, castle_level, building_cost(building),
			has_free_builder())
	if result == BuildRules.Result.OK and instant_construction:
		finish_construction(origin)
	return result


# --- Equipment (GDD §8 "Trang bị", M12e) --------------------------------------------------

const FORGE_ID: StringName = &"forge"


## The working forge's level (finished, not being upgraded), 0 without one.
func forge_level() -> int:
	for cell in board.get_all_cells():
		if cell.building_id == FORGE_ID and cell.coord == cell.building_origin and not cell.is_constructing():
			return cell.building_level
	return 0


func start_forge(kind: StringName, slot: StringName) -> Equipment.Result:
	return equipment.start_forge(stockpile, forge_level(), kind, slot)


## Dismisses an officer; their items go back to storage (a general killed in battle loses them).
func dismiss_officer(officer: Officer) -> void:
	equipment.take_back(officer)
	if officer is General:
		generals.dismiss(officer)
	else:
		advisors.dismiss(officer)


# --- Construction (GDD §8, M12d) ----------------------------------------------------------

## Builder teams: how many buildings (the castle included) may be built or upgraded at once.
func builder_limit() -> int:
	return 1 + castle_level


func builders_busy() -> int:
	return board.get_construction_origins().size() + (1 if castle_turns > 0 else 0)


func has_free_builder() -> bool:
	return builders_busy() < builder_limit()


## Finishes the construction at `origin` now (instant_construction; an upgrade gains its level).
func finish_construction(origin: Vector2i) -> void:
	var cell := board.get_cell(origin)
	if cell == null or not cell.is_constructing():
		return
	if cell.building_upgrading:
		board.set_building_level(origin, cell.building_level + 1)
	board.set_construction(origin, 0)


## One turn of work on every construction; finished ones start working. Returns what was finished:
## [{"name": String, "level": int, "upgrade": bool}].
func _advance_construction() -> Array[Dictionary]:
	var finished: Array[Dictionary] = []
	for origin in board.get_construction_origins():
		var cell := board.get_cell(origin)
		var turns_left := cell.building_turns - 1
		var upgrading := cell.building_upgrading
		board.set_construction(origin, turns_left, upgrading)
		if turns_left > 0:
			continue
		if upgrading:
			board.set_building_level(origin, cell.building_level + 1)
		var data: BuildingData = buildings.get(cell.building_id)
		finished.append({"name": data.display_name if data != null else String(cell.building_id),
				"level": cell.building_level, "upgrade": upgrading})
	if castle_turns > 0:
		castle_turns -= 1
		if castle_turns == 0:
			castle_level += 1
			finished.append({"name": "Thành chính", "level": castle_level, "upgrade": true})
			castle_changed.emit()
	return finished


## What a building costs right now: its cost less the Nội chính discount (Advisors.discounted).
func building_cost(building: BuildingData) -> Dictionary[StringName, int]:
	return advisors.discounted(building.cost)


## Share of the building cost given back when a building is demolished.
const DEMOLISH_REFUND := 0.5


## What demolishing a building of this type gives back (half its cost, rounded down).
func demolish_refund(building_id: StringName) -> Dictionary[StringName, int]:
	var refund: Dictionary[StringName, int] = {}
	var building: BuildingData = buildings.get(building_id)
	if building != null:
		for resource_id in building.cost:
			var amount := floori(building.cost[resource_id] * DEMOLISH_REFUND)
			if amount > 0:
				refund[resource_id] = amount
	return refund


## Removes the building whose origin is `origin` (finished, or still a foundation) and refunds
## half its cost. The castle cannot be demolished; an upgrade is called off with cancel_upgrade().
## Returns the refund ({} when nothing was demolished).
func demolish(origin: Vector2i) -> Dictionary[StringName, int]:
	var cell := board.get_cell(origin)
	if cell == null or not cell.has_building() or cell.building_id == BoardData.CASTLE_ID or cell.building_origin != origin:
		return {}
	if cell.building_upgrading:
		return cancel_upgrade(origin)
	if cell.building_id == FORGE_ID:
		equipment.cancel_forge()
	var refund := demolish_refund(cell.building_id)
	board.remove_building(origin)
	stockpile.add(refund)
	return refund


## Moves the building whose origin is `from_origin` for free. Nothing changes unless
## BuildRules.check_move() is OK; the castle and buildings under construction never move.
func move_building(from_origin: Vector2i, to_origin: Vector2i) -> BuildRules.Result:
	var cell := board.get_cell(from_origin)
	if cell == null or not buildings.has(cell.building_id) or cell.building_origin != from_origin:
		return BuildRules.Result.OCCUPIED
	if cell.is_constructing():
		return BuildRules.Result.UNDER_CONSTRUCTION
	var building := buildings[cell.building_id]
	var result := BuildRules.check_move(board, building, from_origin, to_origin)
	if result == BuildRules.Result.OK:
		var level := board.get_building_level(from_origin)
		board.remove_building(from_origin)
		board.place_building(building.building_id, to_origin, building.size)
		board.set_building_level(to_origin, level)
	return result


# --- Building levels (GDD §8, economy v2) -------------------------------------------------

enum UpgradeResult { OK, NOT_UPGRADABLE, MAX_LEVEL, CASTLE_TOO_LOW, CANNOT_AFFORD, NO_BUILDERS, UNDER_CONSTRUCTION,
		FORGING }


## What raising the building at `origin` one level costs right now (Nội chính discount included).
func building_upgrade_cost(origin: Vector2i) -> Dictionary[StringName, int]:
	var cell := board.get_cell(origin)
	var none: Dictionary[StringName, int] = {}
	if cell == null or not buildings.has(cell.building_id):
		return none
	return advisors.discounted(buildings[cell.building_id].upgrade_cost(cell.building_level + 1))


## A building's level never goes above the castle's.
func check_building_upgrade(origin: Vector2i) -> UpgradeResult:
	var cell := board.get_cell(origin)
	if cell == null or not buildings.has(cell.building_id) or cell.building_origin != origin \
			or not buildings[cell.building_id].is_upgradable():
		return UpgradeResult.NOT_UPGRADABLE
	if cell.building_level >= buildings[cell.building_id].max_level():
		return UpgradeResult.MAX_LEVEL
	if cell.is_constructing():
		return UpgradeResult.UNDER_CONSTRUCTION
	if cell.building_id == FORGE_ID and not equipment.forge_job.is_empty():
		return UpgradeResult.FORGING
	if cell.building_level + buildings[cell.building_id].castle_level_gap >= castle_level:
		return UpgradeResult.CASTLE_TOO_LOW
	if not has_free_builder():
		return UpgradeResult.NO_BUILDERS
	if not stockpile.can_afford(building_upgrade_cost(origin)):
		return UpgradeResult.CANNOT_AFFORD
	return UpgradeResult.OK


## Turns the next upgrade of the building at `origin` takes.
func building_upgrade_turns(origin: Vector2i) -> int:
	return BuildingData.upgrade_turns(board.get_building_level(origin) + 1)


## Pays and starts the upgrade; the building stops working and reaches the next level after
## building_upgrade_turns(). Nothing changes unless check_building_upgrade() is OK.
func upgrade_building(origin: Vector2i) -> UpgradeResult:
	var result := check_building_upgrade(origin)
	if result == UpgradeResult.OK:
		# Construction first: paying emits stockpile.changed, and the income shown must already
		# leave the building out.
		var cost := building_upgrade_cost(origin)
		board.set_construction(origin, building_upgrade_turns(origin), true)
		if instant_construction:
			finish_construction(origin)
		stockpile.spend(cost)
	return result


## Calls off the upgrade of the building at `origin`: it keeps its level and half the upgrade's
## cost comes back. Returns the refund ({} when there was no upgrade).
func cancel_upgrade(origin: Vector2i) -> Dictionary[StringName, int]:
	var cell := board.get_cell(origin)
	var refund: Dictionary[StringName, int] = {}
	if cell == null or not cell.building_upgrading or not buildings.has(cell.building_id):
		return refund
	refund = half_refund(buildings[cell.building_id].upgrade_cost(cell.building_level + 1))
	board.set_construction(origin, 0)
	stockpile.add(refund)
	return refund


## Half of `amounts` (DEMOLISH_REFUND), rounded down, without the zeros.
func half_refund(amounts: Dictionary[StringName, int]) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for resource_id in amounts:
		var amount := floori(amounts[resource_id] * DEMOLISH_REFUND)
		if amount > 0:
			result[resource_id] = amount
	return result


func recruit(unit_id: StringName) -> RecruitmentRules.Result:
	return RecruitmentRules.apply(board, stockpile, army, get_squad_capacity(), units[unit_id])


## Removes a squad for good. Nothing is refunded.
func disband(squad: Army.Squad) -> void:
	army.remove_squad(squad)


## Most squads the kingdom may have: castle garrison, every castle level reached and every
## building's squad_capacity.
func get_squad_capacity() -> int:
	var capacity := BASE_SQUAD_CAPACITY
	for level in castle_levels:
		if level.level <= castle_level:
			capacity += level.squad_capacity
	for building_id in buildings:
		capacity += buildings[building_id].squad_capacity * board.count_buildings(building_id)
	return capacity


# --- Castle (GDD §8, M11c) ----------------------------------------------------------------

enum CastleResult { OK, MAX_LEVEL, CANNOT_AFFORD, NO_BUILDERS, IN_PROGRESS }


## The level the castle would reach next, or null at the top.
func next_castle_level() -> CastleLevelData:
	for level in castle_levels:
		if level.level == castle_level + 1:
			return level
	return null


## The next castle level's cost less the Nội chính discount; empty at the top level.
func castle_upgrade_cost() -> Dictionary[StringName, int]:
	var next := next_castle_level()
	var none: Dictionary[StringName, int] = {}
	return advisors.discounted(next.cost) if next != null else none


func check_castle_upgrade() -> CastleResult:
	var next := next_castle_level()
	if next == null:
		return CastleResult.MAX_LEVEL
	if castle_turns > 0:
		return CastleResult.IN_PROGRESS
	if not has_free_builder():
		return CastleResult.NO_BUILDERS
	if not stockpile.can_afford(castle_upgrade_cost()):
		return CastleResult.CANNOT_AFFORD
	return CastleResult.OK


## Turns the castle's next upgrade takes: the new level + 1.
func castle_upgrade_turns() -> int:
	return castle_level + 2


## Pays and starts the castle's upgrade; it keeps the current level's limits until it is finished
## (castle_upgrade_turns() later) and Chiêu hiền is closed meanwhile. Nothing changes unless
## check_castle_upgrade() is OK.
func upgrade_castle() -> CastleResult:
	var result := check_castle_upgrade()
	if result == CastleResult.OK:
		var cost := castle_upgrade_cost()
		castle_turns = castle_upgrade_turns()
		if instant_construction:
			castle_turns = 0
			castle_level += 1
		stockpile.spend(cost)
		castle_changed.emit()
	return result


## Calls off the castle's upgrade and gives half its cost back. Returns the refund.
func cancel_castle_upgrade() -> Dictionary[StringName, int]:
	var refund: Dictionary[StringName, int] = {}
	var next := next_castle_level()
	if castle_turns <= 0 or next == null:
		return refund
	refund = half_refund(next.cost)
	castle_turns = 0
	stockpile.add(refund)
	castle_changed.emit()
	return refund


func can_replenish() -> bool:
	for building_id in buildings:
		if buildings[building_id].enables_replenishment and board.count_buildings(building_id) > 0:
			return true
	return false


## Land plus production buildings (only while their upkeep was paid last turn), plus the
## Nội chính advisor's share of both (advisor_yield_bonus).
func get_turn_yield() -> Dictionary[StringName, int]:
	var total := Economy.board_yield(board, terrains)
	if buildings_supplied:
		Economy.add_into(total, Economy.buildings_yield(board, buildings))
	Economy.add_into(total, advisor_yield_bonus())
	return total


## Nội chính: a share of what production buildings make (economy v2: the land yields nothing).
func advisor_yield_bonus() -> Dictionary[StringName, int]:
	var bonus: Dictionary[StringName, int] = {}
	if buildings_supplied:
		bonus = Advisors.share_of(Economy.buildings_yield(board, buildings),
				advisors.post_stat(&"admin") * Advisors.ADMIN_YIELD + advisors.post_effect(&"admin", &"admin_yield"))
	return bonus


## Squads, generals and advisors together (paid before anything else at the end of a turn), less
## the Nội chính advisor's share of the squads' and generals' part (upkeep_discount).
func get_army_upkeep() -> Dictionary[StringName, int]:
	var total := army.get_upkeep(units)
	Economy.add_into(total, generals.get_upkeep())
	var saved := upkeep_discount()
	for resource_id in saved:
		total[resource_id] -= saved[resource_id]
	Economy.add_into(total, advisors.get_upkeep())
	return total


## What the Nội chính advisor saves on squad and general upkeep.
func upkeep_discount() -> Dictionary[StringName, int]:
	var base := army.get_upkeep(units)
	Economy.add_into(base, generals.get_upkeep())
	return Advisors.share_of(base, advisors.post_stat(&"admin") * Advisors.ADMIN_UPKEEP
			+ advisors.post_effect(&"admin", &"upkeep_cut"))


## Every building's upkeep at its level (BuildingData.upkeep_at).
func get_building_upkeep() -> Dictionary[StringName, int]:
	var total: Dictionary[StringName, int] = {}
	for building_id in buildings:
		Economy.add_into(total, building_type_upkeep(building_id))
	return total


## Upkeep of every finished building of this type, at its level (buildings under construction pay none).
func building_type_upkeep(building_id: StringName) -> Dictionary[StringName, int]:
	var total: Dictionary[StringName, int] = {}
	for cell in board.get_all_cells():
		if cell.building_id == building_id and cell.coord == cell.building_origin and not cell.is_constructing():
			Economy.add_into(total, buildings[building_id].upkeep_at(cell.building_level))
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
	# Army upkeep, all squads together, then the generals.
	var army_upkeep := army.get_upkeep(units)
	for resource_id in army_upkeep:
		add.call(resource_id, {"source": &"army", "id": &"", "amount": -army_upkeep[resource_id],
				"count": army.count_squads()})
	var general_upkeep := generals.get_upkeep()
	for resource_id in general_upkeep:
		add.call(resource_id, {"source": &"generals", "id": &"", "amount": -general_upkeep[resource_id],
				"count": generals.generals.size()})
	var advisor_upkeep := advisors.get_upkeep()
	for resource_id in advisor_upkeep:
		add.call(resource_id, {"source": &"advisors", "id": &"", "amount": -advisor_upkeep[resource_id],
				"count": advisors.advisors.size()})
	# The Nội chính advisor: upkeep saved and extra yield.
	var saved := upkeep_discount()
	for resource_id in saved:
		add.call(resource_id, {"source": &"admin_upkeep", "id": &"", "amount": saved[resource_id], "count": 1})
	var extra := advisor_yield_bonus()
	for resource_id in extra:
		add.call(resource_id, {"source": &"admin_yield", "id": &"", "amount": extra[resource_id], "count": 1})
	# Production buildings, per building type (paused while their upkeep is unpaid).
	if buildings_supplied:
		var produced := {}  # building_id -> amounts
		for cell in board.get_all_cells():
			if cell.has_building() and cell.coord == cell.building_origin and buildings.has(cell.building_id) \
					and not cell.is_constructing():
				var amounts: Dictionary[StringName, int] = produced.get_or_add(cell.building_id, {} as Dictionary[StringName, int])
				Economy.add_into(amounts, Economy.building_yield(buildings[cell.building_id], cell.is_key, cell.building_level))
		for building_id in produced:
			for resource_id in produced[building_id]:
				add.call(resource_id, {"source": &"production", "id": building_id,
						"amount": produced[building_id][resource_id], "count": board.count_buildings(building_id)})
	# Building upkeep, per building type.
	for building_id in buildings:
		var count := board.count_buildings(building_id)
		var type_upkeep := building_type_upkeep(building_id)
		for resource_id in type_upkeep:
			add.call(resource_id, {"source": &"building", "id": building_id,
					"amount": -type_upkeep[resource_id], "count": count})
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
##    squads below full strength regain soldiers for free and squads train up to Veteran (both
##    need a barracks); clan relations drift;
## 5. advance the turn and deal a fresh hand (unplaced pieces are discarded);
## 6. bandits may raid at the start of the new turn.
## 4b. every construction gets one turn closer; finished buildings work from the next turn;
## Returns {"collected", "upkeep", "deserted", "buildings_supplied", "replenished", "agreements",
## "completed" (_advance_construction), "forged" (an Item or null)} plus
## "treaties" (Alliances.end_turn events), "war_declared" (clan ids that declared war this turn),
## "victory" (Victory.Path won this turn, or Victory.NO_PATH), "castle_in_danger", "events" (new
## EventSystem.pending entries, answered through `events`) and,
## at most one battle per turn (the kingdom's allies already on its side):
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
	var completed := _advance_construction()
	# An invasion may have taken the forge.
	if board.count_buildings(FORGE_ID, true) == 0:
		equipment.cancel_forge()
	var forged := equipment.advance_forge()
	var replenished := _replenish()
	if can_replenish():
		army.train()
	diplomacy.threat = get_threat()
	diplomacy.end_turn()
	var treaties := alliances.end_turn()
	var declared := wars.end_turn(rng)
	turn += 1
	var healed := generals.end_turn(castle_level, turn)
	var advisors_healed := advisors.end_turn()
	hand.deal_new_hand()
	var report := {"collected": collected, "upkeep": upkeep, "deserted": deserted,
			"buildings_supplied": buildings_supplied, "replenished": replenished, "agreements": agreements}
	report["completed"] = completed
	report["forged"] = forged
	report["treaties"] = treaties
	report["war_declared"] = declared
	report["generals_healed"] = healed
	report["advisors_healed"] = advisors_healed
	report["victory"] = victory.end_turn(self)
	report["castle_in_danger"] = victory.castle_in_danger(self)
	var invader := wars.pick_invader(rng)
	if invader != &"":
		var invaders := wars.create_clan_side(invader, wars.invasion_size(invader), units)
		report["pending_invasion"] = {"clan_id": invader,
				"simulator": BattleSimulator.new(invaders, create_kingdom_side(invader), rng.randi())}
	elif raid != null and rng.randf() < RaidSystem.get_raid_chance(self, raid):
		var bandits := RaidSystem.create_bandit_side(raid, enemy_units, turn, rng)
		report["pending_raid"] = BattleSimulator.new(bandits, create_kingdom_side(&""), rng.randi())
	# Rolled last so the invasion and raid rolls above stay as they were.
	var no_events: Array[Dictionary] = []
	report["events"] = events.roll(self, rng) if not victory.lost else no_events
	turn_started.emit(turn)
	return report


## The kingdom's army led by its commander (with their bodyguard), plus the soldiers its allies
## send against `enemy_clan` (&"" for bandits). `defending`: a raid or invasion, not an attack.
func create_kingdom_side(enemy_clan: StringName, defending: bool = true) -> BattleSide:
	var side := RaidSystem.create_kingdom_side(self)
	generals.lead(side, board, defending)
	advisors.assist(side)
	alliances.add_allies(side, enemy_clan, units)
	return side


## Applies a finished raid battle (see end_turn) to the kingdom. Returns RaidSystem.apply_outcome's
## report plus "allies" / "helpers" (Alliances.apply_battle) and "general" (Generals.after_battle).
func finish_raid(record: BattleRecord) -> Dictionary:
	var result := RaidSystem.apply_outcome(self, raid, record)
	_record_battle(result.won)
	result["general"] = generals.after_battle(record, BattleRecord.DEFENDER)
	result["advisor"] = advisors.after_battle(record, BattleRecord.DEFENDER)
	if result.won:
		events.raid_won_turn = turn
	result.merge(alliances.apply_battle(record, BattleRecord.DEFENDER))
	result["item"] = equipment.roll_loot(false, stockpile) if result.won else {}
	return result


## Returns unit_id -> soldiers added.
func _replenish() -> Dictionary[StringName, int]:
	var added: Dictionary[StringName, int] = {}
	if not can_replenish():
		return added
	for squad in army.squads.duplicate():
		var full := units[squad.unit_id].squad_size
		var gain := mini(ceili(full * REPLENISH_FRACTION), full - squad.soldiers)
		if gain > 0:
			army.add_soldiers(squad, gain)
			added[squad.unit_id] = added.get(squad.unit_id, 0) + gain
	return added


# --- War (GDD §9.6) -----------------------------------------------------------------------

## Starting territory: cells beyond this count make the clans wary.
const START_TERRITORY := 16
const THREAT_CELLS_PER_POINT := 4
const THREAT_PER_ANNEXED_CLAN := 15
const THREAT_SOLDIERS_PER_POINT := 20


## How threatening the kingdom looks to the clans (GDD §9.3): territory beyond the start,
## annexed clans and army size. Every clan's wariness grows toward it (Diplomacy.wariness_target).
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
## Losing with no land left outside the castle makes the castle fall: the game is lost (GDD §9b).
## Returns {"record", "won", "clan_id", "casualties", "scattered", "retreat_losses",
##          "lost_cells": Array[Vector2i], "resources_lost", "enemy_lost": int, "allies", "helpers",
##          "castle_fallen": bool}.
func finish_invasion(clan_id: StringName, record: BattleRecord) -> Dictionary:
	var won := record.winner == BattleRecord.DEFENDER
	_record_battle(won)
	var general := generals.after_battle(record, BattleRecord.DEFENDER)
	var advisor := advisors.after_battle(record, BattleRecord.DEFENDER)
	var castle_fallen := not won and board.count_land_outside_castle() == 0
	if castle_fallen:
		victory.lost = true
	var result := BattleOutcome.apply_to_army(army, record, BattleRecord.DEFENDER)
	result.merge(alliances.apply_battle(record, BattleRecord.DEFENDER))
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
			"resources_lost": resources_lost, "enemy_lost": enemy_lost, "castle_fallen": castle_fallen,
			"general": general, "advisor": advisor, "item": equipment.roll_loot(false, stockpile) if won else {}})
	return result


## Starts the player's attack on a clan at war: the whole army (and the allies' soldiers) against
## the clan's whole army and the soldiers its friends send.
## Returns null (and changes nothing) unless Wars.check_attack() is OK.
func start_attack(clan_id: StringName) -> BattleSimulator:
	if wars.check_attack(clan_id, army.count_squads() > 0) != Wars.AttackResult.OK:
		return null
	wars.mark_attacked(clan_id)
	var defenders := wars.create_clan_side(clan_id, wars.fronts[clan_id].strength, units)
	alliances.add_friends(defenders, clan_id, units)
	return BattleSimulator.new(create_kingdom_side(clan_id, false), defenders, rng.randi())


## Applies a finished attack. Winning loots resources and may make the clan surrender: it is
## annexed and the board grows toward it. Losing costs the whole army (half of the unbroken
## squads if the player retreated) and a compensation of every resource.
## Returns {"record", "won", "clan_id", "casualties", "scattered", "retreat_losses", "enemy_lost",
##          "loot", "compensation", "annexed": bool, "allies", "helpers"}.
func finish_attack(clan_id: StringName, record: BattleRecord) -> Dictionary:
	var won := record.winner == BattleRecord.ATTACKER
	_record_battle(won)
	var general := generals.after_battle(record, BattleRecord.ATTACKER)
	var advisor := advisors.after_battle(record, BattleRecord.ATTACKER)
	var result := BattleOutcome.apply_to_army(army, record, BattleRecord.ATTACKER, true)
	result.merge(alliances.apply_battle(record, BattleRecord.ATTACKER))
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
			events.annexed_turn = turn
	else:
		for resource_id in stockpile.get_all():
			var amount := floori(stockpile.get_amount(resource_id) * Wars.ATTACK_DEFEAT_COMPENSATION)
			if amount > 0:
				compensation[resource_id] = amount
		stockpile.spend(compensation)
	result.merge({"record": record, "won": won, "clan_id": clan_id, "enemy_lost": enemy_lost,
			"loot": loot, "compensation": compensation, "annexed": annexed, "general": general, "advisor": advisor,
			"item": equipment.roll_loot(true, stockpile) if won else {}})
	return result
