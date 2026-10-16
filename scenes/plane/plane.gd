class_name PaperPlane
extends Node3D
## The paper plane: custom glide kinematics at 60 Hz (no RigidBody), collision and landing
## detection, gusts, barrel rolls, wingtip trails and crash/landing effects.
## All flight constants are exported so they can be tuned in the inspector.

signal launched
signal stall_entered
signal rising_air
signal entered_thermal
signal gust_used
signal barrel_roll_done
signal landed(info: Dictionary)
signal crashed(message: String, kind: String)
signal skipped

enum Mode { IDLE, FLYING, SLIDING, SKIMMING, LANDED, CRASHED }

@export_group("Pitch and roll")
@export var stall_speed := 4.6
@export var stall_pitch := -0.45
@export var trim_pitch := -0.07
@export var pitch_input_gain := 0.55
@export var pitch_min := -0.75
@export var pitch_max := 0.5
@export var pitch_rate := 2.6
@export var pitch_rate_stall := 3.0
@export var roll_gain := 0.95
@export var roll_rate := 3.2
@export var turn_rate := 1.2
@export var input_damp := 10.0

@export_group("Speed and sink")
@export var gravity := 9.8
@export var drag := 0.0075
@export var min_speed := 2.5
@export var max_speed := 21.0
@export var base_sink := 0.25
@export var slow_sink_speed := 6.0
@export var slow_sink_gain := 0.45
@export var ground_effect_height := 1.8
@export var flap_damp := 2.2

@export_group("Gusts, tricks, launch")
@export var gust_flap := 3.4
@export var gust_speed := 1.8
@export var gust_max := 3.0
@export var gust_refill_time := 9.0
@export var star_gust := 0.5
@export var barrel_roll_time := 0.6
@export var launch_speed := 10.5
@export var launch_pitch := 0.05
@export var rising_air_threshold := 1.2

@export_group("Collision")
@export var collision_radius := 0.2
@export var short_landing_distance := 12.0

@export_group("Sliding")
## A belly touch on a flat surface becomes a slide instead of a crash when the plane meets it
## at less than this angle (degrees) and isn't diving nose-first.
@export var slide_max_angle := 25.0
## Surfaces flatter than this (normal.y) can be slid on: ground, floors, balconies, flat roofs.
@export var slide_min_flatness := 0.85
## How quickly a slide on a floor slows down (about speed / friction metres of slide).
@export var slide_friction := 2.0
## How quickly the plane settles once it is on the target.
@export var pad_friction := 3.2

@export_group("Water")
## A belly touch on the water faster than this and flatter than skip_max_angle skips like a stone.
@export var skip_min_speed := 8.0
@export var skip_max_angle := 15.0
## Speed kept after a skip, and the little upward pop it gives.
@export var skip_speed_keep := 0.7
@export var skip_pop := 1.6
## Water is grabby: a skim stops after roughly speed / friction metres (about 1-1.5 m).
@export var skim_friction := 5.0


## Minimal flight state, also used for the touchdown predictor.
class FlightState:
	var pos := Vector3.ZERO
	var yaw := 0.0
	var pitch := 0.0
	var roll := 0.0
	var v := 0.0
	var vy := 0.0
	var flap_v := 0.0

	func copy() -> FlightState:
		var s := FlightState.new()
		s.pos = pos
		s.yaw = yaw
		s.pitch = pitch
		s.roll = roll
		s.v = v
		s.vy = vy
		s.flap_v = flap_v
		return s


var mode := Mode.IDLE
var state := FlightState.new()
var level: Node  # LevelRuntime: lift_at(), pad info, hazards
var gusts := 3.0
var in_x := 0.0
var in_y := 0.0
var _raw_x := 0.0
var _raw_y := 0.0
var stalled := false
var lift := 0.0
var agl := 0.0
var rolls_done := 0
var flight_time := 0.0
var autopilot: Callable  # Optional: returns Vector2(in_x, in_y) (used by tests).

