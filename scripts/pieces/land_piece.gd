class_name LandPiece
extends RefCounted
## A land piece in the player's hand. Its orientation is fixed: the player cannot rotate it.

const NO_KEY := -1

var shape_id: StringName
## Cell offsets from the piece origin, normalized so min x and min y are 0.
var offsets: Array[Vector2i] = []
## Terrain of each cell, same order as `offsets`.
var terrains: Array[StringName] = []
## Index into `offsets` of the key cell, or NO_KEY.
var key_index: int = NO_KEY


func _init(p_shape_id: StringName, p_offsets: Array[Vector2i], p_terrains: Array[StringName], p_key_index: int = NO_KEY) -> void:
	assert(p_offsets.size() == p_terrains.size(), "Every piece cell needs a terrain")
	shape_id = p_shape_id
	offsets = p_offsets
	terrains = p_terrains
	key_index = p_key_index


func get_size() -> Vector2i:
	var size := Vector2i.ZERO
	for offset in offsets:
		size = size.max(offset + Vector2i.ONE)
	return size


## The cell that sits under the mouse cursor while the piece is being placed.
func get_anchor() -> Vector2i:
	return (get_size() - Vector2i.ONE) / 2


## Board coordinates covered when the piece's origin is at `origin`.
func get_board_coords(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in offsets:
		result.append(origin + offset)
	return result


func is_key_cell(index: int) -> bool:
	return index == key_index
