class_name Thermal
extends Node3D
## A column of rising air. Shown as a faint golden shimmer with rising sparkles, or as
## grey puffs for chimney smoke. Node position = (x, ground, z).

@export var radius := 8.0
@export var strength := 3.4
@export var top := 15.0
## "golden", "smoke" or "lantern" (Lantern Night: warm air carrying sky lanterns)
@export var style := "golden"
## Height where the smoke starts (chimney top).
@export var source_height := 0.0
## Visual column is cut off here (e.g. a classroom ceiling). Lift is unaffected.
@export var ceiling := INF


## Vertical air speed contributed at a world position (m/s).
func lift_at(p: Vector3) -> float:
	var dx := p.x - global_position.x
	var dz := p.z - global_position.z
	var d2 := dx * dx + dz * dz
	var r2 := radius * radius
	if d2 >= r2:
		return 0.0
	return strength * (1.0 - d2 / r2) * smoothstep(top + 2.5, top - 2.5, p.y)


func _ready() -> void:
	var base := global_position.y
	var h := maxf(2.0, minf(top + 2.0, ceiling) - base)
	var col := MeshInstance3D.new()
	col.name = "Shimmer"
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.85
	cm.bottom_radius = radius * 0.6
	cm.height = h
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 24
	cm.rings = 1
	col.mesh = cm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/thermal.gdshader")
	sm.set_shader_parameter("height", h)
	sm.set_shader_parameter("intensity", 0.15 if style == "golden" else 0.05)
	sm.set_shader_parameter("tint", UIKit.LIFT)
	if style == "smoke":
		sm.set_shader_parameter("tint", Color(0.9, 0.85, 0.8))
	elif style == "lantern":
		sm.set_shader_parameter("tint", Color(1.0, 0.6, 0.3))
		sm.set_shader_parameter("intensity", 0.13)
	col.material_override = sm
	col.position = Vector3(0, h * 0.5, 0)
	col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(col)

	var p := GPUParticles3D.new()
	p.name = "Rising"
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 8.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-radius - 4, -2, -radius - 4), Vector3(radius * 2 + 8, h + 8, radius * 2 + 8))
	var q := QuadMesh.new()
	if style == "smoke":
		p.amount = 22 if Settings.is_mobile else 40
		p.lifetime = 6.0
		p.preprocess = 6.0
		p.position = Vector3(0, source_height - base, 0)
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.3
		pm.initial_velocity_min = 1.0
		pm.initial_velocity_max = 1.5
		pm.gravity = Vector3(0.25, 0.15, 0)
		pm.damping_min = 0.1
		pm.damping_max = 0.2
		pm.scale_min = 1.0
		pm.scale_max = 1.6
		var sc := Curve.new()
		sc.add_point(Vector2(0, 0.4))
		sc.add_point(Vector2(1, 3.2))
		var sct := CurveTexture.new()
		sct.curve = sc
		pm.scale_curve = sct
		var g := Gradient.new()
		g.set_color(0, Color(0.75, 0.73, 0.72, 0.0))
		g.add_point(0.12, Color(0.78, 0.76, 0.75, 0.55))
		g.set_color(g.get_point_count() - 1, Color(0.85, 0.83, 0.82, 0.0))
		var gt := GradientTexture1D.new()
		gt.gradient = g
		pm.color_ramp = gt
		pm.angle_max = 360.0
		q.size = Vector2(1.2, 1.2)
		var mat := Mats.soft_alpha(Color(1, 1, 1, 1), TexGen.get_tex("cloud"), true, false)
		q.material = mat
	else:
		p.amount = 36 if Settings.is_mobile else 72
		p.lifetime = clampf(h / 2.2, 2.0, 9.0)
		p.preprocess = p.lifetime
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = radius * 0.7
		pm.emission_ring_inner_radius = radius * 0.1
		pm.emission_ring_height = 0.5
		pm.initial_velocity_min = 1.8
		pm.initial_velocity_max = 2.6
		pm.gravity = Vector3.ZERO
		pm.scale_min = 0.7
		pm.scale_max = 1.4
		var g2 := Gradient.new()
		var spark := Color(1, 0.86, 0.48) if style == "lantern" else Color(0.62, 1.0, 0.76)
		g2.set_color(0, Color(spark, 0.0))
		g2.add_point(0.15, Color(spark, 1.0))
		g2.add_point(0.75, Color(spark, 0.8))
		g2.set_color(g2.get_point_count() - 1, Color(spark, 0.0))
		var gt2 := GradientTexture1D.new()
		gt2.gradient = g2
		pm.color_ramp = gt2
		q.size = Vector2(0.24, 0.24)
		var glint := Color(1, 0.7, 0.4) if style == "lantern" else Color(0.72, 1.0, 0.82)
		q.material = Mats.additive(glint, TexGen.get_tex("star_glint"), true)
	p.process_material = pm
	p.draw_pass_1 = q
	add_child(p)
	if style == "lantern":
		_build_sky_lanterns(h)
	else:
		_build_swirl(h)