var _rising_cooldown := 0.0
var _thermal_cooldown := 0.0
var _was_inside := false
var _was_rising := false
var _roll_t := -1.0
var _roll_dir := 1.0
var _skid_t := 0.0
## First-touch values for a landing (a slide-in keeps the softness of its first touch).
var _touch_impact := 0.0
var _touch_speed := 0.0
var _land_info := {}
var _landed_sent := false
## A skip is available again once the plane has climbed ~1 m clear of the water.
var _skip_armed := true
var _skim_y := 0.0
var _spray: GPUParticles3D
var _visual: Node3D
var _query := PhysicsShapeQueryParameters3D.new()
var trail_style := "white"
var _trail: PlaneTrail
var _sparkles: GPUParticles3D
var _scraps: GPUParticles3D
var _shock: MeshInstance3D
var _bonk: MeshInstance3D


func _ready() -> void:
	_visual = get_node_or_null("Visual")
	if _visual == null:
		_visual = Node3D.new()
		_visual.name = "Visual"
		add_child(_visual)
	if not _visual.has_node("Model"):
		var mi := MeshInstance3D.new()
		mi.name = "Model"
		mi.mesh = PaperPlaneMesh.get_mesh()
		_visual.add_child(mi)
	var sphere := SphereShape3D.new()
	sphere.radius = collision_radius
	_query.shape = sphere
	_query.collision_mask = 1 | 2
	_query.collide_with_areas = false
	_build_trails()
	_build_effects()
	visible = false


# --- Public API ---------------------------------------------------------------------------

func launch(pos: Vector3, yaw: float) -> void:
	state = FlightState.new()
	state.pos = pos
	state.yaw = yaw
	state.pitch = launch_pitch
	state.roll = 0.0
	state.v = launch_speed
	state.vy = 0.0
	state.flap_v = 0.0
	gusts = gust_max
	in_x = 0.0
	in_y = 0.0
	stalled = false
	rolls_done = 0
	flight_time = 0.0
	_roll_t = -1.0
	_was_rising = false
	_rising_cooldown = 0.0
	_was_inside = false
	_thermal_cooldown = 0.0
	_visual.scale = Vector3.ONE
	_visual.rotation = Vector3.ZERO
	_trail.clear()
	mode = Mode.FLYING
	visible = true
	_trail.active = true
	_apply_transform()
	reset_physics_interpolation()
	launched.emit()


func reset() -> void:
	mode = Mode.IDLE
	visible = false
	_skip_armed = true
	if _spray:
		_spray.emitting = false
	_trail.active = false
	_trail.clear()


func set_controls(x: float, y: float) -> void:
	_raw_x = clampf(x, -1.0, 1.0)
	_raw_y = clampf(y, -1.0, 1.0)


func use_gust() -> bool:
	if mode != Mode.FLYING or gusts < 1.0:
		return false
	gusts -= 1.0
	state.flap_v += gust_flap
	state.v = minf(max_speed, state.v + gust_speed)
	Audio.play("gust", -3.0)
	gust_used.emit()
	return true


func add_star_gust() -> void:
	gusts = minf(gust_max, gusts + star_gust)


func barrel_roll(direction: float) -> void:
	if mode != Mode.FLYING or _roll_t >= 0.0:
		return
	_roll_t = 0.0
	_roll_dir = signf(direction) if direction != 0.0 else 1.0
	Audio.play("roll", -6.0, 1.1)


func forward() -> Vector3:
	return Vector3(-sin(state.yaw) * cos(state.pitch), sin(state.pitch), -cos(state.yaw) * cos(state.pitch))


func velocity() -> Vector3:
	var f := Vector3(-sin(state.yaw) * cos(state.pitch), 0.0, -cos(state.yaw) * cos(state.pitch))
	return f * state.v + Vector3(0, state.vy, 0)


func speed() -> float:
	return state.v


# --- Flight model ------------------------------------------------------------------------

static func _damp(a: float, b: float, rate: float, dt: float) -> float:
	return lerpf(a, b, 1.0 - exp(-rate * dt))


