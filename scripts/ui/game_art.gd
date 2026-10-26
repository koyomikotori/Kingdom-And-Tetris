class_name GameArt
extends RefCounted
## The generated pixel art (GDD §13, tools/art/generate.py): looks textures up by id, so drawing
## code never builds paths. Missing art returns null and callers fall back to flat colors.

const TILE_DIR := "res://assets/tiles/"
const BUILDING_DIR := "res://assets/buildings/"
const ICON_DIR := "res://assets/icons/"
## Board art is drawn at 16×16 and shown ×2 (BoardView.TILE_SIZE).
const ART_SCALE := 2

## Keeps every texture alive: canvas draw commands only hold the texture's RID, so a texture
## loaded inside _draw() and dropped right after would render white.
static var _cache: Dictionary[String, Texture2D] = {}


static func _load(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


## Lets the textures go (the headless test runner calls it before quitting).
static func clear_cache() -> void:
	_cache.clear()


## Tile for a terrain id; &"" (no terrain) is the wild land outside the kingdom.
static func terrain(terrain_id: StringName) -> Texture2D:
	return _load(TILE_DIR + ("wild" if terrain_id == &"" else String(terrain_id)) + ".png")


static func key_marker() -> Texture2D:
	return _load(TILE_DIR + "key.png")


## Gold frame drawn over a key cell (above any building on it).
static func key_frame() -> Texture2D:
	return _load(TILE_DIR + "key_frame.png")


## The castle changes with the castle level (1–6).
static func castle(level: int) -> Texture2D:
	return _load(BUILDING_DIR + "castle_%d.png" % clampi(level, 1, 6))


static func building(building_id: StringName) -> Texture2D:
	return _load(BUILDING_DIR + String(building_id) + ".png")


static func level_badge(level: int) -> Texture2D:
	return _load(BUILDING_DIR + "level_%d.png" % level)


## Resource icon (24×24 on screen).
static func icon(resource_id: StringName) -> Texture2D:
	return _load(ICON_DIR + String(resource_id) + ".png")
