extends VBoxContainer
## World news ticker: the last few headlines, newest at the bottom, fading out with age.

const ThemeFactory := preload("res://scripts/ui/theme_factory.gd")

const MAX_LINES := 6
const LIFETIME := 18.0
const COLORS := {
	"war": Color("#F98BA9"),
	"peace": Color("#B7C96A"),
	"politics": Color("#D6BEEA"),
	"world": Color("#7FB9E6"),
	"you": Color("#F4D77A"),
}

var lines: Array = []   # [{label, age}]


func _ready() -> void:
	add_theme_constant_override("separation", 3)
	mouse_filter = MOUSE_FILTER_IGNORE


func push(text: String, kind: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", ThemeFactory.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = MOUSE_FILTER_IGNORE
	var style := ThemeFactory.pill(ThemeFactory.PANEL, 2, 8)
	style.border_color = COLORS.get(kind, ThemeFactory.SKY)
	style.set_border_width_all(0)
	style.border_width_left = 4
	l.add_theme_stylebox_override("normal", style)
	add_child(l)
	lines.append({"label": l, "age": 0.0})
	while lines.size() > MAX_LINES:
		var old: Dictionary = lines.pop_front()
		old["label"].queue_free()


func _process(delta: float) -> void:
	var dead: Array = []
	for entry in lines:
		entry["age"] += delta
		var a: float = clampf((LIFETIME - entry["age"]) / 4.0, 0.0, 1.0)
		entry["label"].modulate = Color(1, 1, 1, a)
		if entry["age"] >= LIFETIME:
			dead.append(entry)
	for entry in dead:
		lines.erase(entry)
		entry["label"].queue_free()
