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
##   {type="repeal", player, bill}                                 cancel a passed bill (half price)
##   {type="reform", player, axis, option}                         change the constitution on one axis
##   {type="project", player, project}                             start a national project
##   {type="gift", player, target}                                 send gold to a bot: relations up
##   {type="pact", player, target}                                 non-aggression pact for PACT_SECONDS
##   {type="trade_deal", player, target}                           trade agreement: gold per second both ways
##   {type="alliance", player, target}                             permanent pact, allies retaliate for you
##   {type="vassalize", player, target}                            a much smaller rival pays tribute
##   {type="spy", player, target, op}                              covert operation, see Rules.SPY_OPS
##   {type="autopilot", player, task, on}                          let the AI run a part of your country
##   {type="rate", player, level}                                  key interest rate 0..10
##   {type="loan", player, amount} / {type="repay", player, amount}
##   {type="emission", player}                                     print money: gold now, inflation later
##   {type="policy", player, good, policy}                         trade policy for a good (Economy.POLICIES)
##   {type="buy", player, good, amount} / {type="sell", player, good, amount}
##   {type="invest", player, amount} / {type="divest", player, amount}   the stock market
##   {type="tariff", player, level}                                import duties 0..3
##   {type="sanction", player, target, on}                         trade sanctions against a rival
##   {type="admin",  player, code}                               cheat code: infinite resources

const Rules := preload("res://scripts/sim/rules.gd")
const Names := preload("res://scripts/sim/names.gd")
const BotBrain := preload("res://scripts/sim/bot_brain.gd")
const Content := preload("res://scripts/sim/content.gd")
const Resources := preload("res://scripts/sim/resources.gd")
const Missions := preload("res://scripts/sim/missions.gd")
const Economy := preload("res://scripts/sim/economy.gd")

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
signal bill_repealed(faction_id: int, bill: String)
signal reform_changed(faction_id: int, axis: String, option: String)
signal project_started(faction_id: int, project: String)
signal project_done(faction_id: int, project: String)
signal pact_signed(faction_id: int, target: int)
signal gift_sent(faction_id: int, target: int, relation: float)
signal faction_eliminated(faction_id: int, by: int)
signal action_rejected(action: Dictionary, reason: String)
signal match_started
signal match_finished(winner_id: int)
signal season_changed(season: int)
signal trade_signed(faction_id: int, target: int)
signal alliance_formed(faction_id: int, target: int)
signal vassal_gained(faction_id: int, target: int)
signal spy_result(faction_id: int, target: int, op: String, success: bool, text: String)
signal mission_done(faction_id: int, mission: Dictionary)
signal news_posted(text: String, kind: String)
signal economy_event(faction_id: int, text: String)
signal wonder_built(faction_id: int, wonder: String)
signal catch_up_changed(active: bool)

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
var winner_declared: int = 0          # faction that already triggered match_finished (the match may go on)
var lead_since: int = -1              # tick since the current leader has been undisputed
var wonders: Dictionary = {}          # wonder key -> faction that owns it
var catch_up := false                 # the human is far behind and gets Rules.CATCH_UP_MODS
var season: int = 0                   # index into Rules.SEASONS
var difficulty: int = 1               # index into Rules.DIFFICULTIES
var scenario: String = "free"        # key in Scenarios.LIST
var market: Dictionary = Economy.new_market()
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
		f["persona"] = Rules.PERSONA_ORDER[rng.randi_range(0, Rules.PERSONA_ORDER.size() - 1)]
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
		"reforms": _default_reforms(), "projects": {}, "projects_done": {}, "relations": {}, "pacts": {},
		"res": {}, "counters": {}, "trade": {}, "allies": {}, "vassals": {}, "overlord": 0, "persona": "",
		"missions": [], "spy_cd": 0, "autopilot": {}, "econ": Economy.new_state(), "sanctions": {}, "wonders": {},
		"mods": {}, "mods_dirty": true,
		"history": {"gold": PackedFloat32Array(), "troops": PackedFloat32Array(), "cells": PackedFloat32Array(),
			"approval": PackedFloat32Array(), "income": PackedFloat32Array(), "gdp": PackedFloat32Array(),
			"inflation": PackedFloat32Array(), "price_food": PackedFloat32Array(), "pop": PackedFloat32Array(),
			"index": PackedFloat32Array(), "unemployment": PackedFloat32Array()},
		"alive": true, "border": {}, "spawn": -1,
		"attack_size": Rules.DEFAULT_ATTACK_SIZE,
	}
	factions.append(f)
	return f


static func _default_reforms() -> Dictionary:
	var r := {}
	for axis in Rules.REFORM_ORDER:
		r[axis] = Rules.REFORMS[axis]["default"]
	return r


## Recompute every faction's border set from the owner array (after loading a save).
func rebuild_borders() -> void:
	for id in range(1, factions.size()):
		factions[id]["border"] = {}
	for i in map.land_cells:
		if owner[i] != 0:
			_refresh_border(i)


