extends Prop
## Brick clock tower, 7 m square and 22 m tall, with a pyramid roof, four clock faces and a
## stone balcony on the front (+Z) face. Origin = ground center of the tower.

@export var size := 7.0
@export var height := 22.0
@export var balcony_top := 14.05
## Local Z of the balcony (landing pad) center.
@export var balcony_center_z := 4.6


func _build(b: MeshBuilder) -> void:
	var hs := size * 0.5
	var brick := Mats.get_mat("brick")
	var stone := Mats.get_mat("stone")
	var solid := Mats.get_mat("solid")
	var sc := Color("#e6dccb")
	b.box_mm(stone, Vector3(-hs - 0.3, 0, -hs - 0.3), Vector3(hs + 0.3, 1.6, hs + 0.3), sc, 63 - 8)
	b.box_mm(brick, Vector3(-hs, 1.6, -hs), Vector3(hs, height, hs), Color.WHITE, 63 - 8 - 4)
	# Quoins and string courses.
	for cx in [-hs, hs]:
		for cz in [-hs, hs]:
			var y := 1.6
			var k := 0
			while y < height - 0.5:
				var w := 0.7 if k % 2 == 0 else 0.45
				var x0: float = cx - signf(cx) * w
				var x1: float = cx + signf(cx) * 0.06
				var z0: float = cz - signf(cz) * w
				var z1: float = cz + signf(cz) * 0.06
				b.box_mm(stone, Vector3(minf(x0, x1), y, cz - 0.06), Vector3(maxf(x0, x1), y + 0.5, cz + 0.06), sc)
				b.box_mm(stone, Vector3(cx - 0.06, y, minf(z0, z1)), Vector3(cx + 0.06, y + 0.5, maxf(z0, z1)), sc)
				y += 0.6
				k += 1
	for y in [6.0, 11.0, 16.0]:
		b.box_mm(stone, Vector3(-hs - 0.12, y, -hs - 0.12), Vector3(hs + 0.12, y + 0.35, hs + 0.12), sc)
	# Cornice and pyramid roof.
	b.box_mm(stone, Vector3(-hs - 0.4, height - 0.5, -hs - 0.4), Vector3(hs + 0.4, height + 0.2, hs + 0.4), sc)
	b.pyramid(Mats.get_mat("shingle"), Transform3D(Basis(), Vector3(0, height + 0.2, 0)), Vector2(size + 0.6, size + 0.6), 6.5, Color("#4f5a68"))
	b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(), Vector3(0, height + 6.5, 0)), 0.12, 0.03, 1.8, 6, Color("#d4a63a"))
	b.sphere(Mats.get_mat("metal"), Vector3(0, height + 7.0, 0), Vector3(0.22, 0.22, 0.22), 4, 6, Color("#d4a63a"))
	# Belfry openings on all four sides.
	for f in 4:
		var basis := Basis(Vector3.UP, f * PI * 0.5)
		var xf := Transform3D(basis, Vector3.ZERO)
		for x in [-1.3, 1.3]:
			b.box(solid, xf * Transform3D(Basis(), Vector3(x, height - 2.3, hs + 0.01)), Vector3(1.0, 2.6, 0.04), Color("#2a221f"))
			b.cylinder(solid, xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, height - 1.0, hs + 0.03)), 0.5, 0.5, 0.04, 10, Color("#2a221f"), true)
			b.box(stone, xf * Transform3D(Basis(), Vector3(x, height - 3.65, hs + 0.08)), Vector3(1.3, 0.16, 0.2), sc)
		# Clock face.
		var cy := 18.4
		var face := xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, cy, hs + 0.0))
		b.cylinder(stone, face, 1.75, 1.75, 0.16, 20, sc, true)
		b.cylinder(solid, xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, cy, hs + 0.08)), 1.5, 1.5, 0.1, 20, Color("#fbf7ea"), true)
		for t in 12:
			var a := TAU * t / 12.0
			var p := Vector3(sin(a) * 1.3, cy + cos(a) * 1.3, hs + 0.2)
			b.box(solid, xf * Transform3D(Basis(Vector3.BACK, -a), p), Vector3(0.08, 0.28 if t % 3 == 0 else 0.16, 0.04), Color("#2a2a2a"))
		# Hands at 5:42.
		var hour_a := TAU * (5.0 + 42.0 / 60.0) / 12.0
		var min_a := TAU * 42.0 / 60.0
		b.box(solid, xf * Transform3D(Basis(Vector3.BACK, -hour_a), Vector3(sin(hour_a) * 0.4, cy + cos(hour_a) * 0.4, hs + 0.24)), Vector3(0.1, 0.85, 0.04), Color("#1d1d1d"))
		b.box(solid, xf * Transform3D(Basis(Vector3.BACK, -min_a), Vector3(sin(min_a) * 0.6, cy + cos(min_a) * 0.6, hs + 0.26)), Vector3(0.07, 1.25, 0.04), Color("#1d1d1d"))
		b.sphere(Mats.get_mat("metal"), Vector3.ZERO + xf * Vector3(0, cy, hs + 0.28), Vector3(0.1, 0.1, 0.06), 3, 6, Color("#d4a63a"))
	# Front door at the base.
	b.box_mm(solid, Vector3(-1.0, 0, hs + 0.28), Vector3(1.0, 3.0, hs + 0.34), Color("#5a3a2a"))
	b.cylinder(solid, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 3.0, hs + 0.28)), 1.0, 1.0, 0.06, 12, Color("#5a3a2a"), true)
	_balcony(b, sc)


