extends RefCounted
## All balance numbers of the territorial game in one place. Times are seconds, rates are per second.

const TICKS_PER_SEC := 10
const TICK_DT := 1.0 / TICKS_PER_SEC
const WIN_LAND_SHARE := 0.35             # no clock: the match ends when someone holds this share of the land (or stands alone)...
const WIN_LEAD_SHARE := 0.2              # ...or holds this much and twice the land of the runner-up...
const WIN_LEAD_RATIO := 2.0
const WIN_LEAD_SECONDS := 60             # ...for this long (an undisputed leader)
const SPAWN_SECONDS := 20                # time to pick a starting point before the human is placed automatically
const HEAT_TICKS := 14                   # freshly captured cells glow for this many ticks
const SEASON_SECONDS := 120              # spring, summer, autumn, winter, each this long
const SEASONS := [
	{"name": "Весна", "desc": "+5% роста армии", "mods": {"growth": 1.05}, "tint": "#B7C96A"},
	{"name": "Лето", "desc": "+8% золота, корабли на 10% быстрее", "mods": {"gold": 1.08, "ship_speed": 1.1}, "tint": "#F4D77A"},
	{"name": "Осень", "desc": "Урожай: +2 одобрение, +3% золота", "mods": {"approval": 2.0, "gold": 1.03}, "tint": "#FF8F45"},
	{"name": "Зима", "desc": "−8% роста, корабли на 15% медленнее, снег и горы дороже", "mods": {"growth": 0.92, "ship_speed": 0.85}, "tint": "#7FB9E6"},
]
const WINTER_TERRAIN_MULT := 1.3          # capture cost on snow and mountains in winter

# --- spawning
const NUM_BOTS := 12
const NUM_CITY_STATES := 30
const SPAWN_RADIUS := 5                  # radius in cells of a player's starting blob
const START_TROOPS := 400
const START_GOLD := 1500                 # the human starts with this much gold...
const SPAWN_COST := 500                  # ...and pays this when placing the capital
const BOT_START_GOLD := 1000
const CITY_STATE_RADIUS_MIN := 4
const CITY_STATE_RADIUS_MAX := 7
const CITY_STATE_TROOPS_MIN := 800
const CITY_STATE_TROOPS_MAX := 2500
const MIN_SPAWN_DISTANCE := 26           # cells between any two starting blobs

# --- troops
const GROWTH_INTEREST := 0.012           # troops grow by this share of themselves per second
const GROWTH_PER_CELL := 0.06
const GROWTH_BASE := 10.0
const MAX_TROOPS_BASE := 300.0
const MAX_TROOPS_PER_CELL := 6.0
const CITY_MAX_TROOPS := 1500.0          # every city raises the troop cap
const CITY_INTEREST_BONUS := 0.005       # and the interest rate
const CITY_STATE_INTEREST := 0.004
const CITY_STATE_MAX_MULT := 1.5

# --- gold and buildings
const GOLD_BASE := 1.0
const GOLD_PER_CELL := 0.05
const PORT_GOLD := 10.0
const COST_CITY := 2500
const COST_PORT := 4000
const COST_DEFENSE := 3000
const DEFENSE_BONUS := 0.5               # each defense level multiplies the cost of taking your cells by (1 + level * this)
const COST_MARKET := 3500
const MARKET_GOLD := 12.0                # gold per second per market
const COST_BARRACKS := 3000
const BARRACKS_CAP := 800.0              # troop cap per barracks
const BARRACKS_INTEREST := 0.003         # extra growth rate per barracks
const COST_BUNKER := 6000
const BUNKER_RADIUS := 16                # nukes landing this close to a bunker are shot down
const COST_ESCALATION := 0.5             # every building of a kind you own makes the next one this much dearer
const FRONT_JITTER := 100000             # an attack picks the next cell at random among this many front cells (Eden growth = organic blobs)

