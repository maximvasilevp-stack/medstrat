extends RefCounted
## Bright "dopamine" UI theme built in code: cream panels, pastel pills, dark-brown text.

const BG := Color("#FFFFFF")
const BG_HOVER := Color("#7ED5F2")
const BG_PRESSED := Color("#FFAE00")
const FRAME := Color("#EFE3D6")
const TEXT := Color("#3B2A1A")
const TEXT_DIM := Color("#8A7563")
const PANEL := Color("#FFF8F2")
const SKY := Color("#7ED5F2")
const LAVENDER := Color("#CEA8F6")
const LIME := Color("#B2E384")
const LEMON := Color("#F6EE75")
const ORANGE := Color("#FFAE00")
const PEACH := Color("#FACBB8")
const BLUE := Color("#A2C7F7")
const RED := Color("#D9534F")
const GREEN := Color("#3C8D3F")
const RADIUS := 14


static func box(bg: Color, frame: Color = FRAME, margin: int = 8, radius: int = RADIUS) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = frame
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	return sb


## A filled pastel pill without a visible border (cards, badges).
static func pill(bg: Color, margin: int = 8, radius: int = RADIUS) -> StyleBoxFlat:
	return box(bg, bg.darkened(0.08), margin, radius)


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	t.set_stylebox("normal", "Button", box(BG, FRAME))
	t.set_stylebox("hover", "Button", box(BG_HOVER, BG_HOVER.darkened(0.1)))
	t.set_stylebox("pressed", "Button", box(BG_PRESSED, BG_PRESSED.darkened(0.1)))
	t.set_stylebox("disabled", "Button", box(Color("#F3EDE6"), FRAME))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color("#B8A999"))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, FRAME, 12, 18))
	t.set_color("font_color", "Label", TEXT)
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		t.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", TEXT)
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_color("font_hover_pressed_color", "CheckBox", TEXT)
	t.set_stylebox("normal", "LineEdit", box(BG, FRAME, 8, 10))
	t.set_stylebox("focus", "LineEdit", box(BG, ORANGE, 8, 10))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_DIM)
	t.set_color("caret_color", "LineEdit", TEXT)
	t.set_stylebox("slider", "HSlider", pill(FRAME, 0, 6))
	t.set_stylebox("grabber_area", "HSlider", pill(ORANGE, 0, 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", pill(ORANGE, 0, 6))
	t.set_stylebox("panel", "TooltipPanel", box(PANEL, FRAME, 8, 10))
	t.set_color("font_color", "TooltipLabel", TEXT)
	return t
