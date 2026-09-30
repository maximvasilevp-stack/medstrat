extends Node2D
## Root of the map world inside the SubViewport: converts mouse input into cell events.

signal cell_clicked(cell: int)
signal cell_hovered(cell: int)      # -1 when the mouse is off the map

var map
var camera: Camera2D
var _last_hover := -2
var _left_down := false
var _left_dragged := false
var _press_pos := Vector2.ZERO
const DRAG_SLOP := 10.0


func mouse_cell() -> int:
	var c := Vector2i(get_global_mouse_position().floor())
	return map.index(c) if map.in_bounds(c) else -1


func _process(_delta: float) -> void:
	var i := mouse_cell()
	if i != _last_hover:
		_last_hover = i
		cell_hovered.emit(i)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_left_down = true
			_left_dragged = false
			_press_pos = get_viewport().get_mouse_position()
		else:
			if _left_down and not _left_dragged:
				cell_clicked.emit(mouse_cell())
			_left_down = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _left_down:
		var pos: Vector2 = get_viewport().get_mouse_position()
		if not _left_dragged and pos.distance_to(_press_pos) > DRAG_SLOP:
			_left_dragged = true
		if _left_dragged and camera != null:
			camera.pan_by(-event.relative)
		get_viewport().set_input_as_handled()