# --- technologies (researched with gold, see world.apply "research")
const TECHS := {
	"trade": {"name": "Торговля", "desc": "+25% золота за уровень", "max": 3, "costs": [3000, 6000, 12000], "req": ""},
	"conscription": {"name": "Призыв", "desc": "+0.3% роста армии в секунду за уровень", "max": 3, "costs": [4000, 8000, 16000], "req": ""},
	"logistics": {"name": "Логистика", "desc": "Захват любой земли дешевле на 15% за уровень", "max": 3, "costs": [4000, 8000, 16000], "req": ""},
	"fortification": {"name": "Фортификация", "desc": "Ваши клетки дороже врагу на 20% за уровень", "max": 3, "costs": [3500, 7000, 14000], "req": ""},
	"tactics": {"name": "Тактика", "desc": "Фронт продвигается на 25% быстрее за уровень", "max": 2, "costs": [5000, 10000], "req": ""},
	"navigation": {"name": "Навигация", "desc": "Корабли на 50% быстрее и дальше за уровень", "max": 2, "costs": [4000, 8000], "req": ""},
	"nuclear": {"name": "Ядерная программа", "desc": "Открывает ядерную бомбу", "max": 1, "costs": [15000], "req": ""},
	"rockets": {"name": "Ракеты", "desc": "Бомбы летят вдвое быстрее, открывает MEGA NUKE", "max": 1, "costs": [30000], "req": "nuclear"},
}
const TECH_ORDER := ["trade", "conscription", "logistics", "fortification", "tactics", "navigation", "nuclear", "rockets"]
const TRADE_BONUS := 0.25
const CONSCRIPTION_BONUS := 0.003
const LOGISTICS_BONUS := 0.15
const FORTIFICATION_BONUS := 0.20
const TACTICS_BONUS := 0.25
const NAVIGATION_BONUS := 0.5
const ADMIN_CODE := "666"

# --- people and politics
const APPROVAL_START := 60.0
const APPROVAL_DRIFT := 0.05             # share of the gap to the target closed every second
const APPROVAL_BASE_TARGET := 60.0
const TAX_APPROVAL := 12.0               # target approval lost per tax level
const TAX_GOLD_PER_CELL := 0.012         # gold per second per cell per tax level
const MARKET_APPROVAL := 2.0             # target approval per market (capped)
const CITY_APPROVAL := 1.0
const BUILDING_APPROVAL_CAP := 15.0
const WAR_WEARINESS := 4.0               # target approval lost per running attack (capped)
const WAR_WEARINESS_CAP := 12.0
const NUKE_APPROVAL_HIT := 12.0          # immediate approval loss for launching a nuke
const APPROVAL_GROWTH_MIN := 0.6         # growth multiplier at 0% approval...
const APPROVAL_GROWTH_MAX := 1.4         # ...and at 100%
const UNREST_APPROVAL := 25.0            # below this the people start leaving
const UNREST_PERIOD_TICKS := 30
const UNREST_CELLS_PER := 500            # one cell lost per this many cells (plus one)
const ELECTION_PERIOD := 180.0           # seconds between elections
const ELECTION_WIN_APPROVAL := 50.0
const ELECTION_WIN_BONUS := 8.0          # approval gained after a win
const ELECTION_LOSS_TICKS := 600         # penalty length after a lost election
const ELECTION_LOSS_GROWTH := 0.5
const ELECTION_LOSS_GOLD := 0.7
const ELECTION_LOSS_APPROVAL := 45.0     # approval reset after a loss
const PROPAGANDA_COST := 1500
const PROPAGANDA_APPROVAL := 12.0
const PROPAGANDA_COOLDOWN_TICKS := 450
const FESTIVAL_COST := 3000
const FESTIVAL_APPROVAL := 20.0
const FESTIVAL_TICKS := 600              # growth bonus length
const FESTIVAL_GROWTH := 1.1
const FESTIVAL_COOLDOWN_TICKS := 1200
const MOBILIZE_SHARE := 0.15             # troops gained as a share of the cap
const MOBILIZE_APPROVAL := 15.0
const MOBILIZE_COOLDOWN_TICKS := 900
const EVENT_MIN_TICKS := 600             # random events for the human every 60-120 s
const EVENT_MAX_TICKS := 1200
const EVENT_TIMEOUT_TICKS := 300         # first option is taken if the player does not answer
const BOT_PROPAGANDA_APPROVAL := 40.0

