extends Node
## Main game flow: loading, menu, intro, throw, flight, landing/crash and results.

@onready var town: TownBuilder = $Town
@onready var level: LevelRuntime = $Level
@onready var plane: PaperPlane = $Plane
@onready var kid: Node3D = $Kid
@onready var menu_plane: Node3D = $MenuPlane
@onready var cam: ChaseCamera = $Camera
@onready var hud: CanvasLayer = $HUD
@onready var touch: CanvasLayer = $TouchControls
@onready var menu: CanvasLayer = $Menu
@onready var intro: CanvasLayer = $LevelIntro
@onready var result: CanvasLayer = $Result
@onready var pause_ui: CanvasLayer = $Pause
@onready var hangar: CanvasLayer = $Hangar
@onready var settings_menu: CanvasLayer = $SettingsMenu
@onready var credits: CanvasLayer = $Credits

var _loading: CanvasLayer
var _end_timer := -1.0
var _pending := {}
var _last_flight_time := 0.0
var _slow_cooldown := 0.0
var collision_debug: CollisionDebug


func _ready() -> void:
	_show_loading()
	_wire()
	cam.plane = plane
	cam.menu_target = menu_plane
	if menu_plane.get_child_count() == 0:
		var mi := MeshInstance3D.new()
		mi.name = "Model"
		mi.mesh = PaperPlaneMesh.get_mesh()
		menu_plane.add_child(mi)
	# The showreel plane always flies with the rainbow trail.
	_menu_trail = PlaneTrail.new()
	_menu_trail.name = "MenuTrail"
	_menu_trail.source = menu_plane
	add_child(_menu_trail)
	_menu_trail.set_style("rainbow")
	plane.level = level
	kid.visible = false
	hud.visible = false
	# Let the loading card render before the heavy town build.
	await get_tree().process_frame
	await get_tree().process_frame
	town.build()
	collision_debug = CollisionDebug.new()
	collision_debug.name = "CollisionDebug"
	collision_debug.plane = plane
	add_child(collision_debug)
	_apply_cosmetics()
	_loading.queue_free()
	go_menu()


func _show_loading() -> void:
	_loading = CanvasLayer.new()
	_loading.layer = 50
	var bg := ColorRect.new()
	bg.color = UIKit.PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(bg)
	var l := UIKit.label("Folding the plane...", UIKit.display_font(), 54, UIKit.INK)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading.add_child(l)
	add_child(_loading)


func _wire() -> void:
	plane.stall_entered.connect(func(): hud.banner("Stall! Nose down", Color("#ffb3a1"), 1.2))
	plane.rising_air.connect(func(): hud.banner("Rising air", UIKit.LIFT, 1.2))
	plane.barrel_roll_done.connect(func(): hud.float_text(plane.state.pos, "+50"))
	plane.landed.connect(_on_landed)
	plane.skipped.connect(func(): hud.banner("Skip!", Color("#bfe3ff"), 0.9))
	plane.crashed.connect(_on_crashed)
	plane.gust_used.connect(func(): Settings.vibrate(20))
	plane.entered_thermal.connect(func(): _tip("thermal", "Rising air! Circle inside it to climb"))
	Game.cosmetics_changed.connect(_apply_cosmetics)
	menu.hangar_pressed.connect(func(): hangar.open())
	menu.settings_pressed.connect(func(): settings_menu.open())
	menu.credits_pressed.connect(func(): credits.open())
	hangar.closed.connect(func(): menu.refresh())
	pause_ui.settings_pressed.connect(func(): settings_menu.open())
	level.star_collected.connect(func(p: Vector3):
		Audio.play("star", -2.0)
		plane.add_star_gust()
		hud.float_text(p, "+100"))
	level.ring_passed.connect(func(p: Vector3):
		Audio.play("ring", -3.0)
		hud.float_text(p, "+25", UIKit.ROUTE_GLOW))
	level.bonus_ring_passed.connect(func(p: Vector3, _pts: int, msg: String):
		Audio.play("bonus", 0.0)
		hud.banner(msg, UIKit.BONUS, 1.8)
		hud.float_text(p, "+%d" % _pts, UIKit.BONUS))
	kid.released.connect(_on_released)
	touch.gust_pressed.connect(func(): plane.use_gust())
	touch.roll_pressed.connect(func(d: float): plane.barrel_roll(d))
	touch.pause_pressed.connect(pause_game)
	menu.level_chosen.connect(start_level)
	intro.throw_pressed.connect(throw_plane)
	intro.flights_pressed.connect(go_menu)
	result.next_pressed.connect(func(): start_level(mini(Game.current_level + 1, Game.levels.size() - 1)))
	result.retry_pressed.connect(func(): start_level(Game.current_level))
	result.flights_pressed.connect(go_menu)
	pause_ui.resume_pressed.connect(resume_game)
	pause_ui.restart_pressed.connect(func():
		resume_game()
		start_level(Game.current_level))
	pause_ui.flights_pressed.connect(func():
		resume_game()
		go_menu())


