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

# --- gold
const GOLD_BASE := 1.0
const GOLD_PER_CELL := 0.05
const PORT_GOLD := 10.0
const COST_CITY := 2500
const COST_PORT := 4000
const COST_DEFENSE := 3000
const COST_ESCALATION := 0.5             # every building of a kind you own makes the next one this much dearer
const FRONT_JITTER := 100000             # an attack picks the next cell at random among this many front cells (Eden growth = organic blobs)
const DEFENSE_BONUS := 0.5               # each defense level multiplies the cost of taking your cells by (1 + level * this)

# --- combat
const CAPTURE_COST_EMPTY := 3.0          # troops per unclaimed cell for a tiny empire...
const EMPIRE_COST_CELLS := 1000.0        # ...doubling for every this many cells the attacker already owns
const TERRAIN_MULT_SAND := 1.3
const TERRAIN_MULT_SNOW := 2.0
const TERRAIN_MULT_MOUNTAIN := 3.0
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
		_:
			return 1.0


static func max_troops(cells: int, cities: int) -> float:
	return MAX_TROOPS_BASE + cells * MAX_TROOPS_PER_CELL + cities * CITY_MAX_TROOPS


static func growth_per_sec(troops: float, cells: int, cities: int) -> float:
	return troops * (GROWTH_INTEREST + cities * CITY_INTEREST_BONUS) + cells * GROWTH_PER_CELL + GROWTH_BASE


static func gold_per_sec(cells: int, ports: int) -> float:
	return GOLD_BASE + cells * GOLD_PER_CELL + ports * PORT_GOLD


static func attack_rate(troops: float) -> int:
	return clampi(int(sqrt(troops) / ATTACK_RATE_DIV), ATTACK_RATE_MIN, ATTACK_RATE_MAX)


## Cost multiplier that grows with the attacker's empire: expansion slows down as you grow.
static func empire_mult(attacker_cells: int) -> float:
	return 1.0 + attacker_cells / EMPIRE_COST_CELLS