## Free spot for the human next to a city (spiral search); -1 if nothing fits.
func spawn_near(cell: int, radius: int = Rules.SPAWN_RADIUS) -> int:
	var c: Vector2i = map.cell(cell)
	for ring in range(2, 40):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if absi(dx) != ring and absi(dy) != ring:
					continue
				var p := c + Vector2i(dx, dy)
				if not map.in_bounds(p):
					continue
				var i: int = map.index(p)
				if map.is_land(i) and owner[i] == 0 and _blob_ok(i, radius, Rules.MIN_SPAWN_DISTANCE * 0.6):
					return i
	return -1


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
	var ms: Array = factions[human]["missions"]
	while ms.size() < Missions.ACTIVE:
		ms.append(Missions.draw(self, human, ms, 0))
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
			if new_owner != 0 and Rules.WONDERS.has(buildings_at[i]["kind"]):
				_transfer_wonder(i, new_owner)
			else:
				_remove_building(i)
		if map.resources[i] != 0:
			var k: int = map.resources[i]
			fo["res"][k] = int(fo["res"].get(k, 0)) - 1
			fo["mods_dirty"] = true
	owner[i] = new_owner
	if new_owner != 0:
		var fn: Dictionary = factions[new_owner]
		fn["cells"] += 1
		if old != 0 and phase == Phase.PLAY:
			fn["counters"]["captured_enemy"] = int(fn["counters"].get("captured_enemy", 0)) + 1
		fn["sum_x"] += c.x
		fn["sum_y"] += c.y
		if map.resources[i] != 0:
			var k: int = map.resources[i]
			fn["res"][k] = int(fn["res"].get(k, 0)) + 1
			fn["mods_dirty"] = true
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


func _transfer_wonder(cell: int, new_owner: int) -> void:
	var b: Dictionary = buildings_at[cell]
	var key: String = b["kind"]
	var old: Dictionary = factions[b["faction"]]
	old["wonders"].erase(key)
	old["mods_dirty"] = true
	b["faction"] = new_owner
	factions[new_owner]["wonders"][key] = true
	factions[new_owner]["mods_dirty"] = true
	wonders[key] = new_owner
	_news("%s захватывает чудо света: %s" % [factions[new_owner]["name"], Rules.WONDERS[key]["name"]], "war")


func _remove_building(cell: int) -> void:
	var b: Dictionary = buildings_at[cell]
	var f: Dictionary = factions[b["faction"]]
	if Rules.WONDERS.has(b["kind"]):
		f["wonders"].erase(b["kind"])
		wonders.erase(b["kind"])
		f["mods_dirty"] = true
		buildings_at.erase(cell)
		return
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
	for axis in f["reforms"]:
		var opt: String = f["reforms"][axis]
		if Rules.REFORMS.has(axis) and Rules.REFORMS[axis]["options"].has(opt):
			Content.merge_mods(m, Rules.REFORMS[axis]["options"][opt]["mods"])
	for key in f["projects_done"]:
		if f["projects_done"][key]:
			Content.merge_mods(m, Rules.PROJECTS[key]["mods"])
	for kind in f["res"]:
		var n: int = mini(int(f["res"][kind]), Resources.STACK_CAP)
		if n > 0:
			Content.merge_mods(m, Resources.KINDS[kind]["mods"], n)
	if f["kind"] != Kind.CITY:
		Content.merge_mods(m, Rules.SEASONS[season]["mods"])
		Content.merge_mods(m, Economy.mods(f))
	for key in f["wonders"]:
		if f["wonders"][key]:
			Content.merge_mods(m, Rules.WONDERS[key]["mods"])
	if fid == human and catch_up:
		Content.merge_mods(m, Rules.CATCH_UP_MODS)
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
	return f["cells"] * Rules.BUDGET_COST_PER_CELL * levels * mod(fid, "budget_cost")


func has_minister(fid: int, key: String) -> bool:
	return bool(factions[fid]["staff"].get(key, false))


func has_bill(fid: int, key: String) -> bool:
	return bool(factions[fid]["bills"].get(key, false))


func salaries_of(fid: int) -> float:
	return mod(fid, "salary") * mod(fid, "salary_mult")


func bill_cost(fid: int, key: String) -> int:
	return int(round(Rules.BILLS[key]["cost"] * mod(fid, "bill_cost") * price_level(fid)))


## Inflation multiplies every gold price (1.0 = prices of the first minute).
func price_level(fid: int) -> float:
	return float(factions[fid]["econ"]["price_level"])


## Why a bill cannot be put to the vote right now ("" = it can).
func bill_blocked(fid: int, key: String) -> String:
	var bl: Dictionary = Rules.BILLS[key]
	if bl.has("req") and not has_bill(fid, bl["req"]):
		return "Сначала: %s" % Rules.BILLS[bl["req"]]["name"]
	if bl.has("req_tech") and tech_level(fid, bl["req_tech"]) == 0:
		return "Нужна технология: %s" % tech_def(bl["req_tech"])["name"]
	for other in bl.get("excl", []):
		if has_bill(fid, other):
			return "Несовместим: %s" % Rules.BILLS[other]["name"]
	return ""


func reform_cost(fid: int) -> int:
	return int(round(Rules.REFORM_COST * mod(fid, "bill_cost") * price_level(fid)))


func project_progress(fid: int, key: String) -> float:
	var f: Dictionary = factions[fid]
	if f["projects_done"].get(key, false):
		return 1.0
	if not f["projects"].has(key):
		return 0.0
	return clampf(float(f["projects"][key]) / float(Rules.PROJECTS[key]["duration"]), 0.0, 1.0)


func active_projects(fid: int) -> int:
	return factions[fid]["projects"].size()


## How faction a feels about faction b (0..100); the target's own charm ("relation" mod) counts.
func relation_of(a: int, b: int) -> float:
	var base: float = float(factions[a]["relations"].get(b, Rules.RELATION_START))
	return clampf(base + mod(b, "relation"), 0.0, 100.0)


func pact_active(a: int, b: int) -> bool:
	if int(factions[a]["pacts"].get(b, 0)) > tick:
		return true
	var fa: Dictionary = factions[a]
	return bool(fa["allies"].get(b, false)) or fa["overlord"] == b or factions[b]["overlord"] == a


