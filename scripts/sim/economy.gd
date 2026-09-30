extends RefCounted
## A small real-world economy on top of the gold flow.
##
## Goods: every country produces and consumes food, materials, fuel and luxury goods each second.
## Surplus goes to the world market, deficits are bought there; the world price of a good follows
## total demand versus total supply (and the business cycle). Running out of a good hurts:
## no food = hunger, no materials = expensive buildings, no fuel = slow armies and ships.
## Money: inflation raises the price level, which multiplies every gold cost. Printing money
## (emission) gives gold now and inflation later; the key rate fights inflation but slows growth.
## Debt: loans up to a credit limit, interest every second, default when the limit is exceeded.
## GDP = income + value of production, sampled into the history for the charts.

const Rules := preload("res://scripts/sim/rules.gd")
const Resources := preload("res://scripts/sim/resources.gd")

const GOODS := {
	"food": {"name": "Еда", "desc": "Крестьяне, фермы, пшеница и рыба. Едят все: без еды голод и падение одобрения", "base_price": 10.0, "color": "#B7C96A"},
	"materials": {"name": "Материалы", "desc": "Лес, камень, железо, шахты. Нужны стройкам и армии: без них здания дороже", "base_price": 14.0, "color": "#9AA3B0"},
	"fuel": {"name": "Топливо", "desc": "Нефть, уголь и корм для лошадей: питает походы и корабли", "base_price": 18.0, "color": "#3B3B3B"},
	"luxury": {"name": "Роскошь", "desc": "Пряности, вино, золото: народу приятно, без них одобрение ниже", "base_price": 24.0, "color": "#F98BA9"},
}
const GOOD_ORDER := ["food", "materials", "fuel", "luxury"]
const POLICIES := {"auto": "Авто", "stock": "Копить", "noimport": "Не покупать", "noexport": "Не продавать"}
const POLICY_ORDER := ["auto", "stock", "noimport", "noexport"]

const STOCK_CAP := 300.0            # auto policy sells above this much in stock
const SELL_DISCOUNT := 0.85         # exporters get this share of the world price
const PRICE_SMOOTH := 0.04          # world price moves this share toward its target every second
const PRICE_MIN_MULT := 0.35
const PRICE_MAX_MULT := 3.5
const PRICE_ELASTICITY := 0.7
const BASE_INFLATION := 2.0         # % per game "year" (one minute) with sound money
const EMISSION_SHARE := 0.25        # emission prints this share of a minute of GDP...
const EMISSION_INFLATION := 5.0     # ...and adds this much inflation, decaying
const EMISSION_COOLDOWN := 600      # ticks
const RATE_MIN := 0
const RATE_NEUTRAL := 3             # the effects below are relative to this rate
const RATE_MAX := 10
const RATE_INFLATION := 0.6         # each point of the key rate cuts inflation by this
const RATE_GROWTH := 0.012          # and army growth by this share
const RATE_GOLD := 0.006            # and income by this share
const INFLATION_DRIFT := 0.05       # share of the gap to the target closed per second
const LOAN_STEPS := [5000, 20000]
const LOAN_INTEREST_BASE := 4.0     # % per minute on top of the key rate
const CREDIT_MINUTES := 2.5         # credit limit = this many minutes of gross income
const DEFAULT_APPROVAL := 15.0
const CYCLE_MIN_TICKS := 1800
const CYCLE_MAX_TICKS := 3600
const CYCLES := [
	{"key": "steady", "name": "Стабильность", "desc": "мировой спрос обычный", "demand": 1.0},
	{"key": "boom", "name": "Мировой подъём", "desc": "спрос +30%, цены растут, экспорт выгоден", "demand": 1.3},
	{"key": "recession", "name": "Мировая рецессия", "desc": "спрос −30%, цены падают, импорт дёшев", "demand": 0.7},
]

const SHORTAGE_MODS := {
	"food": {"approval": -8.0, "growth": 0.85},
	"materials": {"build_cost": 1.3},
	"fuel": {"attack_rate": 0.85, "ship_speed": 0.8},
	"luxury": {"approval": -3.0},
}
const LUXURY_BONUS := {"approval": 3.0}


static func new_state() -> Dictionary:
	var stock := {}
	var policy := {}
	var shortage := {}
	for g in GOOD_ORDER:
		stock[g] = 60.0
		policy[g] = "auto"
		shortage[g] = false
	return {
		"stock": stock, "policy": policy, "shortage": shortage, "luxury_ok": false,
		"prod": {}, "cons": {}, "trade_gold": 0.0,
		"inflation": BASE_INFLATION, "price_level": 1.0, "rate": 3, "emission_heat": 0.0, "emission_cd": 0,
		"debt": 0.0, "defaulted": false, "gdp": 0.0, "manual_profit": 0.0,
	}


