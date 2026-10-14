extends Prop
## Linden Primary School: a two-storey brick school with an open upstairs classroom (desks,
## chalkboard, radiators, ceiling fan) and a schoolyard (flagpole, swings, hoop, climbing frame).
## Origin = ground at the center of the front facade. The front faces local -Z (toward the lane),
## the building extends toward +Z. The upstairs classroom spans x -8..8, z 1..13, floor 4.0.

const FLOOR_Y := 4.0
const CEILING_Y := 7.4
const ROOM_X := 8.0
const ROOM_Z0 := 1.0
const ROOM_Z1 := 13.0
const WIDTH := 28.0
const DEPTH := 16.0
const ROOF_Y := 7.8
## Window openings in the front wall: [x0, x1, open].
const WINDOWS := [[-6.5, -3.5, false], [-1.5, 1.5, false], [2.0, 5.0, true]]
const SILL_Y := 4.6
const HEAD_Y := 6.9
const FAN_POS := Vector3(-2.5, 7.05, 7.0)

var _fan: Node3D


func _build(b: MeshBuilder) -> void:
	var brick := Mats.get_mat("brick")
	var stone := Mats.get_mat("stone")
	var solid := Mats.get_mat("solid")
	var paint := Mats.get_mat("plaster")
	var wood := Mats.get_mat("wood")
	var trim := Mats.TRIM
	var hw := WIDTH * 0.5
	var wall_in := Color("#f3e3bf")
	# Ground floor block and plinth.
	b.box_mm(stone, Vector3(-hw - 0.1, 0, -0.1), Vector3(hw + 0.1, 0.6, DEPTH + 0.1), Color("#d6cdbd"), 63 - 8)
	b.box_mm(brick, Vector3(-hw, 0.6, 0), Vector3(hw, FLOOR_Y - 0.2, DEPTH), Color.WHITE, 63 - 8)
	b.box_mm(solid, Vector3(-hw - 0.08, FLOOR_Y - 0.3, -0.12), Vector3(hw + 0.08, FLOOR_Y - 0.1, DEPTH + 0.12), trim)
	# Upper floor: solid wings either side of the classroom and behind it.
	b.box_mm(brick, Vector3(-hw, FLOOR_Y - 0.2, 0), Vector3(-ROOM_X - 0.3, ROOF_Y, DEPTH), Color.WHITE, 63 - 8)
	b.box_mm(brick, Vector3(ROOM_X + 0.3, FLOOR_Y - 0.2, 0), Vector3(hw, ROOF_Y, DEPTH), Color.WHITE, 63 - 8)
	b.box_mm(brick, Vector3(-ROOM_X - 0.3, FLOOR_Y - 0.2, ROOM_Z1 + 0.3), Vector3(ROOM_X + 0.3, ROOF_Y, DEPTH), Color.WHITE, 63 - 8)
	# Classroom shell: floor, ceiling, side and back walls (interior paint).
	b.box_mm(wood, Vector3(-ROOM_X, FLOOR_Y - 0.2, 0.3), Vector3(ROOM_X, FLOOR_Y, ROOM_Z1), Color("#c9a27e"))
	b.box_mm(paint, Vector3(-ROOM_X - 0.3, CEILING_Y, 0), Vector3(ROOM_X + 0.3, ROOF_Y, ROOM_Z1 + 0.3), Color("#fbf7ee"))
	b.box_mm(paint, Vector3(-ROOM_X - 0.3, FLOOR_Y, 0.0), Vector3(-ROOM_X, CEILING_Y, ROOM_Z1 + 0.3), wall_in)
	b.box_mm(paint, Vector3(ROOM_X, FLOOR_Y, 0.0), Vector3(ROOM_X + 0.3, CEILING_Y, ROOM_Z1 + 0.3), wall_in)
	b.box_mm(paint, Vector3(-ROOM_X, FLOOR_Y, ROOM_Z1), Vector3(ROOM_X, CEILING_Y, ROOM_Z1 + 0.3), wall_in)
	# Skirting boards.
	for x in [-ROOM_X + 0.03, ROOM_X - 0.03]:
		b.box_mm(wood, Vector3(x - 0.03, FLOOR_Y, 0.3), Vector3(x + 0.03, FLOOR_Y + 0.15, ROOM_Z1), Color("#8a6a52"))
	# Front wall with window openings: brick outside, paint inside.
	for seg in _front_segments():
		var x0: float = seg[0]
		var x1: float = seg[1]
		var y0: float = seg[2]
		var y1: float = seg[3]
		b.box_mm(brick, Vector3(x0, y0, 0.0), Vector3(x1, y1, 0.15), Color.WHITE)
		b.box_mm(paint, Vector3(x0, y0, 0.15), Vector3(x1, y1, 0.3), wall_in)
	for w in WINDOWS:
		var x0: float = w[0]
		var x1: float = w[1]
		# Frame, sill (inside and out) and lintel.
		b.box_mm(solid, Vector3(x0 - 0.1, SILL_Y - 0.12, -0.12), Vector3(x1 + 0.1, SILL_Y, 0.42), trim)
		b.box_mm(stone, Vector3(x0 - 0.2, HEAD_Y, -0.08), Vector3(x1 + 0.2, HEAD_Y + 0.25, 0.02), Color("#e6dccb"))
		for fx in [x0, x1 - 0.08]:
			b.box_mm(solid, Vector3(fx, SILL_Y, 0.0), Vector3(fx + 0.08, HEAD_Y, 0.3), trim)
		b.box_mm(solid, Vector3(x0, HEAD_Y - 0.08, 0.0), Vector3(x1, HEAD_Y, 0.3), trim)
		if w[2]:
			# Open casement: two panes swung outward on their hinges.
			for side in [0, 1]:
				var hinge_x: float = x0 + 0.08 if side == 0 else x1 - 0.08
				var dir := 1.0 if side == 0 else -1.0
				var ang := 1.25 * dir
				var pw := (x1 - x0) * 0.5 - 0.08
				var pane_xf := Transform3D(Basis(Vector3.UP, ang), Vector3(hinge_x, (SILL_Y + HEAD_Y) * 0.5, -0.02))
				b.box(Mats.get_mat("glass"), pane_xf * Transform3D(Basis(), Vector3(dir * pw * 0.5, 0, 0)), Vector3(pw, HEAD_Y - SILL_Y - 0.1, 0.03), Color("#9cc3dd"))
				b.box(solid, pane_xf * Transform3D(Basis(), Vector3(dir * pw * 0.5, 0, 0)), Vector3(pw + 0.06, 0.06, 0.05), trim)
		else:
			b.box_mm(Mats.get_mat("window_lit"), Vector3(x0 + 0.08, SILL_Y, 0.12), Vector3(x1 - 0.08, HEAD_Y - 0.08, 0.16), Color("#8fb8d6"))
			b.box_mm(solid, Vector3((x0 + x1) * 0.5 - 0.03, SILL_Y, 0.1), Vector3((x0 + x1) * 0.5 + 0.03, HEAD_Y, 0.2), trim)
			b.box_mm(solid, Vector3(x0, (SILL_Y + HEAD_Y) * 0.5 - 0.03, 0.1), Vector3(x1, (SILL_Y + HEAD_Y) * 0.5 + 0.03, 0.2), trim)
			# A potted plant on the inside sill.
			var pc := Vector3((x0 + x1) * 0.5 - 0.6, SILL_Y, 0.32)
			b.cylinder(Mats.get_mat("brick"), Transform3D(Basis(), pc), 0.1, 0.13, 0.2, 8, Color("#c46a4a"))
			b.sphere(Mats.get_mat("foliage"), pc + Vector3(0, 0.3, 0), Vector3(0.17, 0.15, 0.17), 4, 6, Color("#6f9e4c"))
		# Radiator under the window (inside).
		var rx := (x0 + x1) * 0.5
		for k in 9:
			var fx2 := rx - 0.8 + k * 0.2
			b.box_mm(solid, Vector3(fx2 - 0.05, FLOOR_Y + 0.12, 0.38), Vector3(fx2 + 0.05, SILL_Y - 0.16, 0.5), Color("#f4f0e6"))
		b.box_mm(solid, Vector3(rx - 0.9, FLOOR_Y + 0.08, 0.36), Vector3(rx + 0.9, FLOOR_Y + 0.14, 0.52), Color("#e6e0d2"))

	_classroom_interior(b)
	_exterior(b)