# --- Flow --------------------------------------------------------------------------------

func go_menu() -> void:
	get_tree().paused = false
	_end_timer = -1.0
	Game.set_state(Game.State.MENU)
	intro.close()
	result.close()
	pause_ui.close()
	hud.visible = false
	touch.close()
	plane.reset()
	level.hide_guides()
	kid.visible = false
	menu_plane.visible = true
	town.set_time_of_day("golden")
	_reel_i = -1
	_update_menu_plane(0.0)
	cam.set_mode(ChaseCamera.Mode.MENU, true)
	menu.open()
	Audio.set_wind(0.0, false)
	Audio.play_music()


func start_level(index: int) -> void:
	if not Game.is_unlocked(index):
		return
	get_tree().paused = false
	_end_timer = -1.0
	Game.current_level = index
	var data := Game.level()
	level.build(data, town)
	town.clear_trees_for_level(data)
	hud.reset()
	plane.reset()
	menu_plane.visible = false
	_hide_reel()
	kid.visible = true
	kid.global_position = data.platform_position
	kid.rotation = Vector3(0, data.start_yaw(), 0)
	kid.reset()
	kid.reset_physics_interpolation()
	cam.intro_center = data.platform_position
	cam.intro_yaw = data.platform_yaw
	cam.set_mode(ChaseCamera.Mode.INTRO, true)
	menu.close()
	result.close()
	pause_ui.close()
	hud.visible = false
	touch.close()
	intro.open(index, data)
	if collision_debug and collision_debug.visible:
		collision_debug.rebuild.call_deferred()
	Audio.set_wind(0.0, false)
	Game.set_state(Game.State.INTRO)


func throw_plane() -> void:
	if Game.state != Game.State.INTRO:
		return
	intro.close()
	get_viewport().gui_release_focus()
	Game.set_state(Game.State.THROWING)
	kid.throw()


func _on_released(hand: Vector3) -> void:
	var data := Game.level()
	plane.launch(hand, data.start_yaw())
	Audio.play("throw", -2.0)
	Game.set_state(Game.State.FLYING)
	cam.set_mode(ChaseCamera.Mode.FOLLOW)
	hud.visible = true
	if Settings.touch_ui:
		touch.open()


func _on_landed(info: Dictionary) -> void:
	Game.set_state(Game.State.LANDED)
	# Any friend waiting at the landing spot (Biscuit the dog) is delighted.
	for buddy in get_tree().get_nodes_in_group("landing_buddy"):
		if level.horizontal_distance_to_pad((buddy as Node3D).global_position) < 4.0:
			buddy.call("celebrate")
	var data := Game.level()
	var stats := {
		"dist": info.dist,
		"radius": data.pad_radius,
		"vertical_impact": info.vertical_impact,
		"speed": info.speed,
		"stars": level.stars_collected,
		"stars_total": level.stars_total(),
		"time": plane.flight_time,
		"par": data.par_time,
		"rings": level.rings_passed,
		"rolls": plane.rolls_done,
		"bonus": level.bonus_points,
	}
	var score := Game.compute_landing_score(stats)
	var ribbons_before := Game.total_ribbons()
	var is_best := Game.record_landing(Game.current_level, score.total, score.ribbons)
	var unlocks := Cosmetics.newly_unlocked(ribbons_before, Game.total_ribbons())
	_pending = {"kind": "land", "score": score, "stats": stats, "best": is_best, "unlocks": unlocks}
	Settings.vibrate(60)
	cam.orbit_center = info.position
	cam.set_mode(ChaseCamera.Mode.ORBIT)
	hud.banner(score.headline, UIKit.GOLD, 1.6)
	level.hide_guides()
	touch.close()
	Audio.set_wind(0.0, false)
	_end_timer = 2.2


