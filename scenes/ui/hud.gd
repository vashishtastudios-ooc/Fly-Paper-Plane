extends CanvasLayer
## In-flight HUD, drawn like notes stuck on the screen: a taped paper tag with height and speed,
## small tags for gusts, stars and the clock, the target tag with its heading arrow, a paper
## climb / sink gauge, banners and floating score texts, the screen-edge target arrow, and the
## flight "juice": ring pops, the ring streak, speed lines and bullseye confetti.

const INK := Color("#2b3a5c")
const PENCIL := Color("#6b665c")

var _root: Control
var _fps: Label
var _tl: PaperTag
var _height: Label
var _speed: Label
var _tr: HBoxContainer
var _gusts: GustDoodles
var _stars: Label
var _timer: Label
var _target_pill: PaperTag
var _target_label: Label
var _heading: UIWidgets.HeadingArrow
var _vario: PaperVario
var _banner: Label
var _banner_tween: Tween
var _banner_queue: Array = []
var _floaters: Array = []
var _float_root: Control
var _edge: UIWidgets.EdgeArrow
var _fx: FxLayer


func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Speed lines and pops sit under the paper tags.
	_fx = FxLayer.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_fx)

	_tl = PaperTag.new()
	_tl.tape = true
	_tl.seed_value = 3
	var tlv := VBoxContainer.new()
	tlv.add_theme_constant_override("separation", -8)
	_tl.add_child(tlv)
	_height = UIKit.label("14 m", UIKit.display_font(), 30, INK)
	_speed = UIKit.label("36 km/h", UIKit.ui_font(), 20, PENCIL)
	tlv.add_child(_height)
	tlv.add_child(_speed)
	_root.add_child(_tl)
	_fps = UIKit.label("", UIKit.ui_font(), 18, Color.WHITE)
	_fps.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_fps.add_theme_constant_override("outline_size", 6)
	_fps.visible = false
	_root.add_child(_fps)

	_tr = HBoxContainer.new()
	_tr.add_theme_constant_override("separation", 6)
	_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tr)
	var gp := PaperTag.new()
	gp.seed_value = 7
	_gusts = GustDoodles.new()
	gp.add_child(_gusts)
	_tr.add_child(gp)
	var sp := PaperTag.new()
	sp.seed_value = 11
	_stars = UIKit.label("★ 0/0", UIKit.display_font(), 26, Color("#c98a12"))
	sp.add_child(_stars)
	_tr.add_child(sp)
	var tp := PaperTag.new()
	tp.seed_value = 13
	_timer = UIKit.label("0.0 s", UIKit.display_font(), 26, INK)
	_timer.custom_minimum_size.x = 70
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tp.add_child(_timer)
	_tr.add_child(tp)

	_target_pill = PaperTag.new()
	_target_pill.seed_value = 17
	_target_pill.tape = true
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 8)
	_target_pill.add_child(th)
	_heading = UIWidgets.HeadingArrow.new()
	th.add_child(_heading)
	_target_label = UIKit.label("", UIKit.display_font(), 24, INK)
	th.add_child(_target_label)
	_root.add_child(_target_pill)

	_vario = PaperVario.new()
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


func _layout() -> void:
	var s := Settings.viewport_size()
	var m := Settings.safe_margins()
	var portrait := s.y > s.x
	_tl.position = Vector2(m.x + 8, m.y + 8)
	var right_pad := 74.0 if Settings.touch_ui else 8.0
	_tr.reset_size()
	_tr.position = Vector2(s.x - m.z - right_pad - _tr.get_combined_minimum_size().x, m.y + 8)
	_target_pill.reset_size()
	var tw := _target_pill.get_combined_minimum_size().x
	var ty := m.y + 8 + (70.0 if portrait else 0.0)
	_target_pill.position = Vector2((s.x - tw) * 0.5, ty)
	_vario.position = Vector2(m.x + 10, s.y * 0.5 - _vario.custom_minimum_size.y * 0.5)
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
	_fx.clear()