## Advances a flight state by dt with the given inputs. Returns the lift (m/s) used.
func step_state(s: FlightState, ix: float, iy: float, dt: float) -> float:
	var stall := s.v < stall_speed
	var target_pitch := stall_pitch if stall else clampf(trim_pitch + iy * pitch_input_gain, pitch_min, pitch_max)
	s.pitch = _damp(s.pitch, target_pitch, pitch_rate_stall if stall else pitch_rate, dt)
	s.roll = _damp(s.roll, ix * roll_gain, roll_rate, dt)
	s.yaw -= s.roll * turn_rate * dt * clampf(s.v / 9.0, 0.6, 1.5)
	s.v += (-gravity * sin(s.pitch) - drag * s.v * s.v) * dt
	s.v = clampf(s.v, min_speed, max_speed)
	var h := s.pos.y - _surface_under(s.pos)
	var ge := 1.0
	if h < ground_effect_height:
		ge = 0.4 + 0.6 * clampf(h / ground_effect_height, 0.0, 1.0)
	var sink := (base_sink + maxf(0.0, slow_sink_speed - s.v) * slow_sink_gain) * ge
	var l := 0.0
	if level:
		l = level.lift_at(s.pos)
	s.vy = s.v * sin(s.pitch) - sink + l + s.flap_v
	s.flap_v = _damp(s.flap_v, 0.0, flap_damp, dt)
	var fwd := Vector3(-sin(s.yaw) * cos(s.pitch), 0.0, -cos(s.yaw) * cos(s.pitch))
	s.pos += fwd * s.v * dt + Vector3(0, s.vy * dt, 0)
	return l


func _surface_under(p: Vector3) -> float:
	var g := Terrain.surface_height(p.x, p.z)
	if level and level.has_method("pad_surface_under"):
		g = maxf(g, level.pad_surface_under(p))
	return g


func _physics_process(dt: float) -> void:
	match mode:
		Mode.FLYING:
			_fly(dt)
		Mode.SLIDING:
			_slide(dt)
		Mode.SKIMMING:
			_skim(dt)
		Mode.LANDED:
			_skid(dt)
		Mode.CRASHED:
			pass


func _fly(dt: float) -> void:
	if autopilot.is_valid():
		var ap: Vector2 = autopilot.call()
		_raw_x = ap.x
		_raw_y = ap.y
	in_x = _damp(in_x, _raw_x, input_damp, dt)
	in_y = _damp(in_y, _raw_y, input_damp, dt)
	var prev := state.pos
	var prev_vy := state.vy
	lift = step_state(state, in_x, in_y, dt)
	flight_time += dt
	agl = state.pos.y - _surface_under(state.pos)
	if agl > 1.0:
		_skip_armed = true
	gusts = minf(gust_max, gusts + dt / gust_refill_time)

	# Once stalled, it only counts as recovered with a little speed to spare (no flicker).
	var now_stalled := state.v < (stall_speed + 0.8 if stalled else stall_speed)
	if now_stalled and not stalled:
		stall_entered.emit()
		Audio.play("stall", -4.0)
	stalled = now_stalled

	_rising_cooldown -= dt
	_thermal_cooldown -= dt
	var inside := lift > 0.4
	if inside and not _was_inside and _thermal_cooldown <= 0.0:
		entered_thermal.emit()
		Audio.play("updraft", -5.0)
		_thermal_cooldown = 1.5
	_was_inside = inside
	var rising := lift > rising_air_threshold
	if rising and not _was_rising and _rising_cooldown <= 0.0:
		rising_air.emit()
		Audio.play("rising", -4.0)
		_rising_cooldown = 3.0
	_was_rising = rising

	if _roll_t >= 0.0:
		_roll_t += dt
		if _roll_t >= barrel_roll_time:
			_roll_t = -1.0
			rolls_done += 1
			barrel_roll_done.emit()

	_apply_transform()
	if level:
		level.process_flight(prev, state.pos)
	_check_collisions(prev, prev_vy)


func _apply_transform() -> void:
	position = state.pos
	rotation = Vector3(state.pitch, state.yaw, 0.0)
	var extra := 0.0
	if _roll_t >= 0.0:
		var t := clampf(_roll_t / barrel_roll_time, 0.0, 1.0)
		extra = _roll_dir * TAU * (t * t * (3.0 - 2.0 * t))
	_visual.rotation = Vector3(0, 0, -state.roll - extra)


# --- Collision and landing ------------------------------------------------------------------

