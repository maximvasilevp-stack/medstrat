extends RefCounted
## Territorial simulation. Every cell has an owner (0 = nobody). Factions grow troops and gold,
## an attack moves a front cell by cell and pays troops for every captured cell. Ships carry
## landings across the sea, missiles turn land to ash. All player intents go through apply(action),
## the same dictionaries will travel over the network later.
##
## Actions:
##   {type="spawn",  player, cell}                                 pick the starting point
##   {type="attack", player, cell, ratio}                          attack whoever owns the cell
##   {type="cancel", player, target}                               call an attack off
##   {type="build",  player, kind: "city"|"port"|"defense", cell}
##   {type="nuke",   player, cell, mega: bool}
##   {type="research", player, tech}                             buy the next level of a technology
##   {type="admin",  player, code}                               cheat code: infinite resources

const Rules := preload("res://scripts/sim/rules.gd")
const Names := preload("res://scripts/sim/names.gd")
const BotBrain := preload("res://scripts/sim/bot_brain.gd")

enum Kind { HUMAN, BOT, CITY }
enum Phase { SPAWN, PLAY, FINISHED }

signal territory_changed
signal building_placed(faction_id: int, kind: String, cell: int)
signal building_removed(cell: int)
signal attack_launched(faction_id: int, target_id: int, cell: int, troops: float)
signal ship_launched(faction_id: int, from_cell: int, to_cell: int, ticks: int)
signal ship_landed(faction_id: int, cell: int, success: bool)
signal nuke_launched(faction_id: int, from_cell: int, to_cell: int, ticks: int, mega: bool)
signal nuke_detonated(cell: int, radius: int)
signal nuke_intercepted(cell: int, by: int)
signal tech_researched(faction_id: int, tech: String, level: int)
signal admin_enabled(faction_id: int)
signal faction_eliminated(faction_id: int, by: int)
signal action_rejected(action: Dictionary, reason: String)
signal match_started
signal match_finished(winner_id: int)

var map
var rng := RandomNumberGenerator.new()
var tick: int = 0
var match_start_tick: int = 0
var phase: int = Phase.SPAWN
var spawn_ticks_left: int = Rules.SPAWN_SECONDS * Rules.TICKS_PER_SEC
var owner: PackedByteArray
var heat: PackedByteArray             # 255 = captured this tick, fades to 0
var scorch: PackedByteArray           # 255 = just nuked, fades to 0
var factions: Array = [null]          # index = faction id; 0 = nobody
var attacks: Array = []               # {attacker, target, troops, queue: Array, queued: Dictionary, head: int}
var ships: Array = []                 # {attacker, target, troops, cell, from, ticks_left, total}
var missiles: Array = []              # {player, cell, from, mega, ticks_left}
var buildings_at: Dictionary = {}     # cell -> {faction, kind}
var scorched: Dictionary = {}         # cell -> tick when it heals
var human: int = 1
var bots_enabled := true
var dirty := false
var heat_dirty := false
var scorch_dirty := false
var _spawns: Array = []
var _captured_now := PackedInt32Array()
var _recent: Array = []               # ring of PackedInt32Array, newest first


