extends Control
## Main menu: nickname, new game, how to play, sound toggle, quit.

const ThemeFactory := preload("res://scripts/ui/theme_factory.gd")

var nick_edit: LineEdit
var help_panel: PanelContainer
var sound_check: CheckBox


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = ThemeFactory.make()
	var settings = get_node_or_null("/root/Settings")

	var bg := TextureRect.new()
	bg.texture = load("res://assets/map/preview.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.10, 0.55)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -250
	panel.offset_bottom = 250
	add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "MEDSTRAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Захвати Европу: расширяйся, строй, побеждай"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var nick_row := HBoxContainer.new()
	nick_row.add_theme_constant_override("separation", 10)
	box.add_child(nick_row)
	var nick_label := Label.new()
	nick_label.text = "Ваш ник:"
	nick_row.add_child(nick_label)
	nick_edit = LineEdit.new()
	nick_edit.max_length = 16
	nick_edit.placeholder_text = "Игрок"
	nick_edit.text = settings.nickname if settings != null else "Игрок"
	nick_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	nick_row.add_child(nick_edit)

	_button(box, "Новая игра", _start)
	var net := _button(box, "Сетевая игра", Callable())
	net.disabled = true
	net.tooltip_text = "Появится на следующем этапе"
	_button(box, "Как играть", func(): help_panel.visible = not help_panel.visible)
	sound_check = CheckBox.new()
	sound_check.text = "Звук"
	sound_check.button_pressed = not (settings != null and settings.muted)
	sound_check.toggled.connect(func(on):
		if settings != null:
			settings.muted = not on
			settings.save())
	box.add_child(sound_check)
	_button(box, "Выход", func(): get_tree().quit())

	help_panel = PanelContainer.new()
	help_panel.set_anchors_and_offsets_preset(PRESET_CENTER_RIGHT)
	help_panel.offset_left = -380
	help_panel.offset_right = -20
	help_panel.offset_top = -200
	help_panel.offset_bottom = 200
	help_panel.visible = false
	add_child(help_panel)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = ("КАК ИГРАТЬ\n\n" +
		"1. В начале матча кликните по свободной земле — это ваша столица.\n" +
		"2. Армия растёт сама. Клик по ничьей или чужой земле отправляет долю армии (ползунок ATTACK SIZE), " +
		"и граница ползёт клетка за клеткой.\n" +
		"3. Золото капает с земли, старт стоит 500. Карточки внизу (клавиши 1–8): Защита, Город, Порт, Рынок, " +
		"Казармы, Бункер, Ядерная бомба и MEGA NUKE. Бомбы требуют технологий из меню Развитие (T).\n" +
		"4. С портом клик по берегу за морем отправляет корабли. Свои атаки можно отозвать в панели слева.\n" +
		"5. Матч длится 15 минут, побеждает тот, у кого больше земли. ПКМ/СКМ или два пальца на трекпаде — " +
		"двигать карту, колесо, щипок, кнопки +/− — зум, M — звук, Esc — меню.")
	help_panel.add_child(help)

	var hint := Label.new()
	hint.text = "ЛКМ — атака · ПКМ/СКМ или WASD — двигать карту · колесо / щипок / +− — зум · 1–8 — карточки · T — развитие · F11 — окно/экран · Esc — меню"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	hint.offset_top = -40
	hint.offset_bottom = -12
	add_child(hint)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="):
			_screenshot(a.get_slice("=", 1))


func _start() -> void:
	var settings = get_node_or_null("/root/Settings")
	if settings != null:
		settings.nickname = nick_edit.text.strip_edges() if nick_edit.text.strip_edges() != "" else "Игрок"
		settings.save()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	if cb.is_valid():
		b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _screenshot(path: String) -> void:
	for i in 6:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved to ", path)
	get_tree().quit()
