extends CanvasLayer
## Pre-flight card: level name, goal and the throw button. The camera orbits the kid behind it.

signal throw_pressed
signal flights_pressed

var _root: Control
var _sheet: NotebookSheet
var _num: Label
var _name: Label
var _goal: Label
var _par: Label
var _throw: Button
var _flights: Button


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_sheet = NotebookSheet.new()
	_sheet.tilt_degrees = 1.1
	_sheet.line_spacing = 28.0
	_root.add_child(_sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_sheet.add_child(v)
	_num = UIKit.label("FLIGHT 1", UIKit.ui_font(), 18, UIKit.MARGIN)
	v.add_child(_num)
	_name = UIKit.label("", UIKit.display_font(), 48, UIKit.INK)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_name)
	_goal = UIKit.label("", UIKit.body_font(), 19, UIKit.PENCIL)
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_goal)
	_par = UIKit.label("", UIKit.ui_font(), 18, UIKit.INK_DARK)
	v.add_child(_par)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	_throw = UIKit.paper_button("Throw the plane", true, 30)
	_throw.pressed.connect(func(): throw_pressed.emit())
	row.add_child(_throw)
	_flights = UIKit.paper_button("Flights", false, 26)
	_flights.pressed.connect(func(): flights_pressed.emit())
	row.add_child(_flights)
	get_viewport().size_changed.connect(_layout)
	visible = false


func open(index: int, data: LevelData) -> void:
	_num.text = "FLYING LESSONS" if index == Game.LESSONS else ("%s · FLIGHT %d" % [Game.map_name(index).to_upper(), Game.flight_number(index)])
	_name.text = data.level_name
	_goal.text = data.goal_text
	var best := ("   Best %d" % Game.best_scores[index]) if Game.best_scores.has(index) else ""
	_par.text = "Par time %d s%s" % [int(data.par_time), best]
	visible = true
	_layout()
	if not get_tree().process_frame.is_connected(_layout):
		get_tree().process_frame.connect(_layout, CONNECT_ONE_SHOT)
	_throw.grab_focus()


func close() -> void:
	visible = false


## The sheet is only as tall as its text needs (plus a little breathing room).
func _fit_height() -> float:
	return maxf(_sheet.get_combined_minimum_size().y + 36.0, 300.0)


func _layout() -> void:
	var s := Settings.viewport_size()
	var m := Settings.safe_margins()
	if s.y > s.x:
		var w := minf(s.x - 24.0, 620.0)
		_sheet.size.x = w
		var h := minf(_fit_height(), minf(s.y * 0.5, 560.0))
		_sheet.size = Vector2(w, h)
		_sheet.position = Vector2((s.x - w) * 0.5, s.y - h - m.w - 16.0)
		_name.add_theme_font_size_override("font_size", 42)
	else:
		var w2 := clampf(s.x * 0.42, 380.0, 560.0)
		_sheet.size.x = w2
		var h2 := minf(_fit_height(), minf(s.y - 48.0, 560.0))
		_sheet.size = Vector2(w2, h2)
		_sheet.position = Vector2(m.x + 24.0, (s.y - h2) * 0.5)
		_name.add_theme_font_size_override("font_size", 48)