func _balcony(b: MeshBuilder, sc: Color) -> void:
	var hs := size * 0.5
	var stone := Mats.get_mat("stone")
	var solid := Mats.get_mat("solid")
	var top := balcony_top
	var z_out := balcony_center_z + 1.8
	var w := 2.6
	b.box_mm(stone, Vector3(-w, top - 0.35, hs), Vector3(w, top, z_out), sc)
	# Corbels.
	for x in [-w + 0.4, -0.8, 0.8, w - 0.4]:
		b.poly(stone, PackedVector3Array([Vector3(x + 0.15, top - 0.35, hs), Vector3(x + 0.15, top - 0.35, z_out - 0.4), Vector3(x + 0.15, top - 1.6, hs)]), sc)
		b.poly(stone, PackedVector3Array([Vector3(x - 0.15, top - 0.35, z_out - 0.4), Vector3(x - 0.15, top - 0.35, hs), Vector3(x - 0.15, top - 1.6, hs)]), sc)
		b.quad(stone, Vector3(x - 0.15, top - 0.35, z_out - 0.4), Vector3(x - 0.15, top - 1.6, hs), Vector3(x + 0.15, top - 1.6, hs), Vector3(x + 0.15, top - 0.35, z_out - 0.4), sc)
	# Low decorative balustrades on the two sides (front stays open for landing).
	for sx in [-1.0, 1.0]:
		var x: float = sx * (w - 0.12)
		b.box_mm(stone, Vector3(x - 0.12, top + 0.62, hs), Vector3(x + 0.12, top + 0.72, z_out), sc)
		var n := 6
		for i in n:
			var z := lerpf(hs + 0.25, z_out - 0.2, float(i) / (n - 1))
			b.cylinder(stone, Transform3D(Basis(), Vector3(x, top, z)), 0.07, 0.1, 0.62, 6, sc)
	# Arched door onto the balcony.
	b.box_mm(solid, Vector3(-0.8, top, hs - 0.02), Vector3(0.8, top + 2.2, hs + 0.03), Color("#3a2c28"))
	b.cylinder(solid, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, top + 2.2, hs + 0.03)), 0.8, 0.8, 0.05, 10, Color("#3a2c28"), true)
	# Potted flowers in the corners.
	for x in [-w + 0.45, w - 0.45]:
		b.cylinder(Mats.get_mat("brick"), Transform3D(Basis(), Vector3(x, top, hs + 0.4)), 0.2, 0.26, 0.38, 8, Color("#c46a4a"))
		b.sphere(Mats.get_mat("foliage"), Vector3(x, top + 0.55, hs + 0.4), Vector3(0.3, 0.25, 0.3), 4, 6, Color("#e8546a"))


func _build_colliders() -> void:
	var hs := size * 0.5
	add_box("wall", Vector3(0, 0.8, 0), Vector3(size + 0.6, 1.6, size + 0.6))
	add_box("wall", Vector3(0, height * 0.5, 0), Vector3(size + 0.1, height, size + 0.1))
	add_box("wall", Vector3(0, height - 0.15, 0), Vector3(size + 0.8, 0.7, size + 0.8))
	add_convex("wall", PackedVector3Array([
		Vector3(-hs - 0.3, height + 0.2, -hs - 0.3), Vector3(hs + 0.3, height + 0.2, -hs - 0.3),
		Vector3(-hs - 0.3, height + 0.2, hs + 0.3), Vector3(hs + 0.3, height + 0.2, hs + 0.3),
		Vector3(0, height + 6.7, 0),
	]))
	# Balcony slab sits just under the landing pad collider.
	var z_out := balcony_center_z + 1.8
	add_box("wall", Vector3(0, balcony_top - 0.225, (hs + z_out) * 0.5), Vector3(5.2, 0.25, z_out - hs))


func _draw_distance() -> float:
	return 0.0