func _check_collisions(prev: Vector3, prev_vy: float) -> void:
	var pos := state.pos
	if Terrain.out_of_bounds(pos):
		_crash("Blown out of town", "out", pos)
		return
	# Analytic landing window around the pad.
	if level and level.is_landing(prev, pos):
		_land(level.pad_contact_point(pos))
		return
	# Swept sphere against world and pads.
	var space := get_world_3d().direct_space_state
	var motion := pos - prev
	_query.transform = Transform3D(Basis(), prev)
	_query.motion = motion
	var res := space.cast_motion(_query)
	if res.size() == 2 and res[1] < 1.0:
		var contact := prev + motion * res[1]
		_query.transform = Transform3D(Basis(), contact)
		_query.motion = Vector3.ZERO
		var info := space.get_rest_info(_query)
		var collider: Object = null
		if info.has("collider_id"):
			collider = instance_from_id(info.collider_id)
		var safe := prev + motion * res[0]
		if collider and collider is CollisionObject3D and (collider as CollisionObject3D).collision_layer & 2:
			if level and prev.y >= level.pad_top() - 0.15:
				_land(level.pad_contact_point(safe))
				return
		# Clipping the edge of the target itself (a raft or jetty) at deck height: hop up onto it.
		if level and level.horizontal_distance_to_pad(contact) < level.pad_radius() + 0.4 				and absf(contact.y - level.pad_top()) < 0.35:
			_land(level.pad_contact_point(safe))
			return
		var kind := "wall"
		if collider and collider.has_meta("kind"):
			kind = collider.get_meta("kind")
		var touch: Vector3 = info.get("point", contact)
		if kind == "pet":
			# Ran into one of the pets sitting by the landing spot: a gentle stop, no crash.
			_crash("Bumped into a pet", "stopped", safe)
			return
		if _can_slide(info.get("normal", Vector3.ZERO)):
			_start_slide(Vector3(safe.x, touch.y, safe.z))
			return
		_crash(_message_for(kind, safe), kind, safe, touch)
		return
	# Hazard lines (bunting, washing, lanterns): only the visible rope and hanging items.
	if level:
		var line_hit: Dictionary = level.hazard_hit(prev, pos)
		if not line_hit.is_empty():
			var tp: Vector3 = line_hit.point
			_crash(line_hit.message, "line", Geometry3D.get_closest_point_to_segment(tp, prev, pos), tp)
			return
	# Ground and water.
	var ground := Terrain.ground_height(pos.x, pos.z)
	var water := Terrain.water_height(pos.x, pos.z)
	if pos.y - collision_radius * 0.5 < water:
		_touch_water(pos, water)
		return
	if pos.y - collision_radius < ground:
		if _can_slide(_ground_normal(pos.x, pos.z)):
			_start_slide(Vector3(pos.x, ground, pos.z))
			return
		var near: bool = level != null and level.horizontal_distance_to_pad(pos) < short_landing_distance + level.pad_radius()
		_crash("Touched down short" if near else "Crash landing", "ground", Vector3(pos.x, ground + 0.05, pos.z))


func _message_for(kind: String, at: Vector3) -> String:
	match kind:
		"tree": return "Snagged in a tree"
		"bridge": return "Bonk! Into the bridge"
		"wall", "car": return "Bonk! Into a wall"
		"water": return "Splash! Into the river"
		"fan": return "Whacked by the ceiling fan"
		"glass": return "Bonk! The window was closed"
		"greenhouse": return "Bonk! Into the greenhouse glass"
		"lamp": return "Clonk! Into the hanging lamp"
		"furniture": return "Bumped into the furniture"
		"banister": return "Clipped the banister"
		"ceiling": return "Bonk! Into the ceiling"
	if level and level.horizontal_distance_to_pad(at) < short_landing_distance + level.pad_radius() and at.y < level.pad_top() + 2.0:
		return "Touched down short"
	return "Crash landing"


func _land(contact: Vector3) -> void:
	# A slide-in keeps the softness of its first touch; a direct landing uses this moment.
	var sliding_in := mode == Mode.SLIDING or mode == Mode.SKIMMING
	_land_info = {
		"vertical_impact": _touch_impact if sliding_in else maxf(0.0, -state.vy),
		"speed": _touch_speed if sliding_in else state.v,
	}
	mode = Mode.LANDED
	_landed_sent = false
	_trail.active = false
	state.pos = contact
	state.vy = 0.0
	_skid_t = 0.0
	_apply_transform()
	_play_landing_fx(contact)


## Called once the plane has stopped on the pad: the landing is scored where it rests.
func _finish_landing() -> void:
	if _landed_sent:
		return
	_landed_sent = true
	var info := _land_info.duplicate()
	info["position"] = state.pos
	info["dist"] = level.horizontal_distance_to_pad(state.pos) if level else 0.0
	landed.emit(info)


