extends CanvasLayer
## Result screen for landings (score breakdown and ribbons) and crashes.

signal next_pressed
signal retry_pressed
signal flights_pressed

var _root: Control
var _dim: ColorRect
var _sheet: NotebookSheet
var _headline: Label
var _sub: Label
## Landings: how close (big), the joke (small) and the little target drawing.
var _close: Label
var _target: TargetDiagram
var _ribbons: UIWidgets.RibbonStars
var _rows: GridContainer
var _best: Label
var _next: Button
var _retry: Button
var _flights: Button


func _ready() -> void:
	layer = 11
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0.15, 0.08, 0.02, 0.25)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)
	_sheet = NotebookSheet.new()
	_sheet.tilt_degrees = -0.9
	_root.add_child(_sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_sheet.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	v.add_child(top)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left)
	_headline = UIKit.label("", UIKit.display_font(), 56, UIKit.INK)
	_headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_headline)
	_close = UIKit.label("", UIKit.display_font(), 30, UIKit.INK_DARK)
	_close.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_close)
	_sub = UIKit.label("", UIKit.body_font(), 18, UIKit.PENCIL)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_sub)
	_ribbons = UIWidgets.RibbonStars.new(0, 20.0)
	left.add_child(_ribbons)
	_target = TargetDiagram.new()
	_target.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_target)
	_rows = GridContainer.new()
	_rows.columns = 2
	_rows.add_theme_constant_override("h_separation", 28)
	_rows.add_theme_constant_override("v_separation", 1)
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_rows)
	_best = UIKit.label("", UIKit.display_font(), 24, UIKit.MARGIN)
	_best.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_best.custom_minimum_size.x = 300
	v.add_child(_best)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 8)
	v.add_child(row)
	_next = UIKit.paper_button("Next flight", true, 28)
	_next.pressed.connect(func(): next_pressed.emit())
	row.add_child(_next)
	_retry = UIKit.paper_button("Fly again", false, 26)
	_retry.pressed.connect(func(): retry_pressed.emit())
	row.add_child(_retry)
	_flights = UIKit.paper_button("Flights", false, 26)
	_flights.pressed.connect(func(): flights_pressed.emit())
	row.add_child(_flights)
	get_viewport().size_changed.connect(_layout)
	visible = false


func _clear_rows() -> void:
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()


