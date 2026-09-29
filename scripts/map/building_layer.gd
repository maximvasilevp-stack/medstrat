extends Node2D
## Sprites for cities, ports, garrisons and battle markers, driven by Sim signals.

const PixelSprites := preload("res://scripts/map/pixel_sprites.gd")
const Rules := preload("res://scripts/sim/rules.gd")

var map
var sim
var sprites: Dictionary = {}     # "city:12" -> Sprite2D
var garrison_icons: Dictionary = {}   # province id -> Sprite2D (shield)
var garrison_numbers: Dictionary = {} # province id -> Sprite2D (digits)


func _init(m, s) -> void:
	map = m
	sim = s


func _ready() -> void:
	sim.building_placed.connect(_on_building_placed)
	sim.garrison_changed.connect(_on_garrison_changed)
	sim.battle.connect(_on_battle)
	for p in map.provinces:
		_on_garrison_changed(p["id"])


func _make_sprite(tex: Texture2D, cell: Vector2i, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = true
	s.position = Vector2(cell) + Vector2(0.5, 0.5)
	s.z_index = z
	add_child(s)
	return s


func _on_building_placed(province_id: int, kind: String, cell: Vector2i) -> void:
	var key := kind + ":" + str(province_id)
	if sprites.has(key):
		sprites[key].queue_free()
	var tex := PixelSprites.texture(PixelSprites.CITY if kind == "city" else PixelSprites.PORT, kind)
	sprites[key] = _make_sprite(tex, cell, 1)


func _on_garrison_changed(province_id: int) -> void:
	var g: int = sim.provinces[province_id]["garrison"]
	var cap: Vector2i = map.province(province_id)["capital"]
	if g <= 0:
		if garrison_icons.has(province_id):
			garrison_icons[province_id].queue_free()
			garrison_numbers[province_id].queue_free()
			garrison_icons.erase(province_id)
			garrison_numbers.erase(province_id)
		return
	if not garrison_icons.has(province_id):
		garrison_icons[province_id] = _make_sprite(PixelSprites.texture(PixelSprites.ARMY, "army"), cap + Vector2i(0, 5), 2)
		garrison_numbers[province_id] = _make_sprite(PixelSprites.number(g), cap + Vector2i(0, 11), 2)
	garrison_numbers[province_id].texture = PixelSprites.number(g)


func _on_battle(province_id: int, cell: Vector2i, _attacker: int, _defender: int, _won: bool, _a: int, _d: int) -> void:
	var s := _make_sprite(PixelSprites.texture(PixelSprites.SWORDS, "swords"), cell + Vector2i(0, -6), 3)
	var tw := create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.6).set_delay(float(Rules.BATTLE_MARK_TICKS) / Rules.TICKS_PER_SEC)
	tw.tween_callback(s.queue_free)