func _skid(dt: float) -> void:
	_skid_t += dt
	state.v *= exp(-pad_friction * dt)
	if state.v < 0.3 or _skid_t > 3.0:
		_finish_landing()
	state.pitch = _damp(state.pitch, 0.0, 6.0, dt)
	state.roll = _damp(state.roll, 0.0, 6.0, dt)
	var fwd := Vector3(-sin(state.yaw), 0.0, -cos(state.yaw))
	var step := fwd * state.v * dt * 0.6
	if step.length() > 0.0005:
		var space := get_world_3d().direct_space_state
		_query.transform = Transform3D(Basis(), state.pos + Vector3(0, 0.26, 0))
		_query.motion = step
		_query.collision_mask = 1
		var res := space.cast_motion(_query)
		_query.collision_mask = 1 | 2
		var next := state.pos + step * (res[0] if res.size() == 2 else 1.0)
		# Stay on the target: move freely inside it, and always allow moving toward the center
		# (a slide-in arrives right at the edge).
		if level == null:
			state.pos = next
		else:
			var d_next: float = level.horizontal_distance_to_pad(next)
			if d_next < level.pad_radius() + 0.3 or d_next < level.horizontal_distance_to_pad(state.pos):
				state.pos = next
	_apply_transform()


# --- Sliding -----------------------------------------------------------------------------

## True when the plane meets a surface with this normal gently enough to slide on it.
func _can_slide(normal: Vector3) -> bool:
	if normal.y < slide_min_flatness or state.pitch < -0.5:
		return false
	var vel := velocity()
	if vel.length() < 0.01:
		return true
	var into := -vel.normalized().dot(normal)
	return into < sin(deg_to_rad(slide_max_angle))


func _ground_normal(x: float, z: float) -> Vector3:
	var hx := Terrain.ground_height(x + 0.5, z) - Terrain.ground_height(x - 0.5, z)
	var hz := Terrain.ground_height(x, z + 0.5) - Terrain.ground_height(x, z - 0.5)
	return Vector3(-hx, 1.0, -hz).normalized()


func _start_slide(at: Vector3) -> void:
	_touch_impact = maxf(0.0, -state.vy)
	_touch_speed = state.v
	mode = Mode.SLIDING
	_skid_t = 0.0
	state.pos = at + Vector3(0, 0.03, 0)
	state.vy = 0.0
	state.flap_v = 0.0
	_apply_transform()
	Audio.play("roll", -8.0, 1.6)
	# Touching down right on the target is a normal landing.
	if level and level.is_landing(state.pos, state.pos):
		_land(level.pad_contact_point(state.pos))


## Height of the floor under a point (ground, or any flat collider), or -INF when there is none.
func _floor_below(p: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.6, 0), p + Vector3(0, -1.2, 0), 1 | 2)
	var hit := space.intersect_ray(q)
	var ground := Terrain.ground_height(p.x, p.z)
	if hit.is_empty() or hit.position.y < ground:
		return {"y": ground, "pad": false, "water": Terrain.is_water(p.x, p.z), "flat": _ground_normal(p.x, p.z).y >= slide_min_flatness}
	var col: Object = hit.collider
	var is_pad: bool = col is CollisionObject3D and (col as CollisionObject3D).collision_layer & 2
	return {"y": hit.position.y, "pad": is_pad, "water": false, "flat": hit.normal.y >= slide_min_flatness}


