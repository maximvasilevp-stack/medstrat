extends SceneTree
## Headless test runner: godot --headless --path . -s tests/run_tests.gd

const MapData := preload("res://scripts/map/map_data.gd")
const Sim := preload("res://scripts/sim/sim.gd")
const Rules := preload("res://scripts/sim/rules.gd")
const BotBrain := preload("res://scripts/sim/bot_brain.gd")

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
	test_economy()
	test_buildings()
	test_combat()
	test_bots()
	test_soak()
	print("tests: %d passed, %d failed" % [passed, failed])
	finished = true
	quit(1 if failed > 0 else 0)


func _process(_delta: float) -> bool:
	if not finished:
		printerr("test runner aborted by a script error")
		quit(2)
	return true


func _fresh() -> Variant:
	var s = Sim.new(map, map.players["player1"], 42)
	s.bots_enabled = false
	return s


func test_map() -> void:
	check(map.width == 640 and map.height == 768, "map size 640x768")
	check(map.ids.size() == map.width * map.height, "ids size")
	var it: int = map.id_by_name_en("Italy")
	var tn: int = map.id_by_name_en("Tunisia")
	check(it > 0 and tn > 0, "Italy and Tunisia exist")
	check(map.players["player1"] == it, "player1 is Italy")
	check(map.province(it)["coastal"], "Italy is coastal")
	check(tn in map.province(it)["sea"], "Tunisia is a sea neighbour of Italy")
	check(map.province_at(map.province(it)["capital"]) == it, "Italy capital lies in Italy")
	check(map.is_coast(map.province(it)["port_cell"]), "Italy port cell is on the coast")
	check(not map.is_coast(Vector2i(0, 0)), "corner cell is not coast")
	check(map.province_at(Vector2i(-1, 5)) == 0, "out of bounds is water")
	for p in map.provinces:
		for q in p["land"]:
			check(p["id"] in map.province(q)["land"], "land adjacency symmetric for " + p["name_en"])


func test_economy() -> void:
	var s = _fresh()
	var h: int = s.human
	var gold0: int = s.factions[h]["gold"]
	var expected: int = Rules.base_income(map.province(h)["cells"])
	check(s.income_of(h) == expected, "income of a single province equals base income")
	for i in Rules.TICKS_PER_MONTH - 1:
		s.step()
	check(s.factions[h]["gold"] == gold0, "no income before the month ends")
	s.step()
	check(s.factions[h]["gold"] == gold0 + expected, "income collected after one month")
	check(s.month == 1, "month counter advanced")
	var bot: int = map.id_by_name_en("Tunisia")
	check(s.income_of(bot) == int(floor(Rules.base_income(map.province(bot)["cells"]) * Rules.BOT_HANDICAP)), "bot handicap applied")


func test_buildings() -> void:
	var s = _fresh()
	var h: int = s.human
	var cap: Vector2i = map.province(h)["capital"]
	var foreign: int = map.id_by_name_en("France")
	s.factions[h]["gold"] = 10000
	check(not s.apply({"type": "build_city", "player": h, "province": h, "cell": Vector2i(0, 0)})["ok"], "no city on water")
	check(not s.apply({"type": "build_city", "player": h, "province": foreign, "cell": map.province(foreign)["capital"]})["ok"], "no city in foreign province")
	check(s.apply({"type": "build_city", "player": h, "province": h, "cell": cap})["ok"], "city built at home capital")
	check(s.provinces[h]["city"] and s.factions[h]["gold"] == 10000 - Rules.CITY_COST, "city flag set and gold paid")
	check(not s.apply({"type": "build_city", "player": h, "province": h, "cell": cap})["ok"], "second city rejected")
	check(s.province_income(h) == Rules.base_income(map.province(h)["cells"]) + Rules.CITY_INCOME, "city raises income")
	var inland := cap
	if map.is_coast(inland):
		inland = map.province(h)["capital"]
	if not map.is_coast(inland):
		check(not s.apply({"type": "build_port", "player": h, "province": h, "cell": inland})["ok"], "no port inland")
	check(s.apply({"type": "build_port", "player": h, "province": h, "cell": map.province(h)["port_cell"]})["ok"], "port built on the coast")
	check(s.provinces[h]["port"], "port flag set")
	check(not s.apply({"type": "hire", "player": h, "province": foreign})["ok"], "no hiring abroad")
	var g0: int = s.provinces[h]["garrison"]
	check(s.apply({"type": "hire", "player": h, "province": h})["ok"], "hire in city province")
	check(s.provinces[h]["garrison"] == g0 + Rules.HIRE_STRENGTH, "garrison grew by hire strength")
	s.factions[h]["gold"] = 0
	var r: Dictionary = s.apply({"type": "hire", "player": h, "province": h})
	check(not r["ok"] and r["reason"].begins_with("Не хватает золота"), "hire rejected without gold")
	var s2 = _fresh()
	check(not s2.apply({"type": "hire", "player": s2.human, "province": s2.human})["ok"], "hire needs a city")


