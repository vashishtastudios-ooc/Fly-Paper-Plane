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
## Rings flown through in a row (a missed ring starts it again), and the misses already counted.
var _streak := 0
var _misses_seen := 0
## A paper-coloured cover faded in and out between screens.
var _fade_rect: ColorRect
var _fade_tween: Tween
var pilot_log: PilotLog
## Replays the best run on the current flight, and records this one.
var ghost: GhostPlane
## Free flight: the map with no rings or goal; a crash pops the plane back into the air.
var free_flight := false
var _free_map := ""
var _free_start := Vector3.ZERO
var _free_yaw := 0.0
## Where the last free-flight crash happened and why (where to pop back up).
var _free_crash := Vector3.ZERO
var _free_crash_kind := ""
var _gust_refill_default := 9.0
## PC: the frozen, HUD-less camera for taking pictures.
var photo: PhotoMode
var _photo_hud := false


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
	_gust_refill_default = plane.gust_refill_time
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 40
	add_child(fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = UIKit.PAPER
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.modulate.a = 0.0
	fade_layer.add_child(_fade_rect)
	ghost = GhostPlane.new()
	ghost.name = "Ghost"
	add_child(ghost)
	pilot_log = PilotLog.new()
	pilot_log.name = "PilotLog"
	add_child(pilot_log)
	pilot_log.closed.connect(menu.refocus)
	photo = PhotoMode.new()
	photo.name = "PhotoMode"
	add_child(photo)
	photo.closed.connect(func():
		hud.visible = _photo_hud
		pause_ui.open())
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
	elif id == "city":
		nt = CityBuilder.new()
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


## Behind the loading screen, every flight of the map is built and drawn for a few frames (a
## full turn at the launch spot and a quick glide along the route), along with the crash and
## landing effects, the ghost and the HUD (dusk flights are prepared behind their intro card). So the phone prepares every material, effect and
## lighting (dusk flights too) here instead of the first time it appears in a flight.
func _prewarm() -> void:
	cam.set_process(false)
	var first := true
	for li in Game.levels.size():
		var data: LevelData = Game.levels[li]
		# Dusk flights (lantern lights) take seconds to prepare: they do it behind their own
		# intro card instead, so the first load stays quick.
		if data.map != town.map_id or data.time_of_day == "dusk":
			continue
		level.build(data, town)
		var pts := data.route_points()
		var origin := data.platform_position + Vector3(0, 2.5, 0)
		cam.global_position = origin
		_menu_trail.active = true
		# A full turn at the launch spot, the trail right in front of the camera.
		for k in 6:
			var yaw := data.platform_yaw + TAU * k / 6.0
			cam.global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.25), origin)
			menu_plane.global_position = cam.global_position - cam.global_transform.basis.z * 3.0 + cam.global_transform.basis.x * 0.3 * k
			if first and k == 0:
				# Once: the crash and landing effects, the ghost and the HUD.
				var fx_at := cam.global_position - cam.global_transform.basis.z * 4.0
				plane.warm_effects(fx_at, true)
				ghost.global_position = fx_at + Vector3(-0.8, 0.3, 0)
				ghost.visible = true
				hud.visible = true
			await get_tree().process_frame
			if first and k == 1:
				plane.warm_effects(Vector3.ZERO, false)
				ghost.visible = false
				hud.visible = false
				first = false
		# A quick glide along the route, looking ahead.
		for f in [0.2, 0.4, 0.6, 0.8, 0.95]:
			var i := clampi(int(f * (pts.size() - 1)), 0, pts.size() - 2)
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[mini(i + 2, pts.size() - 1)]
			cam.global_position = a + Vector3(0, 0.6, 0)
			if a.distance_to(b) > 0.5:
				cam.look_at(b + Vector3(0, 0.6, 0), Vector3.UP)
			await get_tree().process_frame
	_menu_trail.active = false
	_menu_trail.clear()
	plane.warm_effects(Vector3.ZERO, false)
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
	# A tip along the bottom, changing every few seconds.
	var tip := UIKit.label(Quips.LOADING_TIPS.pick_random(), UIKit.body_font(), 19, UIKit.PENCIL)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tip.offset_top = -46
	tip.offset_bottom = -12
	tip.offset_left = 40
	tip.offset_right = -40
	_loading.add_child(tip)
	var t := Timer.new()
	t.wait_time = 3.5
	t.autostart = true
	t.timeout.connect(func(): tip.text = Quips.LOADING_TIPS.pick_random())
	tip.add_child(t)
	add_child(_loading)


