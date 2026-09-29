extends Control
## In-game overlay: top bar (exit, resources), bottom action bar, province panel, toasts, game-over screen.

const ThemeFactory := preload("res://scripts/ui/theme_factory.gd")
const Rules := preload("res://scripts/sim/rules.gd")

enum Mode { NONE, BUILD_CITY, BUILD_PORT, HIRE, ATTACK }

signal mode_selected(mode: int)
signal exit_pressed
signal attack_from_selected(province_id: int)
signal menu_requested

var gold_label: Label
var army_label: Label
var month_label: Label
var status_label: Label
var toast_label: Label
var info_panel: PanelContainer
var info_title: Label
var info_lines: Label
var info_attack_button: Button
var overlay: Control
var overlay_label: Label
var mode_buttons: Dictionary = {}
var button_group := ButtonGroup.new()
var toast_tween: Tween
var _syncing := false
var _info_province := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = ThemeFactory.make()
	button_group.allow_unpress = true
	_build_top_bar()
	_build_bottom_bar()
	_build_info_panel()
	_build_toast()
	_build_overlay()


# ------------------------------------------------------------------ construction

func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = 8
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)

	var exit_button := Button.new()
	exit_button.text = "Выход"
	exit_button.custom_minimum_size = Vector2(110, 40)
	exit_button.pressed.connect(func(): exit_pressed.emit())
	bar.add_child(exit_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	var panel := PanelContainer.new()
	bar.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	gold_label = Label.new()
	army_label = Label.new()
	month_label = Label.new()
	for l in [gold_label, army_label, month_label]:
		row.add_child(l)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = SIZE_EXPAND_FILL
	spacer2.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(spacer2)


func _build_bottom_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	bar.offset_top = -60
	bar.offset_bottom = -8
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 10)
	add_child(bar)
	var defs := [
		[Mode.BUILD_CITY, "Построить город (%d)" % Rules.CITY_COST],
		[Mode.BUILD_PORT, "Построить порт (%d)" % Rules.PORT_COST],
		[Mode.HIRE, "Нанять войска (%d)" % Rules.HIRE_COST],
		[Mode.ATTACK, "Атаковать"],
	]
	for d in defs:
		var b := Button.new()
		b.text = d[1]
		b.toggle_mode = true
		b.button_group = button_group
		b.custom_minimum_size = Vector2(210, 48)
		b.toggled.connect(_on_mode_toggled.bind(d[0]))
		bar.add_child(b)
		mode_buttons[d[0]] = b
	var net := Button.new()
	net.text = "Сетевая игра"
	net.disabled = true
	net.tooltip_text = "Появится на этапе 5"
	net.custom_minimum_size = Vector2(170, 48)
	bar.add_child(net)

	status_label = Label.new()
	status_label.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	status_label.offset_top = -92
	status_label.offset_bottom = -64
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_label)


func _build_info_panel() -> void:
	info_panel = PanelContainer.new()
	info_panel.set_anchors_and_offsets_preset(PRESET_CENTER_RIGHT)
	info_panel.offset_left = -290
	info_panel.offset_right = -8
	info_panel.offset_top = -110
	info_panel.offset_bottom = 110
	info_panel.visible = false
	add_child(info_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	info_panel.add_child(box)
	info_title = Label.new()
	info_title.add_theme_font_size_override("font_size", 20)
	box.add_child(info_title)
	info_lines = Label.new()
	box.add_child(info_lines)
	info_attack_button = Button.new()
	info_attack_button.text = "Атаковать отсюда"
	info_attack_button.visible = false
	info_attack_button.pressed.connect(func(): attack_from_selected.emit(_info_province))
	box.add_child(info_attack_button)


func _build_toast() -> void:
	toast_label = Label.new()
	toast_label.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	toast_label.offset_top = 70
	toast_label.offset_bottom = 110
	toast_label.offset_left = -400
	toast_label.offset_right = 400
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 20)
	toast_label.modulate.a = 0.0
	add_child(toast_label)


func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -90
	panel.offset_bottom = 90
	overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	overlay_label = Label.new()
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.add_theme_font_size_override("font_size", 28)
	box.add_child(overlay_label)
	var b := Button.new()
	b.text = "В главное меню"
	b.pressed.connect(func(): menu_requested.emit())
	box.add_child(b)


# ------------------------------------------------------------------ api

func _on_mode_toggled(pressed: bool, mode: int) -> void:
	if _syncing:
		return
	mode_selected.emit(mode if pressed else Mode.NONE)


func set_mode(mode: int) -> void:
	_syncing = true
	for m in mode_buttons:
		mode_buttons[m].button_pressed = (m == mode)
	_syncing = false
	match mode:
		Mode.BUILD_CITY:
			status_label.text = "Кликните по своей провинции, где построить город (Esc — отмена)"
		Mode.BUILD_PORT:
			status_label.text = "Кликните по береговой клетке своей провинции (Esc — отмена)"
		Mode.HIRE:
			status_label.text = "Кликните по своей провинции с городом (Esc — отмена)"
		Mode.ATTACK:
			status_label.text = "Выберите свою провинцию с войсками"
		_:
			status_label.text = ""


func set_status(text: String) -> void:
	status_label.text = text


func set_resources(gold: int, income: int, army: int, month: int) -> void:
	gold_label.text = "Золото: %d (+%d/мес)" % [gold, income]
	army_label.text = "Армия: %d" % army
	month_label.text = "Месяц %d" % month


func show_province(title: String, lines: String, can_attack_from: bool, province_id: int) -> void:
	_info_province = province_id
	info_title.text = title
	info_lines.text = lines
	info_attack_button.visible = can_attack_from
	info_panel.visible = true


func hide_province() -> void:
	info_panel.visible = false


func toast(text: String, color: Color = Color(1, 0.95, 0.8)) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_label.modulate.a = 1.0
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6).set_delay(2.2)


func show_game_over(text: String) -> void:
	overlay_label.text = text
	overlay.visible = true