func pact_seconds_left(a: int, b: int) -> float:
	return maxf(0.0, (int(factions[a]["pacts"].get(b, 0)) - tick) * Rules.TICK_DT)


func gift_cost(fid: int, target: int) -> int:
	return int(round((Rules.GIFT_COST + factions[target]["cells"] * Rules.GIFT_COST_PER_CELL) * mod(fid, "pact_cost")))


func pact_cost(fid: int, target: int) -> int:
	return int(round((Rules.PACT_COST + factions[target]["cells"] * Rules.PACT_COST_PER_CELL) * mod(fid, "pact_cost")))


## Let the match go on after a winner was declared (the result screen offers it).
func resume() -> void:
	if phase == Phase.FINISHED:
		phase = Phase.PLAY


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
	return int(round(t["costs"][level] * tech_discount(fid) * price_level(fid)))


## Parliament seats from the way the country is run, plus campaign money.
func compute_seats(fid: int) -> Dictionary:
	var f: Dictionary = factions[fid]
	var extra: Dictionary = f["extra"]
	var w := {
		"order": 20.0 + f["barracks"] * 5.0 + f["defense"] * 4.0 + attacks_of(fid).size() * 3.0 + f["nukes"] * 4.0,
		"trade": 20.0 + f["markets"] * 5.0 + f["ports"] * 4.0 + f["tax"] * 5.0 + tech_level(fid, "trade") * 4.0,
		"people": 20.0 + f["approval"] * 0.5 + (3 - f["tax"]) * 6.0,
		"tech": 20.0 + f["cities"] * 2.0,
		"green": 12.0 + (8.0 if f["nukes"] == 0 else 0.0) + maxf(0.0, f["approval"] - 60.0) * 0.3,
		"empire": 12.0 + f["cells"] / 400.0 + attacks_of(fid).size() * 4.0 + f["ports"] * 2.0,
	}
	for key in Rules.TECH_ORDER:
		w["tech"] += tech_level(fid, key) * 4.0
	for key in Rules.EXTRA_TECH_ORDER:
		w["tech"] += tech_level(fid, key) * 3.0
	for key in extra:
		var n: int = extra[key]
		if n > 0 and Rules.BUILDINGS.has(key):
			w[Rules.BUILDINGS[key]["party"]] += n * 3.0
	for key in f["wonders"]:
		if f["wonders"][key]:
			w[Rules.WONDERS[key]["party"]] += 5.0
	for key in f["bills"]:
		if f["bills"][key]:
			for party in Rules.BILLS[key]["support"]:
				w[party] += 1.5
	for axis in f["reforms"]:
		var opt: Dictionary = Rules.REFORMS[axis]["options"][f["reforms"][axis]]
		for party in opt["parties"]:
			w[party] += opt["parties"][party]
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
	var samples := {"gold": f["gold"], "troops": f["troops"], "cells": float(f["cells"]), "approval": f["approval"], "income": gold_rate_of(fid),
		"gdp": float(f["econ"]["gdp"]), "inflation": float(f["econ"]["inflation"]), "price_food": Economy.price(self, "food"),
		"pop": float(population_of(fid)), "index": float(f["econ"]["index"]), "unemployment": float(f["econ"]["unemployment"]) * 100.0}
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
		"Торговля": trade_income(fid),
		"Дань": tribute_of(fid),
		"Подоходный": Economy.income_tax(f) * mod(fid, "gold"),
		"Товары": float(f["econ"]["trade_gold"]),
		"Пошлины": float(f["econ"]["tariff_gold"]),
		"Зарплаты": -salaries_of(fid),
		"Бюджет": -budget_cost(fid),
		"Пособия": -Economy.welfare_cost(f),
		"Проценты": -Economy.interest_per_sec(self, fid),
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
	var g: float = Rules.growth_per_sec(f["troops"], f["cells"], f["cities"], extra) * approval_factor(fid)
	if f["kind"] == Kind.BOT:
		g *= Rules.DIFFICULTIES[difficulty]["bot_growth"]
	return g


func population_of(fid: int) -> int:
	var f: Dictionary = factions[fid]
	if f["kind"] != Kind.CITY and float(f["econ"]["pop"]) >= 0.0:
		return int(f["econ"]["pop"])
	return f["cells"] * 10 + f["cities"] * 500


func gold_rate_of(fid: int) -> float:
	var f: Dictionary = factions[fid]
	var base := Rules.gold_per_sec(f["cells"], f["ports"])
	var taxes: float = f["cells"] * f["tax"] * Rules.TAX_GOLD_PER_CELL
	var rate: float = (base + taxes) * (1.0 + tech_level(fid, "trade") * Rules.TRADE_BONUS) + f["markets"] * Rules.MARKET_GOLD
	if tick < f["loss_until"]:
		rate *= Rules.ELECTION_LOSS_GOLD
	rate = rate * mod(fid, "gold") + mod(fid, "gold_flat")
	if f["kind"] == Kind.BOT:
		rate *= Rules.DIFFICULTIES[difficulty]["bot_gold"]
	rate += trade_income(fid) + tribute_of(fid) + Economy.income_tax(f) * mod(fid, "gold")
	return rate - salaries_of(fid) - budget_cost(fid) - Economy.interest_per_sec(self, fid) - Economy.welfare_cost(f)


## Income before salaries, budget, welfare and interest (the base of the credit limit).
func gross_income(fid: int) -> float:
	var f: Dictionary = factions[fid]
	return gold_rate_of(fid) + salaries_of(fid) + budget_cost(fid) + Economy.interest_per_sec(self, fid) + Economy.welfare_cost(f)