func _on_crashed(message: String, _kind: String) -> void:
	Game.set_state(Game.State.CRASHED)
	_pending = {"kind": "crash", "message": message, "stars": level.stars_collected,
		"stars_total": level.stars_total(), "time": plane.flight_time}
	if _kind != "stopped" and _kind != "soaked":
		cam.shake(0.9)
		Settings.vibrate(120)
	cam.orbit_center = plane.state.pos
	cam.set_mode(ChaseCamera.Mode.ORBIT)
	hud.banner(message, Color("#ffb3a1"), 1.3)
	level.hide_guides()
	touch.close()
	Audio.set_wind(0.0, false)
	_end_timer = 1.6


func _show_result() -> void:
	Game.set_state(Game.State.RESULT)
	hud.visible = false
	if _pending.kind == "land":
		result.show_landing(_pending.score, _pending.stats, _pending.best, Game.has_next_level(), _pending.unlocks)
	else:
		result.show_crash(_pending.message, _pending.stars, _pending.stars_total, _pending.time)


func pause_game() -> void:
	if Game.state in [Game.State.FLYING, Game.State.THROWING, Game.State.INTRO]:
		get_tree().paused = true
		pause_ui.open()


func resume_game() -> void:
	pause_ui.close()
	get_tree().paused = false


# --- Per frame ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	match Game.state:
		Game.State.MENU:
			_update_menu_plane(delta)
		Game.State.FLYING:
			var x := Input.get_axis("turn_left", "turn_right")
			var y := Input.get_axis("dive", "climb")
			if touch.visible:
				x += touch.stick.x
				y += -touch.stick.y
				touch.gust_charge = plane.gusts
			x *= Settings.sensitivity
			y *= Settings.sensitivity * (-1.0 if Settings.invert_pitch else 1.0)
			plane.set_controls(clampf(x, -1.0, 1.0), clampf(y, -1.0, 1.0))
			_flight_hints(delta)
			hud.update_flight(plane, level, cam, plane.flight_time, delta)
			level.update_guides(plane)
			Audio.set_wind(plane.state.v, true)
		Game.State.LANDED, Game.State.CRASHED:
			hud.update_flight(plane, level, cam, plane.flight_time, delta)
			if _end_timer > 0.0:
				_end_timer -= delta
				if _end_timer <= 0.0:
					_show_result()


func _unhandled_input(event: InputEvent) -> void:
	# F3: show collision shapes (testing builds only).
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F3 			and (OS.is_debug_build() or Game.UNLOCK_ALL_FOR_TESTING):
		collision_debug.toggle()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if Game.state == Game.State.RESULT:
			go_menu()
		else:
			pause_game()
		get_viewport().set_input_as_handled()
		return
	match Game.state:
		Game.State.INTRO:
			if event.is_action_pressed("throw"):
				throw_plane()
				get_viewport().set_input_as_handled()
		Game.State.FLYING:
			if event.is_action_pressed("gust"):
				plane.use_gust()
			elif event.is_action_pressed("roll_left"):
				plane.barrel_roll(-1.0)
			elif event.is_action_pressed("roll_right"):
				plane.barrel_roll(1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		match Game.state:
			Game.State.MENU:
				get_tree().quit()
			Game.State.FLYING, Game.State.THROWING:
				pause_game()
			_:
				go_menu()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and Game.state == Game.State.FLYING and Settings.is_mobile:
		pause_game()


# --- Menu showreel ------------------------------------------------------------------------

## Behind the menu, the paper plane flies the best bits of the flights: [level index, start,
## end] (points near the route; the clip runs along the route between them).
const REEL := [
	[1, Vector3(-18, -0.4, -299.3), Vector3(16, -0.2, -304)],
	[2, Vector3(3, 5.9, -345.5), Vector3(-31.5, 5.2, -359)],
	[6, Vector3(35.3, 5.45, -100.4), Vector3(33.4, 2.1, -128.5)],
	[3, Vector3(0.8, 6.1, 58.6), Vector3(-5.5, 1.3, 33)],
	[2, Vector3(-34, 2.5, -411), Vector3(17, 9.3, -427)],
	[5, Vector3(31, 8, -343), Vector3(32, 1.65, -396)],
	[0, Vector3(5, 6.5, -44), Vector3(-19, 5.5, -111)],
]
const REEL_SPEED := 9.0
const REEL_FADE := 0.35

var _reel_curves := {}
var _reel_i := -1
var _reel_off := 0.0
var _reel_end := 0.0
var _reel_fade: ColorRect
var _menu_trail: PlaneTrail


func _reel_curve(li: int) -> Curve3D:
	if _reel_curves.has(li):
		return _reel_curves[li]
	var c := Curve3D.new()
	c.bake_interval = 0.4
	var pts: PackedVector3Array = Game.levels[li].route_points()
	for p in pts:
		c.add_point(p)
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]) / 6.0
		if i == 0 or i == pts.size() - 1:
			t *= 0.5
		c.set_point_in(i, -t)
		c.set_point_out(i, t)
	_reel_curves[li] = c
	return c


