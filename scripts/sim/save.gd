extends RefCounted
## Save and load a whole match (user://save.bin). Everything in World is plain data, so one
## store_var() round trip is enough; borders and the map textures are rebuilt after loading.

const World := preload("res://scripts/sim/world.gd")

const PATH := "user://save.bin"
const VERSION := 1


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func remove() -> void:
	if exists():
		DirAccess.remove_absolute(PATH)


static func to_dict(world) -> Dictionary:
	var factions: Array = []
	for f in world.factions:
		factions.append(f.duplicate(true) if f != null else null)
	for f in factions:
		if f != null:
			f["border"] = {}      # rebuilt on load
			f["mods"] = {}
			f["mods_dirty"] = true
	return {
		"version": VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"tick": world.tick, "match_start_tick": world.match_start_tick, "phase": world.phase,
		"spawn_ticks_left": world.spawn_ticks_left, "human": world.human, "bots_enabled": world.bots_enabled,
		"winner_declared": world.winner_declared, "season": world.season, "difficulty": world.difficulty,
		"rng_seed": world.rng.seed, "rng_state": world.rng.state,
		"owner": world.owner, "scorch": world.scorch,
		"factions": factions, "attacks": world.attacks.duplicate(true), "ships": world.ships.duplicate(true),
		"missiles": world.missiles.duplicate(true), "buildings_at": world.buildings_at.duplicate(true),
		"scorched": world.scorched.duplicate(true), "scenario": world.scenario,
		"market": world.market.duplicate(true), "wonders": world.wonders.duplicate(true), "catch_up": world.catch_up,
	}


static func from_dict(map, d: Dictionary):
	var w = World.new(map, int(d["rng_seed"]))
	w.rng.state = int(d["rng_state"])
	w.tick = int(d["tick"])
	w.match_start_tick = int(d["match_start_tick"])
	w.phase = int(d["phase"])
	w.spawn_ticks_left = int(d["spawn_ticks_left"])
	w.human = int(d["human"])
	w.bots_enabled = bool(d["bots_enabled"])
	w.winner_declared = int(d["winner_declared"])
	w.season = int(d["season"])
	w.difficulty = int(d["difficulty"])
	w.scenario = String(d.get("scenario", "free"))
	w.owner = d["owner"]
	w.scorch = d["scorch"]
	w.factions = d["factions"]
	w.attacks = d["attacks"]
	w.ships = d["ships"]
	w.missiles = d["missiles"]
	w.buildings_at = d["buildings_at"]
	w.scorched = d["scorched"]
	if d.has("market"):
		w.market = d["market"]
	w.wonders = d.get("wonders", {})
	w.catch_up = bool(d.get("catch_up", false))
	w.rebuild_borders()
	w.dirty = true
	w.scorch_dirty = true
	return w


static func save(world) -> bool:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(to_dict(world))
	f.close()
	return true


static func load_world(map):
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return null
	var d = f.get_var()
	f.close()
	if not (d is Dictionary) or int(d.get("version", 0)) != VERSION:
		return null
	return from_dict(map, d)


## Short description of the saved match for the menu.
static func summary() -> String:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return ""
	var d = f.get_var()
	f.close()
	if not (d is Dictionary) or int(d.get("version", 0)) != VERSION:
		return ""
	var human: Dictionary = d["factions"][int(d["human"])]
	var secs: int = int((int(d["tick"]) - int(d["match_start_tick"])) / 10)
	@warning_ignore("integer_division")
	return "%s · %d клеток · %d:%02d" % [human["name"], int(human["cells"]), secs / 60, secs % 60]
