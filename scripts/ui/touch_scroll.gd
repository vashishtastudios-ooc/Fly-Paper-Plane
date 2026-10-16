class_name TouchScroll
extends Node
## Finger-drag scrolling for a ScrollContainer full of buttons and sliders. A built-in
## ScrollContainer only scrolls when the drag starts on an empty spot; this scrolls on any mostly
## vertical drag that starts inside it (even on a button or slider) and swallows that touch so
## the button isn't pressed. Sideways drags are left alone, so sliders still slide.

## Movement (in pixels) before a drag counts as a scroll.
const THRESHOLD := 12.0

var scroll: ScrollContainer
var _index := -1
var _start := Vector2.ZERO
var _start_scroll := 0
var _dragging := false


static func attach(container: ScrollContainer) -> TouchScroll:
	var ts := TouchScroll.new()
	ts.scroll = container
	container.add_child(ts)
	return ts


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if scroll == null or not scroll.is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _index == -1 and scroll.get_global_rect().has_point(t.position):
				_index = t.index
				_start = t.position
				_start_scroll = scroll.scroll_vertical
				_dragging = false
		elif t.index == _index:
			_index = -1
			if _dragging:
				get_viewport().set_input_as_handled()
				# The mouse release emulated from this touch must not click anything either.
				_end_drag.call_deferred()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index != _index:
			return
		var delta := d.position - _start
		if not _dragging and absf(delta.y) > THRESHOLD and absf(delta.y) > absf(delta.x):
			_dragging = true
			# Let go of whatever the finger was holding (a button or a slider grab).
			get_viewport().gui_release_focus()
		if _dragging:
			scroll.scroll_vertical = _start_scroll - int(delta.y)
			get_viewport().set_input_as_handled()
	elif _dragging and (event is InputEventMouseButton or event is InputEventMouseMotion):
		# Mouse events emulated from the dragging finger.
		get_viewport().set_input_as_handled()


func _end_drag() -> void:
	_dragging = false
