class_name PlaneTrail
extends Node3D
## Wingtip ribbons and particles behind a paper plane, in the cosmetic trail styles
## (white, rainbow, gold, confetti, comet). Used by the flying plane and the menu plane.
## Samples the source's wingtips by distance, so the ribbons stay smooth at any frame rate, and
## lets old samples fade out over the style's lifetime (the trail drifts away when the plane stops).

## The node whose transform carries the plane (its wingtips are in its local space).
var source: Node3D
## While true, new samples are added and particles emitted.
var active := false
var style := "white"

const MIN_STEP := 0.16
const MAX_POINTS := 90

var _pts: Array = []  # Each: [left, right, center, time, distance]
var _dist := 0.0
var _mesh: ImmediateMesh
var _node: MeshInstance3D
var _core_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _fx: GPUParticles3D
var _fx2: GPUParticles3D


func _ready() -> void:
	top_level = true
	_mesh = ImmediateMesh.new()
	_node = MeshInstance3D.new()
	_node.name = "Ribbons"
	_node.mesh = _mesh
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_node.extra_cull_margin = 16384.0
	add_child(_node)
	# Soft edges across the ribbon width: transparent at both sides, solid in the middle.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 0.65, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var edge := GradientTexture1D.new()
	edge.gradient = g
	edge.width = 64
	_core_mat = StandardMaterial3D.new()
	_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_core_mat.vertex_color_use_as_albedo = true
	_core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_core_mat.albedo_texture = edge
	_core_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_glow_mat = _core_mat.duplicate()
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_fx = _make_fx("TrailFX")
	_fx2 = _make_fx("TrailFX2")
	set_style(style)


func _make_fx(fx_name: String) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = fx_name
	p.local_coords = false
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(p)
	return p


func clear() -> void:
	_pts.clear()
	_dist = 0.0
	_mesh.clear_surfaces()
	for p in [_fx, _fx2]:
		p.restart()
		p.emitting = false


# --- Styles -------------------------------------------------------------------------------------

## How long ribbon samples last (seconds), the ribbon half-width at the wingtip (m), and the
## strength of the soft glow around it.
func _lifetime() -> float:
	match style:
		"rainbow": return 1.3
		"comet": return 0.9
		"gold": return 1.0
		"confetti": return 0.9
	return 0.75


func _width() -> float:
	match style:
		"rainbow": return 0.055
		"comet": return 0.06
		"gold": return 0.04
		"confetti": return 0.04
	return 0.03


func _glow() -> float:
	match style:
		"rainbow": return 0.5
		"comet": return 0.6
		"gold": return 0.55
		"confetti": return 0.25
	return 0.18


## Ribbon colour at a sample: u is 0 at the tail, 1 at the wingtip; d is the distance flown.
func _color(u: float, d: float, now: float, side: int) -> Color:
	match style:
		"rainbow":
			var c := Color.from_hsv(fposmod(d * 0.16 - now * 0.35 + side * 0.08, 1.0), 0.72, 1.0)
			return Color(c, 0.85)
		"gold":
			var sh := 0.85 + 0.15 * sin(d * 3.0 - now * 6.0)
			return Color(1.0 * sh, 0.74 * sh, 0.22, 0.85)
		"confetti":
			var cols := [Color("#e8546a"), Color("#f2c14e"), Color("#6fb4e8"), Color("#7fd08c"), Color("#c38be8")]
			return Color(cols[int(floor(d * 1.6)) % cols.size()], 0.75)
		"comet":
			return Color(Color("#ffb36b").lerp(Color("#bff4ff"), u), 0.95)
	return Color(1, 1, 1, 0.6)