## Solid parts of the upstairs front wall around the window openings: [x0, x1, y0, y1].
func _front_segments() -> Array:
	var segs := [[-ROOM_X, ROOM_X, FLOOR_Y - 0.2, SILL_Y], [-ROOM_X, ROOM_X, HEAD_Y, CEILING_Y + 0.4]]
	var x := -ROOM_X
	for w in WINDOWS:
		segs.append([x, w[0], SILL_Y, HEAD_Y])
		x = w[1]
	segs.append([x, ROOM_X, SILL_Y, HEAD_Y])
	return segs


func _desk_positions() -> Array:
	var out := []
	for x in [-5.5, -2.5, 0.5, 3.5]:
		for z in [3.6, 6.4, 9.2, 11.6]:
			out.append(Vector3(x, FLOOR_Y, z))
	return out


func _classroom_interior(b: MeshBuilder) -> void:
	var wood := Mats.get_mat("wood")
	var metal := Mats.get_mat("metal")
	var solid := Mats.get_mat("solid")
	var chair_cols := [Color("#e8873a"), Color("#2f6f8f"), Color("#3f7d4f"), Color("#e0a13a"), Color("#c8423b")]
	var i := 0
	for p: Vector3 in _desk_positions():
		# Student desk facing the chalkboard (+X) with a chair behind it.
		b.box_mm(wood, p + Vector3(-0.35, 0.7, -0.5), p + Vector3(0.35, 0.75, 0.5), Color("#d6b48c"))
		for lx in [-0.3, 0.3]:
			for lz in [-0.45, 0.45]:
				b.box_mm(metal, p + Vector3(lx - 0.025, 0, lz - 0.025), p + Vector3(lx + 0.025, 0.7, lz + 0.025), Color("#5b6270"))
		var cp := p + Vector3(-0.75, 0, 0)
		var cc: Color = chair_cols[i % chair_cols.size()]
		b.box_mm(solid, cp + Vector3(-0.2, 0.42, -0.2), cp + Vector3(0.2, 0.46, 0.2), cc)
		b.box_mm(solid, cp + Vector3(-0.24, 0.46, -0.2), cp + Vector3(-0.2, 0.85, 0.2), cc)
		for lx in [-0.17, 0.17]:
			for lz in [-0.17, 0.17]:
				b.box_mm(metal, cp + Vector3(lx - 0.02, 0, lz - 0.02), cp + Vector3(lx + 0.02, 0.42, lz + 0.02), Color("#5b6270"))
		# Exercise books and pencils on some desks.
		if i % 3 != 1:
			b.box_mm(solid, p + Vector3(-0.15, 0.75, -0.3), p + Vector3(0.15, 0.77, 0.05), Color(["#a9c9db", "#f2d58f", "#e6c3da"][i % 3]))
			b.box_mm(solid, p + Vector3(0.05, 0.77, 0.15), p + Vector3(0.07, 0.785, 0.35), Color("#f2c14e"))
		i += 1
	# Chalkboard on the right wall.
	var bx := ROOM_X - 0.04
	b.box_mm(wood, Vector3(bx - 0.06, 4.9, 3.6), Vector3(bx, 6.5, 10.4), Color("#8a6a52"))
	b.box_mm(solid, Vector3(bx - 0.08, 5.0, 3.7), Vector3(bx - 0.05, 6.4, 10.3), Color("#2f4a3a"))
	b.box_mm(wood, Vector3(bx - 0.2, 4.88, 3.6), Vector3(bx, 4.95, 10.4), Color("#8a6a52"))
	# Teacher's desk, globe and apple.
	var td := Vector3(6.2, FLOOR_Y, 7.0)
	b.box_mm(wood, td + Vector3(-0.5, 0.0, -1.0), td + Vector3(0.5, 0.78, 1.0), Color("#a87a4f"))
	b.box_mm(wood, td + Vector3(-0.55, 0.78, -1.05), td + Vector3(0.55, 0.82, 1.05), Color("#8a6a52"))
	b.cylinder(metal, Transform3D(Basis(), td + Vector3(0, 0.82, -0.6)), 0.12, 0.04, 0.12, 8, Color("#c9a24a"))
	b.sphere(solid, td + Vector3(0, 1.15, -0.6), Vector3(0.22, 0.22, 0.22), 6, 10, Color("#5e9ac8"))
	b.sphere(Mats.get_mat("foliage"), td + Vector3(0.08, 1.2, -0.62), Vector3(0.12, 0.1, 0.1), 3, 6, Color("#7fae55"))
	b.sphere(solid, td + Vector3(0, 0.88, 0.5), Vector3(0.06, 0.06, 0.06), 4, 6, Color("#d8433b"))
	# Bookshelf on the back wall.
	var sh := Vector3(-5.5, FLOOR_Y, ROOM_Z1 - 0.2)
	b.box_mm(wood, sh + Vector3(-1.2, 0, -0.35), sh + Vector3(1.2, 1.6, 0.0), Color("#a87a4f"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for shelf in 3:
		var y := 0.1 + shelf * 0.52
		var x := -1.1
		while x < 1.05:
			var w := rng.randf_range(0.05, 0.11)
			var h := rng.randf_range(0.28, 0.42)
			b.box_mm(solid, sh + Vector3(x, y, -0.32), sh + Vector3(x + w, y + h, -0.05), Mats.pick(rng, Mats.PALETTE_HOUSES + Mats.DOOR_COLORS))
			x += w + 0.01
	# Posters, pinned paper planes and an alphabet strip on the walls.
	var poster_cols := ["#f2d58f", "#a9c9db", "#e6c3da", "#b9d6a8", "#e9b7a1"]
	for k in 5:
		var pz := 2.0 + k * 2.2
		b.box_mm(solid, Vector3(-ROOM_X + 0.01, 5.2, pz), Vector3(-ROOM_X + 0.03, 6.2, pz + 1.4), Color(poster_cols[k]))
		b.box_mm(solid, Vector3(-ROOM_X + 0.02, 5.9, pz + 0.2), Vector3(-ROOM_X + 0.04, 6.0, pz + 1.2), Color("#4a4640"))
	for k in 26:
		var ax := -7.6 + k * 0.6
		b.box_mm(solid, Vector3(ax, 6.75, ROOM_Z1 - 0.03), Vector3(ax + 0.5, 7.15, ROOM_Z1 - 0.01), Color(poster_cols[k % poster_cols.size()]))
	# Cork board with pinned paper planes.
	b.box_mm(wood, Vector3(-1.0, 5.0, ROOM_Z1 - 0.05), Vector3(2.4, 6.4, ROOM_Z1 - 0.01), Color("#c9975a"))
	for k in 4:
		var c := Vector3(-0.6 + k * 0.85, 5.6 + (k % 2) * 0.35, ROOM_Z1 - 0.06)
		b.poly(Mats.get_mat("paper_plane"), PackedVector3Array([c + Vector3(-0.25, -0.08, 0), c + Vector3(0.25, 0, 0), c + Vector3(-0.25, 0.1, 0)]), Color.WHITE)
	# Clock above the chalkboard.
	b.cylinder(solid, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(ROOM_X - 0.01, 6.85, 7.0)), 0.28, 0.28, 0.05, 16, Color("#fbf7ea"))
	b.box(solid, Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(ROOM_X - 0.07, 6.88, 7.02)), Vector3(0.02, 0.18, 0.02), Color("#222222"))
	# Ceiling lights.
	for lz in [4.0, 10.0]:
		b.box_mm(Mats.get_mat("glow"), Vector3(-1.5, CEILING_Y - 0.06, lz - 0.3), Vector3(1.5, CEILING_Y, lz + 0.3), Color("#fff4d8"))