## Glowing paper sky lanterns drifting up the column.
func _build_sky_lanterns(h: float) -> void:
	var p := GPUParticles3D.new()
	p.name = "SkyLanterns"
	p.amount = 5 if Settings.is_mobile else 9
	p.lifetime = clampf(h / 1.1, 4.0, 16.0)
	p.preprocess = p.lifetime
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-radius - 4, -2, -radius - 4), Vector3(radius * 2 + 8, h + 8, radius * 2 + 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = radius * 0.55
	pm.emission_ring_inner_radius = 0.0
	pm.emission_ring_height = 0.2
	pm.direction = Vector3.UP
	pm.spread = 6.0
	pm.initial_velocity_min = 0.9
	pm.initial_velocity_max = 1.3
	pm.gravity = Vector3(0.12, 0.0, 0.0)
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.0))
	sc.add_point(Vector2(0.08, 1.0))
	sc.add_point(Vector2(0.85, 1.0))
	sc.add_point(Vector2(1.0, 0.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	p.process_material = pm
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.16
	cm.height = 0.3
	cm.radial_segments = 8
	cm.rings = 1
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.7, 0.85, 0.3)
	cm.material = m
	p.draw_pass_1 = cm
	add_child(p)


# --- Swirl of leaves spiralling up the column ---------------------------------------------

var _swirl: MultiMeshInstance3D
var _leaves: Array = []  # Each: [angle, height, radius_frac, climb_speed, spin_speed, spin]
var _height := 1.0


func _build_swirl(h: float) -> void:
	_height = h
	var count := 10 if Settings.is_mobile else 18
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(global_position.x * 31.0 + global_position.z * 7.0)) + 1
	var q := QuadMesh.new()
	q.size = Vector2(0.24, 0.3)
	var lm := StandardMaterial3D.new()
	lm.albedo_texture = TexGen.get_tex("leaf")
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	lm.alpha_scissor_threshold = 0.5
	lm.vertex_color_use_as_albedo = true
	lm.vertex_color_is_srgb = true
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	lm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	lm.distance_fade_min_distance = 1.5
	lm.distance_fade_max_distance = 4.0
	q.material = lm
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = q
	mm.instance_count = count
	var cols := ["#7fc98f", "#a6dba0", "#5fb37a", "#c6e8a8", "#8fd3a8", "#e8873a"]
	for i in count:
		_leaves.append([rng.randf() * TAU, rng.randf() * h, rng.randf_range(0.35, 0.8),
			rng.randf_range(1.4, 2.4), rng.randf_range(-6.0, 6.0), rng.randf() * TAU])
		mm.set_instance_color(i, Color(cols[i % cols.size()]))
	_swirl = MultiMeshInstance3D.new()
	_swirl.name = "LeafSwirl"
	_swirl.multimesh = mm
	_swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_swirl.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_swirl.visibility_range_end = 160.0
	_swirl.custom_aabb = AABB(Vector3(-radius, 0, -radius), Vector3(radius * 2.0, h + 2.0, radius * 2.0))
	add_child(_swirl)


func _process(delta: float) -> void:
	if _swirl == null or not _swirl.is_visible_in_tree():
		return
	var mm := _swirl.multimesh
	for i in _leaves.size():
		var l: Array = _leaves[i]
		var r: float = radius * l[2] * (0.55 + 0.45 * l[1] / _height)
		l[0] += delta * l[3] * 1.6 / maxf(r, 1.0)
		l[1] += delta * l[3]
		l[5] += delta * l[4]
		if l[1] > _height:
			l[1] = 0.0
		var a: float = l[0]
		var pos := Vector3(cos(a) * r, l[1], sin(a) * r)
		# Leaves fade in at the bottom and out near the top by shrinking.
		var k := clampf(l[1] / 1.5, 0.0, 1.0) * clampf((_height - l[1]) / 2.0, 0.0, 1.0)
		var basis := Basis(Vector3.UP, -a).rotated(Vector3(cos(a), 0, sin(a)), l[5]).scaled(Vector3.ONE * maxf(k, 0.001))
		mm.set_instance_transform(i, Transform3D(basis, pos))
