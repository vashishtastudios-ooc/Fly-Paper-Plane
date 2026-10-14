extends Prop
## Stone arch bridge carrying the lane over the river. Origin = (0, 0, river center).
## The deck rises 1.5 m at the middle with a cosine profile; an elliptical arch opening
## (17 m wide, 3.15 m high above the river bed) is centered under it. The collider follows
## the ellipse with thin slices so the space under the arch is flyable.

@export var half_length := 24.0
@export var half_width := 5.5
@export var rise := 1.5
@export var arch_half_width := 8.5
@export var arch_height := 3.15
@export var bed_y := -2.6
@export var base_y := 0.05

const PARAPET_H := 0.9
const PARAPET_T := 0.5


func deck_top(z: float) -> float:
	if absf(z) >= half_length:
		return base_y
	return base_y + rise * 0.5 * (1.0 + cos(PI * z / half_length))


## Height of the arch intrados at local z, or -INF outside the opening.
func arch_y(z: float) -> float:
	var t := z / arch_half_width
	if absf(t) >= 1.0:
		return -INF
	return bed_y + arch_height * sqrt(1.0 - t * t)


func bottom_y(z: float) -> float:
	var a := arch_y(z)
	if a > -INF:
		return a
	return Terrain.ground_height(global_position.x, global_position.z + z) - 0.6


func _zs() -> PackedFloat32Array:
	var zs := PackedFloat32Array()
	var steps := 64
	for i in steps + 1:
		var z := lerpf(half_length, -half_length, float(i) / steps)
		zs.append(z)
	# Make sure the arch springs are exact slice boundaries.
	zs.append(arch_half_width)
	zs.append(-arch_half_width)
	zs.sort()
	zs.reverse()
	return zs


func _face(b: MeshBuilder, mat: Material, pts: PackedVector3Array, want: Vector3, col: Color) -> void:
	var n := (pts[1] - pts[0]).cross(pts[2] - pts[0])
	if n.dot(want) < 0.0:
		pts.reverse()
	b.poly(mat, pts, col)


func _build(b: MeshBuilder) -> void:
	var stone := Mats.get_mat("stone")
	var sc := Color("#e3d6c0")
	var ring := Color("#efe5d2")
	var W := half_width
	var zs := _zs()
	for i in zs.size() - 1:
		var za := zs[i]
		var zb := zs[i + 1]
		if za - zb < 0.001:
			continue
		var mid := (za + zb) * 0.5
		var inside := absf(mid) < arch_half_width
		var ba := arch_y(za) if inside else bottom_y(za)
		var bb := arch_y(zb) if inside else bottom_y(zb)
		if inside:
			ba = maxf(arch_y(za), bed_y) if absf(za) < arch_half_width else bed_y
			bb = maxf(arch_y(zb), bed_y) if absf(zb) < arch_half_width else bed_y
		var ta := deck_top(za) + PARAPET_H
		var tb := deck_top(zb) + PARAPET_H
		for sx in [-1.0, 1.0]:
			var x: float = sx * W
			_face(b, stone, PackedVector3Array([Vector3(x, ba, za), Vector3(x, bb, zb), Vector3(x, tb, zb), Vector3(x, ta, za)]), Vector3(sx, 0, 0), sc)
			# Parapet inner face and top.
			var xi: float = sx * (W - PARAPET_T)
			_face(b, stone, PackedVector3Array([Vector3(xi, deck_top(za), za), Vector3(xi, deck_top(zb), zb), Vector3(xi, tb, zb), Vector3(xi, ta, za)]), Vector3(-sx, 0, 0), sc)
			_face(b, stone, PackedVector3Array([Vector3(xi, ta, za), Vector3(x, ta, za), Vector3(x, tb, zb), Vector3(xi, tb, zb)]), Vector3.UP, ring)
		# Road deck.
		_face(b, Mats.get_mat("asphalt"), PackedVector3Array([
			Vector3(-W + PARAPET_T, deck_top(za), za), Vector3(W - PARAPET_T, deck_top(za), za),
			Vector3(W - PARAPET_T, deck_top(zb), zb), Vector3(-W + PARAPET_T, deck_top(zb), zb)]), Vector3.UP, Color.WHITE)
		if inside:
			# Arch intrados (underside), facing down into the opening.
			_face(b, stone, PackedVector3Array([Vector3(-W, ba, za), Vector3(W, ba, za), Vector3(W, bb, zb), Vector3(-W, bb, zb)]), Vector3.DOWN, sc.darkened(0.08))
			# Voussoir ring on both faces.
			for sx in [-1.0, 1.0]:
				var x: float = sx * (W + 0.06)
				var oa := _ring_point(za, 0.7)
				var ob := _ring_point(zb, 0.7)
				_face(b, stone, PackedVector3Array([Vector3(x, ba, za), Vector3(x, bb, zb), Vector3(x, ob.y, ob.x), Vector3(x, oa.y, oa.x)]), Vector3(sx, 0, 0), ring)
	# Cutwaters / pilasters at the arch springs.
	for sz in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			var z: float = sz * (arch_half_width + 0.9)
			var x0: float = sx * W
			var x1: float = sx * (W + 0.5)
			b.box_mm(stone, Vector3(minf(x0, x1), bed_y - 0.2, z - 0.8), Vector3(maxf(x0, x1), deck_top(z) + PARAPET_H + 0.15, z + 0.8), sc)
	# Keystones.
	for sx in [-1.0, 1.0]:
		b.box_mm(stone, Vector3(minf(sx * W, sx * (W + 0.12)), bed_y + arch_height - 0.05, -0.35), Vector3(maxf(sx * W, sx * (W + 0.12)), bed_y + arch_height + 0.85, 0.35), ring)


## Point on the outer voussoir ring (as Vector2(z, y)) for an intrados point at z.
func _ring_point(z: float, thickness: float) -> Vector2:
	var a := arch_half_width + thickness
	var bh := arch_height + thickness
	var t := clampf(z / arch_half_width, -1.0, 1.0)
	var ang := asin(t)
	return Vector2(sin(ang) * a, bed_y + cos(ang) * bh)


func _after_build() -> void:
	for sz in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			var z: float = sz * (half_length - 1.5)
			inst("lamp", Transform3D(Basis(), Vector3(sx * (half_width - 0.25), deck_top(z) + PARAPET_H, z)))


func _build_colliders() -> void:
	var W := half_width
	var slice := 0.75
	var z := half_length
	while z > -half_length:
		var za := z
		var zb := maxf(z - slice, -half_length)
		var mid := (za + zb) * 0.5
		var top := maxf(deck_top(za), deck_top(zb))
		var bottom: float
		if absf(za) < arch_half_width and absf(zb) < arch_half_width:
			# Lower end of the slice: keeps the opening fully flyable.
			bottom = minf(arch_y(za), arch_y(zb))
		elif absf(mid) < arch_half_width:
			bottom = bed_y + 0.3
		else:
			bottom = minf(bottom_y(za), bottom_y(zb))
		var h := top - bottom
		if h > 0.05:
			add_box("bridge", Vector3(0, bottom + h * 0.5, mid), Vector3(W * 2.0, h, za - zb))
		for sx in [-1.0, 1.0]:
			add_box("bridge", Vector3(sx * (W - PARAPET_T * 0.5), top + PARAPET_H * 0.5, mid), Vector3(PARAPET_T, PARAPET_H, za - zb))
		z = zb


func _draw_distance() -> float:
	return 0.0
