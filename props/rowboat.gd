extends Prop
## Grandpa's wooden rowing boat moored on the river (flight 8's landing target). Origin = the
## water surface at the middle of the boat; the boat lies along local X, bow toward +X.
## Low gunwales so the plane can glide in over the bow; seats only at the ends.

@export var length := 3.8
@export var beam := 1.5
## Height of the floorboards above the water (the landing surface).
@export var floor_y := 0.18
@export var gunwale_y := 0.46


func _hull_half_width(x: float) -> float:
	# Narrower toward the pointed bow (+X) and a little toward the stern.
	var t := x / (length * 0.5)
	return beam * 0.5 * (1.0 - 0.75 * maxf(0.0, t) * maxf(0.0, t)) * (1.0 - 0.15 * maxf(0.0, -t))


func _build(b: MeshBuilder) -> void:
	var wood := Mats.get_mat("wood")
	var hull := Color("#2f6f8f")
	var inside := Color("#c9a27e")
	var h := length * 0.5
	var n := 12
	for i in n:
		var x0 := lerpf(-h, h, float(i) / n)
		var x1 := lerpf(-h, h, float(i + 1) / n)
		var w0 := _hull_half_width(x0)
		var w1 := _hull_half_width(x1)
		var bot := -0.12
		for s in [-1.0, 1.0]:
			# Outer planking and the inside of the hull.
			b.quad(wood, Vector3(x0, bot, s * w0 * 0.75), Vector3(x1, bot, s * w1 * 0.75), Vector3(x1, gunwale_y, s * w1), Vector3(x0, gunwale_y, s * w0), hull)
			b.quad(wood, Vector3(x1, floor_y, s * w1 * 0.85), Vector3(x0, floor_y, s * w0 * 0.85), Vector3(x0, gunwale_y, s * w0 * 0.97), Vector3(x1, gunwale_y, s * w1 * 0.97), inside)
			# Gunwale rail.
			b.box_mm(wood, Vector3(x0, gunwale_y - 0.02, minf(s * w0 * 0.96, s * w0)), Vector3(x1, gunwale_y + 0.05, maxf(s * w0 * 0.96, s * w0)), Color("#fbf8f0"))
		# Floorboards.
		b.box_mm(wood, Vector3(x0, floor_y - 0.04, -minf(w0, w1) * 0.85), Vector3(x1, floor_y, minf(w0, w1) * 0.85), inside.darkened(0.05 * (i % 2)))
		b.quad(wood, Vector3(x0, bot, -w0 * 0.75), Vector3(x1, bot, -w1 * 0.75), Vector3(x1, bot, w1 * 0.75), Vector3(x0, bot, w0 * 0.75), hull.darkened(0.3))
	# Transom (stern board) and a little bow post.
	b.box_mm(wood, Vector3(-h - 0.05, -0.1, -_hull_half_width(-h)), Vector3(-h + 0.03, gunwale_y + 0.05, _hull_half_width(-h)), hull.darkened(0.15))
	b.box_mm(wood, Vector3(h - 0.12, -0.05, -0.05), Vector3(h + 0.02, gunwale_y + 0.12, 0.05), Color("#fbf8f0"))
	# Seats at the two ends only (the middle is clear for landing), oars along the sides.
	for sx in [-h + 0.45, h - 0.75]:
		var w := _hull_half_width(sx)
		b.box_mm(wood, Vector3(sx - 0.18, gunwale_y - 0.16, -w * 0.95), Vector3(sx + 0.18, gunwale_y - 0.1, w * 0.95), Color("#a87a4f"))
	for s in [-1.0, 1.0]:
		b.tube(wood, PackedVector3Array([Vector3(-1.2, gunwale_y + 0.07, s * 0.62), Vector3(1.1, gunwale_y + 0.07, s * 0.6)]), 0.025, 5, Color("#b48a64"))
		b.box_mm(wood, Vector3(1.1, gunwale_y + 0.04, s * 0.6 - 0.07), Vector3(1.6, gunwale_y + 0.08, s * 0.6 + 0.07), Color("#b48a64"))
	# Mooring rope to a post on the bank side.
	b.tube(Mats.get_mat("rope"), PackedVector3Array([Vector3(-h, gunwale_y, 0), Vector3(-h - 1.0, 0.1, -0.6), Vector3(-h - 2.2, 0.0, -1.4)]), 0.015, 3, Color("#d8c39a"))


func _build_colliders() -> void:
	var h := length * 0.5
	# The hull up to the floorboards, the gunwales (low, so the plane can hop in) and the seats.
	add_box("post", Vector3(0, (floor_y - 0.35) * 0.5, 0), Vector3(length, floor_y + 0.35, beam * 0.8))
	for s in [-1.0, 1.0]:
		add_box("post", Vector3(-0.2, (floor_y + gunwale_y) * 0.5, s * beam * 0.46), Vector3(length - 0.6, gunwale_y - floor_y, 0.08))
	for sx in [-h + 0.45, h - 0.75]:
		add_box("post", Vector3(sx, gunwale_y - 0.13, 0), Vector3(0.36, 0.06, beam * 0.85))


func _draw_distance() -> float:
	return 220.0
