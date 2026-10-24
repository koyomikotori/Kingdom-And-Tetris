class_name KingdomState
extends RefCounted
## Runtime state of one game: board, piece hand, stockpile, army and turn counter.
## All game actions go through here so the scene script only handles input and display.

signal turn_started(turn: int)

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
	return RecruitmentRules.apply(board, stockpile, army, units[unit_id])


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


## Yield minus upkeep: how the stockpile changes at the end of this turn (if upkeep is affordable).
func get_net_income() -> Dictionary[StringName, int]:
	var net := get_turn_yield()
	Economy.add_into(net, get_upkeep(), -1)
	return net


## Ends the turn:
## 1. collect yield;
## 2. pay army upkeep; soldiers desert (largest group first) until it can be paid;
## 3. pay building upkeep if possible, otherwise building effects pause next turn;
## 4. advance the turn and deal a fresh hand (unplaced pieces are discarded);
## 5. bandits may raid at the start of the new turn.
## Returns {"collected", "upkeep", "deserted", "buildings_supplied"} plus "raid" when a raid happened
## (see RaidSystem.resolve).
func end_turn() -> Dictionary:
	var collected := get_turn_yield()
	stockpile.add(collected)
	var deserted: Dictionary[StringName, int] = {}
	while army.get_total() > 0 and not stockpile.can_afford(get_army_upkeep()):
		var unit_id := army.get_largest_group()
		army.remove(unit_id)
		deserted[unit_id] = deserted.get(unit_id, 0) + 1
	var upkeep := get_army_upkeep()
	stockpile.spend(upkeep)
	var building_upkeep := get_building_upkeep()
	buildings_supplied = stockpile.spend(building_upkeep)
	if buildings_supplied:
		Economy.add_into(upkeep, building_upkeep)
	turn += 1
	hand.deal_new_hand()
	var report := {"collected": collected, "upkeep": upkeep, "deserted": deserted,
			"buildings_supplied": buildings_supplied}
	if raid != null and rng.randf() < RaidSystem.get_raid_chance(self, raid):
		var bandits := RaidSystem.create_bandit_side(raid, enemy_units, turn, rng)
		report["raid"] = RaidSystem.resolve(self, raid, bandits, rng.randi())
	turn_started.emit(turn)
	return report
