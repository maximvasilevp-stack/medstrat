extends RefCounted
## A real-world style economy on top of the gold flow.
##
## People: population is a real stock with births, deaths and migration; half of it is the
## workforce, jobs come from land, buildings and cities. Unemployment lowers wages and approval,
## a labour shortage raises wages. Wages are taxed (income tax follows the tax level).
## Goods: food, materials, fuel and luxury are produced (with productivity from technology and
## infrastructure) and consumed; surplus is exported, deficits imported at world prices in your
## own currency. Prices follow world demand versus supply, the business cycle and shocks.
## Money: inflation raises the price level, which multiplies every gold cost; the exchange rate
## of your currency is the world price level over yours. The key rate (neutral 3%) trades growth
## for lower inflation; emission prints money. Debt has a credit rating (AAA..CCC) that sets the
## interest spread and the credit limit; a default halves the debt and angers the people.
## Budget: revenues and expenditures are itemised; a deficit feeds inflation.
## Stock market: every country has an index driven by GDP growth, approval, war and the cycle;
## you can invest the treasury in it. Tariffs tax imports, sanctions squeeze a rival's trade.

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
const LOAN_INTEREST_BASE := 4.0     # % per minute on top of the key rate and the rating spread
const DEFAULT_APPROVAL := 15.0
const CYCLE_MIN_TICKS := 1800
const CYCLE_MAX_TICKS := 3600
const CYCLES := [
	{"key": "steady", "name": "Стабильность", "desc": "мировой спрос обычный", "demand": 1.0, "index": 0.0},
	{"key": "boom", "name": "Мировой подъём", "desc": "спрос +30%, цены и биржи растут, экспорт выгоден", "demand": 1.3, "index": 0.0004},
	{"key": "recession", "name": "Мировая рецессия", "desc": "спрос −30%, цены и биржи падают, импорт дёшев", "demand": 0.7, "index": -0.0006},
]
const SHOCKS := [
	{"good": "food", "mult": 1.6, "text": "Неурожай на континенте: еда дорожает"},
	{"good": "fuel", "mult": 1.8, "text": "Нефтяной шок: топливо дорожает"},
	{"good": "materials", "mult": 1.5, "text": "Строительный бум: материалы дорожают"},
	{"good": "luxury", "mult": 0.6, "text": "Мода прошла: роскошь дешевеет"},
	{"good": "food", "mult": 0.7, "text": "Рекордный урожай: еда дешевеет"},
	{"good": "fuel", "mult": 0.6, "text": "Открыты новые месторождения: топливо дешевеет"},
]
const SHOCK_CHANCE := 0.004          # per second
const SHOCK_TICKS := 900
const CRASH_CHANCE := 0.002          # per second during a recession
const CRASH_DROP := 0.2

# --- people and labour
const BIRTH_RATE := 0.0005           # share of the population per second when fed
const DEATH_RATE := 0.00025
const HUNGER_DEATHS := 0.0015        # extra deaths per second without food
const MIGRATION_RATE := 0.0004       # share per second, scaled by (approval-50)/50
const WORKFORCE_SHARE := 0.5
const WAGE_MIN := 0.6
const WAGE_MAX := 1.6
const WAGE_DRIFT := 0.02
const UNEMPLOYMENT_OK := 0.08        # above this the people get angry
const UNEMPLOYMENT_APPROVAL := 25.0  # approval lost per 100% unemployment above the ok level
const INCOME_TAX_PER_LEVEL := 0.35   # gold per second per 1000 employed per wage unit per tax level
const WELFARE_PER_1000 := 0.15       # gold per second per 1000 unemployed (bills: welfare)

# --- money and credit
const RATINGS := ["AAA", "AA", "A", "BBB", "BB", "B", "CCC"]
const RATING_DEBT := [0.2, 0.5, 0.8, 1.1, 1.5, 2.0]     # debt / (GDP per minute) thresholds
const RATING_SPREAD := [0.0, 0.5, 1.0, 2.0, 3.5, 5.0, 8.0]  # % per minute added to loans
const RATING_LIMIT := [3.0, 2.6, 2.2, 1.8, 1.4, 1.0, 0.6] # credit limit in minutes of gross income
const TARIFF_LEVELS := [0.0, 0.1, 0.2, 0.3]
const TARIFF_RELATION := -4.0        # bots like you less per tariff level
const SANCTION_EXPORT := 0.7         # a sanctioned country's export revenue...
const SANCTION_IMPORT := 1.3         # ...and import prices
const SANCTION_RELATION := 20.0

