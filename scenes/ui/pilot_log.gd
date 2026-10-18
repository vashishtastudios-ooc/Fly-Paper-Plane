class_name PilotLog
extends CanvasLayer
## The Pilot log: the player's name, ribbons per map, lifetime records, per-flight bests and
## achievements, on a notebook page like Settings.

signal closed

const CRASH_NAMES := {"tree": "Trees", "water": "Water", "wall": "Walls", "car": "Cars", "bridge": "Bridges",
	"glass": "Windows", "greenhouse": "Greenhouse", "fan": "Fans", "lamp": "Lamps", "furniture": "Furniture",
	"banister": "Banisters", "ceiling": "Ceilings", "line": "Strings", "ground": "Ground", "stopped": "Short landings",
	"out": "Out of town"}

var _sheet: NotebookSheet
var _list: VBoxContainer
var _name_edit: LineEdit
var _done: Button


func _ready() -> void:
	layer = 25
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.07, 0.02, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	_sheet = NotebookSheet.new()
	root.add_child(_sheet)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_sheet.add_child(outer)
	outer.add_child(UIKit.label("Pilot log", UIKit.display_font(), 54, UIKit.INK))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	name_row.add_child(UIKit.label("Pilot", UIKit.body_font(), 20, UIKit.INK_DARK))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Your pilot name"
	_name_edit.max_length = Profile.NAME_MAX
	_name_edit.custom_minimum_size = Vector2(240, 44)
	_name_edit.add_theme_font_override("font", UIKit.display_font())
	_name_edit.add_theme_font_size_override("font_size", 26)
	_name_edit.add_theme_color_override("font_color", UIKit.INK)
	_name_edit.add_theme_color_override("font_placeholder_color", Color(UIKit.PENCIL, 0.5))
	_name_edit.add_theme_color_override("caret_color", UIKit.INK)
	var under := StyleBoxFlat.new()
	under.bg_color = Color(0, 0, 0, 0)
	under.border_color = Color(UIKit.INK, 0.45)
	under.border_width_bottom = 2
	under.content_margin_left = 4
	_name_edit.add_theme_stylebox_override("normal", under)
	var focus := under.duplicate() as StyleBoxFlat
	focus.border_color = Color("#ee9256")
	_name_edit.add_theme_stylebox_override("focus", focus)
	_name_edit.text_submitted.connect(func(_t: String): _save_name())
	_name_edit.focus_exited.connect(_save_name)
	name_row.add_child(_name_edit)
	outer.add_child(name_row)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.attach(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	# Room on the right so the numbers stay clear of the scroll bar.
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 22)
	scroll.add_child(pad)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	pad.add_child(_list)
	_done = UIKit.paper_button("Done", true, 28)
	_done.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_done.pressed.connect(func():
		close()
		closed.emit())
	outer.add_child(_done)
	get_viewport().size_changed.connect(_layout)
	visible = false


func open() -> void:
	_name_edit.text = Profile.pilot_name()
	_rebuild()
	visible = true
	_layout()
	_done.grab_focus()


func close() -> void:
	_save_name()
	visible = false


func _save_name() -> void:
	Profile.set_pilot_name(_name_edit.text)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		closed.emit()
		get_viewport().set_input_as_handled()


func _layout() -> void:
	var s := Settings.viewport_size()
	var tall := 1180.0 if s.y > s.x else 720.0
	_sheet.size = Vector2(minf(s.x - 24.0, 760.0), minf(s.y - 24.0, tall))
	_sheet.position = (s - _sheet.size) * 0.5


