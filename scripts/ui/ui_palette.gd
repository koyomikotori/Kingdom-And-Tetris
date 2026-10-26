class_name UiPalette
extends RefCounted
## Colors of the wood + paper interface (GDD §13). Text on paper is dark ink; text on wood
## (top bar, buttons) is cream. The battle screen keeps its own dark look (BattleScreen).

## Ink on paper.
const TEXT := Color(0.23, 0.16, 0.1)
const MUTED := Color(0.23, 0.16, 0.1, 0.68)
## Titles and highlighted lines on paper.
const ACCENT := Color(0.6, 0.17, 0.11)
## Section headers on paper.
const HEADER := Color(0.48, 0.24, 0.07)
const WARNING := Color(0.69, 0.16, 0.1)
const GOOD := Color(0.18, 0.49, 0.2)
const XP := Color(0.18, 0.43, 0.69)
const GOLD := Color(0.79, 0.58, 0.18)
## Text on wood.
const ON_WOOD := Color(0.98, 0.93, 0.8)
const ON_WOOD_MUTED := Color(0.98, 0.93, 0.8, 0.7)
## Warning text on a wooden button (Sa thải, Phá hủy…).
const WARNING_ON_WOOD := Color(1.0, 0.68, 0.58)
const ON_WOOD_DISABLED := Color(0.85, 0.8, 0.7, 0.55)
const BUTTON_HOVER := Color(1.0, 0.97, 0.86)
## Flat fills that sit on paper (progress bar backgrounds, dims).
const BAR_BACKGROUND := Color(0.23, 0.16, 0.1, 0.22)
const DIM := Color(0.08, 0.05, 0.03, 0.55)
## Screen backgrounds behind panels (main menu, world map).
const BACKDROP := Color(0.29, 0.19, 0.11)


## A color made dark enough to read on paper (clan colors are light: they were picked for dark
## screens and for map markers).
static func ink(color: Color) -> Color:
	return color.darkened(clampf((color.get_luminance() - 0.3) * 1.5, 0.0, 0.65))