func _slide(dt: float) -> void:
	_skid_t += dt
	state.v *= exp(-slide_friction * dt)
	state.pitch = _damp(state.pitch, 0.0, 8.0, dt)
	state.roll = _damp(state.roll, 0.0, 6.0, dt)
	var fwd := Vector3(-sin(state.yaw), 0.0, -cos(state.yaw))
	var step := fwd * state.v * dt
	# Something in the way ahead (checked just above the floor): bonk.
	var space := get_world_3d().direct_space_state
	_query.transform = Transform3D(Basis(), state.pos + Vector3(0, 0.24, 0))
	_query.motion = step
	_query.collision_mask = 1
	var res := space.cast_motion(_query)
	_query.collision_mask = 1 | 2
	if res.size() == 2 and res[1] < 1.0:
		_query.transform = Transform3D(Basis(), state.pos + Vector3(0, 0.24, 0) + step * res[1])
		_query.motion = Vector3.ZERO
		var info := space.get_rest_info(_query)
		var kind := "wall"
		var col: Object = instance_from_id(info.collider_id) if info.has("collider_id") else null
		if col and col.has_meta("kind"):
			kind = col.get_meta("kind")
		if kind == "pet":
			_crash("Bumped into a pet", "stopped", state.pos)
			return
		_crash(_message_for(kind, state.pos), kind, state.pos, info.get("point", state.pos))
		return
	var next := state.pos + step
	var below := _floor_below(next)
	if below.water:
		# Slid off the bank into the water: carry on as a skim.
		_start_skim(Vector3(next.x, Terrain.water_height(next.x, next.z), next.z))
		return
	if next.y - below.y > 0.35 or not below.flat:
		# Slid off an edge: it's flying again (falling).
		state.pos = next
		state.pitch = -0.2
		mode = Mode.FLYING
		_apply_transform()
		return
	state.pos = Vector3(next.x, below.y + 0.03, next.z)
	_apply_transform()
	if level and (below.pad or level.is_landing(state.pos, state.pos)):
		_land(level.pad_contact_point(state.pos))
		return
	if state.v < 0.3 or _skid_t > 4.0:
		# Came to rest off the target: no crumple, just short.
		var near: bool = level != null and level.horizontal_distance_to_pad(state.pos) < short_landing_distance + level.pad_radius()
		_crash("Touched down short" if near else "Landed off target", "stopped", state.pos)


# --- Water: skip, skim, splash ----------------------------------------------------------

func _touch_water(pos: Vector3, water: float) -> void:
	var vel := velocity()
	var into := -vel.normalized().y if vel.length() > 0.01 else 0.0
	var surface := Vector3(pos.x, water, pos.z)
	if state.pitch < -0.5 or into > sin(deg_to_rad(25.0)):
		_crash("Splash! Into %s" % Terrain.water_name(pos.x, pos.z), "water", surface + Vector3(0, 0.05, 0))
		return
	if _skip_armed and state.v > skip_min_speed and into < sin(deg_to_rad(skip_max_angle)):
		# Skip like a stone: bounce back up, a little slower.
		_skip_armed = false
		state.pos = surface + Vector3(0, collision_radius * 0.6, 0)
		state.vy = 0.0
		state.v *= skip_speed_keep
		state.flap_v += skip_pop
		state.pitch = maxf(state.pitch, 0.04)
		_apply_transform()
		_spray_burst(surface, 18)
		Audio.play("splash", -12.0, 1.5)
		skipped.emit()
		return
	# Too slow (or already skipped without climbing away): skim a short way, then soak.
	_touch_impact = maxf(0.0, -state.vy)
	_touch_speed = state.v
	_start_skim(surface)


func _start_skim(surface: Vector3) -> void:
	mode = Mode.SKIMMING
	_skid_t = 0.0
	_skim_y = surface.y
	state.pos = surface + Vector3(0, 0.02, 0)
	state.vy = 0.0
	state.flap_v = 0.0
	_apply_transform()
	_spray.global_position = state.pos
	_spray.emitting = true
	Audio.play("splash", -10.0, 1.3)


func _skim(dt: float) -> void:
	_skid_t += dt
	state.v *= exp(-skim_friction * dt)
	state.pitch = _damp(state.pitch, 0.02, 8.0, dt)
	state.roll = _damp(state.roll, 0.0, 6.0, dt)
	var fwd := Vector3(-sin(state.yaw), 0.0, -cos(state.yaw))
	var step := fwd * state.v * dt
	var next := state.pos + step
	# Skimmed up onto a raft or jetty that is the target: that's a landing.
	if level and level.is_landing(state.pos, next):
		_spray.emitting = false
		state.pos = next
		_land(level.pad_contact_point(next))
		return
	var space := get_world_3d().direct_space_state
	_query.transform = Transform3D(Basis(), state.pos + Vector3(0, 0.24, 0))
	_query.motion = step
	_query.collision_mask = 1
	var res := space.cast_motion(_query)
	_query.collision_mask = 1 | 2
	if res.size() == 2 and res[1] < 1.0:
		_spray.emitting = false
		# Skimmed into the side of the target itself (a boat or raft): hop aboard.
		if level and level.horizontal_distance_to_pad(next) < level.pad_radius() + 1.0 				and absf(level.pad_top() - _skim_y) < 0.5:
			_land(level.pad_contact_point(state.pos))
			return
		_crash(_message_for("wall", state.pos), "wall", state.pos)
		return
	if not Terrain.is_water(next.x, next.z):
		_spray.emitting = false
		var g := Terrain.ground_height(next.x, next.z)
		if g > _skim_y + 0.2:
			# Bumped into a stone pond edge: stop here.
			_crash("Soaked!", "soaked", state.pos)
			return
		# Skimmed onto a sloping bank: carry on as a normal slide.
		state.pos = Vector3(next.x, g + 0.03, next.z)
		mode = Mode.SLIDING
		_apply_transform()
		return
	state.pos = Vector3(next.x, _skim_y + 0.02, next.z)
	_spray.global_position = state.pos
	_spray.amount_ratio = clampf(state.v / 6.0, 0.2, 1.0)
	_apply_transform()
	if state.v < 0.5 or _skid_t > 1.2:
		_spray.emitting = false
		_crash("Soaked!", "soaked", state.pos)
		# The wet paper settles into the water.
		var tw := create_tween().set_parallel(true).set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tw.tween_property(self, "position:y", _skim_y - 0.06, 1.4).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_visual, "rotation:x", -0.25, 1.4)