func test_combat() -> void:
	var s = _fresh()
	var h: int = s.human
	var tn: int = map.id_by_name_en("Tunisia")
	var fr: int = map.id_by_name_en("France")
	var pl: int = map.id_by_name_en("Poland")
	s.provinces[h]["garrison"] = 150
	s.provinces[tn]["garrison"] = 80
	check(s.defense_of(tn) == 80 + Rules.BASE_DEFENSE, "defense = garrison + base")
	check(not s.apply({"type": "attack", "player": h, "from": h, "to": tn})["ok"], "sea attack without port rejected")
	check(not s.apply({"type": "attack", "player": h, "from": h, "to": pl})["ok"], "attack on non-neighbour rejected")
	s.provinces[h]["port"] = true
	var force: int = Rules.attack_force(150)
	check(force > 100 and force < 150, "attack force keeps part of the garrison home")
	var r: Dictionary = s.apply({"type": "attack", "player": h, "from": h, "to": tn})
	check(r["ok"], "sea attack with port accepted")
	check(s.provinces[tn]["owner"] == h, "Tunisia captured")
	check(s.provinces[tn]["garrison"] == force - 100, "remaining army garrisons the captured province")
	check(s.provinces[h]["garrison"] == 150 - force, "home guard stayed")
	check(not s.factions[tn]["alive"], "Tunisia eliminated")
	check(s.province_count(h) == 2, "player owns two provinces")
	# failed attack over land
	s.provinces[h]["garrison"] = 30
	s.provinces[fr]["garrison"] = 100
	var force2: int = Rules.attack_force(30)
	var r2: Dictionary = s.apply({"type": "attack", "player": h, "from": h, "to": fr})
	check(r2["ok"] and s.provinces[fr]["owner"] == fr, "failed attack keeps owner")
	check(s.provinces[h]["garrison"] == 30 - force2, "failed attackers are lost, home guard stays")
	check(s.provinces[fr]["garrison"] == 100 - maxi(0, force2 - Rules.BASE_DEFENSE), "defenders lose attack minus fortification")
	s.provinces[h]["garrison"] = 0
	check(not s.apply({"type": "attack", "player": h, "from": h, "to": fr})["ok"], "no attack without troops")


func test_bots() -> void:
	var s = _fresh()
	var tn: int = map.id_by_name_en("Tunisia")
	s.factions[tn]["gold"] = 1000
	var actions: Array = BotBrain.think(s, tn)
	var types: Array = []
	for a in actions:
		types.append(a["type"])
	check("build_city" in types, "rich bot builds a city")
	for a in actions:
		s.apply(a)
	check(s.provinces[tn]["city"], "bot city applied")
	# never attacks a much stronger neighbour
	var s3 = _fresh()
	var dz: int = map.id_by_name_en("Algeria")
	s3.provinces[tn]["garrison"] = 10
	s3.provinces[dz]["garrison"] = 500
	var attacks := 0
	for a in BotBrain.think(s3, tn):
		if a["type"] == "attack":
			attacks += 1
	check(attacks == 0, "weak bot does not attack")
	# attacks a weak neighbour
	s3.provinces[tn]["garrison"] = 500
	s3.provinces[dz]["garrison"] = 10
	var target := -1
	for a in BotBrain.think(s3, tn):
		if a["type"] == "attack":
			target = a["to"]
	check(target == dz or target == map.id_by_name_en("Libya"), "strong bot attacks a weak land neighbour")


func test_soak() -> void:
	var s = Sim.new(map, map.players["player1"], 7)
	var counter := {"captures": 0}
	s.province_captured.connect(func(_p, _o, _n): counter["captures"] += 1)
	var human_at := {}
	for i in 6000:
		s.step()
		if (i + 1) % 1200 == 0:
			human_at[(i + 1) / 100] = s.province_count(s.human)
	print("soak: idle human province count by month: ", human_at)
	var captures: int = counter["captures"]
	var ok := true
	for pid in s.provinces:
		if s.provinces[pid]["garrison"] < 0:
			ok = false
	for fid in s.factions:
		if s.factions[fid]["gold"] < 0:
			ok = false
	check(ok, "no negative garrison or gold after 6000 ticks")
	check(captures > 0, "bots captured something in 10 game minutes (%d captures)" % captures)
	var alive := 0
	for fid in s.factions:
		if s.factions[fid]["alive"]:
			alive += 1
	check(alive >= 10, "no single bot steamrolls the map in 10 minutes (%d alive)" % alive)
	print("soak: %d captures, %d factions alive, human owns %d provinces" % [captures, alive, s.province_count(s.human)])
