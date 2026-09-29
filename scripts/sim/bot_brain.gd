extends RefCounted
## Decisions for AI players. Pure function of the world state.

const Rules := preload("res://scripts/sim/rules.gd")


static func think(world, fid: int) -> void:
	var f: Dictionary = world.factions[fid]
	var map = world.map
	var cap: float = world.max_troops_of(fid)
	var share: float = f["troops"] / maxf(1.0, cap)
	var border: Dictionary = f["border"]
	if border.is_empty():
		return

	# buildings
	if f["gold"] >= world.building_cost("city", fid) and f["cities"] < 1 + f["cells"] / 2500:
		world.apply({"type": "build", "player": fid, "kind": "city", "cell": _random_border(world, border)})
	elif f["gold"] >= world.building_cost("port", fid) and f["ports"] == 0:
		for i in border:
			if map.is_coast(i):
				world.apply({"type": "build", "player": fid, "kind": "port", "cell": i})
				break
	elif f["gold"] >= world.building_cost("defense", fid) and f["defense"] < 3 and f["cells"] > 300:
		world.apply({"type": "build", "player": fid, "kind": "defense", "cell": _random_border(world, border)})

	# expansion into empty land first
	var contacts: Dictionary = world.contacts_of(fid)
	if contacts.is_empty():
		return
	if contacts.has(0) and share >= Rules.BOT_MIN_TROOPS_SHARE and not world.has_attack(fid, 0):
		world.launch_attack(fid, 0, Rules.BOT_RATIO_EMPTY)
		return

	# then the cheapest neighbour
	if share < Rules.BOT_ENEMY_TROOPS_SHARE:
		return
	var grace: bool = world.seconds() < Rules.BOT_GRACE_SECONDS
	var best := 0
	var best_score := INF
	for o in contacts:
		if o == 0 or (grace and o == world.human) or world.has_attack(fid, o):
			continue
		var d: Dictionary = world.factions[o]
		var score: float = (1.0 + d["troops"] / maxf(1.0, float(d["cells"]))) * (1.0 + d["defense"] * Rules.DEFENSE_BONUS)
		if d["kind"] == world.Kind.CITY:
			score *= 0.8
		score *= 1.0 + world.rng.randf() * 0.2
		if score < best_score:
			best_score = score
			best = o
	if best == 0:
		return
	var amount: float = f["troops"] * Rules.BOT_RATIO_ENEMY
	var d: Dictionary = world.factions[best]
	if amount >= d["troops"] * 0.35 or contacts[best] >= 40:
		world.launch_attack(fid, best, Rules.BOT_RATIO_ENEMY)


static func _random_border(world, border: Dictionary) -> int:
	var keys := border.keys()
	return keys[world.rng.randi_range(0, keys.size() - 1)]
