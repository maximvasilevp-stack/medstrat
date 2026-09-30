extends SceneTree
## Headless test runner: godot --headless --path . -s tests/run_tests.gd

const MapData := preload("res://scripts/map/map_data.gd")
const World := preload("res://scripts/sim/world.gd")
const Rules := preload("res://scripts/sim/rules.gd")
const Names := preload("res://scripts/sim/names.gd")

var passed := 0
var failed := 0
var finished := false
var map


func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: " + msg)


func _init() -> void:
	map = MapData.new()
	test_map()
	test_spawn_phase()
	test_spawn()
	test_growth()
	test_attack_empty()
	test_heat()
	test_cancel()
	test_attack_enemy()
	test_naval()
	test_nuke()
	test_buildings()
	test_tech_and_new_buildings()
	test_admin()
	test_politics()
	test_government()
	test_content()
	test_content_pass_two()
	test_reforms_projects_diplomacy()
	test_no_clock()
	test_ranking_and_names()
	test_determinism()
	test_soak()
	print("tests: %d passed, %d failed" % [passed, failed])
	finished = true
	quit(1 if failed > 0 else 0)


func _process(_delta: float) -> bool:
	if not finished:
		printerr("test runner aborted by a script error")
		quit(2)
	return true


func _quiet(seed: int) -> Variant:
	var w = World.new(map, seed)
	w.bots_enabled = false
	w.auto_spawn_human()
	return w


func _empty_neighbour(w, fid: int) -> int:
	for i in w.factions[fid]["border"]:
		for n in map.neighbors(i):
			if w.owner[n] == 0 and map.is_land(n):
				return n
	return -1


func _first_bot(w, after: int) -> int:
	for id in range(after + 1, w.factions.size()):
		if w.factions[id]["kind"] == w.Kind.BOT:
			return id
	return -1


func _first_city_state(w) -> int:
	for id in range(1, w.factions.size()):
		if w.factions[id]["kind"] == w.Kind.CITY:
			return id
	return 0


func test_map() -> void:
	check(map.width == 640 and map.height == 768, "map size 640x768")
	check(map.terrain.size() == map.size() and map.coast.size() == map.size(), "data sizes")
	check(map.land_cells.size() == map.land_total, "land cell list matches land_total")
	check(map.coast_cells.size() > 5000, "coast cell list (%d)" % map.coast_cells.size())
	check(map.borders.size() == map.size(), "borders layer loaded")
	check(map.cities.size() >= 100, "real cities loaded (%d)" % map.cities.size())
	for c in map.cities:
		check(map.is_land(c["cell"]), "city %s is on land" % c["name"])
	var forest := 0
	for i in range(0, map.size(), 97):
		if map.terrain[i] == map.FOREST:
			forest += 1
			check(map.is_land(i), "forest is land")
	check(forest > 100, "forests exist")
	var rome: int = map.index(Vector2i(int((12.5 + 11.0) * cos(deg_to_rad(49.0)) / (44.0 / 768.0)), int((71.0 - 41.9) / (44.0 / 768.0))))
	check(map.is_land(rome), "Rome is land")
	check(not map.is_land(0) and map.is_sea(0), "top-left corner is sea")
	for k in 200:
		var i: int = map.coast_cells[k * 37 % map.coast_cells.size()]
		check(map.is_land(i) and map.is_coast(i), "coast cells are land and flagged")


func test_spawn_phase() -> void:
	var w = World.new(map, 4)
	w.bots_enabled = false
	check(w.phase == w.Phase.SPAWN, "world starts in the spawn phase")
	check(w.factions[1]["cells"] == 0, "human has no land before choosing")
	var troops0: float = w.factions[2]["troops"]
	for i in 5:
		w.step()
	check(is_equal_approx(w.factions[2]["troops"], troops0), "nothing grows while waiting for the spawn")
	check(w.spawn_human(0) != "", "no spawn on water")
	check(w.spawn_human(w.factions[2]["spawn"]) != "", "no spawn on occupied land")
	check(w.apply({"type": "attack", "player": 1, "cell": map.land_cells[0], "ratio": 0.5})["reason"].begins_with("Сначала"), "no attacks before spawning")
	var free := -1
	for k in 500:
		var c: int = map.land_cells[(k * 7919) % map.land_cells.size()]
		if w._blob_ok(c, Rules.SPAWN_RADIUS, Rules.MIN_SPAWN_DISTANCE * 0.6):
			free = c
			break
	check(free != -1 and w.apply({"type": "spawn", "player": 1, "cell": free})["ok"], "spawn on free land accepted")
	check(w.phase == w.Phase.PLAY and w.factions[1]["cells"] > 40, "match started with a starting blob")
	check(is_equal_approx(w.factions[1]["gold"], float(Rules.START_GOLD - Rules.SPAWN_COST)), "spawning costs gold")
	check(is_equal_approx(w.seconds(), 0.0), "match clock starts at zero")
	var w2 = World.new(map, 4)
	w2.bots_enabled = false
	w2.spawn_ticks_left = 3
	for i in 3:
		w2.step()
	check(w2.phase == w2.Phase.PLAY and w2.factions[1]["cells"] > 0, "countdown places the human automatically")


func test_spawn() -> void:
	var w = _quiet(5)
	check(w.factions.size() == 1 + 1 + Rules.NUM_BOTS + Rules.NUM_CITY_STATES, "faction count")
	var total := 0
	for id in range(1, w.factions.size()):
		var f: Dictionary = w.factions[id]
		check(f["cells"] > 0 and f["alive"], "faction %s has land" % f["name"])
		total += f["cells"]
	var owned := 0
	for i in w.owner.size():
		if w.owner[i] != 0:
			owned += 1
			if owned < 50:
				check(map.is_land(i), "owned cells are land")
	check(owned == total, "cell counters match the owner map")
	check(is_equal_approx(w.factions[1]["troops"], float(Rules.START_TROOPS)), "human starts with START_TROOPS")
	var border: Dictionary = w.factions[1]["border"]
	check(border.size() > 0, "human has border cells")
	for i in border:
		var ok := false
		for n in map.neighbors(i):
			if map.is_land(n) and w.owner[n] != 1:
				ok = true
		check(ok, "border cell touches foreign land")


