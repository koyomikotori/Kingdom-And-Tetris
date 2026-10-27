class_name GameSettings
extends RefCounted
## Player preferences kept on this computer (user://settings.cfg), apart from the saves (M13c).
## Only "map_effects" so far: building animations and walkers on the kingdom map.

const PATH := "user://settings.cfg"

static var _loaded := false
static var _map_effects := true


static func map_effects() -> bool:
	_load()
	return _map_effects


static func set_map_effects(on: bool) -> void:
	_load()
	_map_effects = on
	var file := ConfigFile.new()
	file.load(PATH)
	file.set_value("display", "map_effects", on)
	file.save(PATH)


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		_map_effects = bool(file.get_value("display", "map_effects", true))
