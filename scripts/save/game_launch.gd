class_name GameLaunch
extends RefCounted
## Moves between the main menu and the kingdom scene, handing over the game to load (GDD §10.1).

const KINGDOM_SCENE := "res://scenes/kingdom/kingdom.tscn"
const MENU_SCENE := "res://scenes/menu/main_menu.tscn"

## Game data (SaveSystem.load_slot().game) for the next kingdom scene; empty = a new game.
static var _pending_game: Dictionary = {}
## A new game's choices (NewGameWindow, M14h) for the next kingdom scene.
static var _new_game_settings: Dictionary = {}


static func new_game(tree: SceneTree, settings: Dictionary = {}) -> void:
	_pending_game = {}
	_new_game_settings = settings
	tree.change_scene_to_file(KINGDOM_SCENE)


## Opens the kingdom scene on the saved game. Returns "" or the reason it cannot be loaded.
static func load_game(tree: SceneTree, system: SaveSystem, slot: String) -> String:
	var result := system.load_slot(slot)
	if result.has("error"):
		return result.error
	_pending_game = result.game
	tree.change_scene_to_file(KINGDOM_SCENE)
	return ""


static func to_menu(tree: SceneTree) -> void:
	_pending_game = {}
	tree.change_scene_to_file(MENU_SCENE)


## The game the kingdom scene should load (once), or {} for a new game.
static func take_pending_game() -> Dictionary:
	var game := _pending_game
	_pending_game = {}
	return game


## The new game's choices (once), or {} for the defaults.
static func take_new_game_settings() -> Dictionary:
	var settings := _new_game_settings
	_new_game_settings = {}
	return settings