## Random events: title, text, two choices with effects. Effects: gold, approval, troops_share, tech.
const BASE_EVENTS := [
	{"title": "Засуха", "text": "Неурожай в провинциях. Крестьяне просят помощи из казны.",
		"choices": [{"text": "Помочь (−2000 золота, +10 одобрение)", "gold": -2000, "approval": 10},
			{"text": "Пусть справляются сами (−10 одобрение)", "approval": -10}]},
	{"title": "Мятеж на границе", "text": "Гарнизон дальней провинции отказывается подчиняться.",
		"choices": [{"text": "Подавить (−10% войск, −5 одобрение)", "troops_share": -0.10, "approval": -5},
			{"text": "Уступить требованиям (−1500 золота, +5 одобрение)", "gold": -1500, "approval": 5}]},
	{"title": "Купцы просят снизить пошлины", "text": "Гильдии обещают поддержку, если налоги станут мягче.",
		"choices": [{"text": "Снизить налоги на уровень (+8 одобрение)", "tax": -1, "approval": 8},
			{"text": "Отказать (+1500 золота, −5 одобрение)", "gold": 1500, "approval": -5}]},
	{"title": "Учёные просят грант", "text": "Академия обещает прорыв, если оплатить исследования.",
		"choices": [{"text": "Выделить 4000 золота (случайная технология +1)", "gold": -4000, "tech": 1},
			{"text": "Отказать", "approval": -2}]},
	{"title": "Эпидемия", "text": "В городах вспышка болезни.",
		"choices": [{"text": "Карантин (−15% войск, +5 одобрение)", "troops_share": -0.15, "approval": 5},
			{"text": "Игнорировать (−8% войск, −10 одобрение)", "troops_share": -0.08, "approval": -10}]},
	{"title": "Беженцы у границ", "text": "Тысячи людей просят убежища.",
		"choices": [{"text": "Принять (+8% войск, −5 одобрение)", "troops_share": 0.08, "approval": -5},
			{"text": "Отказать (+3 одобрение)", "approval": 3}]},
	{"title": "Богатый урожай", "text": "Амбары полны. Как распорядиться излишками?",
		"choices": [{"text": "Продать (+3000 золота)", "gold": 3000},
			{"text": "Раздать народу (+12 одобрение)", "approval": 12}]},
	{"title": "Генералы требуют войны", "text": "Штаб настаивает на всеобщей мобилизации.",
		"choices": [{"text": "Мобилизация (+20% войск, −10 одобрение)", "troops_share": 0.20, "approval": -10},
			{"text": "Отказать генералам (+4 одобрение)", "approval": 4}]},
]

# --- government: ministers, parliament (Duma), bills, statistics
const PLAYER_COLORS := ["#F98BA9", "#FF8F45", "#F4D77A", "#B7C96A", "#7FB9E6", "#D6BEEA"]
const Content := preload("res://scripts/sim/content.gd")
const MINISTERS := Content.MINISTERS
const MINISTER_ORDER := Content.MINISTER_ORDER
const FINANCE_BONUS := 0.15
const GENERAL_BONUS := 0.20
const DIPLOMAT_RATIO := 1.6              # bots need this much more of an edge per point of "diplomacy"
const SCIENTIST_DISCOUNT := 0.20
const PARTIES := Content.PARTIES
const PARTY_ORDER := Content.PARTY_ORDER
const DUMA_SEATS := 100
const AGITATION_COST := 2000
const AGITATION_WEIGHT := 12.0
const BILLS := Content.BILLS
const BILL_ORDER := Content.BILL_ORDER
const BILL_MAJORITY := 50
const BUILDINGS := Content.BUILDINGS
const BUILDING_ORDER := Content.BUILDING_ORDER
const EXTRA_TECHS := Content.EXTRA_TECHS
const EXTRA_TECH_ORDER := Content.EXTRA_TECH_ORDER
const BUDGET := Content.BUDGET
const BUDGET_ORDER := Content.BUDGET_ORDER
const BUDGET_COST_PER_CELL := Content.BUDGET_COST_PER_CELL
const BUDGET_MAX := Content.BUDGET_MAX
const EXTRA_DECREES := Content.EXTRA_DECREES
const EXTRA_DECREE_ORDER := Content.EXTRA_DECREE_ORDER
const REFORMS := Content.REFORMS
const REFORM_ORDER := Content.REFORM_ORDER
const REFORM_COST := Content.REFORM_COST
const REFORM_APPROVAL_HIT := Content.REFORM_APPROVAL_HIT
const PROJECTS := Content.PROJECTS
const PROJECT_ORDER := Content.PROJECT_ORDER
const PROJECT_MAX_ACTIVE := Content.PROJECT_MAX_ACTIVE
const CATEGORIES := Content.CATEGORIES
const CATEGORY_ORDER := Content.CATEGORY_ORDER
const RELATION_START := Content.RELATION_START
const RELATION_DRIFT := Content.RELATION_DRIFT
const RELATION_ATTACK_HIT := Content.RELATION_ATTACK_HIT
const RELATION_GIFT := Content.RELATION_GIFT
const GIFT_COST := Content.GIFT_COST
const GIFT_COST_PER_CELL := Content.GIFT_COST_PER_CELL
const PACT_COST := Content.PACT_COST
const PACT_COST_PER_CELL := Content.PACT_COST_PER_CELL
const PACT_MIN_RELATION := Content.PACT_MIN_RELATION
const PACT_SECONDS := Content.PACT_SECONDS
const RELATION_ATTACK_SCALE := Content.RELATION_ATTACK_SCALE

