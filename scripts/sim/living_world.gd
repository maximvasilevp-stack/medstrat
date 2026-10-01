extends RefCounted
## The world develops by itself: eras advance with the technology of all nations, unhappy or
## overgrown countries split off rebel states, old city-states wake up as new nations.
## Runs every LIVING_PERIOD ticks from World.step().

const Rules := preload("res://scripts/sim/rules.gd")
const Names := preload("res://scripts/sim/names.gd")

const PERIOD_TICKS := 100              # every 10 s
const REBEL_MIN_CELLS := 1200
const REBEL_APPROVAL := 25.0
const REBEL_CHANCE_UNHAPPY := 0.12     # per check, bots
const REBEL_CHANCE_UNHAPPY_HUMAN := 0.08
const REBEL_SHARE := 0.12              # countries above this land share breed separatists...
const REBEL_CHANCE_BIG := 0.03         # ...with this chance per check
const REBEL_TAKE := 0.15               # share of the cells that break away
const REBEL_TAKE_MAX := 3000
const REBEL_TROOPS := 0.15
const AWAKEN_AFTER := 180.0            # seconds before a city-state may become a nation
const AWAKEN_TROOPS := 1200.0
const AWAKEN_CHANCE := 0.02            # per check
const REBEL_NAMES := ["Свободная республика", "Союз провинций", "Новый порядок", "Народное ополчение", "Мятежный край", "Вольные земли", "Лига городов", "Северный пакт", "Южная коммуна", "Горный союз"]


## Era index for the average technology level of all living nations.
static func era_for(world) -> int:
	var total := 0
	var n := 0
	for id in range(1, world.factions.size()):
		var f: Dictionary = world.factions[id]
		if f["kind"] == world.Kind.CITY or not f["alive"]:
			continue
		for k in f["tech"]:
			total += int(f["tech"][k])
		n += 1
	var avg: float = float(total) / maxf(1.0, float(n))
	var era := 0
	for i in Rules.ERAS.size():
		if avg >= float(Rules.ERAS[i]["techs"]):
			era = i
	return era


static func tick(world) -> void:
	# eras
	var era := era_for(world)
	if era > world.era:
		world.era = era
		for id in range(1, world.factions.size()):
			world.factions[id]["mods_dirty"] = true
		world.era_changed.emit(era)
		world.news_posted.emit("Наступает эпоха: %s — %s" % [Rules.ERAS[era]["name"], Rules.ERAS[era]["desc"]], "world")
	if world.phase != world.Phase.PLAY:
		return
	# rebellions
	for id in range(1, world.factions.size()):
		var f: Dictionary = world.factions[id]
		if f["kind"] == world.Kind.CITY or not f["alive"] or f["cells"] < REBEL_MIN_CELLS or f["admin"]:
			continue
		var chance := 0.0
		if f["approval"] < REBEL_APPROVAL:
			chance = REBEL_CHANCE_UNHAPPY_HUMAN if id == world.human else REBEL_CHANCE_UNHAPPY
		elif world.land_share(id) > REBEL_SHARE:
			chance = REBEL_CHANCE_BIG
		if chance > 0.0 and world.rng.randf() < chance:
			spawn_rebels(world, id)
	# city-states awaken
	if world.seconds() >= AWAKEN_AFTER:
		for id in range(1, world.factions.size()):
			var f: Dictionary = world.factions[id]
			if f["kind"] == world.Kind.CITY and f["alive"] and f["troops"] >= AWAKEN_TROOPS and world.rng.randf() < AWAKEN_CHANCE:
				awaken(world, id)
				break


static func _fresh_color(world) -> Color:
	return Color.from_hsv(world.rng.randf(), 0.45 + world.rng.randf() * 0.2, 0.85 + world.rng.randf() * 0.1)


## A province breaks away from faction fid as a new bot nation. Returns the new faction id.
static func spawn_rebels(world, fid: int) -> int:
	var f: Dictionary = world.factions[fid]
	var map = world.map
	var border: Array = f["border"].keys()
	if border.is_empty() or f["cells"] < 300:
		return -1
	var center: Vector2 = world.centroid(fid)
	var seed_cell: int = border[0]
	var best := -1.0
	for i in mini(border.size(), 200):
		var c: int = border[world.rng.randi_range(0, border.size() - 1)]
		var d: float = Vector2(map.cell(c)).distance_to(center)
		if d > best:
			best = d
			seed_cell = c
	var want: int = clampi(int(f["cells"] * REBEL_TAKE), 100, mini(REBEL_TAKE_MAX, int(f["cells"] * 0.5)))
	var taken: Array = []
	var seen := {seed_cell: true}
	var queue: Array = [seed_cell]
	while not queue.is_empty() and taken.size() < want:
		var c: int = queue.pop_front()
		if world.owner[c] != fid:
			continue
		taken.append(c)
		for n in map.neighbors(c):
			if not seen.has(n) and world.owner[n] == fid:
				seen[n] = true
				queue.append(n)
	if taken.size() < 50:
		return -1
	var name: String = REBEL_NAMES[world.rng.randi_range(0, REBEL_NAMES.size() - 1)]
	var used := {}
	for id in range(1, world.factions.size()):
		used[world.factions[id]["name"]] = true
	if used.has(name):
		name = Names.city_name(world.rng, used)
	var r: Dictionary = world._new_faction(name, _fresh_color(world), world.Kind.BOT)
	var rid: int = r["id"]
	r["persona"] = "aggressor" if world.rng.randf() < 0.5 else "turtle"
	for c in taken:
		world._set_owner(c, rid)
	var troops: float = f["troops"] * REBEL_TROOPS
	f["troops"] -= troops
	r["troops"] = troops
	r["gold"] = 1500.0
	r["approval"] = 70.0
	r["next_election"] = world.tick + int(Rules.ELECTION_PERIOD * Rules.TICKS_PER_SEC)
	r["relations"][fid] = 10.0
	f["relations"][rid] = 20.0
	world._update_duma(rid)
	world.faction_born.emit(rid, fid)
	world.news_posted.emit("Восстание: от %s отделяется %s (%d клеток)" % [f["name"], name, taken.size()], "war")
	return rid


## A city-state becomes a real nation with a persona and ambitions.
static func awaken(world, id: int) -> void:
	var f: Dictionary = world.factions[id]
	f["kind"] = world.Kind.BOT
	f["persona"] = Rules.PERSONA_ORDER[world.rng.randi_range(0, Rules.PERSONA_ORDER.size() - 1)]
	f["color"] = _fresh_color(world)
	f["gold"] = 2000.0
	f["approval"] = 65.0
	f["next_election"] = world.tick + int(Rules.ELECTION_PERIOD * Rules.TICKS_PER_SEC)
	f["mods_dirty"] = true
	world._update_duma(id)
	world.faction_born.emit(id, 0)
	world.news_posted.emit("%s провозглашает себя государством" % f["name"], "politics")
