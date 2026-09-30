extends Node2D
## Ships sailing to a landing, missiles in flight and explosion bursts. Purely visual.

const PixelSprites := preload("res://scripts/map/pixel_sprites.gd")
const Rules := preload("res://scripts/sim/rules.gd")

var map
var world


class Burst extends Node2D:
	var radius: float = 10.0
	var t: float = 0.0
	var life: float = 1.3

	func _process(delta: float) -> void:
		t += delta
		if t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / life, 0.0, 1.0)
		var r := radius * (0.3 + 0.9 * k)
		draw_circle(Vector2.ZERO, r * (1.0 - k) * 0.8, Color(1.0, 0.85, 0.4, 0.55 * (1.0 - k)))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.6, 0.2, 1.0 - k), 1.5)
		draw_arc(Vector2.ZERO, r * 0.6, 0.0, TAU, 32, Color(0.2, 0.15, 0.1, 0.8 * (1.0 - k)), 1.0)


func _init(m, w) -> void:
	map = m
	world = w


func _ready() -> void:
	world.ship_launched.connect(_on_ship)
	world.nuke_launched.connect(_on_missile)
	world.nuke_detonated.connect(_on_detonated)


func _fly(rows: Array, key: String, from_cell: int, to_cell: int, ticks: int, spin: bool) -> void:
	var s := Sprite2D.new()
	s.texture = PixelSprites.texture(rows, key)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var a := Vector2(map.cell(from_cell)) + Vector2(0.5, 0.5)
	var b := Vector2(map.cell(to_cell)) + Vector2(0.5, 0.5)
	s.position = a
	s.z_index = 5
	if spin:
		s.rotation = (b - a).angle() + PI / 2.0
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "position", b, ticks * Rules.TICK_DT)
	tw.tween_callback(s.queue_free)


func _on_ship(_fid: int, from_cell: int, to_cell: int, ticks: int) -> void:
	_fly(PixelSprites.BOAT, "boat", from_cell, to_cell, ticks, false)


func _on_missile(_fid: int, from_cell: int, to_cell: int, ticks: int, _mega: bool) -> void:
	_fly(PixelSprites.ROCKET, "rocket", from_cell, to_cell, ticks, true)


func _on_detonated(cell: int, radius: int) -> void:
	var b := Burst.new()
	b.radius = float(radius)
	b.position = Vector2(map.cell(cell)) + Vector2(0.5, 0.5)
	b.z_index = 6
	add_child(b)