## Per-frame update while flying.
func update_flight(plane: PaperPlane, level: LevelRuntime, cam: Camera3D, time: float, delta: float) -> void:
	_fps.visible = Settings.show_fps
	if _fps.visible:
		_fps.text = "%d fps" % Engine.get_frames_per_second()
		_fps.position = _tl.position + Vector2(8, _tl.size.y + 6)
	var p := plane.get_global_transform_interpolated().origin
	_height.text = "%d m" % maxi(0, roundi(plane.agl))
	_speed.text = "%d km/h" % roundi(plane.state.v * 3.6)
	# The speed turns warm when the plane is getting slow.
	_speed.add_theme_color_override("font_color", Color("#c8423b") if plane.state.v < 6.0 else PENCIL)
	_gusts.set_value(plane.gusts)
	_stars.text = "★ %d/%d" % [level.stars_collected, level.stars_total()]
	_timer.text = "%.1f s" % time
	_vario.set_vs(plane.state.vy)
	var tgt := level.current_target()
	var tpos: Vector3 = tgt.position
	var dist := Vector2(tpos.x - p.x, tpos.z - p.z).length()
	var dy := tpos.y - p.y
	var vert := "%d m %s" % [absi(roundi(dy)), "above" if dy >= 0.0 else "below"]
	_target_label.text = "%s  ·  %d m  ·  %s" % [tgt.label, roundi(dist), vert]
	var yaw := plane.state.yaw
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	var to := Vector2(tpos.x - p.x, tpos.z - p.z).normalized()
	_heading.set_angle(atan2(to.dot(right), to.dot(fwd)))
	_layout_target_pill()
	_update_edge_arrow(cam, tpos)
	_update_floaters(cam, delta)
	# Speed lines: from 50 km/h, strongest at the plane's top speed.
	_fx.speed = clampf((plane.state.v - 14.0) / 7.0, 0.0, 1.0) if plane.mode == PaperPlane.Mode.FLYING else 0.0


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


## Shows a banner straight away, dropping whatever is showing or waiting (e.g. the landing result).
func banner_now(text: String, color := Color.WHITE, duration := 1.6) -> void:
	_banner_queue.clear()
	if _banner_tween:
		_banner_tween.kill()
	banner(text, color, duration)


func _next_banner() -> void:
	if _banner_queue.is_empty():
		return
	var b: Array = _banner_queue.pop_front()
	banner(b[0], b[1], b[2])


func float_text(world_pos: Vector3, text: String, color := UIKit.GOLD, size := 40) -> void:
	var l := UIKit.label(text, UIKit.display_font(), size, color)
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


# --- Juice ----------------------------------------------------------------------------------

## A ring of light bursting out from a ring the plane just flew through.
func pop(world_pos: Vector3, cam: Camera3D, color: Color, big := false) -> void:
	if cam == null or cam.is_position_behind(world_pos):
		return
	_fx.add_pop(cam.unproject_position(world_pos), color, big)


## Paper confetti raining down from the top of the screen (a bullseye).
func confetti() -> void:
	_fx.add_confetti(Settings.viewport_size())


# --- Paper pieces ---------------------------------------------------------------------------

## A torn scrap of paper (optionally taped on) holding a child, like a sticky note on the screen.
class PaperTag extends PanelContainer:
	var tape := false
	var seed_value := 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 7
		add_theme_stylebox_override("panel", sb)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_colored_polygon(MenuUI.torn_rect(Rect2(r.position + Vector2(2, 3), r.size), 1.6, seed_value, 10.0), Color(0.15, 0.08, 0.02, 0.22))
		draw_colored_polygon(MenuUI.torn_rect(r, 1.6, seed_value, 10.0), Color("#fbf8ef"))
		if tape:
			var tw := minf(46.0, size.x * 0.4)
			var tr := Rect2(Vector2(size.x * 0.5 - tw * 0.5, -6), Vector2(tw, 13))
			draw_set_transform(tr.get_center(), -0.05, Vector2.ONE)
			draw_rect(Rect2(-tr.size * 0.5, tr.size), Color(0.96, 0.66, 0.72, 0.75))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Three hand-drawn wind swirls: inked when the gust is ready, pencil outline when used, the
## refilling one drawn part-way.
class GustDoodles extends Control:
	var value := 3.0

	func _init() -> void:
		custom_minimum_size = Vector2(96, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float) -> void:
		if absf(v - value) > 0.01:
			value = v
			queue_redraw()

	func _draw() -> void:
		for i in 3:
			var c := Vector2(16 + i * 32, size.y * 0.5)
			var f := clampf(value - i, 0.0, 1.0)
			var col := Color("#2f6f8f") if f >= 1.0 else Color(0.42, 0.4, 0.36, 0.45)
			_swirl(c, col, 1.0, 2.6 if f >= 1.0 else 1.6)
			if f > 0.0 and f < 1.0:
				_swirl(c, Color("#2f6f8f"), f, 2.6)

	## A spiral of wind ending in a little tail; `amount` draws only part of it.
	func _swirl(c: Vector2, col: Color, amount: float, w: float) -> void:
		var pts := PackedVector2Array()
		var n := int(18 * amount) + 2
		for k in n:
			var t := float(k) / 18.0
			var a := -PI * 0.5 + t * TAU * 1.1
			var r := 3.0 + t * 8.5
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		if pts.size() > 1:
			draw_polyline(pts, col, w, true)


