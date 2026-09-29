extends Control
## Faction names and troop counts floating over their territory (screen-space, fixed size).

const Names := preload("res://scripts/sim/names.gd")

var world
var camera: Camera2D
var container: Control
var labels: Dictionary = {}


func setup(w, cam: Camera2D, cont: Control) -> void:
	world = w
	camera = cam
	container = cont


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if world == null:
		return
	var origin := container.global_position
	var zoom := camera.zoom.x
	var rect := Rect2(origin, container.size)
	for id in range(1, world.factions.size()):
		var f: Dictionary = world.factions[id]
		var l: Label = labels.get(id)
		var show: bool = f["alive"] and f["cells"] >= 10
		if not show:
			if l != null:
				l.visible = false
			continue
		if l == null:
			l = Label.new()
			l.mouse_filter = MOUSE_FILTER_IGNORE
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.add_theme_font_size_override("font_size", 11)
			l.add_theme_color_override("font_color", Color(0.12, 0.10, 0.08))
			l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.55))
			l.add_theme_constant_override("shadow_offset_x", 1)
			l.add_theme_constant_override("shadow_offset_y", 1)
			add_child(l)
			labels[id] = l
		var centroid: Vector2 = world.centroid(id)
		var screen: Vector2 = origin + (centroid - camera.position) * zoom
		l.text = "%s\n%s" % [f["name"], Names.short_number(f["troops"])]
		var sz := l.get_minimum_size()
		l.size = sz
		l.position = screen - sz / 2.0
		l.visible = rect.has_point(screen)