static func new_market() -> Dictionary:
	var m := {}
	for g in GOOD_ORDER:
		m[g] = {"price": GOODS[g]["base_price"], "supply": 1.0, "demand": 1.0}
	return {"goods": m, "cycle": 0, "cycle_until": 0}


static func price(world, good: String) -> float:
	return float(world.market["goods"][good]["price"])


static func cycle(world) -> Dictionary:
	return CYCLES[int(world.market["cycle"])]


## Goods produced per second by one country.
static func production(world, fid: int) -> Dictionary:
	var f: Dictionary = world.factions[fid]
	var res: Dictionary = f["res"]
	var extra: Dictionary = f["extra"]
	var cells: float = float(f["cells"])
	var season_food: float = [1.1, 1.2, 1.3, 0.7][world.season]
	return {
		"food": (2.0 + cells * 0.03 + res.get(1, 0) * 2.5 + res.get(6, 0) * 1.5 + extra.get("farm", 0) * 3.0 + extra.get("mill", 0) * 2.0 + extra.get("orchard", 0) * 1.5 + extra.get("fish_market", 0) * 2.0 + extra.get("reservoir", 0) * 1.5) * season_food,
		"materials": 1.0 + cells * 0.012 + res.get(2, 0) * 1.5 + res.get(3, 0) * 1.5 + res.get(9, 0) * 1.0 + extra.get("mine", 0) * 3.0 + extra.get("sawmill", 0) * 2.5 + extra.get("quarry", 0) * 2.5 + extra.get("foundry", 0) * 2.0,
		"fuel": 0.3 + cells * 0.003 + res.get(5, 0) * 3.0 + res.get(7, 0) * 1.0 + extra.get("oil_well", 0) * 4.0 + extra.get("power_plant", 0) * 1.5 + extra.get("windmill", 0) * 0.5,
		"luxury": 0.2 + cells * 0.002 + res.get(8, 0) * 1.5 + res.get(4, 0) * 1.0 + extra.get("casino", 0) * 1.0 + extra.get("vineyard", 0) * 1.5 + extra.get("brewery", 0) * 1.0 + extra.get("theatre", 0) * 0.5,
	}


## Goods consumed per second by one country.
static func consumption(world, fid: int) -> Dictionary:
	var f: Dictionary = world.factions[fid]
	var people: float = float(world.population_of(fid))
	var buildings: int = f["cities"] + f["ports"] + f["defense"] + f["markets"] + f["barracks"] + f["bunkers"]
	for k in f["extra"]:
		buildings += int(f["extra"][k])
	var attacks: int = world.attacks_of(fid).size()
	var ships: int = world.ships_of(fid).size()
	return {
		"food": people / 500.0 + f["troops"] / 4000.0,
		"materials": 0.5 + buildings * 0.15 + attacks * 1.0 + f["cells"] * 0.004,
		"fuel": 0.2 + attacks * 0.8 + ships * 2.0 + f["ports"] * 0.3 + f["cells"] * 0.001,
		"luxury": people / 2500.0 + f["cities"] * 0.3,
	}


## Effects of shortages and the key rate, merged into World.mods_of().
static func mods(f: Dictionary) -> Dictionary:
	var e: Dictionary = f["econ"]
	var m := {}
	for g in GOOD_ORDER:
		if e["shortage"][g]:
			for k in SHORTAGE_MODS[g]:
				m[k] = SHORTAGE_MODS[g][k]
	if e["luxury_ok"]:
		m["approval"] = float(m.get("approval", 0.0)) + LUXURY_BONUS["approval"]
	var rate: int = int(e["rate"]) - RATE_NEUTRAL
	if rate != 0:
		m["growth"] = float(m.get("growth", 1.0)) * (1.0 - rate * RATE_GROWTH)
		m["gold"] = float(m.get("gold", 1.0)) * (1.0 - rate * RATE_GOLD)
	return m


static func credit_limit(world, fid: int) -> float:
	return maxf(2000.0, world.gross_income(fid) * 60.0 * CREDIT_MINUTES)


static func interest_per_sec(f: Dictionary) -> float:
	var e: Dictionary = f["econ"]
	return float(e["debt"]) * (LOAN_INTEREST_BASE + float(e["rate"])) / 100.0 / 60.0


static func emission_amount(world, fid: int) -> float:
	return maxf(1000.0, float(world.factions[fid]["econ"]["gdp"]) * 60.0 * EMISSION_SHARE)


