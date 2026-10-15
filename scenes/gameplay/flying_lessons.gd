class_name FlyingLessons
extends CanvasLayer
## The first-flight tutorial: a forgiving practice course with one lesson at a time. Each lesson
## shows a prompt card and waits until the player actually does it (glide, turn left, dive and
## climb, ride rising air, use a gust, turn right, land). A crash puts the plane straight back in
## the air at the start of the current lesson.

signal finished
signal skip_pressed
## The plane flew past where the current lesson happens: put it back at the lesson's start.
signal retry_needed

## Each lesson: id, title, text for keyboard, text for touch, checkpoint [position, yaw].
const LESSONS := [
	["glide", "Let it glide", "Your paper plane glides all by itself. Just watch it fly for a moment.",
		"Your paper plane glides all by itself. Just watch it fly for a moment.", [Vector3(14.3, 5.9, -31.2), PI * 0.5]],
	["left", "Turn left", "Hold A to turn left, toward the blue ring.",
		"Drag left on the left side of the screen to turn left, toward the blue ring.", [Vector3(9.0, 5.6, -32.5), PI * 0.5]],
	["dive", "Dive, then climb", "Hold S to dive and pick up speed, then W to climb. Climbing costs speed, so don't climb for long.",
		"Drag down to dive and pick up speed, then up to climb. Climbing costs speed, so don't climb for long.", [Vector3(0.0, 4.8, -48.0), 0.0]],
	["lift", "Rising air", "See the green shimmer ahead? That's rising air. Fly into it and it lifts you up.",
		"See the green shimmer ahead? That's rising air. Fly into it and it lifts you up.", [Vector3(0.0, 4.2, -64.0), 0.0]],
	["gust", "Use a gust", "Press Space for a quick puff of lift. You get three gusts every flight.",
		"Tap the Gust button for a quick puff of lift. You get three gusts every flight.", [Vector3(0.0, 8.0, -80.0), 0.0]],
	["right", "Turn right", "Hold D to turn right, into the park.",
		"Drag right to turn right, into the park.", [Vector3(0.0, 8.7, -94.0), 0.0]],
	["land", "Land on the circle", "Follow the dotted line down to the circle. Come in low and slow for a soft landing.",
		"Follow the dotted line down to the circle. Come in low and slow for a soft landing.", [Vector3(-10.0, 7.0, -111.0), PI * 0.5]],
]

## For each lesson, how far down the course (z) the plane may go before it's sent back to try again.
const MISSED_PAST := {"dive": -70.0, "lift": -92.0, "gust": -104.0, "right": -124.0}

var plane: PaperPlane
var step := 0
var _t := 0.0
var _lift_t := 0.0
var _saw_dive := false
var _done_flash := 0.0
var _finished := false
var _card: PanelContainer
var _num: Label
var _title: Label
var _body: Label


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.99, 0.97, 0.92, 0.96)
	sb.border_color = Color(UIKit.INK, 0.7)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0.2, 0.1, 0.02, 0.25)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(2, 4)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	_card.add_theme_stylebox_override("panel", sb)
	root.add_child(_card)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	_card.add_child(h)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_num = UIKit.label("", UIKit.ui_font(), 17, UIKit.MARGIN)
	v.add_child(_num)
	_title = UIKit.label("", UIKit.display_font(), 40, UIKit.INK)
	v.add_child(_title)
	_body = UIKit.label("", UIKit.body_font(), 21, UIKit.INK_DARK)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_body)
	var skip := UIKit.paper_button("Skip lessons", false, 20)
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(func(): skip_pressed.emit())
	h.add_child(skip)
	get_viewport().size_changed.connect(_layout)
	_show_step()
	_layout()


func _layout() -> void:
	var s := Settings.viewport_size()
	var w := minf(s.x * 0.92, 760.0)
	_card.custom_minimum_size = Vector2(w, 0)
	# Give the text its real width up front, so it wraps to a few lines (not a tall column).
	_body.custom_minimum_size = Vector2(w - 250.0, 0)
	_card.position = Vector2((s.x - w) * 0.5, 74.0 * UIKit.ui_scale())
	_fit.call_deferred()


## Shrinks the card to its content (it would otherwise keep its tallest size).
func _fit() -> void:
	_card.reset_size()


func _show_step() -> void:
	var l: Array = LESSONS[step]
	_num.text = "LESSON %d OF %d" % [step + 1, LESSONS.size()]
	_title.text = l[1]
	_title.add_theme_color_override("font_color", UIKit.INK)
	_body.text = l[3] if Settings.touch_ui else l[2]
	_fit.call_deferred()
	_t = 0.0
	_lift_t = 0.0
	_saw_dive = false


## Where to put the plane back after a crash: [position, yaw].
func checkpoint() -> Array:
	return LESSONS[step][4]


func _complete() -> void:
	Audio.play("star", -4.0, 1.2)
	_title.text = "Nice!"
	_title.add_theme_color_override("font_color", Color("#3f9a5a"))
	_done_flash = 0.9


## The plane landed on the circle: the lessons are done.
func on_landed() -> void:
	step = LESSONS.size() - 1
	_num.text = "ALL DONE"
	_title.text = "You can fly!"
	_title.add_theme_color_override("font_color", Color("#3f9a5a"))
	_body.text = "That's everything you need. Next up: Flight 1, Window to the Picnic."
	_fit.call_deferred()
	_finished = true
	finished.emit()


func _physics_process(delta: float) -> void:
	if _finished or plane == null or plane.mode != PaperPlane.Mode.FLYING:
		return
	if _done_flash > 0.0:
		# A moment of "Nice!", then the next lesson.
		_done_flash -= delta
		if _done_flash <= 0.0:
			_done_flash = 0.0
			if step < LESSONS.size() - 1:
				step += 1
				_show_step()
		return
	_t += delta
	var s := plane.state
	var fwd := Vector3(-sin(s.yaw), 0.0, -cos(s.yaw))
	match LESSONS[step][0]:
		"glide":
			if _t > 2.6:
				_complete()
		"left":
			if fwd.z < -0.8 and s.pos.x < 6.0:
				_complete()
		"dive":
			if s.vy < -2.0:
				_saw_dive = true
			elif _saw_dive and s.vy > 0.4:
				_complete()
		"lift":
			_lift_t = _lift_t + delta if plane.lift > 1.0 else maxf(0.0, _lift_t - delta * 0.5)
			if _lift_t > 1.0:
				_complete()
		"gust":
			if plane.gusts < plane.gust_max - 0.5:
				_complete()
		"right":
			if fwd.x < -0.7:
				_complete()
	# Flew past the place for this lesson (e.g. beyond the rising air) without doing it.
	var past: float = MISSED_PAST.get(LESSONS[step][0], -INF)
	if _done_flash == 0.0 and s.pos.z < past:
		retry_needed.emit()