func _spray_burst(at: Vector3, count: int) -> void:
	_spray.global_position = at
	_spray.restart()
	_spray.emitting = true
	_spray.amount_ratio = clampf(count / 30.0, 0.2, 1.0)
	get_tree().create_timer(0.15).timeout.connect(func(): if mode != Mode.SKIMMING: _spray.emitting = false)


func _crash(message: String, kind: String, at: Vector3, touch: Variant = null) -> void:
	mode = Mode.CRASHED
	_trail.active = false
	state.pos = at
	position = at
	if kind != "stopped" and kind != "soaked":
		_play_crash_fx(kind)
		_play_bonk(touch if touch != null else at)
	crashed.emit(message, kind)


# --- Effects ---------------------------------------------------------------------------------

func _build_effects() -> void:
	_sparkles = GPUParticles3D.new()
	_sparkles.name = "Sparkles"
	_sparkles.one_shot = true
	_sparkles.emitting = false
	_sparkles.amount = 60
	_sparkles.lifetime = 1.4
	_sparkles.explosiveness = 0.95
	_sparkles.top_level = true
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 75.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -2.5, 0)
	pm.damping_min = 1.5
	pm.damping_max = 2.5
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.5, 1.0))
	g.set_color(1, Color(1.0, 0.75, 0.3, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_sparkles.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	q.material = Mats.additive(Color(1, 0.9, 0.55), TexGen.get_tex("star_glint"), true)
	_sparkles.draw_pass_1 = q
	add_child(_sparkles)

	_scraps = GPUParticles3D.new()
	_scraps.name = "Scraps"
	_scraps.one_shot = true
	_scraps.emitting = false
	_scraps.amount = 26
	_scraps.lifetime = 1.6
	_scraps.explosiveness = 1.0
	_scraps.top_level = true
	var sm := ParticleProcessMaterial.new()
	sm.direction = Vector3.UP
	sm.spread = 120.0
	sm.initial_velocity_min = 1.5
	sm.initial_velocity_max = 4.0
	sm.gravity = Vector3(0, -6.0, 0)
	sm.angular_velocity_min = -400.0
	sm.angular_velocity_max = 400.0
	sm.angle_max = 360.0
	sm.scale_min = 0.5
	sm.scale_max = 1.2
	_scraps.process_material = sm
	var sq := QuadMesh.new()
	sq.size = Vector2(0.09, 0.07)
	var paper := StandardMaterial3D.new()
	paper.albedo_texture = TexGen.get_tex("paper")
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper.vertex_color_use_as_albedo = true
	paper.particles_anim_h_frames = 1
	sq.material = paper
	_scraps.draw_pass_1 = sq
	add_child(_scraps)

	_spray = GPUParticles3D.new()
	_spray.name = "WaterSpray"
	_spray.top_level = true
	_spray.local_coords = false
	_spray.emitting = false
	_spray.amount = 30
	_spray.lifetime = 0.6
	_spray.visibility_aabb = AABB(Vector3(-5, -3, -5), Vector3(10, 6, 10))
	var wm := ParticleProcessMaterial.new()
	wm.direction = Vector3(0, 1, 0)
	wm.spread = 55.0
	wm.initial_velocity_min = 0.8
	wm.initial_velocity_max = 2.2
	wm.gravity = Vector3(0, -6.0, 0)
	wm.scale_min = 0.5
	wm.scale_max = 1.2
	var wg := Gradient.new()
	wg.set_color(0, Color(0.95, 0.98, 1.0, 0.85))
	wg.set_color(1, Color(0.9, 0.96, 1.0, 0.0))
	var wgt := GradientTexture1D.new()
	wgt.gradient = wg
	wm.color_ramp = wgt
	_spray.process_material = wm
	var wq := QuadMesh.new()
	wq.size = Vector2(0.14, 0.14)
	wq.material = Mats.soft_alpha(Color(1, 1, 1, 1), TexGen.get_tex("soft_dot"))
	_spray.draw_pass_1 = wq
	_spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spray)

	_bonk = MeshInstance3D.new()
	_bonk.name = "ContactBurst"
	var bq := QuadMesh.new()
	bq.size = Vector2(0.9, 0.9)
	_bonk.mesh = bq
	var bm := Mats.additive(Color(1.0, 0.95, 0.8, 1.0), TexGen.get_tex("star_glint"))
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bm.no_depth_test = true
	bm.render_priority = 10
	_bonk.material_override = bm
	_bonk.top_level = true
	_bonk.visible = false
	_bonk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bonk)

	_shock = MeshInstance3D.new()
	_shock.name = "Shockwave"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 6
	_shock.mesh = torus
	_shock.material_override = Mats.additive(Color(1.0, 0.85, 0.45, 0.9))
	_shock.top_level = true
	_shock.visible = false
	_shock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shock)