# --- Content ---------------------------------------------------------------------------------

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var since := Time.get_date_dict_from_unix_time(Profile.created())
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	_list.add_child(_note("Flying since %d %s %d  ·  Played %s" % [since.day, months[since.month - 1], since.year, _duration(Profile.play_time())]))

	_list.add_child(_section("Ribbons"))
	for m in Game.MAPS:
		if m.get("soon", false):
			continue
		var got := 0
		var cleared := 0
		for i in m.levels:
			got += int(Game.best_ribbons.get(i, 0))
			if Game.best_scores.has(i):
				cleared += 1
		var n: int = (m.levels as Array).size()
		_list.add_child(_row(m.name, "%d / %d ribbons  ·  %d of %d flights" % [got, n * 3, cleared, n]))

	_list.add_child(_section("Records"))
	var st := func(k: String) -> int: return roundi(Profile.stat(k))
	var grid := _grid()
	for pair in [
		["Flights flown", str(st.call("flights"))],
		["Landings", str(st.call("landings"))],
		["Perfect landings (3 ribbons)", str(st.call("perfect"))],
		["Bullseyes (within 0.5 m)", str(st.call("bullseyes"))],
		["Time in the air", _duration(Profile.stat("flight_time"))],
		["Distance flown", _distance(Profile.stat("distance"))],
		["Rings flown through", str(st.call("rings"))],
		["Stars collected", str(st.call("stars"))],
		["Barrel rolls", str(st.call("rolls"))],
		["Gusts used", str(st.call("gusts"))],
		["Rising air rides", str(st.call("thermals"))],
		["Skips off the water", str(st.call("skips"))],
		["Secret rings found", str(st.call("bonus_rings"))],
		["Crashes", str(st.call("crashes"))],
	]:
		_grid_row(grid, pair[0], pair[1])
	_list.add_child(grid)
	var ck := Profile.crash_kinds()
	if not ck.is_empty():
		var keys := ck.keys()
		keys.sort_custom(func(a, b): return int(ck[a]) > int(ck[b]))
		var parts := []
		for k in keys:
			parts.append("%s %d" % [CRASH_NAMES.get(k, str(k).capitalize()), int(ck[k])])
		_list.add_child(_note("Crashed into: " + ",  ".join(parts)))

	_list.add_child(_section("Achievements  (%d of %d)" % [Profile.achieved_count(), Profile.ACHIEVEMENTS.size()]))
	for def in Profile.ACHIEVEMENTS:
		_list.add_child(_achievement_row(def))

	_list.add_child(_section("Flights"))
	for m in Game.MAPS:
		if m.get("soon", false):
			continue
		_list.add_child(UIKit.label(m.name, UIKit.ui_font(), 20, UIKit.MARGIN))
		var fg := _grid()
		for k in (m.levels as Array).size():
			var i: int = m.levels[k]
			var id := Game.level_id(i)
			var text := "Not flown yet"
			if Profile.has_flight(id):
				var f := Profile.flight(id)
				if int(f.landings) > 0:
					var parts := ["%d pts" % int(f.best_score), "%d ribbon%s" % [int(f.ribbons), "" if int(f.ribbons) == 1 else "s"]]
					# Records carried over from older versions have no time or distance yet.
					if float(f.best_time) >= 0.0:
						parts.append("%.1f s" % float(f.best_time))
					if float(f.best_dist) >= 0.0:
						parts.append("%.1f m" % float(f.best_dist))
					text = "  ·  ".join(parts)
				elif int(f.attempts) > 0:
					text = "%d tr%s, no landing yet" % [int(f.attempts), "y" if int(f.attempts) == 1 else "ies"]
			_grid_row(fg, "%d. %s" % [k + 1, Game.levels[i].level_name], text)
		_list.add_child(fg)
	_list.add_child(_note("Best score  ·  ribbons  ·  fastest landing  ·  closest to the centre"))


func _achievement_row(def: Dictionary) -> Control:
	var done := Profile.is_achieved(def.id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var badge := Badge.new()
	badge.done = done
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(def.title, UIKit.display_font(), 22, UIKit.INK if done else UIKit.INK_DARK))
	col.add_child(UIKit.label(def.desc, UIKit.body_font(), 16, UIKit.PENCIL))
	row.add_child(col)
	var p := Profile.progress_of(def)
	var txt := "Done!" if done else "%s / %s" % [_amount(p.x, def), _amount(p.y, def)]
	var pl := UIKit.label(txt, UIKit.ui_font(), 18, UIKit.MARGIN if done else UIKit.PENCIL)
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pl)
	if not done:
		row.modulate.a = 0.75
	return row


func _amount(x: float, def: Dictionary) -> String:
	match def.get("unit", ""):
		"m": return _distance(x)
		"s": return _duration(x)
	return str(int(x))


static func _duration(sec: float) -> String:
	var s := int(sec)
	if s < 60:
		return "%d s" % s
	if s < 3600:
		return "%d min" % (s / 60)
	var mins := (s % 3600) / 60
	return ("%d h" % (s / 3600)) if mins == 0 else ("%d h %d min" % [s / 3600, mins])


static func _distance(m: float) -> String:
	return ("%.1f km" % (m / 1000.0)) if m >= 1000.0 else ("%d m" % int(m))


func _section(text: String) -> Label:
	var l := UIKit.label(text, UIKit.display_font(), 30, UIKit.INK_DARK)
	return l


func _note(text: String) -> Label:
	var l := UIKit.label(text, UIKit.body_font(), 16, UIKit.PENCIL)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _row(left: String, right: String) -> Control:
	var row := HBoxContainer.new()
	var l := UIKit.label(left, UIKit.body_font(), 20, UIKit.INK_DARK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UIKit.label(right, UIKit.ui_font(), 20, UIKit.INK))
	return row


func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 3)
	return g


func _grid_row(g: GridContainer, left: String, right: String) -> void:
	var l := UIKit.label(left, UIKit.body_font(), 19, UIKit.INK_DARK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	g.add_child(l)
	var r := UIKit.label(right, UIKit.ui_font(), 19, UIKit.INK)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	g.add_child(r)


## A gold star once an achievement is earned, an empty outline until then.
class Badge extends Control:
	var done := false

	func _init() -> void:
		custom_minimum_size = Vector2(32, 32)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		UIKit.draw_star(self, size * 0.5, 14.0, UIKit.GOLD if done else Color(0, 0, 0, 0.06), UIKit.GOLD_DEEP if done else Color(UIKit.PENCIL, 0.45))
