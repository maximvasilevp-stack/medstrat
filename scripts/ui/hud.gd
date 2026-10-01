extends Control
## In-match overlay: exit and sound buttons, land goal, leaderboard, action cards with hotkeys,
## army/gold panel with the attack-size slider, attacks panel, cursor tooltip, toasts, result screen.

const ThemeFactory := preload("res://scripts/ui/theme_factory.gd")
const PixelSprites := preload("res://scripts/map/pixel_sprites.gd")
const Names := preload("res://scripts/sim/names.gd")
const Rules := preload("res://scripts/sim/rules.gd")
const Charts := preload("res://scripts/ui/charts.gd")
const Content := preload("res://scripts/sim/content.gd")
const Resources := preload("res://scripts/sim/resources.gd")
const Missions := preload("res://scripts/sim/missions.gd")
const Achievements := preload("res://scripts/sim/achievements.gd")
const BotBrain := preload("res://scripts/sim/bot_brain.gd")
const NewsFeed := preload("res://scripts/ui/news_feed.gd")
const Economy := preload("res://scripts/sim/economy.gd")
const SPEEDS := [1.0, 2.0, 3.0, 0.0]
const SPEED_LABELS := ["▶ 1×", "▶▶ 2×", "▶▶▶ 3×", "⏸ пауза"]

signal mode_selected(kind: String)      # "" = no placement / targeting mode
signal research(tech: String)
signal admin_code(code: String)
signal zoom_requested(step: int)
signal tax_changed(level: int)
signal decree(kind: String)
signal event_choice(choice: int)
signal hire(minister: String)
signal fire(minister: String)
signal agitate(party: String)
signal bill(key: String)
signal budget_changed(item: String, level: int)
signal repeal(key: String)
signal reform(axis: String, option: String)
signal project(key: String)
signal gift(target: int)
signal pact(target: int)
signal trade_deal(target: int)
signal alliance(target: int)
signal vassalize(target: int)
signal spy(target: int, op: String)
signal autopilot_changed(task: String, on: bool)
signal speed_changed(speed: float)
signal rate_changed(level: int)
signal loan(amount: int)
signal repay(amount: int)
signal emission
signal policy_changed(good: String, policy: String)
signal buy_goods(good: String, amount: int)
signal sell_goods(good: String, amount: int)
signal invest(amount: int)
signal divest(amount: int)
signal tariff_changed(level: int)
signal sanction(target: int, on: bool)
signal exit_pressed
signal attack_size_changed(ratio: float)
signal cancel_attack(target: int)
signal mute_toggled
signal menu_requested
signal continue_requested
signal restart_requested

const CARDS := [
	["defense", "ЗАЩИТА", PixelSprites.TOWER, "1", ThemeFactory.SKY],
	["city", "ГОРОД", PixelSprites.CITY, "2", ThemeFactory.LEMON],
	["port", "ПОРТ", PixelSprites.PORT, "3", ThemeFactory.LEMON],
	["market", "РЫНОК", PixelSprites.MARKET, "4", ThemeFactory.LEMON],
	["barracks", "КАЗАРМЫ", PixelSprites.BARRACKS, "5", ThemeFactory.PEACH],
	["bunker", "БУНКЕР", PixelSprites.BUNKER, "6", ThemeFactory.BLUE],
	["nuke", "ЯД. БОМБА", PixelSprites.ROCKET, "7", ThemeFactory.LAVENDER],
	["mega", "MEGA NUKE", PixelSprites.ROCKET, "8", ThemeFactory.LAVENDER],
]
const CARD_SIZE_DESKTOP := Vector2(84, 84)
const CARD_SIZE_MOBILE := Vector2(72, 66)
var CARD_SIZE := CARD_SIZE_DESKTOP
var mobile := false

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
var attacks_panel: PanelContainer
var attacks_box: VBoxContainer
var tooltip: PanelContainer
var tooltip_label: Label
var tech_panel: PanelContainer
var tech_rows: Dictionary = {}
var tech_gold: Label
var people_block: Button
var people_panel: PanelContainer
var people_labels: Dictionary = {}
var people_bar: ProgressBar
var tax_buttons: Array = []
var tax_group := ButtonGroup.new()
var decree_buttons: Dictionary = {}
var event_panel: PanelContainer
var event_title: Label
var event_text: Label
var event_buttons: Array = []
var approval_value: Label
var approval_bar: ProgressBar
var election_label: Label
var gov_panel: PanelContainer
var gov_tabs: Array = []
var gov_pages: Array = []
var gov_gold: Label
var seats_chart
var party_rows: Dictionary = {}
var minister_rows: Dictionary = {}
var bill_rows: Dictionary = {}
var stat_charts: Dictionary = {}
var income_chart
var building_rows: Dictionary = {}
var budget_rows: Dictionary = {}
var budget_total: Label
var reform_rows: Dictionary = {}
var reform_cost_label: Label
var project_rows: Dictionary = {}
var diplo_box: VBoxContainer
var diplo_rows: Dictionary = {}
var gov_filters: Dictionary = {}
var resource_rows: Dictionary = {}
var season_label: Label
var news
var speed_button: Button
var speed_index := 0
var autopilot_button: Button
var missions_panel: PanelContainer
var mission_rows: Array = []
var profile_label: Label
var achievement_labels: Dictionary = {}
var autopilot_panel: PanelContainer
var autopilot_buttons: Dictionary = {}
var _autopilot_syncing := false
var spy_target: OptionButton
var spy_status: Label
var spy_rows: Dictionary = {}
var econ_summary: Label
var econ_cycle: Label
var econ_rate: Label
var econ_debt: Label
var econ_buttons: Dictionary = {}
var econ_rows: Dictionary = {}
var _econ_syncing := false
var econ_people: Label
var econ_budget: Label
var econ_index: Label
var tariff_buttons: Array = []
var wonder_rows: Dictionary = {}
var gov_tab_index := 0
var _tax_syncing := false
var overlay: Control
var overlay_title: Label
var overlay_body: Label
var overlay_continue: Button
var _syncing := false
var _lb_timer := 0.0
var _attacks_timer := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = ThemeFactory.make()
	var settings = get_node_or_null("/root/Settings")
	mobile = settings != null and settings.mobile
	if mobile:
		CARD_SIZE = CARD_SIZE_MOBILE
		theme.default_font_size = 13
	card_group.allow_unpress = true
	_build_top()
	_build_leaderboard()
	_build_cards()
	_build_resources()
	_build_attacks_panel()
	_build_zoom_buttons()
	_build_tech_panel()
	_build_people_panel()
	_build_gov_panel()
	_build_missions_panel()
	_build_autopilot_panel()
	_build_event_panel()
	_build_tooltip()
	_build_toast()
	_build_overlay()


func setup(w) -> void:
	world = w
	human = w.human
	attack_slider.value = w.factions[human]["attack_size"]


# ------------------------------------------------------------------ construction helpers

## Centre a panel of the given size; on small screens it fills the screen with a margin instead.
func _place_panel(p: Control, w: float, h: float, margin: float = 8.0) -> void:
	if mobile:
		p.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		p.offset_left = margin
		p.offset_right = -margin
		p.offset_top = margin + 44.0
		p.offset_bottom = -margin
	else:
		p.set_anchors_and_offsets_preset(PRESET_CENTER)
		p.offset_left = -w / 2.0
		p.offset_right = w / 2.0
		p.offset_top = -h / 2.0
		p.offset_bottom = h / 2.0

static func _label(text: String, size: int, color: Color = ThemeFactory.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	if size == 11 and color == ThemeFactory.TEXT_DIM:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = SIZE_EXPAND_FILL
	return l


static func _bar(fill: Color, height: int) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = 1.0
	b.custom_minimum_size = Vector2(0, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = ThemeFactory.FRAME
	bg.set_corner_radius_all(height)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(height)
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
	var row := HBoxContainer.new()
	row.position = Vector2(12, 12)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var menu_button := Button.new()
	menu_button.text = "≡ Меню"
	menu_button.custom_minimum_size = Vector2(110, 36)
	menu_button.tooltip_text = "Esc: звук, код, выход"
	menu_button.pressed.connect(func(): exit_pressed.emit())
	row.add_child(menu_button)
	speed_button = Button.new()
	speed_button.text = SPEED_LABELS[0]
	speed_button.custom_minimum_size = Vector2(70 if mobile else 90, 36)
	speed_button.tooltip_text = "Скорость игры (пробел — пауза)"
	speed_button.pressed.connect(_cycle_speed)
	row.add_child(speed_button)
	autopilot_button = Button.new()
	autopilot_button.text = "Авто" if mobile else "Автопилот"
	autopilot_button.custom_minimum_size = Vector2(60, 36)
	autopilot_button.tooltip_text = "Клавиша A: советники развивают страну сами"
	autopilot_button.pressed.connect(toggle_autopilot)
	row.add_child(autopilot_button)
	news = NewsFeed.new()
	news.position = Vector2(12, 58)
	news.size = Vector2(300, 200)
	news.visible = not mobile
	add_child(news)

	timer_bar = _bar(ThemeFactory.LIME.darkened(0.15), 12)
	timer_bar.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	timer_bar.offset_left = -60 if mobile else -260
	timer_bar.offset_right = 150 if mobile else 260
	timer_bar.offset_top = 54 if mobile else 14
	timer_bar.offset_bottom = 66 if mobile else 26
	add_child(timer_bar)
	timer_label = _label("", 12)
	timer_label.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	timer_label.offset_left = -60 if mobile else -260
	timer_label.offset_right = 150 if mobile else 260
	timer_label.offset_top = 68 if mobile else 28
	timer_label.offset_bottom = 86 if mobile else 46
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_stylebox_override("normal", ThemeFactory.pill(ThemeFactory.PANEL, 2, 8))
	add_child(timer_label)
	season_label = _label("", 11, ThemeFactory.TEXT_DIM)
	season_label.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	season_label.offset_left = -60 if mobile else -260
	season_label.offset_right = 150 if mobile else 260
	season_label.offset_top = 88 if mobile else 48
	season_label.offset_bottom = 104 if mobile else 64
	season_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	season_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(season_label)


func _build_leaderboard() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	panel.offset_left = -200 if mobile else -310
	panel.offset_right = -6 if mobile else -12
	panel.offset_top = 52 if mobile else 12
	panel.offset_bottom = panel.offset_top
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2 if mobile else 4)
	panel.add_child(box)
	box.add_child(_label("ЛИДЕРЫ" if mobile else "ТАБЛИЦА ЛИДЕРОВ", 11 if mobile else 13))
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
		var name := _label("", 11 if mobile else 13)
		name.custom_minimum_size = Vector2(80 if mobile else 150, 0)
		name.clip_text = true
		var share := _label("", 13)
		share.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		share.size_flags_horizontal = SIZE_EXPAND_FILL
		for n in [rank, swatch, name, share]:
			grid.add_child(n)
		lb_rows.append({"rank": rank, "swatch": swatch, "name": name, "share": share})


func _build_cards() -> void:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 8 if not mobile else 6)
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	if mobile:
		var cscroll := ScrollContainer.new()
		cscroll.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
		cscroll.offset_top = -196
		cscroll.offset_bottom = -124
		cscroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		cscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		add_child(cscroll)
		cscroll.add_child(bar)
	else:
		bar.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
		bar.offset_top = -214
		bar.offset_bottom = -130
		add_child(bar)
	for d in CARDS:
		var kind: String = d[0]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = card_group
		b.custom_minimum_size = CARD_SIZE
		b.toggled.connect(_on_card_toggled.bind(kind))
		var tint: Color = d[4]
		b.add_theme_stylebox_override("normal", ThemeFactory.pill(tint))
		b.add_theme_stylebox_override("hover", ThemeFactory.pill(tint.lightened(0.15)))
		b.add_theme_stylebox_override("pressed", ThemeFactory.pill(ThemeFactory.ORANGE))
		b.add_theme_stylebox_override("disabled", ThemeFactory.pill(Color("#F3EDE6")))
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		box.offset_top = 4
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 1)
		b.add_child(box)
		box.add_child(_icon(d[2], kind, Vector2(40, 28)))
		var title := _label(d[1], 10)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)
		var cost := _label("", 12, ThemeFactory.TEXT)
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(cost)
		var key := _label(d[3], 10, ThemeFactory.TEXT_DIM)
		key.position = Vector2(8, 5)
		b.add_child(key)
		bar.add_child(b)
		cards[kind] = b
		card_costs[kind] = cost
	var tech := Button.new()
	tech.custom_minimum_size = CARD_SIZE
	tech.tooltip_text = "Клавиша T"
	tech.pressed.connect(toggle_tech)
	tech.add_theme_stylebox_override("normal", ThemeFactory.pill(ThemeFactory.LIME))
	tech.add_theme_stylebox_override("hover", ThemeFactory.pill(ThemeFactory.LIME.lightened(0.15)))
	tech.add_theme_stylebox_override("pressed", ThemeFactory.pill(ThemeFactory.ORANGE))
	var tbox := VBoxContainer.new()
	tbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	tbox.offset_top = 4
	tbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tbox.mouse_filter = MOUSE_FILTER_IGNORE
	tech.add_child(tbox)
	tbox.add_child(_icon(PixelSprites.LAB, "lab", Vector2(40, 28)))
	var ttitle := _label("РАЗВИТИЕ", 10)
	ttitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tbox.add_child(ttitle)
	var tkey := _label("T", 10, ThemeFactory.TEXT_DIM)
	tkey.position = Vector2(8, 5)
	tech.add_child(tkey)
	bar.add_child(tech)
	var gov := Button.new()
	gov.custom_minimum_size = CARD_SIZE
	gov.tooltip_text = "Клавиша G: Госдума, министры, законы, реформы, нацпроекты, дипломатия"
	gov.pressed.connect(func(): toggle_gov())
	gov.add_theme_stylebox_override("normal", ThemeFactory.pill(ThemeFactory.SKY))
	gov.add_theme_stylebox_override("hover", ThemeFactory.pill(ThemeFactory.SKY.lightened(0.15)))
	gov.add_theme_stylebox_override("pressed", ThemeFactory.pill(ThemeFactory.ORANGE))
	var gbox := VBoxContainer.new()
	gbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	gbox.offset_top = 4
	gbox.alignment = BoxContainer.ALIGNMENT_CENTER
	gbox.mouse_filter = MOUSE_FILTER_IGNORE
	gov.add_child(gbox)
	gbox.add_child(_icon(PixelSprites.BARRACKS, "gov", Vector2(40, 28)))
	var gtitle := _label("ПРАВИТ-ВО", 10)
	gtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gbox.add_child(gtitle)
	var gkey := _label("G", 10, ThemeFactory.TEXT_DIM)
	gkey.position = Vector2(8, 5)
	gov.add_child(gkey)
	bar.add_child(gov)
	_menu_card(bar, "ЗАДАНИЯ", "Q", PixelSprites.COIN, ThemeFactory.LEMON, "Клавиша Q: задания, достижения, профиль", toggle_missions)

	var status_box := CenterContainer.new()
	status_box.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	status_box.offset_top = -244
	status_box.offset_bottom = -216
	status_box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(status_box)
	status_label = _label("", 13)
	status_label.add_theme_stylebox_override("normal", ThemeFactory.pill(ThemeFactory.LEMON, 6, 12))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.visible = false
	status_box.add_child(status_label)


