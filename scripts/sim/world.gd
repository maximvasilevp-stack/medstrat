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
##   {type="tax",    player, level}                                0..3
##   {type="decree", player, kind: "propaganda"|"festival"|"mobilize"}
##   {type="event_choice", player, choice}                         answer the pending event
##   {type="hire", player, minister} / {type="fire", player, minister}
##   {type="agitate", player, party}                               campaign for a party until the election
##   {type="bill", player, bill}                                   put a bill to the Duma
##   {type="budget", player, item, level}                          budget allocation 0..3
##   {type="admin",  player, code}                               cheat code: infinite resources

const Rules := preload("res://scripts/sim/rules.gd")
const Names := preload("res://scripts/sim/names.gd")
const BotBrain := preload("res://scripts/sim/bot_brain.gd")
const Content := preload("res://scripts/sim/content.gd")

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
signal election_result(faction_id: int, won: bool, approval: float)
signal event_offered(faction_id: int, event: Dictionary)
signal event_resolved(faction_id: int, text: String)
signal unrest(faction_id: int, cells_lost: int)
signal decree_applied(faction_id: int, kind: String)
signal duma_changed(faction_id: int, seats: Dictionary, ruling: String)
signal bill_result(faction_id: int, bill: String, passed: bool, support: int)
signal minister_changed(faction_id: int, minister: String, hired: bool)
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
	var me := _new_faction(human_name, Color("#F98BA9"), Kind.HUMAN)
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
		var f := _new_faction(c["name"], Color("#B9B3AE"), Kind.CITY)
		_spawn_blob(f, radius, cell)
		f["troops"] = float(Rules.CITY_STATE_TROOPS_MIN + (Rules.CITY_STATE_TROOPS_MAX - Rules.CITY_STATE_TROOPS_MIN) * (size - 1) / 2 + rng.randi_range(-150, 150))
		f["base_troops"] = f["troops"]
		placed += 1
	while placed < Rules.NUM_CITY_STATES:
		var f := _new_faction(Names.city_name(rng, used), Color("#B9B3AE"), Kind.CITY)
		var radius := rng.randi_range(Rules.CITY_STATE_RADIUS_MIN, Rules.CITY_STATE_RADIUS_MAX)
		_spawn_blob(f, radius, _find_spawn(radius))
		f["troops"] = float(rng.randi_range(Rules.CITY_STATE_TROOPS_MIN, Rules.CITY_STATE_TROOPS_MAX))
		f["base_troops"] = f["troops"]
		placed += 1
	for i in Rules.NUM_BOTS:
		var f := _new_faction(Names.bot_name(rng, used), Color.from_hsv(fmod(0.05 + i * 0.618034, 1.0), 0.48, 0.92), Kind.BOT)
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
		"approval": Rules.APPROVAL_START, "tax": 1, "next_election": 0, "elections_won": 0, "elections_lost": 0,
		"loss_until": 0, "festival_until": 0, "propaganda_cd": 0, "festival_cd": 0, "mobilize_cd": 0,
		"event": {}, "event_until": 0, "next_event": 0, "last_election": "",
		"staff": {}, "seats": {}, "ruling": "", "agitation": {}, "bills": {}, "extra": {}, "budget": {},
		"mods": {}, "mods_dirty": true,
		"history": {"gold": PackedFloat32Array(), "troops": PackedFloat32Array(), "cells": PackedFloat32Array(),
			"approval": PackedFloat32Array(), "income": PackedFloat32Array()},
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
	for id in range(1, factions.size()):
		var f: Dictionary = factions[id]
		if f["kind"] != Kind.CITY:
			f["next_election"] = tick + int(Rules.ELECTION_PERIOD * Rules.TICKS_PER_SEC)
	factions[human]["next_event"] = tick + rng.randi_range(Rules.EVENT_MIN_TICKS, Rules.EVENT_MAX_TICKS)
	for id in range(1, factions.size()):
		if factions[id]["kind"] != Kind.CITY:
			_update_duma(id)
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
		_:
			f["extra"][b["kind"]] = maxi(0, int(f["extra"].get(b["kind"], 0)) - 1)
			f["mods_dirty"] = true
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


