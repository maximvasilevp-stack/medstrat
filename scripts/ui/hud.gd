extends Control
## In-match overlay: exit button, match timer, leaderboard, building cards, army/gold panel,
## attack-size slider, toasts and the result screen.

const ThemeFactory := preload("res://scripts/ui/theme_factory.gd")
const PixelSprites := preload("res://scripts/map/pixel_sprites.gd")
const Names := preload("res://scripts/sim/names.gd")
const Rules := preload("res://scripts/sim/rules.gd")

signal mode_selected(kind: String)      # "" = no placement mode
signal exit_pressed
signal attack_size_changed(ratio: float)
signal menu_requested
signal continue_requested

const CARDS := [
	["defense", "ЗАЩИТА", PixelSprites.TOWER],
	["city", "ГОРОД", PixelSprites.CITY],
	["port", "ПОРТ", PixelSprites.PORT],
]

var world
var human: int = 1
var timer_bar: ProgressBar
var timer_label: Label
var lb_rows: Array = []
var army_value: Label
var army_cap: Label
var army_bar: ProgressBar
var army_rate: Label
var gold_value: Label
var gold_rate: Label
var attack_slider: HSlider
var attack_label: Label
var attack_troops: Label
var cards: Dictionary = {}
var card_costs: Dictionary = {}
var card_group := ButtonGroup.new()
var status_label: Label
var toast_label: Label
var toast_tween: Tween
var overlay: Control
var overlay_title: Label
var overlay_body: Label
var overlay_continue: Button
var _syncing := false
var _lb_timer := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = ThemeFactory.make()
	card_group.allow_unpress = true
	_build_top()
	_build_leaderboard()
	_build_cards()
	_build_resources()
	_build_toast()
	_build_overlay()


func setup(w) -> void:
	world = w
	human = w.human
	attack_slider.value = w.factions[human]["attack_size"]


# ------------------------------------------------------------------ construction helpers

static func _label(text: String, size: int, color: Color = ThemeFactory.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	return l


static func _bar(fill: Color, height: int) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = 1.0
	b.custom_minimum_size = Vector2(0, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.06, 0.05)
	bg.set_corner_radius_all(0)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(0)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = MOUSE_FILTER_IGNORE
	return b


static func _icon(rows: Array, key: String, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = PixelSprites.texture(rows, key)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = size
	t.mouse_filter = MOUSE_FILTER_IGNORE
	return t


func _build_top() -> void:
	var exit_button := Button.new()
	exit_button.text = "Выход"
	exit_button.position = Vector2(12, 12)
	exit_button.custom_minimum_size = Vector2(110, 38)
	exit_button.pressed.connect(func(): exit_pressed.emit())
	add_child(exit_button)

	timer_bar = _bar(Color(0.36, 0.78, 0.36), 12)
	timer_bar.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	timer_bar.offset_left = -260
	timer_bar.offset_right = 260
	timer_bar.offset_top = 14
	timer_bar.offset_bottom = 26
	add_child(timer_bar)
	timer_label = _label("", 12)
	timer_label.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	timer_label.offset_left = -260
	timer_label.offset_right = 260
	timer_label.offset_top = 28
	timer_label.offset_bottom = 46
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(timer_label)


func _build_leaderboard() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	panel.offset_left = -310
	panel.offset_right = -12
	panel.offset_top = 12
	panel.offset_bottom = 12
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(_label("ТАБЛИЦА ЛИДЕРОВ", 13))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 3)
	box.add_child(grid)
	for h in ["#", "", "ИМЯ", "ЗЕМЛЯ"]:
		var l := _label(h, 10, ThemeFactory.TEXT_DIM)
		if h == "ЗЕМЛЯ":
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			l.size_flags_horizontal = SIZE_EXPAND_FILL
		grid.add_child(l)
	for i in 4:
		var rank := _label("", 13)
		rank.custom_minimum_size = Vector2(32, 0)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = SIZE_SHRINK_CENTER
		swatch.mouse_filter = MOUSE_FILTER_IGNORE
		var name := _label("", 13)
		name.custom_minimum_size = Vector2(150, 0)
		name.clip_text = true
		var share := _label("", 13)
		share.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		share.size_flags_horizontal = SIZE_EXPAND_FILL
		for n in [rank, swatch, name, share]:
			grid.add_child(n)
		lb_rows.append({"rank": rank, "swatch": swatch, "name": name, "share": share})


func _build_cards() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	bar.offset_top = -214
	bar.offset_bottom = -130
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 8)
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bar)
	for d in CARDS:
		var kind: String = d[0]
		var rows: Array = d[2]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = card_group
		b.custom_minimum_size = Vector2(100, 84)
		b.toggled.connect(_on_card_toggled.bind(kind))
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 2)
		b.add_child(box)
		box.add_child(_icon(rows, kind, Vector2(40, 30)))
		var title := _label(d[1], 11)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)
		var cost := _label("", 12, Color(1.0, 0.45, 0.4))
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(cost)
		bar.add_child(b)
		cards[kind] = b
		card_costs[kind] = cost
	var plus := Button.new()
	plus.disabled = true
	plus.tooltip_text = "Новые постройки появятся позже"
	plus.custom_minimum_size = Vector2(84, 84)
	var pbox := CenterContainer.new()
	pbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	pbox.mouse_filter = MOUSE_FILTER_IGNORE
	plus.add_child(pbox)
	pbox.add_child(_icon(PixelSprites.PLUS, "plus", Vector2(28, 28)))
	bar.add_child(plus)

	status_label = _label("", 13)
	status_label.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	status_label.offset_top = -238
	status_label.offset_bottom = -216
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_label)


