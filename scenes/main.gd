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
var _loader: FoldingLoader
## The town being built behind the loading screen (its build_progress drives the folding).
var _building: TownBuilder
var _end_timer := -1.0
var _pending := {}
## Achievements earned on the flight that just ended (shown on the result card).
var _pending_achievements := []
var _last_flight_time := 0.0
var _slow_cooldown := 0.0
var _last_stall_banner := -100000
var _lessons: FlyingLessons
var _respawn_timer := -1.0
var collision_debug: CollisionDebug
var pilot_log: PilotLog
## Replays the best run on the current flight, and records this one.
var ghost: GhostPlane


func _ready() -> void:
	_show_loading()
	_wire()
	cam.plane = plane
	cam.menu_target = menu_plane
	# The showreel plane is moved every frame (not by physics), so it must not be interpolated
	# between physics steps: that made it stutter at phone frame rates.
	menu_plane.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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
	ghost = GhostPlane.new()
	ghost.name = "Ghost"
	add_child(ghost)
	pilot_log = PilotLog.new()
	pilot_log.name = "PilotLog"
	add_child(pilot_log)
	kid.visible = false
	hud.visible = false
	# Let the loading card render before the heavy town build.
	await get_tree().process_frame
	await get_tree().process_frame
	town.yield_while_building = true
	_building = town
	await town.build()
	collision_debug = CollisionDebug.new()
	collision_debug.name = "CollisionDebug"
	collision_debug.plane = plane
	add_child(collision_debug)
	_apply_cosmetics()
	await _prewarm()
	await _finish_loading()
	go_menu()


## Builds the world for map `id` (behind the loading card) unless it is the one loaded.
func switch_map(id: String) -> void:
	if town.map_id == id:
		return
	_show_loading()
	await get_tree().process_frame
	await get_tree().process_frame
	var old := town
	remove_child(old)
	old.queue_free()
	Terrain.map = id
	var nt: TownBuilder
	if id == "harbour":
		nt = HarbourBuilder.new()
	else:
		nt = load("res://scenes/town/town.tscn").instantiate()
	nt.name = "Town"
	nt.build_on_ready = false
	add_child(nt)
	move_child(nt, 0)
	town = nt
	town.yield_while_building = true
	_building = town
	await town.build()
	_reel_curves.clear()
	_reel_i = -1
	await _prewarm()
	await _finish_loading()


## Flights whose effects are drawn once behind the loading screen, per map (so the first time a
## ring, star, rising air, breeze or fireworks appears in a flight doesn't make the game hitch while
## the phone prepares it).
const PREWARM := {"linden": [0], "harbour": [11, 14]}


func _prewarm() -> void:
	var ids: Array = PREWARM.get(town.map_id, [])
	cam.set_process(false)
	for li in ids:
		if li >= Game.levels.size():
			continue
		var data: LevelData = Game.levels[li]
		level.build(data, town)
		var pts := data.route_points()
		cam.global_position = data.platform_position + Vector3(0, 2.5, 0)
		var look: Vector3 = pts[mini(3, pts.size() - 1)]
		if cam.global_position.distance_to(look) > 0.5:
			cam.look_at(look, Vector3.UP)
		# The trail too, right in front of the camera.
		_menu_trail.active = true
		menu_plane.global_position = cam.global_position - cam.global_transform.basis.z * 3.0
		for i in 4:
			menu_plane.global_position += cam.global_transform.basis.x * 0.3
			await get_tree().process_frame
	_menu_trail.active = false
	_menu_trail.clear()
	level.clear_content()
	level.hide_guides()
	town.set_time_of_day("golden")
	cam.set_process(true)


## Lets the last fold and the fly-off finish, then removes the loading screen.
func _finish_loading() -> void:
	if _loader and not _loader._done:
		await _loader.finished
	_loading.queue_free()


func _show_loading() -> void:
	_loading = CanvasLayer.new()
	_loading.layer = 50
	var bg := ColorRect.new()
	bg.color = UIKit.PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(bg)
	# A sheet of paper folding itself into a plane while the world is built.
	_loader = FoldingLoader.new()
	_building = null
	_loader.progress_source = func() -> float: return _building.build_progress if is_instance_valid(_building) else 0.0
	_loading.add_child(_loader)
	add_child(_loading)


