extends RefCounted
## Strategic resources scattered over the map. Owning a resource cell gives a small permanent bonus;
## the bonus stacks up to STACK_CAP cells of the same kind. Placement is a pure hash of the cell
## index, so every match shares the same deposits and nothing depends on the seed.

const KINDS := {
	1: {"key": "wheat", "name": "Пшеница", "desc": "+1.5% роста армии, +0.3 одобрение", "color": "#F4D77A", "mods": {"growth": 1.015, "approval": 0.3}},
	2: {"key": "timber", "name": "Лес", "desc": "Постройки на 1.5% дешевле", "color": "#6FA85A", "mods": {"build_cost": 0.985}},
	3: {"key": "iron", "name": "Железо", "desc": "+1.5% к защите, +60 к лимиту армии", "color": "#9AA3B0", "mods": {"defense": 1.015, "cap_flat": 60.0}},
	4: {"key": "gold", "name": "Золото", "desc": "+3 золота в секунду", "color": "#FFC53D", "mods": {"gold_flat": 3.0}},
	5: {"key": "oil", "name": "Нефть", "desc": "Фронт на 1% и корабли на 2% быстрее, +2 золота в секунду", "color": "#3B3B3B", "mods": {"attack_rate": 1.01, "ship_speed": 1.02, "gold_flat": 2.0}},
	6: {"key": "fish", "name": "Рыба", "desc": "+1.5 золота в секунду, +0.3 одобрение", "color": "#7FB9E6", "mods": {"gold_flat": 1.5, "approval": 0.3}},
	7: {"key": "horses", "name": "Лошади", "desc": "Фронт на 1.5% быстрее", "color": "#B07A4A", "mods": {"attack_rate": 1.015}},
	8: {"key": "spices", "name": "Пряности", "desc": "+1% золота, +0.3 одобрение", "color": "#F98BA9", "mods": {"gold": 1.01, "approval": 0.3}},
	9: {"key": "marble", "name": "Мрамор", "desc": "Постройки на 1% дешевле, +0.4 на выборах", "color": "#F2EEE8", "mods": {"build_cost": 0.99, "election": 0.4}},
}
const KIND_ORDER := [1, 2, 3, 4, 5, 6, 7, 8, 9]
const STACK_CAP := 25                 # bonuses stop stacking after this many cells of one kind
const DENSITY := 650                  # roughly one deposit per this many land cells

# 5x5 icons, see PixelSprites.PALETTE for letters
const ICONS := {
	1: ["..y..", ".yyy.", "y.y.y", "..y..", "..m.."],
	2: ["..g..", ".ggg.", "ggggg", "..m..", "..m.."],
	3: [".ii..", "iiii.", ".iiii", "..ii.", "....."],
	4: [".yyy.", "ygggy", "ygygy", "ygggy", ".yyy."],
	5: ["..k..", ".kkk.", "kkkkk", "kkkkk", ".kkk."],
	6: ["b...b", ".bbbb", "bbbbb", ".bbbb", "b...b"],
	7: ["..mm.", ".mmmm", "mmmm.", "m..m.", "m..m."],
	8: [".x.x.", "xxxxx", ".xxx.", "xxxxx", ".x.x."],
	9: ["fffff", "f.f.f", "fffff", "f.f.f", "fffff"],
}


static func _hash(i: int) -> int:
	var h := (i * 2654435761) & 0x7FFFFFFF
	h ^= h >> 13
	h = (h * 1274126177) & 0x7FFFFFFF
	return h ^ (h >> 16)


## Which kinds can appear on a terrain class and how likely each is.
static func _kinds_for(terrain: int, coast: bool) -> Array:
	var out: Array = []
	match terrain:
		2:  # grass
			out = [1, 1, 1, 7, 2]
		3:  # sand
			out = [5, 5, 8, 8, 4]
		4:  # snow
			out = [3, 2]
		5:  # mountain
			out = [3, 3, 4, 9, 9]
		9:  # forest
			out = [2, 2, 2, 7]
		10:  # hills
			out = [3, 3, 4, 9, 1]
		11:  # steppe
			out = [7, 7, 1, 5]
		_:
			out = [1, 2]
	if coast:
		out = out + [6, 6, 6]
	return out


## Deposits for the whole map: 0 = none, otherwise a kind id.
static func place(map) -> PackedByteArray:
	var res := PackedByteArray()
	res.resize(map.size())
	var taken := {}
	for i in map.land_cells:
		var h := _hash(i)
		if h % DENSITY != 0:
			continue
		var crowded := false
		for n in map.neighbors(i):
			if taken.has(n):
				crowded = true
				break
		if crowded:
			continue
		var options := _kinds_for(map.terrain[i], map.coast[i] == 1)
		var kind: int = options[(h / DENSITY) % options.size()]
		res[i] = kind
		taken[i] = true
	return res


static func kind_name(kind: int) -> String:
	return KINDS[kind]["name"] if KINDS.has(kind) else ""
