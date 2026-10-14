extends Prop
## Café table with chairs and a striped umbrella. Origin = ground at the table center.

@export var umbrella_a := Color("#2f6f8f")
@export var umbrella_b := Color("#f7eedd")
@export var chairs := 3


func _build(b: MeshBuilder) -> void:
	var metal := Mats.get_mat("metal")
	var iron := Color("#2f3d36")
	b.cylinder(metal, Transform3D(), 0.25, 0.04, 0.06, 8, iron)
	b.cylinder(metal, Transform3D(Basis(), Vector3(0, 0.05, 0)), 0.04, 0.04, 0.68, 6, iron)
	b.cylinder(Mats.get_mat("solid"), Transform3D(Basis(), Vector3(0, 0.72, 0)), 0.48, 0.48, 0.04, 14, Color("#fbf8f0"))
	for i in chairs:
		var a := TAU * i / chairs + 0.4
		var p := Vector3(sin(a), 0, cos(a)) * 0.85
		var basis := Basis(Vector3.UP, a + PI)
		var xf := Transform3D(basis, p)
		b.box(Mats.get_mat("wood"), xf * Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(0.42, 0.05, 0.42), Color("#b07a4f"))
		b.box(Mats.get_mat("wood"), xf * Transform3D(Basis(), Vector3(0, 0.72, -0.2)), Vector3(0.42, 0.5, 0.04), Color("#b07a4f"))
		for lx in [-0.18, 0.18]:
			for lz in [-0.18, 0.18]:
				b.box(metal, xf * Transform3D(Basis(), Vector3(lx, 0.22, lz)), Vector3(0.03, 0.45, 0.03), iron)
	# Umbrella.
	b.cylinder(metal, Transform3D(Basis(), Vector3(0, 0.76, 0)), 0.025, 0.025, 1.7, 6, Color("#dcd6c8"))
	var segs := 10
	var top := Vector3(0, 2.55, 0)
	var r := 1.45
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var p0 := Vector3(sin(a0) * r, 2.1, cos(a0) * r)
		var p1 := Vector3(sin(a1) * r, 2.1, cos(a1) * r)
		var col := umbrella_a if i % 2 == 0 else umbrella_b
		b.poly(Mats.get_mat("cloth"), PackedVector3Array([p0, p1, top]), col)
		var pm := (p0 + p1) * 0.5
		b.poly(Mats.get_mat("cloth"), PackedVector3Array([p0, pm + Vector3(0, -0.14, 0) + pm.normalized() * 0.02, p1]), col)


func _build_colliders() -> void:
	add_cylinder("post", Vector3.ZERO, 0.5, 0.8)
	add_cylinder("post", Vector3(0, 0.8, 0), 0.08, 1.4)
	add_cylinder("post", Vector3(0, 2.05, 0), 1.45, 0.5)


func _draw_distance() -> float:
	return 160.0
