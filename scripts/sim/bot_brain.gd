extends RefCounted
## Decisions for AI players, and the autopilot that can run the human's country the same way.
## Pure functions of the world state. Every bot has a persona (Rules.PERSONAS) that scales its appetite.

const Rules := preload("res://scripts/sim/rules.gd")

const ALL_TASKS := ["people", "staff", "laws", "build", "research", "diplomacy", "expand", "war"]


static func think(world, fid: int) -> void:
	var f: Dictionary = world.factions[fid]
	if f["border"].is_empty():
		return
	var p: Dictionary = Rules.PERSONAS.get(f["persona"], Rules.PERSONAS["trader"])
	manage_people(world, fid)
	manage_staff(world, fid, p)
	manage_laws(world, fid, p)
	manage_build(world, fid, p)
	manage_research(world, fid, p)
	manage_diplomacy(world, fid, p)
	if manage_war(world, fid, p):
		return
	manage_expand(world, fid, p)


## The human's autopilot: only the enabled tasks, with a calm persona.
static func autopilot(world, fid: int, tasks: Dictionary) -> void:
	var f: Dictionary = world.factions[fid]
	if f["border"].is_empty() or not f["alive"]:
		return
	var p: Dictionary = Rules.PERSONAS["trader"]
	if tasks.get("people", false):
		manage_people(world, fid)
	if tasks.get("staff", false):
		manage_staff(world, fid, p)
	if tasks.get("laws", false):
		manage_laws(world, fid, p)
	if tasks.get("build", false):
		manage_build(world, fid, p)
	if tasks.get("research", false):
		manage_research(world, fid, p)
	if tasks.get("diplomacy", false):
		manage_diplomacy(world, fid, p)
	if tasks.get("war", false) and manage_war(world, fid, p):
		return
	if tasks.get("expand", false):
		manage_expand(world, fid, p)


# ------------------------------------------------------------------ tasks

static func manage_people(world, fid: int) -> void:
	var f: Dictionary = world.factions[fid]
	if f["approval"] < Rules.BOT_PROPAGANDA_APPROVAL and f["gold"] >= Rules.PROPAGANDA_COST * 2 and world.decree_cooldown(fid, "propaganda") == 0.0:
		world.apply({"type": "decree", "player": fid, "kind": "propaganda"})
	if f["approval"] < 35.0 and f["tax"] > 0:
		world.apply({"type": "tax", "player": fid, "level": f["tax"] - 1})
	elif f["approval"] > 75.0 and f["tax"] < 2:
		world.apply({"type": "tax", "player": fid, "level": f["tax"] + 1})
	if not f["event"].is_empty() and fid == world.human:
		world.apply({"type": "event_choice", "player": fid, "choice": 0})


static func manage_staff(world, fid: int, p: Dictionary) -> void:
	var f: Dictionary = world.factions[fid]
	if f["cells"] > 500 and not world.has_minister(fid, "finance") and f["gold"] >= Rules.MINISTERS["finance"]["fee"] * 3:
		world.apply({"type": "hire", "player": fid, "minister": "finance"})
	elif f["cells"] > 1500 and not world.has_minister(fid, "general") and f["gold"] >= Rules.MINISTERS["general"]["fee"] * 3:
		world.apply({"type": "hire", "player": fid, "minister": "general"})
	elif f["cells"] > 1200 and world.rng.randf() < 0.1 * p["build"]:
		var mkey: String = Rules.MINISTER_ORDER[world.rng.randi_range(0, Rules.MINISTER_ORDER.size() - 1)]
		var m: Dictionary = Rules.MINISTERS[mkey]
		if not world.has_minister(fid, mkey) and f["gold"] >= m["fee"] * 4 and world.salaries_of(fid) + m["salary"] < world.gold_rate_of(fid) * 0.3:
			world.apply({"type": "hire", "player": fid, "minister": mkey})


