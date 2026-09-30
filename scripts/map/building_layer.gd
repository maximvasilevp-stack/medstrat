extends Node2D
## Sprites for buildings, driven by World signals.

const PixelSprites := preload("res://scripts/map/pixel_sprites.gd")

var map
var world
var sprites: Dictionary = {}   # cell -> Sprite2D


func _init(m, w) -> void:
	map = m
	world = w


func _ready() -> void:
	world.building_placed.connect(_on_building_placed)
	world.building_removed.connect(_on_building_removed)


func _on_building_placed(_faction_id: int, kind: String, cell: int) -> void:
	var rows: Array = PixelSprites.CITY
	match kind:
		"port", "shipyard", "customs":
			rows = PixelSprites.PORT
		"defense", "fortress", "hq", "arsenal", "radar", "mine":
			rows = PixelSprites.TOWER
		"market", "farm", "granary", "bank", "casino":
			rows = PixelSprites.MARKET
		"barracks":
			rows = PixelSprites.BARRACKS
		"bunker":
			rows = PixelSprites.BUNKER
		"university", "lab":
			rows = PixelSprites.LAB
	var s := Sprite2D.new()
	s.texture = PixelSprites.texture(rows, kind)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = Vector2(map.cell(cell)) + Vector2(0.5, 0.5)
	s.z_index = 1
	add_child(s)
	sprites[cell] = s


func _on_building_removed(cell: int) -> void:
	if sprites.has(cell):
		sprites[cell].queue_free()
		sprites.erase(cell)