# --- stock market
const INDEX_START := 100.0
const INDEX_NOISE := 0.0015
const INDEX_WAR := -0.0003           # per running attack
const INDEX_MIN := 5.0

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
		"prod": {}, "cons": {}, "trade_gold": 0.0, "tariff_gold": 0.0,
		"inflation": BASE_INFLATION, "price_level": 1.0, "rate": 3, "emission_heat": 0.0, "emission_cd": 0,
		"debt": 0.0, "defaulted": false, "gdp": 0.0, "gdp_prev": 0.0, "manual_profit": 0.0,
		"pop": -1.0, "wage": 1.0, "unemployment": 0.0, "employed": 0.0, "jobs": {}, "births": 0.0, "deaths": 0.0, "migration": 0.0,
		"index": INDEX_START, "shares": 0.0, "invested": 0.0, "tariff": 0,
	}


static func new_market() -> Dictionary:
	var m := {}
	for g in GOOD_ORDER:
		m[g] = {"price": GOODS[g]["base_price"], "supply": 1.0, "demand": 1.0}
	return {"goods": m, "cycle": 0, "cycle_until": 0, "shock": {}, "avg_price_level": 1.0}


static func price(world, good: String) -> float:
	return float(world.market["goods"][good]["price"])


static func cycle(world) -> Dictionary:
	return CYCLES[int(world.market["cycle"])]


## World price of a good in this country's own money.
static func local_price(world, fid: int, good: String) -> float:
	return price(world, good) * float(world.factions[fid]["econ"]["price_level"]) / maxf(0.1, float(world.market["avg_price_level"]))


## Exchange rate of the country's money against world gold (1.0 = parity).
static func exchange_rate(world, fid: int) -> float:
	return float(world.market["avg_price_level"]) / maxf(0.1, float(world.factions[fid]["econ"]["price_level"]))


static func is_sanctioned(world, fid: int) -> bool:
	for id in range(1, world.factions.size()):
		var f: Dictionary = world.factions[id]
		if id != fid and f["alive"] and f["sanctions"].get(fid, false):
			return true
	return false


# ------------------------------------------------------------------ people and jobs

static func capacity(world, fid: int) -> float:
	var f: Dictionary = world.factions[fid]
	return float(f["cells"]) * 30.0 + float(f["cities"]) * 1500.0 + 200.0


static func jobs(world, fid: int) -> Dictionary:
	var f: Dictionary = world.factions[fid]
	var extra: Dictionary = f["extra"]
	var industrial := 0
	var service := 0
	for k in extra:
		var n: int = int(extra[k])
		match Rules.BUILDINGS[k]["cat"]:
			"econ", "army", "navy", "nature":
				industrial += n
			_:
				service += n
	return {
		"agri": float(f["cells"]) * 4.0 + extra.get("farm", 0) * 150.0 + extra.get("orchard", 0) * 80.0 + extra.get("vineyard", 0) * 80.0,
		"industry": (f["ports"] + f["defense"] + f["barracks"] + f["bunkers"]) * 120.0 + industrial * 150.0 + f["troops"] * 0.05,
		"services": f["cities"] * 400.0 + f["markets"] * 200.0 + service * 120.0 + float(f["cells"]) * 1.2,
	}


