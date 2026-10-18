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
	_headline = UIKit.label("", UIKit.display_font(), 56, UIKit.INK)
	v.add_child(_headline)
	_sub = UIKit.label("", UIKit.body_font(), 19, UIKit.PENCIL)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_sub)
	_ribbons = UIWidgets.RibbonStars.new(0, 20.0)
	v.add_child(_ribbons)
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
	_sub.text = "%s  %.1f m from the centre at %d km/h." % [Quips.landing(score.ribbons), stats.dist, roundi(stats.speed * 3.6)]
	_ribbons.visible = true
	_ribbons.set_filled(score.ribbons)
	_row("Accuracy", str(score.accuracy))
	_row("Soft touchdown", str(score.soft))
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
	_sub.custom_minimum_size.x = w - 140.0
	var h := 560.0 if _ribbons.visible else 430.0
	# A crash card is only as tall as its text needs.
	_sheet.size.x = w
	if not _ribbons.visible:
		h = minf(h, maxf(_sheet.get_combined_minimum_size().y + 36.0, 280.0))
	_sheet.size = Vector2(w, minf(h, s.y - 24.0))
	_sheet.position = (s - _sheet.size) * 0.5
