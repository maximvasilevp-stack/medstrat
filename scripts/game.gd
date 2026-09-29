extends Node2D
## Glue between the simulation, the map view, the camera and the HUD.
## Command line (after "--"): --screenshot=PATH  --run-ticks=N  --fast  --demo

const MapData := preload("res://scripts/map/map_data.gd")
const MapView := preload("res://scripts/map/map_view.gd")
const BuildingLayer := preload("res://scripts/map/building_layer.gd")
const GameCamera := preload("res://scripts/camera/game_camera.gd")
const Sim := preload("res://scripts/sim/sim.gd")
const Rules := preload("res://scripts/sim/rules.gd")
const HudScene := preload("res://scenes/ui/hud.tscn")
const ExitDialogScene := preload("res://scenes/ui/exit_dialog.tscn")

enum Mode { NONE, BUILD_CITY, BUILD_PORT, HIRE, ATTACK }

var map
var sim
var view
var buildings
var camera
var hud
var exit_dialog
var human: int
var mode: int = Mode.NONE
var attack_from: int = 0
var selected: int = 0
var hovered: int = 0
var speed: float = 1.0
var _acc: float = 0.0
var game_over := false
var screenshot_path := ""


func _ready() -> void:
	map = MapData.new()
	human = map.players["player1"]
	sim = Sim.new(map, human, int(Time.get_unix_time_from_system()) % 100000)
	view = MapView.new(map)
	add_child(view)
	buildings = BuildingLayer.new(map, sim)
	add_child(buildings)
	camera = GameCamera.new()
	camera.map_size = Vector2(map.width, map.height)
	add_child(camera)
	camera.make_current()
	camera.right_clicked.connect(func(_p): _cancel())
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HudScene.instantiate()
	layer.add_child(hud)
	exit_dialog = ExitDialogScene.instantiate()
	layer.add_child(exit_dialog)

	for p in map.provinces:
		view.set_owner_color(p["id"], p["color"])
	sim.province_captured.connect(_on_province_captured)
	sim.action_applied.connect(_on_action_applied)
	sim.action_rejected.connect(_on_action_rejected)
	sim.battle.connect(_on_battle)
	sim.faction_eliminated.connect(_on_faction_eliminated)
	hud.mode_selected.connect(_set_mode)
	hud.exit_pressed.connect(func(): exit_dialog.open())
	hud.attack_from_selected.connect(_attack_from_panel)
	hud.menu_requested.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	camera.focus_on(map.province(human)["capital"])
	_refresh_hud()
	_handle_args()


# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	if game_over:
		return
	_acc += delta * speed
	var n := 0
	while _acc >= 1.0 / Rules.TICKS_PER_SEC and n < 50:
		_acc -= 1.0 / Rules.TICKS_PER_SEC
		sim.step()
		n += 1
	_update_hover()
	_refresh_hud()


func _refresh_hud() -> void:
	hud.set_resources(sim.factions[human]["gold"], sim.income_of(human), sim.total_army(human), sim.month + 1)


func _update_hover() -> void:
	var cell := Vector2i(get_global_mouse_position().floor())
	var pid: int = map.province_at(cell)
	if pid != hovered:
		hovered = pid
		view.set_hovered(pid)
	var shown := selected if selected != 0 else hovered
	if shown != 0:
		_show_province(shown)
	else:
		hud.hide_province()


func _show_province(pid: int) -> void:
	var p: Dictionary = map.province(pid)
	var s: Dictionary = sim.provinces[pid]
	var owner_name: String = sim.factions[s["owner"]]["name"]
	var is_mine: bool = s["owner"] == human
	var lines := "Владелец: %s\nДоход: %d/мес\nГарнизон: %d (защита %d)\n%s%s" % [
		"вы (" + owner_name + ")" if is_mine else owner_name,
		sim.province_income(pid),
		s["garrison"], sim.defense_of(pid),
		"Город " if s["city"] else "Без города ",
		"· Порт" if s["port"] else "· Без порта",
	]
	if mode == Mode.ATTACK and attack_from != 0 and pid != attack_from:
		if sim.can_reach(attack_from, pid) and not is_mine:
			lines += "\nАтака %d против %d" % [Rules.attack_force(sim.provinces[attack_from]["garrison"]), sim.defense_of(pid)]
	hud.show_province(p["name"], lines, is_mine and s["garrison"] > 0 and not game_over, pid)


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return
	if event.is_action_pressed("ui_cancel"):
		if mode != Mode.NONE or selected != 0:
			_cancel()
		else:
			exit_dialog.open()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := Vector2i(get_global_mouse_position().floor())
		_on_map_click(cell, map.province_at(cell))
		get_viewport().set_input_as_handled()


