class_name StarPickup
extends Node3D
## A spinning gold star. Collected within PICKUP_RADIUS of the plane.

const PICKUP_RADIUS := 1.3

@export var bonus := false

var collected := false
var _model: MeshInstance3D
var _glow: MeshInstance3D
var _burst: GPUParticles3D
var _t := 0.0

static var _star_mesh: ArrayMesh
static var _star_mat: StandardMaterial3D
static var _night := false


## Silver-white stars at dusk, gold otherwise. Call before stars are created.
static func set_night(on: bool) -> void:
	_night = on
	star_mesh()
	_star_mat.albedo_color = Color("#e8eef8") if on else Color("#f6c445")
	_star_mat.emission = Color("#dfe8ff") if on else Color("#ffcf5a")
	_star_mat.emission_energy_multiplier = 1.4 if on else 0.9


static func star_mesh() -> ArrayMesh:
	if _star_mesh:
		return _star_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer := 0.5
	var inner := 0.22
	var depth := 0.16
	var pts := []
	for i in 10:
		var a := PI * 0.5 + i * PI / 5.0
		var r := outer if i % 2 == 0 else inner
		pts.append(Vector3(cos(a) * r, sin(a) * r, 0))
	var front := Vector3(0, 0, depth)
	var back := Vector3(0, 0, -depth)
	for i in 10:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % 10]
		_tri(st, front, a, b)
		_tri(st, back, b, a)
	st.generate_normals()
	_star_mesh = st.commit()
	_star_mat = StandardMaterial3D.new()
	_star_mat.albedo_color = Color("#f6c445")
	_star_mat.metallic = 0.6
	_star_mat.roughness = 0.3
	_star_mat.emission_enabled = true
	_star_mat.emission = Color("#ffcf5a")
	_star_mat.emission_energy_multiplier = 0.9
	_star_mesh.surface_set_material(0, _star_mat)
	return _star_mesh


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Counter-clockwise input; Godot front faces are clockwise.
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)


func _ready() -> void:
	if has_node("Model"):
		_model = get_node("Model")
	else:
		_model = MeshInstance3D.new()
		_model.name = "Model"
		_model.mesh = star_mesh()
		add_child(_model)
	_model.scale = Vector3.ONE * (1.25 if bonus else 1.0)
	_glow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 2.2)
	q.material = Mats.additive(Color(0.8, 0.86, 1.0, 0.5) if _night else Color(1, 0.82, 0.4, 0.55), TexGen.get_tex("soft_dot"), true)
	_glow.mesh = q
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	_burst = GPUParticles3D.new()
	_burst.one_shot = true
	_burst.emitting = false
	_burst.amount = 24
	_burst.lifetime = 0.9
	_burst.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3.ZERO
	pm.damping_min = 3.0
	pm.damping_max = 4.0
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.94, 1.0, 1) if _night else Color(1, 0.9, 0.5, 1))
	g.set_color(1, Color(0.8, 0.86, 1.0, 0) if _night else Color(1, 0.8, 0.3, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_burst.process_material = pm
	var bq := QuadMesh.new()
	bq.size = Vector2(0.25, 0.25)
	bq.material = Mats.additive(Color(0.9, 0.94, 1.0) if _night else Color(1, 0.9, 0.6), TexGen.get_tex("star_glint"), true)
	_burst.draw_pass_1 = bq
	add_child(_burst)
	_t = position.z * 0.37


func _process(delta: float) -> void:
	if collected:
		return
	_t += delta
	_model.rotation.y = _t * 2.2
	_model.position.y = sin(_t * 2.4) * 0.12


func reset() -> void:
	collected = false
	_model.visible = true
	_model.scale = Vector3.ONE * (1.25 if bonus else 1.0)
	_glow.visible = true


func collect() -> void:
	if collected:
		return
	collected = true
	_burst.restart()
	_glow.visible = false
	var tw := create_tween()
	tw.tween_property(_model, "scale", Vector3.ONE * 1.8, 0.08)
	tw.tween_property(_model, "scale", Vector3.ZERO, 0.18)
	tw.tween_callback(func(): _model.visible = false)