## All effects of ministers, bills, extra buildings, extra technologies, the ruling party and the budget.
func mods_of(fid: int) -> Dictionary:
	var f: Dictionary = factions[fid]
	if not f["mods_dirty"]:
		return f["mods"]
	var m := Content.default_mods()
	for key in f["staff"]:
		if f["staff"][key]:
			Content.merge_mods(m, Rules.MINISTERS[key]["mods"])
			m["salary"] += Rules.MINISTERS[key]["salary"]
	for key in f["bills"]:
		if f["bills"][key]:
			Content.merge_mods(m, Rules.BILLS[key]["mods"])
	for key in f["extra"]:
		var n: int = f["extra"][key]
		if n > 0:
			Content.merge_mods(m, Rules.BUILDINGS[key]["mods"], n)
	for key in Rules.EXTRA_TECHS:
		var level: int = int(f["tech"].get(key, 0))
		if level > 0:
			Content.merge_mods(m, Rules.EXTRA_TECHS[key]["mods"], level)
	if f["ruling"] != "" and Rules.PARTIES.has(f["ruling"]):
		Content.merge_mods(m, Rules.PARTIES[f["ruling"]]["mods"])
	for key in f["budget"]:
		var level: int = f["budget"][key]
		if level > 0:
			Content.merge_mods(m, Rules.BUDGET[key]["mods"], level)
	f["mods"] = m
	f["mods_dirty"] = false
	return m


func mod(fid: int, key: String) -> float:
	return float(mods_of(fid).get(key, 1.0 if key in Content.MOD_MULT else 0.0))


func budget_cost(fid: int) -> float:
	var f: Dictionary = factions[fid]
	var levels := 0
	for key in f["budget"]:
		levels += int(f["budget"][key])
	return f["cells"] * Rules.BUDGET_COST_PER_CELL * levels


func has_minister(fid: int, key: String) -> bool:
	return bool(factions[fid]["staff"].get(key, false))


func has_bill(fid: int, key: String) -> bool:
	return bool(factions[fid]["bills"].get(key, false))


func salaries_of(fid: int) -> float:
	return mod(fid, "salary")


func tech_discount(fid: int) -> float:
	return mod(fid, "tech_cost")


func tech_def(key: String) -> Dictionary:
	if Rules.TECHS.has(key):
		return Rules.TECHS[key]
	return Rules.EXTRA_TECHS[key]


func tech_cost(fid: int, key: String) -> int:
	var t: Dictionary = tech_def(key)
	var level := tech_level(fid, key)
	if level >= t["max"]:
		return 0
	return int(round(t["costs"][level] * tech_discount(fid)))


## Parliament seats from the way the country is run, plus campaign money.
func compute_seats(fid: int) -> Dictionary:
	var f: Dictionary = factions[fid]
	var extra: Dictionary = f["extra"]
	var w := {
		"order": 20.0 + f["barracks"] * 5.0 + f["defense"] * 4.0 + attacks_of(fid).size() * 3.0 + f["nukes"] * 4.0 + extra.get("fortress", 0) * 3.0 + extra.get("hq", 0) * 3.0,
		"trade": 20.0 + f["markets"] * 5.0 + f["ports"] * 4.0 + f["tax"] * 5.0 + tech_level(fid, "trade") * 4.0 + extra.get("bank", 0) * 3.0 + extra.get("customs", 0) * 3.0 + extra.get("casino", 0) * 2.0,
		"people": 20.0 + f["approval"] * 0.5 + (3 - f["tax"]) * 6.0 + extra.get("stadium", 0) * 3.0 + extra.get("temple", 0) * 2.0,
		"tech": 20.0 + f["cities"] * 2.0 + extra.get("university", 0) * 4.0 + extra.get("lab", 0) * 4.0,
		"green": 12.0 + extra.get("farm", 0) * 3.0 + extra.get("hospital", 0) * 3.0 + extra.get("granary", 0) * 2.0 + (8.0 if f["nukes"] == 0 else 0.0) + maxf(0.0, f["approval"] - 60.0) * 0.3,
		"empire": 12.0 + f["cells"] / 400.0 + attacks_of(fid).size() * 4.0 + f["ports"] * 2.0 + extra.get("shipyard", 0) * 3.0 + extra.get("arsenal", 0) * 2.0,
	}
	for key in Rules.TECH_ORDER:
		w["tech"] += tech_level(fid, key) * 4.0
	for key in Rules.EXTRA_TECH_ORDER:
		w["tech"] += tech_level(fid, key) * 3.0
	for party in f["agitation"]:
		w[party] += f["agitation"][party]
	var total := 0.0
	for party in w:
		total += w[party]
	var seats := {}
	var given := 0
	var remainders: Array = []
	for party in Rules.PARTY_ORDER:
		var exact: float = w[party] / total * Rules.DUMA_SEATS
		seats[party] = int(floor(exact))
		given += seats[party]
		remainders.append([exact - floor(exact), party])
	remainders.sort_custom(func(a, b): return a[0] > b[0])
	var i := 0
	while given < Rules.DUMA_SEATS:
		seats[remainders[i % remainders.size()][1]] += 1
		given += 1
		i += 1
	return seats