static func manage_laws(world, fid: int, p: Dictionary) -> void:
	var f: Dictionary = world.factions[fid]
	if f["cells"] > 1000 and world.rng.randf() < 0.15 * p["build"]:
		var bkey: String = Rules.BILL_ORDER[world.rng.randi_range(0, Rules.BILL_ORDER.size() - 1)]
		if not world.has_bill(fid, bkey) and world.bill_blocked(fid, bkey) == "" and world.bill_support(fid, bkey) >= Rules.BILL_MAJORITY and f["gold"] >= world.bill_cost(fid, bkey) * 2:
			world.apply({"type": "bill", "player": fid, "bill": bkey})
	if f["cells"] > 1500 and world.rng.randf() < 0.1 * p["build"] and world.active_projects(fid) < 2:
		var pkey: String = Rules.PROJECT_ORDER[world.rng.randi_range(0, Rules.PROJECT_ORDER.size() - 1)]
		if f["gold"] >= Rules.PROJECTS[pkey]["cost"] * 2.5:
			world.apply({"type": "project", "player": fid, "project": pkey})
	if f["cells"] > 2000 and world.rng.randf() < 0.03 and f["gold"] >= Rules.REFORM_COST * 5 and f["approval"] > 60.0:
		var axis: String = Rules.REFORM_ORDER[world.rng.randi_range(0, Rules.REFORM_ORDER.size() - 1)]
		var options: Array = Rules.REFORMS[axis]["options"].keys()
		world.apply({"type": "reform", "player": fid, "axis": axis, "option": options[world.rng.randi_range(0, options.size() - 1)]})
	if f["cells"] > 2500 and world.rng.randf() < 0.04 * p["build"]:
		var wkey: String = Rules.WONDER_ORDER[world.rng.randi_range(0, Rules.WONDER_ORDER.size() - 1)]
		if not world.wonders.has(wkey) and f["gold"] >= world.building_cost(wkey, fid) * 2:
			var cell := _random_border(world, f["border"])
			if not Rules.WONDERS[wkey]["coast"] or world.map.is_coast(cell):
				world.apply({"type": "build", "player": fid, "kind": wkey, "cell": cell})
	if f["cells"] > 800 and world.rng.randf() < 0.05 * p["build"] and f["gold"] > 8000.0:
		var item: String = Rules.BUDGET_ORDER[world.rng.randi_range(0, Rules.BUDGET_ORDER.size() - 1)]
		var level: int = int(f["budget"].get(item, 0))
		if level < Rules.BUDGET_MAX and world.budget_cost(fid) < world.gold_rate_of(fid) * 0.25:
			world.apply({"type": "budget", "player": fid, "item": item, "level": level + 1})


static func manage_build(world, fid: int, p: Dictionary) -> void:
	var f: Dictionary = world.factions[fid]
	var map = world.map
	var border: Dictionary = f["border"]
	var contacts: Dictionary = world.contacts_of(fid)
	if f["cells"] > 800 and world.rng.randf() < 0.25 * p["build"]:
		var key: String = Rules.BUILDING_ORDER[world.rng.randi_range(0, Rules.BUILDING_ORDER.size() - 1)]
		if int(f["extra"].get(key, 0)) < 2 and f["gold"] >= world.building_cost(key, fid) * 2:
			var cell := _random_border(world, border)
			if not Rules.BUILDINGS[key]["coast"] or map.is_coast(cell):
				world.apply({"type": "build", "player": fid, "kind": key, "cell": cell})
	var wants_bunker := false
	for o in contacts:
		if o != 0 and world.tech_level(o, "nuclear") > 0:
			wants_bunker = true
	if wants_bunker and f["bunkers"] == 0 and f["gold"] >= world.building_cost("bunker", fid):
		world.apply({"type": "build", "player": fid, "kind": "bunker", "cell": _random_border(world, border)})
	elif f["gold"] >= world.building_cost("city", fid) and f["cities"] < 1 + f["cells"] / 2500:
		world.apply({"type": "build", "player": fid, "kind": "city", "cell": _random_border(world, border)})
	elif f["gold"] >= world.building_cost("port", fid) and f["ports"] == 0:
		for i in border:
			if map.is_coast(i):
				world.apply({"type": "build", "player": fid, "kind": "port", "cell": i})
				break
	elif f["gold"] >= world.building_cost("market", fid) and f["markets"] < f["cities"]:
		world.apply({"type": "build", "player": fid, "kind": "market", "cell": _random_border(world, border)})
	elif f["gold"] >= world.building_cost("barracks", fid) and f["barracks"] < f["cities"] and f["cells"] > 400:
		world.apply({"type": "build", "player": fid, "kind": "barracks", "cell": _random_border(world, border)})
	elif f["gold"] >= world.building_cost("defense", fid) and f["defense"] < int(p["defense_max"]) and f["cells"] > 300:
		world.apply({"type": "build", "player": fid, "kind": "defense", "cell": _random_border(world, border)})


