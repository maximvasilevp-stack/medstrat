extends Control
## Whole-map overview with the camera window; click to move the camera.

signal focus_requested(cell: int)

var map
var world
var camera: Camera2D
var container: Control
var frame: Control


func setup(m, w, cam: Camera2D, cont: Control, mat: ShaderMaterial) -> void:
	map = m
	world = w
	camera = cam
	container = cont
	var aspect := float(map.height) / float(map.width)
	custom_minimum_size = Vector2(150, 150 * aspect)
	size = custom_minimum_size
	clip_contents = true
	var tex := TextureRect.new()
	tex.texture = map.terrain_texture
	tex.material = mat
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	tex.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(tex)
	frame = Control.new()
	frame.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	frame.draw.connect(_draw_frame)
	add_child(frame)


func _process(_delta: float) -> void:
	if frame:
		frame.queue_redraw()


func _draw_frame() -> void:
	var scale := size.x / float(map.width)
	var view := container.size / camera.zoom.x
	var r := Rect2(camera.position * scale, view * scale)
	frame.draw_rect(Rect2(Vector2.ZERO, size), Color(0.62, 0.48, 0.30), false, 2.0)
	frame.draw_rect(r, Color(1, 1, 1, 0.9), false, 1.0)
	frame.draw_rect(r, Color(1, 1, 1, 0.08), true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position / (size.x / float(map.width))
		var c := Vector2i(p.floor())
		if map.in_bounds(c):
			focus_requested.emit(map.index(c))
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var p: Vector2 = event.position / (size.x / float(map.width))
		var c := Vector2i(p.floor())
		if map.in_bounds(c):
			focus_requested.emit(map.index(c))
		accept_event()