func _wire() -> void:
	# The stall warning shows at most once every few seconds (no popping up over and over).
	plane.stall_entered.connect(func():
		var now := Time.get_ticks_msec()
		if now - _last_stall_banner > 4000:
			_last_stall_banner = now
			hud.banner("Whoa, stalling! Nose down", Color("#ffb3a1"), 1.2))
	# Lifetime stats for the Pilot log and achievements.
	plane.barrel_roll_done.connect(func(): Profile.count("rolls"))
	plane.gust_used.connect(func(): Profile.count("gusts"))
	plane.entered_thermal.connect(func(): Profile.count("thermals"))
	plane.skipped.connect(func(): Profile.count("skips"))
	level.star_collected.connect(func(_p: Vector3): Profile.count("stars"))
	level.ring_passed.connect(func(_p: Vector3): Profile.count("rings"))
	level.bonus_ring_passed.connect(func(_p: Vector3, _pts: int, _m: String): Profile.count("bonus_rings"))
	Profile.achievement_unlocked.connect(func(d: Dictionary): hud.banner("Achievement: " + str(d.title), UIKit.GOLD, 1.8))
	plane.rising_air.connect(func(): hud.banner("Rising air! Wheee", UIKit.ROUTE, 1.2))
	plane.wind_entered.connect(func(): hud.banner("Sea breeze! Lean into it", Color.WHITE, 1.4))
	plane.barrel_roll_done.connect(func(): hud.float_text(plane.state.pos, "+50"))
	plane.landed.connect(_on_landed)
	plane.skipped.connect(func(): hud.banner("Skip! Like a pebble", Color("#bfe3ff"), 0.9))
	plane.crashed.connect(_on_crashed)
	plane.gust_used.connect(func(): Settings.vibrate(20))
	plane.entered_thermal.connect(func(): _tip("thermal", "Rising air! Circle inside it to climb"))
	Game.cosmetics_changed.connect(_apply_cosmetics)
	menu.hangar_pressed.connect(func(): hangar.open())
	menu.settings_pressed.connect(func(): settings_menu.open())
	menu.pilot_pressed.connect(func(): pilot_log.open())
	settings_menu.connect("credits_pressed", func(): credits.open())
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
	# The very first flight is the flying lessons.
	menu.level_chosen.connect(func(i: int): start_level(Game.LESSONS if not Game.lessons_done else i))
	settings_menu.connect("lessons_pressed", func():
		pause_ui.close()
		get_tree().paused = false
		start_level(Game.LESSONS))
	intro.throw_pressed.connect(throw_plane)
	intro.flights_pressed.connect(go_menu)
	result.next_pressed.connect(func(): start_level(Game.next_level() if Game.has_next_level() else Game.current_level))
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
	_end_lessons()
	_end_timer = -1.0
	Game.set_state(Game.State.MENU)
	intro.close()
	result.close()
	pause_ui.close()
	hud.visible = false
	touch.close()
	plane.reset()
	ghost.visible = false
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
	await switch_map(data.map)
	_end_lessons()
	if Game.in_lessons():
		_lessons = FlyingLessons.new()
		_lessons.plane = plane
		_lessons.skip_pressed.connect(func():
			Game.finish_lessons()
			start_level(0))
		_lessons.finished.connect(Game.finish_lessons)
		_lessons.retry_needed.connect(func():
			hud.banner("Let's try that again!", Color("#ffd9a1"), 1.2)
			_respawn_in_lesson())
		add_child(_lessons)
		_lessons.visible = false
	ghost.set_run(PackedFloat32Array())
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
	ghost.start_recording()
	ghost.set_run(PackedFloat32Array())
	if not Game.in_lessons():
		Profile.begin_flight(Game.level_id(Game.current_level))
		if Settings.show_ghost:
			ghost.set_run(Profile.load_ghost(Game.level_id(Game.current_level)))
	Audio.play("throw", -2.0)
	Game.set_state(Game.State.FLYING)
	cam.set_mode(ChaseCamera.Mode.FOLLOW)
	hud.visible = true
	if Settings.touch_ui:
		touch.open()
	if _lessons:
		_lessons.visible = true


func _end_lessons() -> void:
	_respawn_timer = -1.0
	if _lessons:
		_lessons.queue_free()
		_lessons = null


## Lessons: put the plane straight back in the air at the start of the current lesson.
func _respawn_in_lesson() -> void:
	var cp := _lessons.checkpoint()
	plane.launch(cp[0], cp[1])
	plane.state.v = 9.5
	plane.state.pitch = -0.05
	Game.set_state(Game.State.FLYING)
	cam.set_mode(ChaseCamera.Mode.FOLLOW, true)
	hud.visible = true
	if Settings.touch_ui:
		touch.open()


