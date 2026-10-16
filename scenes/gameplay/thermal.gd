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
	sm.set_shader_parameter("radius", radius * 0.85)
	sm.set_shader_parameter("intensity", 0.11 if style == "golden" else 0.05)
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
		# Sparkles flowing up the column (fewer than they used to be, no leaves).
		p.amount = 24 if Settings.is_mobile else 44
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
		var gm := Mats.additive(glint, TexGen.get_tex("star_glint"), true)
		# Fade out right in front of the camera.
		gm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		gm.distance_fade_min_distance = 1.5
		gm.distance_fade_max_distance = 5.0
		q.material = gm
	p.process_material = pm
	p.draw_pass_1 = q
	add_child(p)
	if style == "lantern":
		_build_sky_lanterns(h)
	elif style == "golden":
		_build_ground_ring()


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


## A soft mint ring on the ground or water at the foot of the column, so it reads from above.
func _build_ground_ring() -> void:
	var ring := MeshInstance3D.new()
	ring.name = "GroundRing"
	var q := QuadMesh.new()
	q.size = Vector2(radius * 1.7, radius * 1.7)
	q.orientation = PlaneMesh.FACE_Y
	var m := Mats.additive(Color(0.55, 0.95, 0.72, 0.55), TexGen.get_tex("soft_ring"))
	m.vertex_color_use_as_albedo = false
	q.material = m
	ring.mesh = q
	var surface := Terrain.surface_height(global_position.x, global_position.z)
	ring.position = Vector3(0, surface - global_position.y + 0.06, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