## One second of the economy for every living country, then the world market.
static func tick_second(world) -> void:
	var supply := {}
	var demand := {}
	for g in GOOD_ORDER:
		supply[g] = 0.5
		demand[g] = 0.5
	var cyc := cycle(world)
	for id in range(1, world.factions.size()):
		var f: Dictionary = world.factions[id]
		if f["kind"] == world.Kind.CITY or not f["alive"]:
			continue
		var e: Dictionary = f["econ"]
		var prod := production(world, id)
		var cons := consumption(world, id)
		e["prod"] = prod
		e["cons"] = cons
		var trade_gold := 0.0
		var changed := false
		var value := 0.0
		for g in GOOD_ORDER:
			var p: float = price(world, g)
			value += prod[g] * p
			supply[g] += prod[g]
			demand[g] += cons[g] * cyc["demand"]
			var net: float = prod[g] - cons[g]
			var stock: float = float(e["stock"][g]) + net
			var policy: String = e["policy"][g]
			var short := false
			if stock < 0.0:
				var need: float = -stock
				if policy != "noimport" and f["gold"] >= need * p:
					f["gold"] -= need * p
					trade_gold -= need * p
					stock = 0.0
				else:
					stock = 0.0
					short = true
			elif stock > STOCK_CAP and policy != "stock" and policy != "noexport":
				var sell: float = stock - STOCK_CAP
				f["gold"] += sell * p * SELL_DISCOUNT
				trade_gold += sell * p * SELL_DISCOUNT
				stock = STOCK_CAP
			e["stock"][g] = stock
			if e["shortage"][g] != short:
				e["shortage"][g] = short
				changed = true
		var lux_ok: bool = float(e["stock"]["luxury"]) > 20.0 and not e["shortage"]["luxury"]
		if e["luxury_ok"] != lux_ok:
			e["luxury_ok"] = lux_ok
			changed = true
		e["trade_gold"] = trade_gold
		# money: inflation drifts to its target, the price level compounds once per game "year" (minute)
		var target: float = BASE_INFLATION + float(e["emission_heat"]) - float(int(e["rate"]) - RATE_NEUTRAL) * RATE_INFLATION
		if world.gold_rate_of(id) < 0.0:
			target += 1.5
		target = maxf(-2.0, target)
		e["inflation"] = float(e["inflation"]) + (target - float(e["inflation"])) * INFLATION_DRIFT
		e["price_level"] = maxf(0.5, float(e["price_level"]) * pow(1.0 + float(e["inflation"]) / 100.0, 1.0 / 60.0))
		e["emission_heat"] = maxf(0.0, float(e["emission_heat"]) - 0.02)
		# debt: interest every second, default above the limit
		if float(e["debt"]) > 0.0:
			var interest := interest_per_sec(f)
			f["gold"] = maxf(0.0, f["gold"] - interest)
			var limit := credit_limit(world, id)
			if float(e["debt"]) > limit * 1.5 and not e["defaulted"]:
				e["defaulted"] = true
				f["approval"] = maxf(0.0, f["approval"] - DEFAULT_APPROVAL)
				e["debt"] = float(e["debt"]) * 0.5
				world.economy_event.emit(id, "Дефолт! Кредиторы простили половину долга, одобрение −%d" % int(DEFAULT_APPROVAL))
			elif e["defaulted"] and float(e["debt"]) < limit * 0.5:
				e["defaulted"] = false
		e["gdp"] = maxf(0.0, world.gross_income(id)) + value
		if changed:
			f["mods_dirty"] = true
	# world prices follow demand / supply, smoothly
	for g in GOOD_ORDER:
		var m: Dictionary = world.market["goods"][g]
		m["supply"] = supply[g]
		m["demand"] = demand[g]
		var target_mult: float = clampf(pow(demand[g] / maxf(0.1, supply[g]), PRICE_ELASTICITY), PRICE_MIN_MULT, PRICE_MAX_MULT)
		var target_price: float = GOODS[g]["base_price"] * target_mult
		m["price"] = float(m["price"]) + (target_price - float(m["price"])) * PRICE_SMOOTH
	# business cycle
	if world.tick >= int(world.market["cycle_until"]):
		var next: int = world.rng.randi_range(0, CYCLES.size() - 1)
		if next == int(world.market["cycle"]):
			next = (next + 1) % CYCLES.size()
		world.market["cycle"] = next
		world.market["cycle_until"] = world.tick + world.rng.randi_range(CYCLE_MIN_TICKS, CYCLE_MAX_TICKS)
		var c: Dictionary = CYCLES[next]
		world.news_posted.emit("%s: %s" % [c["name"], c["desc"]], "world")
