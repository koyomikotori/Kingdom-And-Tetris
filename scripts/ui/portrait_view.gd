class_name PortraitView
extends Control
## An officer's pixel portrait (GDD §13, M12c), 64×64 drawn `art_scale` times: a hand-drawn / AI
## portrait from the pool (GameArt.officer_pool_portrait) or one named after the officer
## (GameArt.custom_portrait), on the background and inside the frame; otherwise parts from
## tools/art/portrait_art.py stacked and tinted from the officer's OfficerLook. Read-only.

const SIZE := 64
## Stars from which the frame gets its gold border.
const GOLD_FRAME_STARS := 4

var art_scale := 3
var _officer: Officer
var _team := KingdomState.PLAYER_COLOR


## `team`: the armor cloth / robe color (the player's color for the kingdom's officers).
func setup(officer: Officer, scale: int = 3, team: Color = KingdomState.PLAYER_COLOR) -> void:
	_officer = officer
	art_scale = scale
	_team = team
	custom_minimum_size = Vector2.ONE * SIZE * scale
	queue_redraw()


func _draw() -> void:
	if _officer == null:
		return
	var rect := Rect2(Vector2.ZERO, Vector2.ONE * SIZE * art_scale)
	var picture := GameArt.custom_portrait(_officer.name)
	if picture == null:
		picture = GameArt.officer_pool_portrait(_officer)
	if picture != null:
		for entry: Array in [["bg", null], [picture, null], [frame_part(_officer), null]]:
			var texture: Texture2D = entry[0] if entry[0] is Texture2D else GameArt.portrait_part(entry[0])
			if texture != null:
				draw_texture_rect(texture, rect, false)
		return
	for entry: Array in layers(_officer, _team):
		var texture := GameArt.portrait_part(entry[0])
		if texture != null:
			draw_texture_rect(texture, rect, false, entry[1])


## The parts to stack, back to front, each [part name, tint].
static func layers(officer: Officer, team: Color) -> Array:
	var look := officer.look
	var g := "f" if look.is_female() else "m"
	var kind := "advisor" if officer is Advisor else "general"
	var hair := look.hair_tint()
	var result: Array = [
		["bg", Color.WHITE],
		["hair_back_%s_%d" % [g, look.hair_style], hair],
		["body_%s_team" % kind, team],
		["body_%s" % kind, Color.WHITE],
		["face_%s" % g, look.skin_color()],
	]
	if look.beard > 0:
		result.append(["beard_%d" % look.beard, hair])
	result.append_array([
		["mouth_%s" % g, Color.WHITE],
		["eyes_%d_%s" % [look.eyes, g], Color.WHITE],
		["brows_%d" % look.brows, hair],
		["hair_front_%s_%d" % [g, look.hair_style], hair],
	])
	var headgear := "helmet" if kind == "general" else ("hairpin" if look.is_female() else "scholar_hat")
	result.append([headgear, Color.WHITE])
	result.append([headgear + "_accent", look.accent_color()])
	result.append([frame_part(officer), Color.WHITE])
	return result


## The wooden frame, or the gold one from GOLD_FRAME_STARS.
static func frame_part(officer: Officer) -> String:
	return "frame_%d" % (1 if officer.stars >= GOLD_FRAME_STARS else 0)
