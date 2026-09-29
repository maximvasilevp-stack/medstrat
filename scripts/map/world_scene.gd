extends Node2D
## Root of the map world inside the SubViewport: converts mouse input into cell events.

signal cell_clicked(cell: int)
signal cell_hovered(cell: int)      # -1 when the mouse is off the map

var map
var _last_hover := -2


func mouse_cell() -> int:
	var c := Vector2i(get_global_mouse_position().floor())
	return map.index(c) if map.in_bounds(c) else -1


func _process(_delta: float) -> void:
	var i := mouse_cell()
	if i != _last_hover:
		_last_hover = i
		cell_hovered.emit(i)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cell_clicked.emit(mouse_cell())
		get_viewport().set_input_as_handled()
