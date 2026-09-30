extends Control
## In-game menu (Esc): continue, sound, admin code, main menu, quit. Pauses the game while open.

const ThemeFactory := preload("res://scripts/ui/theme_factory.gd")

signal mute_toggled
signal admin_code(code: String)

var sound_button: Button
var code_edit: LineEdit


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = ThemeFactory.make()
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -190
	panel.offset_bottom = 190
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "МЕНЮ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	_button(box, "Продолжить", close)
	sound_button = _button(box, "Звук: вкл", func(): mute_toggled.emit())
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	box.add_child(code_row)
	code_edit = LineEdit.new()
	code_edit.placeholder_text = "Секретный код"
	code_edit.max_length = 12
	code_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	code_edit.custom_minimum_size = Vector2(0, 40)
	code_edit.text_submitted.connect(func(_t): _submit_code())
	code_row.add_child(code_edit)
	var ok := Button.new()
	ok.text = "OK"
	ok.custom_minimum_size = Vector2(60, 40)
	ok.pressed.connect(_submit_code)
	code_row.add_child(ok)
	_button(box, "В главное меню", _to_menu)
	if not OS.has_feature("web"):
		_button(box, "Выйти на рабочий стол", func(): get_tree().quit())


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _submit_code() -> void:
	var code := code_edit.text.strip_edges()
	code_edit.text = ""
	if code != "":
		admin_code.emit(code)
		close()


func set_muted(muted: bool) -> void:
	sound_button.text = "Звук: выкл" if muted else "Звук: вкл"


func open() -> void:
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
