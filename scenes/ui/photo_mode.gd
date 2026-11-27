class_name PhotoMode
extends CanvasLayer
## Photo mode (PC): the game frozen, the HUD hidden, and the camera free to circle the plane.
## Takes a clean picture (no buttons or hints) into Pictures\Paper Plane Playground.

signal closed

const MIN_DIST := 1.2
const MAX_DIST := 16.0

var _cam: Camera3D
var _saved_xform: Transform3D
var _saved_fov := 64.0
var _center := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.25
var _dist := 4.0
var _hint: Label
var _toast: Label
var _flash: ColorRect
var _busy := false
var _dragging := false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_flash = ColorRect.new()
	_flash.color = Color.WHITE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	root.add_child(_flash)
	_hint = _outlined(UIKit.ui_font(), 20)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -86
	_hint.offset_bottom = -18
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	root.add_child(_hint)
	_toast = _outlined(UIKit.display_font(), 32)
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 28
	_toast.offset_bottom = 80
	_toast.modulate.a = 0.0
	root.add_child(_toast)
	visible = false
	set_process(false)


func _outlined(font: Font, size: int) -> Label:
	var l := UIKit.label("", font, size, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.02, 0.8))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Starts photo mode around `center` (the plane), from where the camera is now. The game must
## already be paused.
func open(cam: Camera3D, center: Vector3) -> void:
	_cam = cam
	_saved_xform = cam.global_transform
	_saved_fov = cam.fov
	_center = center
	var off := cam.global_position - center
	_dist = clampf(off.length(), 2.5, 8.0)
	_yaw = atan2(off.x, off.z)
	_pitch = asin(clampf(off.y / maxf(off.length(), 0.01), -1.0, 1.0))
	_dragging = false
	_busy = false
	var keys := "Drag the mouse or %s %s %s %s to look around  ·  Wheel or %s / %s to zoom  ·  Enter to take a photo  ·  Esc to go back" % [
		Settings.key_label("climb"), Settings.key_label("turn_left"), Settings.key_label("dive"), Settings.key_label("turn_right"),
		Settings.key_label("roll_left"), Settings.key_label("roll_right")]
	if not Input.get_connected_joypads().is_empty():
		keys += "\nController: sticks to look around  ·  triggers to zoom  ·  A takes a photo  ·  B goes back"
	_hint.text = keys
	_hint.visible = true
	_toast.modulate.a = 0.0
	visible = true
	set_process(true)
	_apply()


func close() -> void:
	if not visible:
		return
	visible = false
	set_process(false)
	if _cam:
		_cam.global_transform = _saved_xform
		_cam.fov = _saved_fov
	closed.emit()


func _process(delta: float) -> void:
	if _busy:
		return
	var turn := Input.get_axis("turn_left", "turn_right")
	var tilt := Input.get_axis("dive", "climb")
	var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if rs.length() < 0.2:
		rs = Vector2.ZERO
	_yaw += (turn + rs.x) * 1.6 * delta
	_pitch += (tilt - rs.y) * 1.1 * delta
	var zoom := Input.get_action_strength("roll_left") - Input.get_action_strength("roll_right")
	zoom += Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
	_dist = clampf(_dist * exp(zoom * 1.3 * delta), MIN_DIST, MAX_DIST)
	_apply()


func _input(event: InputEvent) -> void:
	if not visible or _busy:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(MIN_DIST, _dist * 0.9)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(MAX_DIST, _dist / 0.9)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_dragging = mb.pressed
		_apply()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		var rel := (event as InputEventMouseMotion).relative
		_yaw -= rel.x * 0.006
		_pitch += rel.y * 0.005
		_apply()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("throw"):
		get_viewport().set_input_as_handled()
		_take()
	elif event.is_action_pressed("pause") or event.is_action_pressed("photo") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Places the camera on a sphere around the plane, never under the ground.
func _apply() -> void:
	if _cam == null:
		return
	_pitch = clampf(_pitch, -0.35, 1.35)
	var dir := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	var pos := _center + dir * _dist
	pos.y = maxf(pos.y, Terrain.ground_height(pos.x, pos.z) + 0.25)
	_cam.global_position = pos
	_cam.look_at(_center, Vector3.UP)


## Takes the picture without the hints, then flashes and says where it went.
func _take() -> void:
	_busy = true
	_hint.visible = false
	_toast.modulate.a = 0.0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _save(img)
	if path != "":
		Profile.feat("photos")
		Profile.check_achievements()
	_hint.visible = true
	_busy = false
	Audio.play("click", 0.0, 0.8)
	_flash.modulate.a = 0.85
	var t := create_tween()
	t.tween_property(_flash, "modulate:a", 0.0, 0.35)
	if path == "":
		_toast.text = "Couldn't save the photo"
	elif path.begins_with(OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)) and OS.get_system_dir(OS.SYSTEM_DIR_PICTURES) != "":
		_toast.text = "Snap! Saved in Pictures › Paper Plane Playground"
	else:
		_toast.text = "Snap! Saved to " + path
	_toast.modulate.a = 1.0
	var tt := create_tween()
	tt.tween_interval(2.2)
	tt.tween_property(_toast, "modulate:a", 0.0, 0.5)


## Saves into Pictures\Paper Plane Playground (or the game's own folder if that fails).
## Returns the file's path, or "" when it could not be saved.
static func _save(img: Image) -> String:
	var dirs := []
	var pics := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pics != "":
		dirs.append(pics.path_join("Paper Plane Playground"))
	dirs.append(OS.get_user_data_dir().path_join("photos"))
	var t := Time.get_datetime_dict_from_system()
	var file := "Paper Plane %04d-%02d-%02d %02d-%02d-%02d.png" % [t.year, t.month, t.day, t.hour, t.minute, t.second]
	for d in dirs:
		DirAccess.make_dir_recursive_absolute(d)
		if not DirAccess.dir_exists_absolute(d):
			continue
		var path: String = d.path_join(file)
		if img.save_png(path) == OK:
			return path
	return ""