const HISTORY_PERIOD_TICKS := 50         # one statistics sample every 5 s
const HISTORY_MAX := 360                 # 30 minutes of samples

const EVENTS := BASE_EVENTS + Content.EXTRA_EVENTS

# --- combat
const CAPTURE_COST_EMPTY := 3.0          # troops per unclaimed cell for a tiny empire...
const EMPIRE_COST_CELLS := 1000.0        # ...doubling for every this many cells the attacker already owns
const TERRAIN_MULT_SAND := 1.3
const TERRAIN_MULT_SNOW := 2.0
const TERRAIN_MULT_MOUNTAIN := 3.0
const TERRAIN_MULT_FOREST := 1.2
const TERRAIN_MULT_HILLS := 1.5
const DEFENDER_LOSS := 0.5               # defenders lose this share of the attacker's spending
const ATTACK_MIN_TROOPS := 10.0
const ATTACK_RATE_MIN := 1               # cells per tick an attack advances at least
const ATTACK_RATE_MAX := 6
const ATTACK_RATE_DIV := 6.0             # cells per tick = sqrt(troops) / this
const NAVAL_REACH := 150.0               # max distance (cells) of a naval landing from your coast
const SHIP_SPEED := 4.0                  # cells per tick a landing ship travels
const NUKE_COST := 20000
const MEGA_NUKE_COST := 80000
const NUKE_RADIUS := 10
const MEGA_NUKE_RADIUS := 18
const NUKE_FLIGHT_TICKS := 30
const NUKE_TROOP_FACTOR := 1.0           # defenders lose troops = cells lost * their density * this
const SCORCH_TICKS := 900                # scorched land stays scorched for 90 s
const SCORCH_COST_MULT := 2.0            # and costs this much more to capture
const DEFAULT_ATTACK_SIZE := 0.33

