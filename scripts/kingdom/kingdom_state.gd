class_name KingdomState
extends RefCounted
## Runtime state of one game: board, piece hand, stockpile and turn counter.
## All game actions go through here so the scene script only handles input and display.

signal turn_started(turn: int)

var board: BoardData
var hand: PieceHand
var stockpile := Stockpile.new()
var turn := 1
var terrains: Dictionary[StringName, TerrainData] = {}


func _init(p_board: BoardData, p_hand: PieceHand, p_terrains: Dictionary[StringName, TerrainData]) -> void:
	board = p_board
	hand = p_hand
	terrains = p_terrains


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


func get_turn_yield() -> Dictionary[StringName, int]:
	return Economy.board_yield(board, terrains)


## Collects this turn's yield, advances the turn and deals a fresh hand.
## Unplaced pieces are discarded. Returns what was collected.
func end_turn() -> Dictionary[StringName, int]:
	var collected := get_turn_yield()
	stockpile.add(collected)
	turn += 1
	hand.deal_new_hand()
	turn_started.emit(turn)
	return collected
