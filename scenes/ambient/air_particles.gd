extends Node3D
## Falling leaves and drifting golden light motes that follow the active camera.

var _leaves: GPUParticles3D
var _motes: GPUParticles3D


func _ready() -> void:
	_leaves = GPUParticles3D.new()
	_leaves.name = "Leaves"
	_leaves.amount = 40 if Settings.is_mobile else 90
	_leaves.lifetime = 9.0
	_leaves.preprocess = 9.0
	_leaves.local_coords = false
	_leaves.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(30, 8, 30)
	pm.direction = Vector3(1, -0.3, 0)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0.35, -0.6, 0.0)
	pm.angular_velocity_min = -180.0
	pm.angular_velocity_max = 180.0
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.turbulence_enabled = not Settings.is_mobile
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 6.0
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	var grad := Gradient.new()
	grad.set_color(0, Color("#e8873a"))
	grad.set_color(1, Color("#f2c14e"))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_initial_ramp = gt
	_leaves.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.2)
	var lm := StandardMaterial3D.new()
	lm.albedo_texture = TexGen.get_tex("leaf")
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	lm.alpha_scissor_threshold = 0.5
	lm.vertex_color_use_as_albedo = true
	lm.vertex_color_is_srgb = true
	lm.albedo_color = Color(1.0, 0.85, 0.7)
	lm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	lm.distance_fade_min_distance = 1.5
	lm.distance_fade_max_distance = 4.0
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	lm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	lm.billboard_keep_scale = true
	q.material = lm
	_leaves.draw_pass_1 = q
	_leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_leaves)

	_motes = GPUParticles3D.new()
	_motes.name = "Motes"
	_motes.amount = 50 if Settings.is_mobile else 120
	_motes.lifetime = 7.0
	_motes.preprocess = 7.0
	_motes.local_coords = false
	_motes.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	var mm := ParticleProcessMaterial.new()
	mm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mm.emission_box_extents = Vector3(18, 7, 18)
	mm.direction = Vector3(0, 1, 0)
	mm.spread = 180.0
	mm.initial_velocity_min = 0.05
	mm.initial_velocity_max = 0.25
	mm.gravity = Vector3(0.1, 0.05, 0)
	mm.scale_min = 0.5
	mm.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 0.85, 0.55, 0.0))
	fade.add_point(0.3, Color(1, 0.85, 0.55, 0.8))
	fade.add_point(0.7, Color(1, 0.85, 0.55, 0.8))
	fade.set_color(fade.get_point_count() - 1, Color(1, 0.85, 0.55, 0.0))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	mm.color_ramp = ft
	_motes.process_material = mm
	var mq := QuadMesh.new()
	mq.size = Vector2(0.08, 0.08)
	var mote_mat := Mats.additive(Color(1.0, 0.85, 0.55, 0.9), TexGen.get_tex("soft_dot"), true)
	mote_mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mote_mat.distance_fade_min_distance = 1.0
	mote_mat.distance_fade_max_distance = 3.0
	mq.material = mote_mat
	_motes.draw_pass_1 = mq
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_motes)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var p := cam.global_position
		_leaves.global_position = p + Vector3(0, 4, 0)
		_motes.global_position = p