func _exterior(b: MeshBuilder) -> void:
	var stone := Mats.get_mat("stone")
	var solid := Mats.get_mat("solid")
	var hw := WIDTH * 0.5
	# Parapet, pyramid roof and a small bell cupola.
	b.box_mm(stone, Vector3(-hw - 0.15, ROOF_Y - 0.1, -0.15), Vector3(hw + 0.15, ROOF_Y + 0.3, DEPTH + 0.15), Color("#e6dccb"))
	b.pyramid(Mats.get_mat("shingle"), Transform3D(Basis(), Vector3(0, ROOF_Y + 0.3, DEPTH * 0.5)), Vector2(WIDTH + 0.4, DEPTH + 0.4), 3.4, Mats.ROOF_SLATE)
	var cy := ROOF_Y + 2.6
	b.box_mm(Mats.get_mat("paint"), Vector3(-0.9, cy, DEPTH * 0.5 - 0.9), Vector3(0.9, cy + 1.6, DEPTH * 0.5 + 0.9), Color("#f5f0e5"))
	b.pyramid(Mats.get_mat("metal"), Transform3D(Basis(), Vector3(0, cy + 1.6, DEPTH * 0.5)), Vector2(2.2, 2.2), 1.4, Color("#5e9a8c"))
	b.sphere(Mats.get_mat("metal"), Vector3(0, cy + 0.8, DEPTH * 0.5 - 0.9), Vector3(0.3, 0.35, 0.3), 4, 8, Color("#d4a63a"))
	# Entrance with steps, double doors and a canopy.
	var ex := -10.5
	b.box_mm(solid, Vector3(ex - 1.1, 0.6, -0.03), Vector3(ex + 1.1, 3.0, 0.02), Color("#2f6f8f"))
	b.box_mm(solid, Vector3(ex - 0.03, 0.6, -0.05), Vector3(ex + 0.03, 3.0, 0.0), Color("#244f66"))
	b.box_mm(solid, Vector3(ex - 1.5, 3.1, -1.6), Vector3(ex + 1.5, 3.3, 0.0), Mats.TRIM)
	for s in 3:
		b.box_mm(stone, Vector3(ex - 1.6, 0, -1.6 + s * 0.4), Vector3(ex + 1.6, 0.6 - s * 0.2, 0.0), Color("#d6cdbd"))
	# Schoolyard surface and painted games.
	b.box_mm(Mats.get_mat("asphalt"), Vector3(-20, 0.0, -34), Vector3(20, 0.025, -0.1), Color(1.05, 1.03, 1.0), 4)
	var paint_c := [Color("#f2c14e"), Color("#e8546a"), Color("#6fb4e8"), Color("#fbf8f0")]
	for k in 8:
		var hz := -6.0 - k * 1.0
		var cols := 2 if k in [2, 5] else 1
		for c in cols:
			var hx := 6.0 + (c - (cols - 1) * 0.5) * 1.0
			b.box_mm(solid, Vector3(hx - 0.45, 0.026, hz - 0.45), Vector3(hx + 0.45, 0.03, hz + 0.45), paint_c[k % paint_c.size()], 4)
	b.cylinder(solid, Transform3D(Basis(), Vector3(-6, 0.026, -14)), 3.0, 3.0, 0.005, 24, Color("#fbf8f0"), true)
	b.cylinder(Mats.get_mat("asphalt"), Transform3D(Basis(), Vector3(-6, 0.027, -14)), 2.85, 2.85, 0.005, 24, Color.WHITE, true)
	# Flagpole with a flag.
	var fp := Vector3(8.0, 0, -12.0)
	b.cylinder(stone, Transform3D(Basis(), fp), 0.4, 0.4, 0.3, 8, Color("#d6cdbd"))
	b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(), fp), 0.06, 0.04, 8.5, 6, Color("#d8d8d8"))
	b.sphere(Mats.get_mat("metal"), fp + Vector3(0, 8.55, 0), Vector3(0.12, 0.12, 0.12), 3, 6, Color("#d4a63a"))
	var fl := Mats.get_mat("cloth_wind")
	for k in 5:
		var c := Color("#c8423b") if k % 2 == 0 else Color("#fbf8f0")
		var y0 := 7.0 + k * 0.24
		b.quad(fl, fp + Vector3(0.05, y0, 0), fp + Vector3(1.8, y0 + 0.05 * sin(k), 0.15), fp + Vector3(1.8, y0 + 0.24 + 0.05 * sin(k + 1), 0.15), fp + Vector3(0.05, y0 + 0.24, 0), c)
	b.quad(fl, fp + Vector3(0.05, 7.6, 0.01), fp + Vector3(0.75, 7.62, 0.06), fp + Vector3(0.75, 8.2, 0.06), fp + Vector3(0.05, 8.2, 0.01), Color("#2f5fa8"))
	# Swing set.
	var sw := Vector3(13.0, 0, -23.0)
	var metal := Mats.get_mat("metal")
	for sx in [-2.2, 2.2]:
		for sz in [-0.9, 0.9]:
			b.tube(metal, PackedVector3Array([sw + Vector3(sx, 0, sz), sw + Vector3(sx, 2.6, 0)]), 0.05, 6, Color("#e0a13a"))
	b.tube(metal, PackedVector3Array([sw + Vector3(-2.2, 2.6, 0), sw + Vector3(2.2, 2.6, 0)]), 0.06, 6, Color("#e0a13a"))
	for seat_x in [-1.0, 1.0]:
		for rx in [-0.22, 0.22]:
			b.tube(Mats.get_mat("rope"), PackedVector3Array([sw + Vector3(seat_x + rx, 2.6, 0), sw + Vector3(seat_x + rx, 0.55, 0)]), 0.015, 4, Color("#9aa3a8"))
		b.box_mm(solid, sw + Vector3(seat_x - 0.3, 0.5, -0.15), sw + Vector3(seat_x + 0.3, 0.56, 0.15), Color("#c8423b"))
	# Basketball hoop.
	var hp := Vector3(-16.0, 0, -8.0)
	b.cylinder(metal, Transform3D(Basis(), hp), 0.08, 0.08, 3.4, 8, Color("#2f6f8f"))
	b.box_mm(solid, hp + Vector3(-0.9, 3.0, 0.15), hp + Vector3(0.9, 4.1, 0.22), Color("#fbf8f0"))
	b.box_mm(solid, hp + Vector3(-0.3, 3.15, 0.14), hp + Vector3(0.3, 3.55, 0.15), Color("#c8423b"))
	b.tube(metal, PackedVector3Array([hp + Vector3(-0.23, 3.05, -0.05), hp + Vector3(0, 3.05, -0.3), hp + Vector3(0.23, 3.05, -0.05), hp + Vector3(0, 3.05, 0.14), hp + Vector3(-0.23, 3.05, -0.05)]), 0.02, 4, Color("#e8873a"))
	# Climbing frame.
	var cf := Vector3(14.0, 0, -12.0)
	for gx in 4:
		for gz in 3:
			b.cylinder(metal, Transform3D(Basis(), cf + Vector3(-1.5 + gx, 0, -1.0 + gz)), 0.04, 0.04, 2.0, 6, Color("#3f7d4f"))
	for gy in 3:
		var y := 0.6 + gy * 0.7
		for gz in 3:
			b.tube(metal, PackedVector3Array([cf + Vector3(-1.5, y, -1.0 + gz), cf + Vector3(1.5, y, -1.0 + gz)]), 0.035, 4, Color("#e8546a"))
		for gx in 4:
			b.tube(metal, PackedVector3Array([cf + Vector3(-1.5 + gx, y, -1.0), cf + Vector3(-1.5 + gx, y, 1.0)]), 0.035, 4, Color("#6fb4e8"))
	# Bike rack.
	for k in 5:
		var bx2 := -18.0 + k * 0.7
		b.tube(metal, PackedVector3Array([Vector3(bx2, 0, -2.5), Vector3(bx2, 0.8, -2.5), Vector3(bx2, 0.8, -1.7), Vector3(bx2, 0, -1.7)]), 0.03, 4, Color("#9aa3a8"))


