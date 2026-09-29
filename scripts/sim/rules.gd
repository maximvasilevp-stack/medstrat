extends RefCounted
## All balance numbers in one place.

const TICKS_PER_SEC := 10
const TICKS_PER_MONTH := 100          # one game month = 10 real seconds

const START_GOLD_PLAYER := 500
const START_GOLD_BOT := 250

const CITY_COST := 500
const CITY_INCOME := 25
const CITY_DEFENSE := 30
const PORT_COST := 300
const PORT_INCOME := 15
const HIRE_COST := 100
const HIRE_STRENGTH := 50
const BASE_DEFENSE := 20
const KEEP_HOME_RATIO := 0.25         # share of the garrison that stays home during an attack

const BOT_PERIOD := 100               # ticks between two decisions of the same bot
const BOT_AGGRESSION := 1.5           # attack when the force sent >= defense * this
const BOT_HANDICAP := 0.8             # bot income multiplier
const BOT_MAX_HIRES := 2              # hires per decision
const BOT_GRACE_MONTHS := 6           # bots do not attack the human player before this month

const WIN_SHARE := 0.6                # own this share of provinces to win
const BATTLE_MARK_TICKS := 25


## Gold per month for a province of the given size (Malta ~17, Tunisia ~176, Italy ~254, Russia capped ~310).
static func base_income(cells: int) -> int:
	return 10 + int(3.0 * sqrt(minf(float(cells), 10000.0)))


## How many troops leave the province when it attacks.
static func attack_force(garrison: int) -> int:
	return maxi(1, int(ceil(garrison * (1.0 - KEEP_HOME_RATIO))))


## Troops every province starts with (Malta 21, Tunisia 47, Italy 60, Russia 143).
static func start_garrison(cells: int) -> int:
	return 20 + int(sqrt(float(cells)) / 2.0)