func _row(label: String, value: String, bold := false) -> void:
	var l := UIKit.label(label, UIKit.body_font(), 21 if not bold else 24, UIKit.INK_DARK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_child(l)
	var r := UIKit.label(value, UIKit.display_font() if bold else UIKit.ui_font(), 22 if not bold else 32, UIKit.INK if bold else UIKit.INK_DARK)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rows.add_child(r)


## score: result of Game.compute_landing_score(); stats: the raw flight stats.
func show_landing(score: Dictionary, stats: Dictionary, is_best: bool, has_next: bool, unlocks: Array = []) -> void:
	_clear_rows()
	_headline.text = score.headline
	_close.visible = true
	_close.text = "%.1f m from the centre  ·  +%d" % [stats.dist, score.accuracy + score.bullseye_bonus]
	_sub.text = Quips.landing_zone(score.zone) + ("  Ouch, a hard landing: one ribbon less." if score.hard else "")
	_ribbons.visible = true
	_ribbons.set_filled(score.ribbons)
	_target.visible = true
	_target.show_landing(stats.get("offset", Vector2.ZERO), stats.radius, score.zone)
	var zone_names := {"bullseye": "bullseye", "inner": "inner ring", "outer": "outer ring", "edge": "on the edge"}
	_row("Accuracy  (%s)" % zone_names[score.zone], str(score.accuracy))
	if score.bullseye_bonus > 0:
		_row("Bullseye bonus", str(score.bullseye_bonus))
	_row("Soft touchdown  (%d km/h)" % roundi(stats.speed * 3.6), str(score.soft))
	_row("Stars  (%d of %d)" % [stats.stars, stats.stars_total], str(score.stars))
	_row("Time bonus  (%.1f s, par %d)" % [stats.time, int(stats.par)], str(score.time_bonus))
	var tricks := "Tricks  (rings %d, rolls %d%s)" % [stats.rings, stats.rolls, ", bridge ring" if stats.bonus > 0 else ""]
	_row(tricks, str(score.tricks))
	_row("Total", str(score.total), true)
	_best.text = "New best!" if is_best else ""
	if not unlocks.is_empty():
		_best.text += ("   " if is_best else "") + "Unlocked in the Hangar: " + ", ".join(unlocks)
	_next.visible = has_next
	_open()
	(_next if has_next else _retry).grab_focus()


## Adds the achievements earned on this flight under the result.
func show_achievements(list: Array) -> void:
	if list.is_empty():
		return
	var names := []
	for d in list:
		names.append(str(d.title))
	_best.text += ("   " if _best.text != "" else "") + "Achievement: " + ", ".join(names)
	_layout()


func show_crash(message: String, stars: int, stars_total: int, time: float, kind := "") -> void:
	_clear_rows()
	_headline.text = message
	_sub.text = Quips.crash(kind)
	_close.visible = false
	_target.visible = false
	_ribbons.visible = false
	_row("Stars collected", "%d of %d" % [stars, stars_total])
	_row("Time in the air", "%.1f s" % time)
	_best.text = ""
	_next.visible = false
	_open()
	_retry.grab_focus()


func _open() -> void:
	visible = true
	_layout()
	# Wrapped labels report a tall size on their first layout pass; settle again next frame.
	if not get_tree().process_frame.is_connected(_layout):
		get_tree().process_frame.connect(_layout, CONNECT_ONE_SHOT)
	_sheet.modulate.a = 0.0
	_sheet.scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_sheet, "modulate:a", 1.0, 0.25)
	tw.tween_property(_sheet, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	visible = false


func _layout() -> void:
	var s := Settings.viewport_size()
	var w := minf(s.x - 28.0, 640.0)
	# Give wrapping labels their width up front so the sheet height is computed sensibly.
	_sub.custom_minimum_size.x = w - (300.0 if _target.visible else 140.0)
	_close.custom_minimum_size.x = w - 300.0
	var h := 600.0 if _ribbons.visible else 430.0
	# A crash card is only as tall as its text needs.
	_sheet.size.x = w
	if not _ribbons.visible:
		h = minf(h, maxf(_sheet.get_combined_minimum_size().y + 36.0, 280.0))
	_sheet.size = Vector2(w, minf(h, s.y - 24.0))
	_sheet.position = (s - _sheet.size) * 0.5


## The landing spot seen from above: rim, inner ring, gold bullseye and a red dot where the plane
## touched down (the plane flew in from the bottom of the drawing).
class TargetDiagram extends Control:
	var _offset := Vector2.ZERO
	var _radius := 2.0
	var _zone := "outer"

	func _init() -> void:
		custom_minimum_size = Vector2(130, 130)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func show_landing(offset: Vector2, radius: float, zone: String) -> void:
		_offset = offset
		_radius = maxf(radius, 0.1)
		_zone = zone
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var px := minf(size.x, size.y) * 0.5 / (_radius + 0.45)
		var zr: Vector2 = Game.landing_zones(_radius)
		draw_circle(c, (_radius + 0.4) * px, Color(0.25, 0.8, 0.4, 0.12))
		draw_circle(c, _radius * px, Color(0.25, 0.8, 0.4, 0.28))
		draw_arc(c, _radius * px, 0, TAU, 48, Color("#3fc463"), 3.0, true)
		draw_arc(c, zr.y * px, 0, TAU, 40, Color("#3fc463", 0.8), 2.0, true)
		draw_circle(c, zr.x * px, UIKit.GOLD)
		draw_arc(c, zr.x * px, 0, TAU, 24, Color.WHITE, 1.5, true)
		var p := c + _offset * px
		var lim := (_radius + 0.42) * px
		if (p - c).length() > lim:
			p = c + (p - c).normalized() * lim
		draw_circle(p, 6.0, Color("#c8423b"))
		draw_arc(p, 9.0, 0, TAU, 16, Color("#c8423b"), 2.0, true)
