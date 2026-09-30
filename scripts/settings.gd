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
	cfg.save(PATH)


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
