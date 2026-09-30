extends Node
## Autoload: persistent player settings (user://settings.cfg) and screen scaling for web / small screens.

const PATH := "user://settings.cfg"
const MOBILE_WIDTH := 900.0

var nickname := "Игрок"
var muted := false
var color_index := 0
var mobile := false            # small screen: compact HUD layout


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		nickname = str(cfg.get_value("player", "nickname", nickname))
		muted = bool(cfg.get_value("audio", "muted", muted))
		color_index = int(cfg.get_value("player", "color", color_index))
	_apply_scaling()
	get_window().size_changed.connect(_apply_scaling)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "nickname", nickname)
	cfg.set_value("player", "color", color_index)
	cfg.set_value("audio", "muted", muted)
	cfg.save(PATH)


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
