extends Control
## Match scene: wooden frame, the map in a SubViewport, HUD, labels, minimap, effects and sounds.
## Command line (after "--"): --screenshot=PATH  --run-ticks=N  --fast  --demo  --open-exit  --seed=N

const MapData := preload("res://scripts/map/map_data.gd")
const World := preload("res://scripts/sim/world.gd")
const MapView := preload("res://scripts/map/map_view.gd")
const BuildingLayer := preload("res://scripts/map/building_layer.gd")
const EffectsLayer := preload("res://scripts/map/effects_layer.gd")
const WorldScene := preload("res://scripts/map/world_scene.gd")
const GameCamera := preload("res://scripts/camera/game_camera.gd")
const MapLabels := preload("res://scripts/ui/map_labels.gd")
const Minimap := preload("res://scripts/ui/minimap.gd")
const Rules := preload("res://scripts/sim/rules.gd")
const Names := preload("res://scripts/sim/names.gd")
const HudScene := preload("res://scenes/ui/hud.tscn")
const ExitDialogScene := preload("res://scenes/ui/exit_dialog.tscn")

var map
var world
var view
var camera
var world_node
var container: SubViewportContainer
var hud
var labels
var minimap
var exit_dialog
var human: int = 1
var mode := ""
var speed := 1.0
var _acc := 0.0
var _last_cells := 0
var hovered_cell := -1
var screenshot_path := ""
var game_seed: int = int(Time.get_unix_time_from_system()) % 1000000


func _settings():
	return get_node_or_null("/root/Settings")


func _sfx(name: String, volume_db: float = 0.0, min_interval: float = 0.0) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s != null:
		s.play(name, volume_db, min_interval)


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_read_seed_arg()
	map = MapData.new()
	var settings = _settings()
	var nick: String = settings.nickname if settings != null else "Вы"
	world = World.new(map, game_seed, nick)
	human = world.human

	var wood := ColorRect.new()
	wood.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	wood.mouse_filter = MOUSE_FILTER_IGNORE
	var wood_mat := ShaderMaterial.new()
	wood_mat.shader = load("res://shaders/wood.gdshader")
	wood.material = wood_mat
	add_child(wood)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 132)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(margin)
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.03)
	sb.border_color = Color(0.62, 0.48, 0.30)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel", sb)
	margin.add_child(frame)
	container = SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = SIZE_EXPAND_FILL
	container.size_flags_vertical = SIZE_EXPAND_FILL
	frame.add_child(container)
	var vp := SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	container.add_child(vp)
	world_node = WorldScene.new()
	world_node.map = map
	vp.add_child(world_node)
	var sea := ColorRect.new()
	sea.color = Color(0.29, 0.54, 0.84)
	sea.position = Vector2(-4000, -4000)
	sea.size = Vector2(8000 + map.width, 8000 + map.height)
	sea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_node.add_child(sea)
	view = MapView.new(map, world)
	world_node.add_child(view)
	world_node.add_child(BuildingLayer.new(map, world))
	world_node.add_child(EffectsLayer.new(map, world))
	camera = GameCamera.new()
	camera.map_size = Vector2(map.width, map.height)
	camera.zoom_index = 0
	world_node.add_child(camera)
	camera.make_current()

	labels = MapLabels.new()
	add_child(labels)
	labels.setup(world, camera, container)
	hud = HudScene.instantiate()
	add_child(hud)
	hud.setup(world)
	if settings != null:
		hud.set_muted(settings.muted)
	minimap = Minimap.new()
	minimap.setup(map, world, camera, container, view.mat)
	minimap.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	minimap.offset_left = 44
	minimap.offset_right = 44 + minimap.custom_minimum_size.x
	minimap.offset_top = -140 - minimap.custom_minimum_size.y
	minimap.offset_bottom = -140
	add_child(minimap)
	exit_dialog = ExitDialogScene.instantiate()
	add_child(exit_dialog)

	world_node.cell_clicked.connect(_on_cell_clicked)
	world_node.cell_hovered.connect(_on_cell_hovered)
	camera.right_clicked.connect(func(_p): _set_mode(""))
	minimap.focus_requested.connect(func(c): camera.focus_on(map.cell(c)))
	hud.mode_selected.connect(_set_mode)
	hud.attack_size_changed.connect(func(v): world.factions[human]["attack_size"] = v)
	hud.cancel_attack.connect(func(t): world.apply({"type": "cancel", "player": human, "target": t}))
	hud.exit_pressed.connect(func(): exit_dialog.open())
	hud.mute_toggled.connect(_toggle_mute)
	hud.research.connect(func(k): world.apply({"type": "research", "player": human, "tech": k}))
	hud.admin_code.connect(func(code): world.apply({"type": "admin", "player": human, "code": code}))
	hud.zoom_requested.connect(func(step): camera.zoom_step(step))
	hud.menu_requested.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	hud.restart_requested.connect(func(): get_tree().reload_current_scene())
	world.match_started.connect(_on_match_started)
	world.action_rejected.connect(_on_action_rejected)
	world.attack_launched.connect(_on_attack_launched)
	world.ship_launched.connect(_on_ship_launched)
	world.ship_landed.connect(_on_ship_landed)
	world.nuke_launched.connect(_on_nuke_launched)
	world.nuke_detonated.connect(func(_c, _r): _sfx("boom"))
	world.nuke_intercepted.connect(_on_nuke_intercepted)
	world.tech_researched.connect(_on_tech_researched)
	world.admin_enabled.connect(func(_f):
		hud.toast("Админ-режим: золото и армия бесконечны", Color(1, 0.85, 0.35))
		_sfx("win"))
	world.faction_eliminated.connect(_on_faction_eliminated)
	world.match_finished.connect(_on_match_finished)
	world.building_placed.connect(_on_building_placed)
	hud.set_mode("")
	await get_tree().process_frame
	camera.center_map()
	_handle_args()


# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	_acc += delta * speed
	var n := 0
	while _acc >= Rules.TICK_DT and n < 50:
		_acc -= Rules.TICK_DT
		world.step()
		n += 1
	var cells: int = world.factions[human]["cells"]
	if cells > _last_cells and _last_cells > 0:
		_sfx("capture", -8.0, 0.09)
	_last_cells = cells
	hud.refresh(delta)
	_refresh_tooltip()


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if mode != "":
			_set_mode("")
		else:
			exit_dialog.open()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var keys := {KEY_1: "defense", KEY_2: "city", KEY_3: "port", KEY_4: "market", KEY_5: "barracks",
			KEY_6: "bunker", KEY_7: "nuke", KEY_8: "mega"}
		if keys.has(event.physical_keycode):
			hud.toggle_card(keys[event.physical_keycode])
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_T:
			hud.toggle_tech()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_M:
			_toggle_mute()
			get_viewport().set_input_as_handled()


func _on_cell_hovered(i: int) -> void:
	hovered_cell = i
	view.set_hover_owner(world.owner[i] if i >= 0 else 0)


func _refresh_tooltip() -> void:
	var over_map: bool = hovered_cell >= 0 and get_viewport().gui_get_hovered_control() == container
	if not over_map or exit_dialog.visible:
		hud.set_tooltip("", Vector2.ZERO)
		return
	var text := ""
	var i := hovered_cell
	if world.phase == world.Phase.SPAWN:
		text = "Начать здесь" if world.owner[i] == 0 and map.is_land(i) else "Здесь начать нельзя"
	elif not map.is_land(i):
		text = "Море" if map.is_sea(i) else ("Озеро" if map.terrain[i] == map.LAKE else "Вне карты")
	else:
		var o: int = world.owner[i]
		var f: Dictionary = world.factions[human]
		if o == 0:
			text = "Ничья земля"
		elif o == human:
			text = "%s (вы)\n%s войск · %.2f%% земли" % [f["name"], Names.short_number(f["troops"]), world.land_share(human) * 100.0]
		else:
			var d: Dictionary = world.factions[o]
			var kind: String = "город-государство" if d["kind"] == world.Kind.CITY else "игрок"
			text = "%s (%s)\n%s войск · %.2f%% земли" % [d["name"], kind, Names.short_number(d["troops"]), world.land_share(o) * 100.0]
		if o != human and f["cells"] > 0:
			text += "\nЗахват: ~%.1f войск за клетку" % world.capture_cost(human, o, i)
		if world.scorched.has(i):
			text += "\nВыжжено"
	hud.set_tooltip(text, get_global_mouse_position())


