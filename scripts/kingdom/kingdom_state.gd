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


func _init(p_board: BoardData, p_hand: PieceHand, p_terrains: Dictionary[StringName, TerrainData],
		p_buildings: Dictionary[StringName, BuildingData] = {}, p_units: Array[UnitData] = []) -> void:
	board = p_board
	hand = p_hand
	terrains = p_terrains
	buildings = p_buildings
	for unit in p_units:
		units[unit.unit_id] = unit


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


func get_upkeep() -> Dictionary[StringName, int]:
	return army.get_upkeep(units)


## Yield minus upkeep: how the stockpile changes at the end of this turn (if upkeep is affordable).
func get_net_income() -> Dictionary[StringName, int]:
	var net := get_turn_yield()
	Economy.add_into(net, get_upkeep(), -1)
	return net


## Collects this turn's yield, pays army upkeep, advances the turn and deals a fresh hand.
## When upkeep cannot be paid, soldiers desert (largest group first) until it can.
## Unplaced pieces are discarded.
## Returns {"collected": amounts, "upkeep": amounts paid, "deserted": {unit_id: count}}.
func end_turn() -> Dictionary:
	var collected := get_turn_yield()
	stockpile.add(collected)
	var deserted: Dictionary[StringName, int] = {}
	while army.get_total() > 0 and not stockpile.can_afford(get_upkeep()):
		var unit_id := army.get_largest_group()
		army.remove(unit_id)
		deserted[unit_id] = deserted.get(unit_id, 0) + 1
	var upkeep := get_upkeep()
	stockpile.spend(upkeep)
	turn += 1
	hand.deal_new_hand()
	turn_started.emit(turn)
	return {"collected": collected, "upkeep": upkeep, "deserted": deserted}
