class_name ChaseCamera
extends Camera3D
## Chase, intro orbit, menu trailing and post-flight orbit camera.

enum Mode { MENU, INTRO, FOLLOW, ORBIT }

@export var landscape_back := 3.3
@export var landscape_up := 1.0
@export var portrait_back := 4.4
@export var portrait_up := 1.5
@export var look_ahead := 7.0
@export var roll_follow := 0.28
@export var smooth_rate := 6.0
@export var launch_smooth_rate := 3.0
@export var launch_smooth_time := 0.6
@export var base_fov := 64.0
@export var speed_fov := 11.0

var mode := Mode.MENU
var plane: PaperPlane
var menu_target: Node3D
var intro_center := Vector3.ZERO
var intro_yaw := 0.0
var orbit_center := Vector3.ZERO

var _time := 0.0
var _since_launch := 10.0
var _shake := 0.0
var _lift_s := 0.0
var _orbit_angle := 0.0
var _look := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _post: MeshInstance3D


## Full-screen quad drawn last: soft ink outline, vignette and paper grain.
func _build_storybook_pass() -> void:
	_post = MeshInstance3D.new()
	_post.name = "StorybookPass"
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/storybook_post.gdshader")
	m.render_priority = 127
	q.material = m
	_post.mesh = q
	_post.extra_cull_margin = 16384.0
	_post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_post.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_post)


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	near = 0.08
	far = 1600.0
	fov = base_fov
	_build_storybook_pass()
	Settings.quality_changed.connect(func(q: int): _post.visible = q >= 1)
	_post.visible = Settings.quality >= 1


func set_mode(m: int, snap := false) -> void:
	mode = m
	_time = 0.0
	if m == Mode.FOLLOW:
		_since_launch = 0.0
	if m == Mode.ORBIT and plane:
		var to_cam := global_position - orbit_center
		_orbit_angle = atan2(to_cam.x, to_cam.z)
	if snap:
		_update(1.0, true)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	_time += delta
	_since_launch += delta
	_update(delta, false)


func _base_fov() -> float:
	var s := get_viewport().get_visible_rect().size
	var aspect := s.x / maxf(s.y, 1.0)
	if aspect < 1.0:
		return clampf(rad_to_deg(2.0 * atan(tan(deg_to_rad(37.0)) / aspect)), 62.0, 95.0)
	return base_fov


func _portrait() -> bool:
	var s := get_viewport().get_visible_rect().size
	return s.y > s.x