func _build_resources() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -122
	panel.offset_bottom = -10
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	box.add_child(row)

	var army := VBoxContainer.new()
	army.size_flags_horizontal = SIZE_EXPAND_FILL
	army.add_theme_constant_override("separation", 2)
	row.add_child(army)
	army.add_child(_label("АРМИЯ", 10, ThemeFactory.TEXT_DIM))
	var army_row := HBoxContainer.new()
	army_row.add_theme_constant_override("separation", 8)
	army.add_child(army_row)
	army_row.add_child(_icon(PixelSprites.ARMY, "army", Vector2(22, 26)))
	army_value = _label("0", 26)
	army_row.add_child(army_value)
	army_cap = _label("/ 0", 12, ThemeFactory.TEXT_DIM)
	army_cap.size_flags_vertical = SIZE_SHRINK_END
	army_row.add_child(army_cap)
	army_bar = _bar(Color(0.98, 0.33, 0.62), 8)
	army.add_child(army_bar)
	army_rate = _label("", 11, Color(0.55, 0.95, 0.55))
	army.add_child(army_rate)

	var gold := VBoxContainer.new()
	gold.custom_minimum_size = Vector2(190, 0)
	gold.add_theme_constant_override("separation", 2)
	row.add_child(gold)
	var gold_title := _label("Золото", 10, ThemeFactory.TEXT_DIM)
	gold_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold.add_child(gold_title)
	var gold_row := HBoxContainer.new()
	gold_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gold_row.add_theme_constant_override("separation", 8)
	gold.add_child(gold_row)
	gold_row.add_child(_icon(PixelSprites.COIN, "coin", Vector2(26, 26)))
	gold_value = _label("0", 24, Color(1.0, 0.85, 0.35))
	gold_row.add_child(gold_value)
	gold_rate = _label("", 11, Color(0.55, 0.95, 0.55))
	gold_rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold.add_child(gold_rate)

	var attack_row := HBoxContainer.new()
	attack_row.add_theme_constant_override("separation", 10)
	box.add_child(attack_row)
	attack_row.add_child(_label("ATTACK SIZE", 10, ThemeFactory.TEXT_DIM))
	attack_label = _label("33%", 12)
	attack_label.custom_minimum_size = Vector2(40, 0)
	attack_row.add_child(attack_label)
	attack_slider = HSlider.new()
	attack_slider.min_value = 0.05
	attack_slider.max_value = 1.0
	attack_slider.step = 0.01
	attack_slider.value = Rules.DEFAULT_ATTACK_SIZE
	attack_slider.size_flags_horizontal = SIZE_EXPAND_FILL
	attack_slider.size_flags_vertical = SIZE_SHRINK_CENTER
	attack_slider.value_changed.connect(_on_slider)
	attack_row.add_child(attack_slider)
	attack_troops = _label("", 12)
	attack_troops.custom_minimum_size = Vector2(110, 0)
	attack_troops.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	attack_row.add_child(attack_troops)


