extends RefCounted
## Deterministic game simulation. All mutations go through apply(action) so the same
## code can later run on a multiplayer host with actions arriving over the network.
##
## Action dictionaries:
##   {type="build_city", player, province, cell: Vector2i}
##   {type="build_port", player, province, cell: Vector2i}
##   {type="hire", player, province}
##   {type="attack", player, from, to}

const Rules := preload("res://scripts/sim/rules.gd")
const BotBrain := preload("res://scripts/sim/bot_brain.gd")

signal gold_changed(faction_id: int)
signal month_passed(month: int)
signal building_placed(province_id: int, kind: String, cell: Vector2i)
signal garrison_changed(province_id: int)
signal province_captured(province_id: int, old_owner: int, new_owner: int)
signal battle(province_id: int, cell: Vector2i, attacker: int, defender: int, won: bool, attack_strength: int, defense_strength: int)
signal faction_eliminated(faction_id: int)
signal action_applied(action: Dictionary)
signal action_rejected(action: Dictionary, reason: String)

var map
var human: int
var tick: int = 0
var month: int = 0
var factions: Dictionary = {}    # faction id (= home province id) -> {id, name, color, gold, is_bot, alive}
var provinces: Dictionary = {}   # province id -> {owner, city, city_cell, port, port_cell, garrison}
var battles: Array = []          # {province, cell, tick}
var rng := RandomNumberGenerator.new()
var bots_enabled := true


func _init(m, human_faction: int, game_seed: int = 1) -> void:
	map = m
	human = human_faction
	rng.seed = game_seed
	for p in map.provinces:
		var id: int = p["id"]
		var is_bot: bool = id != human
		factions[id] = {
			"id": id, "name": p["name"], "color": p["color"],
			"gold": Rules.START_GOLD_BOT if is_bot else Rules.START_GOLD_PLAYER,
			"is_bot": is_bot, "alive": true,
		}
		provinces[id] = {
			"owner": id, "city": false, "city_cell": Vector2i(-1, -1),
			"port": false, "port_cell": Vector2i(-1, -1),
			"garrison": Rules.start_garrison(p["cells"]),
		}


# ------------------------------------------------------------------ time

func step() -> void:
	tick += 1
	if tick % Rules.TICKS_PER_MONTH == 0:
		month += 1
		_collect_income()
		month_passed.emit(month)
	if bots_enabled:
		for fid in factions:
			var f: Dictionary = factions[fid]
			if f["is_bot"] and f["alive"] and (tick + fid * 7) % Rules.BOT_PERIOD == 0:
				for a in BotBrain.think(self, fid):
					apply(a)
	while battles.size() > 0 and tick - battles[0]["tick"] > Rules.BATTLE_MARK_TICKS:
		battles.pop_front()


func _collect_income() -> void:
	var income: Dictionary = {}
	for pid in provinces:
		var owner: int = provinces[pid]["owner"]
		income[owner] = income.get(owner, 0) + province_income(pid)
	for fid in income:
		var f: Dictionary = factions[fid]
		var amount: int = income[fid]
		if f["is_bot"]:
			amount = int(floor(amount * Rules.BOT_HANDICAP))
		f["gold"] += amount
		gold_changed.emit(fid)


# ------------------------------------------------------------------ queries

func province_income(pid: int) -> int:
	var p: Dictionary = provinces[pid]
	var v: int = Rules.base_income(map.province(pid)["cells"])
	if p["city"]:
		v += Rules.CITY_INCOME
	if p["port"]:
		v += Rules.PORT_INCOME
	return v


func income_of(fid: int) -> int:
	var total := 0
	for pid in provinces:
		if provinces[pid]["owner"] == fid:
			total += province_income(pid)
	if factions[fid]["is_bot"]:
		total = int(floor(total * Rules.BOT_HANDICAP))
	return total


func provinces_of(fid: int) -> Array:
	var out: Array = []
	for pid in provinces:
		if provinces[pid]["owner"] == fid:
			out.append(pid)
	return out


func province_count(fid: int) -> int:
	return provinces_of(fid).size()


func total_army(fid: int) -> int:
	var total := 0
	for pid in provinces:
		if provinces[pid]["owner"] == fid:
			total += provinces[pid]["garrison"]
	return total


func defense_of(pid: int) -> int:
	var p: Dictionary = provinces[pid]
	return p["garrison"] + Rules.BASE_DEFENSE + (Rules.CITY_DEFENSE if p["city"] else 0)


func can_reach(from: int, to: int) -> bool:
	var p: Dictionary = map.province(from)
	if to in p["land"]:
		return true
	return provinces[from]["port"] and to in p["sea"]