func set_style(s: String) -> void:
	style = s
	if _fx == null:
		return
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.3, 1)
	pm.spread = 30.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.32, 0.03, 0.05)
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0.15))
	var shrink_t := CurveTexture.new()
	shrink_t.curve = shrink
	pm.scale_curve = shrink_t
	var q := QuadMesh.new()
	_fx2.visible = false
	match style:
		"rainbow":
			# Twinkling rainbow sparkles drifting down behind the plane.
			_fx.amount = 40
			_fx.lifetime = 1.1
			pm.initial_velocity_min = 0.2
			pm.initial_velocity_max = 0.8
			pm.gravity = Vector3(0, -0.6, 0)
			pm.scale_min = 0.6
			pm.scale_max = 1.3
			pm.color_initial_ramp = _rainbow_ramp()
			pm.color_ramp = _alpha_ramp()
			q.size = Vector2(0.16, 0.16)
			q.material = _additive_particles("star_glint")
			# And a few soft rainbow puffs off the tail.
			var pm2 := pm.duplicate() as ParticleProcessMaterial
			pm2.emission_box_extents = Vector3(0.08, 0.03, 0.05)
			pm2.gravity = Vector3(0, 0.15, 0)
			pm2.initial_velocity_max = 0.3
			pm2.scale_min = 1.0
			pm2.scale_max = 1.8
			_fx2.amount = 16
			_fx2.lifetime = 0.9
			_fx2.process_material = pm2
			var q2 := QuadMesh.new()
			q2.size = Vector2(0.28, 0.28)
			q2.material = _additive_particles("soft_dot", 0.55)
			_fx2.draw_pass_1 = q2
			_fx2.visible = true
		"gold":
			_fx.amount = 36
			_fx.lifetime = 1.0
			pm.initial_velocity_min = 0.3
			pm.initial_velocity_max = 1.0
			pm.gravity = Vector3(0, -0.4, 0)
			pm.scale_min = 0.5
			pm.scale_max = 1.2
			pm.color_ramp = _fade_ramp(Color(1.0, 0.86, 0.42))
			q.size = Vector2(0.17, 0.17)
			q.material = _additive_particles("star_glint")
		"confetti":
			_fx.amount = 44
			_fx.lifetime = 1.4
			pm.initial_velocity_min = 0.5
			pm.initial_velocity_max = 1.6
			pm.gravity = Vector3(0, -2.4, 0)
			pm.angular_velocity_min = -540.0
			pm.angular_velocity_max = 540.0
			pm.angle_max = 360.0
			pm.scale_curve = null
			pm.color_initial_ramp = _confetti_ramp()
			q.size = Vector2(0.07, 0.045)
			var cm := StandardMaterial3D.new()
			cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			cm.vertex_color_use_as_albedo = true
			cm.vertex_color_is_srgb = true
			cm.cull_mode = BaseMaterial3D.CULL_DISABLED
			cm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			q.material = cm
		"comet":
			_fx.amount = 48
			_fx.lifetime = 0.55
			pm.spread = 12.0
			pm.emission_box_extents = Vector3(0.1, 0.03, 0.05)
			pm.initial_velocity_min = 0.2
			pm.initial_velocity_max = 0.6
			pm.gravity = Vector3.ZERO
			pm.scale_min = 0.9
			pm.scale_max = 1.5
			var g2 := Gradient.new()
			g2.set_color(0, Color(0.7, 0.97, 1.0, 0.95))
			g2.set_color(1, Color(1.0, 0.5, 0.3, 0.0))
			var gt2 := GradientTexture1D.new()
			gt2.gradient = g2
			pm.color_ramp = gt2
			q.size = Vector2(0.34, 0.34)
			q.material = _additive_particles("soft_dot")
		_:
			# Classic white: faint wisps of air off the wingtips.
			_fx.amount = 14
			_fx.lifetime = 0.7
			pm.initial_velocity_min = 0.1
			pm.initial_velocity_max = 0.4
			pm.gravity = Vector3.ZERO
			pm.scale_min = 0.8
			pm.scale_max = 1.4
			pm.color_ramp = _fade_ramp(Color(1, 1, 1, 0.35))
			q.size = Vector2(0.12, 0.12)
			q.material = _additive_particles("soft_dot", 0.6)
	_fx.process_material = pm
	_fx.draw_pass_1 = q
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD


