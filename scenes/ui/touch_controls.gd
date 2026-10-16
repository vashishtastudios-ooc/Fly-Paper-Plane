extends CanvasLayer
## Touch controls: a floating virtual stick on the left 60% of the screen, Gust and Roll
## buttons on the right and a pause button in the top right corner. Multitouch aware.

signal gust_pressed
signal roll_pressed(direction: float)
signal pause_pressed

const STICK_REGION := 0.72
const STICK_MAX := 44.0
## Response curve for turning: small drags already turn noticeably (1 = linear).
const STICK_CURVE := 0.75
## Ignore tiny movements of the thumb.
const DEAD_ZONE := 0.12
const RING_RADIUS := 60.0
const KNOB_RADIUS := 26.0
const GUST_RADIUS := 42.0
const ROLL_RADIUS := 31.0
const PAUSE_SIZE := 52.0
const HINT_TIME := 5.0

## Stick deflection: x right, y down, each -1..1.
var stick := Vector2.ZERO
var gust_charge := 3.0

var _canvas: Control
var _stick_index := -1
var _origin := Vector2.ZERO
var _pos := Vector2.ZERO
var _gust_index := -1
var _roll_index := -1
var _hint_t := 0.0
var _hint: Label
var _font: Font
var _flash_gust := 0.0
var _flash_roll := 0.0


func _ready() -> void:
	layer = 6
	_font = UIKit.ui_font()
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	_hint = UIKit.label("Drag here to steer, up to climb", UIKit.display_font(), 30, Color.WHITE)
	_hint.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.05, 0.7))
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_hint)
	visible = false


func open() -> void:
	visible = true
	_hint_t = HINT_TIME
	_release_all()


func close() -> void:
	visible = false
	_release_all()


func _release_all() -> void:
	_stick_index = -1
	_gust_index = -1
	_roll_index = -1
	stick = Vector2.ZERO
	if _canvas:
		_canvas.queue_redraw()


func _margins() -> Vector4:
	return Settings.safe_margins()


func _gust_center() -> Vector2:
	var s := Settings.viewport_size()
	var m := _margins()
	return Vector2(s.x - m.z - 28.0 - GUST_RADIUS, s.y - m.w - 28.0 - GUST_RADIUS)


func _roll_center() -> Vector2:
	var g := _gust_center()
	return g + Vector2(-GUST_RADIUS - ROLL_RADIUS - 22.0, -GUST_RADIUS - 6.0)