func _build_resources() -> void:
	var panel := PanelContainer.new()
	if mobile:
		panel.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
		panel.offset_left = 6
		panel.offset_right = -6
		panel.offset_top = -118
		panel.offset_bottom = -6
	else:
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
	row.add_theme_constant_override("separation", 12 if mobile else 30)
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
	army_value = _label("0", 20 if mobile else 26)
	army_row.add_child(army_value)
	army_cap = _label("/ 0", 12, ThemeFactory.TEXT_DIM)
	army_cap.size_flags_vertical = SIZE_SHRINK_END
	army_row.add_child(army_cap)
	army_bar = _bar(ThemeFactory.PEACH, 8)
	army.add_child(army_bar)
	army_rate = _label("", 11, ThemeFactory.GREEN)
	army.add_child(army_rate)

	var gold := VBoxContainer.new()
	gold.custom_minimum_size = Vector2(110 if mobile else 190, 0)
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
	gold_value = _label("0", 18 if mobile else 24, Color("#D9731F"))
	gold_row.add_child(gold_value)
	gold_rate = _label("", 11, ThemeFactory.GREEN)
	gold_rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold.add_child(gold_rate)

	people_block = Button.new()
	people_block.custom_minimum_size = Vector2(100 if mobile else 170, 0)
	people_block.tooltip_text = "Народ: налоги, указы, выборы (P)"
	people_block.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	people_block.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	people_block.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	people_block.pressed.connect(toggle_people)
	row.add_child(people_block)
	var people := VBoxContainer.new()
	people.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	people.mouse_filter = MOUSE_FILTER_IGNORE
	people.add_theme_constant_override("separation", 2)
	people_block.add_child(people)
	var people_title := _label("Народ", 10, ThemeFactory.TEXT_DIM)
	people_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	people.add_child(people_title)
	approval_value = _label("60%", 18 if mobile else 22, ThemeFactory.GREEN)
	approval_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	people.add_child(approval_value)
	approval_bar = _bar(ThemeFactory.LIME.darkened(0.15), 6)
	people.add_child(approval_bar)
	election_label = _label("", 11, ThemeFactory.TEXT_DIM)
	election_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	people.add_child(election_label)

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


func _build_attacks_panel() -> void:
	attacks_panel = PanelContainer.new()
	attacks_panel.set_anchors_and_offsets_preset(PRESET_CENTER_LEFT)
	attacks_panel.offset_left = 6 if mobile else 12
	attacks_panel.offset_right = 186 if mobile else 262
	attacks_panel.offset_top = -80
	attacks_panel.offset_bottom = 80
	attacks_panel.visible = false
	add_child(attacks_panel)
	attacks_box = VBoxContainer.new()
	attacks_box.add_theme_constant_override("separation", 4)
	attacks_panel.add_child(attacks_box)


func _build_zoom_buttons() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	box.offset_left = -50 if mobile else -84
	box.offset_right = -6 if mobile else -44
	box.offset_top = -290 if mobile else -224
	box.offset_bottom = -206 if mobile else -140
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	for d in [["+", 1], ["−", -1]]:
		var b := Button.new()
		b.text = d[0]
		b.custom_minimum_size = Vector2(40, 38)
		b.add_theme_font_size_override("font_size", 20)
		b.tooltip_text = "Зум: колесо, щипок на трекпаде, клавиши + и −, F11 — во весь экран"
		var step: int = d[1]
		b.pressed.connect(func(): zoom_requested.emit(step))
		box.add_child(b)


