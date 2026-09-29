extends RefCounted
## Territorial simulation. Every cell has an owner (0 = nobody). Factions grow troops and gold,
## an attack moves a front cell by cell and pays troops for every captured cell. All player
## intents go through apply(action) - the same dictionaries will travel over the network later.
##
## Actions:
##   {type="attack", player, cell: int, ratio: float}          attack whoever owns the cell
##   {type="build",  player, kind: "city"|"port"|"defense", cell: int}

const Rules := preload("res://scripts/sim/rules.gd")
const Names := preload("res://scripts/sim/names.gd")
const BotBrain := preload("res://scripts/sim/bot_brain.gd")

enum Kind { HUMAN, BOT, CITY }

signal territory_changed
signal building_placed(faction_id: int, kind: String, cell: int)
signal building_removed(cell: int)
signal attack_launched(faction_id: int, target_id: int, cell: int, troops: float)
signal faction_eliminated(faction_id: int, by: int)
signal action_rejected(action: Dictionary, reason: String)
signal match_finished(winner_id: int)

var map
var rng := RandomNumberGenerator.new()
var tick: int = 0
var owner: PackedByteArray
var factions: Array = [null]        # index = faction id; 0 = nobody
var attacks: Array = []             # {attacker, target, troops, queue: Array, queued: Dictionary, head: int}
var buildings_at: Dictionary = {}   # cell -> {faction, kind}
var human: int = 1
var finished := false
var bots_enabled := true
var dirty := false


func _init(m, game_seed: int) -> void:
	map = m
	rng.seed = game_seed
	owner = PackedByteArray()
	owner.resize(map.size())
	_spawn_all()


func seconds() -> float:
	return tick * Rules.TICK_DT


# ------------------------------------------------------------------ spawning

func _new_faction(name: String, color: Color, kind: int) -> Dictionary:
	var f := {
		"id": factions.size(), "name": name, "color": color, "kind": kind,
		"troops": 0.0, "gold": 0.0, "base_troops": 0.0,
		"cells": 0, "sum_x": 0.0, "sum_y": 0.0,
		"cities": 0, "ports": 0, "defense": 0,
		"alive": true, "border": {}, "spawn": -1,
		"attack_size": Rules.DEFAULT_ATTACK_SIZE,
	}
	factions.append(f)
	return f


func _spawn_all() -> void:
	var used := {}
	var spawns: Array = []
	var me := _new_faction("Вы", Color(0.93, 0.33, 0.33), Kind.HUMAN)
	_spawn_blob(me, Rules.SPAWN_RADIUS, spawns)
	me["troops"] = float(Rules.START_TROOPS)
	for i in Rules.NUM_BOTS:
		var f := _new_faction(Names.bot_name(rng, used), Color.from_hsv(fmod(0.11 + i * 0.618034, 1.0), 0.62, 0.86), Kind.BOT)
		_spawn_blob(f, Rules.SPAWN_RADIUS, spawns)
		f["troops"] = float(Rules.START_TROOPS)
	for i in Rules.NUM_CITY_STATES:
		var f := _new_faction(Names.city_name(rng, used), Color(0.60, 0.60, 0.62), Kind.CITY)
		_spawn_blob(f, rng.randi_range(Rules.CITY_STATE_RADIUS_MIN, Rules.CITY_STATE_RADIUS_MAX), spawns)
		f["troops"] = float(rng.randi_range(Rules.CITY_STATE_TROOPS_MIN, Rules.CITY_STATE_TROOPS_MAX))
		f["base_troops"] = f["troops"]
	dirty = true


