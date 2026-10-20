extends CanvasLayer
## Settings: volumes, graphics quality, steering sensitivity, invert climb/dive, vibration and tips.
## Works from the main menu and from the pause screen (runs while paused).

signal closed
signal lessons_pressed
signal credits_pressed

var _sheet: NotebookSheet
var _camera_buttons := {}
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
	TouchScroll.attach(scroll)
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
		b.pressed.connect(func(): Settings.choose_quality(q))
		qrow.add_child(b)
		_quality_buttons.append(b)
	v.add_child(qrow)
	v.add_child(_note("Lower quality saves battery and keeps older phones smooth."))
	# The painterly look is a desktop option; phones always use the storybook style.
	if not Settings.is_mobile:
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
	v.add_child(_check_row("fps", "Show frames per second", Settings.show_fps, func(on: bool): Settings.set_option("show_fps", on)))

	v.add_child(_section("Controls"))
	v.add_child(_slider_row("sensitivity", "Steering sensitivity", inverse_lerp(0.5, 1.6, Settings.sensitivity),
		func(x: float): Settings.set_option("sensitivity", lerpf(0.5, 1.6, x))))
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 8)
	var cl := UIKit.label("Camera", UIKit.body_font(), 20, UIKit.INK_DARK)
	cl.custom_minimum_size.x = 150
	crow.add_child(cl)
	var cgroup := ButtonGroup.new()
	for cs in [["responsive", "Responsive"], ["smooth", "Smooth"]]:
		var b := UIKit.paper_button(cs[1], false, 22)
		b.toggle_mode = true
		b.button_group = cgroup
		b.set_pressed_no_signal(Settings.camera_style == cs[0])
		var cid: String = cs[0]
		b.pressed.connect(func(): Settings.set_option("camera_style", cid))
		crow.add_child(b)
		_camera_buttons[cid] = b
	v.add_child(crow)
	v.add_child(_note("Responsive swings round quickly with the plane; Smooth follows more slowly."))
	v.add_child(_check_row("ghost", "Race your best-run ghost", Settings.show_ghost, func(on: bool): Settings.set_option("show_ghost", on)))
	v.add_child(_check_row("invert", "Invert climb and dive", Settings.invert_pitch, func(on: bool): Settings.set_option("invert_pitch", on)))
	if Settings.is_mobile:
		v.add_child(_check_row("vibration", "Vibration", Settings.vibration, func(on: bool): Settings.set_option("vibration", on)))
	var lessons := UIKit.paper_button("Play the flying lessons again", false, 20)
	lessons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lessons.pressed.connect(func():
		close()
		lessons_pressed.emit())
	var credits := UIKit.paper_button("Credits", false, 20)
	credits.pressed.connect(func():
		close()
		credits_pressed.emit())
	var extra := HBoxContainer.new()
	extra.add_theme_constant_override("separation", 12)
	extra.add_child(lessons)
	extra.add_child(credits)
	v.add_child(extra)
	v.add_child(_check_row("tips", "Flight tips", Settings.show_tips, func(on: bool):
		Settings.set_option("show_tips", on)
		if on:
			Game.reset_tips()))

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
	l.custom_minimum_size.x = 150
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	var s := HSlider.new()
	s.custom_minimum_size.x = 160
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size.y = 44
	if key == "sensitivity":
		# Snap to tidy 0.1× steps (0.5× to 1.6×).
		s.step = 1.0 / 11.0
	s.value_changed.connect(on_change)
	# − and + buttons either side: a tap always works, even where a finger drag would scroll
	# the page instead of moving the slider.
	var nudge := s.step if key == "sensitivity" else 0.1
	var minus := UIKit.paper_button("−", false, 20)
	minus.custom_minimum_size = Vector2(40, 38)
	minus.pressed.connect(func(): s.value = clampf(s.value - nudge, 0.0, 1.0))
	row.add_child(minus)
	row.add_child(s)
	var plus := UIKit.paper_button("+", false, 20)
	plus.custom_minimum_size = Vector2(40, 38)
	plus.pressed.connect(func(): s.value = clampf(s.value + nudge, 0.0, 1.0))
	row.add_child(plus)
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
	# Clear on/off switches (the default "on" icon is nearly invisible on the paper).
	c.add_theme_icon_override("checked", _switch_icon(true))
	c.add_theme_icon_override("unchecked", _switch_icon(false))
	c.add_theme_icon_override("checked_disabled", _switch_icon(true))
	c.add_theme_icon_override("unchecked_disabled", _switch_icon(false))
	c.toggled.connect(on_change)
	_checks[key] = c
	return c


static var _switch_cache := {}


## A pill-shaped switch: green with the knob on the right when on, grey with it on the left.
static func _switch_icon(on: bool) -> Texture2D:
	if _switch_cache.has(on):
		return _switch_cache[on]
	var w := 56
	var h := 30
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := Color("#5fae6a") if on else Color("#b9b2a6")
	var r := h * 0.5
	var knob_c := Vector2(w - r, r) if on else Vector2(r, r)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(p.x, r, w - r)
			var dt := p.distance_to(Vector2(cx, r)) - (r - 0.5)
			var a := clampf(0.5 - dt, 0.0, 1.0)
			var col := Color(track, a)
			var dk := p.distance_to(knob_c) - (r - 3.5)
			var ka := clampf(0.5 - dk, 0.0, 1.0)
			col = col.blend(Color(1, 1, 1, ka))
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_switch_cache[on] = tex
	return tex


## Shows the current settings in every control without re-triggering their callbacks.
func _sync() -> void:
	(_sliders.music as HSlider).set_value_no_signal(Settings.music_volume)
	(_sliders.sfx as HSlider).set_value_no_signal(Settings.sfx_volume)
	(_sliders.ambience as HSlider).set_value_no_signal(Settings.ambience_volume)
	(_sliders.sensitivity as HSlider).set_value_no_signal(inverse_lerp(0.5, 1.6, Settings.sensitivity))
	(_checks.invert as CheckButton).set_pressed_no_signal(Settings.invert_pitch)
	(_checks.tips as CheckButton).set_pressed_no_signal(Settings.show_tips)
	(_checks.fps as CheckButton).set_pressed_no_signal(Settings.show_fps)
	(_checks.ghost as CheckButton).set_pressed_no_signal(Settings.show_ghost)
	for cid in _camera_buttons:
		(_camera_buttons[cid] as Button).set_pressed_no_signal(Settings.camera_style == cid)
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
	# Taller in portrait so more of the list shows at once.
	var tall := 1180.0 if s.y > s.x else 720.0
	_sheet.size = Vector2(minf(s.x - 24.0, 760.0), minf(s.y - 24.0, tall))
	_sheet.position = (s - _sheet.size) * 0.5
