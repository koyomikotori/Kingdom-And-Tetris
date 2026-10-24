class_name PieceHand
extends RefCounted
## The land pieces the player can currently place.

signal changed

const DEFAULT_SIZE := 3

var pieces: Array[LandPiece] = []
var hand_size: int
var _generator: PieceGenerator


func _init(generator: PieceGenerator, p_hand_size: int = DEFAULT_SIZE) -> void:
	_generator = generator
	hand_size = p_hand_size


## Tops the hand up to hand_size pieces.
func refill() -> void:
	while pieces.size() < hand_size:
		pieces.append(_generator.generate())
	changed.emit()


## Discards any remaining pieces and draws a full new hand.
func deal_new_hand() -> void:
	pieces.clear()
	refill()


## Removes and returns the piece at `index`. Call only after a successful placement.
func take(index: int) -> LandPiece:
	var piece := pieces[index]
	pieces.remove_at(index)
	changed.emit()
	return piece


func is_empty() -> bool:
	return pieces.is_empty()
