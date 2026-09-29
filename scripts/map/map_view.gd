extends Sprite2D
## Draws the whole map with one shader: terrain + territory colours + borders.

var map
var world
var owner_img: Image
var owner_tex: ImageTexture
var palette_img: Image
var palette_tex: ImageTexture
var mat: ShaderMaterial


func _init(m, w) -> void:
	map = m
	world = w
	centered = false
	texture = map.terrain_texture
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	owner_img = Image.create_from_data(map.width, map.height, false, Image.FORMAT_R8, world.owner)
	owner_tex = ImageTexture.create_from_image(owner_img)
	palette_img = Image.create_empty(256, 1, false, Image.FORMAT_RGBA8)
	palette_img.fill(Color(0.5, 0.5, 0.5, 1.0))
	for id in range(1, world.factions.size()):
		palette_img.set_pixel(id, 0, world.factions[id]["color"])
	palette_tex = ImageTexture.create_from_image(palette_img)
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/map.gdshader")
	mat.set_shader_parameter("terrain_tex", map.terrain_texture)
	mat.set_shader_parameter("owner_tex", owner_tex)
	mat.set_shader_parameter("palette", palette_tex)
	mat.set_shader_parameter("map_size", Vector2i(map.width, map.height))
	mat.set_shader_parameter("human_id", world.human)
	material = mat
	world.territory_changed.connect(refresh_owner)


func refresh_owner() -> void:
	owner_img.set_data(map.width, map.height, false, Image.FORMAT_R8, world.owner)
	owner_tex.update(owner_img)


func set_hover_owner(id: int) -> void:
	mat.set_shader_parameter("hover_owner", id)
