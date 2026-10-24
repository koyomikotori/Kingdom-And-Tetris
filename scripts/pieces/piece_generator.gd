class_name PieceGenerator
extends RefCounted
## Creates random land pieces. Every orientation of every shape is its own draw;
## a shape's spawn_weight is split evenly across its orientations.

const KEY_CELL_CHANCE := 0.2

var _rng := RandomNumberGenerator.new()
var _shape_ids: Array[StringName] = []
var _shape_offsets: Array[Array] = []
var _shape_weights := PackedFloat32Array()
var _terrain_ids: Array[StringName] = []
var _terrain_weights := PackedFloat32Array()


## Same seed + same data = same sequence of pieces.
func _init(shapes: Dictionary[StringName, PieceShapeData], terrains: Dictionary[StringName, TerrainData], seed_value: int) -> void:
	_rng.seed = seed_value
	var shape_keys := shapes.keys()
	shape_keys.sort()
	for id: StringName in shape_keys:
		var shape := shapes[id]
		var orientations := shape.get_orientations()
		for offsets in orientations:
			_shape_ids.append(id)
			_shape_offsets.append(offsets)
			_shape_weights.append(shape.spawn_weight / orientations.size())
	var terrain_keys := terrains.keys()
	terrain_keys.sort()
	for id: StringName in terrain_keys:
		if terrains[id].spawn_weight > 0:
			_terrain_ids.append(id)
			_terrain_weights.append(terrains[id].spawn_weight)
	assert(not _shape_ids.is_empty(), "No piece shapes loaded")
	assert(not _terrain_ids.is_empty(), "No spawnable terrains loaded")


func generate() -> LandPiece:
	var choice := _rng.rand_weighted(_shape_weights)
	var offsets: Array[Vector2i] = []
	offsets.assign(_shape_offsets[choice])
	var terrains: Array[StringName] = []
	for i in offsets.size():
		terrains.append(_terrain_ids[_rng.rand_weighted(_terrain_weights)])
	var key_index := LandPiece.NO_KEY
	if _rng.randf() < KEY_CELL_CHANCE:
		key_index = _rng.randi_range(0, offsets.size() - 1)
	return LandPiece.new(_shape_ids[choice], offsets, terrains, key_index)


## Number of distinct piece layouts the generator can produce (shape × orientation).
func get_orientation_count() -> int:
	return _shape_ids.size()