func test_growth() -> void:
	var w = _quiet(6)
	w.factions[1]["next_event"] = 1 << 40   # no random events: they may add troops above the cap
	var t0: float = w.factions[1]["troops"]
	var g0: float = w.factions[1]["gold"]
	for i in 10:
		w.step()
	check(w.factions[1]["troops"] > t0, "troops grow")
	check(w.factions[1]["gold"] > g0, "gold grows")
	for i in 5000:
		w.step()
	check(w.factions[1]["troops"] <= w.max_troops_of(1) + 0.001, "troops capped at max")
	var cs := _first_city_state(w)
	check(w.factions[cs]["troops"] <= w.factions[cs]["base_troops"] * Rules.CITY_STATE_MAX_MULT + 0.001, "city-state troops capped")


func test_attack_empty() -> void:
	var w = _quiet(7)
	var target := _empty_neighbour(w, 1)
	check(target != -1, "human has empty land next door")
	var cells0: int = w.factions[1]["cells"]
	var troops0: float = w.factions[1]["troops"]
	check(not w.apply({"type": "attack", "player": 1, "cell": 0, "ratio": 0.5})["ok"], "attack on water rejected")
	check(not w.apply({"type": "attack", "player": 1, "cell": w.factions[1]["spawn"], "ratio": 0.5})["ok"], "attack on own land rejected")
	var far := -1
	for id in range(1, w.factions.size()):
		if w.factions[id]["kind"] == w.Kind.CITY and not w.contacts_of(id).has(1):
			far = w.factions[id]["spawn"]
			break
	check(far != -1 and not w.apply({"type": "attack", "player": 1, "cell": far, "ratio": 0.5})["ok"], "attack on a faction without a shared border rejected")
	check(w.apply({"type": "attack", "player": 1, "cell": target, "ratio": 0.5})["ok"], "attack on empty land accepted")
	check(w.attacks.size() == 1, "one active attack")
	check(w.factions[1]["troops"] < troops0 * 0.51, "troops committed to the attack")
	for i in 150:
		w.step()
	check(w.factions[1]["cells"] > cells0 + 20, "territory expanded (%d -> %d)" % [cells0, w.factions[1]["cells"]])
	check(w.attacks.is_empty(), "attack finished when troops ran out")
	check(w.factions[1]["troops"] >= 0.0, "troops never negative")


func test_heat() -> void:
	var w = _quiet(21)
	w.apply({"type": "attack", "player": 1, "cell": _empty_neighbour(w, 1), "ratio": 0.5})
	w.step()
	var hot := -1
	for i in w.owner.size():
		if w.heat[i] == 255:
			hot = i
			break
	check(hot != -1 and w.owner[hot] == 1, "a freshly captured cell glows at full heat")
	check(w.heat_dirty, "heat texture flagged dirty")
	for i in 200:
		w.step()
	check(w.attacks.is_empty(), "attack over")
	for i in Rules.HEAT_TICKS + 2:
		w.step()
	check(w.heat[hot] == 0, "heat fades to zero")


func test_cancel() -> void:
	var w = _quiet(22)
	var troops0: float = w.factions[1]["troops"]
	check(w.apply({"type": "attack", "player": 1, "cell": _empty_neighbour(w, 1), "ratio": 0.4})["ok"], "attack launched")
	check(w.factions[1]["troops"] < troops0, "troops left home")
	check(not w.apply({"type": "cancel", "player": 1, "target": 5})["ok"], "cancelling a missing attack is rejected")
	check(w.apply({"type": "cancel", "player": 1, "target": 0})["ok"], "attack cancelled")
	check(is_equal_approx(w.factions[1]["troops"], troops0) and w.attacks.is_empty(), "troops came back home")


func test_attack_enemy() -> void:
	var w = _quiet(8)
	var cs := _first_city_state(w)
	var bridge := -1
	for i in w.factions[cs]["border"]:
		for n in map.neighbors(i):
			if w.owner[n] == 0 and map.is_land(n):
				bridge = n
				break
		if bridge != -1:
			break
	check(bridge != -1, "city-state has free land next to it")
	w._set_owner(bridge, 1)
	w.factions[1]["troops"] = 1000000.0
	var cs_cells0: int = w.factions[cs]["cells"]
	var cs_troops0: float = w.factions[cs]["troops"]
	var name: String = w.factions[cs]["name"]
	var eliminated := {"by": -1}
	w.faction_eliminated.connect(func(fid, by): if fid == cs: eliminated["by"] = by)
	check(w.apply({"type": "attack", "player": 1, "cell": w.factions[cs]["spawn"], "ratio": 0.5})["ok"], "attack on %s accepted" % name)
	w.step()
	check(w.factions[cs]["cells"] < cs_cells0, "city-state loses cells")
	check(w.factions[cs]["troops"] < cs_troops0, "defenders lose troops")
	for i in 400:
		w.step()
	check(not w.factions[cs]["alive"] and w.factions[cs]["cells"] == 0, "city-state eliminated")
	check(eliminated["by"] == 1, "elimination signal names the attacker")
	check(w.attacks.is_empty(), "attack ended after elimination")
	check(not w.apply({"type": "attack", "player": cs, "cell": bridge, "ratio": 0.5})["ok"], "dead faction cannot act")


