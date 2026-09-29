extends Control
## Main menu: new game, network game (stage 5), quit.

const ThemeFactory := preload("res://scripts/ui/theme_factory.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = ThemeFactory.make()
	var bg := ColorRect.new()
	bg.color = Color(0.094, 0.204, 0.376)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(PRESET_CENTER)
	box.offset_left = -180
	box.offset_right = 180
	box.offset_top = -170
	box.offset_bottom = 170
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var title := Label.new()
	title.text = "MEDSTRAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Пиксельная стратегия по Европе и Средиземноморью"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(Control.new())
	_button(box, "Новая игра (Италия)", func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))
	var net := _button(box, "Сетевая игра", Callable())
	net.disabled = true
	net.tooltip_text = "Появится на этапе 5"
	_button(box, "Выход", func(): get_tree().quit())
	var hint := Label.new()
	hint.text = "ПКМ/СКМ или WASD — двигать карту · колесо — зум · Esc — отмена / меню"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	hint.offset_top = -40
	hint.offset_bottom = -12
	add_child(hint)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="):
			_screenshot(a.get_slice("=", 1))


func _screenshot(path: String) -> void:
	for i in 6:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved to ", path)
	get_tree().quit()


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	if cb.is_valid():
		b.pressed.connect(cb)
	parent.add_child(b)
	return b