func _build_tech_panel() -> void:
	tech_panel = PanelContainer.new()
	_place_panel(tech_panel, 660, 500)
	tech_panel.visible = false
	add_child(tech_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	tech_panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := _label("РАЗВИТИЕ", 20)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(title)
	tech_gold = _label("", 14, Color("#D9731F"))
	head.add_child(tech_gold)
	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(36, 32)
	close.pressed.connect(toggle_tech)
	head.add_child(close)
	var thint := _label("Технологии покупаются за золото и действуют до конца матча.", 11, ThemeFactory.TEXT_DIM)
	thint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	thint.custom_minimum_size = Vector2(620, 0)
	box.add_child(thint)
	var tscroll := ScrollContainer.new()
	tscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tscroll.size_flags_vertical = SIZE_EXPAND_FILL
	tscroll.custom_minimum_size = Vector2(0, 220 if mobile else 400)
	box.add_child(tscroll)
	var tlist := VBoxContainer.new()
	tlist.size_flags_horizontal = SIZE_EXPAND_FILL
	tlist.add_theme_constant_override("separation", 6)
	tscroll.add_child(tlist)
	for key in Rules.TECH_ORDER + Rules.EXTRA_TECH_ORDER:
		var t: Dictionary = world_tech_def(key)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		tlist.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		text.add_child(_label(t["name"], 14))
		var desc := _label(t["desc"], 11, ThemeFactory.TEXT_DIM)
		text.add_child(desc)
		var level := _label("", 13)
		level.custom_minimum_size = Vector2(44, 0)
		level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(level)
		var button := Button.new()
		button.custom_minimum_size = Vector2(170, 36)
		var k: String = key
		button.pressed.connect(func(): research.emit(k))
		row.add_child(button)
		tech_rows[key] = {"level": level, "button": button}


func _build_people_panel() -> void:
	people_panel = PanelContainer.new()
	_place_panel(people_panel, 660, 580)
	people_panel.visible = false
	add_child(people_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	people_panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := _label("НАРОД", 20)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(36, 32)
	close.pressed.connect(toggle_people)
	head.add_child(close)
	for key in ["population", "approval", "target", "election", "effects"]:
		var l := _label("", 13)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
		people_labels[key] = l
	people_bar = _bar(ThemeFactory.LIME.darkened(0.15), 10)
	box.add_child(people_bar)
	var hint := _label("Одобрение тянется к цели: налоги и войны его снижают, рынки и города поднимают. Ниже 25% люди уходят с окраин. Раз в 3 минуты выборы: меньше 50% — поражение и штраф на минуту.", 11, ThemeFactory.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(620, 0)
	box.add_child(hint)

	box.add_child(_label("НАЛОГИ", 12, ThemeFactory.TEXT_DIM))
	var taxes := HBoxContainer.new()
	taxes.add_theme_constant_override("separation", 6)
	box.add_child(taxes)
	tax_group.allow_unpress = false
	var names := ["Нет", "Низкие", "Средние", "Высокие"]
	for i in 4:
		var b := Button.new()
		b.text = names[i]
		b.toggle_mode = true
		b.button_group = tax_group
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 34)
		var level := i
		b.toggled.connect(func(on):
			if on and not _tax_syncing:
				tax_changed.emit(level))
		taxes.add_child(b)
		tax_buttons.append(b)

	var dscroll := ScrollContainer.new()
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dscroll.custom_minimum_size = Vector2(0, 150)
	dscroll.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(dscroll)
	var dlist := VBoxContainer.new()
	dlist.size_flags_horizontal = SIZE_EXPAND_FILL
	dlist.add_theme_constant_override("separation", 6)
	dscroll.add_child(dlist)
	dlist.add_child(_label("УКАЗЫ", 12, ThemeFactory.TEXT_DIM))
	var decrees := [
		["propaganda", "Пропаганда", "+12 одобрение", "%s золота" % Names.short_number(Rules.PROPAGANDA_COST)],
		["festival", "Праздник", "+20 одобрение, +10% роста армии на минуту", "%s золота" % Names.short_number(Rules.FESTIVAL_COST)],
		["mobilize", "Мобилизация", "+15% лимита войск сразу, −15 одобрение", "бесплатно"],
	]
	for key in Rules.EXTRA_DECREE_ORDER:
		var d: Dictionary = Rules.EXTRA_DECREES[key]
		decrees.append([key, d["name"], d["desc"], ("%s золота" % Names.short_number(d["cost"])) if d["cost"] > 0 else "бесплатно"])
	for d in decrees:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		dlist.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		text.add_child(_label(d[1], 14))
		text.add_child(_label("%s · %s" % [d[2], d[3]], 11, ThemeFactory.TEXT_DIM))
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 34)
		b.text = "Издать"
		var kind: String = d[0]
		b.pressed.connect(func(): decree.emit(kind))
		row.add_child(b)
		decree_buttons[kind] = b


const GOV_TABS := ["Госдума", "Министры", "Законы", "Постройки", "Бюджет", "Реформы", "Проекты", "Дипломатия", "Разведка", "Ресурсы", "Экономика", "Графики"]


func _build_gov_panel() -> void:
	gov_panel = PanelContainer.new()
	_place_panel(gov_panel, 1080, 660)
	gov_panel.visible = false
	add_child(gov_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	gov_panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var title := _label("ПРАВИТЕЛЬСТВО", 20)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(title)
	if not mobile:
		head.add_child(_label("%d решений" % Content.item_count(), 12, ThemeFactory.TEXT_DIM))
	gov_gold = _label("", 14, Color("#D9731F"))
	head.add_child(gov_gold)
	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(36, 32)
	close.pressed.connect(toggle_gov)
	head.add_child(close)
	var tabs: Container
	if mobile:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		tabs = grid
	else:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 4)
		tabs = hb
	box.add_child(tabs)
	var group := ButtonGroup.new()
	for i in GOV_TABS.size():
		var b := Button.new()
		b.text = GOV_TABS[i]
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 36)
		b.add_theme_font_size_override("font_size", 12)
		var idx := i
		b.pressed.connect(func(): show_gov_tab(idx))
		tabs.add_child(b)
		gov_tabs.append(b)
	for i in GOV_TABS.size():
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(0, 200 if mobile else 480)
		scroll.visible = i == 0
		box.add_child(scroll)
		var page := VBoxContainer.new()
		page.size_flags_horizontal = SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 6)
		scroll.add_child(page)
		gov_pages.append(page)

	# --- Duma
	var duma: VBoxContainer = gov_pages[0]
	seats_chart = Charts.BarChart.new()
	seats_chart.custom_minimum_size = Vector2(0, 100)
	duma.add_child(seats_chart)
	duma.add_child(_label("Места распределяются на каждых выборах по тому, как вы правите: постройки, законы, реформы и войны двигают партии. Правящая партия даёт бонус. Агитация добавляет партии голосов до следующих выборов.", 11, ThemeFactory.TEXT_DIM))
	for party in Rules.PARTY_ORDER:
		var p: Dictionary = Rules.PARTIES[party]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		duma.add_child(row)
		var swatch := ColorRect.new()
		swatch.color = Color(p["color"])
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = SIZE_SHRINK_CENTER
		swatch.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(swatch)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		var name := _label(p["name"], 14)
		text.add_child(name)
		text.add_child(_label("%s · за неё: %s" % [p["bonus"], p["who"]], 11, ThemeFactory.TEXT_DIM))
		var seats := _label("", 14)
		seats.custom_minimum_size = Vector2(70, 0)
		seats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(seats)
		var b := Button.new()
		b.text = "Агитация · " + Names.short_number(Rules.AGITATION_COST)
		b.custom_minimum_size = Vector2(120 if mobile else 170, 34)
		var key: String = party
		b.pressed.connect(func(): agitate.emit(key))
		row.add_child(b)
		party_rows[party] = {"name": name, "seats": seats, "button": b}

	# --- ministers
	var staff: VBoxContainer = gov_pages[1]
	staff.add_child(_label("Найм стоит золота один раз, зарплата списывается каждую секунду. Уволить можно в любой момент.", 11, ThemeFactory.TEXT_DIM))
	_filter_bar(1, staff)
	for key in Rules.MINISTER_ORDER:
		var m: Dictionary = Rules.MINISTERS[key]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		staff.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		text.add_child(_wrap(_label(m["name"], 14)))
		text.add_child(_label("%s · найм %s · зарплата %d/с" % [m["desc"], Names.short_number(m["fee"]), int(m["salary"])], 11, ThemeFactory.TEXT_DIM))
		var b := Button.new()
		b.custom_minimum_size = Vector2(120 if mobile else 170, 34)
		var mk: String = key
		b.pressed.connect(func():
			if world.has_minister(human, mk):
				fire.emit(mk)
			else:
				hire.emit(mk))
		row.add_child(b)
		minister_rows[key] = {"button": b}
		_register_row(1, row, m["cat"], m["name"] + " " + m["desc"])

	# --- bills
	var laws: VBoxContainer = gov_pages[2]
	laws.add_child(_label("Закон проходит, если партии, которые его поддерживают, держат вместе не меньше %d мест. Взнос сгорает в любом случае. Принятый закон можно отменить за полцены." % Rules.BILL_MAJORITY, 11, ThemeFactory.TEXT_DIM))
	_filter_bar(2, laws)
	for key in Rules.BILL_ORDER:
		var bl: Dictionary = Rules.BILLS[key]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		laws.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		text.add_child(_wrap(_label(bl["name"], 14)))
		var support_names: Array = []
		for party in bl["support"]:
			support_names.append(Rules.PARTIES[party]["name"])
		var base_info: String = "%s · за: %s" % [bl["desc"], ", ".join(support_names)]
		var info := _label(base_info, 11, ThemeFactory.TEXT_DIM)
		text.add_child(info)
		var support := _label("", 13)
		support.custom_minimum_size = Vector2(60 if mobile else 90, 0)
		support.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(support)
		var b := Button.new()
		b.custom_minimum_size = Vector2(120 if mobile else 170, 34)
		var bk: String = key
		b.pressed.connect(func():
			if world.has_bill(human, bk):
				repeal.emit(bk)
			else:
				bill.emit(bk))
		row.add_child(b)
		bill_rows[key] = {"button": b, "support": support, "info": info, "base": base_info}
		_register_row(2, row, bl["cat"], bl["name"] + " " + bl["desc"])

	# --- extra buildings
	var builds: VBoxContainer = gov_pages[3]
	builds.add_child(_label("Выберите постройку и кликните по своей земле. Каждая следующая того же типа дороже на 50 %. Постройки двигают партии в Госдуме.", 11, ThemeFactory.TEXT_DIM))
	_filter_bar(3, builds)
	for key in Rules.BUILDING_ORDER:
		var bd: Dictionary = Rules.BUILDINGS[key]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		builds.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		var name := _wrap(_label(bd["name"], 14))
		text.add_child(name)
		text.add_child(_label("%s · нравится: %s" % [bd["desc"], Rules.PARTIES[bd["party"]]["name"]], 11, ThemeFactory.TEXT_DIM))
		var b := Button.new()
		b.custom_minimum_size = Vector2(120 if mobile else 170, 34)
		var kk: String = key
		b.pressed.connect(func():
			gov_panel.visible = false
			mode_selected.emit(kk))
		row.add_child(b)
		building_rows[key] = {"button": b, "name": name}
		_register_row(3, row, bd["cat"], bd["name"] + " " + bd["desc"])

	# --- budget
	var budget: VBoxContainer = gov_pages[4]
	budget.add_child(_label("Каждый уровень стоит золота в секунду пропорционально размеру страны. Меняется мгновенно.", 11, ThemeFactory.TEXT_DIM))
	for key in Rules.BUDGET_ORDER:
		var bg: Dictionary = Rules.BUDGET[key]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		budget.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		text.add_child(_label(bg["name"], 14))
		text.add_child(_label(bg["desc"], 11, ThemeFactory.TEXT_DIM))
		var levels := HBoxContainer.new()
		levels.add_theme_constant_override("separation", 4)
		row.add_child(levels)
		var group2 := ButtonGroup.new()
		var buttons: Array = []
		for level in Rules.BUDGET_MAX + 1:
			var lb := Button.new()
			lb.text = str(level)
			lb.toggle_mode = true
			lb.button_group = group2
			lb.custom_minimum_size = Vector2(40, 34)
			var bk: String = key
			var lv := level
			lb.pressed.connect(func(): budget_changed.emit(bk, lv))
			levels.add_child(lb)
			buttons.append(lb)
		budget_rows[key] = buttons
	budget_total = _label("", 13)
	budget.add_child(budget_total)

	# --- reforms
	var reforms: VBoxContainer = gov_pages[5]
	reform_cost_label = _label("", 11, ThemeFactory.TEXT_DIM)
	reforms.add_child(reform_cost_label)
	for axis in Rules.REFORM_ORDER:
		var ax: Dictionary = Rules.REFORMS[axis]
		reforms.add_child(_label(ax["name"], 14))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 4)
		reforms.add_child(flow)
		var group3 := ButtonGroup.new()
		var buttons := {}
		for opt in ax["options"]:
			var od: Dictionary = ax["options"][opt]
			var b := Button.new()
			b.text = od["name"]
			b.toggle_mode = true
			b.button_group = group3
			b.custom_minimum_size = Vector2(0, 34)
			b.tooltip_text = od["desc"]
			var ak: String = axis
			var ok: String = opt
			b.pressed.connect(func(): reform.emit(ak, ok))
			flow.add_child(b)
			buttons[opt] = b
		var desc := _label("", 11, ThemeFactory.TEXT_DIM)
		reforms.add_child(desc)
		reform_rows[axis] = {"buttons": buttons, "desc": desc}

	# --- national projects
	var projects: VBoxContainer = gov_pages[6]
	projects.add_child(_label("Нацпроект оплачивается один раз и строится несколько минут, зато бонус навсегда. Одновременно не больше %d." % Rules.PROJECT_MAX_ACTIVE, 11, ThemeFactory.TEXT_DIM))
	for key in Rules.PROJECT_ORDER:
		var p: Dictionary = Rules.PROJECTS[key]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		projects.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		var name := _wrap(_label(p["name"], 14))
		text.add_child(name)
		text.add_child(_label("%s · %s золота · %d с" % [p["desc"], Names.short_number(p["cost"]), int(p["duration"])], 11, ThemeFactory.TEXT_DIM))
		var bar := _bar(ThemeFactory.SKY.darkened(0.1), 12)
		bar.custom_minimum_size = Vector2(70 if mobile else 140, 12)
		bar.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(bar)
		var b := Button.new()
		b.custom_minimum_size = Vector2(120 if mobile else 170, 34)
		var pk: String = key
		b.pressed.connect(func(): project.emit(pk))
		row.add_child(b)
		project_rows[key] = {"button": b, "bar": bar, "name": name}

	# --- wonders of the world (in the projects tab)
	projects.add_child(_label("ЧУДЕСА СВЕТА", 14))
	projects.add_child(_label("Каждое чудо существует в мире в одном экземпляре: кто первый построил, тот и владеет. Чудо стоит на клетке, захватите её — заберёте чудо.", 11, ThemeFactory.TEXT_DIM))
	for key in Rules.WONDER_ORDER:
		var wd: Dictionary = Rules.WONDERS[key]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		projects.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		var name := _wrap(_label(wd["name"], 14))
		text.add_child(name)
		text.add_child(_label("%s · %s золота" % [wd["desc"], Names.short_number(wd["cost"])], 11, ThemeFactory.TEXT_DIM))
		var b := Button.new()
		b.custom_minimum_size = Vector2(120 if mobile else 170, 34)
		var wk: String = key
		b.pressed.connect(func():
			gov_panel.visible = false
			mode_selected.emit(wk))
		row.add_child(b)
		wonder_rows[key] = {"button": b, "name": name}

	# --- diplomacy
	var diplo: VBoxContainer = gov_pages[7]
	diplo.add_child(_label("Подарки поднимают отношения, нападения роняют их, со временем всё возвращается к 50. Соперник с отношениями от %d согласится на пакт о ненападении на %d с: ни он, ни вы не сможете атаковать друг друга. Боты реже нападают на тех, кого любят." % [int(Rules.PACT_MIN_RELATION), Rules.PACT_SECONDS], 11, ThemeFactory.TEXT_DIM))
	diplo_box = VBoxContainer.new()
	diplo_box.add_theme_constant_override("separation", 6)
	diplo.add_child(diplo_box)

	# --- espionage (rows are built on first use, they need the world)
	var spyp: VBoxContainer = gov_pages[8]
	spyp.add_child(_label("Выберите цель и операцию. Шанс зависит от вашего шефа разведки и от разведки цели. Провал портит отношения на %d. После операции агенты отдыхают %d с." % [int(Rules.SPY_FAIL_RELATION), Rules.SPY_COOLDOWN_TICKS / Rules.TICKS_PER_SEC], 11, ThemeFactory.TEXT_DIM))

	# --- resources
	var resp: VBoxContainer = gov_pages[9]
	resp.add_child(_label("Месторождения разбросаны по карте (значки на земле). Каждая клетка с ресурсом даёт бонус, до %d клеток одного вида. Наведите на значок, чтобы узнать, что там." % Resources.STACK_CAP, 11, ThemeFactory.TEXT_DIM))
	for kind in Resources.KIND_ORDER:
		var rd: Dictionary = Resources.KINDS[kind]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		resp.add_child(row)
		var swatch := ColorRect.new()
		swatch.color = Color(rd["color"])
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = SIZE_SHRINK_CENTER
		swatch.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(swatch)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		text.add_child(_label(rd["name"], 14))
		text.add_child(_label("за клетку: " + rd["desc"], 11, ThemeFactory.TEXT_DIM))
		var count := _label("", 14)
		count.custom_minimum_size = Vector2(120, 0)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(count)
		resource_rows[kind] = count


	# --- economy
	var econ: VBoxContainer = gov_pages[10]
	econ.add_child(_label("Страна производит и потребляет еду, материалы, топливо и роскошь. Излишки уходят на мировой рынок, дефицит покупается по мировой цене. Цена растёт, когда спроса больше, чем предложения. Пустой склад бьёт по стране: голод, дорогие стройки, медленные армии.", 11, ThemeFactory.TEXT_DIM))
	econ_summary = _label("", 13)
	econ_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	econ.add_child(econ_summary)
	econ_cycle = _label("", 11, ThemeFactory.TEXT_DIM)
	econ.add_child(econ_cycle)
	var money := HFlowContainer.new()
	money.add_theme_constant_override("h_separation", 6)
	money.add_theme_constant_override("v_separation", 6)
	econ.add_child(money)
	money.add_child(_label("Ключевая ставка:", 13))
	var rate_down := Button.new()
	rate_down.text = "−"
	rate_down.custom_minimum_size = Vector2(36, 34)
	rate_down.pressed.connect(func(): rate_changed.emit(int(world.factions[human]["econ"]["rate"]) - 1))
	money.add_child(rate_down)
	econ_rate = _label("", 14)
	econ_rate.custom_minimum_size = Vector2(44, 0)
	econ_rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money.add_child(econ_rate)
	var rate_up := Button.new()
	rate_up.text = "+"
	rate_up.custom_minimum_size = Vector2(36, 34)
	rate_up.pressed.connect(func(): rate_changed.emit(int(world.factions[human]["econ"]["rate"]) + 1))
	money.add_child(rate_up)
	econ.add_child(_label("Ставка: нейтральная 3%. Выше — инфляция ниже, но −1.2% роста и −0.6% дохода за пункт; ниже — наоборот.", 11, ThemeFactory.TEXT_DIM))
	var debt_row := HFlowContainer.new()
	debt_row.add_theme_constant_override("h_separation", 6)
	debt_row.add_theme_constant_override("v_separation", 6)
	econ.add_child(debt_row)
	econ_debt = _label("", 13)
	econ_debt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	econ.add_child(econ_debt)
	econ.move_child(econ_debt, econ.get_child_count() - 2)
	for amount in Economy.LOAN_STEPS:
		var b := Button.new()
		b.text = "Займ " + Names.short_number(amount)
		b.custom_minimum_size = Vector2(0, 34)
		var am: int = amount
		b.pressed.connect(func(): loan.emit(am))
		debt_row.add_child(b)
		econ_buttons["loan_%d" % amount] = b
	var repay_b := Button.new()
	repay_b.text = "Погасить 5.00K"
	repay_b.custom_minimum_size = Vector2(0, 34)
	repay_b.pressed.connect(func(): repay.emit(5000))
	debt_row.add_child(repay_b)
	econ_buttons["repay"] = repay_b
	var repay_all := Button.new()
	repay_all.text = "Погасить всё"
	repay_all.custom_minimum_size = Vector2(0, 34)
	repay_all.pressed.connect(func(): repay.emit(int(world.factions[human]["econ"]["debt"]) + 1))
	debt_row.add_child(repay_all)
	econ_buttons["repay_all"] = repay_all
	var emit_b := Button.new()
	emit_b.text = "Эмиссия"
	emit_b.custom_minimum_size = Vector2(0, 34)
	emit_b.tooltip_text = "Напечатать золото: сразу четверть минуты ВВП, потом инфляция +5"
	emit_b.pressed.connect(func(): emission.emit())
	debt_row.add_child(emit_b)
	econ_buttons["emission"] = emit_b

	# --- people, budget, market, trade policy (sections inserted above the goods)
	var sec_people := _label("НАСЕЛЕНИЕ И ТРУД", 13)
	econ.add_child(sec_people)
	econ.move_child(sec_people, 3)
	econ_people = _label("", 11, ThemeFactory.TEXT_DIM)
	econ.add_child(econ_people)
	econ.move_child(econ_people, 4)
	var sec_budget := _label("ГОСБЮДЖЕТ", 13)
	econ.add_child(sec_budget)
	econ.move_child(sec_budget, 5)
	econ_budget = _label("", 11, ThemeFactory.TEXT_DIM)
	econ.add_child(econ_budget)
	econ.move_child(econ_budget, 6)
	var sec_money := _label("ДЕНЬГИ, КУРС И ДОЛГ", 13)
	econ.add_child(sec_money)
	econ.move_child(sec_money, 7)
	var sec_market := _label("БИРЖА", 13)
	econ.add_child(sec_market)
	econ_index = _label("", 11, ThemeFactory.TEXT_DIM)
	econ.add_child(econ_index)
	var market_row := HFlowContainer.new()
	market_row.add_theme_constant_override("h_separation", 6)
	market_row.add_theme_constant_override("v_separation", 6)
	econ.add_child(market_row)
	for amount in [1000, 5000, 20000]:
		var b := Button.new()
		b.text = "Вложить " + Names.short_number(amount)
		b.custom_minimum_size = Vector2(0, 34)
		var am: int = amount
		b.pressed.connect(func(): invest.emit(am))
		market_row.add_child(b)
		econ_buttons["invest_%d" % amount] = b
	var sell_half := Button.new()
	sell_half.text = "Продать половину"
	sell_half.custom_minimum_size = Vector2(0, 34)
	sell_half.pressed.connect(func(): divest.emit(int(Economy.portfolio_value(world.factions[human]) / 2.0)))
	market_row.add_child(sell_half)
	econ_buttons["divest_half"] = sell_half
	var sell_all := Button.new()
	sell_all.text = "Продать всё"
	sell_all.custom_minimum_size = Vector2(0, 34)
	sell_all.pressed.connect(func(): divest.emit(int(Economy.portfolio_value(world.factions[human])) + 1))
	market_row.add_child(sell_all)
	econ_buttons["divest_all"] = sell_all
	var sec_trade := _label("ТОРГОВАЯ ПОЛИТИКА", 13)
	econ.add_child(sec_trade)
	var tariff_row := HFlowContainer.new()
	tariff_row.add_theme_constant_override("h_separation", 6)
	tariff_row.add_theme_constant_override("v_separation", 6)
	econ.add_child(tariff_row)
	tariff_row.add_child(_label("Пошлины на импорт:", 13))
	var tgroup := ButtonGroup.new()
	for i in Economy.TARIFF_LEVELS.size():
		var b := Button.new()
		b.text = "%d%%" % int(Economy.TARIFF_LEVELS[i] * 100.0)
		b.toggle_mode = true
		b.button_group = tgroup
		b.custom_minimum_size = Vector2(52, 34)
		var lv := i
		b.pressed.connect(func(): tariff_changed.emit(lv))
		tariff_row.add_child(b)
		tariff_buttons.append(b)
	econ.add_child(_label("Пошлины наполняют казну и защищают своих производителей (+30% выпуска еды и материалов при 30%), но импорт дороже, а соседи любят вас меньше. Санкции против отдельных стран — во вкладке Дипломатия.", 11, ThemeFactory.TEXT_DIM))
	var sec_goods := _label("ТОВАРЫ", 13)
	econ.add_child(sec_goods)
	for good in Economy.GOOD_ORDER:
		var gd: Dictionary = Economy.GOODS[good]
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 2)
		econ.add_child(stack)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		stack.add_child(row)
		var swatch := ColorRect.new()
		swatch.color = Color(gd["color"])
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = SIZE_SHRINK_CENTER
		swatch.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(swatch)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		var name := _label(gd["name"], 14)
		text.add_child(name)
		text.add_child(_label(gd["desc"], 11, ThemeFactory.TEXT_DIM))
		var stats_l := _label("", 11, ThemeFactory.TEXT_DIM)
		text.add_child(stats_l)
		var bar := _bar(Color(gd["color"]), 10)
		bar.custom_minimum_size = Vector2(60 if mobile else 120, 10)
		bar.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(bar)
		var line: Container
		if mobile:
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 4)
			flow.add_theme_constant_override("v_separation", 4)
			line = flow
		else:
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 6)
			line = hb
		stack.add_child(line)
		var opt := OptionButton.new()
		opt.custom_minimum_size = Vector2(130, 32)
		opt.fit_to_longest_item = false
		for pk in Economy.POLICY_ORDER:
			opt.add_item(Economy.POLICIES[pk])
		var gk: String = good
		opt.item_selected.connect(func(i):
			if not _econ_syncing:
				policy_changed.emit(gk, Economy.POLICY_ORDER[i]))
		line.add_child(opt)
		var buy_b := Button.new()
		buy_b.custom_minimum_size = Vector2(0, 32)
		buy_b.size_flags_horizontal = SIZE_EXPAND_FILL
		buy_b.pressed.connect(func(): buy_goods.emit(gk, 100))
		line.add_child(buy_b)
		var sell_b := Button.new()
		sell_b.custom_minimum_size = Vector2(0, 32)
		sell_b.size_flags_horizontal = SIZE_EXPAND_FILL
		sell_b.pressed.connect(func(): sell_goods.emit(gk, 100))
		line.add_child(sell_b)
		econ_rows[good] = {"name": name, "stats": stats_l, "bar": bar, "policy": opt, "buy": buy_b, "sell": sell_b}

	# --- statistics
	var stats: VBoxContainer = gov_pages[11]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	stats.add_child(grid)
	for key in ["gold", "troops", "cells", "approval", "gdp", "inflation", "pop", "index"]:
		var c = Charts.LineChart.new()
		c.custom_minimum_size = Vector2(150 if mobile else 420, 120 if mobile else 160)
		grid.add_child(c)
		stat_charts[key] = c
	income_chart = Charts.BarChart.new()
	income_chart.custom_minimum_size = Vector2(0, 130)
	stats.add_child(income_chart)
	show_gov_tab(0)