func _update(delta: float, snap: bool) -> void:
	var desired := global_position
	var look := _look
	var target_fov := _base_fov()
	var rate := smooth_rate
	var cam_roll := 0.0
	match mode:
		Mode.MENU:
			if menu_target:
				var mp := menu_target.global_position
				var fwd := -menu_target.global_transform.basis.z
				fwd.y = 0.0
				fwd = fwd.normalized()
				var side := fwd.cross(Vector3.UP)
				desired = mp - fwd * 6.5 + Vector3.UP * 1.8 + side * 1.6
				look = mp + fwd * 6.0
				rate = 2.5
		Mode.INTRO:
			var swing := sin(_time * 0.22) * 0.85
			# Sweep slowly through an arc in front of the kid (the house is behind).
			var a := intro_yaw + swing
			var r := 4.6
			var head := intro_center + Vector3(0, 1.0, 0)
			desired = intro_center + Vector3(-sin(a) * r, 1.5 + 0.3 * sin(_time * 0.4), -cos(a) * r)
			desired = _avoid_walls(head, desired)
			# Frame the kid beside the intro card: right of center in landscape, high in portrait.
			var right := (head - desired).cross(Vector3.UP).normalized()
			look = head + Vector3(0, -0.9, 0) if _portrait() else head - right * 1.3
			rate = 2.0
		Mode.FOLLOW:
			if plane:
				var p := plane.get_global_transform_interpolated().origin
				var s := plane.state
				var portrait := _portrait()
				var back := portrait_back if portrait else landscape_back
				var up := portrait_up if portrait else landscape_up
				var dir := Vector3(-sin(s.yaw), 0.0, -cos(s.yaw))
				var right := dir.cross(Vector3.UP)
				var dive := maxf(0.0, -s.pitch) * 2.2
				# Gentle upward float while riding rising air.
				_lift_s = lerpf(_lift_s, clampf(plane.lift / 4.0, 0.0, 1.0), 1.0 - exp(-1.5 * delta))
				desired = p - dir * back + Vector3.UP * (up + dive + _lift_s * 0.75) - right * (s.roll * 0.8)
				var vel := plane.velocity()
				var vdir := vel.normalized() if vel.length() > 0.1 else dir
				look = p + vdir * look_ahead + Vector3.UP * _lift_s * 0.4
				rate = launch_smooth_rate if _since_launch < launch_smooth_time else smooth_rate
				cam_roll = s.roll * roll_follow
				target_fov += clampf((s.v - 9.0) / 12.0, 0.0, 1.0) * speed_fov + _lift_s * 2.5
				desired = _clamp_to_world(desired, p)
				desired = _avoid_walls(p + Vector3(0, 0.15, 0), desired)
		Mode.ORBIT:
			_orbit_angle += delta * 0.32
			var r2 := 5.5
			desired = orbit_center + Vector3(sin(_orbit_angle) * r2, 2.3, cos(_orbit_angle) * r2)
			desired = _clamp_to_world(desired, orbit_center)
			desired = _avoid_walls(orbit_center + Vector3(0, 0.4, 0), desired)
			look = orbit_center + Vector3(0, 0.3, 0)
			rate = 2.5
	var k := 1.0 if snap else 1.0 - exp(-rate * delta)
	var pos := global_position.lerp(desired, k)
	_look = look if snap else _look.lerp(look, 1.0 - exp(-rate * 1.6 * delta))
	if mode == Mode.FOLLOW and plane:
		pos = _clamp_to_world(pos, plane.state.pos)
		pos = _avoid_walls(plane.get_global_transform_interpolated().origin + Vector3(0, 0.15, 0), pos)
	var offset := Vector3.ZERO
	if _shake > 0.001:
		offset = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake * 0.35
		_shake = maxf(0.0, _shake - delta * 1.6)
	global_position = pos + offset
	if global_position.distance_to(_look) > 0.01:
		look_at(_look, Vector3.UP)
	rotate_object_local(Vector3(0, 0, 1), -cam_roll)
	fov = lerpf(fov, target_fov, 1.0 - exp(-3.0 * delta)) if not snap else target_fov


## Pulls the camera in front of any wall between the subject and the desired position.
func _avoid_walls(focus: Vector3, desired: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	if space == null:
		return desired
	var q := PhysicsRayQueryParameters3D.create(focus, desired, 1)
	var hit := space.intersect_ray(q)
	# Look through thin or leafy things (trees, posts, fences); only walls block the view.
	var tries := 0
	while not hit.is_empty() and tries < 4:
		var col: Object = hit.get("collider")
		var kind: String = col.get_meta("kind", "wall") if col else "wall"
		if kind in ["tree", "post", "fence", "desk", "furniture", "lamp", "greenhouse", "banister"]:
			var ex := q.exclude
			ex.append(hit.rid)
			q.exclude = ex
			hit = space.intersect_ray(q)
			tries += 1
		else:
			break
	if hit.is_empty():
		return desired
	var back := (focus - desired).normalized()
	return hit.position + back * 0.35 + hit.normal * 0.2


## Keeps the camera above ground/water (0.5 m) except when following the plane under the arch.
func _clamp_to_world(p: Vector3, subject: Vector3) -> Vector3:
	var under_arch := absf(subject.z - Terrain.RIVER_Z) < 8.5 and subject.y < 1.2 and absf(subject.x) < 14.0
	var ground := Terrain.surface_height(p.x, p.z)
	if under_arch:
		p.y = maxf(p.y, Terrain.WATER_Y + 0.3)
		if absf(p.x) < 6.5 and absf(p.z - Terrain.RIVER_Z) < 8.5:
			var t := (p.z - Terrain.RIVER_Z) / 8.5
			var ceiling := -2.6 + 3.15 * sqrt(maxf(0.0, 1.0 - t * t)) - 0.3
			p.y = minf(p.y, maxf(ceiling, Terrain.WATER_Y + 0.3))
	else:
		p.y = maxf(p.y, ground + 0.5)
	return p