func _on_landed(info: Dictionary) -> void:
	Game.set_state(Game.State.LANDED)
	if _lessons:
		# Lessons done: no score, just a well done and on to Flight 1.
		_lessons.on_landed()
		cam.orbit_center = info.position
		cam.set_mode(ChaseCamera.Mode.ORBIT)
		hud.banner("Well done!", UIKit.LIFT, 2.0)
		level.hide_guides()
		touch.close()
		Settings.vibrate(60)
		_pending = {"kind": "lessons"}
		_end_timer = 3.6
		return
	# The pet sitting by the landing spot is delighted.
	for pet in get_tree().get_nodes_in_group("pets"):
		if level.horizontal_distance_to_pad((pet as Node3D).global_position) < pet.watch_radius:
			pet.react()
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
	var id := Game.level_id(Game.current_level)
	var star_ids := []
	for k in level.stars.size():
		if level.stars[k].collected:
			star_ids.append(k)
	Profile.record_landing(id, stats, score, star_ids)
	var is_best := Game.record_landing(Game.current_level, score.total, score.ribbons)
	# The ghost is the best run; flights without one yet (e.g. records from older versions) keep
	# this one.
	if is_best or not Profile.has_ghost(id):
		Profile.save_ghost(id, ghost.recording())
	ghost.visible = false
	_pending_achievements = Profile.check_achievements()
	Profile.save()
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
	if _lessons:
		# Lessons are forgiving: a moment to see what happened, then back in the air.
		hud.banner(message + "  Let's try that again!", Color("#ffd9a1"), 1.2)
		cam.orbit_center = plane.state.pos
		cam.set_mode(ChaseCamera.Mode.ORBIT)
		level.hide_guides()
		touch.close()
		_respawn_timer = 1.3
		return
	ghost.visible = false
	Profile.record_crash(Game.level_id(Game.current_level), _kind)
	_pending_achievements = Profile.check_achievements()
	Profile.save()
	_pending = {"kind": "crash", "message": message, "crash_kind": _kind, "stars": level.stars_collected,
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
	if _pending.get("kind", "") == "lessons":
		# Straight on to Flight 1 after the lessons.
		start_level(0)
		return
	Game.set_state(Game.State.RESULT)
	hud.visible = false
	if _pending.kind == "land":
		result.show_landing(_pending.score, _pending.stats, _pending.best, Game.has_next_level(), _pending.unlocks)
	else:
		result.show_crash(_pending.message, _pending.stars, _pending.stars_total, _pending.time, _pending.crash_kind)
	result.show_achievements(_pending_achievements)
	_pending_achievements = []


func pause_game() -> void:
	if Game.state in [Game.State.FLYING, Game.State.THROWING, Game.State.INTRO]:
		get_tree().paused = true
		pause_ui.open()


func resume_game() -> void:
	pause_ui.close()
	get_tree().paused = false


# --- Per frame ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _respawn_timer > 0.0 and not get_tree().paused:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0 and _lessons:
			_respawn_in_lesson()
	match Game.state:
		Game.State.MENU:
			_update_menu_plane(delta)
			_auto_quality(delta)
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
			Profile.add_air("" if Game.in_lessons() else Game.level_id(Game.current_level), delta, plane.state.v * delta)
			ghost.record(plane.flight_time, plane, (plane.get_node("Visual") as Node3D).rotation.z)
			ghost.play(plane.flight_time)
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

## Behind the menu, the paper plane flies the best bits of the flights (ending with the dive off
## Skyline Apartments): [level index, start,
## end] (points near the route; the clip runs along the route between them).
const REEL := [
	[1, Vector3(-18, -0.4, -299.3), Vector3(16, -0.2, -304)],
	[2, Vector3(3, 5.9, -345.5), Vector3(-31.5, 5.2, -359)],
	[6, Vector3(35.3, 5.45, -100.4), Vector3(33.4, 2.1, -128.5)],
	[3, Vector3(0.8, 6.1, 58.6), Vector3(-5.5, 1.3, 33)],
	[2, Vector3(-34, 2.5, -411), Vector3(17, 9.3, -427)],
	[5, Vector3(31, 8, -343), Vector3(32, 1.65, -396)],
	[0, Vector3(5, 6.5, -44), Vector3(-19, 5.5, -111)],
	[7, Vector3(-28, 32.4, 84.6), Vector3(-12, 8.1, 14)],
]
const REEL_SPEED := 9.0
const REEL_FADE := 0.35

var _reel_curves := {}
var _reel_i := -1
var _reel_off := 0.0
var _reel_end := 0.0
var _reel_fade: ColorRect
var _menu_trail: PlaneTrail


## The showreel clips for the loaded map: the town's own, or the Linden Lane REEL.
func _reel_clips() -> Array:
	var own := town.showreel()
	return own if not own.is_empty() else REEL


## A clip's path: a flight's route (by level index) or the points given in the clip.
func _reel_curve(key: Variant) -> Curve3D:
	var id: Variant = key if key is int else hash(key)
	if _reel_curves.has(id):
		return _reel_curves[id]
	var c := Curve3D.new()
	c.bake_interval = 0.4
	var pts: PackedVector3Array = Game.levels[key].route_points() if key is int else key
	for p in pts:
		c.add_point(p)
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]) / 6.0
		if i == 0 or i == pts.size() - 1:
			t *= 0.5
		c.set_point_in(i, -t)
		c.set_point_out(i, t)
	_reel_curves[id] = c
	return c


