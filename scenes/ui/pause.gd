extends CanvasLayer
## Pause screen. Runs while the tree is paused.

signal resume_pressed
signal restart_pressed
signal flights_pressed

var _sheet: NotebookSheet
var _resume: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.06, 0.02, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	_sheet = NotebookSheet.new()
	_sheet.tilt_degrees = 1.3
	_sheet.holes = false
	root.add_child(_sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_sheet.add_child(v)
	v.add_child(UIKit.label("Paused", UIKit.display_font(), 58, UIKit.INK))
	_resume = UIKit.paper_button("Keep flying", true, 30)
	_resume.pressed.connect(func(): resume_pressed.emit())
	v.add_child(_resume)
	var restart := UIKit.paper_button("Restart flight", false, 26)
	restart.pressed.connect(func(): restart_pressed.emit())
	v.add_child(restart)
	var flights := UIKit.paper_button("Flights", false, 26)
	flights.pressed.connect(func(): flights_pressed.emit())
	v.add_child(flights)
	get_viewport().size_changed.connect(_layout)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		resume_pressed.emit()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	_layout()
	if not get_tree().process_frame.is_connected(_layout):
		get_tree().process_frame.connect(_layout, CONNECT_ONE_SHOT)
	_resume.grab_focus()


func close() -> void:
	visible = false


func _layout() -> void:
	var s := Settings.viewport_size()
	_sheet.size = Vector2(minf(s.x - 40.0, 380.0), minf(s.y - 40.0, 380.0))
	_sheet.position = (s - _sheet.size) * 0.5