# --- bots
const BOT_PERIOD_TICKS := 30
const BOT_GRACE_SECONDS := 60            # bots do not attack the human before this
const BOT_MIN_TROOPS_SHARE := 0.35       # share of the cap before a bot expands into empty land
const BOT_ENEMY_TROOPS_SHARE := 0.5      # share of the cap before a bot attacks someone
const BOT_RATIO_EMPTY := 0.4
const BOT_RATIO_ENEMY := 0.6
const BOT_RETALIATE_SHARE := 0.3         # attacked bots strike back at this share of the cap
const BOT_RATIO_RETALIATE := 0.4
const BOT_NUKE_CHANCE := 0.25            # per decision, when a nuke is affordable and a big neighbour exists
const BOT_NAVAL_CHANCE := 0.5
const DIFFICULTIES := [
	{"name": "Лёгкая", "desc": "Боты вдвое слабее, первые 3 минуты вас не трогают", "bot_growth": 0.55, "bot_gold": 0.6, "grace": 180, "xp": 0.6},
	{"name": "Обычная", "desc": "Боты чуть слабее вас, полторы минуты не нападают", "bot_growth": 0.8, "bot_gold": 0.85, "grace": 90, "xp": 1.0},
	{"name": "Сложная", "desc": "Боты равны вам и нападают через 45 с", "bot_growth": 1.0, "bot_gold": 1.05, "grace": 45, "xp": 1.5},
	{"name": "Кошмар", "desc": "Боты на 40% сильнее, пощады нет с первой секунды", "bot_growth": 1.4, "bot_gold": 1.5, "grace": 0, "xp": 2.5},
]
## Bot personalities: multipliers on appetite. enemy_share = troop share before attacking someone,
## ratio = share of the army sent, nuke/build/naval scale chances, defense_max = defense levels built.
const PERSONAS := {
	"aggressor": {"name": "агрессор", "desc": "нападает раньше и большими силами", "enemy_share": 0.4, "ratio": 0.75, "nuke": 1.6, "build": 0.7, "naval": 0.5, "defense_max": 2, "retaliate": 0.7},
	"trader": {"name": "торговец", "desc": "строит и торгует, воюет неохотно", "enemy_share": 0.65, "ratio": 0.5, "nuke": 0.5, "build": 2.0, "naval": 0.4, "defense_max": 3, "retaliate": 1.0},
	"turtle": {"name": "черепаха", "desc": "обороняется и редко нападает", "enemy_share": 0.8, "ratio": 0.45, "nuke": 0.3, "build": 1.2, "naval": 0.2, "defense_max": 6, "retaliate": 0.8},
	"explorer": {"name": "мореход", "desc": "любит высадки с моря", "enemy_share": 0.55, "ratio": 0.6, "nuke": 0.8, "build": 1.0, "naval": 1.2, "defense_max": 3, "retaliate": 1.0},
	"schemer": {"name": "интриган", "desc": "бомбы, шпионы и подкуп", "enemy_share": 0.55, "ratio": 0.6, "nuke": 2.0, "build": 1.0, "naval": 0.5, "defense_max": 3, "retaliate": 1.0},
}
const PERSONA_ORDER := ["aggressor", "trader", "turtle", "explorer", "schemer"]
const PERSONA_TAUNTS := {
	"aggressor": ["Твои земли будут моими!", "Сопротивление бесполезно.", "Я иду за тобой."],
	"trader": ["Ничего личного, это бизнес.", "Твои порты мне пригодятся.", "Сделка отменяется."],
	"turtle": ["Ты подошёл слишком близко.", "Это оборонительная операция.", "Больше так не делай."],
	"explorer": ["Море привело меня к тебе.", "Новые берега зовут.", "Высадка начинается!"],
	"schemer": ["Всё идёт по плану.", "Ты даже не заметил, как это началось.", "Шах и мат."],
}

# --- catch-up: a human far behind the leader gets a hand
const CATCH_UP_AFTER := 120.0            # seconds into the match
const CATCH_UP_RATIO := 0.5              # when the human holds less than this share of the leader's land...
const CATCH_UP_MODS := {"growth": 1.15, "gold": 1.15}   # ...these multipliers apply

## Wonders of the world: unique, one per world, the first to build it keeps it (capturing the cell takes it over).
const WONDERS := {
	"pyramids": {"name": "Пирамиды", "desc": "+10% к лимиту армии, +3 одобрение", "cost": 15000, "coast": false, "party": "empire", "mods": {"cap": 1.10, "approval": 3.0}},
	"colossus": {"name": "Колосс", "desc": "Корабли на 25% быстрее и дальше (на берегу)", "cost": 14000, "coast": true, "party": "trade", "mods": {"ship_speed": 1.25, "naval_reach": 1.25}},
	"great_library": {"name": "Великая библиотека", "desc": "Технологии на 20% дешевле", "cost": 16000, "coast": false, "party": "tech", "mods": {"tech_cost": 0.80}},
	"colosseum": {"name": "Колизей", "desc": "+8 одобрение, +5 на выборах", "cost": 15000, "coast": false, "party": "people", "mods": {"approval": 8.0, "election": 5.0}},
	"pharos": {"name": "Александрийский маяк", "desc": "+6% золота, корабли на 15% дальше (на берегу)", "cost": 13000, "coast": true, "party": "trade", "mods": {"gold": 1.06, "naval_reach": 1.15}},
	"gardens": {"name": "Висячие сады", "desc": "+8% роста армии, +4 одобрение", "cost": 15000, "coast": false, "party": "green", "mods": {"growth": 1.08, "approval": 4.0}},
	"artemis": {"name": "Храм Артемиды", "desc": "+6 одобрение, волнения намного позже", "cost": 12000, "coast": false, "party": "people", "mods": {"approval": 6.0, "unrest": -6.0}},
	"mausoleum": {"name": "Мавзолей", "desc": "+6 на выборах, зарплаты на 10% меньше", "cost": 12000, "coast": false, "party": "order", "mods": {"election": 6.0, "salary_mult": 0.9}},
	"oracle": {"name": "Оракул", "desc": "Отношения со всеми +10, боты нападают реже", "cost": 13000, "coast": false, "party": "green", "mods": {"relation": 10.0, "diplomacy": 0.5}},
	"forge": {"name": "Кузница богов", "desc": "+15% к защите, фронт на 10% быстрее", "cost": 18000, "coast": false, "party": "order", "mods": {"defense": 1.15, "attack_rate": 1.10}},
}
const WONDER_ORDER := ["pyramids", "colossus", "great_library", "colosseum", "pharos", "gardens", "artemis", "mausoleum", "oracle", "forge"]