## Start offset of the current clip along its path.
func _clip_offset(c: Curve3D, at: Variant) -> float:
	return c.get_closest_offset(at) if at is Vector3 else c.get_baked_length() * float(at)


func _next_reel_clip() -> void:
	var clips := _reel_clips()
	_reel_i = (_reel_i + 1) % clips.size()
	var clip: Array = clips[_reel_i]
	var c := _reel_curve(clip[0])
	_reel_off = _clip_offset(c, clip[1])
	_reel_end = _clip_offset(c, clip[2])
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
	var clip: Array = _reel_clips()[_reel_i]
	var c := _reel_curve(clip[0])
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
	var into := (_reel_off - _clip_offset(c, clip[1])) / REEL_SPEED
	_reel_fade.color.a = clampf(1.0 - minf(left, into) / REEL_FADE, 0.0, 1.0)
	cam.menu_frame = menu.reel_frame()


func _hide_reel() -> void:
	if _reel_fade:
		_reel_fade.color.a = 0.0
	_menu_trail.active = false
	_menu_trail.clear()


# --- Cosmetics and flight tips --------------------------------------------------------------

func _apply_cosmetics() -> void:
	var c := Game.cosmetics
	Cosmetics.apply(plane.get_node_or_null("Visual/Model") as MeshInstance3D, c.paper, c.sticker, c.shape)
	Cosmetics.apply(menu_plane.get_node_or_null("Model") as MeshInstance3D, c.paper, c.sticker, c.shape)
	if kid.has_method("held_plane"):
		Cosmetics.apply(kid.held_plane(), c.paper, c.sticker, c.shape)
	ghost.set_shape(c.shape)
	plane.set_trail_style(c.trail)


## Shows a one-time tip (until tips are reset in Settings).
func _tip(id: String, text: String, duration := 2.6) -> void:
	if not Settings.show_tips or Game.tips_seen.has(id) or Game.state != Game.State.FLYING:
		return
	Game.mark_tip_seen(id)
	hud.banner(text, Color.WHITE, duration)


var _aq_time := 0.0
var _aq_frames := 0


## Phones: measure the frame rate on the menu once (seconds 1.5 to 5.5); if the phone can't keep
## about 50 fps, switch to Low quality (unless the player picked a quality themselves).
func _auto_quality(delta: float) -> void:
	if not Settings.is_mobile or Settings.quality_auto_done or Settings.quality_chosen or Settings.quality == 0:
		return
	_aq_time += delta
	if _aq_time < 1.5:
		return
	_aq_frames += 1
	if _aq_time >= 5.5:
		var fps := _aq_frames / (_aq_time - 1.5)
		Settings.quality_auto_done = true
		if fps < 50.0:
			Settings.set_quality(0)
		else:
			Settings.set_quality(Settings.quality)


func _flight_hints(delta: float) -> void:
	if Game.in_lessons():
		return
	var t := plane.flight_time
	if t > 0.8:
		_tip("steer", "Drag left or right to steer, up to climb" if touch.visible else "A / D to steer, W / S to climb and dive")
	if t > 4.5:
		_tip("climb", "Climbing costs speed. Ease off before you get slow")
	if t > 6.0 and plane.state.vy < -1.2 and plane.gusts >= 1.0:
		_tip("gust", "Tap Gust for a quick lift" if touch.visible else "Press Space for a quick lift")
	if level.horizontal_distance_to_pad(plane.state.pos) < 30.0 and t > 2.0:
		_tip("land", "Slow down and settle gently onto the green circle")
	# Early warning before a stall, every flight.
	_slow_cooldown -= delta
	if plane.state.v < 6.0 and not plane.stalled and _slow_cooldown <= 0.0:
		_slow_cooldown = 6.0
		hud.banner("Running out of puff! Nose down", Color("#ffd9a1"), 1.0)
