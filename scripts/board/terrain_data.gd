class_name TerrainData
extends Resource
## Static definition of a terrain type. One .tres per terrain in data/terrains/.

@export var terrain_id: StringName
@export var display_name: String
## Placeholder color until pixel-art tiles exist.
@export var color: Color = Color.MAGENTA
## Relative chance of this terrain appearing on a land-piece cell. 0 = never.
@export var spawn_weight: float = 1.0