func test_naval() -> void:
	var w = null
	for seed in range(12, 60):
		var cand = _quiet(seed)
		var has_coast := false
		for i in cand.factions[1]["border"]:
			if map.is_coast(i):
				has_coast = true
				break
		if has_coast:
			w = cand
			break
	check(w != null, "found a seed where the human spawns on a coast")
	if w == null:
		return
	var f: Dictionary = w.factions[1]
	var center: Vector2 = w.centroid(1)
	var target := -1
	for k in map.coast_cells.size():
		var c: int = map.coast_cells[(k * 104729) % map.coast_cells.size()]
		var d := Vector2(map.cell(c)).distance_to(center)
		if w.owner[c] == 0 and d > 25.0 and d < Rules.NAVAL_REACH * 0.8:
			target = c
			break
	check(target != -1, "found a free beach within reach")
	f["troops"] = 3000.0
	var r: Dictionary = w.apply({"type": "attack", "player": 1, "cell": target, "ratio": 0.5})
	check(r["ok"] and w.ships.is_empty() and w.attacks.size() == 1, "without a port a far beach click expands at home instead")
	w.apply({"type": "cancel", "player": 1, "target": 0})
	f["ports"] = 1
	check(w.apply({"type": "attack", "player": 1, "cell": target, "ratio": 0.5})["ok"], "landing with a port accepted")
	check(w.ships.size() == 1 and w.attacks.is_empty(), "a ship is under way, no land attack yet")
	if w.ships.is_empty():
		return
	var total: int = w.ships[0]["total"]
	for i in total + 1:
		w.step()
	check(w.ships.is_empty() and w.attacks.size() == 1, "ship landed and opened an attack")
	for i in 30:
		w.step()
	check(w.owner[target] == 1, "the beach was captured")


func test_nuke() -> void:
	var w = _quiet(13)
	var f: Dictionary = w.factions[1]
	var cs := _first_city_state(w)
	var center: int = w.centroid_cell(cs)
	f["gold"] = 0.0
	check(not w.apply({"type": "nuke", "player": 1, "cell": center, "mega": false})["ok"], "nuke needs gold")
	f["gold"] = 1000000.0
	check(not w.apply({"type": "nuke", "player": 1, "cell": 0, "mega": false})["ok"], "nuke needs a land target")
	var cells0: int = w.factions[cs]["cells"]
	var troops0: float = w.factions[cs]["troops"]
	var boom := {"n": 0}
	w.nuke_detonated.connect(func(_c, _r): boom["n"] += 1)
	check(not w.apply({"type": "nuke", "player": 1, "cell": center, "mega": false})["ok"], "nuke needs the nuclear technology")
	f["tech"]["nuclear"] = 1
	check(not w.apply({"type": "nuke", "player": 1, "cell": center, "mega": true})["ok"], "mega nuke needs rockets")
	check(w.apply({"type": "nuke", "player": 1, "cell": center, "mega": false})["ok"], "nuke launched")
	check(w.missiles.size() == 1 and is_equal_approx(f["gold"], 1000000.0 - Rules.NUKE_COST), "missile in flight, gold paid")
	for i in Rules.NUKE_FLIGHT_TICKS:
		w.step()
	check(w.missiles.is_empty() and boom["n"] == 1, "missile detonated")
	check(w.factions[cs]["cells"] < cells0, "city-state lost land (%d -> %d)" % [cells0, w.factions[cs]["cells"]])
	check(w.factions[cs]["troops"] < troops0, "city-state lost troops")
	check(w.scorched.has(center) and w.scorch[center] > 200, "ground is scorched")
	var plain := Rules.CAPTURE_COST_EMPTY * Rules.empire_mult(f["cells"]) * Rules.terrain_mult(map.terrain[center])
	check(w.capture_cost(1, 0, center) > plain * 1.5, "scorched land is dearer to take")
	for i in Rules.SCORCH_TICKS + 10:
		w.step()
	check(not w.scorched.has(center) and w.scorch[center] == 0, "scorch heals")


func test_buildings() -> void:
	var w = _quiet(9)
	var f: Dictionary = w.factions[1]
	var spawn: int = f["spawn"]
	f["gold"] = 0.0
	var r: Dictionary = w.apply({"type": "build", "player": 1, "kind": "city", "cell": spawn})
	check(not r["ok"] and r["reason"].begins_with("Не хватает"), "city needs gold")
	f["gold"] = 100000.0
	check(not w.apply({"type": "build", "player": 1, "kind": "city", "cell": 0})["ok"], "no building on foreign cell")
	var cap0: float = w.max_troops_of(1)
	check(w.apply({"type": "build", "player": 1, "kind": "city", "cell": spawn})["ok"], "city built")
	check(w.factions[1]["cities"] == 1 and w.max_troops_of(1) > cap0, "city raises the troop cap")
	check(is_equal_approx(f["gold"], 100000.0 - Rules.COST_CITY), "gold paid")
	check(w.building_cost("city", 1) > Rules.COST_CITY, "next city costs more")
	check(not w.apply({"type": "build", "player": 1, "kind": "port", "cell": spawn})["ok"], "one building per cell")
	var inland := -1
	for i in f["border"]:
		if not map.is_coast(i):
			inland = i
			break
	if inland != -1:
		check(not w.apply({"type": "build", "player": 1, "kind": "port", "cell": inland})["ok"], "port needs a coast")
		var cost0: float = w.capture_cost(2, 1, spawn)
		check(w.apply({"type": "build", "player": 1, "kind": "defense", "cell": inland})["ok"], "defense placed")
		check(w.capture_cost(2, 1, spawn) > cost0, "defense raises capture cost")
	var removed := {"n": 0}
	w.building_removed.connect(func(_c): removed["n"] += 1)
	w._set_owner(spawn, 0)
	check(w.factions[1]["cities"] == 0 and removed["n"] == 1, "captured cell loses its building")


