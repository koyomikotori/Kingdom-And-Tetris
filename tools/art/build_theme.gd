extends SceneTree
## Builds the project Theme (assets/ui/theme.tres) from the generated UI frames (GDD §13).
## Run after tools/art/generate.py and an import:
##   <godot> --headless --path . --import
##   <godot> --headless --path . -s res://tools/art/build_theme.gd
## The project uses it through gui/theme/custom in project.godot.

const UI := "res://assets/ui/"
const OUTPUT := "res://assets/ui/theme.tres"
## Frames are drawn ×2: margins below are in screen pixels (art pixels × 2).
const PAPER_MARGIN := 8
const WOOD_MARGIN := 4
const BUTTON_MARGIN := 6
const TAB_MARGIN := 6


func _initialize() -> void:
	var theme := Theme.new()
	var paper := _box("panel_paper.png", PAPER_MARGIN, Vector4(14, 12, 14, 12))
	var wood := _box("panel_wood.png", WOOD_MARGIN, Vector4(8, 6, 8, 6))
	var inset := _box("panel_inset.png", 4, Vector4(6, 4, 6, 4))

	theme.set_stylebox("panel", "PanelContainer", paper)
	theme.set_stylebox("panel", "Panel", paper)
	theme.set_stylebox("panel", "TooltipPanel", paper)
	theme.set_color("font_color", "TooltipLabel", UiPalette.TEXT)
	theme.set_color("font_color", "Label", UiPalette.TEXT)
	theme.set_color("font_color", "RichTextLabel", UiPalette.TEXT)
	theme.set_color("default_color", "RichTextLabel", UiPalette.TEXT)

	# Wooden bars (top bar, side panel frame) and the cream labels on them.
	theme.set_type_variation("WoodPanel", "PanelContainer")
	theme.set_stylebox("panel", "WoodPanel", wood)
	theme.set_type_variation("WoodLabel", "Label")
	theme.set_color("font_color", "WoodLabel", UiPalette.ON_WOOD)
	theme.set_type_variation("InsetPanel", "PanelContainer")
	theme.set_stylebox("panel", "InsetPanel", inset)

	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := _box("button_%s.png" % state, BUTTON_MARGIN, Vector4(10, 5, 10, 7))
		theme.set_stylebox(state, "Button", box)
	theme.set_stylebox("hover_pressed", "Button", theme.get_stylebox("pressed", "Button"))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", UiPalette.ON_WOOD)
	theme.set_color("font_hover_color", "Button", UiPalette.BUTTON_HOVER)
	theme.set_color("font_pressed_color", "Button", UiPalette.ON_WOOD)
	theme.set_color("font_hover_pressed_color", "Button", UiPalette.BUTTON_HOVER)
	theme.set_color("font_focus_color", "Button", UiPalette.ON_WOOD)
	theme.set_color("font_disabled_color", "Button", UiPalette.ON_WOOD_DISABLED)
	theme.set_color("font_outline_color", "Button", Color(0.17, 0.11, 0.07))
	theme.set_constant("outline_size", "Button", 4)

	var selected := _box("tab_selected.png", TAB_MARGIN, Vector4(8, 6, 8, 4))
	var unselected := _box("tab_unselected.png", TAB_MARGIN, Vector4(8, 6, 8, 4))
	theme.set_stylebox("tab_selected", "TabContainer", selected)
	theme.set_stylebox("tab_unselected", "TabContainer", unselected)
	theme.set_stylebox("tab_hovered", "TabContainer", unselected)
	theme.set_stylebox("tab_disabled", "TabContainer", unselected)
	theme.set_stylebox("panel", "TabContainer", paper)
	theme.set_color("font_selected_color", "TabContainer", UiPalette.TEXT)
	theme.set_color("font_unselected_color", "TabContainer", UiPalette.ON_WOOD)
	theme.set_color("font_hovered_color", "TabContainer", UiPalette.BUTTON_HOVER)
	theme.set_stylebox("tab_selected", "TabBar", selected)
	theme.set_stylebox("tab_unselected", "TabBar", unselected)
	theme.set_stylebox("tab_hovered", "TabBar", unselected)
	theme.set_color("font_selected_color", "TabBar", UiPalette.TEXT)
	theme.set_color("font_unselected_color", "TabBar", UiPalette.ON_WOOD)
	theme.set_color("font_hovered_color", "TabBar", UiPalette.BUTTON_HOVER)

	theme.set_stylebox("normal", "LineEdit", inset)
	theme.set_stylebox("focus", "LineEdit", inset)
	theme.set_color("font_color", "LineEdit", UiPalette.TEXT)
	theme.set_stylebox("normal", "SpinBox", inset)
	theme.set_color("font_color", "OptionButton", UiPalette.ON_WOOD)
	theme.set_color("font_color", "CheckBox", UiPalette.TEXT)
	theme.set_color("font_hover_color", "CheckBox", UiPalette.ACCENT)
	theme.set_color("font_pressed_color", "CheckBox", UiPalette.TEXT)
	theme.set_color("font_hover_pressed_color", "CheckBox", UiPalette.ACCENT)
	theme.set_color("font_color", "CheckButton", UiPalette.TEXT)
	theme.set_color("font_color", "PopupMenu", UiPalette.TEXT)
	theme.set_stylebox("panel", "PopupMenu", paper)
	theme.set_color("font_color", "ItemList", UiPalette.TEXT)
	theme.set_stylebox("panel", "ItemList", inset)

	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = UiPalette.BAR_BACKGROUND
	theme.set_stylebox("background", "ProgressBar", bar_background)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = UiPalette.GOLD
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	theme.set_color("font_color", "ProgressBar", UiPalette.TEXT)

	var separator := StyleBoxLine.new()
	separator.color = Color(UiPalette.HEADER, 0.45)
	separator.thickness = 2
	theme.set_stylebox("separator", "HSeparator", separator)

	var error := ResourceSaver.save(theme, OUTPUT)
	print("Theme saved to %s (%s)" % [OUTPUT, error_string(error)])
	quit(0 if error == OK else 1)


## A 9-slice box from a generated frame; `content` = left, top, right, bottom padding.
func _box(file: String, margin: int, content: Vector4) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(UI + file)
	box.set_texture_margin_all(margin)
	# Tile the middle and the edges: stretching would smear the grain and paper fibers.
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.content_margin_left = content.x
	box.content_margin_top = content.y
	box.content_margin_right = content.z
	box.content_margin_bottom = content.w
	return box
