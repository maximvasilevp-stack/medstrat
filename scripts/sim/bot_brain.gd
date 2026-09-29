extends RefCounted
## Decision making for AI factions. Pure function of the current Sim state.

const Rules := preload("res://scripts/sim/rules.gd")


static func think(sim, fid: int) -> Array:
	var actions: Array = []
	var owned: Array = sim.provinces_of(fid)
	if owned.is_empty():
		return actions
	var map = sim.map
	var gold: int = sim.factions[fid]["gold"]

	# 1. a city in the biggest province without one
	if gold >= Rules.CITY_COST:
		var best := -1
		var best_cells := -1
		for pid in owned:
			if not sim.provinces[pid]["city"] and map.province(pid)["cells"] > best_cells:
				best = pid
				best_cells = map.province(pid)["cells"]
		if best != -1:
			actions.append({"type": "build_city", "player": fid, "province": best, "cell": map.province(best)["capital"]})
			gold -= Rules.CITY_COST

	# 2. a port in a coastal province that has enemies across the sea
	if gold >= Rules.PORT_COST:
		for pid in owned:
			var p: Dictionary = map.province(pid)
			if p["coastal"] and not sim.provinces[pid]["port"] and _has_enemy(sim, fid, p["sea"]):
				actions.append({"type": "build_port", "player": fid, "province": pid, "cell": p["port_cell"]})
				gold -= Rules.PORT_COST
				break

	# 3. hire where the front is (city province with the most enemy neighbours)
	var hire_at := -1
	var hire_score := -1
	for pid in owned:
		if not sim.provinces[pid]["city"]:
			continue
		var score := 0
		for t in sim.attackable_from(pid, fid):
			score += 1
		if score > hire_score:
			hire_score = score
			hire_at = pid
	if hire_at != -1:
		var n := 0
		while gold >= Rules.HIRE_COST and n < Rules.BOT_MAX_HIRES:
			actions.append({"type": "hire", "player": fid, "province": hire_at})
			gold -= Rules.HIRE_COST
			n += 1

	# 4. attack the weakest reachable neighbour when clearly stronger
	var best_from := -1
	var best_to := -1
	var best_ratio := 0.0
	var grace: bool = sim.month < Rules.BOT_GRACE_MONTHS
	for pid in owned:
		var g: int = sim.provinces[pid]["garrison"]
		if g <= 0:
			continue
		for t in sim.attackable_from(pid, fid):
			if grace and sim.provinces[t]["owner"] == sim.human:
				continue
			var ratio := float(Rules.attack_force(g)) / float(sim.defense_of(t))
			if ratio > best_ratio or (is_equal_approx(ratio, best_ratio) and sim.rng.randi_range(0, 1) == 0):
				best_ratio = ratio
				best_from = pid
				best_to = t
	if best_from != -1 and best_ratio >= Rules.BOT_AGGRESSION:
		actions.append({"type": "attack", "player": fid, "from": best_from, "to": best_to})
	return actions


static func _has_enemy(sim, fid: int, ids: Array) -> bool:
	for t in ids:
		if sim.provinces[t]["owner"] != fid:
			return true
	return false
