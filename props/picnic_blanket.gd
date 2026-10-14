extends Prop
## Red striped picnic blanket with a basket. Origin = ground under the blanket center.

@export var top_height := 0.13
@export var size := Vector2(3.2, 2.6)


func _build(b: MeshBuilder) -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var y := top_height
	b.quad(Mats.get_mat("blanket"), Vector3(-hx, y, hz), Vector3(hx, y, hz), Vector3(hx, y, -hz), Vector3(-hx, y, -hz), Color.WHITE, 0.4)
	# A slight fold along one edge.
	b.quad(Mats.get_mat("blanket"), Vector3(-hx, y, hz), Vector3(-hx, y, -hz), Vector3(-hx - 0.18, 0.02, -hz), Vector3(-hx - 0.18, 0.02, hz), Color(0.9, 0.9, 0.9), 0.4)
	# Wicker basket with a handle.
	var wood := Mats.get_mat("wood")
	var bc := Vector3(hx - 0.6, y, -hz + 0.5)
	b.box_mm(wood, bc + Vector3(-0.32, 0, -0.22), bc + Vector3(0.32, 0.32, 0.22), Color("#c9975a"))
	b.box_mm(wood, bc + Vector3(-0.34, 0.32, -0.24), bc + Vector3(0.34, 0.36, 0.24), Color("#a87a46"))
	b.tube(Mats.get_mat("rope"), PackedVector3Array([bc + Vector3(-0.28, 0.36, 0), bc + Vector3(-0.2, 0.55, 0), bc + Vector3(0, 0.6, 0), bc + Vector3(0.2, 0.55, 0), bc + Vector3(0.28, 0.36, 0)]), 0.025, 4, Color("#a87a46"))
	# Plates, cups, apples and a thermos.
	var solid := Mats.get_mat("solid")
	for p in [Vector3(-0.6, y, 0.3), Vector3(0.4, y, 0.5)]:
		b.cylinder(solid, Transform3D(Basis(), p), 0.2, 0.22, 0.03, 12, Color("#fbf8f0"))
	for p in [Vector3(-0.2, y, -0.4), Vector3(0.1, y, 0.0)]:
		b.cylinder(solid, Transform3D(Basis(), p), 0.05, 0.06, 0.12, 8, Color("#a9c9db"))
	for p in [Vector3(-0.62, y + 0.1, 0.3), Vector3(-0.5, y + 0.09, 0.42), Vector3(0.7, y + 0.08, -0.3)]:
		b.sphere(solid, p, Vector3(0.08, 0.08, 0.08), 4, 7, Color("#d8433b"))
	b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(), Vector3(0.9, y, 0.7)), 0.07, 0.07, 0.34, 8, Color("#3f7d4f"))
	# Sandwich triangles.
	b.box(solid, Transform3D(Basis(Vector3.UP, 0.6), Vector3(0.4, y + 0.06, 0.5)), Vector3(0.16, 0.06, 0.16), Color("#f2d58f"))


func _casts_shadow() -> bool:
	return false


func _draw_distance() -> float:
	return 160.0