func test_tech_and_new_buildings() -> void:
	var w = _quiet(31)
	var f: Dictionary = w.factions[1]
	var spawn: int = f["spawn"]
	f["gold"] = 0.0
	check(not w.apply({"type": "research", "player": 1, "tech": "trade"})["ok"], "research needs gold")
	check(not w.apply({"type": "research", "player": 1, "tech": "warp"})["ok"], "unknown tech rejected")
	f["gold"] = 1000000.0
	var gold0: float = w.gold_rate_of(1)
	check(w.apply({"type": "research", "player": 1, "tech": "trade"})["ok"], "trade researched")
	check(w.tech_level(1, "trade") == 1 and w.gold_rate_of(1) > gold0 * 1.2, "trade raises the gold rate")
	check(is_equal_approx(f["gold"], 1000000.0 - Rules.TECHS["trade"]["costs"][0]), "research paid")
	check(w.tech_cost(1, "trade") == Rules.TECHS["trade"]["costs"][1], "next level costs more")
	var r: Dictionary = w.apply({"type": "research", "player": 1, "tech": "rockets"})
	check(not r["ok"] and r["reason"].contains("Ядерная"), "rockets need the nuclear programme")
	check(w.apply({"type": "research", "player": 1, "tech": "nuclear"})["ok"] and w.apply({"type": "research", "player": 1, "tech": "nuclear"})["reason"].begins_with("Уже"), "max level enforced")
	var free := _empty_neighbour(w, 1)
	var cost0: float = w.capture_cost(1, 0, free)
	w.apply({"type": "research", "player": 1, "tech": "logistics"})
	check(w.capture_cost(1, 0, free) < cost0, "logistics makes expansion cheaper")
	var def0: float = w.capture_cost(2, 1, spawn)
	w.apply({"type": "research", "player": 1, "tech": "fortification"})
	check(w.capture_cost(2, 1, spawn) > def0, "fortification makes the player harder to take")
	# new buildings
	var rate0: float = w.gold_rate_of(1)
	check(w.apply({"type": "build", "player": 1, "kind": "market", "cell": spawn})["ok"], "market built")
	check(w.gold_rate_of(1) > rate0 + Rules.MARKET_GOLD * 0.99, "market adds gold")
	var cap0: float = w.max_troops_of(1)
	var cells: Array = f["border"].keys()
	check(w.apply({"type": "build", "player": 1, "kind": "barracks", "cell": cells[0]})["ok"], "barracks built")
	check(w.max_troops_of(1) >= cap0 + Rules.BARRACKS_CAP, "barracks raise the cap")
	check(w.apply({"type": "build", "player": 1, "kind": "bunker", "cell": cells[1]})["ok"], "bunker built")
	check(f["bunkers"] == 1 and w.bunker_near(spawn, 2) == 1, "bunker guards its surroundings")
	# an enemy nuke on the bunker area is intercepted
	var enemy := 2
	w.factions[enemy]["gold"] = 1000000.0
	w.factions[enemy]["tech"]["nuclear"] = 1
	var hits := {"boom": 0, "shield": 0}
	w.nuke_detonated.connect(func(_c, _r): hits["boom"] += 1)
	w.nuke_intercepted.connect(func(_c, _by): hits["shield"] += 1)
	var mine0: int = f["cells"]
	check(w.apply({"type": "nuke", "player": enemy, "cell": spawn, "mega": false})["ok"], "enemy nuke launched")
	for i in Rules.NUKE_FLIGHT_TICKS + 1:
		w.step()
	check(hits["shield"] == 1 and hits["boom"] == 0, "bunker intercepted the nuke")
	check(f["cells"] == mine0, "no land lost to an intercepted nuke")


func test_admin() -> void:
	var w = _quiet(32)
	var f: Dictionary = w.factions[1]
	var r: Dictionary = w.apply({"type": "admin", "player": 1, "code": "123"})
	check(not r["ok"] and not f["admin"], "wrong code rejected")
	check(w.apply({"type": "admin", "player": 1, "code": "666"})["ok"] and f["admin"], "code 666 enables admin mode")
	check(f["gold"] > 1e8 and f["troops"] >= 1e6, "admin has endless resources")
	check(w.tech_level(1, "rockets") == 1 and w.tech_level(1, "trade") == 3, "admin gets every technology")
	w.apply({"type": "build", "player": 1, "kind": "city", "cell": f["spawn"]})
	w.step()
	check(f["gold"] > 1e8, "gold refills every tick")