func _init(m, game_seed: int, human_name: String = "Вы") -> void:
	map = m
	rng.seed = game_seed
	owner = PackedByteArray()
	owner.resize(map.size())
	heat = PackedByteArray()
	heat.resize(map.size())
	scorch = PackedByteArray()
	scorch.resize(map.size())
	var me := _new_faction(human_name, Color(0.93, 0.33, 0.33), Kind.HUMAN)
	me["troops"] = float(Rules.START_TROOPS)
	me["gold"] = float(Rules.START_GOLD)
	var used := {}
	# real cities first: they are the neutral city-states
	var cities: Array = map.cities.duplicate()
	for i in range(cities.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cities[i]
		cities[i] = cities[j]
		cities[j] = tmp
	var placed := 0
	for c in cities:
		if placed >= Rules.NUM_CITY_STATES:
			break
		var size: int = c["size"]
		var radius: int = Rules.CITY_STATE_RADIUS_MIN + size
		var cell: int = c["cell"]
		if owner[cell] != 0 or not _blob_ok(cell, radius, Rules.MIN_SPAWN_DISTANCE * 0.5):
			continue
		var f := _new_faction(c["name"], Color(0.60, 0.60, 0.62), Kind.CITY)
		_spawn_blob(f, radius, cell)
		f["troops"] = float(Rules.CITY_STATE_TROOPS_MIN + (Rules.CITY_STATE_TROOPS_MAX - Rules.CITY_STATE_TROOPS_MIN) * (size - 1) / 2 + rng.randi_range(-150, 150))
		f["base_troops"] = f["troops"]
		placed += 1
	while placed < Rules.NUM_CITY_STATES:
		var f := _new_faction(Names.city_name(rng, used), Color(0.60, 0.60, 0.62), Kind.CITY)
		var radius := rng.randi_range(Rules.CITY_STATE_RADIUS_MIN, Rules.CITY_STATE_RADIUS_MAX)
		_spawn_blob(f, radius, _find_spawn(radius))
		f["troops"] = float(rng.randi_range(Rules.CITY_STATE_TROOPS_MIN, Rules.CITY_STATE_TROOPS_MAX))
		f["base_troops"] = f["troops"]
		placed += 1
	for i in Rules.NUM_BOTS:
		var f := _new_faction(Names.bot_name(rng, used), Color.from_hsv(fmod(0.11 + i * 0.618034, 1.0), 0.62, 0.86), Kind.BOT)
		_spawn_blob(f, Rules.SPAWN_RADIUS, _find_spawn(Rules.SPAWN_RADIUS))
		f["troops"] = float(Rules.START_TROOPS)
		f["gold"] = float(Rules.BOT_START_GOLD)
	dirty = true


func seconds() -> float:
	if phase == Phase.SPAWN:
		return 0.0
	return (tick - match_start_tick) * Rules.TICK_DT


func spawn_seconds_left() -> float:
	return spawn_ticks_left * Rules.TICK_DT


# ------------------------------------------------------------------ spawning

func _new_faction(name: String, color: Color, kind: int) -> Dictionary:
	var f := {
		"id": factions.size(), "name": name, "color": color, "kind": kind,
		"troops": 0.0, "gold": 0.0, "base_troops": 0.0,
		"cells": 0, "sum_x": 0.0, "sum_y": 0.0,
		"cities": 0, "ports": 0, "defense": 0, "markets": 0, "barracks": 0, "bunkers": 0, "nukes": 0,
		"tech": {}, "admin": false,
		"alive": true, "border": {}, "spawn": -1,
		"attack_size": Rules.DEFAULT_ATTACK_SIZE,
	}
	factions.append(f)
	return f


func _blob_ok(center: int, radius: int, min_distance: float) -> bool:
	var t: int = map.terrain[center]
	if t != map.GRASS and t != map.SAND:
		return false
	var c: Vector2i = map.cell(center)
	if c.x < 12 or c.y < 12 or c.x > map.width - 13 or c.y > map.height - 13:
		return false
	for s in _spawns:
		if (s - c).length_squared() < min_distance * min_distance:
			return false
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
	return land_n >= total * 0.6


func _find_spawn(radius: int) -> int:
	for attempt in 4000:
		var i: int = map.land_cells[rng.randi_range(0, map.land_cells.size() - 1)]
		if _blob_ok(i, radius, Rules.MIN_SPAWN_DISTANCE):
			return i
	assert(false, "no spawn location found")
	return map.land_cells[0]


func _spawn_blob(f: Dictionary, radius: int, center: int) -> void:
	var cc: Vector2i = map.cell(center)
	_spawns.append(cc)
	f["spawn"] = center
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var j: int = map.index(cc + Vector2i(dx, dy))
			if map.is_land(j) and owner[j] == 0:
				_set_owner(j, f["id"])


## Human picks a starting point. Returns "" or a reason.
func spawn_human(cell: int) -> String:
	if phase != Phase.SPAWN:
		return "Матч уже идёт"
	if cell < 0 or cell >= owner.size() or not map.is_land(cell):
		return "Старт возможен только на суше"
	if owner[cell] != 0:
		return "Эта земля уже занята"
	if not _blob_ok(cell, Rules.SPAWN_RADIUS, Rules.MIN_SPAWN_DISTANCE * 0.6):
		return "Слишком близко к чужим владениям или к краю карты"
	_spawn_blob(factions[human], Rules.SPAWN_RADIUS, cell)
	factions[human]["gold"] = maxf(0.0, factions[human]["gold"] - Rules.SPAWN_COST)
	_start_match()
	return ""


func auto_spawn_human() -> void:
	if phase != Phase.SPAWN:
		return
	_spawn_blob(factions[human], Rules.SPAWN_RADIUS, _find_spawn(Rules.SPAWN_RADIUS))
	factions[human]["gold"] = maxf(0.0, factions[human]["gold"] - Rules.SPAWN_COST)
	_start_match()


func _start_match() -> void:
	phase = Phase.PLAY
	match_start_tick = tick
	dirty = true
	match_started.emit()


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
	if phase == Phase.PLAY:
		_captured_now.append(i)
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
		"market":
			f["markets"] -= 1
		"barracks":
			f["barracks"] -= 1
		"bunker":
			f["bunkers"] -= 1
	buildings_at.erase(cell)
	building_removed.emit(cell)


func centroid(fid: int) -> Vector2:
	var f: Dictionary = factions[fid]
	if f["cells"] == 0:
		if f["spawn"] < 0:
			return Vector2(map.width, map.height) / 2.0
		return Vector2(map.cell(f["spawn"])) + Vector2(0.5, 0.5)
	return Vector2(f["sum_x"] / f["cells"] + 0.5, f["sum_y"] / f["cells"] + 0.5)


func centroid_cell(fid: int) -> int:
	var c := Vector2i(centroid(fid).floor())
	c.x = clampi(c.x, 0, map.width - 1)
	c.y = clampi(c.y, 0, map.height - 1)
	return map.index(c)


# ------------------------------------------------------------------ queries

func tech_level(fid: int, key: String) -> int:
	return int(factions[fid]["tech"].get(key, 0))


func tech_cost(fid: int, key: String) -> int:
	var t: Dictionary = Rules.TECHS[key]
	var level := tech_level(fid, key)
	if level >= t["max"]:
		return 0
	return int(t["costs"][level])


func max_troops_of(fid: int) -> float:
	var f: Dictionary = factions[fid]
	if f["kind"] == Kind.CITY:
		return f["base_troops"] * Rules.CITY_STATE_MAX_MULT
	return Rules.max_troops(f["cells"], f["cities"]) + f["barracks"] * Rules.BARRACKS_CAP


func growth_of(fid: int) -> float:
	var f: Dictionary = factions[fid]
	if f["kind"] == Kind.CITY:
		return f["troops"] * Rules.CITY_STATE_INTEREST + 1.0
	var extra: float = tech_level(fid, "conscription") * Rules.CONSCRIPTION_BONUS + f["barracks"] * Rules.BARRACKS_INTEREST
	return Rules.growth_per_sec(f["troops"], f["cells"], f["cities"], extra)


func gold_rate_of(fid: int) -> float:
	var f: Dictionary = factions[fid]
	var base := Rules.gold_per_sec(f["cells"], f["ports"])
	return base * (1.0 + tech_level(fid, "trade") * Rules.TRADE_BONUS) + f["markets"] * Rules.MARKET_GOLD


func capture_cost(attacker: int, target: int, cell: int) -> float:
	var mult := Rules.terrain_mult(map.terrain[cell]) * Rules.empire_mult(factions[attacker]["cells"])
	mult *= 1.0 - tech_level(attacker, "logistics") * Rules.LOGISTICS_BONUS
	if scorched.has(cell):
		mult *= Rules.SCORCH_COST_MULT
	if target == 0:
		return Rules.CAPTURE_COST_EMPTY * mult
	var d: Dictionary = factions[target]
	var density: float = d["troops"] / maxf(1.0, float(d["cells"]))
	var fort: float = 1.0 + d["defense"] * Rules.DEFENSE_BONUS + tech_level(target, "fortification") * Rules.FORTIFICATION_BONUS
	return (1.0 + density) * mult * fort


func bunker_near(cell: int, exclude: int) -> int:
	var c := Vector2(map.cell(cell))
	var r2 := float(Rules.BUNKER_RADIUS * Rules.BUNKER_RADIUS)
	for b_cell in buildings_at:
		var b: Dictionary = buildings_at[b_cell]
		if b["kind"] == "bunker" and b["faction"] != exclude and Vector2(map.cell(b_cell)).distance_squared_to(c) <= r2:
			return b["faction"]
	return 0


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


func attacks_of(fid: int) -> Array:
	var out: Array = []
	for a in attacks:
		if a["attacker"] == fid:
			out.append(a)
	return out


func incoming_attacks(fid: int) -> Array:
	var out: Array = []
	for a in attacks:
		if a["target"] == fid:
			out.append(a)
	return out


func ships_of(fid: int) -> Array:
	var out: Array = []
	for s in ships:
		if s["attacker"] == fid:
			out.append(s)
	return out


func nearest_coast_cell(fid: int, to_cell: int) -> int:
	var target := Vector2(map.cell(to_cell))
	var best := -1
	var best_d := INF
	for i in factions[fid]["border"]:
		if map.is_coast(i):
			var d := Vector2(map.cell(i)).distance_squared_to(target)
			if d < best_d:
				best_d = d
				best = i
	return best


# ------------------------------------------------------------------ time

func step() -> void:
	if phase == Phase.FINISHED:
		return
	tick += 1
	if phase == Phase.SPAWN:
		spawn_ticks_left -= 1
		if spawn_ticks_left <= 0:
			auto_spawn_human()
		if dirty:
			dirty = false
			territory_changed.emit()
		return
	_grow()
	_advance_ships()
	_advance_missiles()
	_advance_attacks()
	if bots_enabled:
		for id in range(1, factions.size()):
			var f: Dictionary = factions[id]
			if f["kind"] == Kind.BOT and f["alive"] and (tick + id * 7) % Rules.BOT_PERIOD_TICKS == 0:
				BotBrain.think(self, id)
	if tick % 5 == 0:
		_decay_scorch()
	_update_heat()
	if dirty:
		dirty = false
		territory_changed.emit()
	if seconds() >= Rules.MATCH_SECONDS:
		phase = Phase.FINISHED
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
		if f["admin"]:
			f["gold"] = 999999999.0
			f["troops"] = maxf(f["troops"], 1000000.0)


func _update_heat() -> void:
	if _captured_now.is_empty() and _recent.is_empty():
		return
	_recent.push_front(_captured_now)
	_captured_now = PackedInt32Array()
	if _recent.size() > Rules.HEAT_TICKS:
		var oldest: PackedInt32Array = _recent.pop_back()
		for c in oldest:
			heat[c] = 0
	for age in _recent.size():
		var v := 255 - int(255.0 * age / Rules.HEAT_TICKS)
		for c in _recent[age]:
			heat[c] = v
	heat_dirty = true


func _decay_scorch() -> void:
	if scorched.is_empty():
		return
	var healed: Array = []
	for c in scorched:
		var remaining: int = scorched[c] - tick
		if remaining <= 0:
			healed.append(c)
			scorch[c] = 0
		else:
			scorch[c] = clampi(int(255.0 * remaining / Rules.SCORCH_TICKS), 1, 255)
	for c in healed:
		scorched.erase(c)
	scorch_dirty = true


func _advance_attacks() -> void:
	var i := 0
	while i < attacks.size():
		var a: Dictionary = attacks[i]
		var att: int = a["attacker"]
		var tgt: int = a["target"]
		var queue: Array = a["queue"]
		var queued: Dictionary = a["queued"]
		var target_alive: bool = tgt == 0 or factions[tgt]["alive"]
		var rate := int(Rules.attack_rate(a["troops"]) * (1.0 + tech_level(att, "tactics") * Rules.TACTICS_BONUS))
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


func _advance_ships() -> void:
	var i := 0
	while i < ships.size():
		var s: Dictionary = ships[i]
		s["ticks_left"] -= 1
		if s["ticks_left"] > 0:
			i += 1
			continue
		var att: int = s["attacker"]
		var ok: bool = factions[att]["alive"] and owner[s["cell"]] == s["target"] and (s["target"] == 0 or factions[s["target"]]["alive"])
		if ok:
			_add_attack(att, s["target"], s["troops"], [s["cell"]])
		elif factions[att]["alive"]:
			factions[att]["troops"] += s["troops"]
		ship_landed.emit(att, s["cell"], ok)
		ships.remove_at(i)


func _advance_missiles() -> void:
	var i := 0
	while i < missiles.size():
		var m: Dictionary = missiles[i]
		m["ticks_left"] -= 1
		if m["ticks_left"] > 0:
			i += 1
			continue
		_detonate(m)
		missiles.remove_at(i)


func _detonate(m: Dictionary) -> void:
	var shield := bunker_near(m["cell"], m["player"])
	if shield != 0:
		_captured_now.append(m["cell"])
		nuke_intercepted.emit(m["cell"], shield)
		return
	var radius: int = Rules.MEGA_NUKE_RADIUS if m["mega"] else Rules.NUKE_RADIUS
	var center: Vector2i = map.cell(m["cell"])
	var density := {}
	var lost := {}
	for id in range(1, factions.size()):
		density[id] = factions[id]["troops"] / maxf(1.0, float(factions[id]["cells"]))
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var c := center + Vector2i(dx, dy)
			if not map.in_bounds(c):
				continue
			var j: int = map.index(c)
			if not map.is_land(j):
				continue
			var o: int = owner[j]
			if o != 0:
				lost[o] = lost.get(o, 0) + 1
				_set_owner(j, 0)
			else:
				_captured_now.append(j)
			scorched[j] = tick + Rules.SCORCH_TICKS
			scorch[j] = 255
	scorch_dirty = true
	for o in lost:
		var f: Dictionary = factions[o]
		f["troops"] = maxf(0.0, f["troops"] - lost[o] * density[o] * Rules.NUKE_TROOP_FACTOR)
		if f["cells"] == 0 and f["alive"]:
			_eliminate(o, m["player"])
	nuke_detonated.emit(m["cell"], radius)


func _eliminate(fid: int, by: int) -> void:
	var f: Dictionary = factions[fid]
	f["alive"] = false
	f["troops"] = 0.0
	f["border"].clear()
	faction_eliminated.emit(fid, by)


# ------------------------------------------------------------------ actions

func _add_attack(fid: int, target: int, troops: float, cells: Array) -> void:
	for a in attacks:
		if a["attacker"] == fid and a["target"] == target:
			a["troops"] += troops
			for c in cells:
				if not a["queued"].has(c):
					a["queued"][c] = true
					a["queue"].append(c)
			return
	var queued := {}
	for c in cells:
		queued[c] = true
	attacks.append({"attacker": fid, "target": target, "troops": troops, "queue": cells.duplicate(), "queued": queued, "head": 0})
	attack_launched.emit(fid, target, cells[0], troops)


func launch_attack(fid: int, target: int, ratio: float, cell: int = -1) -> String:
	var f: Dictionary = factions[fid]
	if target == fid:
		return "Это ваша территория"
	if target != 0 and not factions[target]["alive"]:
		return "Этой фракции больше нет"
	var amount: float = f["troops"] * clampf(ratio, 0.01, 1.0)
	if amount < Rules.ATTACK_MIN_TROOPS:
		return "Слишком мало войск"
	var front: Array = []
	var queued := {}
	for i in f["border"]:
		for n in map.neighbors(i):
			if owner[n] == target and map.is_land(n) and not queued.has(n):
				queued[n] = true
				front.append(n)
	var far_click: bool = cell >= 0 and not queued.has(cell)
	if far_click and map.is_coast(cell):
		var from := nearest_coast_cell(fid, cell)
		if f["ports"] == 0:
			if front.is_empty():
				return "Нет общей границы: для высадки с моря нужен порт"
		elif from == -1:
			return "У вас нет берега для отплытия"
		else:
			var dist := Vector2(map.cell(from)).distance_to(Vector2(map.cell(cell)))
			var nav := 1.0 + tech_level(fid, "navigation") * Rules.NAVIGATION_BONUS
			if dist > Rules.NAVAL_REACH * nav:
				return "Слишком далеко для высадки (изучите Навигацию)"
			f["troops"] -= amount
			var ticks := maxi(5, int(dist / (Rules.SHIP_SPEED * nav)))
			ships.append({"attacker": fid, "target": target, "troops": amount, "cell": cell, "from": from, "ticks_left": ticks, "total": ticks})
			ship_launched.emit(fid, from, cell, ticks)
			return ""
	if front.is_empty():
		return "Нет общей границы"
	f["troops"] -= amount
	_add_attack(fid, target, amount, front)
	return ""


func cancel_attack(fid: int, target: int) -> String:
	for i in attacks.size():
		var a: Dictionary = attacks[i]
		if a["attacker"] == fid and a["target"] == target:
			factions[fid]["troops"] += a["troops"]
			attacks.remove_at(i)
			return ""
	return "Такой атаки нет"


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
			"market":
				owned = f["markets"]
			"barracks":
				owned = f["barracks"]
			"bunker":
				owned = f["bunkers"]
	match kind:
		"city":
			base = Rules.COST_CITY
		"port":
			base = Rules.COST_PORT
		"defense":
			base = Rules.COST_DEFENSE
		"market":
			base = Rules.COST_MARKET
		"barracks":
			base = Rules.COST_BARRACKS
		"bunker":
			base = Rules.COST_BUNKER
		"nuke":
			return Rules.NUKE_COST
		"mega":
			return Rules.MEGA_NUKE_COST
	return int(base * (1.0 + Rules.COST_ESCALATION * owned))


func apply(a: Dictionary) -> Dictionary:
	var reason := _apply(a)
	if reason != "":
		action_rejected.emit(a, reason)
	return {"ok": reason == "", "reason": reason}


func _apply(a: Dictionary) -> String:
	var fid: int = a["player"]
	var f: Dictionary = factions[fid]
	if a["type"] == "spawn":
		return spawn_human(a["cell"])
	if a["type"] == "admin":
		if str(a.get("code", "")) != Rules.ADMIN_CODE:
			return "Неверный код"
		f["admin"] = true
		f["gold"] = 999999999.0
		f["troops"] = maxf(f["troops"], 1000000.0)
		admin_enabled.emit(fid)
		return ""
	if phase == Phase.SPAWN:
		return "Сначала выберите точку старта"
	if not f["alive"]:
		return "Вы выбыли из игры"
	if phase == Phase.FINISHED:
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
		"cancel":
			return cancel_attack(fid, a["target"])
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
				"market":
					f["markets"] += 1
				"barracks":
					f["barracks"] += 1
				"bunker":
					f["bunkers"] += 1
			buildings_at[c] = {"faction": fid, "kind": kind}
			building_placed.emit(fid, kind, c)
			return ""
		"nuke":
			var c: int = a["cell"]
			var mega: bool = a.get("mega", false)
			if tech_level(fid, "nuclear") == 0:
				return "Сначала изучите Ядерную программу (меню Развитие, клавиша T)"
			if mega and tech_level(fid, "rockets") == 0:
				return "MEGA NUKE требует технологию Ракеты"
			if c < 0 or c >= owner.size() or not map.is_land(c):
				return "Цель должна быть на суше"
			var cost := building_cost("mega" if mega else "nuke", fid)
			if f["gold"] < cost:
				return "Не хватает золота (нужно %s)" % Names.short_number(cost)
			f["gold"] -= cost
			f["nukes"] += 1
			var from := centroid_cell(fid)
			@warning_ignore("integer_division")
			var flight: int = Rules.NUKE_FLIGHT_TICKS / 2 if tech_level(fid, "rockets") > 0 else Rules.NUKE_FLIGHT_TICKS
			missiles.append({"player": fid, "cell": c, "from": from, "mega": mega, "ticks_left": flight})
			nuke_launched.emit(fid, from, c, flight, mega)
			return ""
		"research":
			var key: String = a["tech"]
			if not Rules.TECHS.has(key):
				return "Неизвестная технология"
			var t: Dictionary = Rules.TECHS[key]
			var level := tech_level(fid, key)
			if level >= t["max"]:
				return "Уже изучено полностью"
			if t["req"] != "" and tech_level(fid, t["req"]) == 0:
				return "Сначала изучите: %s" % Rules.TECHS[t["req"]]["name"]
			var cost := tech_cost(fid, key)
			if f["gold"] < cost:
				return "Не хватает золота (нужно %s)" % Names.short_number(cost)
			f["gold"] -= cost
			f["tech"][key] = level + 1
			tech_researched.emit(fid, key, level + 1)
			return ""
	return "Неизвестное действие"
