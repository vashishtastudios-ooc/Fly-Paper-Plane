extends Prop
## Octagonal park bandstand with a red and white striped roof. Origin = ground center.

@export var radius := 4.0
@export var deck_height := 0.9
@export var post_height := 2.8


func _corner(i: int, r: float) -> Vector3:
	var a := TAU * (i + 0.5) / 8.0
	return Vector3(sin(a) * r, 0, cos(a) * r)


func _build(b: MeshBuilder) -> void:
	var stone := Mats.get_mat("stone")
	var wood := Mats.get_mat("wood")
	var solid := Mats.get_mat("solid")
	var trim := Mats.TRIM
	b.cylinder(stone, Transform3D(Basis(Vector3.UP, TAU / 16.0), Vector3.ZERO), radius, radius, deck_height - 0.1, 8, Color("#e6dccb"))
	b.cylinder(wood, Transform3D(Basis(Vector3.UP, TAU / 16.0), Vector3(0, deck_height - 0.1, 0)), radius + 0.15, radius + 0.15, 0.12, 8, Color("#c9a27e"))
	var top := deck_height + post_height
	for i in 8:
		var c := _corner(i, radius - 0.2)
		b.cylinder(solid, Transform3D(Basis(), c + Vector3(0, deck_height, 0)), 0.1, 0.1, post_height, 6, trim)
		# Railing between posts except the entrance (facing +Z).
		if i != 7:
			var c2 := _corner((i + 1) % 8, radius - 0.2)
			var a := c + Vector3(0, deck_height + 0.85, 0)
			var bpt := c2 + Vector3(0, deck_height + 0.85, 0)
			var dir := (bpt - a)
			var seg_len := dir.length()
			var basis := Basis(Vector3.UP, atan2(dir.x, dir.z))
			b.box(solid, Transform3D(basis, (a + bpt) * 0.5), Vector3(0.08, 0.08, seg_len), trim)
			for k in 7:
				var p := a.lerp(bpt, (k + 0.5) / 7.0) - Vector3(0, 0.42, 0)
				b.box(solid, Transform3D(basis, p), Vector3(0.04, 0.84, 0.04), trim)
		# Fretwork brackets under the eaves.
		var cb := c + Vector3(0, top - 0.35, 0)
		b.box(solid, Transform3D(Basis(Vector3.UP, atan2(c.x, c.z)), cb - c.normalized() * 0.2), Vector3(0.06, 0.25, 0.45), trim)
	# Eave ring.
	b.cylinder(solid, Transform3D(Basis(Vector3.UP, TAU / 16.0), Vector3(0, top - 0.1, 0)), radius + 0.2, radius + 0.2, 0.2, 8, trim)
	# Striped conical roof: one triangle per segment, alternating colors.
	var segs := 16
	var apex := Vector3(0, top + 2.3, 0)
	var rr := radius + 0.55
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var p0 := Vector3(sin(a0) * rr, top + 0.05, cos(a0) * rr)
		var p1 := Vector3(sin(a1) * rr, top + 0.05, cos(a1) * rr)
		var col := Color("#c8423b") if i % 2 == 0 else Color("#f7eedd")
		b.poly(Mats.get_mat("paint"), PackedVector3Array([p0, p1, apex]), col)
		b.poly(Mats.get_mat("solid"), PackedVector3Array([p1, p0, Vector3(0, top + 0.05, 0)]), Color("#f4ead8"))
	b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(), apex - Vector3(0, 0.1, 0)), 0.06, 0.02, 0.9, 6, Color("#d4a63a"))
	b.sphere(Mats.get_mat("metal"), apex + Vector3(0, 0.85, 0), Vector3(0.12, 0.12, 0.12), 3, 6, Color("#d4a63a"))
	# Entrance steps.
	for s in 3:
		b.box_mm(stone, Vector3(-1.0, 0, radius - 0.2 + s * 0.35), Vector3(1.0, deck_height - 0.1 - s * 0.28, radius + 0.15 + s * 0.35), Color("#e6dccb"))
	# Music stands.
	for i in 3:
		var p := Vector3(-1.2 + i * 1.2, deck_height, -0.5 - (i % 2) * 0.6)
		b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(), p), 0.02, 0.02, 1.0, 4, Color("#2f3d36"))
		b.box(Mats.get_mat("metal"), Transform3D(Basis(Vector3.RIGHT, -0.5), p + Vector3(0, 1.1, 0)), Vector3(0.45, 0.32, 0.02), Color("#2f3d36"))


func _build_colliders() -> void:
	add_cylinder("wall", Vector3.ZERO, radius + 0.1, deck_height)
	var top := deck_height + post_height
	for i in 8:
		var c := _corner(i, radius - 0.2)
		add_cylinder("wall", c + Vector3(0, deck_height, 0), 0.15, post_height)
	var pts := PackedVector3Array()
	for i in 8:
		pts.append(_corner(i, radius + 0.6) + Vector3(0, top - 0.1, 0))
	pts.append(Vector3(0, top + 2.4, 0))
	add_convex("wall", pts)