func test_politics() -> void:
	var w = _quiet(41)
	var f: Dictionary = w.factions[1]
	check(is_equal_approx(f["approval"], Rules.APPROVAL_START), "approval starts at the base value")
	# taxes pull approval down and raise gold
	var rate1: float = w.gold_rate_of(1)
	check(w.apply({"type": "tax", "player": 1, "level": 3})["ok"] and f["tax"] == 3, "tax level set")
	check(w.gold_rate_of(1) > rate1, "higher taxes bring more gold")
	for i in 300:
		w.step()
	check(f["approval"] < Rules.APPROVAL_START, "high taxes erode approval (%.1f)" % f["approval"])
	w.apply({"type": "tax", "player": 1, "level": 0})
	var a0: float = f["approval"]
	for i in 300:
		w.step()
	check(f["approval"] > a0, "no taxes restore approval")
	# growth depends on approval
	f["approval"] = 100.0
	var g_high: float = w.growth_of(1)
	f["approval"] = 0.0
	check(w.growth_of(1) < g_high, "unhappy people grow the army slower")
	# unrest below the threshold
	f["approval"] = 10.0
	var cells0: int = f["cells"]
	var events := {"unrest": 0, "elections": [], "offered": 0, "resolved": 0}
	w.unrest.connect(func(fid, lost): if fid == 1: events["unrest"] += lost)
	w.election_result.connect(func(fid, won, _a): if fid == 1: events["elections"].append(won))
	w.event_offered.connect(func(fid, _e): if fid == 1: events["offered"] += 1)
	w.event_resolved.connect(func(fid, _t): if fid == 1: events["resolved"] += 1)
	for i in Rules.UNREST_PERIOD_TICKS * 2 + 2:
		w.step()
		f["approval"] = 10.0
	check(events["unrest"] > 0 and f["cells"] < cells0, "unrest costs land")
	# elections
	f["approval"] = 30.0
	f["next_election"] = w.tick + 1
	for i in 12:
		w.step()
	check(events["elections"] == [false] and f["elections_lost"] == 1 and w.tick < f["loss_until"], "low approval loses the election")
	check(w.approval_factor(1) < 1.0, "lost election halves growth")
	f["approval"] = 80.0
	f["next_election"] = w.tick + 1
	for i in 12:
		w.step()
	check(events["elections"] == [false, true] and f["elections_won"] == 1, "high approval wins the election")
	# decrees
	f["gold"] = 0.0
	check(not w.apply({"type": "decree", "player": 1, "kind": "propaganda"})["ok"], "propaganda needs gold")
	f["gold"] = 10000.0
	var ap: float = f["approval"]
	check(w.apply({"type": "decree", "player": 1, "kind": "propaganda"})["ok"] and f["approval"] > ap, "propaganda raises approval")
	check(not w.apply({"type": "decree", "player": 1, "kind": "propaganda"})["ok"], "propaganda has a cooldown")
	var t0: float = f["troops"]
	check(w.apply({"type": "decree", "player": 1, "kind": "mobilize"})["ok"] and f["troops"] > t0, "mobilisation adds troops")
	check(w.apply({"type": "decree", "player": 1, "kind": "festival"})["ok"] and w.tick < f["festival_until"], "festival active")
	# events
	f["next_event"] = w.tick + 1
	for i in 12:
		w.step()
	check(events["offered"] == 1 and not f["event"].is_empty(), "an event was offered")
	check(w.apply({"type": "event_choice", "player": 1, "choice": 1})["ok"] and f["event"].is_empty(), "choice resolves the event")
	check(events["resolved"] == 1 and f["next_event"] > w.tick, "next event scheduled")
	f["next_event"] = w.tick + 1
	for i in 12:
		w.step()
	f["event_until"] = w.tick + 1
	for i in 12:
		w.step()
	check(events["resolved"] == 2 and f["event"].is_empty(), "unanswered event resolves by itself")
	check(not w.apply({"type": "event_choice", "player": 1, "choice": 0})["ok"], "no choice without an event")


func test_government() -> void:
	var w = _quiet(51)
	var f: Dictionary = w.factions[1]
	# parliament
	var total := 0
	for party in Rules.PARTY_ORDER:
		total += int(f["seats"][party])
	check(total == Rules.DUMA_SEATS and f["ruling"] != "", "duma has %d seats and a ruling party" % Rules.DUMA_SEATS)
	f["gold"] = 100000.0
	var before: int = int(f["seats"]["tech"])
	for i in 4:
		check(w.apply({"type": "agitate", "player": 1, "party": "tech"})["ok"], "agitation accepted")
	w._update_duma(1)
	check(int(f["seats"]["tech"]) > before, "agitation shifts seats (%d -> %d)" % [before, int(f["seats"]["tech"])])
	check(f["agitation"].is_empty(), "agitation resets after the election")
	check(not w.apply({"type": "agitate", "player": 1, "party": "pirates"})["ok"], "unknown party rejected")
	# ministers
	var rate0: float = w.gold_rate_of(1)
	f["gold"] = 0.0
	check(not w.apply({"type": "hire", "player": 1, "minister": "finance"})["ok"], "hiring needs gold")
	f["gold"] = 100000.0
	check(w.apply({"type": "hire", "player": 1, "minister": "finance"})["ok"] and w.has_minister(1, "finance"), "finance minister hired")
	check(is_equal_approx(f["gold"], 100000.0 - Rules.MINISTERS["finance"]["fee"]), "hiring fee paid")
	var rate1: float = w.gold_rate_of(1)
	check(absf(rate1 - (rate0 * (1.0 + Rules.FINANCE_BONUS) - Rules.MINISTERS["finance"]["salary"])) < 0.01, "finance bonus minus salary")
	check(not w.apply({"type": "hire", "player": 1, "minister": "finance"})["ok"], "cannot hire twice")
	var tech0: int = w.tech_cost(1, "trade")
	w.apply({"type": "hire", "player": 1, "minister": "scientist"})
	check(w.tech_cost(1, "trade") < tech0, "scientist makes research cheaper")
	check(w.apply({"type": "fire", "player": 1, "minister": "finance"})["ok"] and not w.has_minister(1, "finance"), "minister fired")
	check(not w.apply({"type": "fire", "player": 1, "minister": "finance"})["ok"], "cannot fire twice")
	# bills
	f["seats"] = {"order": 60, "trade": 20, "people": 10, "tech": 10}
	var results := {"passed": [], "failed": []}
	w.bill_result.connect(func(fid, key, passed, _s): if fid == 1: (results["passed"] if passed else results["failed"]).append(key))
	check(w.apply({"type": "bill", "player": 1, "bill": "emergency"})["ok"] and w.has_bill(1, "emergency"), "bill with majority passes")
	check(w.apply({"type": "bill", "player": 1, "bill": "social"})["ok"] and not w.has_bill(1, "social"), "bill without majority fails but costs")
	check(results["passed"] == ["emergency"] and results["failed"] == ["social"], "bill signals")
	check(not w.apply({"type": "bill", "player": 1, "bill": "emergency"})["ok"], "a passed bill cannot be re-submitted")
	var g_plain := Rules.growth_per_sec(f["troops"], f["cells"], f["cities"], 0.0)
	check(w.growth_of(1) > g_plain * 1.1 or f["approval"] < 50.0, "emergency bill boosts growth")
	# statistics
	var n0: int = f["history"]["gold"].size()
	for i in Rules.HISTORY_PERIOD_TICKS * 3:
		w.step()
	check(f["history"]["gold"].size() >= n0 + 3, "history samples accumulate")
	var breakdown: Dictionary = w.income_breakdown(1)
	check(breakdown.has("Зарплаты") and breakdown["Зарплаты"] <= 0.0, "income breakdown lists salaries")