## Search field plus category buttons for a long list page.
func _filter_bar(tab: int, page: VBoxContainer) -> void:
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 4)
	bar.add_theme_constant_override("v_separation", 4)
	page.add_child(bar)
	var search := LineEdit.new()
	search.placeholder_text = "Поиск…"
	search.custom_minimum_size = Vector2(130, 32)
	search.clear_button_enabled = true
	bar.add_child(search)
	var count := _label("", 11, ThemeFactory.TEXT_DIM)
	gov_filters[tab] = {"cat": "", "text": "", "rows": [], "count": count}
	var group := ButtonGroup.new()
	var cats: Array = [["", "Все"]]
	for c in Rules.CATEGORY_ORDER:
		cats.append([c, Rules.CATEGORIES[c]])
	for pair in cats:
		var b := Button.new()
		b.text = pair[1]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = pair[0] == ""
		b.custom_minimum_size = Vector2(0, 32)
		b.add_theme_font_size_override("font_size", 12)
		var ck: String = pair[0]
		var t := tab
		b.pressed.connect(func():
			gov_filters[t]["cat"] = ck
			_apply_filter(t))
		bar.add_child(b)
	var t2 := tab
	search.text_changed.connect(func(text: String):
		gov_filters[t2]["text"] = text.to_lower()
		_apply_filter(t2))
	page.add_child(count)