func _on_cell_clicked(i: int) -> void:
	if i < 0:
		return
	if world.phase == world.Phase.SPAWN:
		world.apply({"type": "spawn", "player": human, "cell": i})
		return
	if hud.tech_panel.visible:
		hud.toggle_tech()
	if mode == "nuke" or mode == "mega":
		var r: Dictionary = world.apply({"type": "nuke", "player": human, "cell": i, "mega": mode == "mega"})
		if r["ok"]:
			_set_mode("")
	elif mode != "":
		var r: Dictionary = world.apply({"type": "build", "player": human, "kind": mode, "cell": i})
		if r["ok"]:
			_set_mode("")
	else:
		world.apply({"type": "attack", "player": human, "cell": i, "ratio": world.factions[human]["attack_size"]})


func _set_mode(kind: String) -> void:
	mode = kind
	hud.set_mode(kind)
	_sfx("click", -10.0)


func _toggle_mute() -> void:
	var settings = _settings()
	if settings == null:
		return
	settings.muted = not settings.muted
	settings.save()
	hud.set_muted(settings.muted)


# ------------------------------------------------------------------ world events

func _on_match_started() -> void:
	var spawn: int = world.factions[human]["spawn"]
	camera.zoom_index = 1
	camera._apply_zoom()
	camera.focus_on(map.cell(spawn))
	hud.toast("Матч начался! Расширяйтесь, пока земля свободна", Color(0.8, 1, 0.8))
	_sfx("start")


func _on_action_rejected(a: Dictionary, reason: String) -> void:
	if a["player"] == human:
		hud.toast(reason, Color(1, 0.6, 0.5))
		_sfx("error", -8.0, 0.2)


func _on_attack_launched(fid: int, target: int, _cell: int, troops: float) -> void:
	if fid == human:
		_sfx("attack")
	elif target == human:
		hud.toast("%s атакует вас: %s войск" % [world.factions[fid]["name"], Names.short_number(troops)], Color(1, 0.55, 0.45))
		_sfx("attack", -4.0, 0.5)


func _on_ship_launched(fid: int, _from: int, _to: int, ticks: int) -> void:
	if fid == human:
		hud.toast("Корабли вышли в море: высадка через %d с" % int(ceil(ticks * Rules.TICK_DT)), Color(0.8, 0.9, 1))
		_sfx("ship")


func _on_ship_landed(fid: int, _cell: int, success: bool) -> void:
	if fid == human:
		hud.toast("Высадка началась!" if success else "Высадка сорвалась: берег уже занят другими", Color(0.8, 1, 0.8) if success else Color(1, 0.6, 0.5))


func _on_nuke_launched(fid: int, _from: int, _to: int, _ticks: int, mega: bool) -> void:
	_sfx("launch", 0.0 if fid == human else -6.0)
	if fid != human:
		hud.toast("%s запускает %s!" % [world.factions[fid]["name"], "MEGA NUKE" if mega else "ядерную бомбу"], Color(1, 0.7, 0.4))


func _on_nuke_intercepted(_cell: int, by: int) -> void:
	hud.toast("Бомба сбита бункером (%s)" % world.factions[by]["name"], Color(0.8, 0.9, 1))
	_sfx("error", -4.0)


func _on_tech_researched(fid: int, key: String, level: int) -> void:
	if fid == human:
		hud.toast("Изучено: %s (уровень %d)" % [Rules.TECHS[key]["name"], level], Color(0.85, 0.75, 1))
		_sfx("build")


