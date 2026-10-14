class_name PaperPlaneMesh
extends RefCounted
## Low-poly folded notebook-paper dart: a nose, two wings and a keel fold. Forward is -Z.
## Flat shaded, double sided, mapped with the generated notebook-paper texture.

const SCALE := 1.35
const LENGTH := 0.78 * SCALE
const SPAN := 0.64 * SCALE
## Wingtip positions in plane space (used for trails).
const TIP_LEFT := Vector3(-0.32 * SCALE, 0.05 * SCALE, 0.37 * SCALE)
const TIP_RIGHT := Vector3(0.32 * SCALE, 0.05 * SCALE, 0.37 * SCALE)

static var _mesh: ArrayMesh


static func get_mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nose := Vector3(0, 0.0, -0.41)
	var tail_c := Vector3(0, 0.0, 0.37)
	var tail_keel := Vector3(0, -0.1, 0.37)
	var keel_front := Vector3(0, -0.015, -0.3)
	var tip_l := TIP_LEFT / SCALE
	var tip_r := TIP_RIGHT / SCALE
	var root_l := Vector3(-0.035, 0.0, 0.37)
	var root_r := Vector3(0.035, 0.0, 0.37)
	var mid_l := Vector3(-0.12, 0.015, 0.05)
	var mid_r := Vector3(0.12, 0.015, 0.05)
	# Wings (each split into an inner and outer facet for a folded look).
	_tri(st, nose, mid_l, root_l, Color(1, 1, 1))
	_tri(st, nose, tip_l, mid_l, Color(0.95, 0.95, 0.94))
	_tri(st, mid_l, tip_l, root_l, Color(0.97, 0.97, 0.96))
	_tri(st, nose, root_r, mid_r, Color(1, 1, 1))
	_tri(st, nose, mid_r, tip_r, Color(0.95, 0.95, 0.94))
	_tri(st, mid_r, root_r, tip_r, Color(0.97, 0.97, 0.96))
	# Keel fold (the two folded halves under the body).
	_tri(st, nose, root_l, tail_keel, Color(0.86, 0.85, 0.82))
	_tri(st, nose, tail_keel, root_r, Color(0.88, 0.87, 0.84))
	_tri(st, keel_front, tail_keel, tail_c, Color(0.84, 0.83, 0.8))
	# Small upturned winglets.
	_tri(st, tip_l, tip_l + Vector3(0.0, 0.07, -0.02), tip_l + Vector3(0.03, 0.0, -0.14), Color(0.93, 0.93, 0.92))
	_tri(st, tip_r, tip_r + Vector3(-0.03, 0.0, -0.14), tip_r + Vector3(0.0, 0.07, -0.02), Color(0.93, 0.93, 0.92))
	_mesh = st.commit()
	# Scale the unit dart up to its in-game size.
	var arrays := _mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] *= SCALE
	arrays[Mesh.ARRAY_VERTEX] = verts
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh.surface_set_material(0, Mats.get_mat("paper_plane"))
	return _mesh


static func _uv(p: Vector3) -> Vector2:
	return Vector2(p.x / (SPAN / SCALE) + 0.5, (p.z + 0.41) / (LENGTH / SCALE)) * Vector2(0.92, 0.92) + Vector2(0.04, 0.04)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	for p in [a, c, b]:
		st.set_color(col)
		st.set_normal(n)
		st.set_uv(_uv(p))
		st.add_vertex(p)
