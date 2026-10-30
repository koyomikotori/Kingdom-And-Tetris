class_name ImportantReportWindow
extends ModalWindow
## The important news of the turn (ImportantNews, GDD §15 M14g), one heading per kind. Closed only
## with "OK" or Enter (Esc too), so it is never missed by clicking past it.


func open(news: Array[Dictionary]) -> void:
	Sfx.play(&"horn")
	var body := build_frame("Báo cáo quan trọng", UiPalette.WARNING, 0.42, false)
	for entry in news:
		var heading := _label(entry.title, 17)
		heading.add_theme_color_override("font_color", WARNING_COLOR)
		body.add_child(heading)
		for line: String in entry.lines:
			body.add_child(_label("• " + line, 15))
	add_action("OK (Enter)", close)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		close()
	get_viewport().set_input_as_handled()
