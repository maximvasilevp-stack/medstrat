extends Camera2D
## Strategy camera inside the map SubViewport: integer zoom steps, mouse wheel, trackpad pinch and
## two-finger pan, drag with middle/right button, WASD/arrows, screen edges, +/- keys. Clamped to the map.

signal right_clicked(screen_pos: Vector2)
signal zoom_changed(level: int)

const ZOOMS := [1, 2, 3, 4, 6, 8]   # screen pixels per map cell
const PAN_SPEED := 700.0            # pixels per second for keyboard / edge panning
const EDGE := 6                     # edge-pan zone in pixels
const CLICK_SLOP := 4.0
const WHEEL_COOLDOWN := 0.08        # seconds between wheel zoom steps (trackpads send bursts)

var map_size := Vector2(640, 768)
var zoom_index := 1
var dragging := false
var drag_moved := 0.0
var edge_pan_enabled := true
var _magnify := 1.0
var _wheel_timer := 0.0


func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	_apply_zoom()
	center_map()
	get_viewport().size_changed.connect(_clamp_and_snap)
	center_map.call_deferred()


func center_map() -> void:
	var view := get_viewport_rect().size / _z()
	position = (map_size - view) / 2.0
	_clamp_and_snap()


func _z() -> float:
	return float(ZOOMS[zoom_index])


func _apply_zoom() -> void:
	zoom = Vector2(_z(), _z())
	zoom_changed.emit(zoom_index)


func _process(delta: float) -> void:
	_wheel_timer = maxf(0.0, _wheel_timer - delta)
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1
	if edge_pan_enabled and not dragging:
		var m := get_viewport().get_mouse_position()
		var vs := get_viewport_rect().size
		if m.x >= 0 and m.y >= 0 and m.x <= vs.x and m.y <= vs.y:
			if m.x < EDGE:
				dir.x -= 1
			elif m.x > vs.x - EDGE:
				dir.x += 1
			if m.y < EDGE:
				dir.y -= 1
			elif m.y > vs.y - EDGE:
				dir.y += 1
	if dir != Vector2.ZERO:
		position += dir.normalized() * PAN_SPEED * delta / _z()
		_clamp_and_snap()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if _wheel_timer <= 0.0:
				_wheel_timer = WHEEL_COOLDOWN
				_zoom_at(1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1, get_viewport().get_mouse_position())
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				dragging = true
				drag_moved = 0.0
			else:
				dragging = false
				if mb.button_index == MOUSE_BUTTON_RIGHT and drag_moved < CLICK_SLOP:
					right_clicked.emit(get_viewport().get_mouse_position())
	elif event is InputEventMouseMotion and dragging:
		var mm := event as InputEventMouseMotion
		drag_moved += mm.relative.length()
		position -= mm.relative / _z()
		_clamp_and_snap()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		_magnify *= mg.factor
		if _magnify >= 1.25:
			_magnify = 1.0
			_zoom_at(1, get_viewport().get_mouse_position())
		elif _magnify <= 0.8:
			_magnify = 1.0
			_zoom_at(-1, get_viewport().get_mouse_position())
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		if pg.ctrl_pressed or pg.meta_pressed:
			_magnify *= 1.0 - pg.delta.y * 0.02
			if _magnify >= 1.25:
				_magnify = 1.0
				_zoom_at(1, get_viewport().get_mouse_position())
			elif _magnify <= 0.8:
				_magnify = 1.0
				_zoom_at(-1, get_viewport().get_mouse_position())
		else:
			position += pg.delta * 2.0 / _z()
			_clamp_and_snap()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_EQUAL or k.physical_keycode == KEY_KP_ADD or k.physical_keycode == KEY_PLUS:
			zoom_step(1)
			get_viewport().set_input_as_handled()
		elif k.physical_keycode == KEY_MINUS or k.physical_keycode == KEY_KP_SUBTRACT:
			zoom_step(-1)
			get_viewport().set_input_as_handled()


## Zoom around the centre of the view (buttons and keys).
func zoom_step(step: int) -> void:
	_zoom_at(step, get_viewport_rect().size / 2.0)


func _zoom_at(step: int, screen_pos: Vector2) -> void:
	var old_z := _z()
	zoom_index = clampi(zoom_index + step, 0, ZOOMS.size() - 1)
	var new_z := _z()
	if is_equal_approx(old_z, new_z):
		return
	var world := position + screen_pos / old_z
	position = world - screen_pos / new_z
	_apply_zoom()
	_clamp_and_snap()


func _clamp_and_snap() -> void:
	var z := _z()
	var view := get_viewport_rect().size / z
	var p := position
	for axis in 2:
		if view[axis] >= map_size[axis]:
			p[axis] = (map_size[axis] - view[axis]) / 2.0
		else:
			p[axis] = clampf(p[axis], 0.0, map_size[axis] - view[axis])
	position = (p * z).round() / z


func focus_on(cell: Vector2i) -> void:
	var view := get_viewport_rect().size / _z()
	position = Vector2(cell) - view / 2.0
	_clamp_and_snap()
