extends CanvasLayer
## In-flight HUD: height/speed, gusts, stars, timer, target pill with heading arrow,
## variometer, banners, floating score texts and the screen-edge target arrow.

var _root: Control
var _fps: Label
var _tl: PanelContainer
var _height: Label
var _speed: Label
var _tr: HBoxContainer
var _gusts: UIWidgets.GustDots
var _stars: Label
var _timer: Label
var _target_pill: PanelContainer
var _target_label: Label
var _heading: UIWidgets.HeadingArrow
var _vario: UIWidgets.Vario
var _banner: Label
var _banner_tween: Tween
var _banner_queue: Array = []
var _floaters: Array = []
var _float_root: Control
var _edge: UIWidgets.EdgeArrow


func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_tl = _pill()
	var tlv := VBoxContainer.new()
	tlv.add_theme_constant_override("separation", -4)
	_tl.add_child(tlv)
	_height = UIKit.label("Height 0 m", UIKit.ui_font(), 22, Color.WHITE)
	_speed = UIKit.label("Speed 0 km/h", UIKit.ui_font(), 22, Color.WHITE)
	tlv.add_child(_height)
	tlv.add_child(_speed)
	_root.add_child(_tl)
	_fps = UIKit.label("", UIKit.ui_font(), 18, Color.WHITE)
	_fps.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_fps.add_theme_constant_override("outline_size", 6)
	_fps.visible = false
	_root.add_child(_fps)

	_tr = HBoxContainer.new()
	_tr.add_theme_constant_override("separation", 8)
	_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tr)
	var gp := _pill()
	_gusts = UIWidgets.GustDots.new()
	gp.add_child(_gusts)
	_tr.add_child(gp)
	var sp := _pill()
	_stars = UIKit.label("0/0", UIKit.ui_font(), 22, UIKit.GOLD)
	sp.add_child(_stars)
	_tr.add_child(sp)
	var tp := _pill()
	_timer = UIKit.label("0.0", UIKit.ui_font(), 22, Color.WHITE)
	_timer.custom_minimum_size.x = 58
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tp.add_child(_timer)
	_tr.add_child(tp)

	_target_pill = _pill(20.0)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 8)
	_target_pill.add_child(th)
	_heading = UIWidgets.HeadingArrow.new()
	th.add_child(_heading)
	_target_label = UIKit.label("", UIKit.ui_font(), 22, Color.WHITE)
	th.add_child(_target_label)
	_root.add_child(_target_pill)

	_vario = UIWidgets.Vario.new()
	_root.add_child(_vario)

	_banner = UIKit.label("", UIKit.display_font(), 56, Color.WHITE)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.05, 0.75))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	_root.add_child(_banner)

	_float_root = Control.new()
	_float_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_float_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_float_root)

	_edge = UIWidgets.EdgeArrow.new()
	_edge.visible = false
	_root.add_child(_edge)

	get_viewport().size_changed.connect(_layout)
	_layout()
	visible = false


func _pill(radius := 18.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.pill_style(radius))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _layout() -> void:
	var s := Settings.viewport_size()
	var m := Settings.safe_margins()
	var portrait := s.y > s.x
	_tl.position = Vector2(m.x + 6, m.y + 6)
	var right_pad := 74.0 if Settings.touch_ui else 6.0
	_tr.reset_size()
	_tr.position = Vector2(s.x - m.z - right_pad - _tr.get_combined_minimum_size().x, m.y + 6)
	_target_pill.reset_size()
	var tw := _target_pill.get_combined_minimum_size().x
	var ty := m.y + 6 + (64.0 if portrait else 0.0)
	_target_pill.position = Vector2((s.x - tw) * 0.5, ty)
	_vario.position = Vector2(m.x + 8, s.y * 0.5 - _vario.custom_minimum_size.y * 0.5)
	_vario.size = _vario.custom_minimum_size
	_banner.size = Vector2(s.x - 80.0, 80)
	_banner.position = Vector2(40.0, s.y * (0.24 if portrait else 0.22))
	_banner.add_theme_font_size_override("font_size", 46 if portrait else 56)


func reset() -> void:
	for f in _floaters:
		(f.label as Label).queue_free()
	_floaters.clear()
	_banner_queue.clear()
	if _banner_tween:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_edge.visible = false