static func manage_research(world, fid: int, p: Dictionary) -> void:
	var f: Dictionary = world.factions[fid]
	if f["gold"] < 3000.0:
		return
	var order: Array = Rules.TECH_ORDER + Rules.EXTRA_TECH_ORDER
	for key in order:
		if (key == "nuclear" or key == "rockets") and (f["cells"] < 3000 or p["nuke"] < 0.4):
			continue
		var cost: int = world.tech_cost(fid, key)
		if cost > 0 and f["gold"] >= cost * 1.5:
			if world.apply({"type": "research", "player": fid, "tech": key})["ok"]:
				break


static func manage_diplomacy(world, fid: int, p: Dictionary) -> void:
	var f: Dictionary = world.factions[fid]
	if f["cells"] < 600 or world.rng.randf() > 0.15:
		return
	var contacts: Dictionary = world.contacts_of(fid)
	# trade with friendly neighbours, gifts to the strongest one, pacts when weak
	var strongest := 0
	var strongest_troops := 0.0
	for o in contacts:
		if o == 0 or world.factions[o]["kind"] == world.Kind.CITY or not world.factions[o]["alive"]:
			continue
		if world.factions[o]["troops"] > strongest_troops:
			strongest_troops = world.factions[o]["troops"]
			strongest = o
		if world.relation_of(o, fid) >= Rules.TRADE_MIN_RELATION and not world.trade_active(fid, o) and f["gold"] >= world.trade_cost(fid, o) * 3:
			world.apply({"type": "trade_deal", "player": fid, "target": o})
			return
	if strongest != 0 and strongest_troops > f["troops"] * 1.5:
		if world.relation_of(strongest, fid) >= Rules.PACT_MIN_RELATION and not world.pact_active(fid, strongest) and f["gold"] >= world.pact_cost(fid, strongest) * 2:
			world.apply({"type": "pact", "player": fid, "target": strongest})
		elif f["gold"] >= world.gift_cost(fid, strongest) * 3:
			world.apply({"type": "gift", "player": fid, "target": strongest})
	elif p["nuke"] >= 1.5 and strongest != 0 and f["gold"] >= Rules.SPY_OPS["sabotage"]["cost"] * 3 and world.rng.randf() < 0.3:
		world.apply({"type": "spy", "player": fid, "target": strongest, "op": "sabotage"})


## Nukes, retaliation for us and our allies. Returns true when an attack was launched.
static func manage_war(world, fid: int, p: Dictionary) -> bool:
	var f: Dictionary = world.factions[fid]
	var cap: float = world.max_troops_of(fid)
	var share: float = f["troops"] / maxf(1.0, cap)
	var contacts: Dictionary = world.contacts_of(fid)
	var grace: bool = world.seconds() < world.grace_seconds()
	if world.tech_level(fid, "nuclear") > 0 and f["gold"] >= Rules.NUKE_COST * 1.5 and world.rng.randf() < Rules.BOT_NUKE_CHANCE * p["nuke"]:
		var victim := 0
		var victim_cells := 400
		for o in contacts:
			if o == 0 or (grace and o == world.human) or world.pact_active(fid, o):
				continue
			if world.factions[o]["cells"] > victim_cells:
				victim_cells = world.factions[o]["cells"]
				victim = o
		if victim != 0:
			world.apply({"type": "nuke", "player": fid, "cell": world.centroid_cell(victim), "mega": false})
	if share >= Rules.BOT_RETALIATE_SHARE * p["retaliate"]:
		var victims: Array = [fid]
		for ally in f["allies"]:
			if f["allies"][ally] and world.factions[ally]["alive"]:
				victims.append(ally)
		for v in victims:
			for a in world.incoming_attacks(v):
				var enemy: int = a["attacker"]
				if enemy == fid or (enemy == world.human and grace):
					continue
				if contacts.has(enemy) and not world.has_attack(fid, enemy) and not world.pact_active(fid, enemy):
					world.launch_attack(fid, enemy, Rules.BOT_RATIO_RETALIATE)
					return true
	return false