func _build_toast() -> void:
	toast_label = _label("", 18)
	toast_label.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	toast_label.offset_top = 56
	toast_label.offset_bottom = 84
	toast_label.offset_left = -400
	toast_label.offset_right = 400
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	panel.offset_left = -240
	panel.offset_right = 240
	panel.offset_top = -170
	panel.offset_bottom = 170
	overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	overlay_title = _label("", 28)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(overlay_title)
	overlay_body = _label("", 14)
	overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(overlay_body)
	overlay_continue = Button.new()
	overlay_continue.text = "Смотреть дальше"
	overlay_continue.pressed.connect(func():
		overlay.visible = false
		continue_requested.emit())
	box.add_child(overlay_continue)
	var b := Button.new()
	b.text = "В главное меню"
	b.pressed.connect(func(): menu_requested.emit())
	box.add_child(b)


# ------------------------------------------------------------------ events

func _on_card_toggled(pressed: bool, kind: String) -> void:
	if _syncing:
		return
	mode_selected.emit(kind if pressed else "")


func _on_slider(v: float) -> void:
	attack_label.text = "%d%%" % int(round(v * 100.0))
	attack_size_changed.emit(v)


func set_mode(kind: String) -> void:
	_syncing = true
	for k in cards:
		cards[k].button_pressed = (k == kind)
	_syncing = false
	match kind:
		"city":
			status_label.text = "Кликните по своей земле, где построить город (+войска, +лимит). Esc — отмена"
		"port":
			status_label.text = "Кликните по своему берегу: порт даёт золото и высадки с моря. Esc — отмена"
		"defense":
			status_label.text = "Кликните по своей земле: защита удорожает захват ваших клеток. Esc — отмена"
		_:
			status_label.text = "Клик по чужой или ничьей земле — атака долей армии (ползунок внизу)"


func toast(text: String, color: Color = Color(1, 0.95, 0.8)) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_label.modulate.a = 1.0
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6).set_delay(2.2)


func show_result(title: String, body: String, can_continue: bool) -> void:
	overlay_title.text = title
	overlay_body.text = body
	overlay_continue.visible = can_continue
	overlay.visible = true


# ------------------------------------------------------------------ per-frame refresh

func refresh(delta: float) -> void:
	if world == null:
		return
	var f: Dictionary = world.factions[human]
	var elapsed: float = world.seconds()
	var remaining: int = maxi(0, int(Rules.MATCH_SECONDS - elapsed))
	timer_bar.value = clampf(elapsed / Rules.MATCH_SECONDS, 0.0, 1.0)
	@warning_ignore("integer_division")
	timer_label.text = "Осталось %d:%02d" % [remaining / 60, remaining % 60]

	var cap: float = world.max_troops_of(human)
	army_value.text = Names.short_number(f["troops"])
	army_cap.text = "/ " + Names.short_number(cap)
	army_bar.value = clampf(f["troops"] / maxf(1.0, cap), 0.0, 1.0)
	army_rate.text = "+%s / сек" % Names.short_number(world.growth_of(human))
	gold_value.text = Names.short_number(f["gold"])
	gold_rate.text = "+%s / сек" % Names.short_number(world.gold_rate_of(human))
	attack_troops.text = Names.short_number(f["troops"] * attack_slider.value) + " войск"
	for kind in card_costs:
		var cost: int = world.building_cost(kind, human)
		var l: Label = card_costs[kind]
		l.text = Names.short_number(cost)
		l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35) if f["gold"] >= cost else Color(1.0, 0.45, 0.4))

	_lb_timer -= delta
	if _lb_timer <= 0.0:
		_lb_timer = 0.5
		_refresh_leaderboard()


func _refresh_leaderboard() -> void:
	var ranking: Array = world.ranking()
	var rows: Array = []
	for i in mini(3, ranking.size()):
		rows.append([i + 1, ranking[i]])
	var my_rank: int = world.rank_of(human)
	if my_rank > 3:
		rows.append([my_rank, world.factions[human]])
	for i in lb_rows.size():
		var r: Dictionary = lb_rows[i]
		var visible := i < rows.size()
		for k in r:
			r[k].visible = visible
		if not visible:
			continue
		var f: Dictionary = rows[i][1]
		r["rank"].text = "#%d" % rows[i][0]
		r["swatch"].color = f["color"]
		r["name"].text = f["name"]
		var share: float = world.land_share(f["id"]) * 100.0
		r["share"].text = ("%.2f%%" if share < 1.0 else "%.1f%%") % share
		var c: Color = Color(1, 0.8, 0.5) if f["id"] == human else ThemeFactory.TEXT
		r["name"].add_theme_color_override("font_color", c)
		r["rank"].add_theme_color_override("font_color", c)