func _after_build() -> void:
	# School sign and chalkboard writing.
	var sign_label := Label3D.new()
	sign_label.text = "Linden Primary School"
	sign_label.font = UIKit.display_font()
	sign_label.font_size = 140
	sign_label.pixel_size = 0.008
	sign_label.modulate = Color("#fbf3dc")
	sign_label.outline_modulate = Color("#3a2c28")
	sign_label.outline_size = 18
	sign_label.position = Vector3(0, 3.35, -0.05)
	sign_label.rotation.y = PI
	sign_label.shaded = false
	add_child(sign_label)
	var chalk := Label3D.new()
	chalk.text = "Paper planes 101\n1. Fold    2. Throw    3. Glide home!"
	chalk.font = UIKit.display_font()
	chalk.font_size = 64
	chalk.pixel_size = 0.0065
	chalk.modulate = Color(0.95, 0.95, 0.9, 0.9)
	chalk.position = Vector3(ROOM_X - 0.1, 5.75, 7.0)
	chalk.rotation.y = -PI * 0.5
	chalk.shaded = false
	add_child(chalk)
	# Warm classroom light.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffe2b8")
	lamp.light_energy = 0.9
	lamp.omni_range = 11.0
	lamp.position = Vector3(0, CEILING_Y - 0.6, 7.0)
	add_child(lamp)
	# Ceiling fan (spins; hitting it is a crash).
	_fan = Node3D.new()
	_fan.name = "CeilingFan"
	_fan.position = FAN_POS
	var fb := MeshBuilder.new()
	var metal := Mats.get_mat("metal")
	fb.cylinder(metal, Transform3D(Basis(), Vector3(0, 0.0, 0)), 0.03, 0.03, CEILING_Y - FAN_POS.y, 6, Color("#e6e0d2"))
	fb.cylinder(metal, Transform3D(Basis(), Vector3(0, -0.12, 0)), 0.16, 0.12, 0.16, 10, Color("#e6e0d2"))
	for k in 4:
		var a := TAU * k / 4.0
		fb.box(Mats.get_mat("wood"), Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 0.6, -0.06, -sin(a) * 0.6)), Vector3(0.95, 0.02, 0.2), Color("#a87a4f"))
	var fan_mesh := MeshInstance3D.new()
	fan_mesh.mesh = fb.build()
	_fan.add_child(fan_mesh)
	add_child(_fan)
	# Schoolyard props.
	for p in [Vector3(-14.0, 0, -18.0), Vector3(-3.0, 0, -28.0), Vector3(17.0, 0, -30.0)]:
		inst("bench", Transform3D(Basis(Vector3.UP, PI), p))
	for p in [Vector3(-19.0, 0, -4.0), Vector3(19.0, 0, -4.0)]:
		inst("bush", Transform3D(Basis().scaled(Vector3(1.4, 1.2, 1.4)), p), Color("#5f8f45"))
	# Picket fence around the yard, open toward the lane.
	for seg in _fence_segments():
		var a: Vector3 = seg[0]
		var c: Vector3 = seg[1]
		var n := int(a.distance_to(c) / 0.17)
		var yaw := atan2(c.x - a.x, c.z - a.z) + PI * 0.5
		for k in n:
			inst("picket", Transform3D(Basis(Vector3.UP, yaw), a.lerp(c, (k + 0.5) / n)))


