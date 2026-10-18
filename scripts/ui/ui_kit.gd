class_name UIKit
extends RefCounted
## Fonts, colors and widget helpers for the notebook-paper UI.
## Bundled OFL fonts are loaded from res://fonts/ when present, with system fallbacks.

const INK := Color("#2f5fa8")
const INK_DARK := Color("#24324f")
const PENCIL := Color("#4a4640")
const PAPER := Color("#fbf9f2")
const RULE := Color("#a9c8e8")
const MARGIN := Color("#e27a72")
const GOLD := Color("#f2c14e")
const GOLD_DEEP := Color("#d99a2b")
## Gameplay colors: the route (rings, dotted line, guide arrow) is sky blue, rising air is mint,
## stars stay gold and bonus rings pink.
const ROUTE := Color("#6ec6ff")
const ROUTE_GLOW := Color("#a8dcff")
const LIFT := Color("#8fe3b0")
const BONUS := Color("#ff7eb6")
const PILL := Color(0.09, 0.08, 0.07, 0.5)
const CLIMB := Color("#6fd08c")
const SINK := Color("#6fb4e8")

static var _fonts := {}


static func _load_font(key: String, files: Array, fallbacks: Array, weight := 400) -> Font:
	if _fonts.has(key):
		return _fonts[key]
	var f: Font = null
	for path in files:
		if ResourceLoader.exists(path):
			f = load(path)
			break
	if f == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(fallbacks)
		sf.font_weight = weight
		sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f = sf
	_fonts[key] = f
	return f


## Handwritten display face (Caveat Brush).
static func display_font() -> Font:
	return _load_font("display", ["res://fonts/CaveatBrush-Regular.ttf"],
		["Caveat Brush", "Caveat", "Segoe Print", "Bradley Hand", "Comic Sans MS", "casual", "cursive"], 400)


## Serif body face (Newsreader).
static func body_font() -> Font:
	return _load_font("body", ["res://fonts/Newsreader-Regular.ttf", "res://fonts/Newsreader.ttf"],
		["Newsreader", "Georgia", "Cambria", "Noto Serif", "serif"], 400)


## Condensed UI face (Barlow Condensed).
static func ui_font() -> Font:
	return _load_font("ui", ["res://fonts/BarlowCondensed-SemiBold.ttf", "res://fonts/BarlowCondensed-Medium.ttf"],
		["Barlow Condensed", "Bahnschrift SemiCondensed", "Arial Narrow", "Roboto Condensed", "sans-serif-condensed", "sans-serif"], 600)


static func ui_scale() -> float:
	var s := Settings.viewport_size()
	return clampf(minf(s.x, s.y) / 720.0, 0.75, 1.6)


static func pill_style(radius := 18.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PILL
	sb.set_corner_radius_all(int(radius))
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


static func label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A pencil-sketch style button on paper.
static func paper_button(text: String, primary := false, size := 30) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", display_font())
	b.add_theme_font_size_override("font_size", size)
	var fg := PAPER if primary else INK_DARK
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_focus_color", fg)
	var normal := StyleBoxFlat.new()
	normal.bg_color = INK if primary else Color(1, 1, 1, 0.0)
	normal.border_color = INK
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(14)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 6
	normal.content_margin_bottom = 8
	normal.skew = Vector2(-0.04, 0)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = INK.lightened(0.12) if primary else Color(INK, 0.1)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = INK.darkened(0.15) if primary else Color(INK, 0.2)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color("#ee9256")
	focus.set_border_width_all(3)
	focus.draw_center = false
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", focus)
	b.pressed.connect(func(): Audio.play("click", -6.0))
	return b


## Draws a small five-pointed star (used for ribbons).
static func draw_star(ci: CanvasItem, center: Vector2, r: float, fill: Color, outline: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	ci.draw_polyline(pts, outline, maxf(1.5, r * 0.09), true)