func attackable_from(from: int, fid: int) -> Array:
	var out: Array = []
	var p: Dictionary = map.province(from)
	for t in p["land"]:
		if provinces[t]["owner"] != fid:
			out.append(t)
	if provinces[from]["port"]:
		for t in p["sea"]:
			if provinces[t]["owner"] != fid and not (t in out):
				out.append(t)
	return out


# ------------------------------------------------------------------ actions

func validate(a: Dictionary) -> String:
	var player: int = a["player"]
	var gold: int = factions[player]["gold"]
	match a["type"]:
		"build_city", "build_port":
			var cell: Vector2i = a["cell"]
			var pid: int = map.province_at(cell)
			if pid == 0:
				return "Эта земля вне игры" if map.is_void(cell) else "Это вода"
			if pid != a["province"]:
				return "Клетка не в этой провинции"
			if provinces[pid]["owner"] != player:
				return "Это не ваша провинция"
			if a["type"] == "build_city":
				if provinces[pid]["city"]:
					return "Здесь уже есть город"
				if gold < Rules.CITY_COST:
					return "Не хватает золота (нужно %d)" % Rules.CITY_COST
			else:
				if provinces[pid]["port"]:
					return "Здесь уже есть порт"
				if not map.is_coast(cell):
					return "Порт можно строить только на берегу"
				if gold < Rules.PORT_COST:
					return "Не хватает золота (нужно %d)" % Rules.PORT_COST
		"hire":
			var pid: int = a["province"]
			if provinces[pid]["owner"] != player:
				return "Это не ваша провинция"
			if not provinces[pid]["city"]:
				return "Войска нанимаются только в провинции с городом"
			if gold < Rules.HIRE_COST:
				return "Не хватает золота (нужно %d)" % Rules.HIRE_COST
		"attack":
			var from: int = a["from"]
			var to: int = a["to"]
			if from == 0 or to == 0:
				return "Это вода"
			if provinces[from]["owner"] != player:
				return "Атаковать можно только из своей провинции"
			if provinces[to]["owner"] == player:
				return "Это ваша провинция"
			if provinces[from]["garrison"] <= 0:
				return "В провинции нет войск"
			if not can_reach(from, to):
				if to in map.province(from)["sea"]:
					return "Для атаки по морю нужен порт"
				return "Провинции не граничат"
		_:
			return "Неизвестное действие"
	return ""


func apply(a: Dictionary) -> Dictionary:
	var reason := validate(a)
	if reason != "":
		action_rejected.emit(a, reason)
		return {"ok": false, "reason": reason}
	var player: int = a["player"]
	match a["type"]:
		"build_city":
			factions[player]["gold"] -= Rules.CITY_COST
			provinces[a["province"]]["city"] = true
			provinces[a["province"]]["city_cell"] = a["cell"]
			building_placed.emit(a["province"], "city", a["cell"])
			gold_changed.emit(player)
		"build_port":
			factions[player]["gold"] -= Rules.PORT_COST
			provinces[a["province"]]["port"] = true
			provinces[a["province"]]["port_cell"] = a["cell"]
			building_placed.emit(a["province"], "port", a["cell"])
			gold_changed.emit(player)
		"hire":
			factions[player]["gold"] -= Rules.HIRE_COST
			provinces[a["province"]]["garrison"] += Rules.HIRE_STRENGTH
			garrison_changed.emit(a["province"])
			gold_changed.emit(player)
		"attack":
			_resolve_attack(player, a["from"], a["to"])
	action_applied.emit(a)
	return {"ok": true, "reason": ""}


func _resolve_attack(player: int, from: int, to: int) -> void:
	var src: Dictionary = provinces[from]
	var dst: Dictionary = provinces[to]
	var attack_strength: int = Rules.attack_force(src["garrison"])
	var defense_strength: int = defense_of(to)
	var old_owner: int = dst["owner"]
	src["garrison"] -= attack_strength
	var won := attack_strength > defense_strength
	if won:
		dst["owner"] = player
		dst["garrison"] = attack_strength - defense_strength
	else:
		var fortification: int = defense_strength - dst["garrison"]
		dst["garrison"] = maxi(0, dst["garrison"] - maxi(0, attack_strength - fortification))
	var cell: Vector2i = map.province(to)["capital"]
	battles.append({"province": to, "cell": cell, "tick": tick})
	garrison_changed.emit(from)
	garrison_changed.emit(to)
	if won:
		province_captured.emit(to, old_owner, player)
		if province_count(old_owner) == 0 and factions[old_owner]["alive"]:
			factions[old_owner]["alive"] = false
			faction_eliminated.emit(old_owner)
	battle.emit(to, cell, player, old_owner, won, attack_strength, defense_strength)
