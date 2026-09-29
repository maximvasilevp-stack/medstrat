extends Control
## Match scene: wooden frame, the map in a SubViewport, HUD, floating labels and the exit dialog.
## Command line (after "--"): --screenshot=PATH  --run-ticks=N  --fast  --demo  --open-exit  --seed=N

const MapData := preload("res://scripts/map/map_data.gd")
const World := preload("res://scripts/sim/world.gd")
const MapView := preload("res://scripts/map/map_view.gd")
const BuildingLayer := preload("res://scripts/map/building_layer.gd")
const WorldScene := preload("res://scripts/map/world_scene.gd")
const GameCamera := preload("res://scripts/camera/game_camera.gd")
const MapLabels := preload("res://scripts/ui/map_labels.gd")
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
var exit_dialog
var human: int = 1
var mode := ""
var speed := 1.0
var _acc := 0.0
var screenshot_path := ""
var game_seed: int = int(Time.get_unix_time_from_system()) % 1000000


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_read_seed_arg()
	map = MapData.new()
	world = World.new(map, game_seed)
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
	view = MapView.new(map, world)
	world_node.add_child(view)
	world_node.add_child(BuildingLayer.new(map, world))
	camera = GameCamera.new()
	camera.map_size = Vector2(map.width, map.height)
	world_node.add_child(camera)
	camera.make_current()

	labels = MapLabels.new()
	add_child(labels)
	labels.setup(world, camera, container)
	hud = HudScene.instantiate()
	add_child(hud)
	hud.setup(world)
	exit_dialog = ExitDialogScene.instantiate()
	add_child(exit_dialog)

	world_node.cell_clicked.connect(_on_cell_clicked)
	world_node.cell_hovered.connect(_on_cell_hovered)
	camera.right_clicked.connect(func(_p): _set_mode(""))
	hud.mode_selected.connect(_set_mode)
	hud.attack_size_changed.connect(func(v): world.factions[human]["attack_size"] = v)
	hud.exit_pressed.connect(func(): exit_dialog.open())
	hud.menu_requested.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	world.action_rejected.connect(_on_action_rejected)
	world.attack_launched.connect(_on_attack_launched)
	world.faction_eliminated.connect(_on_faction_eliminated)
	world.match_finished.connect(_on_match_finished)
	world.building_placed.connect(_on_building_placed)
	hud.set_mode("")

	await get_tree().process_frame
	camera.focus_on(map.cell(world.factions[human]["spawn"]))
	_handle_args()


# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	_acc += delta * speed
	var n := 0
	while _acc >= Rules.TICK_DT and n < 50:
		_acc -= Rules.TICK_DT
		world.step()
		n += 1
	hud.refresh(delta)


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if mode != "":
			_set_mode("")
		else:
			exit_dialog.open()
		get_viewport().set_input_as_handled()


func _on_cell_hovered(i: int) -> void:
	view.set_hover_owner(world.owner[i] if i >= 0 else 0)


func _on_cell_clicked(i: int) -> void:
	if i < 0:
		return
	if mode != "":
		var r: Dictionary = world.apply({"type": "build", "player": human, "kind": mode, "cell": i})
		if r["ok"]:
			_set_mode("")
	else:
		world.apply({"type": "attack", "player": human, "cell": i, "ratio": world.factions[human]["attack_size"]})


func _set_mode(kind: String) -> void:
	mode = kind
	hud.set_mode(kind)


# ------------------------------------------------------------------ world events

func _on_action_rejected(a: Dictionary, reason: String) -> void:
	if a["player"] == human:
		hud.toast(reason, Color(1, 0.6, 0.5))


func _on_attack_launched(fid: int, target: int, _cell: int, troops: float) -> void:
	if fid == human:
		var who: String = "ничью землю" if target == 0 else world.factions[target]["name"]
		hud.toast("Атака: %s войск на %s" % [Names.short_number(troops), who], Color(1, 0.95, 0.7))
	elif target == human:
		hud.toast("%s атакует вас: %s войск" % [world.factions[fid]["name"], Names.short_number(troops)], Color(1, 0.55, 0.45))


func _on_building_placed(fid: int, kind: String, _cell: int) -> void:
	if fid == human:
		var names := {"city": "Город", "port": "Порт", "defense": "Защита"}
		hud.toast("%s: построено" % names[kind], Color(0.75, 1, 0.75))


func _on_faction_eliminated(fid: int, by: int) -> void:
	if fid == human:
		hud.show_result("Поражение", "Ваши земли захватил игрок %s\nМесто: #%d из %d" % [world.factions[by]["name"], world.rank_of(human), world.ranking().size()], true)
	elif by == human:
		hud.toast("Вы уничтожили %s" % world.factions[fid]["name"], Color(0.75, 1, 0.75))
	elif world.factions[fid]["kind"] != world.Kind.CITY:
		hud.toast("%s выбывает" % world.factions[fid]["name"], Color(0.9, 0.9, 0.9))


func _on_match_finished(winner: int) -> void:
	var lines: Array = []
	var ranking: Array = world.ranking()
	for i in mini(5, ranking.size()):
		var f: Dictionary = ranking[i]
		lines.append("%d. %s — %.1f%%" % [i + 1, f["name"], world.land_share(f["id"]) * 100.0])
	var title := "Победа!" if winner == human else "Матч окончен"
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
		world.step()
	if open_exit:
		exit_dialog.open()
	if screenshot_path != "":
		_take_screenshot()


func _run_demo() -> void:
	var f: Dictionary = world.factions[human]
	f["gold"] = 20000.0
	f["troops"] = 3000.0
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
