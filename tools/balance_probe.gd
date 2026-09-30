extends SceneTree
## Balance probe: godot --headless --path . -s tools/balance_probe.gd  (prints land shares over a match)

const MapData := preload("res://scripts/map/map_data.gd")
const World := preload("res://scripts/sim/world.gd")
const Rules := preload("res://scripts/sim/rules.gd")


func _init() -> void:
	var map = MapData.new()
	for seed in [11, 42]:
		var w = World.new(map, seed)
		w.auto_spawn_human()
		print("seed %d" % seed)
		var t := Time.get_ticks_msec()
		for minute in range(1, 16):
			for i in 600:
				w.step()
			var owned := 0
			var alive := 0
			for id in range(1, w.factions.size()):
				owned += w.factions[id]["cells"]
				if w.factions[id]["kind"] == w.Kind.BOT and w.factions[id]["alive"]:
					alive += 1
			var lead: Dictionary = w.factions[w.leader()]
			if minute in [1, 3, 5, 8, 10, 15]:
				print("  min %2d: claimed %4.1f%%  leader %-12s %4.1f%% troops %6d  human %4.2f%% (%s)  bots alive %d  %d ms" % [
					minute, 100.0 * owned / map.land_total, lead["name"], 100.0 * w.land_share(lead["id"]), int(lead["troops"]),
					100.0 * w.land_share(1), "alive" if w.factions[1]["alive"] else "dead", alive, Time.get_ticks_msec() - t])
	quit(0)