func _pause_rect() -> Rect2:
	var s := Settings.viewport_size()
	var m := _margins()
	return Rect2(Vector2(s.x - m.z - 8.0 - PAUSE_SIZE, m.y + 4.0), Vector2(PAUSE_SIZE, PAUSE_SIZE))


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_on_press(t.index, t.position)
		else:
			_on_release(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_index:
			_pos = d.position
			_update_stick()
	elif Settings.mouse_as_finger:
		# PC test of the phone version: the left mouse button is finger 0.
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := event as InputEventMouseButton
			if mb.pressed:
				_on_press(0, mb.position)
			else:
				_on_release(0)
		elif event is InputEventMouseMotion and _stick_index == 0:
			_pos = (event as InputEventMouseMotion).position
			_update_stick()
			get_viewport().set_input_as_handled()


func _on_press(index: int, p: Vector2) -> void:
	var s := Settings.viewport_size()
	if _pause_rect().grow(10.0).has_point(p):
		pause_pressed.emit()
		get_viewport().set_input_as_handled()
		return
	if p.distance_to(_gust_center()) < GUST_RADIUS + 14.0:
		_gust_index = index
		_flash_gust = 0.2
		gust_pressed.emit()
		_canvas.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if p.distance_to(_roll_center()) < ROLL_RADIUS + 12.0:
		_roll_index = index
		_flash_roll = 0.2
		roll_pressed.emit(1.0 if stick.x >= 0.0 else -1.0)
		_canvas.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if p.x < s.x * STICK_REGION and _stick_index == -1:
		_stick_index = index
		_origin = p
		_pos = p
		_hint_t = minf(_hint_t, 0.6)
		_update_stick()
		get_viewport().set_input_as_handled()


func _on_release(index: int) -> void:
	if index == _stick_index:
		_stick_index = -1
		stick = Vector2.ZERO
	if index == _gust_index:
		_gust_index = -1
	if index == _roll_index:
		_roll_index = -1
	_canvas.queue_redraw()


func _update_stick() -> void:
	var d := _pos - _origin
	if d.length() > STICK_MAX:
		d = d.normalized() * STICK_MAX
	var n := d / STICK_MAX
	var x := _dead(n.x)
	var y := _dead(n.y)
	# While turning, the thumb drifts up and down a little: ignore that drift so a long turn
	# doesn't slowly pull the nose up (and stall). Deliberate climbs and dives still count.
	y *= clampf(1.0 - (absf(x) - absf(y) * 1.5), 0.0, 1.0) if absf(x) > absf(y) else 1.0
	stick = Vector2(signf(x) * pow(absf(x), STICK_CURVE), y)
	_canvas.queue_redraw()


func _dead(v: float) -> float:
	return signf(v) * clampf((absf(v) - DEAD_ZONE) / (1.0 - DEAD_ZONE), 0.0, 1.0)


func _process(delta: float) -> void:
	if not visible:
		return
	_hint_t = maxf(0.0, _hint_t - delta)
	var s := Settings.viewport_size()
	_hint.size = Vector2(s.x * STICK_REGION, 50)
	_hint.position = Vector2(0, s.y * 0.62)
	_hint.modulate.a = clampf(_hint_t / 0.6, 0.0, 1.0)
	if _flash_gust > 0.0 or _flash_roll > 0.0:
		_flash_gust = maxf(0.0, _flash_gust - delta)
		_flash_roll = maxf(0.0, _flash_roll - delta)
	_canvas.queue_redraw()


func _draw_controls() -> void:
	var c := _canvas
	if _stick_index != -1:
		c.draw_circle(_origin, RING_RADIUS, Color(1, 1, 1, 0.12))
		c.draw_arc(_origin, RING_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.6), 2.5, true)
		var knob := _origin + stick * STICK_MAX
		c.draw_circle(knob, KNOB_RADIUS, Color(1, 1, 1, 0.55))
		c.draw_arc(knob, KNOB_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.9), 2.0, true)
	elif _hint_t > 0.0:
		var s := Settings.viewport_size()
		var o := Vector2(s.x * STICK_REGION * 0.5, s.y * 0.5)
		c.draw_arc(o, RING_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35 * clampf(_hint_t, 0.0, 1.0)), 2.5, true)
	# Gust button with charge ring.
	var g := _gust_center()
	var pressed_g := _gust_index != -1 or _flash_gust > 0.0
	c.draw_circle(g, GUST_RADIUS, Color(0.1, 0.08, 0.06, 0.55 if not pressed_g else 0.75))
	var frac := clampf(gust_charge / 3.0, 0.0, 1.0)
	c.draw_arc(g, GUST_RADIUS - 3.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, Color("#bfe3ff"), 5.0, true)
	c.draw_arc(g, GUST_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.8), 2.0, true)
	c.draw_string(_font, g + Vector2(-GUST_RADIUS, 8), "Gust", HORIZONTAL_ALIGNMENT_CENTER, GUST_RADIUS * 2.0, 24, Color.WHITE)
	# Roll button.
	var r := _roll_center()
	var pressed_r := _roll_index != -1 or _flash_roll > 0.0
	c.draw_circle(r, ROLL_RADIUS, Color(0.1, 0.08, 0.06, 0.5 if not pressed_r else 0.75))
	c.draw_arc(r, ROLL_RADIUS, 0, TAU, 40, Color(1, 1, 1, 0.75), 2.0, true)
	c.draw_string(_font, r + Vector2(-ROLL_RADIUS, 7), "Roll", HORIZONTAL_ALIGNMENT_CENTER, ROLL_RADIUS * 2.0, 20, Color.WHITE)
	# Pause button.
	var pr := _pause_rect()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.06, 0.5)
	sb.set_corner_radius_all(14)
	c.draw_style_box(sb, pr)
	var pc := pr.get_center()
	c.draw_rect(Rect2(pc + Vector2(-9, -11), Vector2(6, 22)), Color.WHITE)
	c.draw_rect(Rect2(pc + Vector2(3, -11), Vector2(6, 22)), Color.WHITE)