func _update_duma(fid: int) -> void:
	var f: Dictionary = factions[fid]
	f["seats"] = compute_seats(fid)
	f["agitation"] = {}
	var best := ""
	var best_seats := -1
	for party in Rules.PARTY_ORDER:
		if f["seats"][party] > best_seats:
			best_seats = f["seats"][party]
			best = party
	f["ruling"] = best
	f["mods_dirty"] = true
	duma_changed.emit(fid, f["seats"], best)


func bill_support(fid: int, key: String) -> int:
	var seats: Dictionary = factions[fid]["seats"]
	var support := 0
	for party in Rules.BILLS[key]["support"]:
		support += int(seats.get(party, 0))
	return support


func record_history(fid: int) -> void:
	var f: Dictionary = factions[fid]
	var h: Dictionary = f["history"]
	var samples := {"gold": f["gold"], "troops": f["troops"], "cells": float(f["cells"]), "approval": f["approval"], "income": gold_rate_of(fid)}
	for key in samples:
		var arr: PackedFloat32Array = h[key]
		arr.append(samples[key])
		if arr.size() > Rules.HISTORY_MAX:
			arr.remove_at(0)
		h[key] = arr


func income_breakdown(fid: int) -> Dictionary:
	var f: Dictionary = factions[fid]
	var mult := 1.0 + tech_level(fid, "trade") * Rules.TRADE_BONUS
	return {
		"Земля": (Rules.GOLD_BASE + f["cells"] * Rules.GOLD_PER_CELL) * mult,
		"Налоги": f["cells"] * f["tax"] * Rules.TAX_GOLD_PER_CELL * mult,
		"Порты": f["ports"] * Rules.PORT_GOLD * mult,
		"Рынки": f["markets"] * Rules.MARKET_GOLD,
		"Постройки": mod(fid, "gold_flat"),
		"Зарплаты": -salaries_of(fid),
		"Бюджет": -budget_cost(fid),
	}


func max_troops_of(fid: int) -> float:
	var f: Dictionary = factions[fid]
	if f["kind"] == Kind.CITY:
		return f["base_troops"] * Rules.CITY_STATE_MAX_MULT
	var cap: float = Rules.max_troops(f["cells"], f["cities"]) + f["barracks"] * Rules.BARRACKS_CAP + mod(fid, "cap_flat")
	return cap * mod(fid, "cap")


func approval_factor(fid: int) -> float:
	var f: Dictionary = factions[fid]
	var k: float = clampf(f["approval"] / 100.0, 0.0, 1.0)
	var m: float = lerpf(Rules.APPROVAL_GROWTH_MIN, Rules.APPROVAL_GROWTH_MAX, k)
	if tick < f["loss_until"]:
		m *= Rules.ELECTION_LOSS_GROWTH
	if tick < f["festival_until"]:
		m *= Rules.FESTIVAL_GROWTH
	return m * mod(fid, "growth")