func grace_seconds() -> float:
	return float(Rules.DIFFICULTIES[difficulty]["grace"])


func trade_active(a: int, b: int) -> bool:
	return int(factions[a]["trade"].get(b, 0)) > tick


func trade_cost(fid: int, _target: int) -> int:
	return int(round(Rules.TRADE_COST * mod(fid, "pact_cost")))


func alliance_cost(fid: int, target: int) -> int:
	return int(round((Rules.ALLIANCE_COST + factions[target]["cells"] * Rules.PACT_COST_PER_CELL) * mod(fid, "pact_cost")))


func is_ally(a: int, b: int) -> bool:
	return bool(factions[a]["allies"].get(b, false))


func trade_income(fid: int) -> float:
	var total := 0.0
	for o in factions[fid]["trade"]:
		if int(factions[fid]["trade"][o]) > tick and factions[o]["alive"]:
			total += Rules.TRADE_INCOME_BASE + factions[o]["cells"] * Rules.TRADE_INCOME_PER_CELL
	return total


## Tribute received from vassals minus tribute paid to an overlord (a share of the plain land income).
func tribute_of(fid: int) -> float:
	var f: Dictionary = factions[fid]
	var total := 0.0
	for v in f["vassals"]:
		if f["vassals"][v] and factions[v]["alive"]:
			total += _base_income(v) * Rules.VASSAL_TRIBUTE
	if f["overlord"] != 0 and factions[f["overlord"]]["alive"]:
		total -= _base_income(fid) * Rules.VASSAL_TRIBUTE
	return total


func _base_income(fid: int) -> float:
	var f: Dictionary = factions[fid]
	return Rules.gold_per_sec(f["cells"], f["ports"]) + f["markets"] * Rules.MARKET_GOLD


func spy_chance(fid: int, target: int, op: String) -> float:
	var c: float = Rules.SPY_OPS[op]["chance"]
	if has_minister(fid, "spy"):
		c += Rules.SPY_MINISTER_BONUS
	if has_minister(target, "spy"):
		c -= Rules.SPY_COUNTER_MALUS
	return clampf(c, 0.05, 0.95)


func spy_cooldown(fid: int) -> float:
	return maxf(0.0, (int(factions[fid]["spy_cd"]) - tick) * Rules.TICK_DT)


func _count(fid: int, key: String, n: int = 1) -> void:
	var c: Dictionary = factions[fid]["counters"]
	c[key] = int(c.get(key, 0)) + n


func _news(text: String, kind: String) -> void:
	news_posted.emit(text, kind)


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
	if season == 3 and (map.terrain[cell] == 4 or map.terrain[cell] == 5):
		mult *= Rules.WINTER_TERRAIN_MULT
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
	if tick % Rules.BOT_PERIOD_TICKS == 0 and not factions[human]["autopilot"].is_empty():
		BotBrain.autopilot(self, human, factions[human]["autopilot"])
	if tick % Rules.TICKS_PER_SEC == 0:
		_politics_second()
		Economy.tick_second(self)
	if tick % Rules.HISTORY_PERIOD_TICKS == 0 and factions[human]["alive"]:
		record_history(human)
	if tick % 5 == 0:
		_decay_scorch()
	_update_heat()
	if dirty:
		dirty = false
		territory_changed.emit()
	if tick % Rules.TICKS_PER_SEC == 0:
		_check_victory()
		_tick_season()


func _tick_season() -> void:
	var s: int = int(seconds() / Rules.SEASON_SECONDS) % Rules.SEASONS.size()
	if s == season:
		return
	season = s
	for id in range(1, factions.size()):
		factions[id]["mods_dirty"] = true
	season_changed.emit(season)
	_news("Наступает %s: %s" % [Rules.SEASONS[season]["name"].to_lower(), Rules.SEASONS[season]["desc"]], "world")


func resource_count(fid: int, kind: int) -> int:
	return int(factions[fid]["res"].get(kind, 0))


## The match has no clock: it ends when a player holds WIN_LAND_SHARE of the land or is the last one standing.
func _check_victory() -> void:
	if winner_declared != 0:
		return
	var lead := leader()
	var alive := 0
	for id in range(1, factions.size()):
		var f: Dictionary = factions[id]
		if f["kind"] != Kind.CITY and f["alive"]:
			alive += 1
	var undisputed := false
	var r: Array = ranking()
	if r.size() >= 2 and r[0]["id"] == lead and land_share(lead) >= Rules.WIN_LEAD_SHARE and r[0]["cells"] >= r[1]["cells"] * Rules.WIN_LEAD_RATIO:
		if lead_since < 0:
			lead_since = tick
		undisputed = (tick - lead_since) * Rules.TICK_DT >= Rules.WIN_LEAD_SECONDS
	else:
		lead_since = -1
	if land_share(lead) >= Rules.WIN_LAND_SHARE or undisputed or (alive <= 1 and factions[lead]["alive"] and bots_enabled):
		winner_declared = lead
		phase = Phase.FINISHED
		match_finished.emit(lead)


## Seconds the leader has been undisputed (0 when nobody is).
func lead_seconds() -> float:
	return 0.0 if lead_since < 0 else (tick - lead_since) * Rules.TICK_DT


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
		_advance_projects(id)
		_drift_relations(id)
	_check_missions()
	_update_catch_up()
	var h: Dictionary = factions[human]
	if h["alive"] and h["event"].is_empty() and tick >= h["next_event"]:
		_offer_event()
	elif not h["event"].is_empty() and tick >= h["event_until"]:
		_resolve_event(human, 0)


