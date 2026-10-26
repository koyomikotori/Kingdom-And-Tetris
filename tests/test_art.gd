extends "res://tests/test_suite.gd"
## M12a: every piece of content has its generated art (GDD §13, tools/art/generate.py).


func test_every_terrain_has_a_tile() -> void:
	for terrain_id in TerrainLibrary.load_all():
		var texture := GameArt.terrain(terrain_id)
		check(texture != null, "Tile for %s" % terrain_id)
		if texture != null:
			check_eq(texture.get_size(), Vector2(16, 16), "%s is 16×16" % terrain_id)
	check(GameArt.terrain(&"") != null, "Wild land outside the kingdom")
	check(GameArt.key_marker() != null, "Key cell marker")
	check(GameArt.key_frame() != null, "Key cell frame (drawn over buildings)")


func test_every_building_has_a_picture() -> void:
	for building_id in BuildingData.load_all():
		check(GameArt.building(building_id) != null, "Picture for %s" % building_id)
	for level in range(1, 7):
		var castle := GameArt.castle(level)
		check(castle != null and castle.get_size() == Vector2(32, 32), "Castle level %d is 32×32" % level)
		check(GameArt.level_badge(level) != null, "Level badge %d" % level)
	check(GameArt.castle(9) == GameArt.castle(6), "Levels past the art use the top castle")


func test_every_resource_has_an_icon() -> void:
	for type in ResourceTypeData.load_all():
		var icon := GameArt.icon(type.resource_id)
		check(icon != null, "Icon for %s" % type.resource_id)
		if icon != null:
			check_eq(icon.get_size(), Vector2(24, 24), "%s icon is 24×24" % type.resource_id)


func test_missing_art_is_null_not_an_error() -> void:
	check(GameArt.building(&"no_such_building") == null, "Unknown ids fall back to flat colors")


func test_project_theme_is_wood_and_paper() -> void:
	var path: String = ProjectSettings.get_setting("gui/theme/custom", "")
	check_eq(path, "res://assets/ui/theme.tres", "Project theme set")
	var theme: Theme = load(path)
	check(theme != null, "Theme loads")
	if theme == null:
		return
	check(theme.get_stylebox("panel", "PanelContainer") is StyleBoxTexture, "Paper panels")
	check(theme.get_stylebox("normal", "Button") is StyleBoxTexture, "Wooden buttons")
	check(theme.get_stylebox("panel", "WoodPanel") is StyleBoxTexture, "Wooden bars")
	check_eq(theme.get_color("font_color", "Label"), UiPalette.TEXT, "Ink on paper")
	check_eq(theme.get_color("font_color", "WoodLabel"), UiPalette.ON_WOOD, "Cream on wood")


func test_ink_keeps_dark_colors_and_darkens_light_ones() -> void:
	check_eq(UiPalette.ink(UiPalette.TEXT), UiPalette.TEXT, "Already dark")
	var light := Color(0.75, 0.8, 0.9)
	check(UiPalette.ink(light).get_luminance() < light.get_luminance() - 0.2, "Light clan colors get darker")