func _spawn_blob(f: Dictionary, radius: int, spawns: Array) -> void:
	var center := -1
	var min_d2 := Rules.MIN_SPAWN_DISTANCE * Rules.MIN_SPAWN_DISTANCE
	for attempt in 4000:
		var i: int = map.land_cells[rng.randi_range(0, map.land_cells.size() - 1)]
		var t: int = map.terrain[i]
		if t != map.GRASS and t != map.SAND:
			continue
		var c: Vector2i = map.cell(i)
		if c.x < 12 or c.y < 12 or c.x > map.width - 13 or c.y > map.height - 13:
			continue
		var ok := true
		for s in spawns:
			if (s - c).length_squared() < min_d2:
				ok = false
				break
		if not ok:
			continue
		var land_n := 0
		var total := 0
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if dx * dx + dy * dy > radius * radius:
					continue
				total += 1
				var j: int = map.index(c + Vector2i(dx, dy))
				if map.is_land(j) and owner[j] == 0:
					land_n += 1
		if land_n < total * 0.6:
			continue
		center = i
		break
	assert(center != -1, "no spawn location found")
	var cc: Vector2i = map.cell(center)
	spawns.append(cc)
	f["spawn"] = center
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var j: int = map.index(cc + Vector2i(dx, dy))
			if map.is_land(j) and owner[j] == 0:
				_set_owner(j, f["id"])


# ------------------------------------------------------------------ ownership bookkeeping

func _set_owner(i: int, new_owner: int) -> void:
	var old: int = owner[i]
	if old == new_owner:
		return
	var c: Vector2i = map.cell(i)
	if old != 0:
		var fo: Dictionary = factions[old]
		fo["cells"] -= 1
		fo["sum_x"] -= c.x
		fo["sum_y"] -= c.y
		fo["border"].erase(i)
		if buildings_at.has(i):
			_remove_building(i)
	owner[i] = new_owner
	if new_owner != 0:
		var fn: Dictionary = factions[new_owner]
		fn["cells"] += 1
		fn["sum_x"] += c.x
		fn["sum_y"] += c.y
	_refresh_border(i)
	for n in map.neighbors(i):
		_refresh_border(n)
	dirty = true


func _refresh_border(i: int) -> void:
	var o: int = owner[i]
	if o == 0:
		return
	var is_border := false
	for n in map.neighbors(i):
		if owner[n] != o and map.is_land(n):
			is_border = true
			break
	var b: Dictionary = factions[o]["border"]
	if is_border:
		b[i] = true
	else:
		b.erase(i)


func _remove_building(cell: int) -> void:
	var b: Dictionary = buildings_at[cell]
	var f: Dictionary = factions[b["faction"]]
	match b["kind"]:
		"city":
			f["cities"] -= 1
		"port":
			f["ports"] -= 1
		"defense":
			f["defense"] -= 1
	buildings_at.erase(cell)
	building_removed.emit(cell)


func centroid(fid: int) -> Vector2:
	var f: Dictionary = factions[fid]
	if f["cells"] == 0:
		return Vector2(map.cell(f["spawn"])) + Vector2(0.5, 0.5)
	return Vector2(f["sum_x"] / f["cells"] + 0.5, f["sum_y"] / f["cells"] + 0.5)


# ------------------------------------------------------------------ queries

func max_troops_of(fid: int) -> float:
	var f: Dictionary = factions[fid]
	if f["kind"] == Kind.CITY:
		return f["base_troops"] * Rules.CITY_STATE_MAX_MULT
	return Rules.max_troops(f["cells"], f["cities"])


func growth_of(fid: int) -> float:
	var f: Dictionary = factions[fid]
	if f["kind"] == Kind.CITY:
		return f["troops"] * Rules.CITY_STATE_INTEREST + 1.0
	return Rules.growth_per_sec(f["troops"], f["cells"], f["cities"])


func gold_rate_of(fid: int) -> float:
	var f: Dictionary = factions[fid]
	return Rules.gold_per_sec(f["cells"], f["ports"])


func capture_cost(attacker: int, target: int, cell: int) -> float:
	var mult := Rules.terrain_mult(map.terrain[cell]) * Rules.empire_mult(factions[attacker]["cells"])
	if target == 0:
		return Rules.CAPTURE_COST_EMPTY * mult
	var d: Dictionary = factions[target]
	var density: float = d["troops"] / maxf(1.0, float(d["cells"]))
	return (1.0 + density) * mult * (1.0 + d["defense"] * Rules.DEFENSE_BONUS)