## Long names wrap on phones so list rows never push the panel off screen.
func _wrap(l: Label) -> Label:
	if mobile:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _register_row(tab: int, row: Control, cat: String, name: String) -> void:
	gov_filters[tab]["rows"].append({"node": row, "cat": cat, "name": name.to_lower()})
	var fl: Dictionary = gov_filters[tab]
	fl["count"].text = "Показано %d из %d" % [fl["rows"].size(), fl["rows"].size()]


func _apply_filter(tab: int) -> void:
	var fl: Dictionary = gov_filters[tab]
	var shown := 0
	for r in fl["rows"]:
		var ok: bool = (fl["cat"] == "" or r["cat"] == fl["cat"]) and (fl["text"] == "" or r["name"].contains(fl["text"]))
		r["node"].visible = ok
		if ok:
			shown += 1
	fl["count"].text = "Показано %d из %d" % [shown, fl["rows"].size()]


func show_gov_tab(i: int) -> void:
	gov_tab_index = i
	for k in gov_pages.size():
		gov_pages[k].get_parent().visible = k == i
		gov_tabs[k].button_pressed = k == i
	if world != null:
		_refresh_gov()


func toggle_gov(tab: int = -1) -> void:
	var show := not gov_panel.visible
	_hide_panels()
	gov_panel.visible = show
	if show:
		if tab >= 0:
			show_gov_tab(tab)
		_refresh_gov()


func _refresh_gov() -> void:
	var f: Dictionary = world.factions[human]
	gov_gold.text = "Золото: " + Names.short_number(f["gold"])
	match gov_tab_index:
		0:
			var bars: Array = []
			for party in Rules.PARTY_ORDER:
				var p: Dictionary = Rules.PARTIES[party]
				var n: int = int(f["seats"].get(party, 0))
				bars.append({"value": float(n), "color": Color(p["color"]), "label": p["name"]})
				var r: Dictionary = party_rows[party]
				r["seats"].text = "%d мест" % n
				r["name"].text = p["name"] + (" · правит" if f["ruling"] == party else "")
				r["name"].add_theme_color_override("font_color", Color("#D9731F") if f["ruling"] == party else ThemeFactory.TEXT)
				var ag: float = f["agitation"].get(party, 0.0)
				r["button"].text = ("Агитация · " + Names.short_number(Rules.AGITATION_COST)) + (" (+%d)" % int(ag) if ag > 0.0 else "")
				r["button"].disabled = f["gold"] < Rules.AGITATION_COST
			seats_chart.set_data("Госдума: %d мест · следующие выборы через %d с" % [Rules.DUMA_SEATS, int(world.seconds_to_election(human))], bars, true)
		1:
			for key in minister_rows:
				var b: Button = minister_rows[key]["button"]
				if world.has_minister(human, key):
					b.text = "Уволить"
					b.disabled = false
				else:
					b.text = "Нанять · " + Names.short_number(Rules.MINISTERS[key]["fee"])
					b.disabled = f["gold"] < Rules.MINISTERS[key]["fee"]
		2:
			for key in bill_rows:
				var r: Dictionary = bill_rows[key]
				var support: int = world.bill_support(human, key)
				var b: Button = r["button"]
				var blocked: String = world.bill_blocked(human, key)
				if world.has_bill(human, key):
					@warning_ignore("integer_division")
					var half: int = world.bill_cost(human, key) / 2
					r["support"].text = "действует"
					r["support"].add_theme_color_override("font_color", ThemeFactory.GREEN)
					r["info"].text = r["base"]
					b.text = "Отменить · " + Names.short_number(half)
					b.disabled = f["gold"] < half
				elif blocked != "":
					r["support"].text = "%d/%d мест" % [support, Rules.BILL_MAJORITY]
					r["support"].add_theme_color_override("font_color", ThemeFactory.TEXT_DIM)
					r["info"].text = r["base"] + " · " + blocked
					b.text = "Недоступен"
					b.disabled = true
				else:
					var cost: int = world.bill_cost(human, key)
					r["support"].text = "%d/%d мест" % [support, Rules.BILL_MAJORITY]
					r["support"].add_theme_color_override("font_color", ThemeFactory.GREEN if support >= Rules.BILL_MAJORITY else ThemeFactory.RED)
					r["info"].text = r["base"]
					b.text = "Внести · " + Names.short_number(cost)
					b.disabled = f["gold"] < cost
		3:
			for key in building_rows:
				var r: Dictionary = building_rows[key]
				var cost: int = world.building_cost(key, human)
				var n: int = int(f["extra"].get(key, 0))
				r["name"].text = Rules.BUILDINGS[key]["name"] + (" ×%d" % n if n > 0 else "")
				r["button"].text = "Построить · " + Names.short_number(cost)
				r["button"].disabled = f["gold"] < cost
		4:
			for key in budget_rows:
				var level: int = int(f["budget"].get(key, 0))
				var buttons: Array = budget_rows[key]
				for i in buttons.size():
					buttons[i].button_pressed = (i == level)
			budget_total.text = "Расходы бюджета: %s золота в секунду" % Names.short_number(world.budget_cost(human))
		5:
			var cost: int = world.reform_cost(human)
			reform_cost_label.text = "Смена курса стоит %s золота и −%d одобрения. Партии реагируют на следующих выборах." % [Names.short_number(cost), int(Rules.REFORM_APPROVAL_HIT)]
			for axis in reform_rows:
				var current: String = f["reforms"][axis]
				var r: Dictionary = reform_rows[axis]
				for opt in r["buttons"]:
					var b: Button = r["buttons"][opt]
					b.button_pressed = opt == current
					b.disabled = opt != current and f["gold"] < cost
				var od: Dictionary = Rules.REFORMS[axis]["options"][current]
				r["desc"].text = "Сейчас: %s — %s" % [od["name"], od["desc"]]
		6:
			var active: int = world.active_projects(human)
			for key in project_rows:
				var r: Dictionary = project_rows[key]
				var p: Dictionary = Rules.PROJECTS[key]
				var progress: float = world.project_progress(human, key)
				r["bar"].value = progress
				var b: Button = r["button"]
				if f["projects_done"].get(key, false):
					r["name"].text = p["name"] + " ✓"
					b.text = "Готово"
					b.disabled = true
				elif f["projects"].has(key):
					r["name"].text = p["name"]
					b.text = "Идёт · %d%%" % int(progress * 100.0)
					b.disabled = true
				elif p.has("req_tech") and world.tech_level(human, p["req_tech"]) == 0:
					r["name"].text = p["name"]
					b.text = "Нужна техн."
					b.disabled = true
				else:
					r["name"].text = p["name"]
					var cost: int = int(round(p["cost"] * world.mod(human, "build_cost")))
					b.text = "Начать · " + Names.short_number(cost)
					b.disabled = f["gold"] < cost or active >= Rules.PROJECT_MAX_ACTIVE
			for key in wonder_rows:
				var r: Dictionary = wonder_rows[key]
				var wd: Dictionary = Rules.WONDERS[key]
				if world.wonders.has(key):
					var owner_id: int = world.wonders[key]
					r["name"].text = wd["name"] + (" ✓ ваше" if owner_id == human else " · у %s" % world.factions[owner_id]["name"])
					r["button"].text = "Построено"
					r["button"].disabled = true
				else:
					r["name"].text = wd["name"]
					var cost: int = world.building_cost(key, human)
					r["button"].text = "Построить · " + Names.short_number(cost)
					r["button"].disabled = f["gold"] < cost
		7:
			_refresh_diplomacy(f)
		8:
			_refresh_spy(f)
		9:
			var total := 0
			for kind in resource_rows:
				var n: int = world.resource_count(human, kind)
				total += n
				resource_rows[kind].text = "%d клеток" % n if n > 0 else "нет"
				resource_rows[kind].add_theme_color_override("font_color", ThemeFactory.TEXT if n > 0 else ThemeFactory.TEXT_DIM)
		10:
			var e: Dictionary = f["econ"]
			var limit: float = Economy.credit_limit(world, human)
			econ_summary.text = "ВВП %s/с · инфляция %.1f%% в минуту · уровень цен ×%.2f · курс валюты %.2f · рейтинг %s · торговля товарами %+.0f/с" % [Names.short_number(e["gdp"]), float(e["inflation"]), float(e["price_level"]), Economy.exchange_rate(world, human), Economy.rating(world, human), float(e["trade_gold"])]
			var cyc: Dictionary = Economy.cycle(world)
			econ_cycle.text = "Мировой рынок: %s — %s" % [cyc["name"], cyc["desc"]]
			econ_rate.text = "%d%%" % int(e["rate"])
			var debt: float = float(e["debt"])
			econ_debt.text = "Долг %s из лимита %s · ставка по кредиту %.1f%% в минуту · проценты %.1f/с%s" % [Names.short_number(debt), Names.short_number(limit), Economy.loan_rate(world, human), Economy.interest_per_sec(world, human), " · ДЕФОЛТ" if e["defaulted"] else ""]
			var pop: int = world.population_of(human)
			var jobs: Dictionary = e["jobs"]
			econ_people.text = "Население %s (%+.1f/с: рождаемость +%.1f, смертность −%.1f, миграция %+.1f) · рабочих мест %s: село %s, промышленность %s, услуги %s · безработица %.1f%% · зарплата ×%.2f · производительность ×%.2f" % [
				Names.short_number(pop), float(e["births"]) - float(e["deaths"]) + float(e["migration"]), float(e["births"]), float(e["deaths"]), float(e["migration"]),
				Names.short_number(float(jobs.get("agri", 0.0)) + float(jobs.get("industry", 0.0)) + float(jobs.get("services", 0.0))), Names.short_number(float(jobs.get("agri", 0.0))), Names.short_number(float(jobs.get("industry", 0.0))), Names.short_number(float(jobs.get("services", 0.0))),
				float(e["unemployment"]) * 100.0, float(e["wage"]), Economy.productivity(world, human)]
			var bd: Dictionary = Economy.budget(world, human)
			var rev_parts: Array = []
			for k in bd["revenue"]:
				if float(bd["revenue"][k]) > 0.05:
					rev_parts.append("%s %s" % [k, Names.short_number(bd["revenue"][k])])
			var sp_parts: Array = []
			for k in bd["spending"]:
				if float(bd["spending"][k]) > 0.05:
					sp_parts.append("%s %s" % [k, Names.short_number(bd["spending"][k])])
			econ_budget.text = "Доходы %s/с (%s) · расходы %s/с (%s) · сальдо %+.1f/с%s" % [Names.short_number(bd["total_revenue"]), ", ".join(rev_parts) if not rev_parts.is_empty() else "—", Names.short_number(bd["total_spending"]), ", ".join(sp_parts) if not sp_parts.is_empty() else "—", bd["balance"], " · дефицит разгоняет инфляцию" if bd["balance"] < 0.0 else ""]
			var pv: float = Economy.portfolio_value(f)
			econ_index.text = "Индекс %s: %.1f · ваш портфель %s (вложено %s) · растёт с ВВП и одобрением, падает от войн и рецессий" % [f["name"], float(e["index"]), Names.short_number(pv), Names.short_number(e["invested"])]
			for amount in [1000, 5000, 20000]:
				econ_buttons["invest_%d" % amount].disabled = f["gold"] < amount
			econ_buttons["divest_half"].disabled = pv < 2.0
			econ_buttons["divest_all"].disabled = pv < 1.0
			for i in tariff_buttons.size():
				tariff_buttons[i].button_pressed = i == int(e["tariff"])
			econ_debt.add_theme_color_override("font_color", ThemeFactory.RED if e["defaulted"] else ThemeFactory.TEXT)
			for amount in Economy.LOAN_STEPS:
				econ_buttons["loan_%d" % amount].disabled = e["defaulted"] or debt + amount > limit
			econ_buttons["repay"].disabled = debt <= 0.0 or f["gold"] < 1.0
			econ_buttons["repay_all"].disabled = debt <= 0.0 or f["gold"] < debt
			var cd: int = maxi(0, int(e["emission_cd"]) - world.tick)
			econ_buttons["emission"].text = "Эмиссия +%s" % Names.short_number(Economy.emission_amount(world, human)) if cd == 0 else "Эмиссия · %d с" % int(ceil(cd * Rules.TICK_DT))
			econ_buttons["emission"].disabled = cd > 0
			_econ_syncing = true
			for good in econ_rows:
				var r: Dictionary = econ_rows[good]
				var stock: float = float(e["stock"][good])
				var prod: float = float(e["prod"].get(good, 0.0))
				var cons: float = float(e["cons"].get(good, 0.0))
				var p: float = Economy.price(world, good)
				var short: bool = e["shortage"][good]
				r["name"].text = Economy.GOODS[good]["name"] + (" · ДЕФИЦИТ" if short else "")
				r["name"].add_theme_color_override("font_color", ThemeFactory.RED if short else ThemeFactory.TEXT)
				r["stats"].text = "склад %d · производство +%.1f/с · потребление −%.1f/с · мировая цена %.1f (в вашей валюте %.1f)" % [int(stock), prod, cons, p, Economy.local_price(world, human, good)]
				r["bar"].value = clampf(stock / Economy.STOCK_CAP, 0.0, 1.0)
				r["policy"].select(Economy.POLICY_ORDER.find(e["policy"][good]))
				r["buy"].text = "Купить 100 · " + Names.short_number(100.0 * p)
				r["buy"].disabled = f["gold"] < 100.0 * p
				r["sell"].text = "Продать 100 · +" + Names.short_number(100.0 * p * Economy.SELL_DISCOUNT)
				r["sell"].disabled = stock < 1.0
			_econ_syncing = false
		11:
			var h: Dictionary = f["history"]
			var titles := {"gold": "Золото", "troops": "Армия", "cells": "Земля (клетки)", "approval": "Одобрение, %", "gdp": "ВВП в секунду", "inflation": "Инфляция, % в минуту", "pop": "Население", "index": "Биржевой индекс"}
			var colors := {"gold": Color("#D9731F"), "troops": ThemeFactory.PEACH.darkened(0.15), "cells": ThemeFactory.LIME.darkened(0.2), "approval": ThemeFactory.SKY.darkened(0.15), "gdp": ThemeFactory.LAVENDER.darkened(0.25), "inflation": ThemeFactory.RED, "pop": ThemeFactory.LIME.darkened(0.35), "index": ThemeFactory.SKY.darkened(0.3)}
			for key in stat_charts:
				stat_charts[key].set_data(titles[key], [{"values": h[key], "color": colors[key], "label": "за матч, шаг 5 с"}])
			var bars: Array = []
			var breakdown: Dictionary = world.income_breakdown(human)
			var palette := [ThemeFactory.LIME, ThemeFactory.LEMON, ThemeFactory.SKY, ThemeFactory.LAVENDER, ThemeFactory.PEACH]
			var i := 0
			for label in breakdown:
				bars.append({"value": breakdown[label], "color": palette[i % palette.size()], "label": label})
				i += 1
			income_chart.set_data("Доход в секунду: +%s" % Names.short_number(world.gold_rate_of(human)), bars, false)


