class_name GameArt
extends RefCounted
## The generated pixel art (GDD §13, tools/art/generate.py): looks textures up by id, so drawing
## code never builds paths. Missing art returns null and callers fall back to flat colors.

const TILE_DIR := "res://assets/tiles/"
const BUILDING_DIR := "res://assets/buildings/"
const ICON_DIR := "res://assets/icons/"
const UNIT_DIR := "res://assets/units/"
const BATTLE_DIR := "res://assets/battle/"
const EFFECT_DIR := "res://assets/effects/"
## Rows of every unit sprite sheet, top to bottom (tools/art/battle_art.py STATES); 2 frames each.
const UNIT_STATES: Array[StringName] = [&"stand", &"walk", &"attack", &"fall", &"cheer"]
const UNIT_FRAMES := 2
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


# --- Battle (M12b) ------------------------------------------------------------------------

## A unit's sprite sheet; its "_team" sheet holds the clothes in grays, drawn tinted with the side's
## color. Unknown sprites fall back to the swordsman.
static func unit_sheet(sprite_id: StringName, team: bool = false) -> Texture2D:
	var suffix := "_team.png" if team else ".png"
	var texture := _load(UNIT_DIR + String(sprite_id) + suffix)
	return texture if texture != null else _load(UNIT_DIR + "swordsman" + suffix)


## The region of `sheet` holding `frame` of `state`.
static func unit_frame(sheet: Texture2D, state: StringName, frame: int) -> Rect2:
	var size := sheet.get_size() / Vector2(UNIT_FRAMES, UNIT_STATES.size())
	return Rect2(Vector2(frame % UNIT_FRAMES, maxi(0, UNIT_STATES.find(state))) * size, size)


## Battlefield pieces: &"mountains", &"cloud", &"ground", &"town", &"camp" (+ &"camp_team").
static func battle(piece: StringName) -> Texture2D:
	return _load(BATTLE_DIR + String(piece) + ".png")


## Effect strips (2 frames side by side): &"fire", &"smoke", &"sparkle"; &"arrow" is one image.
static func effect(effect_id: StringName) -> Texture2D:
	return _load(EFFECT_DIR + String(effect_id) + ".png")
