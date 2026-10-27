class_name ItemIcon
extends Control
## An item's pixel icon in its rarity frame (GDD §8 "Trang bị", M12e), or an empty slot frame.
## Read-only; drawn ×`art_scale` (the art is 24×24: a 16×16 icon inside a 4 px frame).

const SIZE := 24

var art_scale := 2
var _item: Item
## Shown in the empty frame when there is no item yet (an item being forged).
var _icon_id: StringName = &""


func setup(item: Item, scale: int = 2) -> void:
	_item = item
	art_scale = scale
	custom_minimum_size = Vector2.ONE * SIZE * scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


## The empty frame with a type's icon: something still being made (the forge).
func setup_type(icon_id: StringName, scale: int = 2) -> void:
	_icon_id = icon_id
	setup(null, scale)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2.ONE * SIZE * art_scale)
	var frame := GameArt.item_frame(_item.rarity if _item != null else -1)
	if frame != null:
		draw_texture_rect(frame, rect, false)
	else:
		draw_rect(rect, Item.RARITY_COLORS[_item.rarity] if _item != null else UiPalette.MUTED, false, 2.0)
	if _item == null and _icon_id == &"":
		return
	var icon := GameArt.item_icon(_item.icon_id() if _item != null else _icon_id)
	if icon != null:
		draw_texture_rect(icon, Rect2(Vector2.ONE * 4 * art_scale, Vector2.ONE * 16 * art_scale), false)