## Goods and GDP multiplier from technology and infrastructure.
static func productivity(world, fid: int) -> float:
	var f: Dictionary = world.factions[fid]
	var levels := 0
	for k in f["tech"]:
		levels += int(f["tech"][k])
	var extra: Dictionary = f["extra"]
	var infra: int = extra.get("university", 0) + extra.get("institute", 0) + extra.get("power_plant", 0) + extra.get("toll_road", 0) + extra.get("school", 0)
	var p: float = 1.0 + levels * 0.02 + infra * 0.04 + f["projects_done"].size() * 0.03
	var e: Dictionary = f["econ"]
	if float(e["unemployment"]) > UNEMPLOYMENT_OK:
		p *= 1.0 - (float(e["unemployment"]) - UNEMPLOYMENT_OK) * 0.5
	return maxf(0.5, p)


static func _people_second(world, fid: int, hungry: bool) -> void:
	var f: Dictionary = world.factions[fid]
	var e: Dictionary = f["econ"]
	var pop: float = float(e["pop"])
	var births: float = pop * BIRTH_RATE * (0.4 if hungry else 1.0) * world.mod(fid, "growth")
	var deaths: float = pop * (DEATH_RATE + (HUNGER_DEATHS if hungry else 0.0))
	var migration: float = pop * MIGRATION_RATE * (f["approval"] - 50.0) / 50.0
	if hungry:
		migration -= pop * MIGRATION_RATE
	var prev_u: float = float(e["unemployment"])
	if prev_u > UNEMPLOYMENT_OK:
		migration -= pop * MIGRATION_RATE * (prev_u - UNEMPLOYMENT_OK) * 2.0   # the jobless emigrate
	pop = clampf(pop + births - deaths + migration, 50.0, capacity(world, fid))
	e["pop"] = pop
	e["births"] = births
	e["deaths"] = deaths
	e["migration"] = migration
	# jobs, wages, unemployment
	var j := jobs(world, fid)
	e["jobs"] = j
	var total_jobs: float = float(j["agri"]) + float(j["industry"]) + float(j["services"])
	var workforce: float = pop * WORKFORCE_SHARE
	var employed: float = minf(workforce, total_jobs)
	e["employed"] = employed
	var unemployment: float = 1.0 - employed / maxf(1.0, workforce)
	var was_angry: bool = prev_u > UNEMPLOYMENT_OK
	e["unemployment"] = unemployment
	if (unemployment > UNEMPLOYMENT_OK) != was_angry or (unemployment > UNEMPLOYMENT_OK and absf(unemployment - prev_u) > 0.01):
		f["mods_dirty"] = true
	var wage_target: float = clampf(1.0 + (total_jobs - workforce) / maxf(1.0, workforce), WAGE_MIN, WAGE_MAX)
	e["wage"] = float(e["wage"]) + (wage_target - float(e["wage"])) * WAGE_DRIFT


## Gold per second from income tax on wages.
static func income_tax(f: Dictionary) -> float:
	var e: Dictionary = f["econ"]
	return float(e["employed"]) / 1000.0 * float(e["wage"]) * float(f["tax"]) * INCOME_TAX_PER_LEVEL


## Gold per second of unemployment benefits (only with the welfare bill).
static func welfare_cost(f: Dictionary) -> float:
	if not bool(f["bills"].get("welfare", false)):
		return 0.0
	var e: Dictionary = f["econ"]
	return maxf(0.0, float(e["pop"])) * WORKFORCE_SHARE * float(e["unemployment"]) / 1000.0 * WELFARE_PER_1000


# ------------------------------------------------------------------ goods