## Empty land first, then naval landings, then the cheapest neighbour.
static func manage_expand(world, fid: int, p: Dictionary) -> void:
	var f: Dictionary = world.factions[fid]
	var cap: float = world.max_troops_of(fid)
	var share: float = f["troops"] / maxf(1.0, cap)
	var contacts: Dictionary = world.contacts_of(fid)
	var grace: bool = world.seconds() < world.grace_seconds()
	if contacts.has(0):
		if share >= Rules.BOT_MIN_TROOPS_SHARE and not world.has_attack(fid, 0):
			world.launch_attack(fid, 0, Rules.BOT_RATIO_EMPTY)
			return
	elif f["ports"] > 0 and share >= Rules.BOT_MIN_TROOPS_SHARE and world.ships_of(fid).is_empty() and world.rng.randf() < Rules.BOT_NAVAL_CHANCE * p["naval"]:
		var landing := _naval_target(world, fid)
		if landing != -1:
			world.launch_attack(fid, world.owner[landing], Rules.BOT_RATIO_EMPTY, landing)
			return
	if share < p["enemy_share"]:
		return
	var best := 0
	var best_score := INF
	for o in contacts:
		if o == 0 or (grace and o == world.human) or world.has_attack(fid, o) or world.pact_active(fid, o):
			continue
		var d: Dictionary = world.factions[o]
		var score: float = (1.0 + d["troops"] / maxf(1.0, float(d["cells"]))) * (1.0 + d["defense"] * Rules.DEFENSE_BONUS)
		if d["kind"] == world.Kind.CITY:
			score *= 0.8
		else:
			score *= maxf(0.5, 1.0 + Rules.RELATION_ATTACK_SCALE * (world.relation_of(fid, o) - Rules.RELATION_START) / 50.0)
		var diplomacy: float = world.mod(o, "diplomacy")
		if diplomacy > 0.0:
			score *= 1.0 + (Rules.DIPLOMAT_RATIO - 1.0) * diplomacy
		score *= 1.0 + world.rng.randf() * 0.2
		if score < best_score:
			best_score = score
			best = o
	if best == 0:
		return
	var amount: float = f["troops"] * p["ratio"]
	var d: Dictionary = world.factions[best]
	if amount >= d["troops"] * 0.35 or contacts[best] >= 40:
		world.launch_attack(fid, best, p["ratio"])


static func _random_border(world, border: Dictionary) -> int:
	var keys := border.keys()
	return keys[world.rng.randi_range(0, keys.size() - 1)]


## A free (or weakly held) beach within reach of this faction's coast.
static func _naval_target(world, fid: int) -> int:
	var map = world.map
	var center: Vector2 = world.centroid(fid)
	for attempt in 40:
		var c: int = map.coast_cells[world.rng.randi_range(0, map.coast_cells.size() - 1)]
		var o: int = world.owner[c]
		if o == fid:
			continue
		if o != 0 and (world.factions[o]["kind"] != world.Kind.CITY or (world.factions[o]["troops"] > world.factions[fid]["troops"] * 0.3)):
			continue
		if o != 0 and world.pact_active(fid, o):
			continue
		if Vector2(map.cell(c)).distance_to(center) > Rules.NAVAL_REACH:
			continue
		return c
	return -1
