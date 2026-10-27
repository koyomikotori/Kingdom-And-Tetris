class_name ScreenFit
extends RefCounted
## Keeps windows inside a small game window (GDD §10.2).


## Shrinks `control` (a window's panel) around its center when it is bigger than `viewport_size`
## less `margin` on each side, so nothing is cut off. Call it after layout (on `resized`).
static func shrink_to_fit(control: Control, viewport_size: Vector2, margin: float = 12.0) -> void:
	var room := viewport_size - Vector2.ONE * margin * 2.0
	var factor := minf(1.0, minf(room.x / maxf(1.0, control.size.x), room.y / maxf(1.0, control.size.y)))
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * factor
