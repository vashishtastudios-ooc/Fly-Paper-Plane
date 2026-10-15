class_name Pet
extends Prop
## Base for the smooth, rounded pets that sit on landing spots (Biscuit the dog, the picnic
## cat). Pets are part of the landing spot (pad layer, kind "buddy"): when the paper plane
## touches one, it stops right there and the pet reacts (react()). A landing elsewhere on the
## spot leaves the pet alone. Origin = the ground under the pet; it faces local +Z.

## How close the plane must come to rest for it to count as touching the pet.
@export var touch_radius := 0.6

var _t := 0.0
var _happy := 0.0
var _sparkles: GPUParticles3D


func _after_build() -> void:
	add_to_group("pets")
	_sparkles = GPUParticles3D.new()
	_sparkles.name = "Sparkles"
	_sparkles.one_shot = true
	_sparkles.emitting = false
	_sparkles.amount = 14
	_sparkles.lifetime = 1.3
	_sparkles.explosiveness = 0.85
	_sparkles.position = Vector3(0, _head_height(), 0)
	_sparkles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 40.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0, 0.25, 0)
	pm.damping_min = 0.6
	pm.damping_max = 1.0
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	g.colors = PackedColorArray([Color(1, 0.55, 0.75, 0), Color(1, 0.55, 0.75, 1), Color(1, 0.7, 0.85, 0.8), Color(1, 0.8, 0.9, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_sparkles.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	var m := Mats.additive(Color.WHITE, TexGen.get_tex("star_glint"), true)
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	_sparkles.draw_pass_1 = q
	add_child(_sparkles)


## Height of the pet's head above its origin (where the sparkles start).
func _head_height() -> float:
	return 0.6


## The plane touched the pet: a happy reaction for a few seconds.
func react() -> void:
	_happy = 3.5
	if _sparkles:
		_sparkles.restart()
		_sparkles.emitting = true


## True when a plane resting at `p` is touching the pet.
func is_touching(p: Vector3) -> bool:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() < touch_radius


func _process(delta: float) -> void:
	_t += delta
	_happy = maxf(0.0, _happy - delta)
	_animate(clampf(_happy / 1.2, 0.0, 1.0))


## Override: idle and happy (h = 0..1) animation.
func _animate(_h: float) -> void:
	pass


func _build_colliders() -> void:
	var r := _collider_size()
	add_cylinder("buddy", Vector3(0, 0, 0.02), r.x, r.y, LAYER_PADS)


## Override: collider radius and height.
func _collider_size() -> Vector2:
	return Vector2(0.27, 0.92)


# --- Smooth parts ------------------------------------------------------------------------------

func _sphere(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, rot := Basis()) -> void:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 16
	m.rings = 10
	_part(st, m, Transform3D(rot * Basis.from_scale(r), c), col)


func _capsule(st: SurfaceTool, c: Vector3, radius: float, height: float, col: Color, rot := Basis()) -> void:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 12
	m.rings = 4
	_part(st, m, Transform3D(rot, c), col)


func _cone(st: SurfaceTool, base: Vector3, radius: float, height: float, col: Color, rot := Basis()) -> void:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 10
	m.rings = 1
	_part(st, m, Transform3D(rot, base) * Transform3D(Basis(), Vector3(0, height * 0.5, 0)), col)


## Appends a primitive mesh, transformed and coloured, to the surface (normals stay smooth).
func _part(st: SurfaceTool, mesh: PrimitiveMesh, xf: Transform3D, col: Color) -> void:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var nb := xf.basis.inverse().transposed()
	for i in idx:
		st.set_color(col)
		st.set_normal((nb * normals[i]).normalized())
		st.add_vertex(xf * verts[i])


func _mesh_node(st: SurfaceTool, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = Mats.get_mat("solid")
	return mi