func _build_event_panel() -> void:
	event_panel = PanelContainer.new()
	event_panel.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	event_panel.offset_left = -160 if mobile else -260
	event_panel.offset_right = 160 if mobile else 260
	event_panel.offset_top = 60 if mobile else 100
	event_panel.offset_bottom = event_panel.offset_top
	event_panel.visible = false
	event_panel.z_index = 5
	add_child(event_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	event_panel.add_child(box)
	event_title = _label("", 18, Color("#D9731F"))
	box.add_child(event_title)
	event_text = _label("", 13)
	event_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(event_text)
	for i in 2:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 38)
		var idx := i
		b.pressed.connect(func(): event_choice.emit(idx))
		box.add_child(b)
		event_buttons.append(b)


func toggle_people() -> void:
	var show := not people_panel.visible
	_hide_panels()
	people_panel.visible = show
	if show:
		_refresh_people()


func show_event(e: Dictionary) -> void:
	event_title.text = e["title"]
	event_text.text = e["text"]
	for i in 2:
		event_buttons[i].text = e["choices"][i]["text"]
	event_panel.visible = true


func hide_event() -> void:
	event_panel.visible = false


func _refresh_people() -> void:
	var f: Dictionary = world.factions[human]
	var approval: float = f["approval"]
	people_labels["population"].text = "Население: %s · Золото с налогов: +%s / сек" % [Names.short_number(world.population_of(human)), Names.short_number(f["cells"] * f["tax"] * Rules.TAX_GOLD_PER_CELL)]
	people_labels["approval"].text = "Одобрение: %d%% (рост армии ×%.2f)" % [int(approval), world.approval_factor(human)]
	people_labels["target"].text = "Тянется к %d%%" % int(world.approval_target(human))
	var secs: int = int(world.seconds_to_election(human))
	@warning_ignore("integer_division")
	people_labels["election"].text = "Выборы через %d:%02d · побед %d · поражений %d%s" % [secs / 60, secs % 60, f["elections_won"], f["elections_lost"],
		("" if f["last_election"] == "" else " · последние: " + f["last_election"])]
	var effects: Array = []
	if world.tick < f["loss_until"]:
		effects.append("поражение на выборах: −50%% роста, −30%% золота ещё %d с" % int((f["loss_until"] - world.tick) * Rules.TICK_DT))
	if world.tick < f["festival_until"]:
		effects.append("праздник: +10%% роста ещё %d с" % int((f["festival_until"] - world.tick) * Rules.TICK_DT))
	people_labels["effects"].text = "Эффекты: " + (", ".join(effects) if not effects.is_empty() else "нет")
	people_bar.value = approval / 100.0
	_tax_syncing = true
	for i in tax_buttons.size():
		tax_buttons[i].button_pressed = (i == f["tax"])
	_tax_syncing = false
	for kind in decree_buttons:
		var b: Button = decree_buttons[kind]
		var cd: float = world.decree_cooldown(human, kind)
		var cost: int = world.decree_cost(human, kind)
		if cd > 0.0:
			b.text = "через %d с" % int(ceil(cd))
			b.disabled = true
		else:
			b.text = "Издать"
			b.disabled = f["gold"] < cost


func toggle_tech() -> void:
	var show := not tech_panel.visible
	_hide_panels()
	tech_panel.visible = show
	if show:
		_refresh_tech()


static func world_tech_def(key: String) -> Dictionary:
	if Rules.TECHS.has(key):
		return Rules.TECHS[key]
	return Rules.EXTRA_TECHS[key]


func _refresh_tech() -> void:
	var f: Dictionary = world.factions[human]
	tech_gold.text = "Золото: " + Names.short_number(f["gold"])
	for key in tech_rows:
		var t: Dictionary = world_tech_def(key)
		var level: int = world.tech_level(human, key)
		var r: Dictionary = tech_rows[key]
		r["level"].text = "%d/%d" % [level, t["max"]]
		var b: Button = r["button"]
		if level >= t["max"]:
			b.text = "Изучено"
			b.disabled = true
		elif t["req"] != "" and world.tech_level(human, t["req"]) == 0:
			b.text = "Нужно: " + world_tech_def(t["req"])["name"]
			b.disabled = true
		else:
			var cost: int = world.tech_cost(human, key)
			b.text = "Изучить · " + Names.short_number(cost)
			b.disabled = f["gold"] < cost


func _build_tooltip() -> void:
	tooltip = PanelContainer.new()
	tooltip.visible = false
	tooltip.mouse_filter = MOUSE_FILTER_IGNORE
	tooltip.z_index = 10
	add_child(tooltip)
	tooltip_label = _label("", 12)
	tooltip.add_child(tooltip_label)


func _build_toast() -> void:
	var toast_box := CenterContainer.new()
	toast_box.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	toast_box.offset_top = 56
	toast_box.offset_bottom = 96
	toast_box.offset_left = -400
	toast_box.offset_right = 400
	toast_box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(toast_box)
	toast_label = _label("", 18)
	toast_label.add_theme_stylebox_override("normal", ThemeFactory.pill(ThemeFactory.PANEL, 8, 14))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0.0
	toast_box.add_child(toast_label)


func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.23, 0.16, 0.10, 0.45)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	panel.offset_left = -170 if mobile else -250
	panel.offset_right = 170 if mobile else 250
	panel.offset_top = -190
	panel.offset_bottom = 190
	overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
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
	var again := Button.new()
	again.text = "Играть снова"
	again.pressed.connect(func(): restart_requested.emit())
	box.add_child(again)
	var b := Button.new()
	b.text = "В главное меню"
	b.pressed.connect(func(): menu_requested.emit())
	box.add_child(b)



# ------------------------------------------------------------------ missions, achievements, autopilot

func _build_missions_panel() -> void:
	missions_panel = PanelContainer.new()
	_place_panel(missions_panel, 720, 600)
	missions_panel.visible = false
	add_child(missions_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	missions_panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := _label("ЗАДАНИЯ И ДОСТИЖЕНИЯ", 20)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(36, 32)
	close.pressed.connect(toggle_missions)
	head.add_child(close)
	profile_label = _label("", 13, Color("#D9731F"))
	box.add_child(profile_label)
	box.add_child(_label("Три задания одновременно. Выполненное даёт золото и опыт, на его место приходит новое, всё сложнее.", 11, ThemeFactory.TEXT_DIM))
	for i in Missions.ACTIVE:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		box.add_child(row)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		row.add_child(line)
		var name := _label("", 14)
		name.size_flags_horizontal = SIZE_EXPAND_FILL
		line.add_child(name)
		var reward := _label("", 12, Color("#D9731F"))
		line.add_child(reward)
		var desc := _label("", 11, ThemeFactory.TEXT_DIM)
		row.add_child(desc)
		var bar := _bar(ThemeFactory.LIME.darkened(0.1), 10)
		row.add_child(bar)
		mission_rows.append({"name": name, "reward": reward, "desc": desc, "bar": bar})
	box.add_child(_label("ДОСТИЖЕНИЯ", 14))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 120 if mobile else 220)
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 1 if mobile else 2
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	for key in Achievements.ORDER:
		var a: Dictionary = Achievements.LIST[key]
		var l := _label("", 11, ThemeFactory.TEXT_DIM)
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		l.custom_minimum_size = Vector2(0 if mobile else 320, 0)
		l.text = "☐ %s — %s (+%d XP)" % [a["name"], a["desc"], a["xp"]]
		grid.add_child(l)
		achievement_labels[key] = l


func set_profile(text: String, unlocked: Dictionary) -> void:
	profile_label.text = text
	for key in achievement_labels:
		var a: Dictionary = Achievements.LIST[key]
		var l: Label = achievement_labels[key]
		var done: bool = unlocked.get(key, false)
		l.text = "%s %s — %s (+%d XP)" % ["✔" if done else "☐", a["name"], a["desc"], a["xp"]]
		l.add_theme_color_override("font_color", ThemeFactory.GREEN if done else ThemeFactory.TEXT_DIM)


