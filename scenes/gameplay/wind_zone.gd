class_name WindZone
extends Node3D
## A sea breeze: a round area where the wind pushes the plane sideways (it drifts with the wind
## and has to steer against it). Shown by long white streaks blowing through the area.
## Node position = (x, ground or water, z).

@export var radius := 18.0
## Wind direction (horizontal) and speed (m/s).
@export var direction := Vector3(0, 0, 1)
@export var strength := 2.5
## The wind blows up to this height above the node.
@export var top := 25.0


## Wind velocity (m/s) at a world position: full inside, fading over the outer 30%.
func wind_at(p: Vector3) -> Vector3:
	var d := Vector2(p.x - global_position.x, p.z - global_position.z).length()
	if d >= radius or p.y > global_position.y + top + 3.0:
		return Vector3.ZERO
	var k := 1.0 - smoothstep(radius * 0.7, radius, d)
	k *= 1.0 - smoothstep(global_position.y + top - 2.0, global_position.y + top + 3.0, p.y)
	return Vector3(direction.x, 0.0, direction.z).normalized() * strength * k


func _ready() -> void:
	var dir := Vector3(direction.x, 0.0, direction.z).normalized()
	var p := GPUParticles3D.new()
	p.name = "Streaks"
	p.amount = 18 if Settings.is_mobile else 36
	p.lifetime = 2.2
	p.preprocess = 2.2
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-radius - 10, -2, -radius - 10), Vector3(radius * 2 + 20, top + 6, radius * 2 + 20))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(radius * 0.75, top * 0.4, radius * 0.75)
	pm.direction = dir
	pm.spread = 4.0
	pm.initial_velocity_min = 7.0 + strength
	pm.initial_velocity_max = 10.0 + strength
	pm.gravity = Vector3.ZERO
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.add_point(0.25, Color(1, 1, 1, 0.75))
	g.add_point(0.75, Color(1, 1, 1, 0.6))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 2.4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1, 1, 1, 0.9)
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 1.0
	m.distance_fade_max_distance = 4.0
	q.material = m
	p.draw_pass_1 = q
	# Start upwind so the streaks blow across the whole area.
	p.position = Vector3(0, top * 0.45, 0) - dir * radius * 0.5
	add_child(p)
