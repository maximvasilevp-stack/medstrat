extends RefCounted
## Tiny pixel-art sprites defined as strings; one char = one map cell.

const PALETTE := {
	"t": Color(0.86, 0.80, 0.68),  # wall
	"w": Color(0.28, 0.22, 0.18),  # window / gate
	"r": Color(0.72, 0.28, 0.22),  # roof
	"d": Color(0.30, 0.24, 0.18),  # ground / hull
	"s": Color(0.96, 0.96, 0.98),  # sail
	"m": Color(0.55, 0.36, 0.22),  # mast
	"i": Color(0.78, 0.80, 0.86),  # iron
	"x": Color(0.80, 0.20, 0.20),  # red
	"g": Color(0.92, 0.75, 0.25),  # gold
	"k": Color(0.06, 0.05, 0.05),  # outline
	"f": Color(1.0, 1.0, 1.0),     # white
	"y": Color(1.0, 0.92, 0.45),   # bright gold
	"b": Color(0.35, 0.55, 0.85),  # blue
}

const CITY := [
	"t.....t",
	"tt.r.tt",
	"twwrwwt",
	"ttttttt",
	"tgtwtgt",
	"ttttttt",
	"ddddddd",
]

const PORT := [
	"...s...",
	"..ss...",
	".sss...",
	"...m...",
	"ddddddd",
	".ddddd.",
	"..ddd..",
]

const TOWER := [
	"t.t.t.t",
	"ttttttt",
	".ttttt.",
	".twtwt.",
	".ttttt.",
	".twtwt.",
	"ddddddd",
]

const COIN := [
	".ggggg.",
	"gggyggg",
	"ggyyygg",
	"ggyyygg",
	"ggyyygg",
	"gggyggg",
	".ggggg.",
]

const PLUS := [
	"...f...",
	"...f...",
	"...f...",
	"fffffff",
	"...f...",
	"...f...",
	"...f...",
]

const BOAT := [
	"...s...",
	"..ss...",
	".sss...",
	"...m...",
	"ddddddd",
	".ddddd.",
	"..ddd..",
]

const ROCKET := [
	"...f...",
	"..fxf..",
	"..fff..",
	"..fff..",
	".ifffi.",
	".i.f.i.",
	"..y.y..",
]

const ARMY := [
	"iiiii",
	"ixixi",
	"iiiii",
	".iii.",
	"..i..",
]

const SWORDS := [
	"i.....i",
	".i...i.",
	"..i.i..",
	"...i...",
	"..i.i..",
	".g...g.",
	"g.....g",
]

const DIGITS := {
	"0": ["###", "#.#", "#.#", "#.#", "###"],
	"1": [".#.", "##.", ".#.", ".#.", "###"],
	"2": ["###", "..#", "###", "#..", "###"],
	"3": ["###", "..#", "###", "..#", "###"],
	"4": ["#.#", "#.#", "###", "..#", "..#"],
	"5": ["###", "#..", "###", "..#", "###"],
	"6": ["###", "#..", "###", "#.#", "###"],
	"7": ["###", "..#", "..#", "..#", "..#"],
	"8": ["###", "#.#", "###", "#.#", "###"],
	"9": ["###", "#.#", "###", "..#", "###"],
}

static var _cache: Dictionary = {}


static func texture(rows: Array, key: String) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	var h := rows.size()
	var w: int = rows[0].length()
	var img := Image.create_empty(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# 1-cell dark outline around every opaque pixel, then the pixels themselves
	for y in h:
		for x in w:
			if rows[y][x] != ".":
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						img.set_pixel(x + 1 + dx, y + 1 + dy, PALETTE["k"])
	for y in h:
		for x in w:
			var ch: String = rows[y][x]
			if ch != ".":
				img.set_pixel(x + 1, y + 1, PALETTE.get(ch, Color.MAGENTA))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func number(n: int) -> ImageTexture:
	var s := str(maxi(0, n))
	var key := "num:" + s
	if _cache.has(key):
		return _cache[key]
	var w := s.length() * 4 - 1
	var img := Image.create_empty(w + 2, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.06, 0.05, 0.05, 0.85))
	for i in s.length():
		var glyph: Array = DIGITS[s[i]]
		for y in 5:
			for x in 3:
				if glyph[y][x] == "#":
					img.set_pixel(1 + i * 4 + x, 1 + y, PALETTE["f"])
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