func test_content() -> void:
	# tables are consistent
	var Content = preload("res://scripts/sim/content.gd")
	var valid_keys: Array = Content.MOD_MULT + Content.MOD_ADD + ["cap_flat"]
	var items := 0
	for table in [Rules.MINISTERS, Rules.BILLS, Rules.BUILDINGS, Rules.EXTRA_TECHS, Rules.PARTIES, Rules.BUDGET]:
		for key in table:
			items += 1
			for mk in table[key]["mods"]:
				check(mk in valid_keys, "mod key %s in %s" % [mk, key])
	for key in Rules.BILLS:
		for party in Rules.BILLS[key]["support"]:
			check(Rules.PARTIES.has(party), "bill %s supported by a real party" % key)
	check(Rules.BILL_ORDER.size() == Rules.BILLS.size() and Rules.BUILDING_ORDER.size() == Rules.BUILDINGS.size() and Rules.MINISTER_ORDER.size() == Rules.MINISTERS.size(), "order lists cover the tables")
	check(Rules.PARTY_ORDER.size() == 6 and Rules.BILLS.size() >= 150 and Rules.BUILDINGS.size() >= 60 and Rules.MINISTERS.size() >= 30 and Rules.EVENTS.size() >= 35, "plenty of content (%d items)" % items)
	# modifiers aggregate
	var w = _quiet(61)
	var f: Dictionary = w.factions[1]
	f["gold"] = 1000000.0
	var m0: Dictionary = w.mods_of(1)
	check(is_equal_approx(m0["gold"], Rules.PARTIES[f["ruling"]]["mods"].get("gold", 1.0)), "mods start from the ruling party only")
	w.apply({"type": "hire", "player": 1, "minister": "finance"})
	check(absf(w.mod(1, "gold") - m0["gold"] * 1.15) < 1e-6 and is_equal_approx(w.mod(1, "salary"), 6.0), "finance minister changes mods")
	var cap0: float = w.max_troops_of(1)
	var spawn: int = f["spawn"]
	check(w.apply({"type": "build", "player": 1, "kind": "arsenal", "cell": spawn})["ok"] and int(f["extra"]["arsenal"]) == 1, "extra building built")
	check(w.max_troops_of(1) > cap0 + 500.0, "arsenal raises the cap")
	check(w.building_cost("arsenal", 1) > Rules.BUILDINGS["arsenal"]["cost"], "second arsenal costs more")
	var coast_ok := false
	for i in f["border"]:
		if not map.is_coast(i):
			check(not w.apply({"type": "build", "player": 1, "kind": "shipyard", "cell": i})["ok"], "shipyard needs a coast")
			coast_ok = true
			break
	check(coast_ok, "found an inland cell for the shipyard test")
	var rate0: float = w.gold_rate_of(1)
	w.apply({"type": "budget", "player": 1, "item": "social", "level": 3})
	check(int(f["budget"]["social"]) == 3 and w.gold_rate_of(1) < rate0 and w.mod(1, "approval") >= 9.0, "budget costs gold and adds approval")
	w.apply({"type": "budget", "player": 1, "item": "social", "level": 0})
	check(absf(w.gold_rate_of(1) - rate0) < 1e-6, "budget can be switched off")
	var t0: int = w.tech_cost(1, "irrigation")
	check(t0 > 0 and w.apply({"type": "research", "player": 1, "tech": "irrigation"})["ok"] and w.mod(1, "growth") > 1.0, "extra technology researched and applied")
	check(not w.apply({"type": "research", "player": 1, "tech": "satellites"})["ok"], "satellites need rockets")
	w._set_owner(spawn, 0)
	check(int(f["extra"]["arsenal"]) == 0 and absf(w.mod(1, "cap_flat")) < 1e-6, "losing the cell removes the extra building and its effect")
	var ap: float = f["approval"]
	check(w.apply({"type": "decree", "player": 1, "kind": "parade"})["ok"] and f["approval"] > ap, "extra decree applies")
	check(not w.apply({"type": "decree", "player": 1, "kind": "parade"})["ok"], "extra decree has a cooldown")
	f["bills"]["disarmament"] = true
	f["mods_dirty"] = true
	check(w.building_cost("nuke", 1) == Rules.NUKE_COST * 2, "disarmament doubles nuke cost")