# --- diplomacy 2: trade, alliances, vassals, espionage
const TRADE_COST := 1500
const TRADE_SECONDS := 300
const TRADE_MIN_RELATION := 50.0
const TRADE_INCOME_BASE := 3.0           # gold per second per partner...
const TRADE_INCOME_PER_CELL := 0.02      # ...plus this per partner cell
const ALLIANCE_COST := 4000
const ALLIANCE_MIN_RELATION := 75.0
const VASSAL_RATIO := 4.0                # you need this many times their land
const VASSAL_MIN_RELATION := 30.0
const VASSAL_TRIBUTE := 0.10             # share of the vassal's income paid to the overlord
const SPY_OPS := {
	"sabotage": {"name": "Саботаж", "desc": "Цель теряет 10% войск", "cost": 3000, "chance": 0.6},
	"steal_tech": {"name": "Кража технологии", "desc": "Получите уровень технологии, которая есть у цели", "cost": 5000, "chance": 0.5},
	"incite": {"name": "Подстрекательство", "desc": "−15 одобрения у цели", "cost": 2500, "chance": 0.65},
	"assassinate": {"name": "Устранение министра", "desc": "Цель теряет случайного министра", "cost": 4000, "chance": 0.5},
	"arson": {"name": "Поджог", "desc": "Цель теряет случайную постройку", "cost": 3500, "chance": 0.55},
	"bribe": {"name": "Подкуп генералов", "desc": "Цель отзывает атаку на вас", "cost": 4500, "chance": 0.6},
}
const SPY_OP_ORDER := ["sabotage", "steal_tech", "incite", "assassinate", "arson", "bribe"]
const SPY_COOLDOWN_TICKS := 200
const SPY_FAIL_RELATION := 15.0
const SPY_MINISTER_BONUS := 0.15         # your spy chief adds this to the chance, theirs subtracts 0.2
const SPY_COUNTER_MALUS := 0.2


static func terrain_mult(terrain: int) -> float:
	match terrain:
		3:
			return TERRAIN_MULT_SAND
		4:
			return TERRAIN_MULT_SNOW
		5:
			return TERRAIN_MULT_MOUNTAIN
		9:
			return TERRAIN_MULT_FOREST
		10:
			return TERRAIN_MULT_HILLS
		_:
			return 1.0


static func max_troops(cells: int, cities: int) -> float:
	return MAX_TROOPS_BASE + cells * MAX_TROOPS_PER_CELL + cities * CITY_MAX_TROOPS


static func growth_per_sec(troops: float, cells: int, cities: int, extra_interest: float = 0.0) -> float:
	return troops * (GROWTH_INTEREST + cities * CITY_INTEREST_BONUS + extra_interest) + cells * GROWTH_PER_CELL + GROWTH_BASE


static func gold_per_sec(cells: int, ports: int) -> float:
	return GOLD_BASE + cells * GOLD_PER_CELL + ports * PORT_GOLD


static func attack_rate(troops: float) -> int:
	return clampi(int(sqrt(troops) / ATTACK_RATE_DIV), ATTACK_RATE_MIN, ATTACK_RATE_MAX)


## Cost multiplier that grows with the attacker's empire: expansion slows down as you grow.
static func empire_mult(attacker_cells: int) -> float:
	return 1.0 + attacker_cells / EMPIRE_COST_CELLS