func land_share(fid: int) -> float:
	return float(factions[fid]["cells"]) / float(map.land_total)


## Players (human and bots) sorted by land, eliminated ones last.
func ranking() -> Array:
	var out: Array = []
	for id in range(1, factions.size()):
		var f: Dictionary = factions[id]
		if f["kind"] != Kind.CITY:
			out.append(f)
	out.sort_custom(func(a, b): return a["cells"] > b["cells"] if a["alive"] == b["alive"] else a["alive"])
	return out


func rank_of(fid: int) -> int:
	var r := ranking()
	for i in r.size():
		if r[i]["id"] == fid:
			return i + 1
	return 0


func leader() -> int:
	var r := ranking()
	return r[0]["id"] if r.size() > 0 else 0


func contacts_of(fid: int) -> Dictionary:
	var contacts := {}
	for i in factions[fid]["border"]:
		for n in map.neighbors(i):
			if map.is_land(n):
				var o: int = owner[n]
				if o != fid:
					contacts[o] = contacts.get(o, 0) + 1
	return contacts


func has_attack(fid: int, target: int) -> bool:
	for a in attacks:
		if a["attacker"] == fid and a["target"] == target:
			return true
	return false


# ------------------------------------------------------------------ time

func step() -> void:
	if finished:
		return
	tick += 1
	_grow()
	_advance_attacks()
	if bots_enabled:
		for id in range(1, factions.size()):
			var f: Dictionary = factions[id]
			if f["kind"] == Kind.BOT and f["alive"] and (tick + id * 7) % Rules.BOT_PERIOD_TICKS == 0:
				BotBrain.think(self, id)
	if dirty:
		dirty = false
		territory_changed.emit()
	if seconds() >= Rules.MATCH_SECONDS:
		finished = true
		match_finished.emit(leader())


func _grow() -> void:
	for id in range(1, factions.size()):
		var f: Dictionary = factions[id]
		if not f["alive"]:
			continue
		var cap := max_troops_of(id)
		if f["troops"] < cap:
			f["troops"] = minf(cap, f["troops"] + growth_of(id) * Rules.TICK_DT)
		if f["kind"] != Kind.CITY:
			f["gold"] += gold_rate_of(id) * Rules.TICK_DT


func _advance_attacks() -> void:
	var i := 0
	while i < attacks.size():
		var a: Dictionary = attacks[i]
		var att: int = a["attacker"]
		var tgt: int = a["target"]
		var queue: Array = a["queue"]
		var queued: Dictionary = a["queued"]
		var target_alive: bool = tgt == 0 or factions[tgt]["alive"]
		var rate := Rules.attack_rate(a["troops"])
		var taken := 0
		while taken < rate and a["head"] < queue.size() and a["troops"] > 0.0 and target_alive:
			var head: int = a["head"]
			var pick: int = head + rng.randi_range(0, mini(queue.size() - head, Rules.FRONT_JITTER) - 1)
			var c: int = queue[pick]
			queue[pick] = queue[head]
			a["head"] = head + 1
			queued.erase(c)
			if owner[c] != tgt:
				continue
			var cost := capture_cost(att, tgt, c)
			if a["troops"] < cost:
				a["troops"] = 0.0
				break
			a["troops"] -= cost
			if tgt != 0:
				var d: Dictionary = factions[tgt]
				d["troops"] = maxf(0.0, d["troops"] - cost * Rules.DEFENDER_LOSS)
			_set_owner(c, att)
			for n in map.neighbors(c):
				if owner[n] == tgt and map.is_land(n) and not queued.has(n):
					queued[n] = true
					queue.append(n)
			taken += 1
			if tgt != 0 and factions[tgt]["cells"] == 0:
				_eliminate(tgt, att)
				target_alive = false
		if a["troops"] <= 0.0 or a["head"] >= queue.size() or not target_alive or not factions[att]["alive"]:
			if factions[att]["alive"]:
				factions[att]["troops"] += maxf(0.0, a["troops"])
			attacks.remove_at(i)
		else:
			i += 1