func test_content_pass_two() -> void:
	var Content = preload("res://scripts/sim/content.gd")
	var valid_keys: Array = Content.MOD_MULT + Content.MOD_ADD + ["cap_flat"]
	check(Rules.EXTRA_TECHS.size() >= 24 and Rules.PROJECTS.size() >= 20 and Rules.REFORM_ORDER.size() == 6 and Rules.BUDGET.size() >= 8 and Rules.EXTRA_DECREES.size() >= 10, "second content pass is big")
	check(Content.item_count() >= 350, "item_count counts everything (%d)" % Content.item_count())
	check(Rules.PROJECT_ORDER.size() == Rules.PROJECTS.size() and Rules.REFORM_ORDER.size() == Rules.REFORMS.size() and Rules.EXTRA_TECH_ORDER.size() == Rules.EXTRA_TECHS.size() and Rules.BUDGET_ORDER.size() == Rules.BUDGET.size(), "new order lists cover the tables")
	var names := {}
	for table in [Rules.BILLS, Rules.BUILDINGS, Rules.MINISTERS, Rules.PROJECTS]:
		for key in table:
			var d: Dictionary = table[key]
			check(not names.has(d["name"]), "unique name %s" % d["name"])
			names[d["name"]] = true
			if d.has("cat"):
				check(Rules.CATEGORIES.has(d["cat"]), "category %s exists" % d["cat"])
	for key in Rules.BILLS:
		var bl: Dictionary = Rules.BILLS[key]
		if bl.has("req"):
			check(Rules.BILLS.has(bl["req"]), "bill %s requires a real bill" % key)
		if bl.has("req_tech"):
			check(Rules.TECHS.has(bl["req_tech"]) or Rules.EXTRA_TECHS.has(bl["req_tech"]), "bill %s requires a real tech" % key)
		for other in bl.get("excl", []):
			check(Rules.BILLS.has(other) and key in Rules.BILLS[other].get("excl", []), "exclusion %s <-> %s is mutual" % [key, other])
	for key in Rules.BUILDINGS:
		check(Rules.PARTIES.has(Rules.BUILDINGS[key]["party"]), "building %s pleases a real party" % key)
	for axis in Rules.REFORMS:
		var ax: Dictionary = Rules.REFORMS[axis]
		check(ax["options"].has(ax["default"]) and ax["options"].size() >= 4, "reform axis %s has a default and 4+ options" % axis)
		for opt in ax["options"]:
			for mk in ax["options"][opt]["mods"]:
				check(mk in valid_keys, "reform mod key %s" % mk)
			for party in ax["options"][opt]["parties"]:
				check(Rules.PARTIES.has(party), "reform party %s" % party)
	for key in Rules.PROJECTS:
		var p: Dictionary = Rules.PROJECTS[key]
		check(p["duration"] > 0 and p["cost"] > 0, "project %s has cost and duration" % key)
		for mk in p["mods"]:
			check(mk in valid_keys, "project mod key %s" % mk)
		if p.has("req_tech"):
			check(Rules.TECHS.has(p["req_tech"]) or Rules.EXTRA_TECHS.has(p["req_tech"]), "project %s requires a real tech" % key)
	for key in Rules.EXTRA_TECHS:
		var t: Dictionary = Rules.EXTRA_TECHS[key]
		check(t["costs"].size() == t["max"] and (t["req"] == "" or Rules.TECHS.has(t["req"]) or Rules.EXTRA_TECHS.has(t["req"])), "extra tech %s is consistent" % key)
	for e in Rules.EVENTS:
		check(e["choices"].size() == 2 and e["title"] != "", "event %s has two choices" % e["title"])


func test_reforms_projects_diplomacy() -> void:
	var w = _quiet(71)
	var f: Dictionary = w.factions[1]
	f["gold"] = 1000000.0
	# bills: prerequisites, exclusions, cost modifiers, repeal
	check(w.bill_blocked(1, "stock_exchange") != "" and not w.apply({"type": "bill", "player": 1, "bill": "stock_exchange"})["ok"], "bill needs its prerequisite")
	f["bills"]["free_trade"] = true
	f["mods_dirty"] = true
	check(w.bill_blocked(1, "tariffs") != "", "exclusive bills block each other")
	var gold0: float = f["gold"]
	f["bills"]["bank_reform"] = true
	f["bills"]["stock_exchange"] = true
	check(not w.apply({"type": "repeal", "player": 1, "bill": "bank_reform"})["ok"], "cannot repeal a bill others depend on")
	check(w.apply({"type": "repeal", "player": 1, "bill": "stock_exchange"})["ok"] and not w.has_bill(1, "stock_exchange"), "repeal works")
	@warning_ignore("integer_division")
	check(is_equal_approx(gold0 - f["gold"], float(w.bill_cost(1, "stock_exchange") / 2)), "repeal costs half")
	f["bills"]["chancellery"] = true
	f["mods_dirty"] = true
	check(w.bill_cost(1, "science") == int(round(Rules.BILLS["science"]["cost"] * 0.8)), "bill_cost modifier applies")
	w.apply({"type": "hire", "player": 1, "minister": "finance"})
	var sal0: float = w.salaries_of(1)
	f["bills"]["lean_gov"] = true
	f["mods_dirty"] = true
	check(absf(w.salaries_of(1) - sal0 * 0.8) < 1e-6, "salary_mult scales salaries")
	# reforms
	check(f["reforms"]["government"] == "republic", "default reform option")
	var ap0: float = f["approval"]
	var g0: float = f["gold"]
	var seats_before: int = w.compute_seats(1)["order"]
	check(w.apply({"type": "reform", "player": 1, "axis": "government", "option": "junta"})["ok"], "reform applied")
	check(f["reforms"]["government"] == "junta" and is_equal_approx(g0 - f["gold"], float(w.reform_cost(1))) and absf(ap0 - Rules.REFORM_APPROVAL_HIT - f["approval"]) < 1e-6, "reform costs gold and approval")
	check(w.mods_of(1)["growth"] > 1.0 and w.compute_seats(1)["order"] > seats_before, "reform changes mods and Duma weights")
	check(not w.apply({"type": "reform", "player": 1, "axis": "government", "option": "junta"})["ok"], "same option is rejected")
	# projects
	check(not w.apply({"type": "project", "player": 1, "project": "space"})["ok"], "project needs its tech")
	var tc0: int = w.tech_cost(1, "trade")
	check(w.apply({"type": "project", "player": 1, "project": "literacy"})["ok"] and w.active_projects(1) == 1, "project started")
	check(not w.apply({"type": "project", "player": 1, "project": "literacy"})["ok"], "no double start")
	w.apply({"type": "project", "player": 1, "project": "dam"})
	w.apply({"type": "project", "player": 1, "project": "cathedral"})
	check(not w.apply({"type": "project", "player": 1, "project": "highways"})["ok"], "at most %d projects at once" % Rules.PROJECT_MAX_ACTIVE)
	for i in 45 * Rules.TICKS_PER_SEC:
		w.step()
	check(w.project_progress(1, "literacy") > 0.4 and w.project_progress(1, "literacy") < 0.6, "project halfway after 45 s (%.2f)" % w.project_progress(1, "literacy"))
	for i in 50 * Rules.TICKS_PER_SEC:
		w.step()
	check(f["projects_done"].get("literacy", false) and not f["projects"].has("literacy"), "project finished")
	check(w.tech_cost(1, "trade") < tc0, "finished project applies its bonus")
	# diplomacy
	var bot := _first_bot(w, 0)
	var bot2 := _first_bot(w, bot)
	check(is_equal_approx(w.relation_of(bot, 1), Rules.RELATION_START), "relations start neutral")
	g0 = f["gold"]
	check(w.apply({"type": "gift", "player": 1, "target": bot})["ok"] and is_equal_approx(w.relation_of(bot, 1), Rules.RELATION_START + Rules.RELATION_GIFT) and f["gold"] < g0, "gift raises relations")
	check(w.apply({"type": "pact", "player": 1, "target": bot})["ok"] and w.pact_active(1, bot) and w.pact_active(bot, 1), "pact signed both ways")
	check(not w.apply({"type": "pact", "player": 1, "target": bot})["ok"], "no double pact")
	check(w.launch_attack(1, bot, 0.5) != "", "cannot attack a pact partner")
	w._relation_hit(bot2, 1)
	check(is_equal_approx(w.relation_of(bot2, 1), Rules.RELATION_START - Rules.RELATION_ATTACK_HIT), "attacks sour relations")
	check(not w.apply({"type": "pact", "player": 1, "target": bot2})["ok"], "pact refused at low relations")
	for i in 100 * Rules.TICKS_PER_SEC:
		w.step()
	check(w.relation_of(bot2, 1) > Rules.RELATION_START - Rules.RELATION_ATTACK_HIT + 2.0, "relations drift back to neutral")
	check(w.pact_seconds_left(1, bot) > 0.0 and w.pact_seconds_left(1, bot) < Rules.PACT_SECONDS, "pact runs out")
	check(not w.apply({"type": "gift", "player": 1, "target": 1})["ok"] and not w.apply({"type": "pact", "player": 1, "target": _first_city_state(w)})["ok"], "gifts and pacts only with rival players")
	w.apply({"type": "hire", "player": 1, "minister": "foreign"})
	check(w.relation_of(bot2, 1) >= Rules.RELATION_START - Rules.RELATION_ATTACK_HIT + 10.0, "relation modifier counts")


