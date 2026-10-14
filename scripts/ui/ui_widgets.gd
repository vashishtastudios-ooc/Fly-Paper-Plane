class_name UIWidgets
extends RefCounted
## Small custom-drawn UI widgets.


## Three ribbon stars, `filled` of them gold.
class RibbonStars extends Control:
	var filled := 0
	var star_size := 14.0

	func _init(count := 0, s := 14.0) -> void:
		filled = count
		star_size = s
		custom_minimum_size = Vector2(s * 2.2 * 3, s * 2.2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_filled(n: int) -> void:
		filled = n
		queue_redraw()

	func _draw() -> void:
		for i in 3:
			var c := Vector2(star_size * 1.1 + i * star_size * 2.2, size.y * 0.5)
			var on := i < filled
			UIKit.draw_star(self, c, star_size, UIKit.GOLD if on else Color(0, 0, 0, 0.08), UIKit.GOLD_DEEP if on else Color(UIKit.PENCIL, 0.45))


## Gust charges: three circles that fill up.
class GustDots extends Control:
	var value := 3.0

	func _init() -> void:
		custom_minimum_size = Vector2(70, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float) -> void:
		if absf(v - value) > 0.01:
			value = v
			queue_redraw()

	func _draw() -> void:
		for i in 3:
			var c := Vector2(11 + i * 23, size.y * 0.5)
			var f := clampf(value - i, 0.0, 1.0)
			draw_circle(c, 9.0, Color(1, 1, 1, 0.18))
			if f >= 1.0:
				draw_circle(c, 9.0, Color("#bfe3ff"))
			elif f > 0.0:
				draw_arc(c, 6.5, -PI * 0.5, -PI * 0.5 + TAU * f, 20, Color("#bfe3ff"), 4.0, true)
			draw_arc(c, 9.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.5, true)


## Vertical variometer bar: green when climbing, blue when sinking.
class Vario extends Control:
	var vs := 0.0
	var font: Font

	func _init() -> void:
		custom_minimum_size = Vector2(46, 200)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		font = UIKit.ui_font()

	func set_vs(v: float) -> void:
		vs = v
		queue_redraw()

	func _draw() -> void:
		var w := 14.0
		var x := (size.x - w) * 0.5
		var top := 14.0
		var h := size.y - 40.0
		var mid := top + h * 0.5
		var bg := StyleBoxFlat.new()
		bg.bg_color = UIKit.PILL
		bg.set_corner_radius_all(10)
		draw_style_box(bg, Rect2(x - 6, top - 6, w + 12, h + 12))
		draw_line(Vector2(x - 3, mid), Vector2(x + w + 3, mid), Color(1, 1, 1, 0.7), 2.0)
		for k in [-1.0, -0.5, 0.5, 1.0]:
			var yy: float = mid - k * h * 0.5
			draw_line(Vector2(x, yy), Vector2(x + 4, yy), Color(1, 1, 1, 0.35), 1.0)
		var frac := clampf(vs / 5.0, -1.0, 1.0)
		var col := UIKit.CLIMB if vs >= 0.0 else UIKit.SINK
		var bar_h := absf(frac) * h * 0.5
		if vs >= 0.0:
			draw_rect(Rect2(x, mid - bar_h, w, bar_h), col)
		else:
			draw_rect(Rect2(x, mid, w, bar_h), col)
		var txt := "%+.1f" % vs
		draw_string(font, Vector2(0, size.y - 6), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, col)


## Small arrow that rotates to show the target direction relative to the heading.
class HeadingArrow extends Control:
	var angle := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(24, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_angle(a: float) -> void:
		angle = a
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var pts := PackedVector2Array([Vector2(0, -10), Vector2(7, 7), Vector2(0, 3), Vector2(-7, 7)])
		var t := Transform2D(angle, c)
		draw_colored_polygon(t * pts, UIKit.GOLD)


## The gold circular arrow clamped to the screen edge when the target is off-screen.
class EdgeArrow extends Control:
	var angle := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(54, 54)
		size = Vector2(54, 54)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		pivot_offset = Vector2(27, 27)

	func _draw() -> void:
		var c := Vector2(27, 27)
		draw_circle(c, 24.0, Color(0.1, 0.08, 0.06, 0.45))
		draw_arc(c, 24.0, 0, TAU, 32, UIKit.GOLD, 3.0, true)
		var pts := PackedVector2Array([Vector2(14, 0), Vector2(-8, -11), Vector2(-3, 0), Vector2(-8, 11)])
		draw_colored_polygon(Transform2D(angle, c) * pts, UIKit.GOLD)