func _eliminate(fid: int, by: int) -> void:
	var f: Dictionary = factions[fid]
	f["alive"] = false
	f["troops"] = 0.0
	f["border"].clear()
	faction_eliminated.emit(fid, by)


# ------------------------------------------------------------------ actions

func launch_attack(fid: int, target: int, ratio: float, cell: int = -1) -> String:
	var f: Dictionary = factions[fid]
	if target == fid:
		return "Это ваша территория"
	if target != 0 and not factions[target]["alive"]:
		return "Этой фракции больше нет"
	var amount: float = f["troops"] * clampf(ratio, 0.01, 1.0)
	if amount < Rules.ATTACK_MIN_TROOPS:
		return "Слишком мало войск"
	for a in attacks:
		if a["attacker"] == fid and a["target"] == target:
			f["troops"] -= amount
			a["troops"] += amount
			return ""
	var queue: Array = []
	var queued := {}
	for i in f["border"]:
		for n in map.neighbors(i):
			if owner[n] == target and map.is_land(n) and not queued.has(n):
				queued[n] = true
				queue.append(n)
	if queue.is_empty():
		if cell >= 0 and f["ports"] > 0 and map.is_coast(cell) and owner[cell] == target:
			queued[cell] = true
			queue.append(cell)          # naval landing
		elif cell >= 0 and map.is_coast(cell) and f["ports"] == 0:
			return "Нет общей границы: для высадки с моря нужен порт"
		else:
			return "Нет общей границы"
	f["troops"] -= amount
	attacks.append({"attacker": fid, "target": target, "troops": amount, "queue": queue, "queued": queued, "head": 0})
	attack_launched.emit(fid, target, queue[0], amount)
	return ""


func building_cost(kind: String, fid: int = 0) -> int:
	var base := 0
	var owned := 0
	if fid > 0:
		var f: Dictionary = factions[fid]
		match kind:
			"city":
				owned = f["cities"]
			"port":
				owned = f["ports"]
			"defense":
				owned = f["defense"]
	match kind:
		"city":
			base = Rules.COST_CITY
		"port":
			base = Rules.COST_PORT
		"defense":
			base = Rules.COST_DEFENSE
	return int(base * (1.0 + Rules.COST_ESCALATION * owned))


func apply(a: Dictionary) -> Dictionary:
	var reason := _apply(a)
	if reason != "":
		action_rejected.emit(a, reason)
	return {"ok": reason == "", "reason": reason}


func _apply(a: Dictionary) -> String:
	var fid: int = a["player"]
	var f: Dictionary = factions[fid]
	if not f["alive"]:
		return "Вы выбыли из игры"
	if finished:
		return "Матч окончен"
	match a["type"]:
		"attack":
			var c: int = a["cell"]
			if c < 0 or c >= owner.size():
				return "Вне карты"
			if map.terrain[c] == map.VOID:
				return "Эта земля вне игры"
			if not map.is_land(c):
				return "Сюда нельзя: вода"
			return launch_attack(fid, owner[c], a["ratio"], c)
		"build":
			var c: int = a["cell"]
			var kind: String = a["kind"]
			if c < 0 or c >= owner.size() or owner[c] != fid:
				return "Строить можно только на своей земле"
			if buildings_at.has(c):
				return "Здесь уже есть постройка"
			var cost := building_cost(kind, fid)
			if cost == 0:
				return "Неизвестная постройка"
			if kind == "port" and not map.is_coast(c):
				return "Порт строится на берегу моря"
			if f["gold"] < cost:
				return "Не хватает золота (нужно %s)" % Names.short_number(cost)
			f["gold"] -= cost
			match kind:
				"city":
					f["cities"] += 1
				"port":
					f["ports"] += 1
				"defense":
					f["defense"] += 1
			buildings_at[c] = {"faction": fid, "kind": kind}
			building_placed.emit(fid, kind, c)
			return ""
	return "Неизвестное действие"
