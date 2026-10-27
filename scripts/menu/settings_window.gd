class_name SettingsWindow
extends ModalWindow
## "Cài đặt" (M14a), from the in-game menu and the main menu: music and sound volumes, map effects,
## full screen. Every change is saved at once (GameSettings) and applied by whoever listens to
## `GameSettings.notifier.changed`.

const ACCENT := UiPalette.ACCENT
const SLIDER_WIDTH := 220.0


func open() -> void:
	var body := build_frame("Cài đặt", ACCENT, 0.34)
	body.add_child(_volume_row("Nhạc nền", GameSettings.music_volume(), GameSettings.set_music_volume, false))
	body.add_child(_volume_row("Âm thanh hiệu ứng", GameSettings.sound_volume(), GameSettings.set_sound_volume, true))
	body.add_child(_toggle("Hiệu ứng bản đồ", GameSettings.map_effects, GameSettings.set_map_effects))
	body.add_child(_toggle("Toàn màn hình", GameSettings.fullscreen, GameSettings.set_fullscreen))
	var hint := _label("Hiệu ứng bản đồ: công trình chuyển động, người và vật đi lại, tiếng chim và tiếng búa.", 13)
	hint.add_theme_color_override("font_color", MUTED_COLOR)
	body.add_child(hint)


func _volume_row(title: String, value: float, setter: Callable, sample: bool) -> Control:
	var name_label := _label(title, 16, false)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var amount := _label("%d%%" % roundi(value * 100), 16, false)
	amount.custom_minimum_size = Vector2(52, 0)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = roundi(value * 100)
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(percent: float) -> void:
		setter.call(percent / 100.0)
		amount.text = "%d%%" % roundi(percent))
	if sample:
		# Let go of the sound slider: hear how loud it is now.
		slider.drag_ended.connect(func(_changed: bool) -> void: Sfx.play(&"coins"))
	return _row([name_label, slider, amount])


func _toggle(title: String, getter: Callable, setter: Callable) -> Button:
	var button := _button("", func() -> void: pass)
	button.custom_minimum_size = Vector2(0, 48)
	var refresh := func() -> void: button.text = "%s: %s" % [title, "Bật" if getter.call() else "Tắt"]
	refresh.call()
	button.pressed.connect(func() -> void:
		setter.call(not getter.call())
		refresh.call())
	return button