func _next_reel_clip() -> void:
	_reel_i = (_reel_i + 1) % REEL.size()
	var clip: Array = REEL[_reel_i]
	var c := _reel_curve(clip[0])
	_reel_off = c.get_closest_offset(clip[1])
	_reel_end = c.get_closest_offset(clip[2])
	_update_menu_plane(0.0)
	_menu_trail.clear()
	_menu_trail.active = true
	cam.set_mode(ChaseCamera.Mode.MENU, true)


## Moves the menu plane along the current showreel clip, fading between clips.
func _update_menu_plane(delta: float) -> void:
	if _reel_fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 5
		add_child(layer)
		_reel_fade = ColorRect.new()
		_reel_fade.color = Color(0.98, 0.95, 0.88, 0.0)
		_reel_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_reel_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(_reel_fade)
	if _reel_i < 0:
		_next_reel_clip()
		return
	_reel_off += REEL_SPEED * delta
	if _reel_off >= _reel_end:
		_next_reel_clip()
		return
	var c := _reel_curve(REEL[_reel_i][0])
	var p := c.sample_baked(_reel_off, true)
	var ahead := c.sample_baked(_reel_off + 0.8, true)
	var further := c.sample_baked(_reel_off + 1.6, true)
	var dir := (ahead - p).normalized()
	var bank := clampf(-dir.cross(further - 2.0 * ahead + p).y * 6.0, -0.7, 0.7)
	menu_plane.global_position = p
	if dir.length() > 0.5:
		menu_plane.basis = Basis.looking_at(dir, Vector3.UP) * Basis(Vector3(0, 0, 1), bank)
	# Fade the paper-coloured veil in at the end of a clip and out at the start of the next.
	var left := (_reel_end - _reel_off) / REEL_SPEED
	var into := (_reel_off - c.get_closest_offset(REEL[_reel_i][1])) / REEL_SPEED
	_reel_fade.color.a = clampf(1.0 - minf(left, into) / REEL_FADE, 0.0, 1.0)
	var s := Settings.viewport_size()
	cam.menu_frame = Vector2(0.5, 0.86) if s.y > s.x else Vector2(0.84, 0.5)


func _hide_reel() -> void:
	if _reel_fade:
		_reel_fade.color.a = 0.0
	_menu_trail.active = false
	_menu_trail.clear()


# --- Cosmetics and flight tips --------------------------------------------------------------

func _apply_cosmetics() -> void:
	var c := Game.cosmetics
	Cosmetics.apply(plane.get_node_or_null("Visual/Model") as MeshInstance3D, c.paper, c.sticker)
	Cosmetics.apply(menu_plane.get_node_or_null("Model") as MeshInstance3D, c.paper, c.sticker)
	if kid.has_method("held_plane"):
		Cosmetics.apply(kid.held_plane(), c.paper, c.sticker)
	plane.set_trail_style(c.trail)


## Shows a one-time tip (until tips are reset in Settings).
func _tip(id: String, text: String, duration := 2.6) -> void:
	if not Settings.show_tips or Game.tips_seen.has(id) or Game.state != Game.State.FLYING:
		return
	Game.mark_tip_seen(id)
	hud.banner(text, Color.WHITE, duration)


func _flight_hints(delta: float) -> void:
	var t := plane.flight_time
	if t > 0.8:
		_tip("steer", "Drag left or right to steer, up to climb" if touch.visible else "A / D to steer, W / S to climb and dive")
	if t > 4.5:
		_tip("climb", "Climbing costs speed. Ease off before you get slow")
	if t > 6.0 and plane.state.vy < -1.2 and plane.gusts >= 1.0:
		_tip("gust", "Tap Gust for a quick lift" if touch.visible else "Press Space for a quick lift")
	if level.horizontal_distance_to_pad(plane.state.pos) < 30.0 and t > 2.0:
		_tip("land", "Slow down and settle gently onto the gold circle")
	# Early warning before a stall, every flight.
	_slow_cooldown -= delta
	if plane.state.v < 6.0 and not plane.stalled and _slow_cooldown <= 0.0:
		_slow_cooldown = 6.0
		hud.banner("Too slow! Ease the nose down", Color("#ffd9a1"), 1.0)
