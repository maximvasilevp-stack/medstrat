extends Node
## Autoload: persistent player settings and profile (user://settings.cfg), screen scaling for
## web / small screens, and the hand-off of "load the saved match" between scenes.

const PATH := "user://settings.cfg"
const MOBILE_WIDTH := 900.0
const TITLES := [[1, "Новобранец"], [3, "Староста"], [5, "Воевода"], [8, "Князь"], [12, "Герцог"], [17, "Король"], [23, "Император"], [30, "Легенда"]]

var nickname := "Игрок"
var muted := false
var color_index := 0
var mobile := false            # small screen: compact HUD layout
var difficulty := 1            # index into Rules.DIFFICULTIES
var scenario := "free"         # key in Scenarios.LIST
var load_save := false         # the game scene should load user://save.bin instead of a new match
var spectate := false          # start the next match as an observer (the AI runs your country)
var adaptive := true           # bots get stronger after your wins and weaker after losses
var bot_tuning := 1.0          # the learned multiplier (0.6 .. 1.5)
var bot_memory: Dictionary = {}  # persona -> {matches, share_sum}: how each bot character fared

# --- profile
var xp := 0
var unlocked: Dictionary = {}  # achievement key -> true
var stats: Dictionary = {"matches": 0, "wins": 0, "best_share": 0.0, "missions": 0}


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		nickname = str(cfg.get_value("player", "nickname", nickname))
		muted = bool(cfg.get_value("audio", "muted", muted))
		color_index = int(cfg.get_value("player", "color", color_index))
		difficulty = int(cfg.get_value("player", "difficulty", difficulty))
		scenario = str(cfg.get_value("player", "scenario", scenario))
		xp = int(cfg.get_value("profile", "xp", xp))
		unlocked = cfg.get_value("profile", "unlocked", {})
		stats = cfg.get_value("profile", "stats", stats)
		adaptive = bool(cfg.get_value("ai", "adaptive", adaptive))
		bot_tuning = float(cfg.get_value("ai", "bot_tuning", bot_tuning))
		bot_memory = cfg.get_value("ai", "bot_memory", {})
	_apply_scaling()
	get_window().size_changed.connect(_apply_scaling)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "nickname", nickname)
	cfg.set_value("player", "color", color_index)
	cfg.set_value("player", "difficulty", difficulty)
	cfg.set_value("player", "scenario", scenario)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("profile", "xp", xp)
	cfg.set_value("profile", "unlocked", unlocked)
	cfg.set_value("profile", "stats", stats)
	cfg.set_value("ai", "adaptive", adaptive)
	cfg.set_value("ai", "bot_tuning", bot_tuning)
	cfg.set_value("ai", "bot_memory", bot_memory)
	cfg.save(PATH)


## Bots learn between matches: the player's wins make them bolder, losses make them gentler,
## and the characters that grabbed the most land get picked a little more often.
func learn_from_match(won: bool, persona_shares: Dictionary) -> void:
	if adaptive:
		bot_tuning = clampf(bot_tuning * (1.08 if won else 0.93), 0.6, 1.5)
	for persona in persona_shares:
		var m: Dictionary = bot_memory.get(persona, {"matches": 0, "share_sum": 0.0})
		m["matches"] = int(m["matches"]) + 1
		m["share_sum"] = float(m["share_sum"]) + float(persona_shares[persona])
		bot_memory[persona] = m


func persona_weights() -> Dictionary:
	var w := {}
	for persona in bot_memory:
		var m: Dictionary = bot_memory[persona]
		var avg: float = float(m["share_sum"]) / maxf(1.0, float(m["matches"]))
		w[persona] = 1.0 + clampf(avg * 8.0, 0.0, 1.5)
	return w


# --- profile helpers

static func level_of(points: int) -> int:
	return 1 + int(floor(sqrt(maxf(0.0, float(points)) / 100.0)))


static func xp_for_level(level: int) -> int:
	return (level - 1) * (level - 1) * 100


static func title_of(level: int) -> String:
	var t := "Новобранец"
	for pair in TITLES:
		if level >= pair[0]:
			t = pair[1]
	return t


func level() -> int:
	return level_of(xp)


func title() -> String:
	return title_of(level())


## Adds XP; returns the number of levels gained.
func add_xp(points: int) -> int:
	var before := level()
	xp += maxi(0, points)
	return level() - before


func unlock(key: String) -> bool:
	if unlocked.get(key, false):
		return false
	unlocked[key] = true
	return true


## Logical (CSS) size of the screen: on the web the canvas is in device pixels, so ask the browser.
func logical_size() -> Vector2:
	if OS.has_feature("web"):
		var w := float(JavaScriptBridge.eval("window.innerWidth"))
		var h := float(JavaScriptBridge.eval("window.innerHeight"))
		if w > 0.0 and h > 0.0:
			return Vector2(w, h)
	return Vector2(get_window().size)


## Desktop keeps the crisp integer scaling of a 1280x800 base. On the web and on small windows the
## base becomes the screen itself, so one logical pixel is one CSS pixel and nothing is cropped.
func _apply_scaling() -> void:
	var win := get_window()
	var size := logical_size()
	mobile = size.x < MOBILE_WIDTH or size.y < 600.0
	if OS.has_feature("web") or mobile:
		win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
		win.content_scale_size = Vector2i(maxi(320, int(size.x)), maxi(320, int(size.y)))
	else:
		win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
		win.content_scale_size = Vector2i(1280, 800)