func _wire() -> void:
	# The stall warning shows at most once every few seconds (no popping up over and over).
	plane.stall_entered.connect(func():
		var now := Time.get_ticks_msec()
		if now - _last_stall_banner > 4000:
			_last_stall_banner = now
			hud.banner("Whoa, stalling! Nose down", Color("#ffb3a1"), 1.2))
	# Lifetime stats for the Pilot log and achievements.
	plane.barrel_roll_done.connect(func():
		Profile.count("rolls")
		if plane.rolls_done == 3 and not _lessons:
			Profile.feat("rolls_3"))
	plane.gust_used.connect(func(): Profile.count("gusts"))
	plane.entered_thermal.connect(func(): Profile.count("thermals"))
	plane.skipped.connect(func(): Profile.count("skips"))
	level.star_collected.connect(func(_p: Vector3): Profile.count("stars"))
	level.ring_passed.connect(func(_p: Vector3): Profile.count("rings"))
	level.bonus_ring_passed.connect(func(_p: Vector3, _pts: int, _m: String): Profile.count("bonus_rings"))
	Profile.achievement_unlocked.connect(func(d: Dictionary): hud.banner("Achievement: " + str(d.title), UIKit.GOLD, 1.8))
	plane.rising_air.connect(func(): hud.banner("Rising air! Wheee", UIKit.ROUTE, 1.2))
	plane.wind_entered.connect(func():
		hud.banner("Whoosh, a draught! Lean into it" if Game.level().map == "linden" else "Sea breeze! Lean into it", Color.WHITE, 1.4))
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
	menu.free_flight_chosen.connect(start_free_flight)
	pause_ui.photo_pressed.connect(open_photo)
	settings_menu.connect("credits_pressed", func(): credits.open())
	hangar.closed.connect(func():
		menu.refresh()
		menu.refocus())
	settings_menu.closed.connect(menu.refocus)
	credits.closed.connect(menu.refocus)
	Settings.keys_changed.connect(func(): menu._layout())
	pause_ui.settings_pressed.connect(func(): settings_menu.open())
	level.star_collected.connect(func(p: Vector3):
		Audio.play("star", -2.0)
		plane.add_star_gust()
		hud.float_text(p, "+100"))
	level.ring_passed.connect(_on_ring)
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
		if free_flight:
			start_free_flight(_free_map)
		else:
			start_level(Game.current_level))
	pause_ui.flights_pressed.connect(func():
		resume_game()
		go_menu())


# --- Flow --------------------------------------------------------------------------------