func _update_catch_up() -> void:
	var h: Dictionary = factions[human]
	var lead := leader()
	var active: bool = h["alive"] and seconds() >= Rules.CATCH_UP_AFTER and lead != human and land_share(human) < land_share(lead) * Rules.CATCH_UP_RATIO
	if active != catch_up:
		catch_up = active
		h["mods_dirty"] = true
		catch_up_changed.emit(active)


func _check_missions() -> void:
	var h: Dictionary = factions[human]
	if not h["alive"]:
		return
	var ms: Array = h["missions"]
	for i in ms.size():
		var m: Dictionary = ms[i]
		if Missions.done(self, human, m):
			h["gold"] += float(m["gold"])
			_count(human, "missions_done")
			_count(human, "xp_match", int(m["xp"]))
			mission_done.emit(human, m)
			ms[i] = Missions.draw(self, human, ms, int(h["counters"]["missions_done"]))


func _advance_projects(fid: int) -> void:
	var f: Dictionary = factions[fid]
	if f["projects"].is_empty():
		return
	var speed: float = mod(fid, "project_speed")
	var finished: Array = []
	for key in f["projects"]:
		f["projects"][key] = float(f["projects"][key]) + speed
		if f["projects"][key] >= Rules.PROJECTS[key]["duration"]:
			finished.append(key)
	for key in finished:
		f["projects"].erase(key)
		f["projects_done"][key] = true
		f["approval"] = clampf(f["approval"] + float(Rules.PROJECTS[key]["approval"]), 0.0, 100.0)
		f["mods_dirty"] = true
		project_done.emit(fid, key)
		if fid != human and f["cells"] > 1500:
			_news("%s завершает нацпроект «%s»" % [f["name"], Rules.PROJECTS[key]["name"]], "world")


func _drift_relations(fid: int) -> void:
	var rel: Dictionary = factions[fid]["relations"]
	for other in rel:
		var v: float = rel[other]
		if absf(v - Rules.RELATION_START) <= Rules.RELATION_DRIFT:
			rel[other] = Rules.RELATION_START
		else:
			rel[other] = v + (Rules.RELATION_DRIFT if v < Rules.RELATION_START else -Rules.RELATION_DRIFT)


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
		_count(fid, "election_streak")
	else:
		f["elections_lost"] += 1
		f["loss_until"] = tick + Rules.ELECTION_LOSS_TICKS
		f["approval"] = Rules.ELECTION_LOSS_APPROVAL
		f["last_election"] = "поражение"
		f["counters"]["election_streak"] = 0
		if fid != human and f["cells"] > 1000:
			_news("%s проигрывает выборы" % f["name"], "politics")
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
	if by > 0:
		_count(by, "kills")
	if f["kind"] != Kind.CITY:
		_news("%s уничтожает %s" % [factions[by]["name"] if by > 0 else "Народ", f["name"]], "war")
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
	if target != 0 and pact_active(fid, target):
		return "Пакт о ненападении с %s ещё %d с" % [factions[target]["name"], int(ceil(pact_seconds_left(fid, target)))]
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
			_relation_hit(target, fid)
			_count(fid, "landings")
			return ""
	if front.is_empty():
		return "Нет общей границы"
	f["troops"] -= amount
	_add_attack(fid, target, amount, front)
	_relation_hit(target, fid)
	if fid != human and target != human and target != 0 and amount >= 2000.0 and factions[target]["kind"] != Kind.CITY:
		_news("%s нападает на %s (%s войск)" % [f["name"], factions[target]["name"], Names.short_number(amount)], "war")
	return ""


