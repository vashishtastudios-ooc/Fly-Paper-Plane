extends CanvasLayer
## Title screen and flight (level) select on a sheet of notebook paper.

signal level_chosen(index: int)
signal hangar_pressed
signal settings_pressed
signal credits_pressed

var _root: Control
var _sheet: NotebookSheet
var _cards_box: GridContainer
var _cards: Array[Button] = []
var _title: Label
var _subtitle: Label
var _hint: Label


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_sheet = NotebookSheet.new()
	_sheet.tilt_degrees = -1.4
	_root.add_child(_sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_sheet.add_child(v)
	_title = UIKit.label("Glide Home", UIKit.display_font(), 84, UIKit.INK)
	v.add_child(_title)
	_subtitle = UIKit.label("A folded paper plane, a golden evening, and somewhere soft to land.", UIKit.body_font(), 20, UIKit.PENCIL)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_subtitle)
	var h := UIKit.label("Flights", UIKit.display_font(), 38, UIKit.INK_DARK)
	v.add_child(h)
	_cards_box = GridContainer.new()
	_cards_box.add_theme_constant_override("h_separation", 14)
	_cards_box.add_theme_constant_override("v_separation", 10)
	_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_cards_box)
	for i in Game.levels.size():
		var card := _make_card(i)
		_cards_box.add_child(card)
		_cards.append(card)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	for b_def in [["Hangar", hangar_pressed], ["Settings", settings_pressed], ["Credits", credits_pressed]]:
		var b := UIKit.paper_button(b_def[0], b_def[0] == "Hangar", 24)
		var sig: Signal = b_def[1]
		b.pressed.connect(func(): sig.emit())
		buttons.add_child(b)
	_hint = UIKit.label("", UIKit.ui_font(), 18, Color(UIKit.PENCIL, 0.8))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	buttons.add_child(_hint)
	_hint.text = "Drag on the left to steer, tap Gust for a lift." if Settings.touch_ui \
		else "A/D turn  W/S climb, dive  Space gust  Q/E roll"
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh()


func open() -> void:
	refresh()
	visible = true
	_layout()
	if not get_tree().process_frame.is_connected(_layout):
		get_tree().process_frame.connect(_layout, CONNECT_ONE_SHOT)
	for i in _cards.size():
		if not _cards[i].disabled:
			_cards[i].grab_focus()
	var first := _first_unplayed()
	if first >= 0:
		_cards[first].grab_focus()


func close() -> void:
	visible = false


func _first_unplayed() -> int:
	for i in _cards.size():
		if Game.is_unlocked(i) and not Game.best_scores.has(i):
			return i
	return -1


func _layout() -> void:
	var s := Settings.viewport_size()
	var portrait := s.y > s.x
	var sheet_size: Vector2
	if portrait:
		sheet_size = Vector2(minf(s.x * 0.94, 640.0), minf(s.y * 0.86, 1100.0))
	else:
		sheet_size = Vector2(minf(s.x * 0.86, 1040.0), minf(s.y * 0.94, 680.0))
	_sheet.size = sheet_size
	_sheet.position = (s - sheet_size) * 0.5
	var n := _cards.size()
	var cols := 1 if portrait else (n if n <= 3 else (2 if n == 4 else 3))
	_cards_box.columns = cols
	var rows := int(ceil(float(n) / cols))
	var scale_f := clampf(sheet_size.x / 900.0, 0.6, 1.1) if not portrait else clampf(sheet_size.x / 560.0, 0.7, 1.1)
	_title.add_theme_font_size_override("font_size", int((84 if rows < 2 or portrait else 64) * scale_f))
	_subtitle.add_theme_font_size_override("font_size", int(20 * scale_f))
	for c in _cards:
		c.custom_minimum_size = Vector2(0, 124 * scale_f) if portrait else Vector2((sheet_size.x - 150) / cols, (250.0 / rows) * scale_f)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _make_card(i: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.55)
	sb.border_color = Color(UIKit.INK, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0.3, 0.2, 0.1, 0.12)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(2, 3)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 0.97, 0.88, 0.95)
	hover.border_color = UIKit.INK
	var focus := sb.duplicate() as StyleBoxFlat
	focus.draw_center = false
	focus.border_color = UIKit.GOLD_DEEP
	focus.set_border_width_all(3)
	var disabled := sb.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.85, 0.83, 0.8, 0.35)
	disabled.border_color = Color(UIKit.PENCIL, 0.3)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("disabled", disabled)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	b.add_child(m)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	m.add_child(v)
	var num := UIKit.label("FLIGHT %d" % (i + 1), UIKit.ui_font(), 16, UIKit.MARGIN)
	num.name = "Num"
	v.add_child(num)
	var nm := UIKit.label(Game.levels[i].level_name, UIKit.display_font(), 30, UIKit.INK_DARK)
	nm.name = "Name"
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var goal := UIKit.label(Game.levels[i].short_goal, UIKit.body_font(), 16, UIKit.PENCIL)
	goal.name = "Goal"
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(goal)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var best := UIKit.label("", UIKit.ui_font(), 18, UIKit.INK_DARK)
	best.name = "Best"
	best.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(best)
	var stars := UIWidgets.RibbonStars.new(0, 10.0)
	stars.name = "Ribbons"
	row.add_child(stars)
	for c in v.get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(func(): level_chosen.emit(i))
	return b


func refresh() -> void:
	for i in _cards.size():
		var card := _cards[i]
		var unlocked := Game.is_unlocked(i)
		card.disabled = not unlocked
		var goal: Label = card.find_child("Goal", true, false)
		var best: Label = card.find_child("Best", true, false)
		var rib = card.find_child("Ribbons", true, false)
		if unlocked:
			goal.text = Game.levels[i].short_goal
			best.text = ("Best %d" % Game.best_scores[i]) if Game.best_scores.has(i) else "Not flown yet"
			rib.set_filled(int(Game.best_ribbons.get(i, 0)))
			card.modulate = Color.WHITE
		else:
			goal.text = "Land the previous flight to unlock"
			best.text = "Locked"
			rib.set_filled(0)
			card.modulate = Color(1, 1, 1, 0.75)