func toggle_missions() -> void:
	var show := not missions_panel.visible
	_hide_panels()
	missions_panel.visible = show
	if show:
		_refresh_missions()


func _refresh_missions() -> void:
	var ms: Array = world.factions[human]["missions"]
	for i in mission_rows.size():
		var r: Dictionary = mission_rows[i]
		if i >= ms.size():
			r["name"].text = ""
			r["desc"].text = ""
			r["reward"].text = ""
			r["bar"].value = 0.0
			continue
		var m: Dictionary = ms[i]
		var t: Dictionary = Missions.TEMPLATES[m["key"]]
		r["name"].text = "%s · уровень %d" % [t["name"], int(m["tier"]) + 1]
		r["desc"].text = Missions.describe(m)
		r["reward"].text = "+%s золота · +%d XP" % [Names.short_number(m["gold"]), int(m["xp"])]
		r["bar"].value = Missions.progress(world, human, m)


func _build_autopilot_panel() -> void:
	autopilot_panel = PanelContainer.new()
	_place_panel(autopilot_panel, 560, 520)
	autopilot_panel.visible = false
	add_child(autopilot_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	autopilot_panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := _label("АВТОПИЛОТ", 20)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(36, 32)
	close.pressed.connect(toggle_autopilot)
	head.add_child(close)
	box.add_child(_label("Страна может развиваться сама: советники решают за вас включённые области, как это делают боты. Вы в любой момент вмешиваетесь вручную.", 11, ThemeFactory.TEXT_DIM))
	var descs := {
		"people": ["Народ", "налоги, пропаганда, ответы на события"],
		"staff": ["Министры", "найм ключевых министров"],
		"laws": ["Законы и проекты", "законы, нацпроекты, реформы, бюджет"],
		"build": ["Стройка", "города, порты, рынки, казармы, защита, здания"],
		"research": ["Наука", "покупка технологий"],
		"diplomacy": ["Дипломатия", "торговля, подарки, пакты с сильными соседями"],
		"expand": ["Экспансия", "захват пустой земли, высадки, слабые соседи"],
		"war": ["Война", "ответные удары и бомбы"],
	}
	for task in BotBrain.ALL_TASKS:
		var cb := CheckButton.new()
		cb.text = "%s — %s" % [descs[task][0], descs[task][1]]
		cb.custom_minimum_size = Vector2(0, 36)
		var tk: String = task
		cb.toggled.connect(func(on):
			if not _autopilot_syncing:
				autopilot_changed.emit(tk, on))
		box.add_child(cb)
		autopilot_buttons[task] = cb
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var all_on := Button.new()
	all_on.text = "Включить всё"
	all_on.size_flags_horizontal = SIZE_EXPAND_FILL
	all_on.pressed.connect(func():
		for task in BotBrain.ALL_TASKS:
			autopilot_changed.emit(task, true))
	row.add_child(all_on)
	var all_off := Button.new()
	all_off.text = "Выключить всё"
	all_off.size_flags_horizontal = SIZE_EXPAND_FILL
	all_off.pressed.connect(func():
		for task in BotBrain.ALL_TASKS:
			autopilot_changed.emit(task, false))
	row.add_child(all_off)


func toggle_autopilot() -> void:
	var show := not autopilot_panel.visible
	_hide_panels()
	autopilot_panel.visible = show
	if show:
		_refresh_autopilot()


func _refresh_autopilot() -> void:
	var ap: Dictionary = world.factions[human]["autopilot"]
	_autopilot_syncing = true
	for task in autopilot_buttons:
		autopilot_buttons[task].button_pressed = ap.get(task, false)
	_autopilot_syncing = false
	var n := ap.size()
	var base := "Авто" if mobile else "Автопилот"
	autopilot_button.text = ("%s · %d" % [base, n]) if n > 0 else base


func _hide_panels() -> void:
	tech_panel.visible = false
	people_panel.visible = false
	gov_panel.visible = false
	missions_panel.visible = false
	autopilot_panel.visible = false


func any_panel_open() -> bool:
	return tech_panel.visible or people_panel.visible or gov_panel.visible or missions_panel.visible or autopilot_panel.visible


func _cycle_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()
	speed_button.text = SPEED_LABELS[speed_index]
	speed_changed.emit(SPEEDS[speed_index])


func toggle_pause() -> void:
	if SPEEDS[speed_index] == 0.0:
		speed_index = 0
	else:
		speed_index = SPEEDS.size() - 1
	speed_button.text = SPEED_LABELS[speed_index]
	speed_changed.emit(SPEEDS[speed_index])


func _menu_card(bar: Control, title: String, key: String, rows: Array, tint: Color, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.tooltip_text = tip
	b.pressed.connect(cb)
	b.add_theme_stylebox_override("normal", ThemeFactory.pill(tint))
	b.add_theme_stylebox_override("hover", ThemeFactory.pill(tint.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", ThemeFactory.pill(ThemeFactory.ORANGE))
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vb.offset_top = 4
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(vb)
	vb.add_child(_icon(rows, "card_" + key, Vector2(40, 28)))
	var t := _label(title, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var k := _label(key, 10, ThemeFactory.TEXT_DIM)
	k.position = Vector2(8, 5)
	b.add_child(k)
	bar.add_child(b)
	return b


func _build_diplo_rows() -> void:
	for id in range(1, world.factions.size()):
		var f: Dictionary = world.factions[id]
		if id == human or f["kind"] != world.Kind.BOT:
			continue
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 4)
		diplo_box.add_child(stack)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		stack.add_child(row)
		var swatch := ColorRect.new()
		swatch.color = f["color"]
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = SIZE_SHRINK_CENTER
		swatch.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(swatch)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		var persona: Dictionary = Rules.PERSONAS.get(f["persona"], Rules.PERSONAS["trader"])
		var name := _wrap(_label("%s · %s" % [f["name"], persona["name"]], 14))
		text.add_child(name)
		var info := _label("", 11, ThemeFactory.TEXT_DIM)
		text.add_child(info)
		var rel := _label("", 13)
		rel.custom_minimum_size = Vector2(70 if mobile else 110, 0)
		rel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(rel)
		var line: Container
		if mobile:
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 4)
			flow.add_theme_constant_override("v_separation", 4)
			line = flow
		else:
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 6)
			line = hb
		stack.add_child(line)
		var buttons := {}
		var tid := id
		for pair in [["gift", "Подарок"], ["pact", "Пакт"], ["trade", "Торговля"], ["alliance", "Союз"], ["vassal", "Вассал"], ["sanction", "Санкции"]]:
			var b := Button.new()
			b.text = pair[1]
			b.custom_minimum_size = Vector2(0, 32)
			b.size_flags_horizontal = SIZE_EXPAND_FILL
			b.add_theme_font_size_override("font_size", 12)
			var act: String = pair[0]
			b.pressed.connect(_diplo_action.bind(act, tid))
			line.add_child(b)
			buttons[act] = b
		diplo_rows[id] = {"name": name, "info": info, "rel": rel, "buttons": buttons, "line": line, "persona": persona["name"]}


func _diplo_action(act: String, tid: int) -> void:
	match act:
		"gift":
			gift.emit(tid)
		"pact":
			pact.emit(tid)
		"trade":
			trade_deal.emit(tid)
		"alliance":
			alliance.emit(tid)
		"vassal":
			vassalize.emit(tid)
		"sanction":
			sanction.emit(tid, not bool(world.factions[human]["sanctions"].get(tid, false)))


func _refresh_diplomacy(f: Dictionary) -> void:
	if diplo_rows.is_empty():
		_build_diplo_rows()
	var attackers := {}
	for a in world.incoming_attacks(human):
		attackers[a["attacker"]] = true
	for id in diplo_rows:
		var r: Dictionary = diplo_rows[id]
		var o: Dictionary = world.factions[id]
		var bt: Dictionary = r["buttons"]
		if not o["alive"]:
			r["name"].text = o["name"] + " · выбыл"
			r["info"].text = ""
			r["rel"].text = ""
			r["line"].visible = false
			continue
		var rel: float = world.relation_of(id, human)
		var status := "мир"
		if world.is_ally(human, id):
			status = "союзник"
		elif o["overlord"] == human:
			status = "ваш вассал"
		elif world.pact_active(human, id):
			status = "пакт ещё %d с" % int(ceil(world.pact_seconds_left(human, id)))
		elif attackers.has(id) and world.has_attack(human, id):
			status = "война"
		elif attackers.has(id):
			status = "нападает на вас"
		elif world.has_attack(human, id):
			status = "вы нападаете"
		if world.trade_active(human, id):
			status += " · торговля"
		if bool(f["sanctions"].get(id, false)):
			status += " · под вашими санкциями"
		r["name"].text = "%s · %s" % [o["name"], r["persona"]]
		r["info"].text = "%.1f%% карты · %s войск · %s" % [world.land_share(id) * 100.0, Names.short_number(o["troops"]), status]
		r["rel"].text = "отношения %d" % int(rel)
		r["rel"].add_theme_color_override("font_color", ThemeFactory.GREEN if rel >= 60.0 else (Color("#D9731F") if rel >= Rules.PACT_MIN_RELATION else ThemeFactory.RED))
		var gcost: int = world.gift_cost(human, id)
		var pcost: int = world.pact_cost(human, id)
		var tcost: int = world.trade_cost(human, id)
		var acost: int = world.alliance_cost(human, id)
		bt["gift"].text = "Подарок · " + Names.short_number(gcost)
		bt["gift"].disabled = f["gold"] < gcost
		bt["pact"].text = "Пакт · " + Names.short_number(pcost)
		bt["pact"].disabled = f["gold"] < pcost or world.pact_active(human, id) or rel < Rules.PACT_MIN_RELATION
		bt["pact"].tooltip_text = "Ненападение на %d с, нужны отношения от %d" % [Rules.PACT_SECONDS, int(Rules.PACT_MIN_RELATION)]
		bt["trade"].text = "Торговля · " + Names.short_number(tcost)
		bt["trade"].disabled = f["gold"] < tcost or world.trade_active(human, id) or rel < Rules.TRADE_MIN_RELATION
		bt["trade"].tooltip_text = "+%d золота в секунду обоим на %d с, нужны отношения от %d" % [int(Rules.TRADE_INCOME_BASE + o["cells"] * Rules.TRADE_INCOME_PER_CELL), Rules.TRADE_SECONDS, int(Rules.TRADE_MIN_RELATION)]
		bt["alliance"].text = "Союз · " + Names.short_number(acost)
		bt["alliance"].disabled = f["gold"] < acost or world.is_ally(human, id) or rel < Rules.ALLIANCE_MIN_RELATION or o["overlord"] == human
		bt["alliance"].tooltip_text = "Вечный пакт, союзник бьёт тех, кто напал на вас. Нужны отношения от %d" % int(Rules.ALLIANCE_MIN_RELATION)
		bt["vassal"].text = "Вассал"
		bt["vassal"].disabled = o["overlord"] != 0 or f["cells"] < o["cells"] * Rules.VASSAL_RATIO
		bt["vassal"].tooltip_text = "Платит вам %d%% дохода и не воюет с вами. Нужно в %d раза больше земли и отношения от %d (или ваша атака на него)" % [int(Rules.VASSAL_TRIBUTE * 100.0), int(Rules.VASSAL_RATIO), int(Rules.VASSAL_MIN_RELATION)]
		var sanctioned: bool = bool(f["sanctions"].get(id, false))
		bt["sanction"].text = "Снять санкции" if sanctioned else "Санкции"
		bt["sanction"].tooltip_text = "Его экспорт −30%%, импорт +30%%, отношения −%d, торговый договор рвётся" % int(Economy.SANCTION_RELATION)


func _build_spy_rows(page: VBoxContainer) -> void:
	spy_target = OptionButton.new()
	spy_target.custom_minimum_size = Vector2(0, 36)
	for id in range(1, world.factions.size()):
		var f: Dictionary = world.factions[id]
		if id != human and f["kind"] == world.Kind.BOT:
			spy_target.add_item(f["name"], id)
	page.add_child(spy_target)
	page.move_child(spy_target, 1)
	spy_status = _label("", 12)
	page.add_child(spy_status)
	page.move_child(spy_status, 2)
	for op in Rules.SPY_OP_ORDER:
		var d: Dictionary = Rules.SPY_OPS[op]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		page.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		text.add_child(_wrap(_label(d["name"], 14)))
		text.add_child(_label(d["desc"], 11, ThemeFactory.TEXT_DIM))
		var chance := _label("", 13)
		chance.custom_minimum_size = Vector2(60 if mobile else 90, 0)
		chance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(chance)
		var b := Button.new()
		b.custom_minimum_size = Vector2(120 if mobile else 170, 34)
		var ok: String = op
		b.pressed.connect(func():
			if spy_target.selected >= 0:
				spy.emit(spy_target.get_item_id(spy_target.selected), ok))
		row.add_child(b)
		spy_rows[op] = {"chance": chance, "button": b}


func _refresh_spy(f: Dictionary) -> void:
	if spy_target == null:
		_build_spy_rows(gov_pages[8])
	var target: int = spy_target.get_item_id(spy_target.selected) if spy_target.selected >= 0 else -1
	var cd: float = world.spy_cooldown(human)
	spy_status.text = ("Агенты отдыхают: %d с" % int(ceil(cd))) if cd > 0.0 else "Агенты готовы"
	for op in spy_rows:
		var r: Dictionary = spy_rows[op]
		var cost: int = Rules.SPY_OPS[op]["cost"]
		var alive: bool = target > 0 and world.factions[target]["alive"]
		r["chance"].text = ("%d%%" % int(round(world.spy_chance(human, target, op) * 100.0))) if alive else "—"
		r["button"].text = "Провести · " + Names.short_number(cost)
		r["button"].disabled = not alive or f["gold"] < cost or cd > 0.0


# ------------------------------------------------------------------ events and api

func _on_card_toggled(pressed: bool, kind: String) -> void:
	if _syncing:
		return
	mode_selected.emit(kind if pressed else "")


func _on_slider(v: float) -> void:
	attack_label.text = "%d%%" % int(round(v * 100.0))
	attack_size_changed.emit(v)


func toggle_card(kind: String) -> void:
	if not cards.has(kind) or cards[kind].disabled:
		return
	mode_selected.emit("" if cards[kind].button_pressed else kind)


func set_mode(kind: String) -> void:
	_syncing = true
	for k in cards:
		cards[k].button_pressed = (k == kind)
	_syncing = false
	match kind:
		"city":
			set_status("Клик по своей земле: город поднимает лимит и рост армии. Esc — отмена")
		"port":
			set_status("Клик по своему берегу: порт даёт золото и высадки с моря. Esc — отмена")
		"defense":
			set_status("Клик по своей земле: защита удорожает захват ваших клеток. Esc — отмена")
		"market":
			set_status("Клик по своей земле: рынок приносит +12 золота в секунду. Esc — отмена")
		"barracks":
			set_status("Клик по своей земле: казармы поднимают лимит и рост армии. Esc — отмена")
		"bunker":
			set_status("Клик по своей земле: бункер сбивает чужие бомбы в радиусе 16 клеток. Esc — отмена")
		"nuke", "mega":
			set_status("Клик по цели: через 3 секунды земля в радиусе станет ничьей и выжженной. Esc — отмена")
		_:
			if Rules.BUILDINGS.has(kind):
				var bd: Dictionary = Rules.BUILDINGS[kind]
				set_status("Клик по %s: %s. Esc — отмена" % ["своему берегу" if bd["coast"] else "своей земле", bd["name"]])
			else:
				set_status("")


func set_status(text: String) -> void:
	status_label.text = text
	status_label.visible = text != ""


func set_tooltip(text: String, at: Vector2) -> void:
	if text == "":
		tooltip.visible = false
		return
	tooltip_label.text = text
	tooltip.visible = true
	tooltip.size = tooltip.get_combined_minimum_size()
	var p := at + Vector2(18, 18)
	p.x = minf(p.x, size.x - tooltip.size.x - 8)
	p.y = minf(p.y, size.y - tooltip.size.y - 8)
	tooltip.position = p


func toast(text: String, color: Color = Color(1, 0.95, 0.8)) -> void:
	toast_label.text = text
	# incoming colours are the old light-on-dark hints; map them to a pill colour and keep the text dark
	var pill_color := ThemeFactory.PANEL
	if color.r > 0.9 and color.g < 0.7:
		pill_color = ThemeFactory.PEACH
	elif color.g > 0.9 and color.r < 0.9:
		pill_color = ThemeFactory.LIME
	elif color.b > 0.9 and color.r < 0.9:
		pill_color = ThemeFactory.SKY
	elif color.r > 0.9 and color.g > 0.8 and color.b < 0.5:
		pill_color = ThemeFactory.LEMON
	toast_label.add_theme_stylebox_override("normal", ThemeFactory.pill(pill_color, 6, 12))
	toast_label.add_theme_color_override("font_color", ThemeFactory.TEXT)
	toast_label.modulate.a = 1.0
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6).set_delay(2.2)


func show_result(title: String, body: String, can_continue: bool, continue_text: String = "Смотреть дальше") -> void:
	overlay_title.text = title
	overlay_body.text = body
	overlay_continue.visible = can_continue
	overlay_continue.text = continue_text
	overlay.visible = true


# ------------------------------------------------------------------ per-frame refresh

func refresh(delta: float) -> void:
	if world == null:
		return
	var f: Dictionary = world.factions[human]
	var spawning: bool = world.phase == world.Phase.SPAWN
	for k in cards:
		cards[k].disabled = spawning
	if spawning:
		var left := int(ceil(world.spawn_seconds_left()))
		timer_bar.value = 0.0
		timer_label.text = "До начала: %d с" % left
		set_status("Выберите точку старта: кликните по свободной земле (автостарт через %d с)" % left)
	else:
		var goal: float = Rules.WIN_LAND_SHARE * 100.0
		if f["alive"]:
			var share: float = world.land_share(human) * 100.0
			var lead_goal: float = Rules.WIN_LEAD_SHARE * 100.0
			var lead_s: float = world.lead_seconds()
			if lead_s > 0.0 and world.leader() == human:
				timer_bar.value = clampf(lead_s / Rules.WIN_LEAD_SECONDS, 0.0, 1.0)
				timer_label.text = "Вы бесспорный лидер: победа через %d с" % int(ceil(Rules.WIN_LEAD_SECONDS - lead_s))
			else:
				timer_bar.value = clampf(share / goal, 0.0, 1.0)
				timer_label.text = "Победа: %d%% карты или %d%% и вдвое больше второго · у вас %.1f%%" % [int(goal), int(lead_goal), share]
		else:
			var lead: int = world.leader()
			timer_bar.value = clampf(world.land_share(lead) * 100.0 / goal, 0.0, 1.0)
			timer_label.text = "Вы выбыли · лидер %s: %.1f%%" % [world.factions[lead]["name"], world.land_share(lead) * 100.0]
		var sd: Dictionary = Rules.SEASONS[world.season]
		var left: int = Rules.SEASON_SECONDS - int(world.seconds()) % Rules.SEASON_SECONDS
		season_label.text = "%s · %s · %d с" % [sd["name"], sd["desc"], left] + (" · бонус догоняющего +15%" if world.catch_up else "")

	var cap: float = world.max_troops_of(human)
	army_value.text = Names.short_number(f["troops"])
	army_cap.text = "/ " + Names.short_number(cap)
	army_bar.value = clampf(f["troops"] / maxf(1.0, cap), 0.0, 1.0)
	army_rate.text = "+%s / сек" % Names.short_number(world.growth_of(human))
	gold_value.text = Names.short_number(f["gold"])
	gold_rate.text = "+%s / сек" % Names.short_number(world.gold_rate_of(human))
	var approval: float = f["approval"]
	approval_value.text = "%d%%" % int(approval)
	var ac := ThemeFactory.GREEN if approval >= 50.0 else (Color("#D9731F") if approval >= 25.0 else ThemeFactory.RED)
	approval_value.add_theme_color_override("font_color", ac)
	approval_bar.value = approval / 100.0
	if not spawning:
		var secs: int = int(world.seconds_to_election(human))
		@warning_ignore("integer_division")
		election_label.text = "выборы через %d:%02d" % [secs / 60, secs % 60]

	attack_troops.text = Names.short_number(f["troops"] * attack_slider.value) + " войск"
	for kind in card_costs:
		var cost: int = world.building_cost(kind, human)
		var l: Label = card_costs[kind]
		var locked: bool = (kind == "nuke" and world.tech_level(human, "nuclear") == 0) or (kind == "mega" and world.tech_level(human, "rockets") == 0)
		if locked:
			l.text = "нужна техн."
			l.add_theme_color_override("font_color", ThemeFactory.TEXT_DIM)
		else:
			l.text = Names.short_number(cost)
			l.add_theme_color_override("font_color", ThemeFactory.TEXT if f["gold"] >= cost else ThemeFactory.RED)
	if tech_panel.visible and _attacks_timer <= 0.0:
		_refresh_tech()
	if people_panel.visible and _attacks_timer <= 0.0:
		_refresh_people()
	if missions_panel.visible and _lb_timer <= 0.0:
		_refresh_missions()
	if autopilot_panel.visible and _lb_timer <= 0.0:
		_refresh_autopilot()
	if gov_panel.visible and _lb_timer <= 0.0:
		_refresh_gov()

	_lb_timer -= delta
	if _lb_timer <= 0.0:
		_lb_timer = 0.5
		_refresh_leaderboard()
	_attacks_timer -= delta
	if _attacks_timer <= 0.0:
		_attacks_timer = 0.25
		_refresh_attacks()


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
		var c: Color = Color("#D9731F") if f["id"] == human else ThemeFactory.TEXT
		r["name"].add_theme_color_override("font_color", c)
		r["rank"].add_theme_color_override("font_color", c)


func _refresh_attacks() -> void:
	for child in attacks_box.get_children():
		child.queue_free()
	var mine: Array = world.attacks_of(human)
	var ships: Array = world.ships_of(human)
	var incoming: Array = world.incoming_attacks(human)
	if mine.is_empty() and ships.is_empty() and incoming.is_empty():
		attacks_panel.visible = false
		return
	attacks_panel.visible = true
	attacks_box.add_child(_label("БОИ", 11, ThemeFactory.TEXT_DIM))
	for a in mine:
		var row := HBoxContainer.new()
		var who: String = "ничья земля" if a["target"] == 0 else world.factions[a["target"]]["name"]
		var l := _label("→ %s · %s" % [who, Names.short_number(a["troops"])], 12)
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		l.clip_text = true
		row.add_child(l)
		var b := Button.new()
		b.text = "✕"
		b.custom_minimum_size = Vector2(28, 24)
		b.tooltip_text = "Отозвать войска"
		var t: int = a["target"]
		b.pressed.connect(func(): cancel_attack.emit(t))
		row.add_child(b)
		attacks_box.add_child(row)
	for s in ships:
		var who: String = "ничья земля" if s["target"] == 0 else world.factions[s["target"]]["name"]
		attacks_box.add_child(_label("⛵ %s · %s (%d с)" % [who, Names.short_number(s["troops"]), int(ceil(s["ticks_left"] * Rules.TICK_DT))], 12))
	for a in incoming:
		attacks_box.add_child(_label("← %s · %s" % [world.factions[a["attacker"]]["name"], Names.short_number(a["troops"])], 12, ThemeFactory.RED))