## Being attacked sours the victim's attitude toward the attacker.
func _relation_hit(victim: int, attacker: int) -> void:
	if victim == 0:
		return
	var rel: Dictionary = factions[victim]["relations"]
	rel[attacker] = maxf(0.0, float(rel.get(attacker, Rules.RELATION_START)) - Rules.RELATION_ATTACK_HIT)


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
			elif Rules.WONDERS.has(kind):
				base = Rules.WONDERS[kind]["cost"]
	var cost := base * (1.0 + Rules.COST_ESCALATION * owned)
	if fid > 0:
		cost *= mod(fid, "build_cost") * price_level(fid)
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
			if Rules.WONDERS.has(kind):
				if wonders.has(kind):
					return "%s уже построен: %s" % [Rules.WONDERS[kind]["name"], factions[wonders[kind]]["name"]]
				if Rules.WONDERS[kind]["coast"] and not map.is_coast(c):
					return "%s строится на берегу моря" % Rules.WONDERS[kind]["name"]
			if f["gold"] < cost:
				return "Не хватает золота (нужно %s)" % Names.short_number(cost)
			f["gold"] -= cost
			if Rules.WONDERS.has(kind):
				f["wonders"][kind] = true
				wonders[kind] = fid
				f["mods_dirty"] = true
				buildings_at[c] = {"faction": fid, "kind": kind}
				building_placed.emit(fid, kind, c)
				_count(fid, "wonders")
				wonder_built.emit(fid, kind)
				_news("%s строит чудо света: %s" % [f["name"], Rules.WONDERS[kind]["name"]], "world")
				return ""
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
			_count(fid, "meganukes" if mega else "nukes")
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
			var blocked := bill_blocked(fid, key)
			if blocked != "":
				return blocked
			var cost: int = bill_cost(fid, key)
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
		"repeal":
			var key: String = a["bill"]
			if not Rules.BILLS.has(key) or not has_bill(fid, key):
				return "Такой закон не действует"
			for other in f["bills"]:
				if f["bills"][other] and Rules.BILLS[other].get("req", "") == key:
					return "Сначала отмените: %s" % Rules.BILLS[other]["name"]
			@warning_ignore("integer_division")
			var cost: int = bill_cost(fid, key) / 2
			if f["gold"] < cost:
				return "Не хватает золота (нужно %s)" % Names.short_number(cost)
			f["gold"] -= cost
			f["bills"][key] = false
			f["mods_dirty"] = true
			bill_repealed.emit(fid, key)
			return ""
		"reform":
			var axis: String = a["axis"]
			var option: String = a["option"]
			if not Rules.REFORMS.has(axis) or not Rules.REFORMS[axis]["options"].has(option):
				return "Нет такой реформы"
			if f["reforms"][axis] == option:
				return "Уже действует"
			var cost := reform_cost(fid)
			if f["gold"] < cost:
				return "Не хватает золота (нужно %s)" % Names.short_number(cost)
			f["gold"] -= cost
			f["reforms"][axis] = option
			f["approval"] = maxf(0.0, f["approval"] - Rules.REFORM_APPROVAL_HIT)
			f["mods_dirty"] = true
			_count(fid, "reforms_done")
			reform_changed.emit(fid, axis, option)
			if fid != human and f["cells"] > 1500:
				_news("%s: %s — %s" % [f["name"], Rules.REFORMS[axis]["name"].to_lower(), Rules.REFORMS[axis]["options"][option]["name"]], "politics")
			return ""
		"project":
			var key: String = a["project"]
			if not Rules.PROJECTS.has(key):
				return "Нет такого проекта"
			var p: Dictionary = Rules.PROJECTS[key]
			if f["projects_done"].get(key, false):
				return "Проект уже завершён"
			if f["projects"].has(key):
				return "Проект уже идёт"
			if active_projects(fid) >= Rules.PROJECT_MAX_ACTIVE:
				return "Одновременно не больше %d проектов" % Rules.PROJECT_MAX_ACTIVE
			if p.has("req_tech") and tech_level(fid, p["req_tech"]) == 0:
				return "Нужна технология: %s" % tech_def(p["req_tech"])["name"]
			var cost: int = int(round(p["cost"] * mod(fid, "build_cost") * price_level(fid)))
			if f["gold"] < cost:
				return "Не хватает золота (нужно %s)" % Names.short_number(cost)
			f["gold"] -= cost
			f["projects"][key] = 0.0
			project_started.emit(fid, key)
			return ""
		"gift":
			var target: int = int(a["target"])
			if target <= 0 or target >= factions.size() or target == fid or factions[target]["kind"] == Kind.CITY:
				return "Некому дарить"
			if not factions[target]["alive"]:
				return "Этой фракции больше нет"
			var cost := gift_cost(fid, target)
			if f["gold"] < cost:
				return "Не хватает золота (нужно %s)" % Names.short_number(cost)
			f["gold"] -= cost
			var rel: Dictionary = factions[target]["relations"]
			rel[fid] = minf(100.0, float(rel.get(fid, Rules.RELATION_START)) + Rules.RELATION_GIFT)
			gift_sent.emit(fid, target, relation_of(target, fid))
			return ""
		"pact":
			var target: int = int(a["target"])
			if target <= 0 or target >= factions.size() or target == fid or factions[target]["kind"] == Kind.CITY:
				return "Не с кем заключать пакт"
			if not factions[target]["alive"]:
				return "Этой фракции больше нет"
			if pact_active(fid, target):
				return "Пакт уже действует (%d с)" % int(ceil(pact_seconds_left(fid, target)))
			var rel := relation_of(target, fid)
			if rel < Rules.PACT_MIN_RELATION:
				return "%s отказывается: отношения %d (нужно %d), помогут подарки" % [factions[target]["name"], int(rel), int(Rules.PACT_MIN_RELATION)]
			var cost := pact_cost(fid, target)
			if f["gold"] < cost:
				return "Не хватает золота (нужно %s)" % Names.short_number(cost)
			f["gold"] -= cost
			var until: int = tick + Rules.PACT_SECONDS * Rules.TICKS_PER_SEC
			f["pacts"][target] = until
			factions[target]["pacts"][fid] = until
			cancel_attack(fid, target)
			cancel_attack(target, fid)
			_count(fid, "pacts_signed")
			pact_signed.emit(fid, target)
			return ""
		"trade_deal":
			var target: int = int(a["target"])
			if target <= 0 or target >= factions.size() or target == fid or factions[target]["kind"] == Kind.CITY:
				return "Не с кем торговать"
			if not factions[target]["alive"]:
				return "Этой фракции больше нет"
			if trade_active(fid, target):
				return "Договор уже действует"
			var rel := relation_of(target, fid)
			if rel < Rules.TRADE_MIN_RELATION:
				return "%s не хочет торговать: отношения %d (нужно %d)" % [factions[target]["name"], int(rel), int(Rules.TRADE_MIN_RELATION)]
			var cost := trade_cost(fid, target)
			if f["gold"] < cost:
				return "Не хватает золота (нужно %s)" % Names.short_number(cost)
			f["gold"] -= cost
			var until: int = tick + Rules.TRADE_SECONDS * Rules.TICKS_PER_SEC
			f["trade"][target] = until
			factions[target]["trade"][fid] = until
			_count(fid, "trades_made")
			trade_signed.emit(fid, target)
			return ""
		"alliance":
			var target: int = int(a["target"])
			if target <= 0 or target >= factions.size() or target == fid or factions[target]["kind"] == Kind.CITY:
				return "Не с кем заключать союз"
			if not factions[target]["alive"]:
				return "Этой фракции больше нет"
			if is_ally(fid, target):
				return "Вы уже союзники"
			var rel := relation_of(target, fid)
			if rel < Rules.ALLIANCE_MIN_RELATION:
				return "%s не готов к союзу: отношения %d (нужно %d)" % [factions[target]["name"], int(rel), int(Rules.ALLIANCE_MIN_RELATION)]
			var cost := alliance_cost(fid, target)
			if f["gold"] < cost:
				return "Не хватает золота (нужно %s)" % Names.short_number(cost)
			f["gold"] -= cost
			f["allies"][target] = true
			factions[target]["allies"][fid] = true
			cancel_attack(fid, target)
			cancel_attack(target, fid)
			_count(fid, "allies_made")
			alliance_formed.emit(fid, target)
			return ""
		"vassalize":
			var target: int = int(a["target"])
			if target <= 0 or target >= factions.size() or target == fid or factions[target]["kind"] == Kind.CITY:
				return "Некого делать вассалом"
			var t: Dictionary = factions[target]
			if not t["alive"]:
				return "Этой фракции больше нет"
			if t["overlord"] != 0:
				return "%s уже чей-то вассал" % t["name"]
			if f["overlord"] != 0:
				return "Вассал не может иметь вассалов"
			if f["cells"] < t["cells"] * Rules.VASSAL_RATIO:
				return "%s не покорится: нужно в %d раза больше земли, чем у него" % [t["name"], int(Rules.VASSAL_RATIO)]
			if relation_of(target, fid) < Rules.VASSAL_MIN_RELATION and not has_attack(fid, target):
				return "%s отказывается: отношения ниже %d и вы на него не давите" % [t["name"], int(Rules.VASSAL_MIN_RELATION)]
			t["overlord"] = fid
			f["vassals"][target] = true
			t["relations"][fid] = 60.0
			cancel_attack(fid, target)
			cancel_attack(target, fid)
			_count(fid, "vassals")
			vassal_gained.emit(fid, target)
			return ""
		"spy":
			var target: int = int(a["target"])
			var op: String = a["op"]
			if not Rules.SPY_OPS.has(op):
				return "Нет такой операции"
			if target <= 0 or target >= factions.size() or target == fid or factions[target]["kind"] == Kind.CITY:
				return "Нет такой цели"
			var t: Dictionary = factions[target]
			if not t["alive"]:
				return "Этой фракции больше нет"
			if spy_cooldown(fid) > 0.0:
				return "Агенты ещё не готовы (%d с)" % int(ceil(spy_cooldown(fid)))
			var cost: int = Rules.SPY_OPS[op]["cost"]
			if f["gold"] < cost:
				return "Не хватает золота (нужно %s)" % Names.short_number(cost)
			var text := ""
			var pick := ""
			match op:
				"steal_tech":
					var options: Array = []
					for key in Rules.TECH_ORDER + Rules.EXTRA_TECH_ORDER:
						if tech_level(target, key) > tech_level(fid, key) and tech_level(fid, key) < tech_def(key)["max"]:
							options.append(key)
					if options.is_empty():
						return "У цели нет технологий, которых нет у вас"
					pick = options[rng.randi_range(0, options.size() - 1)]
				"assassinate":
					var options: Array = []
					for key in t["staff"]:
						if t["staff"][key]:
							options.append(key)
					if options.is_empty():
						return "У цели нет министров"
					pick = options[rng.randi_range(0, options.size() - 1)]
				"arson":
					var options: Array = []
					for c in buildings_at:
						if buildings_at[c]["faction"] == target:
							options.append(c)
					if options.is_empty():
						return "У цели нет построек"
					pick = str(options[rng.randi_range(0, options.size() - 1)])
				"bribe":
					if not has_attack(target, fid):
						return "%s на вас не нападает" % t["name"]
			f["gold"] -= cost
			f["spy_cd"] = tick + Rules.SPY_COOLDOWN_TICKS
			var success: bool = rng.randf() < spy_chance(fid, target, op)
			if success:
				match op:
					"sabotage":
						t["troops"] *= 0.9
						text = "%s теряет 10%% войск" % t["name"]
					"steal_tech":
						f["tech"][pick] = tech_level(fid, pick) + 1
						f["mods_dirty"] = true
						tech_researched.emit(fid, pick, f["tech"][pick])
						text = "Украдены чертежи: %s" % tech_def(pick)["name"]
					"incite":
						t["approval"] = maxf(0.0, t["approval"] - 15.0)
						text = "В %s волнения: одобрение −15" % t["name"]
					"assassinate":
						t["staff"][pick] = false
						t["mods_dirty"] = true
						text = "%s остаётся без должности «%s»" % [t["name"], Rules.MINISTERS[pick]["name"]]
					"arson":
						var c := int(pick)
						var kind: String = buildings_at[c]["kind"]
						_remove_building(c)
						building_removed.emit(c)
						text = "Сгорела постройка %s: %s" % [t["name"], kind]
					"bribe":
						cancel_attack(target, fid)
						text = "Генералы %s отзывают войска" % t["name"]
				_count(fid, "spy_ok")
			else:
				var rel: Dictionary = t["relations"]
				rel[fid] = maxf(0.0, float(rel.get(fid, Rules.RELATION_START)) - Rules.SPY_FAIL_RELATION)
				text = "Агент пойман, %s в ярости (отношения −%d)" % [t["name"], int(Rules.SPY_FAIL_RELATION)]
			spy_result.emit(fid, target, op, success, text)
			return ""
		"rate":
			var level: int = clampi(int(a["level"]), Economy.RATE_MIN, Economy.RATE_MAX)
			f["econ"]["rate"] = level
			f["mods_dirty"] = true
			return ""
		"loan":
			var amount: float = maxf(0.0, float(a["amount"]))
			var e: Dictionary = f["econ"]
			if e["defaulted"]:
				return "После дефолта в долг не дают, пока долг не станет меньше половины лимита"
			var limit := Economy.credit_limit(self, fid)
			if float(e["debt"]) + amount > limit:
				return "Кредитный лимит %s золота (2.5 минуты дохода)" % Names.short_number(limit)
			e["debt"] = float(e["debt"]) + amount
			f["gold"] += amount
			_count(fid, "loans_taken")
			return ""
		"repay":
			var e: Dictionary = f["econ"]
			var amount: float = minf(float(e["debt"]), minf(f["gold"], maxf(0.0, float(a["amount"]))))
			if amount <= 0.0:
				return "Нечего погашать" if float(e["debt"]) <= 0.0 else "Не хватает золота"
			e["debt"] = float(e["debt"]) - amount
			f["gold"] -= amount
			if float(e["debt"]) <= 0.01:
				e["debt"] = 0.0
				_count(fid, "loans_repaid")
			return ""
		"emission":
			var e: Dictionary = f["econ"]
			if int(e["emission_cd"]) > tick:
				return "Печатный станок остывает (%d с)" % int(ceil((int(e["emission_cd"]) - tick) * Rules.TICK_DT))
			var amount := Economy.emission_amount(self, fid)
			f["gold"] += amount
			e["emission_heat"] = float(e["emission_heat"]) + Economy.EMISSION_INFLATION
			e["emission_cd"] = tick + Economy.EMISSION_COOLDOWN
			_count(fid, "emissions")
			economy_event.emit(fid, "Напечатано %s золота, инфляция разгоняется" % Names.short_number(amount))
			return ""
		"policy":
			var good: String = a["good"]
			var policy: String = a["policy"]
			if not Economy.GOODS.has(good) or not Economy.POLICIES.has(policy):
				return "Нет такого товара или политики"
			f["econ"]["policy"][good] = policy
			return ""
		"buy":
			var good: String = a["good"]
			if not Economy.GOODS.has(good):
				return "Нет такого товара"
			var amount: float = maxf(1.0, float(a["amount"]))
			var cost: float = amount * Economy.price(self, good)
			if f["gold"] < cost:
				return "Не хватает золота (нужно %s)" % Names.short_number(cost)
			f["gold"] -= cost
			f["econ"]["stock"][good] = float(f["econ"]["stock"][good]) + amount
			f["econ"]["manual_profit"] = float(f["econ"]["manual_profit"]) - cost
			return ""
		"sell":
			var good: String = a["good"]
			if not Economy.GOODS.has(good):
				return "Нет такого товара"
			var amount: float = minf(float(f["econ"]["stock"][good]), maxf(1.0, float(a["amount"])))
			if amount < 1.0:
				return "Склад пуст"
			var gain: float = amount * Economy.price(self, good) * Economy.SELL_DISCOUNT
			f["gold"] += gain
			f["econ"]["stock"][good] = float(f["econ"]["stock"][good]) - amount
			f["econ"]["manual_profit"] = float(f["econ"]["manual_profit"]) + gain
			return ""
		"invest":
			var amount: float = minf(f["gold"], maxf(0.0, float(a["amount"])))
			if amount < 1.0:
				return "Не хватает золота"
			var e: Dictionary = f["econ"]
			f["gold"] -= amount
			e["shares"] = float(e["shares"]) + amount / float(e["index"])
			e["invested"] = float(e["invested"]) + amount
			return ""
		"divest":
			var e: Dictionary = f["econ"]
			var value := Economy.portfolio_value(f)
			var amount: float = minf(value, maxf(0.0, float(a["amount"])))
			if amount < 1.0:
				return "На бирже у вас ничего нет"
			var shares: float = amount / float(e["index"])
			e["shares"] = maxf(0.0, float(e["shares"]) - shares)
			f["gold"] += amount
			e["invested"] = maxf(0.0, float(e["invested"]) - amount)
			_count(fid, "market_gold", int(amount))
			return ""
		"tariff":
			var level: int = clampi(int(a["level"]), 0, Economy.TARIFF_LEVELS.size() - 1)
			f["econ"]["tariff"] = level
			f["mods_dirty"] = true
			return ""
		"sanction":
			var target: int = int(a["target"])
			if target <= 0 or target >= factions.size() or target == fid or factions[target]["kind"] == Kind.CITY:
				return "Нет такой страны"
			var on: bool = bool(a["on"])
			if on == bool(f["sanctions"].get(target, false)):
				return "Уже так"
			if on:
				f["sanctions"][target] = true
				var rel: Dictionary = factions[target]["relations"]
				rel[fid] = maxf(0.0, float(rel.get(fid, Rules.RELATION_START)) - Economy.SANCTION_RELATION)
				f["trade"].erase(target)
				factions[target]["trade"].erase(fid)
				_count(fid, "sanctions")
			else:
				f["sanctions"].erase(target)
			return ""
		"autopilot":
			var task: String = a["task"]
			if not (task in BotBrain.ALL_TASKS):
				return "Нет такой задачи автопилота"
			if bool(a["on"]):
				f["autopilot"][task] = true
			else:
				f["autopilot"].erase(task)
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
