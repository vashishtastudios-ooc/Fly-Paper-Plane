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

enum Mode { IDLE, FLYING, LANDED, CRASHED }

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
var _visual: Node3D
var _trail_l := PackedVector3Array()
var _trail_r := PackedVector3Array()
var _trail_mesh: ImmediateMesh
var _trail_node: MeshInstance3D
var _trail_fade := 0.0
var _query := PhysicsShapeQueryParameters3D.new()
var _sparkles: GPUParticles3D
var _scraps: GPUParticles3D
var _shock: MeshInstance3D


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
	_trail_l.clear()
	_trail_r.clear()
	_trail_fade = 1.0
	mode = Mode.FLYING
	visible = true
	_apply_transform()
	reset_physics_interpolation()
	launched.emit()


func reset() -> void:
	mode = Mode.IDLE
	visible = false
	_trail_l.clear()
	_trail_r.clear()
	_trail_mesh.clear_surfaces()


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
		Mode.LANDED:
			_skid(dt)
		Mode.CRASHED:
			pass
	_update_trail_points()


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
	gusts = minf(gust_max, gusts + dt / gust_refill_time)

	var now_stalled := state.v < stall_speed
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
		var kind := "wall"
		if collider and collider.has_meta("kind"):
			kind = collider.get_meta("kind")
		_crash(_message_for(kind, safe), kind, safe)
		return
	# Hazard lines (bunting, washing).
	if level:
		var line_msg: String = level.hazard_hit(pos)
		if line_msg != "":
			_crash(line_msg, "line", pos)
			return
	# Ground and water.
	var ground := Terrain.ground_height(pos.x, pos.z)
	if ground < Terrain.WATER_Y and pos.y - collision_radius * 0.5 < Terrain.WATER_Y:
		_crash("Splash! Into the river", "water", Vector3(pos.x, Terrain.WATER_Y + 0.05, pos.z))
		return
	if pos.y - collision_radius < ground:
		var near: bool = level != null and level.horizontal_distance_to_pad(pos) < short_landing_distance + level.pad_radius()
		_crash("Touched down short" if near else "Crash landing", "ground", Vector3(pos.x, ground + 0.05, pos.z))


func _message_for(kind: String, at: Vector3) -> String:
	match kind:
		"tree": return "Snagged in a tree"
		"bridge": return "Bonk! Into the bridge"
		"wall", "car": return "Bonk! Into a wall"
		"water": return "Splash! Into the river"
	if level and level.horizontal_distance_to_pad(at) < short_landing_distance + level.pad_radius() and at.y < level.pad_top() + 2.0:
		return "Touched down short"
	return "Crash landing"


func _land(contact: Vector3) -> void:
	var info := {
		"position": contact,
		"vertical_impact": maxf(0.0, -state.vy),
		"speed": state.v,
		"dist": level.horizontal_distance_to_pad(contact) if level else 0.0,
	}
	mode = Mode.LANDED
	state.pos = contact
	state.vy = 0.0
	_skid_t = 0.0
	_apply_transform()
	_play_landing_fx(contact)
	landed.emit(info)


func _skid(dt: float) -> void:
	_skid_t += dt
	state.v *= exp(-3.2 * dt)
	state.pitch = _damp(state.pitch, 0.0, 6.0, dt)
	state.roll = _damp(state.roll, 0.0, 6.0, dt)
	var fwd := Vector3(-sin(state.yaw), 0.0, -cos(state.yaw))
	var step := fwd * state.v * dt * 0.6
	if step.length() > 0.0005:
		var space := get_world_3d().direct_space_state
		_query.transform = Transform3D(Basis(), state.pos + Vector3(0, 0.15, 0))
		_query.motion = step
		_query.collision_mask = 1
		var res := space.cast_motion(_query)
		_query.collision_mask = 1 | 2
		var next := state.pos + step * (res[0] if res.size() == 2 else 1.0)
		if level == null or level.horizontal_distance_to_pad(next) < level.pad_radius() + 0.3:
			state.pos = next
	_apply_transform()


func _crash(message: String, kind: String, at: Vector3) -> void:
	mode = Mode.CRASHED
	state.pos = at
	position = at
	_play_crash_fx(kind)
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


func _play_landing_fx(at: Vector3) -> void:
	_sparkles.global_position = at + Vector3(0, 0.2, 0)
	_sparkles.restart()
	_shock.global_position = at + Vector3(0, 0.06, 0)
	_shock.scale = Vector3(0.3, 0.3, 0.3)
	_shock.visible = true
	var mat := _shock.material_override as StandardMaterial3D
	mat.albedo_color.a = 0.9
	var tw := create_tween().set_parallel(true)
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
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_visual, "scale", Vector3(0.55, 0.32, 0.42), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "rotation", _visual.rotation + Vector3(1.2, 2.6, 0.8), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# --- Wingtip trails ---------------------------------------------------------------------------

const TRAIL_POINTS := 36

func _build_trails() -> void:
	_trail_mesh = ImmediateMesh.new()
	_trail_node = MeshInstance3D.new()
	_trail_node.name = "Trails"
	_trail_node.mesh = _trail_mesh
	_trail_node.top_level = true
	_trail_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail_node.material_override = m
	add_child(_trail_node)


func _update_trail_points() -> void:
	if mode == Mode.FLYING:
		var xf := global_transform * _visual.transform
		_trail_l.append(xf * PaperPlaneMesh.TIP_LEFT)
		_trail_r.append(xf * PaperPlaneMesh.TIP_RIGHT)
		while _trail_l.size() > TRAIL_POINTS:
			_trail_l.remove_at(0)
			_trail_r.remove_at(0)
	elif _trail_l.size() > 0:
		_trail_l.remove_at(0)
		_trail_r.remove_at(0)


func _process(_delta: float) -> void:
	_trail_node.global_transform = Transform3D.IDENTITY
	_trail_mesh.clear_surfaces()
	if _trail_l.size() < 2:
		return
	var cam := get_viewport().get_camera_3d()
	var cam_pos := cam.global_position if cam else Vector3.ZERO
	for trail in [_trail_l, _trail_r]:
		_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var n: int = trail.size()
		for i in n:
			var p: Vector3 = trail[i]
			var t := float(i) / float(n - 1)
			var dir: Vector3 = (trail[mini(i + 1, n - 1)] - trail[maxi(i - 1, 0)])
			var to_cam := (cam_pos - p).normalized()
			var side := dir.cross(to_cam).normalized() * (0.012 + 0.022 * t)
			var near_fade := smoothstep(1.2, 3.2, p.distance_to(cam_pos))
			var c := Color(1, 1, 1, 0.55 * t * t * near_fade)
			_trail_mesh.surface_set_color(c)
			_trail_mesh.surface_add_vertex(p - side)
			_trail_mesh.surface_set_color(c)
			_trail_mesh.surface_add_vertex(p + side)
		_trail_mesh.surface_end()


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