## A quick flash exactly where the plane touched something.
func _play_bonk(at: Vector3) -> void:
	_bonk.global_position = at
	_bonk.visible = true
	_bonk.scale = Vector3.ONE * 0.2
	var mat := _bonk.material_override as StandardMaterial3D
	mat.albedo_color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_bonk, "scale", Vector3.ONE * 1.4, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tw.tween_callback(func(): _bonk.visible = false)


func _play_landing_fx(at: Vector3) -> void:
	_sparkles.global_position = at + Vector3(0, 0.2, 0)
	_sparkles.restart()
	_shock.global_position = at + Vector3(0, 0.06, 0)
	_shock.scale = Vector3(0.3, 0.3, 0.3)
	_shock.visible = true
	var mat := _shock.material_override as StandardMaterial3D
	mat.albedo_color.a = 0.9
	var tw := create_tween().set_parallel(true).set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(_shock, "scale", Vector3(7.0, 1.0, 7.0), 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.1)
	tw.chain().tween_callback(func(): _shock.visible = false)
	Audio.play("land", -2.0)


func _play_crash_fx(kind: String) -> void:
	_scraps.global_position = global_position
	_scraps.restart()
	if kind == "water":
		Audio.play("splash", -2.0)
	else:
		Audio.play("crumple", 0.0)
	var tw := create_tween().set_parallel(true).set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(_visual, "scale", Vector3(0.55, 0.32, 0.42), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "rotation", _visual.rotation + Vector3(1.2, 2.6, 0.8), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# --- Wingtip trails ---------------------------------------------------------------------------

func _build_trails() -> void:
	_trail = PlaneTrail.new()
	_trail.name = "Trail"
	_trail.source = _visual
	add_child(_trail)


## Selects the wingtip trail look (see Cosmetics.TRAILS).
func set_trail_style(style: String) -> void:
	trail_style = style
	_trail.set_style(style)


# --- Prediction -------------------------------------------------------------------------------

## Runs the flight model forward with the current inputs. Returns {hit, position, on_pad}.
func predict_touchdown(steps := 90, dt := 0.08) -> Dictionary:
	var s := state.copy()
	for i in steps:
		step_state(s, in_x, in_y, dt)
		if level and level.horizontal_distance_to_pad(s.pos) < level.pad_radius() + 0.4 and s.pos.y <= level.pad_top() + 0.05:
			return {"hit": true, "position": Vector3(s.pos.x, level.pad_top(), s.pos.z), "on_pad": true}
		var g := Terrain.surface_height(s.pos.x, s.pos.z)
		if s.pos.y <= g + 0.05:
			return {"hit": true, "position": Vector3(s.pos.x, g, s.pos.z), "on_pad": false}
	return {"hit": false}