## Per-frame update while flying.
func update_flight(plane: PaperPlane, level: LevelRuntime, cam: Camera3D, time: float, delta: float) -> void:
	_fps.visible = Settings.show_fps
	if _fps.visible:
		_fps.text = "%d fps" % Engine.get_frames_per_second()
		_fps.position = _tl.position + Vector2(8, _tl.size.y + 6)
	var p := plane.get_global_transform_interpolated().origin
	_height.text = "Height %d m" % maxi(0, roundi(plane.agl))
	_speed.text = "Speed %d km/h" % roundi(plane.state.v * 3.6)
	_gusts.set_value(plane.gusts)
	_stars.text = "★ %d/%d" % [level.stars_collected, level.stars_total()]
	_timer.text = "%.1f s" % time
	_vario.set_vs(plane.state.vy)
	var tgt := level.current_target()
	var tpos: Vector3 = tgt.position
	var dist := Vector2(tpos.x - p.x, tpos.z - p.z).length()
	var dy := tpos.y - p.y
	var vert := "%d m %s" % [absi(roundi(dy)), "above" if dy >= 0.0 else "below"]
	_target_label.text = "%s   %d m   %s" % [tgt.label, roundi(dist), vert]
	var yaw := plane.state.yaw
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	var to := Vector2(tpos.x - p.x, tpos.z - p.z).normalized()
	_heading.set_angle(atan2(to.dot(right), to.dot(fwd)))
	_layout_target_pill()
	_update_edge_arrow(cam, tpos)
	_update_floaters(cam, delta)


func _layout_target_pill() -> void:
	var s := Settings.viewport_size()
	_target_pill.reset_size()
	var tw := _target_pill.get_combined_minimum_size().x
	_target_pill.position.x = (s.x - tw) * 0.5


func _update_edge_arrow(cam: Camera3D, target: Vector3) -> void:
	if cam == null:
		_edge.visible = false
		return
	var s := Settings.viewport_size()
	var behind := cam.is_position_behind(target)
	var sp := cam.unproject_position(target)
	var margin := 46.0
	var inside := not behind and sp.x > margin and sp.x < s.x - margin and sp.y > margin and sp.y < s.y - margin
	if inside:
		_edge.visible = false
		return
	var c := s * 0.5
	var dir := sp - c
	if behind:
		dir = -dir
		if dir.length() < 1.0:
			dir = Vector2(0, 1)
	var half := c - Vector2(margin + 8, margin + 8)
	var k := minf(absf(half.x / maxf(absf(dir.x), 0.001)), absf(half.y / maxf(absf(dir.y), 0.001)))
	var pos := c + dir * k
	_edge.visible = true
	_edge.position = pos - _edge.size * 0.5
	_edge.angle = dir.angle()
	_edge.queue_redraw()


func banner(text: String, color := Color.WHITE, duration := 1.6) -> void:
	if _banner_tween and _banner_tween.is_running():
		if _banner.text == text:
			return
		if _banner_queue.size() < 3:
			_banner_queue.append([text, color, duration])
		return
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	# Long tips use a smaller size so they fit on one or two lines.
	var base := 46 if Settings.portrait else 56
	_banner.add_theme_font_size_override("font_size", base if text.length() <= 26 else int(base * 0.68))
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(0.9, 0.9)
	_banner.pivot_offset = _banner.size * 0.5
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.18)
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_interval(duration)
	_banner_tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.35)
	_banner_tween.chain().tween_callback(_next_banner)


func _next_banner() -> void:
	if _banner_queue.is_empty():
		return
	var b: Array = _banner_queue.pop_front()
	banner(b[0], b[1], b[2])


func float_text(world_pos: Vector3, text: String, color := UIKit.GOLD) -> void:
	var l := UIKit.label(text, UIKit.display_font(), 40, color)
	l.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.05, 0.7))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_root.add_child(l)
	_floaters.append({"label": l, "pos": world_pos, "t": 0.0})


func _update_floaters(cam: Camera3D, delta: float) -> void:
	for i in range(_floaters.size() - 1, -1, -1):
		var f: Dictionary = _floaters[i]
		f.t += delta
		var l: Label = f.label
		if f.t > 1.3 or cam == null:
			l.queue_free()
			_floaters.remove_at(i)
			continue
		var wp: Vector3 = f.pos + Vector3(0, 0.5 + f.t * 1.2, 0)
		if cam.is_position_behind(wp):
			l.visible = false
			continue
		l.visible = true
		var sp := cam.unproject_position(wp)
		l.position = sp - l.size * 0.5
		l.modulate.a = 1.0 - smoothstep(0.8, 1.3, f.t)
