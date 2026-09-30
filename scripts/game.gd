extends Control
## Match scene: wooden frame, the map in a SubViewport, HUD, labels, effects, sounds, profile and saves.
## Command line (after "--"): --screenshot=PATH  --run-ticks=N  --fast  --demo  --open-exit  --seed=N

const MapData := preload("res://scripts/map/map_data.gd")
const World := preload("res://scripts/sim/world.gd")
const MapView := preload("res://scripts/map/map_view.gd")
const BuildingLayer := preload("res://scripts/map/building_layer.gd")
const EffectsLayer := preload("res://scripts/map/effects_layer.gd")
const ResourceLayer := preload("res://scripts/map/resource_layer.gd")
const Resources := preload("res://scripts/sim/resources.gd")
const WorldScene := preload("res://scripts/map/world_scene.gd")
const GameCamera := preload("res://scripts/camera/game_camera.gd")
const MapLabels := preload("res://scripts/ui/map_labels.gd")
const Save := preload("res://scripts/sim/save.gd")
const Scenarios := preload("res://scripts/sim/scenarios.gd")
const Achievements := preload("res://scripts/sim/achievements.gd")
const Missions := preload("res://scripts/sim/missions.gd")
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
var loaded_from_save := false
var _ach_timer := 0.0
var _autosave_timer := 0.0
var _result_counted := false
var exit_dialog
var human: int = 1
var mode := ""
var speed := 1.0
var _acc := 0.0
var _last_cells := 0
var hovered_cell := -1
var season_tint: ColorRect
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
	if settings != null and settings.load_save and Save.exists():
		settings.load_save = false
		world = Save.load_world(map)
		loaded_from_save = world != null
	if world == null:
		world = World.new(map, game_seed, nick)
		if settings != null:
			world.difficulty = clampi(settings.difficulty, 0, Rules.DIFFICULTIES.size() - 1)
			world.scenario = settings.scenario
	human = world.human
	if settings != null and not loaded_from_save:
		var idx: int = clampi(settings.color_index, 0, Rules.PLAYER_COLORS.size() - 1)
		world.factions[human]["color"] = Color(Rules.PLAYER_COLORS[idx])

	var wood := ColorRect.new()
	wood.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	wood.mouse_filter = MOUSE_FILTER_IGNORE
	var wood_mat := ShaderMaterial.new()
	wood_mat.shader = load("res://shaders/wood.gdshader")
	wood.material = wood_mat
	add_child(wood)

	# the map fills the whole window; panels float on top of it
	container = SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(container)
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
	world_node.add_child(ResourceLayer.new(map))
	world_node.add_child(BuildingLayer.new(map, world))
	world_node.add_child(EffectsLayer.new(map, world))
	season_tint = ColorRect.new()
	season_tint.color = Color(1, 1, 1, 0)
	season_tint.position = Vector2(-4000, -4000)
	season_tint.size = Vector2(8000 + map.width, 8000 + map.height)
	season_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	season_tint.z_index = 2
	world_node.add_child(season_tint)
	camera = GameCamera.new()
	camera.map_size = Vector2(map.width, map.height)
	camera.zoom_index = 0
	world_node.add_child(camera)
	camera.make_current()
	world_node.camera = camera

	labels = MapLabels.new()
	add_child(labels)
	labels.setup(world, camera, container)
	hud = HudScene.instantiate()
	add_child(hud)
	hud.setup(world)
	exit_dialog = ExitDialogScene.instantiate()
	add_child(exit_dialog)
	exit_dialog.set_muted(settings != null and settings.muted)
	exit_dialog.mute_toggled.connect(_toggle_mute)
	exit_dialog.admin_code.connect(func(code): world.apply({"type": "admin", "player": human, "code": code}))

	world_node.cell_clicked.connect(_on_cell_clicked)
	world_node.cell_hovered.connect(_on_cell_hovered)
	camera.right_clicked.connect(func(_p): _set_mode(""))
	hud.mode_selected.connect(_set_mode)
	hud.attack_size_changed.connect(func(v): world.factions[human]["attack_size"] = v)
	hud.cancel_attack.connect(func(t): world.apply({"type": "cancel", "player": human, "target": t}))
	hud.exit_pressed.connect(func(): exit_dialog.open())
	hud.research.connect(func(k): world.apply({"type": "research", "player": human, "tech": k}))
	hud.zoom_requested.connect(func(step): camera.zoom_step(step))
	hud.tax_changed.connect(func(level): world.apply({"type": "tax", "player": human, "level": level}))
	hud.decree.connect(func(kind): world.apply({"type": "decree", "player": human, "kind": kind}))
	hud.event_choice.connect(func(idx): world.apply({"type": "event_choice", "player": human, "choice": idx}))
	hud.hire.connect(func(m): world.apply({"type": "hire", "player": human, "minister": m}))
	hud.fire.connect(func(m): world.apply({"type": "fire", "player": human, "minister": m}))
	hud.agitate.connect(func(p): world.apply({"type": "agitate", "player": human, "party": p}))
	hud.bill.connect(func(b): world.apply({"type": "bill", "player": human, "bill": b}))
	hud.budget_changed.connect(func(item, level): world.apply({"type": "budget", "player": human, "item": item, "level": level}))
	hud.repeal.connect(func(b): world.apply({"type": "repeal", "player": human, "bill": b}))
	hud.reform.connect(func(axis, option): world.apply({"type": "reform", "player": human, "axis": axis, "option": option}))
	hud.project.connect(func(p): world.apply({"type": "project", "player": human, "project": p}))
	hud.gift.connect(func(t): world.apply({"type": "gift", "player": human, "target": t}))
	hud.pact.connect(func(t): world.apply({"type": "pact", "player": human, "target": t}))
	hud.continue_requested.connect(func(): world.resume())
	hud.trade_deal.connect(func(t): world.apply({"type": "trade_deal", "player": human, "target": t}))
	hud.alliance.connect(func(t): world.apply({"type": "alliance", "player": human, "target": t}))
	hud.vassalize.connect(func(t): world.apply({"type": "vassalize", "player": human, "target": t}))
	hud.spy.connect(func(t, op): world.apply({"type": "spy", "player": human, "target": t, "op": op}))
	hud.autopilot_changed.connect(func(task, on): world.apply({"type": "autopilot", "player": human, "task": task, "on": on}))
	hud.speed_changed.connect(func(s): speed = s)
	hud.rate_changed.connect(func(l): world.apply({"type": "rate", "player": human, "level": l}))
	hud.loan.connect(func(a): world.apply({"type": "loan", "player": human, "amount": a}))
	hud.repay.connect(func(a): world.apply({"type": "repay", "player": human, "amount": a}))
	hud.emission.connect(func(): world.apply({"type": "emission", "player": human}))
	hud.policy_changed.connect(func(g, p): world.apply({"type": "policy", "player": human, "good": g, "policy": p}))
	hud.buy_goods.connect(func(g, a): world.apply({"type": "buy", "player": human, "good": g, "amount": a}))
	hud.sell_goods.connect(func(g, a): world.apply({"type": "sell", "player": human, "good": g, "amount": a}))
	world.economy_event.connect(func(fid, text):
		if fid == human:
			hud.toast(text, Color(1, 0.85, 0.35))
			_sfx("error" if text.begins_with("Дефолт") else "build"))
	exit_dialog.save_requested.connect(_save_game)
	world.trade_signed.connect(func(fid, target):
		if fid == human:
			hud.toast("Торговый договор с %s на %d с" % [world.factions[target]["name"], Rules.TRADE_SECONDS], Color(0.75, 1, 0.75))
			_sfx("build"))
	world.alliance_formed.connect(func(fid, target):
		if fid == human:
			hud.toast("Союз с %s!" % world.factions[target]["name"], Color(0.75, 1, 0.75))
			_sfx("win"))
	world.vassal_gained.connect(func(fid, target):
		if fid == human:
			hud.toast("%s стал вашим вассалом и платит дань" % world.factions[target]["name"], Color(0.85, 0.75, 1))
			_sfx("win"))
	world.spy_result.connect(func(fid, _target, _op, success, text):
		if fid == human:
			hud.toast(text, Color(0.75, 1, 0.75) if success else Color(1, 0.6, 0.5))
			_sfx("build" if success else "error")
		elif _target == human:
			hud.toast("Чужие агенты: %s" % text, Color(1, 0.7, 0.4))
			_sfx("error", -4.0))
	world.mission_done.connect(_on_mission_done)
	world.news_posted.connect(func(text, kind): hud.news.push(text, kind))
	world.bill_repealed.connect(func(fid, key):
		if fid == human:
			hud.toast("Закон отменён: %s" % Rules.BILLS[key]["name"], Color(1, 0.9, 0.7))
			_sfx("build"))
	world.reform_changed.connect(func(fid, axis, option):
		if fid == human:
			hud.toast("%s: %s" % [Rules.REFORMS[axis]["name"], Rules.REFORMS[axis]["options"][option]["name"]], Color(0.85, 0.75, 1))
			_sfx("win"))
	world.project_started.connect(func(fid, key):
		if fid == human:
			hud.toast("Нацпроект начат: %s (%d с)" % [Rules.PROJECTS[key]["name"], int(Rules.PROJECTS[key]["duration"])], Color(0.85, 0.95, 1))
			_sfx("build"))
	world.project_done.connect(func(fid, key):
		if fid == human:
			hud.toast("Нацпроект завершён: %s" % Rules.PROJECTS[key]["name"], Color(0.75, 1, 0.75))
			_sfx("win"))
	world.pact_signed.connect(func(fid, target):
		if fid == human:
			hud.toast("Пакт о ненападении с %s на %d с" % [world.factions[target]["name"], Rules.PACT_SECONDS], Color(0.75, 1, 0.75))
			_sfx("win"))
	world.gift_sent.connect(func(fid, target, relation):
		if fid == human:
			hud.toast("Подарок отправлен: отношения с %s теперь %d" % [world.factions[target]["name"], int(relation)], Color(0.85, 0.95, 1))
			_sfx("build"))
	world.bill_result.connect(func(fid, key, passed, support):
		if fid == human:
			var name: String = Rules.BILLS[key]["name"]
			if passed:
				hud.toast("Закон принят: %s (%d мест за)" % [name, support], Color(0.75, 1, 0.75))
				_sfx("win")
			else:
				hud.toast("Закон отклонён: %s (%d из %d мест)" % [name, support, Rules.BILL_MAJORITY], Color(1, 0.6, 0.5))
				_sfx("error"))
	world.minister_changed.connect(func(fid, key, hired):
		if fid == human:
			hud.toast(("Нанят: %s" if hired else "Уволен: %s") % Rules.MINISTERS[key]["name"], Color(0.85, 0.95, 1))
			_sfx("build"))
	world.duma_changed.connect(func(fid, _seats, ruling):
		if fid == human and world.phase == world.Phase.PLAY:
			hud.toast("Госдума: правит %s" % Rules.PARTIES[ruling]["name"], Color(0.85, 0.75, 1)))
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
	world.election_result.connect(_on_election)
	world.event_offered.connect(func(fid, e):
		if fid == human:
			hud.show_event(e)
			_sfx("click"))
	world.event_resolved.connect(func(fid, text):
		if fid == human:
			hud.hide_event()
			hud.toast(text, Color(1, 0.95, 0.8)))
	world.unrest.connect(func(fid, lost):
		if fid == human:
			hud.toast("Волнения: народ уходит, потеряно клеток: %d. Снизьте налоги или издайте указ" % lost, Color(1, 0.55, 0.45))
			_sfx("error", -4.0, 1.0))
	world.decree_applied.connect(func(fid, kind):
		if fid == human:
			var names := {"propaganda": "Пропаганда", "festival": "Праздник", "mobilize": "Мобилизация"}
			var label: String = names.get(kind, Rules.EXTRA_DECREES[kind]["name"] if Rules.EXTRA_DECREES.has(kind) else kind)
			hud.toast("Указ: %s" % label, Color(0.85, 0.95, 1))
			_sfx("build"))
	world.admin_enabled.connect(func(_f):
		hud.toast("Админ-режим: бесконечные золото и армия, все технологии открыты", Color(1, 0.85, 0.35))
		_sfx("win"))
	world.faction_eliminated.connect(_on_faction_eliminated)
	world.match_finished.connect(_on_match_finished)
	world.season_changed.connect(_on_season_changed)
	world.building_placed.connect(_on_building_placed)
	hud.set_mode("")
	var settings2 = _settings()
	if settings2 != null:
		hud.set_profile(_profile_text(), settings2.unlocked)
	await get_tree().process_frame
	camera.center_map()
	if loaded_from_save:
		for c in world.buildings_at:
			world.building_placed.emit(world.buildings_at[c]["faction"], world.buildings_at[c]["kind"], c)
		world.territory_changed.emit()
		if world.phase != world.Phase.SPAWN:
			camera.zoom_index = 2
			camera._apply_zoom()
			camera.focus_on(world.centroid(human))
			hud.toast("Сохранённая игра загружена", Color(0.85, 0.95, 1))
			_on_season_changed(world.season)
	else:
		_place_scenario_capital()
	_handle_args()


# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	if world == null:
		return
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
	_ach_timer -= delta
	if _ach_timer <= 0.0:
		_ach_timer = 2.0
		_check_achievements()
	_autosave_timer += delta
	if _autosave_timer >= 90.0 and world.phase == world.Phase.PLAY and world.factions[human]["alive"]:
		_autosave_timer = 0.0
		Save.save(world)


# ------------------------------------------------------------------ input

## Wheel and trackpad gestures are handled here, before the GUI, so zoom works wherever the pointer is.
func _input(event: InputEvent) -> void:
	if exit_dialog.visible:
		return
	var pos: Vector2 = container.get_local_mouse_position()
	if event is InputEventMagnifyGesture:
		camera.magnify(event.factor, pos)
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		if event.ctrl_pressed or event.meta_pressed:
			camera.magnify(1.0 - event.delta.y * 0.02, pos)
		else:
			camera.pan_by(event.delta * 2.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if camera.wheel_ready():
			camera.zoom_at_screen(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1, pos)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k == KEY_EQUAL or k == KEY_PLUS or k == KEY_KP_ADD or k == KEY_BRACKETRIGHT:
			camera.zoom_step(1)
			get_viewport().set_input_as_handled()
		elif k == KEY_MINUS or k == KEY_KP_SUBTRACT or k == KEY_BRACKETLEFT:
			camera.zoom_step(-1)
			get_viewport().set_input_as_handled()
		elif k == KEY_F11 or (k == KEY_F and event.ctrl_pressed):
			_toggle_fullscreen()
			get_viewport().set_input_as_handled()


func _toggle_fullscreen() -> void:
	var w := get_window()
	if w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		w.mode = Window.MODE_WINDOWED
		w.size = Vector2i(1280, 800)
	else:
		w.mode = Window.MODE_FULLSCREEN


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
		elif event.physical_keycode == KEY_P:
			hud.toggle_people()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_G:
			hud.toggle_gov()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_M:
			_toggle_mute()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_Q:
			hud.toggle_missions()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_A:
			hud.toggle_autopilot()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_SPACE:
			hud.toggle_pause()
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
			var kind: String = "город-государство" if d["kind"] == world.Kind.CITY else ("игрок · " + Rules.PERSONAS.get(d["persona"], Rules.PERSONAS["trader"])["name"])
			text = "%s (%s)\n%s войск · %.2f%% земли" % [d["name"], kind, Names.short_number(d["troops"]), world.land_share(o) * 100.0]
		if o != human and f["cells"] > 0:
			text += "\nЗахват: ~%.1f войск за клетку" % world.capture_cost(human, o, i)
		if world.scorched.has(i):
			text += "\nВыжжено"
		if map.resources[i] != 0:
			var rk: int = map.resources[i]
			text += "\n%s: %s" % [Resources.KINDS[rk]["name"], Resources.KINDS[rk]["desc"]]
	hud.set_tooltip(text, get_global_mouse_position())


func _on_cell_clicked(i: int) -> void:
	if i < 0:
		return
	if world.phase == world.Phase.SPAWN:
		world.apply({"type": "spawn", "player": human, "cell": i})
		return
	if hud.tech_panel.visible:
		hud.toggle_tech()
	if hud.people_panel.visible:
		hud.toggle_people()
	if hud.gov_panel.visible:
		hud.toggle_gov()
	if hud.missions_panel.visible:
		hud.toggle_missions()
	if hud.autopilot_panel.visible:
		hud.toggle_autopilot()
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
	exit_dialog.set_muted(settings.muted)


# ------------------------------------------------------------------ world events

func _on_match_started() -> void:
	var spawn: int = world.factions[human]["spawn"]
	camera.zoom_index = 2
	camera._apply_zoom()
	camera.focus_on(map.cell(spawn))
	_apply_scenario()
	hud.toast("Матч начался! Расширяйтесь, пока земля свободна", Color(0.8, 1, 0.8))
	_sfx("start")


## Flavour bonuses of the chosen historical start (once, right after the capital is placed).
func _apply_scenario() -> void:
	var sc := Scenarios.get_def(world.scenario)
	if world.scenario == "free" or world.factions[human]["counters"].get("scenario_applied", 0) > 0:
		return
	var f: Dictionary = world.factions[human]
	f["counters"]["scenario_applied"] = 1
	f["troops"] *= float(sc["troops"])
	f["gold"] += (float(sc["gold"]) - 1.0) * Rules.START_GOLD
	if sc["tech"] != "":
		f["tech"][sc["tech"]] = maxi(1, world.tech_level(human, sc["tech"]))
	for b in sc["bills"]:
		f["bills"][b] = true
	f["mods_dirty"] = true
	hud.toast("%s: %s" % [sc["name"], sc["desc"]], Color(0.85, 0.75, 1))


## Historical start: the capital goes next to the scenario's city before the spawn phase ends.
func _place_scenario_capital() -> void:
	var sc := Scenarios.get_def(world.scenario)
	if sc["city"] == "" or world.phase != world.Phase.SPAWN:
		return
	var city := Scenarios.city_cell(map, sc["city"])
	if city == -1:
		return
	var spot: int = world.spawn_near(city)
	if spot != -1:
		world.apply({"type": "spawn", "player": human, "cell": spot})


func _profile_text() -> String:
	var settings = _settings()
	if settings == null:
		return ""
	var n := 0
	for k in settings.unlocked:
		if settings.unlocked[k]:
			n += 1
	var lvl: int = settings.level()
	return "%s · уровень %d · %s · %d XP (до следующего: %d) · достижений %d/%d" % [settings.nickname, lvl, settings.title(), settings.xp, settings.xp_for_level(lvl + 1) - settings.xp, n, Achievements.ORDER.size()]


func _check_achievements() -> void:
	var settings = _settings()
	if settings == null or world.phase == world.Phase.SPAWN:
		return
	var fresh: Array = Achievements.check_new(world, human, settings.unlocked)
	var mult: float = Rules.DIFFICULTIES[world.difficulty]["xp"]
	for key in fresh:
		settings.unlock(key)
		var a: Dictionary = Achievements.LIST[key]
		var gained: int = settings.add_xp(int(round(a["xp"] * mult)))
		hud.toast("Достижение: %s (+%d XP)" % [a["name"], int(round(a["xp"] * mult))], Color(1, 0.85, 0.35))
		hud.news.push("Достижение: %s" % a["name"], "you")
		_sfx("win")
		if gained > 0:
			hud.toast("Новый уровень %d: %s" % [settings.level(), settings.title()], Color(1, 0.85, 0.35))
	if not fresh.is_empty():
		settings.save()
	hud.set_profile(_profile_text(), settings.unlocked)


func _on_mission_done(fid: int, m: Dictionary) -> void:
	if fid != human:
		return
	var settings = _settings()
	var t: Dictionary = Missions.TEMPLATES[m["key"]]
	var xp: int = int(m["xp"])
	if settings != null:
		xp = int(round(xp * Rules.DIFFICULTIES[world.difficulty]["xp"]))
		var gained: int = settings.add_xp(xp)
		settings.stats["missions"] = int(settings.stats.get("missions", 0)) + 1
		settings.save()
		if gained > 0:
			hud.toast("Новый уровень %d: %s" % [settings.level(), settings.title()], Color(1, 0.85, 0.35))
	hud.toast("Задание выполнено: %s (+%s золота, +%d XP)" % [t["name"], Names.short_number(m["gold"]), xp], Color(0.75, 1, 0.75))
	hud.news.push("Задание выполнено: %s" % t["name"], "you")
	_sfx("win")


func _save_game() -> void:
	if Save.save(world):
		hud.toast("Игра сохранена. В главном меню появится кнопка «Продолжить»", Color(0.85, 0.95, 1))
	else:
		hud.toast("Не удалось сохранить", Color(1, 0.6, 0.5))


## XP and statistics for the match result (counted once per match).
func _count_result(won: bool) -> String:
	var settings = _settings()
	if settings == null or _result_counted:
		return ""
	_result_counted = true
	var share: float = world.land_share(human)
	var mult: float = Rules.DIFFICULTIES[world.difficulty]["xp"]
	var xp: int = int(round((50.0 + share * 400.0 + (150.0 if won else 0.0)) * mult))
	var gained: int = settings.add_xp(xp)
	settings.stats["matches"] = int(settings.stats.get("matches", 0)) + 1
	if won:
		settings.stats["wins"] = int(settings.stats.get("wins", 0)) + 1
	settings.stats["best_share"] = maxf(float(settings.stats.get("best_share", 0.0)), share)
	settings.save()
	Save.remove()
	var text := "+%d XP" % xp
	if gained > 0:
		text += " · новый уровень %d: %s" % [settings.level(), settings.title()]
	return text


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


func _on_election(fid: int, won: bool, approval: float) -> void:
	if fid == human:
		if won:
			hud.toast("Выборы выиграны: одобрение %d%%. Народ с вами!" % int(approval), Color(0.75, 1, 0.75))
			_sfx("win")
		else:
			hud.toast("Выборы проиграны: минуту штраф к росту и золоту. Поднимайте одобрение!", Color(1, 0.55, 0.45))
			_sfx("lose")


func _on_tech_researched(fid: int, key: String, level: int) -> void:
	if fid == human:
		hud.toast("Изучено: %s (уровень %d)" % [world.tech_def(key)["name"], level], Color(0.85, 0.75, 1))
		_sfx("build")


func _on_building_placed(fid: int, kind: String, _cell: int) -> void:
	if fid == human:
		var names := {"city": "Город", "port": "Порт", "defense": "Защита", "market": "Рынок", "barracks": "Казармы", "bunker": "Бункер"}
		var label: String = names.get(kind, Rules.BUILDINGS[kind]["name"] if Rules.BUILDINGS.has(kind) else kind)
		hud.toast("%s: построено" % label, Color(0.75, 1, 0.75))
		_sfx("build")


func _on_faction_eliminated(fid: int, by: int) -> void:
	if fid == human:
		_sfx("lose")
		var bonus := _count_result(false)
		hud.show_result("Поражение", "Ваши земли захватил %s\nМесто: #%d из %d\n%s" % [world.factions[by]["name"], world.rank_of(human), world.ranking().size(), bonus], true)
	elif by == human:
		hud.toast("Уничтожено: %s" % world.factions[fid]["name"], Color(0.75, 1, 0.75))
		_sfx("build")


func _on_season_changed(s: int) -> void:
	var d: Dictionary = Rules.SEASONS[s]
	var tint := Color(d["tint"])
	tint.a = 0.10 if s == 3 else 0.05
	season_tint.color = tint
	hud.toast("%s: %s" % [d["name"], d["desc"]], Color(d["tint"]).lightened(0.4))


func _on_match_finished(winner: int) -> void:
	var lines: Array = []
	var ranking: Array = world.ranking()
	for i in mini(5, ranking.size()):
		var f: Dictionary = ranking[i]
		lines.append("%d. %s — %.1f%%" % [i + 1, f["name"], world.land_share(f["id"]) * 100.0])
	var won: bool = winner == human
	var title := "Победа!" if won else "Матч окончен"
	var goal := "%s занял %d%% карты." % [world.factions[winner]["name"], int(Rules.WIN_LAND_SHARE * 100.0)]
	_sfx("win" if won else "lose")
	var bonus := _count_result(won)
	hud.show_result(title, goal + "\n" + "\n".join(lines) + "\n\nВаше место: #%d\n%s" % [world.rank_of(human), bonus], true, "Продолжить завоевание" if won else "Играть дальше")


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
	var open_people := false
	var open_event := false
	var open_gov := -1
	var open_missions := false
	var open_autopilot := false
	for a in OS.get_cmdline_user_args():
		if a == "--open-missions":
			open_missions = true
		elif a == "--open-autopilot":
			open_autopilot = true
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
		elif a == "--open-people":
			open_people = true
		elif a == "--open-event":
			open_event = true
		elif a.begins_with("--open-gov="):
			open_gov = int(a.get_slice("=", 1))
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
	if open_people:
		hud.toggle_people()
	if open_gov >= 0:
		hud.toggle_gov(open_gov)
	if open_missions:
		hud.toggle_missions()
	if open_autopilot:
		hud.toggle_autopilot()
	if open_event:
		world.factions[human]["next_event"] = world.tick
		world._offer_event()
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
	world.apply({"type": "decree", "player": human, "kind": "festival"})
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