func _on_map_click(cell: Vector2i, pid: int) -> void:
	match mode:
		Mode.NONE:
			selected = pid
			view.set_selected(pid)
		Mode.BUILD_CITY:
			sim.apply({"type": "build_city", "player": human, "province": pid, "cell": cell})
		Mode.BUILD_PORT:
			sim.apply({"type": "build_port", "player": human, "province": pid, "cell": cell})
		Mode.HIRE:
			if pid == 0:
				hud.toast("Это вода")
			else:
				sim.apply({"type": "hire", "player": human, "province": pid})
		Mode.ATTACK:
			if attack_from == 0:
				if pid != 0 and sim.provinces[pid]["owner"] == human and sim.provinces[pid]["garrison"] > 0:
					_pick_attack_source(pid)
				else:
					hud.toast("Выберите свою провинцию с войсками")
			elif pid == attack_from:
				attack_from = 0
				view.set_highlight([])
				view.set_selected(0)
				hud.set_status("Выберите свою провинцию с войсками")
			else:
				sim.apply({"type": "attack", "player": human, "from": attack_from, "to": pid})


func _pick_attack_source(pid: int) -> void:
	attack_from = pid
	selected = 0
	view.set_selected(pid)
	view.set_highlight(sim.attackable_from(pid, human))
	hud.set_status("Выберите цель: подсвечены доступные провинции (нужен порт для атаки по морю)")


func _attack_from_panel(pid: int) -> void:
	_set_mode(Mode.ATTACK)
	hud.set_mode(Mode.ATTACK)
	_pick_attack_source(pid)


func _set_mode(m: int) -> void:
	mode = m
	attack_from = 0
	selected = 0
	view.set_selected(0)
	view.set_highlight([])
	hud.set_mode(m)


func _cancel() -> void:
	_set_mode(Mode.NONE)


# ------------------------------------------------------------------ sim events

func _on_action_applied(a: Dictionary) -> void:
	if a["player"] != human:
		return
	match a["type"]:
		"build_city":
			hud.toast("Город построен: " + map.name_of(a["province"]))
			_set_mode(Mode.NONE)
		"build_port":
			hud.toast("Порт построен: " + map.name_of(a["province"]))
			_set_mode(Mode.NONE)
		"hire":
			hud.toast("+%d войск в %s" % [Rules.HIRE_STRENGTH, map.name_of(a["province"])])
		"attack":
			attack_from = 0
			view.set_highlight([])
			view.set_selected(0)
			hud.set_status("Выберите свою провинцию с войсками")


func _on_action_rejected(a: Dictionary, reason: String) -> void:
	if a["player"] == human:
		hud.toast(reason, Color(1, 0.6, 0.5))


func _on_battle(pid: int, _cell: Vector2i, attacker: int, defender: int, won: bool, a: int, d: int) -> void:
	if attacker == human:
		if won:
			hud.toast("Захвачена провинция: %s (%d против %d)" % [map.name_of(pid), a, d], Color(0.7, 1, 0.7))
		else:
			hud.toast("Атака на %s отбита: %d против %d" % [map.name_of(pid), a, d], Color(1, 0.6, 0.5))
	elif defender == human:
		var who: String = sim.factions[attacker]["name"]
		if won:
			hud.toast("%s захватывает %s!" % [who, map.name_of(pid)], Color(1, 0.5, 0.4))
		else:
			hud.toast("Атака %s на %s отбита (%d против %d)" % [who, map.name_of(pid), a, d], Color(1, 0.9, 0.6))


func _on_province_captured(pid: int, _old_owner: int, new_owner: int) -> void:
	view.set_owner_color(pid, sim.factions[new_owner]["color"])
	_check_game_over()


func _on_faction_eliminated(fid: int) -> void:
	if fid != human:
		hud.toast("Фракция уничтожена: %s" % sim.factions[fid]["name"], Color(0.9, 0.9, 0.9))


func _check_game_over() -> void:
	if game_over:
		return
	var mine: int = sim.province_count(human)
	if mine == 0:
		game_over = true
		hud.show_game_over("Поражение\nВаши земли захвачены")
	elif mine >= int(ceil(Rules.WIN_SHARE * map.province_count())):
		game_over = true
		hud.show_game_over("Победа!\nВы контролируете %d%% Европы" % int(100.0 * mine / map.province_count()))


# ------------------------------------------------------------------ command line helpers

func _handle_args() -> void:
	var run_ticks := 0
	var demo := false
	var open_exit := false
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
	if demo:
		_run_demo()
	for i in run_ticks:
		sim.step()
	_refresh_hud()
	if open_exit:
		exit_dialog.open()
	if screenshot_path != "":
		_take_screenshot()


func _run_demo() -> void:
	var p: Dictionary = map.province(human)
	sim.factions[human]["gold"] = 2000
	sim.apply({"type": "build_city", "player": human, "province": human, "cell": p["capital"]})
	sim.apply({"type": "build_port", "player": human, "province": human, "cell": p["port_cell"]})
	for i in 3:
		sim.apply({"type": "hire", "player": human, "province": human})
	var target: int = map.players.get("player2", 0)
	if target != 0:
		sim.apply({"type": "attack", "player": human, "from": human, "to": target})
	camera.zoom_index = 2
	camera._apply_zoom()
	camera.focus_on(p["capital"] + Vector2i(0, 60))
	selected = human
	view.set_selected(human)


func _take_screenshot() -> void:
	for i in 6:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(screenshot_path)
	print("screenshot saved to ", screenshot_path, " (", img.get_width(), "x", img.get_height(), ")")
	get_tree().quit()
