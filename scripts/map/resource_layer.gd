extends Node2D
## Icons for the strategic deposits on the map. Static: built once from map.resources.

const PixelSprites := preload("res://scripts/map/pixel_sprites.gd")
const Resources := preload("res://scripts/sim/resources.gd")

var map


func _init(m) -> void:
	map = m


func _ready() -> void:
	z_index = 1
	var textures := {}
	for kind in Resources.KIND_ORDER:
		textures[kind] = PixelSprites.texture(Resources.ICONS[kind], "res_%d" % kind)
	for i in map.land_cells:
		var kind: int = map.resources[i]
		if kind == 0:
			continue
		var s := Sprite2D.new()
		s.texture = textures[kind]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(map.cell(i)) + Vector2(0.5, 0.5)
		add_child(s)