func growth_of(fid: int) -> float:
	var f: Dictionary = factions[fid]
	if f["kind"] == Kind.CITY:
		return f["troops"] * Rules.CITY_STATE_INTEREST + 1.0
	var extra: float = tech_level(fid, "conscription") * Rules.CONSCRIPTION_BONUS + f["barracks"] * Rules.BARRACKS_INTEREST + mod(fid, "interest")
	return Rules.growth_per_sec(f["troops"], f["cells"], f["cities"], extra) * approval_factor(fid)


func population_of(fid: int) -> int:
	var f: Dictionary = factions[fid]
	return f["cells"] * 10 + f["cities"] * 500


func gold_rate_of(fid: int) -> float:
	var f: Dictionary = factions[fid]
	var base := Rules.gold_per_sec(f["cells"], f["ports"])
	var taxes: float = f["cells"] * f["tax"] * Rules.TAX_GOLD_PER_CELL
	var rate: float = (base + taxes) * (1.0 + tech_level(fid, "trade") * Rules.TRADE_BONUS) + f["markets"] * Rules.MARKET_GOLD
	if tick < f["loss_until"]:
		rate *= Rules.ELECTION_LOSS_GOLD
	rate = rate * mod(fid, "gold") + mod(fid, "gold_flat")
	return rate - salaries_of(fid) - budget_cost(fid)


func approval_target(fid: int) -> float:
	var f: Dictionary = factions[fid]
	var t: float = Rules.APPROVAL_BASE_TARGET - f["tax"] * Rules.TAX_APPROVAL
	t += minf(Rules.BUILDING_APPROVAL_CAP, f["markets"] * Rules.MARKET_APPROVAL + f["cities"] * Rules.CITY_APPROVAL)
	t -= minf(Rules.WAR_WEARINESS_CAP, attacks_of(fid).size() * Rules.WAR_WEARINESS)
	t += mod(fid, "approval")
	return clampf(t, 0.0, 100.0)


func seconds_to_election(fid: int) -> float:
	return maxf(0.0, (factions[fid]["next_election"] - tick) * Rules.TICK_DT)


func decree_cost(fid: int, kind: String) -> int:
	var base := 0
	match kind:
		"propaganda":
			base = Rules.PROPAGANDA_COST
		"festival":
			base = Rules.FESTIVAL_COST
		_:
			if Rules.EXTRA_DECREES.has(kind):
				base = int(Rules.EXTRA_DECREES[kind]["cost"])
	return int(base * mod(fid, "decree_cost"))


func decree_cooldown(fid: int, kind: String) -> float:
	var f: Dictionary = factions[fid]
	var until: int = 0
	match kind:
		"propaganda":
			until = f["propaganda_cd"]
		"festival":
			until = f["festival_cd"]
		"mobilize":
			until = f["mobilize_cd"]
		_:
			until = int(f.get("decree_cd_" + kind, 0))
	return maxf(0.0, (until - tick) * Rules.TICK_DT)


func capture_cost(attacker: int, target: int, cell: int) -> float:
	var mult := Rules.terrain_mult(map.terrain[cell]) * Rules.empire_mult(factions[attacker]["cells"])
	mult *= 1.0 - tech_level(attacker, "logistics") * Rules.LOGISTICS_BONUS
	mult *= mod(attacker, "capture")
	if scorched.has(cell):
		mult *= Rules.SCORCH_COST_MULT
	if target == 0:
		return Rules.CAPTURE_COST_EMPTY * mult
	var d: Dictionary = factions[target]
	var density: float = d["troops"] / maxf(1.0, float(d["cells"]))
	var fort: float = (1.0 + d["defense"] * Rules.DEFENSE_BONUS + tech_level(target, "fortification") * Rules.FORTIFICATION_BONUS) * mod(target, "defense")
	return (1.0 + density) * mult * fort