func _on_building_placed(fid: int, kind: String, _cell: int) -> void:
	if fid == human:
		var names := {"city": "Город", "port": "Порт", "defense": "Защита", "market": "Рынок", "barracks": "Казармы", "bunker": "Бункер"}
		hud.toast("%s: построено" % names[kind], Color(0.75, 1, 0.75))
		_sfx("build")


func _on_faction_eliminated(fid: int, by: int) -> void:
	if fid == human:
		_sfx("lose")
		hud.show_result("Поражение", "Ваши земли захватил %s\nМесто: #%d из %d" % [world.factions[by]["name"], world.rank_of(human), world.ranking().size()], true)
	elif by == human:
		hud.toast("Уничтожено: %s" % world.factions[fid]["name"], Color(0.75, 1, 0.75))
		_sfx("build")
	elif world.factions[fid]["kind"] != world.Kind.CITY:
		hud.toast("%s выбывает" % world.factions[fid]["name"], Color(0.9, 0.9, 0.9))


func _on_match_finished(winner: int) -> void:
	var lines: Array = []
	var ranking: Array = world.ranking()
	for i in mini(5, ranking.size()):
		var f: Dictionary = ranking[i]
		lines.append("%d. %s — %.1f%%" % [i + 1, f["name"], world.land_share(f["id"]) * 100.0])
	var title := "Победа!" if winner == human else "Матч окончен"
	_sfx("win" if winner == human else "lose")
	hud.show_result(title, "\n".join(lines) + "\n\nВаше место: #%d" % world.rank_of(human), false)


# ------------------------------------------------------------------ command line helpers

func _read_seed_arg() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			game_seed = int(a.get_slice("=", 1))


func _handle_args() -> void:
	var run_ticks := 0
	var demo := false
	var open_exit := false
	var open_tech := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="):
			screenshot_path = a.get_slice("=", 1)
		elif a.begins_with("--run-ticks="):
			run_ticks = int(a.get_slice("=", 1))
		elif a == "--fast":
			speed = 10.0
		elif a == "--demo":
			demo = true
		elif a == "--open-exit":
			open_exit = true
		elif a == "--open-tech":
			open_tech = true
	if run_ticks > 0 or demo:
		world.auto_spawn_human()
	if demo:
		_run_demo()
	for i in run_ticks:
		world.step()
	if open_exit:
		exit_dialog.open()
	if open_tech:
		hud.toggle_tech()
	if screenshot_path != "":
		_take_screenshot()


func _run_demo() -> void:
	var f: Dictionary = world.factions[human]
	f["gold"] = 100000.0
	f["troops"] = 3000.0
	f["tech"]["nuclear"] = 1
	var spawn: int = f["spawn"]
	world.apply({"type": "build", "player": human, "kind": "city", "cell": spawn})
	var target := -1
	for i in f["border"]:
		for n in map.neighbors(i):
			if world.owner[n] == 0 and map.is_land(n):
				target = n
				break
		if target != -1:
			break
	if target != -1:
		world.apply({"type": "attack", "player": human, "cell": target, "ratio": 0.5})
	for i in 200:
		world.step()
	# nuke the nearest city-state to show craters
	var best := 0
	var best_d := INF
	var c0: Vector2 = world.centroid(human)
	for id in range(1, world.factions.size()):
		if world.factions[id]["kind"] == world.Kind.CITY:
			var d: float = world.centroid(id).distance_squared_to(c0)
			if d < best_d:
				best_d = d
				best = id
	if best != 0:
		world.apply({"type": "nuke", "player": human, "cell": world.centroid_cell(best), "mega": false})
		for i in 45:
			world.step()
	camera.zoom_index = 2
	camera._apply_zoom()
	camera.focus_on(map.cell(spawn))


func _take_screenshot() -> void:
	for i in 8:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(screenshot_path)
	print("screenshot saved to ", screenshot_path, " (", img.get_width(), "x", img.get_height(), ")")
	get_tree().quit()