## Fades the paper cover to `to` (1 = covered) over `time`; await it to wait for the cover.
func _fade(to: float, time: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(_fade_rect, "modulate:a", to, time)
	await _fade_tween.finished


## A ring flown through: a pop of light, a chime that climbs with the streak, a little kick of
## the camera, and every few rings in a row a cheer.
func _on_ring(p: Vector3) -> void:
	_streak += 1
	if _streak == 20 and not _lessons:
		Profile.feat("streak_20")
	Audio.play("ring", -3.0, 1.0 + 0.05 * mini(_streak - 1, 10))
	hud.pop(p, cam, UIKit.GOLD, _streak >= 5)
	cam.shake(0.08)
	hud.float_text(p, "+25", UIKit.GOLD)
	if _streak >= 3:
		hud.float_text(p + Vector3(0, -0.8, 0), "×%d" % _streak, Color.WHITE, 30)
	if _streak in [5, 10, 15, 20]:
		hud.banner("%d in a row!" % _streak, UIKit.GOLD, 1.0)


func go_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	_fade_rect.modulate.a = 1.0
	_fade(0.0, 0.35)
	_end_lessons()
	_end_free_flight()
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
	Audio.play_music("day")


func start_level(index: int) -> void:
	if not Game.is_unlocked(index):
		return
	get_tree().paused = false
	Engine.time_scale = 1.0
	await _fade(1.0, 0.15)
	_streak = 0
	_misses_seen = 0
	_end_timer = -1.0
	_end_free_flight()
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
	Audio.play_music("night" if data.time_of_day == "dusk" else ("city" if data.map == "city" else "day"))
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
	_fade(0.0, 0.35)


## Free flight over map `map_id`: no rings, stars, timer or landing spot, all of the map's rising
## air and breezes, gusts that refill quickly, and the plane starting high over the best viewpoint.
func start_free_flight(map_id: String) -> void:
	var lv: Array = []
	for m in Game.MAPS:
		if m.id == map_id:
			lv = m.levels
	if lv.is_empty():
		return
	get_tree().paused = false
	Engine.time_scale = 1.0
	await _fade(1.0, 0.15)
	_end_lessons()
	_end_timer = -1.0
	_streak = 0
	_misses_seen = 0
	Game.current_level = lv[0]
	await switch_map(map_id)
	var data := _free_flight_data(lv)
	free_flight = true
	_free_map = map_id
	ghost.set_run(PackedFloat32Array())
	ghost.visible = false
	level.build(data, town)
	# Just the air: no rings, stars, dotted line or landing spot.
	for g in level.gates:
		g.queue_free()
	level.gates.clear()
	for st in level.stars:
		st.queue_free()
	level.stars.clear()
	if level.pad:
		level.pad.queue_free()
		level.pad = null
	if level._dots:
		level._dots.visible = false
	level.hide_guides()
	# Every tree stands (none cleared for a route).
	var trees := data.duplicate() as LevelData
	trees.route = null
	town.clear_trees_for_level(trees)
	Audio.play_music("city" if map_id == "city" else "day")
	hud.reset()
	hud.free_mode = true
	plane.reset()
	plane.gust_refill_time = 2.0
	menu_plane.visible = false
	_hide_reel()
	kid.visible = false
	menu.close()
	intro.close()
	result.close()
	pause_ui.close()
	_launch_free(_free_start, _free_yaw)
	if collision_debug and collision_debug.visible:
		collision_debug.rebuild.call_deferred()
	_fade(0.0, 0.35)
	hud.banner("Free flight! Go anywhere", UIKit.GOLD, 1.8)


## The map's flights merged for free flight: all their rising air, breezes and lines, the
## start above the highest launch spot, and the landing spot moved far out of reach.
func _free_flight_data(lv: Array) -> LevelData:
	var base: LevelData = Game.levels[lv[0]]
	for i in lv:
		if Game.levels[i].time_of_day != "dusk":
			base = Game.levels[i]
			break
	var d := base.duplicate() as LevelData
	d.decor = ""
	d.bonus_stars = PackedVector3Array()
	d.has_bonus_ring = false
	d.pad_position = Vector3(0, -1000, 0)
	d.pad_radius = 0.1
	var th := []
	var wz := []
	var hz := []
	var high: LevelData = base
	for i in lv:
		var l: LevelData = Game.levels[i]
		if l.platform_position.y > high.platform_position.y:
			high = l
		for t in l.thermals:
			if not _near_any(th, t):
				th.append(t)
		for w in l.wind_zones:
			if not _near_any(wz, w):
				wz.append(w)
		for h in l.hazard_lines:
			var dup := false
			for o in hz:
				if (o.a as Vector3).distance_to(h.a) < 1.0 and (o.b as Vector3).distance_to(h.b) < 1.0:
					dup = true
			if not dup:
				hz.append(h)
	d.thermals = th
	d.wind_zones = wz
	d.hazard_lines = hz
	_free_yaw = high.start_yaw()
	var fwd := Vector3(-sin(_free_yaw), 0.0, -cos(_free_yaw))
	_free_start = high.platform_position + fwd * 5.0 + Vector3(0, 7.0, 0)
	return d


static func _near_any(list: Array, item: Dictionary) -> bool:
	for o in list:
		if Vector2(float(o.x) - float(item.x), float(o.z) - float(item.z)).length() < 4.0:
			return true
	return false


func _launch_free(pos: Vector3, yaw: float) -> void:
	plane.launch(pos, yaw)
	plane.state.v = 10.0
	plane.state.pitch = -0.05
	Game.set_state(Game.State.FLYING)
	cam.set_mode(ChaseCamera.Mode.FOLLOW, true)
	hud.visible = true
	if Settings.touch_ui:
		touch.open()


## After a free-flight crash: back in the air well above the spot (over any roof just ahead), or
## at the start after flying out of the map.
func _respawn_free() -> void:
	if _free_crash_kind == "out":
		_launch_free(_free_start, _free_yaw)
		return
	var yaw := plane.state.yaw
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var side := Vector3(fwd.z, 0.0, -fwd.x)
	var space := plane.get_world_3d().direct_space_state
	var top := -INF
	for a in [0.0, 5.0, 10.0, 15.0]:
		for b in [-3.0, 0.0, 3.0]:
			var p: Vector3 = _free_crash + fwd * a + side * b
			var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 400.0, p.z), Vector3(p.x, -50.0, p.z), 1 | 2)
			var hit := space.intersect_ray(q)
			top = maxf(top, Terrain.ground_height(p.x, p.z))
			if not hit.is_empty():
				top = maxf(top, hit.position.y)
	_launch_free(Vector3(_free_crash.x, top + 16.0, _free_crash.z), yaw)