func _additive_particles(tex: String, strength := 1.0) -> Material:
	var m := Mats.additive(Color(strength, strength, strength), TexGen.get_tex(tex), true)
	if m is StandardMaterial3D:
		(m as StandardMaterial3D).vertex_color_use_as_albedo = true
		(m as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return m


func _fade_ramp(c: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(c, c.a))
	g.set_color(1, Color(c, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	return gt


func _alpha_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	return gt


func _rainbow_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in 7:
		offs.append(i / 6.0)
		cols.append(Color.from_hsv(i / 6.0 * 0.85, 0.6, 1.0))
	g.offsets = offs
	g.colors = cols
	var gt := GradientTexture1D.new()
	gt.gradient = g
	return gt


func _confetti_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray([Color("#e8546a"), Color("#f2c14e"), Color("#6fb4e8"), Color("#7fd08c"), Color("#c38be8")])
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var gt := GradientTexture1D.new()
	gt.gradient = g
	return gt


# --- Per frame ----------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	global_transform = Transform3D.IDENTITY
	var now := Time.get_ticks_msec() * 0.001
	if source and active and source.is_visible_in_tree():
		var xf := source.get_global_transform_interpolated()
		var l := xf * PaperPlaneMesh.TIP_LEFT
		var r := xf * PaperPlaneMesh.TIP_RIGHT
		var c := xf * Vector3(0, 0.02, 0.42)
		var head := [l, r, c, now, _dist]
		if _pts.is_empty():
			_pts.append(head)
		else:
			var last: Array = _pts[_pts.size() - 1]
			var step: float = (c - last[2]).length()
			if step > 6.0:
				# Teleported (a new showreel clip or a restart): start a fresh trail.
				_pts.clear()
				_dist = 0.0
				head[4] = 0.0
				_pts.append(head)
			else:
				_dist += step
				head[4] = _dist
				if _pts.size() >= 2 and (c - (_pts[_pts.size() - 2][2] as Vector3)).length() < MIN_STEP:
					# Too close to the previous sample: just move the head.
					_pts[_pts.size() - 1] = head
				else:
					_pts.append(head)
		while _pts.size() > MAX_POINTS:
			_pts.remove_at(0)
		_fx.global_transform = Transform3D(xf.basis, c)
		_fx2.global_transform = _fx.global_transform
	for p in [_fx, _fx2]:
		var want: bool = active and p.visible and source != null and source.is_visible_in_tree()
		if p.emitting != want:
			p.emitting = want
	var life := _lifetime()
	while not _pts.is_empty() and now - float(_pts[0][3]) > life:
		_pts.remove_at(0)
	_draw_ribbons(now, life)


func _draw_ribbons(now: float, life: float) -> void:
	_mesh.clear_surfaces()
	var n := _pts.size()
	if n < 2:
		return
	var cam := get_viewport().get_camera_3d()
	var cam_pos := cam.global_position if cam else Vector3.ZERO
	var w := _width()
	var glow := _glow()
	var ribbons := [[0, 1.0, 0], [1, 1.0, 1]]
	if style == "rainbow":
		# A soft rainbow band from the tail between the two wingtip ribbons.
		ribbons.append([2, 2.2, 2])
	for rb in ribbons:
		var idx: int = rb[0]
		var wmul: float = rb[1]
		for pass_i in 2:
			var is_glow := pass_i == 0
			if is_glow and glow <= 0.0:
				continue
			_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _glow_mat if is_glow else _core_mat)
			for i in n:
				var pt: Array = _pts[i]
				var p: Vector3 = pt[idx]
				var u := float(i) / float(n - 1)
				var age := clampf((now - float(pt[3])) / life, 0.0, 1.0)
				var prev: Vector3 = _pts[maxi(i - 1, 0)][idx]
				var next: Vector3 = _pts[mini(i + 1, n - 1)][idx]
				var dir := next - prev
				var to_cam := (cam_pos - p).normalized()
				var side := dir.cross(to_cam)
				if side.length() < 0.0001:
					side = Vector3.UP
				side = side.normalized()
				var taper := (0.2 + 0.8 * u) * (1.0 - age * 0.6)
				var half := w * wmul * taper * (2.6 if is_glow else 1.0)
				var c := _color(u, float(pt[4]), now, rb[2])
				var a := c.a * (1.0 - age) * (1.0 - age) * smoothstep(0.0, 0.08, u)
				a *= smoothstep(0.8, 2.6, p.distance_to(cam_pos))
				if idx == 2:
					a *= 0.35
				if is_glow:
					a *= glow * 0.45
				var col := Color(c.r, c.g, c.b, a)
				_mesh.surface_set_color(col)
				_mesh.surface_set_uv(Vector2(0, u))
				_mesh.surface_add_vertex(p - side * half)
				_mesh.surface_set_color(col)
				_mesh.surface_set_uv(Vector2(1, u))
				_mesh.surface_add_vertex(p + side * half)
			_mesh.surface_end()