func bunker_near(cell: int, exclude: int) -> int:
	var c := Vector2(map.cell(cell))
	for b_cell in buildings_at:
		var b: Dictionary = buildings_at[b_cell]
		if b["kind"] == "bunker" and b["faction"] != exclude:
			var r: float = Rules.BUNKER_RADIUS + mod(b["faction"], "shield")
			if Vector2(map.cell(b_cell)).distance_squared_to(c) <= r * r:
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
	if tick % Rules.TICKS_PER_SEC == 0:
		_politics_second()
	if tick % Rules.HISTORY_PERIOD_TICKS == 0 and factions[human]["alive"]:
		record_history(human)
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
			f["gold"] = maxf(0.0, f["gold"] + gold_rate_of(id) * Rules.TICK_DT)
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


func _politics_second() -> void:
	for id in range(1, factions.size()):
		var f: Dictionary = factions[id]
		if f["kind"] == Kind.CITY or not f["alive"]:
			continue
		f["approval"] = clampf(f["approval"] + (approval_target(id) - f["approval"]) * Rules.APPROVAL_DRIFT, 0.0, 100.0)
		if f["admin"]:
			f["approval"] = 100.0
		if f["approval"] < Rules.UNREST_APPROVAL + mod(id, "unrest") and tick % Rules.UNREST_PERIOD_TICKS == 0 and f["cells"] > 30:
			_unrest(id)
		if tick >= f["next_election"]:
			_hold_election(id)
	var h: Dictionary = factions[human]
	if h["alive"] and h["event"].is_empty() and tick >= h["next_event"]:
		_offer_event()
	elif not h["event"].is_empty() and tick >= h["event_until"]:
		_resolve_event(human, 0)


func _unrest(fid: int) -> void:
	var f: Dictionary = factions[fid]
	@warning_ignore("integer_division")
	var n: int = 1 + f["cells"] / Rules.UNREST_CELLS_PER
	var keys: Array = f["border"].keys()
	var lost := 0
	for i in n:
		if keys.is_empty():
			break
		var c: int = keys[rng.randi_range(0, keys.size() - 1)]
		if owner[c] == fid:
			_set_owner(c, 0)
			lost += 1
	if lost > 0:
		unrest.emit(fid, lost)


func _hold_election(fid: int) -> void:
	var f: Dictionary = factions[fid]
	f["next_election"] = tick + int(Rules.ELECTION_PERIOD * Rules.TICKS_PER_SEC)
	_update_duma(fid)
	var won: bool = f["approval"] + mod(fid, "election") >= Rules.ELECTION_WIN_APPROVAL or f["admin"]
	if won:
		f["elections_won"] += 1
		f["approval"] = minf(100.0, f["approval"] + Rules.ELECTION_WIN_BONUS)
		f["last_election"] = "победа"
	else:
		f["elections_lost"] += 1
		f["loss_until"] = tick + Rules.ELECTION_LOSS_TICKS
		f["approval"] = Rules.ELECTION_LOSS_APPROVAL
		f["last_election"] = "поражение"
	election_result.emit(fid, won, f["approval"])


func _offer_event() -> void:
	var h: Dictionary = factions[human]
	var e: Dictionary = Rules.EVENTS[rng.randi_range(0, Rules.EVENTS.size() - 1)]
	h["event"] = e
	h["event_until"] = tick + Rules.EVENT_TIMEOUT_TICKS
	event_offered.emit(human, e)


