extends Node
## Autoload: persistent player settings (user://settings.cfg).

const PATH := "user://settings.cfg"

var nickname := "Игрок"
var muted := false


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		nickname = str(cfg.get_value("player", "nickname", nickname))
		muted = bool(cfg.get_value("audio", "muted", muted))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "nickname", nickname)
	cfg.set_value("audio", "muted", muted)
	cfg.save(PATH)