func test_no_clock() -> void:
	var w = _quiet(72)
	w.match_start_tick = w.tick - 100000
	w.step()
	check(w.seconds() > 9000.0 and w.phase == w.Phase.PLAY, "no time limit: the match goes on after any number of minutes")
	var f: Dictionary = w.factions[1]
	var cells0: int = f["cells"]
	f["cells"] = int(map.land_total * Rules.WIN_LAND_SHARE) + 1
	w._check_victory()
	check(w.phase == w.Phase.FINISHED and w.winner_declared == 1, "holding half the land wins")
	w.resume()
	w.step()
	check(w.phase == w.Phase.PLAY and w.winner_declared == 1, "the match can go on after the win without a second result")
	f["cells"] = cells0


func test_ranking_and_names() -> void:
	var w = _quiet(10)
	var r: Array = w.ranking()
	check(r.size() == 1 + Rules.NUM_BOTS, "ranking lists players only")
	for i in range(1, r.size()):
		check(r[i - 1]["cells"] >= r[i]["cells"], "ranking sorted by land")
	check(w.rank_of(1) >= 1 and w.rank_of(1) <= r.size(), "human has a rank")
	check(abs(w.land_share(1) - float(w.factions[1]["cells"]) / map.land_total) < 1e-9, "land share formula")
	check(Names.short_number(6390.0) == "6.39K" and Names.short_number(17000.0) == "17.0K" and Names.short_number(2500000.0) == "2.50M" and Names.short_number(97.0) == "97", "short numbers")
	var used := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var a := Names.city_name(rng, used)
	var b := Names.city_name(rng, used)
	check(a != b and a.length() > 2, "city names are unique")
	var w2 = World.new(map, 3, "Максим")
	check(w2.factions[1]["name"] == "Максим", "nickname is used")


func test_determinism() -> void:
	var a = World.new(map, 123)
	var b = World.new(map, 123)
	for i in 500:
		a.step()
		b.step()
	check(a.phase == a.Phase.PLAY, "auto spawn happened within 500 ticks")
	check(a.owner == b.owner, "same seed gives the same map after 500 ticks")
	check(is_equal_approx(a.factions[2]["troops"], b.factions[2]["troops"]), "same troops")
	var c = World.new(map, 124)
	check(c.owner != a.owner, "different seed gives a different map")


func test_soak() -> void:
	var w = World.new(map, 77)
	w.auto_spawn_human()
	var owned0 := 0
	for id in range(1, w.factions.size()):
		owned0 += w.factions[id]["cells"]
	var t := Time.get_ticks_msec()
	for i in 1800:
		w.step()
		if i == 599:
			check(w.factions[1]["alive"], "idle human survives the first minute")
	var ms := Time.get_ticks_msec() - t
	var owned1 := 0
	var ok := true
	var bots_grown := 0
	for id in range(1, w.factions.size()):
		var f: Dictionary = w.factions[id]
		owned1 += f["cells"]
		if f["troops"] < 0.0 or f["gold"] < 0.0 or f["cells"] < 0:
			ok = false
		if f["kind"] == w.Kind.BOT and f["cells"] > 200:
			bots_grown += 1
	check(ok, "no negative values after 3 minutes")
	check(owned1 > owned0 * 2, "bots expanded (%d -> %d cells)" % [owned0, owned1])
	check(bots_grown >= 6, "most bots grew past 200 cells (%d)" % bots_grown)
	print("soak: 1800 ticks in %d ms, owned %d -> %d, human %d cells, leader %s %.1f%%" % [ms, owned0, owned1, w.factions[1]["cells"], w.factions[w.leader()]["name"], w.land_share(w.leader()) * 100.0])
	check(ms < 60000, "3 game minutes simulate in under a minute")
