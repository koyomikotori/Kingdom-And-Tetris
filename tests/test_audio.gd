extends "res://tests/test_suite.gd"
## M14a: generated sounds and music, the settings that hold the volumes and full screen.

const TEST_SETTINGS := "user://test_settings.cfg"


func test_every_sound_has_a_file() -> void:
	for id in Sfx.EFFECTS:
		check(Sfx.load_stream(Sfx.SFX_DIR, id) != null, "Effect %s" % id)
	for id in Sfx.MUSIC + Sfx.STINGS:
		check(Sfx.load_stream(Sfx.MUSIC_DIR, id) != null, "Music %s" % id)
	check(Sfx.load_stream(Sfx.SFX_DIR, &"no_such_sound") == null, "An unknown sound is null")
	# Playing anything, known or not, never fails.
	Sfx.play(&"click")
	Sfx.play(&"no_such_sound")


func test_settings_are_kept_and_clamped() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	GameSettings.use_file(TEST_SETTINGS)
	check_eq(GameSettings.music_volume(), GameSettings.DEFAULT_MUSIC_VOLUME, "Default music volume")
	check_eq(GameSettings.sound_volume(), GameSettings.DEFAULT_SOUND_VOLUME, "Default sound volume")
	check(GameSettings.map_effects(), "Map effects on by default")
	check(not GameSettings.fullscreen(), "Windowed by default")
	var heard := [0]
	var count := func() -> void: heard[0] += 1
	GameSettings.notifier.changed.connect(count)
	GameSettings.set_music_volume(0.25)
	GameSettings.set_sound_volume(3.0)
	GameSettings.set_map_effects(false)
	GameSettings.notifier.changed.disconnect(count)
	check_eq(heard[0], 3, "Every change is announced")
	check_eq(GameSettings.sound_volume(), 1.0, "Volumes stay within 0..1")
	GameSettings.use_file(TEST_SETTINGS)
	check_eq(GameSettings.music_volume(), 0.25, "Music volume read back from the file")
	check_eq(GameSettings.sound_volume(), 1.0, "Sound volume read back")
	check(not GameSettings.map_effects(), "Map effects read back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	GameSettings.use_file(GameSettings.PATH)
