extends RefCounted
## Builds the pixel-style UI theme in code (no .tres to hand-edit).

const BG := Color(0.13, 0.10, 0.08)
const BG_HOVER := Color(0.24, 0.19, 0.14)
const BG_PRESSED := Color(0.62, 0.38, 0.16)
const FRAME := Color(0.86, 0.76, 0.56)
const TEXT := Color(0.96, 0.92, 0.82)
const TEXT_DIM := Color(0.55, 0.52, 0.47)
const PANEL := Color(0.09, 0.07, 0.06, 0.94)


static func box(bg: Color, frame: Color, margin: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = frame
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = false
	return sb


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	t.set_stylebox("normal", "Button", box(BG, FRAME))
	t.set_stylebox("hover", "Button", box(BG_HOVER, FRAME))
	t.set_stylebox("pressed", "Button", box(BG_PRESSED, TEXT))
	t.set_stylebox("disabled", "Button", box(Color(0.10, 0.10, 0.10), Color(0.35, 0.35, 0.35)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, FRAME, 10))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.8))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	return t