## The climb / sink gauge on a paper strip: green when climbing, blue when sinking.
class PaperVario extends Control:
	var vs := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(34, 190)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_vs(v: float) -> void:
		vs = v
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_colored_polygon(MenuUI.torn_rect(Rect2(r.position + Vector2(2, 3), r.size), 1.4, 23, 10.0), Color(0.15, 0.08, 0.02, 0.2))
		draw_colored_polygon(MenuUI.torn_rect(r, 1.4, 23, 10.0), Color("#fbf8ef"))
		var mid := size.y * 0.5
		var h := size.y * 0.5 - 10.0
		for k in range(-4, 5):
			var y := mid - k * h / 4.0
			var w := 10.0 if k == 0 else 5.0
			draw_line(Vector2(size.x * 0.5 - w, y), Vector2(size.x * 0.5 + w, y), Color(0.42, 0.4, 0.36, 0.6), 1.5, true)
		var f := clampf(vs / 4.0, -1.0, 1.0)
		var col := Color("#3a9a52") if f >= 0.0 else Color("#3b78b8")
		var y1 := mid - f * h
		draw_rect(Rect2(size.x * 0.5 - 5, minf(mid, y1), 10, absf(y1 - mid)), Color(col, 0.75))
		var tip := Vector2(size.x * 0.5, y1)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-9, 0), tip + Vector2(9, 0), tip + Vector2(0, -7.0 * signf(f + 0.0001))]), col)


## Screen effects under the tags: speed lines at high speed, ring pops, confetti.
class FxLayer extends Control:
	var speed := 0.0
	var _t := 0.0
	var _pops: Array = []
	var _confetti: Array = []
	var _rng := RandomNumberGenerator.new()
	var _was_active := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func clear() -> void:
		_pops.clear()
		_confetti.clear()
		speed = 0.0
		queue_redraw()

	func add_pop(at: Vector2, col: Color, big: bool) -> void:
		_pops.append({"at": at, "t": 0.0, "col": col, "big": big})

	func add_confetti(s: Vector2) -> void:
		var cols := [Color("#e8546a"), Color("#f2c14e"), Color("#6fb4e8"), Color("#7fd08c"), Color("#c38be8"), Color("#ff9a33")]
		# Starts already on screen (the top third) so it shows straight away, even in slow motion.
		for i in 130:
			_confetti.append({"p": Vector2(_rng.randf_range(0, s.x), _rng.randf_range(-s.y * 0.15, s.y * 0.35)),
				"v": Vector2(_rng.randf_range(-40, 40), _rng.randf_range(160, 320)), "a": _rng.randf() * TAU,
				"w": _rng.randf_range(-6.0, 6.0), "col": cols[i % cols.size()], "s": _rng.randf_range(6.0, 11.0)})

	func _process(delta: float) -> void:
		_t += delta
		for i in range(_pops.size() - 1, -1, -1):
			_pops[i].t += delta
			if _pops[i].t > 0.45:
				_pops.remove_at(i)
		var h := size.y
		for i in range(_confetti.size() - 1, -1, -1):
			var c: Dictionary = _confetti[i]
			c.p += c.v * delta + Vector2(sin(_t * 3.0 + c.a) * 30.0 * delta, 0)
			c.a += c.w * delta
			if c.p.y > h + 20.0:
				_confetti.remove_at(i)
		# Redraw while anything is showing, plus one last frame to clear it.
		var active := speed > 0.01 or not _pops.is_empty() or not _confetti.is_empty()
		if active or _was_active:
			queue_redraw()
		_was_active = active

	func _draw() -> void:
		var s := size
		var c := s * 0.5
		if speed > 0.01:
			# Streaks rushing out from the middle of the screen, more and longer the faster.
			var n := int(10 + 26 * speed)
			for i in n:
				var a := float(i) / n * TAU + float(i * 37 % 11) * 0.11
				var phase := fmod(_t * (1.6 + float(i % 5) * 0.3) + float(i) * 0.37, 1.0)
				var dir := Vector2(cos(a), sin(a))
				var r0 := lerpf(0.38, 1.1, phase) * s.length() * 0.5
				var len := (60.0 + 140.0 * speed) * (0.6 + phase)
				var alpha := (0.25 + 0.45 * speed) * sin(phase * PI)
				# A faint dark edge keeps the white streak visible against a bright sky.
				draw_line(c + dir * r0, c + dir * (r0 + len), Color(0.2, 0.15, 0.1, alpha * 0.25), 5.0, true)
				draw_line(c + dir * r0, c + dir * (r0 + len), Color(1, 1, 1, alpha), 2.6, true)
		for p in _pops:
			var t: float = p.t / 0.45
			var r: float = lerpf(18.0, 110.0 if p.big else 70.0, 1.0 - pow(1.0 - t, 3.0))
			draw_arc(p.at, r, 0, TAU, 40, Color(p.col, (1.0 - t) * 0.9), lerpf(7.0, 1.5, t), true)
			draw_arc(p.at, r * 0.62, 0, TAU, 32, Color(1, 1, 1, (1.0 - t) * 0.6), lerpf(4.0, 1.0, t), true)
		for cf in _confetti:
			draw_set_transform(cf.p, cf.a, Vector2(1.0, absf(sin(cf.a * 2.0)) * 0.8 + 0.2))
			draw_rect(Rect2(-cf.s * 0.5, -cf.s * 0.3, cf.s, cf.s * 0.6), cf.col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