func _end_free_flight() -> void:
	if not free_flight:
		return
	Profile.check_achievements()
	free_flight = false
	hud.free_mode = false
	plane.gust_refill_time = _gust_refill_default


## PC: freezes the flight and opens photo mode around the plane.
func open_photo() -> void:
	if Settings.is_mobile or Game.state != Game.State.FLYING or photo.visible:
		return
	get_tree().paused = true
	pause_ui.close()
	_photo_hud = hud.visible
	hud.visible = false
	photo.open(cam, plane.get_global_transform_interpolated().origin)


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
		# Where on the target it landed (for the result card's little target drawing).
		"offset": Vector2(info.position.x - data.pad_position.x, info.position.z - data.pad_position.z),
	}
	var score := Game.compute_landing_score(stats)
	var ribbons_before := Game.total_ribbons()
	var id := Game.level_id(Game.current_level)
	var star_ids := []
	for k in level.stars.size():
		if level.stars[k].collected:
			star_ids.append(k)
	_landing_feats(id, score)
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
	var zone_col: Color = {"bullseye": UIKit.GOLD, "inner": Color("#8fe3b0"), "outer": Color("#bfe3ff"), "edge": Color("#ffd9a1")}[score.zone]
	hud.banner_now(score.headline, zone_col, 1.8)
	hud.float_text(info.position, "+%d" % (score.accuracy + score.bullseye_bonus), zone_col)
	if level.pad:
		level.pad.mark(info.position)
	hud.pop(info.position, cam, zone_col, score.zone == "bullseye")
	if score.zone == "bullseye":
		# Confetti, a fanfare and a short slow-motion moment.
		hud.confetti()
		Audio.play("bonus", 0.0)
		Engine.time_scale = 0.35
		get_tree().create_timer(0.8, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
	level.hide_guides()
	touch.close()
	Audio.set_wind(0.0, false)
	_end_timer = 2.2


## The fun achievements decided at the moment of landing (before the landing is recorded, so the
## flight's attempts and old ghost are still this flight's history).
func _landing_feats(id: String, score: Dictionary) -> void:
	var bull: bool = score.zone == "bullseye"
	if bull and int(Profile.flight(id).attempts) == 1:
		Profile.feat("hole_in_one")
	if bull and id == "level_10":
		Profile.feat("basket")
	if plane.gusts < 1.0:
		Profile.feat("fumes")
	if Profile.has_ghost(id):
		var old := Profile.load_ghost(id)
		if old.size() >= 7 and plane.flight_time < old[old.size() - 7] - 0.05:
			Profile.feat("ghostbuster")


func _on_crashed(message: String, _kind: String) -> void:
	Game.set_state(Game.State.CRASHED)
	if free_flight:
		# No score card: a moment to see it, then straight back up.
		hud.banner(message, Color("#ffd9a1"), 1.0)
		if _kind != "stopped" and _kind != "soaked":
			cam.shake(0.5)
			Settings.vibrate(80)
		cam.orbit_center = plane.state.pos
		cam.set_mode(ChaseCamera.Mode.ORBIT)
		touch.close()
		Audio.set_wind(0.0, false)
		_free_crash = plane.state.pos
		_free_crash_kind = _kind
		Profile.check_achievements()
		_respawn_timer = 1.2
		return
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
	if plane.flight_time < 1.0:
		Profile.feat("paper_cut")
	Profile.record_crash(Game.level_id(Game.current_level), _kind)
	_pending_achievements = Profile.check_achievements()
	Profile.save()
	var to_pad := level.horizontal_distance_to_pad(plane.state.pos)
	_pending = {"kind": "crash", "message": message, "crash_kind": _kind, "stars": level.stars_collected,
		"stars_total": level.stars_total(), "time": plane.flight_time,
		# How far along the route it got, and how far from the landing spot it came down.
		"progress": clampf(level.curve.get_closest_offset(plane.state.pos) / maxf(level.route_length, 1.0), 0.0, 1.0),
		"to_pad": to_pad, "near": to_pad < level.pad_radius() + 8.0}
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
		result.show_crash(_pending.message, _pending.stars, _pending.stars_total, _pending.time, _pending.crash_kind, _pending)
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
		elif _respawn_timer <= 0.0 and free_flight:
			_respawn_free()
	match Game.state:
		Game.State.MENU:
			_update_menu_plane(delta)
			_auto_quality(delta)
		Game.State.FLYING:
			var x := _steer_x()
			var y := Input.get_axis("dive", "climb")
			if touch.visible:
				y += -touch.stick.y
				touch.gust_charge = plane.gusts
			x *= Settings.sensitivity
			y *= Settings.sensitivity * (-1.0 if Settings.invert_pitch else 1.0)
			plane.set_controls(clampf(x, -1.0, 1.0), clampf(y, -1.0, 1.0))
			# A ring skipped (flown past) ends the streak.
			var misses: int = level.next_gate - level.rings_passed
			if misses > _misses_seen:
				_misses_seen = misses
				_streak = 0
			# Sharp turn: E (or Q) held while already turning right (or left), or the touch Roll
			# button held while steering.
			var sharp := 0.0
			if x > 0.2 and (Input.is_action_pressed("roll_right") or touch.sharp_held):
				sharp = 1.0
			elif x < -0.2 and (Input.is_action_pressed("roll_left") or touch.sharp_held):
				sharp = -1.0
			plane.sharp_dir = sharp
			Profile.add_air("" if Game.in_lessons() or free_flight else Game.level_id(Game.current_level), delta, plane.state.v * delta)
			if free_flight:
				var before := float(Profile.data.feats.get("free_time", 0.0))
				Profile.feat("free_time", delta)
				if before < 300.0 and before + delta >= 300.0:
					Profile.check_achievements()
			if not free_flight:
				ghost.record(plane.flight_time, plane, (plane.get_node("Visual") as Node3D).rotation.z)
				ghost.play(plane.flight_time)
				_flight_hints(delta)
			hud.update_flight(plane, level, cam, plane.flight_time, delta)
			if not free_flight:
				level.update_guides(plane)
			Audio.set_wind(plane.state.v, true)
		Game.State.LANDED, Game.State.CRASHED:
			hud.update_flight(plane, level, cam, plane.flight_time, delta)
			if _end_timer > 0.0:
				_end_timer -= delta
				if _end_timer <= 0.0:
					_show_result()


func _unhandled_input(event: InputEvent) -> void:
	# F3: show collision shapes (only when run from the Godot editor).
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F3 			and OS.has_feature("editor"):
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
			if event.is_action_pressed("photo"):
				open_photo()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("gust"):
				plane.use_gust()
			# Q / E always roll; held while turning that way they also sharpen the turn.
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


## Steering input (keys, stick and touch), before sensitivity.
func _steer_x() -> float:
	var x := Input.get_axis("turn_left", "turn_right")
	if touch.visible:
		x += touch.stick.x
	return x


func _flight_hints(delta: float) -> void:
	if Game.in_lessons():
		return
	var t := plane.flight_time
	if t > 3.0 and absf(plane.in_x) > 0.7:
		_tip("sharp", "Hold Roll while steering for a sharper turn" if touch.visible else "Turning? Hold %s (right) or %s (left) too for a sharper turn" % [Settings.key_label("roll_right"), Settings.key_label("roll_left")])
	if t > 0.8:
		_tip("steer", "Drag left or right to steer, up to climb" if touch.visible else "%s / %s to steer, %s / %s to climb and dive" % [Settings.key_label("turn_left"), Settings.key_label("turn_right"), Settings.key_label("climb"), Settings.key_label("dive")])
	if t > 4.5:
		_tip("climb", "Climbing costs speed. Ease off before you get slow")
	if t > 6.0 and plane.state.vy < -1.2 and plane.gusts >= 1.0:
		_tip("gust", "Tap Gust for a quick lift" if touch.visible else "Press %s for a quick lift" % Settings.key_label("gust"))
	if level.horizontal_distance_to_pad(plane.state.pos) < 30.0 and t > 2.0:
		_tip("land", "Slow down and settle gently onto the green circle")
	# Early warning before a stall, every flight.
	_slow_cooldown -= delta
	# (Not while touching down or sliding to a stop on the target: slowing down is the point there.)
	var near_pad := level.horizontal_distance_to_pad(plane.state.pos) < level.pad_radius() + 5.0 and plane.state.pos.y < level.pad_top() + 3.0
	if plane.state.v < 6.0 and not plane.stalled and _slow_cooldown <= 0.0 and plane.mode == PaperPlane.Mode.FLYING and not near_pad:
		_slow_cooldown = 6.0
		hud.banner("Running out of puff! Nose down", Color("#ffd9a1"), 1.0)