## Goods produced per second by one country.
static func production(world, fid: int) -> Dictionary:
	var f: Dictionary = world.factions[fid]
	var res: Dictionary = f["res"]
	var extra: Dictionary = f["extra"]
	var cells: float = float(f["cells"])
	var season_food: float = [1.1, 1.2, 1.3, 0.7][world.season]
	var p := productivity(world, fid)
	var tariff_protect: float = 1.0 + TARIFF_LEVELS[int(f["econ"]["tariff"])] * 0.3
	return {
		"food": (2.0 + cells * 0.03 + res.get(1, 0) * 2.5 + res.get(6, 0) * 1.5 + extra.get("farm", 0) * 3.0 + extra.get("mill", 0) * 2.0 + extra.get("orchard", 0) * 1.5 + extra.get("fish_market", 0) * 2.0 + extra.get("reservoir", 0) * 1.5) * season_food * p * tariff_protect,
		"materials": (1.0 + cells * 0.012 + res.get(2, 0) * 1.5 + res.get(3, 0) * 1.5 + res.get(9, 0) * 1.0 + extra.get("mine", 0) * 3.0 + extra.get("sawmill", 0) * 2.5 + extra.get("quarry", 0) * 2.5 + extra.get("foundry", 0) * 2.0) * p * tariff_protect,
		"fuel": (0.3 + cells * 0.003 + res.get(5, 0) * 3.0 + res.get(7, 0) * 1.0 + extra.get("oil_well", 0) * 4.0 + extra.get("power_plant", 0) * 1.5 + extra.get("windmill", 0) * 0.5) * p,
		"luxury": (0.2 + cells * 0.002 + res.get(8, 0) * 1.5 + res.get(4, 0) * 1.0 + extra.get("casino", 0) * 1.0 + extra.get("vineyard", 0) * 1.5 + extra.get("brewery", 0) * 1.0 + extra.get("theatre", 0) * 0.5) * p,
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
	var wealth: float = float(f["econ"]["wage"])
	return {
		"food": people / 500.0 + f["troops"] / 4000.0,
		"materials": 0.5 + buildings * 0.15 + attacks * 1.0 + f["cells"] * 0.004,
		"fuel": 0.2 + attacks * 0.8 + ships * 2.0 + f["ports"] * 0.3 + f["cells"] * 0.001,
		"luxury": (people / 2500.0 + f["cities"] * 0.3) * wealth,
	}


## Effects of shortages, unemployment, tariffs and the key rate, merged into World.mods_of().
static func mods(f: Dictionary) -> Dictionary:
	var e: Dictionary = f["econ"]
	var m := {}
	for g in GOOD_ORDER:
		if e["shortage"][g]:
			for k in SHORTAGE_MODS[g]:
				m[k] = SHORTAGE_MODS[g][k]
	if e["luxury_ok"]:
		m["approval"] = float(m.get("approval", 0.0)) + LUXURY_BONUS["approval"]
	var u: float = float(e["unemployment"])
	if u > UNEMPLOYMENT_OK:
		m["approval"] = float(m.get("approval", 0.0)) - (u - UNEMPLOYMENT_OK) * UNEMPLOYMENT_APPROVAL
	var rate: int = int(e["rate"]) - RATE_NEUTRAL
	if rate != 0:
		m["growth"] = float(m.get("growth", 1.0)) * (1.0 - rate * RATE_GROWTH)
		m["gold"] = float(m.get("gold", 1.0)) * (1.0 - rate * RATE_GOLD)
	var tariff: int = int(e["tariff"])
	if tariff > 0:
		m["relation"] = float(m.get("relation", 0.0)) + tariff * TARIFF_RELATION
	return m


# ------------------------------------------------------------------ money and credit

static func rating_index(world, fid: int) -> int:
	var e: Dictionary = world.factions[fid]["econ"]
	if e["defaulted"]:
		return RATINGS.size() - 1
	var ratio: float = float(e["debt"]) / maxf(1.0, float(e["gdp"]) * 60.0)
	for i in RATING_DEBT.size():
		if ratio < RATING_DEBT[i]:
			return i
	return RATINGS.size() - 1


static func rating(world, fid: int) -> String:
	return RATINGS[rating_index(world, fid)]


static func credit_limit(world, fid: int) -> float:
	return maxf(2000.0, world.gross_income(fid) * 60.0 * RATING_LIMIT[rating_index(world, fid)])


static func loan_rate(world, fid: int) -> float:
	var e: Dictionary = world.factions[fid]["econ"]
	return LOAN_INTEREST_BASE + float(e["rate"]) + RATING_SPREAD[rating_index(world, fid)]


static func interest_per_sec(world, fid: int) -> float:
	var e: Dictionary = world.factions[fid]["econ"]
	return float(e["debt"]) * loan_rate(world, fid) / 100.0 / 60.0


static func emission_amount(world, fid: int) -> float:
	return maxf(1000.0, float(world.factions[fid]["econ"]["gdp"]) * 60.0 * EMISSION_SHARE)


static func portfolio_value(f: Dictionary) -> float:
	var e: Dictionary = f["econ"]
	return float(e["shares"]) * float(e["index"])


## Itemised state budget per second.
static func budget(world, fid: int) -> Dictionary:
	var breakdown: Dictionary = world.income_breakdown(fid)
	var revenue := {}
	var spending := {}
	for k in breakdown:
		var v: float = float(breakdown[k])
		if v >= 0.0:
			revenue[k] = v
		else:
			spending[k] = -v
	var r := 0.0
	for k in revenue:
		r += revenue[k]
	var s := 0.0
	for k in spending:
		s += spending[k]
	return {"revenue": revenue, "spending": spending, "total_revenue": r, "total_spending": s, "balance": r - s}


# ------------------------------------------------------------------ the tick

## One second of the economy for every living country, then the world market.
static func tick_second(world) -> void:
	var supply := {}
	var demand := {}
	for g in GOOD_ORDER:
		supply[g] = 0.5
		demand[g] = 0.5
	var cyc := cycle(world)
	var shock: Dictionary = world.market["shock"]
	var levels := 0.0
	var countries := 0
	for id in range(1, world.factions.size()):
		var f: Dictionary = world.factions[id]
		if f["kind"] == world.Kind.CITY or not f["alive"]:
			continue
		var e: Dictionary = f["econ"]
		if float(e["pop"]) < 0.0:
			e["pop"] = float(f["cells"]) * 10.0 + float(f["cities"]) * 500.0
		var sanctioned := is_sanctioned(world, id)
		var tariff: float = TARIFF_LEVELS[int(e["tariff"])]
		var fx_mult: float = float(e["price_level"]) / maxf(0.1, float(world.market["avg_price_level"]))
		var prod := production(world, id)
		var cons := consumption(world, id)
		e["prod"] = prod
		e["cons"] = cons
		var trade_gold := 0.0
		var tariff_gold := 0.0
		var changed := false
		var value := 0.0
		for g in GOOD_ORDER:
			var p: float = price(world, g)
			var lp: float = p * fx_mult
			value += prod[g] * p
			supply[g] += prod[g]
			var d_mult: float = cyc["demand"]
			if not shock.is_empty() and shock["good"] == g and world.tick < int(shock["until"]):
				d_mult *= float(shock["mult"])
			demand[g] += cons[g] * d_mult
			var net: float = prod[g] - cons[g]
			var stock: float = float(e["stock"][g]) + net
			var policy: String = e["policy"][g]
			var short := false
			if stock < 0.0:
				var need: float = -stock
				var unit: float = lp * (1.0 + tariff) * (SANCTION_IMPORT if sanctioned else 1.0)
				if policy != "noimport" and f["gold"] >= need * unit:
					f["gold"] -= need * unit
					trade_gold -= need * lp
					tariff_gold += need * lp * tariff
					stock = 0.0
				else:
					stock = 0.0
					short = true
			elif stock > STOCK_CAP and policy != "stock" and policy != "noexport":
				var sell: float = stock - STOCK_CAP
				var gain: float = sell * lp * SELL_DISCOUNT * (SANCTION_EXPORT if sanctioned else 1.0)
				f["gold"] += gain
				trade_gold += gain
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
		e["tariff_gold"] = tariff_gold
		f["gold"] += tariff_gold
		# people
		_people_second(world, id, e["shortage"]["food"])
		# money: inflation drifts to its target, the price level compounds once per game "year" (minute)
		var target: float = BASE_INFLATION + float(e["emission_heat"]) - float(int(e["rate"]) - RATE_NEUTRAL) * RATE_INFLATION
		if world.gold_rate_of(id) < 0.0:
			target += 1.5
		if float(e["unemployment"]) < 0.02:
			target += 0.5      # overheating labour market
		target = maxf(-2.0, target)
		e["inflation"] = float(e["inflation"]) + (target - float(e["inflation"])) * INFLATION_DRIFT
		e["price_level"] = maxf(0.5, float(e["price_level"]) * pow(1.0 + float(e["inflation"]) / 100.0, 1.0 / 60.0))
		e["emission_heat"] = maxf(0.0, float(e["emission_heat"]) - 0.02)
		levels += float(e["price_level"])
		countries += 1
		# debt: interest every second, default above the limit
		if float(e["debt"]) > 0.0:
			var interest := interest_per_sec(world, id)
			f["gold"] = maxf(0.0, f["gold"] - interest)
			var limit := credit_limit(world, id)
			if float(e["debt"]) > limit * 1.5 and not e["defaulted"]:
				e["defaulted"] = true
				f["approval"] = maxf(0.0, f["approval"] - DEFAULT_APPROVAL)
				e["debt"] = float(e["debt"]) * 0.5
				world.economy_event.emit(id, "Дефолт! Кредиторы простили половину долга, одобрение −%d" % int(DEFAULT_APPROVAL))
				if id != world.human:
					world.news_posted.emit("%s объявляет дефолт" % f["name"], "world")
			elif e["defaulted"] and float(e["debt"]) < limit * 0.5:
				e["defaulted"] = false
		# GDP and the stock index
		var gdp: float = maxf(0.0, world.gross_income(id)) + value
		var growth: float = (gdp - float(e["gdp_prev"])) / maxf(1.0, float(e["gdp_prev"]))
		e["gdp_prev"] = float(e["gdp"])
		e["gdp"] = gdp
		var drift: float = clampf(growth * 0.5, -0.003, 0.003) + (f["approval"] - 50.0) / 50.0 * 0.0002 + float(cyc["index"]) + world.attacks_of(id).size() * INDEX_WAR
		var noise: float = (world.rng.randf() - 0.5) * 2.0 * INDEX_NOISE
		e["index"] = maxf(INDEX_MIN, float(e["index"]) * (1.0 + drift + noise))
		if changed:
			f["mods_dirty"] = true
	if countries > 0:
		world.market["avg_price_level"] = levels / countries
	# world prices follow demand / supply, smoothly
	for g in GOOD_ORDER:
		var m: Dictionary = world.market["goods"][g]
		m["supply"] = supply[g]
		m["demand"] = demand[g]
		var target_mult: float = clampf(pow(demand[g] / maxf(0.1, supply[g]), PRICE_ELASTICITY), PRICE_MIN_MULT, PRICE_MAX_MULT)
		var target_price: float = GOODS[g]["base_price"] * target_mult
		m["price"] = float(m["price"]) + (target_price - float(m["price"])) * PRICE_SMOOTH
	# shocks and crashes
	if not shock.is_empty() and world.tick >= int(shock["until"]):
		world.market["shock"] = {}
	elif shock.is_empty() and world.rng.randf() < SHOCK_CHANCE:
		var sh: Dictionary = SHOCKS[world.rng.randi_range(0, SHOCKS.size() - 1)]
		world.market["shock"] = {"good": sh["good"], "mult": sh["mult"], "until": world.tick + SHOCK_TICKS, "text": sh["text"]}
		world.news_posted.emit(sh["text"], "world")
	if int(world.market["cycle"]) == 2 and world.rng.randf() < CRASH_CHANCE:
		for id in range(1, world.factions.size()):
			var f: Dictionary = world.factions[id]
			if f["kind"] != world.Kind.CITY:
				f["econ"]["index"] = maxf(INDEX_MIN, float(f["econ"]["index"]) * (1.0 - CRASH_DROP))
		world.news_posted.emit("Биржевой крах: индексы всех стран −%d%%" % int(CRASH_DROP * 100.0), "world")
	# business cycle
	if world.tick >= int(world.market["cycle_until"]):
		var next: int = world.rng.randi_range(0, CYCLES.size() - 1)
		if next == int(world.market["cycle"]):
			next = (next + 1) % CYCLES.size()
		world.market["cycle"] = next
		world.market["cycle_until"] = world.tick + world.rng.randi_range(CYCLE_MIN_TICKS, CYCLE_MAX_TICKS)
		var c: Dictionary = CYCLES[next]
		world.news_posted.emit("%s: %s" % [c["name"], c["desc"]], "world")
