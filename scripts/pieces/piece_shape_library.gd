class_name PieceShapeLibrary
extends RefCounted
## Loads every PieceShapeData resource in data/pieces/. Add a shape by adding a .tres file there.

const SHAPE_DIR := "res://data/pieces/"


static func load_all() -> Dictionary[StringName, PieceShapeData]:
	var result: Dictionary[StringName, PieceShapeData] = {}
	result.assign(DataLibrary.load_folder(SHAPE_DIR, &"shape_id"))
	return result
