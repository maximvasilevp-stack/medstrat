extends Sprite2D
## Draws the whole map with one shader: terrain + owner tint + borders + highlights.

var map
var palette_img: Image
var palette_tex: ImageTexture
var flags_img: Image
var flags_tex: ImageTexture
var mat: ShaderMaterial


func _init(m) -> void:
	map = m
	centered = false
	texture = map.ids_texture
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	palette_img = Image.create_empty(256, 1, false, Image.FORMAT_RGBA8)
	palette_img.fill(Color(0.5, 0.5, 0.5, 1.0))
	palette_tex = ImageTexture.create_from_image(palette_img)
	flags_img = Image.create_empty(256, 1, false, Image.FORMAT_RGBA8)
	flags_img.fill(Color(0, 0, 0, 0))
	flags_tex = ImageTexture.create_from_image(flags_img)
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/map.gdshader")
	mat.set_shader_parameter("ids", map.ids_texture)
	mat.set_shader_parameter("terrain_tex", map.terrain_texture)
	mat.set_shader_parameter("palette", palette_tex)
	mat.set_shader_parameter("flags", flags_tex)
	mat.set_shader_parameter("map_size", Vector2i(map.width, map.height))
	material = mat


func set_owner_color(province_id: int, color: Color) -> void:
	palette_img.set_pixel(province_id, 0, color)
	palette_tex.update(palette_img)


func set_hovered(province_id: int) -> void:
	mat.set_shader_parameter("hovered_id", province_id)


func set_selected(province_id: int) -> void:
	mat.set_shader_parameter("selected_id", province_id)


func set_highlight(province_ids: Array) -> void:
	flags_img.fill(Color(0, 0, 0, 0))
	for id in province_ids:
		flags_img.set_pixel(id, 0, Color(1, 0, 0, 1))
	flags_tex.update(flags_img)
