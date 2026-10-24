class_name PieceShapeData
extends Resource
## Static definition of a land-piece shape. One .tres per shape in data/pieces/.
## Mirror images (L left / L right) are separate shapes; rotations are generated.

@export var shape_id: StringName
@export var display_name: String
## Cells of the shape in its base orientation. x right, y down.
@export var cells: Array[Vector2i] = []
## Relative chance of drawing this shape, shared across all its orientations.
@export var spawn_weight: float = 1.0


## Every distinct 90° rotation of `cells`, each normalized so min x and min y are 0.
## A square has 1, a bar has 2, an L has 4.
func get_orientations() -> Array[Array]:
	var result: Array[Array] = []
	var current := cells.duplicate()
	for i in 4:
		var normalized := normalize(current)
		if not result.has(normalized):
			result.append(normalized)
		current = rotate_clockwise(current)
	return result


## Rotates 90° clockwise in screen space (y grows down).
static func rotate_clockwise(points: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for p in points:
		result.append(Vector2i(-p.y, p.x))
	return result


## Shifts points so min x and min y are 0, then sorts them so equal shapes compare equal.
static func normalize(points: Array[Vector2i]) -> Array[Vector2i]:
	var min_corner := points[0]
	for p in points:
		min_corner = min_corner.min(p)
	var result: Array[Vector2i] = []
	for p in points:
		result.append(p - min_corner)
	result.sort()
	return result
