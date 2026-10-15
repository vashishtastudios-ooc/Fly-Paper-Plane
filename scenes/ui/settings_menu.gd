extends CanvasLayer
## Settings: volumes, graphics quality, steering sensitivity, invert climb/dive, vibration and tips.
## Works from the main menu and from the pause screen (runs while paused).

signal closed
signal lessons_pressed

var _sheet: NotebookSheet
var _quality_buttons: Array[Button] = []
var _done: Button
## Controls by setting name, so they can be refreshed (e.g. after Reset to defaults).
var _sliders := {}
var _checks := {}
## Value labels next to sliders, with how to format each one.
var _value_labels := {}
var _formats := {}


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.07, 0.02, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	_sheet = NotebookSheet.new()
	_sheet.tilt_degrees = 0.9
	root.add_child(_sheet)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_sheet.add_child(outer)
	outer.add_child(UIKit.label("Settings", UIKit.display_font(), 54, UIKit.INK))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	scroll.add_child(v)

	v.add_child(_section("Sound"))
	v.add_child(_slider_row("music", "Music", Settings.music_volume, func(x: float): Settings.set_volume("Music", x)))
	v.add_child(_slider_row("sfx", "Effects", Settings.sfx_volume, func(x: float): Settings.set_volume("SFX", x)))
	v.add_child(_slider_row("ambience", "Wind and birds", Settings.ambience_volume, func(x: float): Settings.set_volume("Ambience", x)))

	v.add_child(_section("Graphics"))
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for i in 3:
		var b := UIKit.paper_button(Settings.QUALITY_NAMES[i], false, 24)
		b.toggle_mode = true
		b.button_group = group
		var q := i
		b.pressed.connect(func(): Settings.set_quality(q))
		qrow.add_child(b)
		_quality_buttons.append(b)
	v.add_child(qrow)
	v.add_child(_note("Lower quality saves battery and keeps older phones smooth."))
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 8)
	srow.add_child(UIKit.label("Art style", UIKit.body_font(), 20, UIKit.INK_DARK))
	var sgroup := ButtonGroup.new()
	for st in [["storybook", "Storybook"], ["painterly", "Painterly"]]:
		var b := UIKit.paper_button(st[1], false, 22)
		b.toggle_mode = true
		b.button_group = sgroup
		b.set_pressed_no_signal(Settings.art_style == st[0])
		var id: String = st[0]
		b.pressed.connect(func(): Settings.set_option("art_style", id))
		srow.add_child(b)
	v.add_child(srow)
	v.add_child(_note("The art style changes the next time you start the game."))

	v.add_child(_section("Controls"))
	v.add_child(_slider_row("sensitivity", "Steering sensitivity", inverse_lerp(0.5, 1.6, Settings.sensitivity),
		func(x: float): Settings.set_option("sensitivity", lerpf(0.5, 1.6, x))))
	v.add_child(_check_row("invert", "Invert climb and dive", Settings.invert_pitch, func(on: bool): Settings.set_option("invert_pitch", on)))
	if Settings.is_mobile:
		v.add_child(_check_row("vibration", "Vibration", Settings.vibration, func(on: bool): Settings.set_option("vibration", on)))
	var lessons := UIKit.paper_button("Play the flying lessons again", false, 20)
	lessons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lessons.pressed.connect(func():
		close()
		lessons_pressed.emit())
	v.add_child(lessons)
	v.add_child(_check_row("tips", "Flight tips", Settings.show_tips, func(on: bool):
		Settings.set_option("show_tips", on)
		if on:
			Game.reset_tips()))

	if OS.is_debug_build() or Game.UNLOCK_ALL_FOR_TESTING:
		v.add_child(_section("Testing"))
		v.add_child(_check_row("collision", "Show collision shapes (F3)", false, func(on: bool):
			var dbg := get_tree().root.find_child("CollisionDebug", true, false)
			if dbg:
				dbg.set_shown(on)))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	outer.add_child(buttons)
	_done = UIKit.paper_button("Done", true, 28)
	_done.pressed.connect(func():
		close()
		closed.emit())
	buttons.add_child(_done)
	var reset := UIKit.paper_button("Reset to defaults", false, 24)
	reset.pressed.connect(func():
		Settings.reset_to_defaults()
		_sync())
	buttons.add_child(reset)
	get_viewport().size_changed.connect(_layout)
	visible = false


func _section(text: String) -> Label:
	return UIKit.label(text, UIKit.display_font(), 30, UIKit.INK_DARK)


func _note(text: String) -> Label:
	var l := UIKit.label(text, UIKit.body_font(), 16, UIKit.PENCIL)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _slider_row(key: String, text: String, value: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := UIKit.label(text, UIKit.body_font(), 20, UIKit.INK_DARK)
	l.custom_minimum_size.x = 200
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size.y = 32
	if key == "sensitivity":
		# Snap to tidy 0.1× steps (0.5× to 1.6×).
		s.step = 1.0 / 11.0
	s.value_changed.connect(on_change)
	row.add_child(s)
	_sliders[key] = s
	var vl := UIKit.label("", UIKit.ui_font(), 20, UIKit.INK)
	vl.custom_minimum_size.x = 58
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(vl)
	_value_labels[key] = vl
	_formats[key] = func(x: float) -> String: return ("%.1f×" % lerpf(0.5, 1.6, x)) if key == "sensitivity" else ("%d%%" % roundi(x * 100.0))
	s.value_changed.connect(func(x: float): vl.text = _formats[key].call(x))
	vl.text = _formats[key].call(value)
	return row


func _check_row(key: String, text: String, value: bool, on_change: Callable) -> Control:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = value
	c.add_theme_font_override("font", UIKit.body_font())
	c.add_theme_font_size_override("font_size", 20)
	c.add_theme_color_override("font_color", UIKit.INK_DARK)
	c.add_theme_color_override("font_pressed_color", UIKit.INK_DARK)
	c.add_theme_color_override("font_hover_color", UIKit.INK)
	c.add_theme_color_override("font_hover_pressed_color", UIKit.INK)
	c.add_theme_color_override("font_focus_color", UIKit.INK)
	c.toggled.connect(on_change)
	_checks[key] = c
	return c


## Shows the current settings in every control without re-triggering their callbacks.
func _sync() -> void:
	(_sliders.music as HSlider).set_value_no_signal(Settings.music_volume)
	(_sliders.sfx as HSlider).set_value_no_signal(Settings.sfx_volume)
	(_sliders.ambience as HSlider).set_value_no_signal(Settings.ambience_volume)
	(_sliders.sensitivity as HSlider).set_value_no_signal(inverse_lerp(0.5, 1.6, Settings.sensitivity))
	(_checks.invert as CheckButton).set_pressed_no_signal(Settings.invert_pitch)
	(_checks.tips as CheckButton).set_pressed_no_signal(Settings.show_tips)
	if _checks.has("vibration"):
		(_checks.vibration as CheckButton).set_pressed_no_signal(Settings.vibration)
	for i in _quality_buttons.size():
		_quality_buttons[i].set_pressed_no_signal(i == Settings.quality)
	for key in _sliders:
		(_value_labels[key] as Label).text = _formats[key].call((_sliders[key] as HSlider).value)


func open() -> void:
	_sync()
	visible = true
	_layout()
	_done.grab_focus()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		closed.emit()
		get_viewport().set_input_as_handled()


func _layout() -> void:
	var s := Settings.viewport_size()
	_sheet.size = Vector2(minf(s.x - 24.0, 640.0), minf(s.y - 24.0, 720.0))
	_sheet.position = (s - _sheet.size) * 0.5