func _fence_segments() -> Array:
	return [
		[Vector3(-20, 0, -34), Vector3(-6.5, 0, -34)],
		[Vector3(6.5, 0, -34), Vector3(20, 0, -34)],
		[Vector3(-20, 0, -34), Vector3(-20, 0, -0.5)],
		[Vector3(20, 0, -34), Vector3(20, 0, -0.5)],
	]


func _process(delta: float) -> void:
	if _fan:
		_fan.rotation.y += delta * 5.0


func _build_colliders() -> void:
	var hw := WIDTH * 0.5
	add_box("wall", Vector3(0, FLOOR_Y * 0.5, DEPTH * 0.5), Vector3(WIDTH, FLOOR_Y, DEPTH))
	add_box("wall", Vector3((-hw - ROOM_X - 0.3) * 0.5, (FLOOR_Y + ROOF_Y) * 0.5, DEPTH * 0.5), Vector3(hw - ROOM_X - 0.3, ROOF_Y - FLOOR_Y, DEPTH))
	add_box("wall", Vector3((hw + ROOM_X + 0.3) * 0.5, (FLOOR_Y + ROOF_Y) * 0.5, DEPTH * 0.5), Vector3(hw - ROOM_X - 0.3, ROOF_Y - FLOOR_Y, DEPTH))
	add_box("wall", Vector3(0, (FLOOR_Y + ROOF_Y) * 0.5, (ROOM_Z1 + DEPTH) * 0.5), Vector3(ROOM_X * 2.0 + 0.6, ROOF_Y - FLOOR_Y, DEPTH - ROOM_Z1))
	add_box("wall", Vector3(0, (CEILING_Y + ROOF_Y + 0.3) * 0.5, DEPTH * 0.5), Vector3(WIDTH, ROOF_Y + 0.3 - CEILING_Y, DEPTH))
	add_convex("wall", PackedVector3Array([
		Vector3(-hw - 0.2, ROOF_Y + 0.3, -0.2), Vector3(hw + 0.2, ROOF_Y + 0.3, -0.2),
		Vector3(-hw - 0.2, ROOF_Y + 0.3, DEPTH + 0.2), Vector3(hw + 0.2, ROOF_Y + 0.3, DEPTH + 0.2),
		Vector3(0, ROOF_Y + 3.7, DEPTH * 0.5)]))
	add_box("wall", Vector3(0, ROOF_Y + 3.4, DEPTH * 0.5), Vector3(2.0, 2.4, 2.0))
	for seg in _front_segments():
		var c := Vector3((seg[0] + seg[1]) * 0.5, (seg[2] + seg[3]) * 0.5, 0.15)
		add_box("wall", c, Vector3(seg[1] - seg[0], seg[3] - seg[2], 0.3))
	for w in WINDOWS:
		if not w[2]:
			add_box("glass", Vector3((w[0] + w[1]) * 0.5, (SILL_Y + HEAD_Y) * 0.5, 0.15), Vector3(w[1] - w[0], HEAD_Y - SILL_Y, 0.3))
	for p: Vector3 in _desk_positions():
		add_box("desk", p + Vector3(0, 0.375, 0), Vector3(0.7, 0.75, 1.0))
	add_box("desk", Vector3(6.2, FLOOR_Y + 0.42, 7.0), Vector3(1.1, 0.84, 2.1))
	add_box("desk", Vector3(-5.5, FLOOR_Y + 0.8, ROOM_Z1 - 0.37), Vector3(2.4, 1.6, 0.4))
	add_cylinder("fan", FAN_POS + Vector3(0, -0.2, 0), 1.07, 0.16)
	add_cylinder("fan", FAN_POS + Vector3(0, -0.04, 0), 0.04, CEILING_Y - FAN_POS.y + 0.04)
	# Schoolyard.
	add_cylinder("post", Vector3(8.0, 0, -12.0), 0.07, 8.6)
	add_box("post", Vector3(8.9, 7.6, -11.92), Vector3(1.75, 1.2, 0.1))
	# Swing set frame: top bar and the four legs.
	var sw := Vector3(13.0, 0, -23.0)
	add_box("post", sw + Vector3(0, 2.6, 0), Vector3(4.5, 0.12, 0.12))
	for sx in [-2.2, 2.2]:
		for sz in [-0.9, 0.9]:
			var foot: Vector3 = sw + Vector3(sx, 0, sz)
			var top: Vector3 = sw + Vector3(sx, 2.6, 0)
			var mid := (foot + top) * 0.5
			var leg := top - foot
			add_box_xf("post", Transform3D(Basis(Vector3.RIGHT, atan2(leg.z, leg.y)), mid), Vector3(0.1, leg.length(), 0.1))
	add_cylinder("post", Vector3(-16.0, 0, -8.0), 0.08, 4.1)
	add_box("post", Vector3(-16.0, 3.55, -7.82), Vector3(1.8, 1.1, 0.08))
	# Climbing frame: the bars themselves, with the gaps between them left open.
	var cf := Vector3(14.0, 0, -12.0)
	for gx in 4:
		for gz in 3:
			add_cylinder("post", cf + Vector3(-1.5 + gx, 0, -1.0 + gz), 0.04, 2.0)
	for gy in 3:
		var y := 0.6 + gy * 0.7
		for gz in 3:
			add_box("post", cf + Vector3(0, y, -1.0 + gz), Vector3(3.0, 0.07, 0.07))
		for gx in 4:
			add_box("post", cf + Vector3(-1.5 + gx, y, 0), Vector3(0.07, 0.07, 2.0))
	for seg in _fence_segments():
		var a: Vector3 = seg[0]
		var c2: Vector3 = seg[1]
		var mid := (a + c2) * 0.5 + Vector3(0, 0.5, 0)
		var size := Vector3(maxf(absf(c2.x - a.x), 0.08), 0.95, maxf(absf(c2.z - a.z), 0.08))
		add_box("fence", mid - Vector3(0, 0.025, 0), size)
