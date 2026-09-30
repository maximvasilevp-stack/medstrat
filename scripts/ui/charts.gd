extends RefCounted
## Small chart controls drawn with the Canvas API: line charts for statistics, bar charts for seats and income.

const Names := preload("res://scripts/sim/names.gd")
const ThemeFactory := preload("res://scripts/ui/theme_factory.gd")


class LineChart extends Control:
	var title := ""
	var series: Array = []      # [{values: PackedFloat32Array, color: Color, label: String}]
	var bg := StyleBoxFlat.new()

	func _init() -> void:
		custom_minimum_size = Vector2(300, 150)
		mouse_filter = MOUSE_FILTER_IGNORE
		bg.bg_color = Color.WHITE
		bg.border_color = ThemeFactory.FRAME
		bg.set_border_width_all(2)
		bg.set_corner_radius_all(12)

	func set_data(t: String, s: Array) -> void:
		title = t
		series = s
		queue_redraw()

	func _draw() -> void:
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		var font := get_theme_default_font()
		draw_string(font, Vector2(12, 18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ThemeFactory.TEXT)
		var plot := Rect2(48, 28, size.x - 60, size.y - 48)
		var lo := INF
		var hi := -INF
		for s in series:
			for v in s["values"]:
				lo = minf(lo, v)
				hi = maxf(hi, v)
		if lo == INF:
			lo = 0.0
			hi = 1.0
		if lo > 0.0:
			lo = 0.0
		if hi - lo < 1e-6:
			hi = lo + 1.0
		for i in 5:
			var y := plot.end.y - plot.size.y * i / 4.0
			draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), ThemeFactory.FRAME, 1.0)
			var v := lo + (hi - lo) * i / 4.0
			draw_string(font, Vector2(4, y + 4), Names.short_number(v), HORIZONTAL_ALIGNMENT_LEFT, 44, 10, ThemeFactory.TEXT_DIM)
		var legend_x := plot.end.x
		for s in series:
			var values: PackedFloat32Array = s["values"]
			var n := values.size()
			if n == 0:
				continue
			var pts := PackedVector2Array()
			for i in n:
				var x := plot.position.x + (plot.size.x * i / maxf(1.0, float(Rules_max(n) - 1)))
				var y := plot.end.y - plot.size.y * (values[i] - lo) / (hi - lo)
				pts.append(Vector2(x, y))
			if n >= 2:
				draw_polyline(pts, s["color"], 2.5, true)
			draw_circle(pts[n - 1], 3.5, s["color"])
			var label: String = s["label"]
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			legend_x -= w + 18
			draw_circle(Vector2(legend_x, 14), 4.0, s["color"])
			draw_string(font, Vector2(legend_x + 8, 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ThemeFactory.TEXT_DIM)

	static func Rules_max(n: int) -> int:
		return maxi(n, 2)


class BarChart extends Control:
	var title := ""
	var bars: Array = []        # [{value: float, color: Color, label: String}]
	var stacked := false
	var bg := StyleBoxFlat.new()

	func _init() -> void:
		custom_minimum_size = Vector2(300, 120)
		mouse_filter = MOUSE_FILTER_IGNORE
		bg.bg_color = Color.WHITE
		bg.border_color = ThemeFactory.FRAME
		bg.set_border_width_all(2)
		bg.set_corner_radius_all(12)

	func set_data(t: String, b: Array, is_stacked: bool) -> void:
		title = t
		bars = b
		stacked = is_stacked
		queue_redraw()

	func _draw() -> void:
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		var font := get_theme_default_font()
		draw_string(font, Vector2(12, 18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ThemeFactory.TEXT)
		if bars.is_empty():
			return
		if stacked:
			var total := 0.0
			for b in bars:
				total += maxf(0.0, b["value"])
			if total <= 0.0:
				return
			var x := 12.0
			var bar_rect := Rect2(12, 30, size.x - 24, 30)
			for b in bars:
				var w: float = bar_rect.size.x * maxf(0.0, b["value"]) / total
				draw_rect(Rect2(x, bar_rect.position.y, w, bar_rect.size.y), b["color"])
				if w > 28:
					draw_string(font, Vector2(x + 6, bar_rect.position.y + 20), str(int(b["value"])), HORIZONTAL_ALIGNMENT_LEFT, w - 8, 12, ThemeFactory.TEXT)
				x += w
			var ly := bar_rect.end.y + 22
			var lx := 12.0
			for b in bars:
				draw_circle(Vector2(lx + 5, ly - 4), 5.0, b["color"])
				var text: String = "%s %d" % [b["label"], int(b["value"])]
				draw_string(font, Vector2(lx + 14, ly), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ThemeFactory.TEXT_DIM)
				lx += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 26
			return
		var lo := 0.0
		var hi := 0.0
		for b in bars:
			lo = minf(lo, b["value"])
			hi = maxf(hi, b["value"])
		if hi - lo < 1e-6:
			hi = lo + 1.0
		var plot := Rect2(12, 30, size.x - 24, size.y - 58)
		var zero_y := plot.end.y - plot.size.y * (0.0 - lo) / (hi - lo)
		draw_line(Vector2(plot.position.x, zero_y), Vector2(plot.end.x, zero_y), ThemeFactory.FRAME, 1.0)
		var slot := plot.size.x / bars.size()
		for i in bars.size():
			var b: Dictionary = bars[i]
			var x := plot.position.x + slot * i + slot * 0.15
			var y: float = plot.end.y - plot.size.y * (float(b["value"]) - lo) / (hi - lo)
			var top := minf(y, zero_y)
			var h := absf(y - zero_y)
			draw_rect(Rect2(x, top, slot * 0.7, maxf(h, 1.0)), b["color"])
			draw_string(font, Vector2(x, plot.end.y + 14), b["label"], HORIZONTAL_ALIGNMENT_LEFT, slot, 10, ThemeFactory.TEXT_DIM)
			var vy := top - 4.0 if b["value"] >= 0.0 else top + h + 12.0
			draw_string(font, Vector2(x, vy), Names.short_number(b["value"]) if b["value"] >= 0.0 else "−" + Names.short_number(-b["value"]), HORIZONTAL_ALIGNMENT_LEFT, slot, 10, ThemeFactory.TEXT)
