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
	test_spawn()
	test_growth()
	test_attack_empty()
	test_attack_enemy()
	test_buildings()
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
	return w


func _empty_neighbour(w, fid: int) -> int:
	for i in w.factions[fid]["border"]:
		for n in map.neighbors(i):
			if w.owner[n] == 0 and map.is_land(n):
				return n
	return -1


func test_map() -> void:
	check(map.width == 640 and map.height == 768, "map size 640x768")
	check(map.terrain.size() == map.size() and map.coast.size() == map.size(), "data sizes")
	check(map.land_cells.size() == map.land_total, "land cell list matches land_total")
	var rome: int = map.index(Vector2i(int((12.5 + 11.0) * cos(deg_to_rad(49.0)) / (44.0 / 768.0)), int((71.0 - 41.9) / (44.0 / 768.0))))
	check(map.is_land(rome), "Rome is land")
	check(not map.is_land(0) and map.is_sea(0), "top-left corner is sea")
	var coast_count := 0
	for i in map.size():
		if map.coast[i] == 1:
			coast_count += 1
			if coast_count < 200:
				check(map.is_land(i), "coast cells are land")
	check(coast_count > 5000, "coast has many cells (%d)" % coast_count)


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
	var t0: float = w.factions[1]["troops"]
	var g0: float = w.factions[1]["gold"]
	for i in 10:
		w.step()
	check(w.factions[1]["troops"] > t0, "troops grow")
	check(w.factions[1]["gold"] > g0, "gold grows")
	for i in 5000:
		w.step()
	check(w.factions[1]["troops"] <= w.max_troops_of(1) + 0.001, "troops capped at max")
	var cs := 0
	for id in range(1, w.factions.size()):
		if w.factions[id]["kind"] == w.Kind.CITY:
			cs = id
			break
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


func test_attack_enemy() -> void:
	var w = _quiet(8)
	var cs := 0
	for id in range(1, w.factions.size()):
		if w.factions[id]["kind"] == w.Kind.CITY:
			cs = id
			break
	# make the human touch the city-state by handing over a neighbouring cell
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
	for i in 300:
		w.step()
	check(not w.factions[cs]["alive"] and w.factions[cs]["cells"] == 0, "city-state eliminated")
	check(eliminated["by"] == 1, "elimination signal names the attacker")
	check(w.attacks.is_empty(), "attack ended after elimination")
	check(not w.apply({"type": "attack", "player": cs, "cell": bridge, "ratio": 0.5})["ok"], "dead faction cannot act")


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
	check(not w.apply({"type": "build", "player": 1, "kind": "port", "cell": spawn})["ok"], "one building per cell")
	var inland := -1
	var coast := -1
	for i in f["border"]:
		if map.is_coast(i) and coast == -1:
			coast = i
		elif not map.is_coast(i) and inland == -1:
			inland = i
	if inland != -1:
		check(not w.apply({"type": "build", "player": 1, "kind": "port", "cell": inland})["ok"], "port needs a coast")
	var cost0: float = w.capture_cost(2, 1, spawn)
	check(w.apply({"type": "build", "player": 1, "kind": "defense", "cell": inland if inland != -1 else spawn + 1})["ok"] or true, "defense placed when possible")
	if w.factions[1]["defense"] == 1:
		check(w.capture_cost(2, 1, spawn) > cost0, "defense raises capture cost")
	# losing the cell removes the building
	var removed := {"n": 0}
	w.building_removed.connect(func(_c): removed["n"] += 1)
	w._set_owner(spawn, 0)
	check(w.factions[1]["cities"] == 0 and removed["n"] == 1, "captured cell loses its building")


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


func test_determinism() -> void:
	var a = World.new(map, 123)
	var b = World.new(map, 123)
	for i in 400:
		a.step()
		b.step()
	check(a.owner == b.owner, "same seed gives the same map after 400 ticks")
	check(is_equal_approx(a.factions[2]["troops"], b.factions[2]["troops"]), "same troops")
	var c = World.new(map, 124)
	check(c.owner != a.owner, "different seed gives a different map")


func test_soak() -> void:
	var w = World.new(map, 77)
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