func _resolve_event(fid: int, choice: int) -> void:
	var f: Dictionary = factions[fid]
	var e: Dictionary = f["event"]
	if e.is_empty():
		return
	var c: Dictionary = e["choices"][clampi(choice, 0, e["choices"].size() - 1)]
	f["gold"] = maxf(0.0, f["gold"] + c.get("gold", 0))
	f["approval"] = clampf(f["approval"] + c.get("approval", 0), 0.0, 100.0)
	if c.has("troops_share"):
		f["troops"] = maxf(0.0, f["troops"] + max_troops_of(fid) * c["troops_share"])
	if c.has("tax"):
		f["tax"] = clampi(f["tax"] + c["tax"], 0, 3)
	if c.has("tech"):
		var options: Array = []
		for key in Rules.TECH_ORDER + Rules.EXTRA_TECH_ORDER:
			var td := tech_def(key)
			if tech_level(fid, key) < td["max"] and (td["req"] == "" or tech_level(fid, td["req"]) > 0):
				options.append(key)
		if not options.is_empty():
			var key: String = options[rng.randi_range(0, options.size() - 1)]
			f["tech"][key] = tech_level(fid, key) + 1
			f["mods_dirty"] = true
			tech_researched.emit(fid, key, f["tech"][key])
	f["event"] = {}
	f["next_event"] = tick + rng.randi_range(Rules.EVENT_MIN_TICKS, Rules.EVENT_MAX_TICKS)
	event_resolved.emit(fid, "%s: %s" % [e["title"], c["text"]])


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
		var rate := int(Rules.attack_rate(a["troops"]) * (1.0 + tech_level(att, "tactics") * Rules.TACTICS_BONUS) * mod(att, "attack_rate"))
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
			var nav: float = (1.0 + tech_level(fid, "navigation") * Rules.NAVIGATION_BONUS) * mod(fid, "ship_speed")
			var reach: float = (1.0 + tech_level(fid, "navigation") * Rules.NAVIGATION_BONUS) * mod(fid, "naval_reach")
			if dist > Rules.NAVAL_REACH * reach:
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
			return int(Rules.NUKE_COST * (mod(fid, "nuke_cost") if fid > 0 else 1.0))
		"mega":
			return int(Rules.MEGA_NUKE_COST * (mod(fid, "nuke_cost") if fid > 0 else 1.0))
		_:
			if Rules.BUILDINGS.has(kind):
				base = Rules.BUILDINGS[kind]["cost"]
				if fid > 0:
					owned = int(factions[fid]["extra"].get(kind, 0))
	var cost := base * (1.0 + Rules.COST_ESCALATION * owned)
	if fid > 0:
		cost *= mod(fid, "build_cost")
	return int(cost)


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
		for key in Rules.TECHS:
			f["tech"][key] = Rules.TECHS[key]["max"]
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
			if Rules.BUILDINGS.has(kind) and Rules.BUILDINGS[kind]["coast"] and not map.is_coast(c):
				return "%s строится на берегу моря" % Rules.BUILDINGS[kind]["name"]
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
				_:
					f["extra"][kind] = int(f["extra"].get(kind, 0)) + 1
					f["mods_dirty"] = true
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
			f["approval"] = clampf(f["approval"] - Rules.NUKE_APPROVAL_HIT, 0.0, 100.0)
			var from := centroid_cell(fid)
			@warning_ignore("integer_division")
			var flight: int = Rules.NUKE_FLIGHT_TICKS / 2 if tech_level(fid, "rockets") > 0 else Rules.NUKE_FLIGHT_TICKS
			missiles.append({"player": fid, "cell": c, "from": from, "mega": mega, "ticks_left": flight})
			nuke_launched.emit(fid, from, c, flight, mega)
			return ""
		"tax":
			f["tax"] = clampi(int(a["level"]), 0, 3)
			return ""
		"decree":
			var kind: String = a["kind"]
			if decree_cooldown(fid, kind) > 0.0:
				return "Указ ещё не готов (%d с)" % int(ceil(decree_cooldown(fid, kind)))
			var cost := decree_cost(fid, kind)
			if Rules.EXTRA_DECREES.has(kind):
				var d: Dictionary = Rules.EXTRA_DECREES[kind]
				if f["gold"] < cost:
					return "Не хватает золота (нужно %s)" % Names.short_number(cost)
				f["gold"] = maxf(0.0, f["gold"] - cost + d.get("gold", 0.0))
				f["approval"] = clampf(f["approval"] + d.get("approval", 0.0), 0.0, 100.0)
				if d.has("troops_share"):
					f["troops"] = maxf(0.0, f["troops"] + max_troops_of(fid) * d["troops_share"])
				f["decree_cd_" + kind] = tick + int(d["cooldown"])
				decree_applied.emit(fid, kind)
				return ""
			if f["gold"] < cost:
				return "Не хватает золота (нужно %s)" % Names.short_number(cost)
			match kind:
				"propaganda":
					f["gold"] -= cost
					f["approval"] = minf(100.0, f["approval"] + Rules.PROPAGANDA_APPROVAL)
					f["propaganda_cd"] = tick + Rules.PROPAGANDA_COOLDOWN_TICKS
				"festival":
					f["gold"] -= cost
					f["approval"] = minf(100.0, f["approval"] + Rules.FESTIVAL_APPROVAL)
					f["festival_until"] = tick + Rules.FESTIVAL_TICKS
					f["festival_cd"] = tick + Rules.FESTIVAL_COOLDOWN_TICKS
				"mobilize":
					f["troops"] += max_troops_of(fid) * Rules.MOBILIZE_SHARE
					f["approval"] = maxf(0.0, f["approval"] - Rules.MOBILIZE_APPROVAL)
					f["mobilize_cd"] = tick + Rules.MOBILIZE_COOLDOWN_TICKS
				_:
					return "Неизвестный указ"
			decree_applied.emit(fid, kind)
			return ""
		"event_choice":
			if f["event"].is_empty():
				return "Нет события"
			_resolve_event(fid, int(a["choice"]))
			return ""
		"hire":
			var key: String = a["minister"]
			if not Rules.MINISTERS.has(key):
				return "Нет такой должности"
			if has_minister(fid, key):
				return "Уже нанят"
			var fee: int = Rules.MINISTERS[key]["fee"]
			if f["gold"] < fee:
				return "Не хватает золота (нужно %s)" % Names.short_number(fee)
			f["gold"] -= fee
			f["staff"][key] = true
			f["mods_dirty"] = true
			minister_changed.emit(fid, key, true)
			return ""
		"fire":
			var key: String = a["minister"]
			if not has_minister(fid, key):
				return "Такого сотрудника нет"
			f["staff"][key] = false
			f["mods_dirty"] = true
			minister_changed.emit(fid, key, false)
			return ""
		"agitate":
			var party: String = a["party"]
			if not Rules.PARTIES.has(party):
				return "Нет такой партии"
			if f["gold"] < Rules.AGITATION_COST:
				return "Не хватает золота (нужно %s)" % Names.short_number(Rules.AGITATION_COST)
			f["gold"] -= Rules.AGITATION_COST
			f["agitation"][party] = f["agitation"].get(party, 0.0) + Rules.AGITATION_WEIGHT
			return ""
		"bill":
			var key: String = a["bill"]
			if not Rules.BILLS.has(key):
				return "Нет такого закона"
			if has_bill(fid, key):
				return "Закон уже принят"
			var cost: int = Rules.BILLS[key]["cost"]
			if f["gold"] < cost:
				return "Не хватает золота (нужно %s)" % Names.short_number(cost)
			f["gold"] -= cost
			var support := bill_support(fid, key)
			var passed: bool = support >= Rules.BILL_MAJORITY
			if passed:
				f["bills"][key] = true
				f["mods_dirty"] = true
			bill_result.emit(fid, key, passed, support)
			return ""
		"budget":
			var item: String = a["item"]
			if not Rules.BUDGET.has(item):
				return "Нет такой статьи бюджета"
			f["budget"][item] = clampi(int(a["level"]), 0, Rules.BUDGET_MAX)
			f["mods_dirty"] = true
			return ""
		"research":
			var key: String = a["tech"]
			if not Rules.TECHS.has(key) and not Rules.EXTRA_TECHS.has(key):
				return "Неизвестная технология"
			var t: Dictionary = tech_def(key)
			var level := tech_level(fid, key)
			if level >= t["max"]:
				return "Уже изучено полностью"
			if t["req"] != "" and tech_level(fid, t["req"]) == 0:
				return "Сначала изучите: %s" % tech_def(t["req"])["name"]
			var cost := tech_cost(fid, key)
			if f["gold"] < cost:
				return "Не хватает золота (нужно %s)" % Names.short_number(cost)
			f["gold"] -= cost
			f["tech"][key] = level + 1
			f["mods_dirty"] = true
			tech_researched.emit(fid, key, level + 1)
			return ""
	return "Неизвестное действие"
