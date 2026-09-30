extends RefCounted
## All balance numbers of the territorial game in one place. Times are seconds, rates are per second.

const TICKS_PER_SEC := 10
const TICK_DT := 1.0 / TICKS_PER_SEC
const MATCH_SECONDS := 900               # a match lasts 15 minutes, then the leaderboard decides
const SPAWN_SECONDS := 20                # time to pick a starting point before the human is placed automatically
const HEAT_TICKS := 14                   # freshly captured cells glow for this many ticks

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
const EVENTS := [
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
const MINISTERS := {
	"finance": {"name": "Министр финансов", "desc": "+15% золота", "fee": 3000, "salary": 6.0},
	"general": {"name": "Генерал", "desc": "Фронт продвигается на 20% быстрее", "fee": 4000, "salary": 8.0},
	"diplomat": {"name": "Дипломат", "desc": "Боты нападают на вас заметно реже", "fee": 3500, "salary": 6.0},
	"scientist": {"name": "Учёный", "desc": "Технологии на 20% дешевле", "fee": 3500, "salary": 5.0},
	"propagandist": {"name": "Пропагандист", "desc": "+8 к цели одобрения", "fee": 2500, "salary": 5.0},
}
const MINISTER_ORDER := ["finance", "general", "diplomat", "scientist", "propagandist"]
const FINANCE_BONUS := 0.15
const GENERAL_BONUS := 0.20
const DIPLOMAT_RATIO := 1.6              # bots need this much more of an edge to attack a diplomat's country
const SCIENTIST_DISCOUNT := 0.20
const PROPAGANDIST_APPROVAL := 8.0

const PARTIES := {
	"order": {"name": "Партия порядка", "color": "#F98BA9", "bonus": "+8% роста армии", "who": "казармы, защита, войны, бомбы"},
	"trade": {"name": "Торговый союз", "color": "#F4D77A", "bonus": "+10% золота", "who": "рынки, порты, налоги, торговля"},
	"people": {"name": "Народный фронт", "color": "#B7C96A", "bonus": "+6 к цели одобрения", "who": "низкие налоги, довольный народ"},
	"tech": {"name": "Технократы", "color": "#7FB9E6", "bonus": "−15% к цене технологий", "who": "технологии и города"},
}
const PARTY_ORDER := ["order", "trade", "people", "tech"]
const DUMA_SEATS := 100
const AGITATION_COST := 2000
const AGITATION_WEIGHT := 12.0
const GOV_ORDER_GROWTH := 0.08
const GOV_TRADE_GOLD := 0.10
const GOV_PEOPLE_APPROVAL := 6.0
const GOV_TECH_DISCOUNT := 0.15

const BILLS := {
	"army_reform": {"name": "Военная реформа", "desc": "+10% к лимиту армии", "cost": 5000, "support": ["order", "tech"]},
	"free_trade": {"name": "Свободная торговля", "desc": "+10% золота", "cost": 5000, "support": ["trade", "tech"]},
	"social": {"name": "Социальный пакет", "desc": "+8 к цели одобрения, −5% золота", "cost": 4000, "support": ["people", "trade"]},
	"science": {"name": "Наука в приоритете", "desc": "−20% к цене технологий", "cost": 4000, "support": ["tech", "people"]},
	"emergency": {"name": "Чрезвычайное положение", "desc": "+20% роста армии, −10 к цели одобрения", "cost": 6000, "support": ["order"]},
}
const BILL_ORDER := ["army_reform", "free_trade", "social", "science", "emergency"]
const BILL_MAJORITY := 50
const BILL_ARMY_CAP := 0.10
const BILL_TRADE_GOLD := 0.10
const BILL_SOCIAL_APPROVAL := 8.0
const BILL_SOCIAL_GOLD := -0.05
const BILL_SCIENCE_DISCOUNT := 0.20
const BILL_EMERGENCY_GROWTH := 0.20
const BILL_EMERGENCY_APPROVAL := -10.0

const HISTORY_PERIOD_TICKS := 50         # one statistics sample every 5 s
const HISTORY_MAX := 180                 # 15 minutes of samples

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
