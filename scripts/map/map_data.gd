extends RefCounted
## Loads the generated map (assets/map/*) and answers cell / province queries.
## Cells are 1x1 world units; cell (x, y) covers world rect [x, x+1) x [y, y+1).

var width: int = 0
var height: int = 0
var ids: PackedByteArray
var terrain: PackedByteArray
var provinces: Array = []       # index = id - 1, see _normalize()
var players: Dictionary = {}    # "player1" -> province id
var ids_texture: ImageTexture
var terrain_texture: ImageTexture

const TERRAIN_DEEP := 0
const TERRAIN_SHALLOW := 1
const TERRAIN_GRASS := 2
const TERRAIN_SAND := 3
const TERRAIN_SNOW := 4
const TERRAIN_MOUNTAIN := 5
const VOID_ID := 255                 # land outside the playable area


func _init(dir: String = "res://assets/map/") -> void:
	var f := FileAccess.open(dir + "provinces.json", FileAccess.READ)
	assert(f != null, "provinces.json missing - run python3 tools/build_map.py")
	var meta = JSON.parse_string(f.get_as_text())
	width = int(meta["width"])
	height = int(meta["height"])
	for k in meta["players"]:
		players[k] = int(meta["players"][k])
	for p in meta["provinces"]:
		provinces.append(_normalize(p))
	ids = FileAccess.get_file_as_bytes(dir + "province_ids.dat")
	terrain = FileAccess.get_file_as_bytes(dir + "terrain.dat")
	assert(ids.size() == width * height and terrain.size() == width * height, "map data size mismatch")
	ids_texture = ImageTexture.create_from_image(Image.create_from_data(width, height, false, Image.FORMAT_R8, ids))
	terrain_texture = ImageTexture.create_from_image(Image.create_from_data(width, height, false, Image.FORMAT_R8, terrain))


func _normalize(p: Dictionary) -> Dictionary:
	var d := {}
	d["id"] = int(p["id"])
	d["name"] = String(p["name"])
	d["name_en"] = String(p["name_en"])
	d["cells"] = int(p["cells"])
	d["coastal"] = bool(p["coastal"])
	d["capital"] = Vector2i(int(p["capital"]["x"]), int(p["capital"]["y"]))
	d["port_cell"] = Vector2i(int(p["port_cell"]["x"]), int(p["port_cell"]["y"])) if p.has("port_cell") else d["capital"]
	d["color"] = Color.html(String(p["color"]))
	var land: Array = []
	for v in p["land"]:
		land.append(int(v))
	var sea: Array = []
	for v in p["sea"]:
		sea.append(int(v))
	d["land"] = land
	d["sea"] = sea
	return d


func province_count() -> int:
	return provinces.size()


func province(id: int) -> Dictionary:
	return provinces[id - 1]


func name_of(id: int) -> String:
	return provinces[id - 1]["name"] if id > 0 else "Море"


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func province_at(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return 0
	var v := ids[cell.y * width + cell.x]
	return 0 if v == VOID_ID else v


func is_void(cell: Vector2i) -> bool:
	return in_bounds(cell) and ids[cell.y * width + cell.x] == VOID_ID


func terrain_at(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return TERRAIN_DEEP
	return terrain[cell.y * width + cell.x]


func is_land(cell: Vector2i) -> bool:
	return in_bounds(cell) and ids[cell.y * width + cell.x] != 0


func is_coast(cell: Vector2i) -> bool:
	if not is_land(cell):
		return false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = cell + d
		if in_bounds(n) and ids[n.y * width + n.x] == 0:
			return true
	return false


func id_by_name_en(name_en: String) -> int:
	for p in provinces:
		if p["name_en"] == name_en:
			return p["id"]
	return 0
