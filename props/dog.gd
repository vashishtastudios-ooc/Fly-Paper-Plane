extends Prop
## Biscuit, a friendly sitting dog made of smooth rounded shapes. Origin = the ground under the
## dog; it faces local +Z. The tail wags gently all the time and happily when the paper plane
## lands next to it (call celebrate()). The dog is part of the landing spot (pad layer), so
## bumping into it counts as landing rather than a crash.

const FUR := Color("#d9a066")
const LIGHT := Color("#f6e2c2")
const DARK := Color("#8a5a32")
const BLACK := Color("#2a2522")

var _tail: Node3D
var _body: MeshInstance3D
var _t := 0.0
var _happy := 0.0


func _build(_b: MeshBuilder) -> void:
	# Smooth parts (primitive meshes) merged into one vertex-coloured mesh.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Seated rump and thighs.
	_sphere(st, Vector3(0, 0.24, -0.08), Vector3(0.24, 0.24, 0.27), FUR)
	for s in [-1.0, 1.0]:
		_sphere(st, Vector3(s * 0.16, 0.17, -0.0), Vector3(0.11, 0.16, 0.19), FUR)
		_sphere(st, Vector3(s * 0.17, 0.035, 0.08), Vector3(0.065, 0.04, 0.1), LIGHT)
	# Upright chest and a pale bib.
	_sphere(st, Vector3(0, 0.47, 0.05), Vector3(0.17, 0.27, 0.17), FUR, Basis(Vector3.RIGHT, 0.22))
	_sphere(st, Vector3(0, 0.47, 0.15), Vector3(0.11, 0.19, 0.08), LIGHT, Basis(Vector3.RIGHT, 0.22))
	# Front legs and paws.
	for s in [-1.0, 1.0]:
		_capsule(st, Vector3(s * 0.085, 0.22, 0.16), 0.048, 0.42, FUR)
		_sphere(st, Vector3(s * 0.085, 0.032, 0.2), Vector3(0.058, 0.036, 0.075), LIGHT)
	# Neck, head, muzzle, nose, tongue, eyes and floppy ears.
	_sphere(st, Vector3(0, 0.66, 0.09), Vector3(0.11, 0.13, 0.11), FUR)
	_sphere(st, Vector3(0, 0.79, 0.12), Vector3(0.145, 0.135, 0.15), FUR)
	_sphere(st, Vector3(0, 0.745, 0.245), Vector3(0.075, 0.062, 0.1), LIGHT)
	_sphere(st, Vector3(0, 0.775, 0.34), Vector3(0.03, 0.024, 0.02), BLACK)
	_sphere(st, Vector3(0, 0.705, 0.29), Vector3(0.03, 0.012, 0.04), Color("#e8788a"))
	for s in [-1.0, 1.0]:
		_sphere(st, Vector3(s * 0.062, 0.825, 0.245), Vector3(0.024, 0.026, 0.016), BLACK)
		_sphere(st, Vector3(s * 0.058, 0.833, 0.258), Vector3(0.007, 0.007, 0.004), Color.WHITE)
		_sphere(st, Vector3(s * 0.135, 0.765, 0.1), Vector3(0.035, 0.12, 0.075), DARK, Basis(Vector3.BACK, s * 0.28))
	# Red collar with a gold tag.
	var collar := TorusMesh.new()
	collar.inner_radius = 0.1
	collar.outer_radius = 0.125
	collar.rings = 20
	collar.ring_segments = 8
	_part(st, collar, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, 0.655, 0.095)), Color("#c8423b"))
	_sphere(st, Vector3(0, 0.59, 0.2), Vector3(0.025, 0.025, 0.012), Color("#e0b24a"))
	st.generate_tangents()
	_body = MeshInstance3D.new()
	_body.name = "Model"
	_body.mesh = st.commit()
	_body.material_override = Mats.get_mat("solid")
	add_child(_body)
	# The tail: a curve of shrinking balls on a pivot at the base, so it can wag.
	_tail = Node3D.new()
	_tail.name = "Tail"
	_tail.position = Vector3(0, 0.12, -0.32)
	var ts := SurfaceTool.new()
	ts.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var f := float(i) / 6.0
		var p := Vector3(0, 0.03 + f * 0.24 + sin(f * PI) * 0.02, -0.04 - sin(f * PI * 0.8) * 0.14)
		var r := lerpf(0.05, 0.028, f)
		_sphere(ts, p, Vector3(r, r, r), LIGHT if i == 6 else FUR)
	var tail_mesh := MeshInstance3D.new()
	tail_mesh.mesh = ts.commit()
	tail_mesh.material_override = Mats.get_mat("solid")
	_tail.add_child(tail_mesh)
	add_child(_tail)


func _build_colliders() -> void:
	# On the landing-pad layer: touching Biscuit means you've arrived.
	add_cylinder("buddy", Vector3(0, 0.0, 0.02), 0.27, 0.92, LAYER_PADS)


func _after_build() -> void:
	add_to_group("landing_buddy")


func _casts_shadow() -> bool:
	return true


## Big happy wag (and a little bounce) for a few seconds.
func celebrate() -> void:
	_happy = 3.5


func _process(delta: float) -> void:
	_t += delta
	_happy = maxf(0.0, _happy - delta)
	var h := clampf(_happy / 1.2, 0.0, 1.0)
	var amp := lerpf(0.22, 0.8, h)
	var speed := lerpf(4.0, 17.0, h)
	if _tail:
		_tail.rotation = Vector3(0.15 + 0.15 * h, sin(_t * speed) * amp, sin(_t * speed) * amp * 0.25)
	if _body:
		# Breathing, and a happy little bounce while celebrating.
		_body.scale = Vector3(1, 1.0 + 0.012 * sin(_t * 2.4), 1)
		_body.position.y = absf(sin(_t * 8.0)) * 0.03 * h
		_tail.position.y = 0.12 + _body.position.y


# --- Mesh helpers -----------------------------------------------------------------------------

func _sphere(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, rot := Basis()) -> void:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 16
	m.rings = 10
	_part(st, m, Transform3D(rot * Basis.from_scale(r), c), col)


func _capsule(st: SurfaceTool, c: Vector3, radius: float, height: float, col: Color) -> void:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 12
	m.rings = 4
	_part(st, m, Transform3D(Basis(), c), col)


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
