extends Prop
## Painterly cottage (art style prototype). The same kind of two-storey lane house as house.gd,
## but shaped by hand: every part is a soft rounded box with slightly wobbly, tapered sides. The
## upper floor juts out over the lower one, the thick roof sags a little along the ridge, the
## chimney leans, the door is arched in stone, ivy climbs one corner and the picket fence is a
## bit crooked. Origin = ground level at the center of the front facade; the facade faces +Z.

@export var width := 9.6
@export var depth := 8.0
@export var wall_color := Color("#e9b7a1")
@export var lower_color := Color("#f3e3c6")
@export var roof_color := Color("#b8644a")
@export var door_color := Color("#3f7d6f")
@export var shutter_color := Color("#3f6f8f")
@export var door_offset := -0.9
@export var yard_depth := 7.0
@export var seed_value := 1

const PLINTH := 0.6
const LOWER_H := 3.1
const UPPER_H := 2.9
const JETTY := 0.3
const RISE := 3.8
const TRIM := Color("#f6eedc")

var _rng := RandomNumberGenerator.new()
var _piece := 0


func _build(b: MeshBuilder) -> void:
	_rng.seed = seed_value
	var stone := Mats.get_mat("stone")
	var wood := Mats.get_mat("wood")
	var solid := Mats.get_mat("solid")
	var hw := width * 0.5
	var zc := -depth * 0.5
	var y1 := PLINTH + LOWER_H
	var uw := width + 0.4
	var ud := depth + JETTY * 2.0
	var top := y1 + UPPER_H + 0.1

	# Stone plinth, plastered ground floor, the timber beam and the jutting upper floor.
	_soft(b, stone, _at(0, PLINTH * 0.5 - 0.05, zc), Vector3(width + 0.35, PLINTH + 0.1, depth + 0.35), 0.2, Color("#cdbfa9"), 0.0, 0.0, 0.05)
	_soft(b, Mats.get_mat("plaster"), _at(0, PLINTH + LOWER_H * 0.5 - 0.05, zc), Vector3(width, LOWER_H + 0.1, depth), 0.25, lower_color, 0.015, 0.0, 0.03)
	_soft(b, wood, _at(0, y1, zc), Vector3(width + 0.5, 0.32, depth + 0.5), 0.12, Color("#8a5a3c"), 0.0, 0.04, 0.03)
	_soft(b, Mats.get_mat("paint"), _at(0, y1 + 0.1 + UPPER_H * 0.5, zc), Vector3(uw, UPPER_H, ud), 0.22, wall_color, -0.012, 0.0, 0.03)

	# Gable ends.
	var paint := Mats.get_mat("paint")
	for s in [-1.0, 1.0]:
		var x: float = s * (uw * 0.5 - 0.03)
		_poly_out(b, paint, [Vector3(x, top - 0.25, zc - ud * 0.5 + 0.05), Vector3(x, top - 0.25, zc + ud * 0.5 - 0.05),
			Vector3(x, top + RISE - 0.1, zc)], wall_color, Vector3(s, 0, 0))
		# Round attic window.
		var ax := Basis(Vector3.BACK, -s * PI * 0.5)
		b.cylinder(Mats.get_mat("window_lit"), Transform3D(ax, Vector3(s * (uw * 0.5 - 0.02), top + RISE * 0.32, zc)), 0.34, 0.34, 0.08, 14, Color("#3d5a78"))
		b.cylinder(solid, Transform3D(ax, Vector3(s * (uw * 0.5 - 0.05), top + RISE * 0.32, zc)), 0.46, 0.46, 0.1, 14, TRIM)

	# Thick roof that sags a little along the ridge, with deep soft eaves and a rounded ridge cap.
	var shingle := Mats.get_mat("shingle")
	var over := 0.85
	var run := ud * 0.5 + over
	var ang := atan2(RISE, ud * 0.5)
	var slope_len := run / cos(ang) + 0.3
	var thick := 0.45
	var roof_len := uw + 1.1
	var ridge := Vector3(0, top + RISE, zc)
	for s in [1.0, -1.0]:
		var basis := Basis(Vector3.RIGHT, s * ang)
		var down: Vector3 = basis * Vector3(0, 0, s)
		var up: Vector3 = basis * Vector3.UP
		var c: Vector3 = ridge + down * (slope_len * 0.5 - 0.3) + up * (thick * 0.5)
		_soft(b, shingle, Transform3D(basis, c), Vector3(roof_len, thick, slope_len), 0.2, roof_color, 0.0, 0.16, 0.05)
	_soft(b, shingle, _at(0, ridge.y + thick * 0.8, zc), Vector3(roof_len + 0.1, 0.38, 0.75), 0.17, roof_color.darkened(0.18), 0.0, 0.16, 0.03)
	_dormer(b, hw * 0.42, zc, top, ang, ud)

	# Leaning brick chimney with a stone cap and a pot.
	var ch_bottom := top - 0.6
	var ch_top := top + RISE + 1.5
	var lean := Basis(Vector3.BACK, -0.05) * Basis(Vector3.RIGHT, 0.03)
	var ch_c := Vector3(hw - 1.4, (ch_bottom + ch_top) * 0.5, zc - 1.6)
	_soft(b, Mats.get_mat("brick"), Transform3D(lean, ch_c), Vector3(1.1, ch_top - ch_bottom, 1.1), 0.12, Color("#f0d6c6"), 0.1, 0.0, 0.04)
	var cap := ch_c + lean * Vector3(0, (ch_top - ch_bottom) * 0.5 + 0.08, 0)
	_soft(b, stone, Transform3D(lean, cap), Vector3(1.25, 0.24, 1.25), 0.08, Color("#d8cdbb"), 0.0, 0.0, 0.02)
	b.cylinder(solid, Transform3D(lean, cap + lean * Vector3(0.12, 0.1, 0.05)), 0.2, 0.16, 0.5, 10, Color("#c46a48"), true, true)

	_door(b)

	# Windows: chunky frames, sills, crooked shutters and flower boxes.
	var ly := PLINTH + LOWER_H * 0.5 + 0.15
	var uy := y1 + 0.1 + UPPER_H * 0.5 + 0.05
	for x in [-3.4, 2.6]:
		_window(b, _at(x, ly, 0.0), true)
	for x in [-3.0, 0.0, 3.0]:
		_window(b, _at(x, uy, JETTY), true)
	for s in [-1.0, 1.0]:
		var side := Basis(Vector3.UP, s * PI * 0.5)
		_window(b, Transform3D(side, Vector3(s * hw, ly, zc)), false)
		_window(b, Transform3D(side, Vector3(s * uw * 0.5, uy, zc)), false)
	var back := Basis(Vector3.UP, PI)
	for x in [-2.4, 2.4]:
		_window(b, Transform3D(back, Vector3(x, ly, -depth)), false)
		_window(b, Transform3D(back, Vector3(x, uy, -depth - JETTY)), false)

	_path_and_fence(b)


## The little gabled dormer on the front slope of the roof.
func _dormer(b: MeshBuilder, dx: float, zc: float, top: float, ang: float, ud: float) -> void:
	var zf := zc + ud * 0.5 * 0.58
	var y_bot := top + RISE - tan(ang) * (zf - zc) - 0.15
	var dh := 1.75
	var dw := 1.9
	var z0 := zc + 0.2
	_soft(b, Mats.get_mat("paint"), _at(dx, y_bot + dh * 0.5, (z0 + zf) * 0.5), Vector3(dw, dh, zf - z0), 0.12, wall_color, 0.0, 0.0, 0.025)
	var gy := y_bot + dh
	var dang := 0.62
	var drise := tan(dang) * dw * 0.5
	_poly_out(b, Mats.get_mat("paint"), [Vector3(dx - dw * 0.5, gy - 0.05, zf - 0.02), Vector3(dx + dw * 0.5, gy - 0.05, zf - 0.02),
		Vector3(dx, gy + drise, zf - 0.02)], wall_color, Vector3.BACK)
	var dridge := Vector3(dx, gy + drise, (z0 + zf + 0.4) * 0.5)
	var dlen := (dw * 0.5 + 0.4) / cos(dang) + 0.1
	for s in [1.0, -1.0]:
		var basis := Basis(Vector3.BACK, -s * dang)
		var down: Vector3 = basis * Vector3(s, 0, 0)
		var up: Vector3 = basis * Vector3.UP
		_soft(b, Mats.get_mat("shingle"), Transform3D(basis, dridge + down * (dlen * 0.5 - 0.1) + up * 0.12),
			Vector3(dlen, 0.24, zf - z0 + 0.45), 0.1, roof_color, 0.0, 0.0, 0.025)
	_window(b, _at(dx, y_bot + dh * 0.5 - 0.05, zf), false, 0.75)


func _door(b: MeshBuilder) -> void:
	var solid := Mats.get_mat("solid")
	var stone := Mats.get_mat("stone")
	var dx := door_offset
	var dy := PLINTH
	_soft(b, solid, _at(dx, dy + 1.0, 0.02), Vector3(1.1, 2.0, 0.14), 0.04, door_color, 0.0, 0.0, 0.006, false)
	b.cylinder(solid, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(dx, dy + 2.0, -0.05)), 0.55, 0.55, 0.14, 16, door_color)
	# Plank grooves and a brass knob.
	for gx in [-0.27, 0.0, 0.27]:
		var gh := 2.0 + sqrt(0.55 * 0.55 - gx * gx) - 0.08
		b.box(solid, Transform3D(Basis(), Vector3(dx + gx, dy + 0.05 + gh * 0.5, 0.095)), Vector3(0.035, gh, 0.02), door_color.darkened(0.3))
	b.sphere(Mats.get_mat("metal"), Vector3(dx + 0.36, dy + 1.05, 0.15), Vector3(0.065, 0.065, 0.065), 4, 8, Color("#e0b24a"))
	# Stone arch: wedge stones around the top, uneven blocks down the sides.
	var n := 9
	for i in n:
		var a := PI * (i + 0.5) / n
		var p := Vector3(dx + cos(a) * 0.76, dy + 2.0 + sin(a) * 0.76, 0.06)
		var col := Color("#d9cdb8").darkened(_rng.randf_range(0.0, 0.12))
		_soft(b, stone, Transform3D(Basis(Vector3.BACK, a - PI * 0.5), p), Vector3(0.27, 0.36, 0.22), 0.06, col, 0.0, 0.0, 0.015, false)
	for s in [-1.0, 1.0]:
		var y := dy
		var k := 0
		while y < dy + 1.95:
			var hh := _rng.randf_range(0.34, 0.44)
			var ww := 0.38 if k % 2 == 0 else 0.28
			var col := Color("#d9cdb8").darkened(_rng.randf_range(0.0, 0.12))
			_soft(b, stone, _at(dx + s * (0.58 + ww * 0.5), y + hh * 0.5, 0.06), Vector3(ww, hh - 0.03, 0.22), 0.06, col, 0.0, 0.0, 0.015, false)
			y += hh
			k += 1
	# Steps and a little shingled canopy on brackets.
	_soft(b, stone, _at(dx, 0.16, 0.7), Vector3(1.9, 0.32, 0.8), 0.1, Color("#cfc3ae"), 0.0, 0.0, 0.025, false)
	_soft(b, stone, _at(dx, 0.44, 0.32), Vector3(1.6, 0.3, 0.55), 0.1, Color("#d6cab6"), 0.0, 0.0, 0.025, false)
	var cy := dy + 2.95
	_soft(b, Mats.get_mat("shingle"), Transform3D(Basis(Vector3.RIGHT, 0.32), Vector3(dx, cy, 0.5)), Vector3(2.2, 0.18, 1.15), 0.08, roof_color, 0.0, 0.05, 0.02)
	for s in [-1.0, 1.0]:
		_soft(b, Mats.get_mat("wood"), Transform3D(Basis(Vector3.RIGHT, -0.75), Vector3(dx + s * 0.95, cy - 0.35, 0.28)), Vector3(0.12, 0.7, 0.12), 0.04, Color("#8a5a3c"), 0.0, 0.0, 0.0, false)


## A window on a wall surface; `xf` faces local +Z at the wall surface.
func _window(b: MeshBuilder, xf: Transform3D, flowers: bool, scale := 1.0) -> void:
	var solid := Mats.get_mat("solid")
	var w := 1.0 * scale
	var h := 1.3 * scale
	b.box(Mats.get_mat("window_lit"), xf * Transform3D(Basis(), Vector3(0, 0, 0.05)), Vector3(w, h, 0.06), Color("#3d5a78"))
	_soft(b, solid, xf * _at(0, h * 0.5 + 0.06, 0.1), Vector3(w + 0.32, 0.16, 0.18), 0.06, TRIM, 0.0, 0.0, 0.012, false)
	for s in [-1.0, 1.0]:
		_soft(b, solid, xf * _at(s * (w * 0.5 + 0.06), 0, 0.1), Vector3(0.14, h + 0.18, 0.17), 0.05, TRIM, 0.0, 0.0, 0.01, false)
	var tilt := Basis(Vector3.BACK, _rng.randf_range(-0.03, 0.03))
	_soft(b, solid, xf * Transform3D(tilt, Vector3(0, -h * 0.5 - 0.07, 0.15)), Vector3(w + 0.5, 0.14, 0.34), 0.05, TRIM, 0.0, 0.0, 0.012, false)
	b.box(solid, xf * Transform3D(Basis(), Vector3(0, 0, 0.09)), Vector3(0.06, h, 0.05), TRIM)
	b.box(solid, xf * Transform3D(Basis(), Vector3(0, 0.05 * scale, 0.09)), Vector3(w, 0.06, 0.05), TRIM)
	# Shutters, each hung a little crooked.
	for s in [-1.0, 1.0]:
		var sb := Basis(Vector3.UP, s * _rng.randf_range(0.04, 0.16)) * Basis(Vector3.BACK, _rng.randf_range(-0.02, 0.02))
		var col := shutter_color.lightened(_rng.randf_range(-0.05, 0.08))
		_soft(b, solid, xf * Transform3D(sb, Vector3(s * (w * 0.5 + 0.38 * scale), 0, 0.1)), Vector3(0.46 * scale, h + 0.04, 0.08), 0.05, col, 0.0, 0.0, 0.01, false)
	if flowers:
		_soft(b, Mats.get_mat("wood"), xf * _at(0, -h * 0.5 - 0.3, 0.3), Vector3(w + 0.25, 0.28, 0.3), 0.06, Color("#9c6b4a"), 0.0, 0.0, 0.015, false)
		for i in 3:
			var fx := (i - 1) * (w + 0.1) * 0.33
			var col := Mats.pick(_rng, Mats.FLOWER_COLORS)
			var lx := xf * _at(fx, -h * 0.5 - 0.22, 0.3)
			inst("bush", Transform3D(lx.basis.scaled(Vector3(0.42, 0.42, 0.42)), lx.origin), col.lerp(Color("#6f9e4c"), 0.25))


func _path_and_fence(b: MeshBuilder) -> void:
	var stone := Mats.get_mat("stone")
	var solid := Mats.get_mat("solid")
	var hw := width * 0.5
	var dx := door_offset
	# Stepping stones to the gate.
	var z := 1.45
	var k := 0
	while z < yard_depth - 0.2:
		var px := dx + (0.22 if k % 2 == 0 else -0.2) + _rng.randf_range(-0.08, 0.08)
		var col := Color("#d4c9b6").darkened(_rng.randf_range(0.0, 0.1))
		_soft(b, stone, Transform3D(Basis(Vector3.UP, _rng.randf_range(-0.4, 0.4)), Vector3(px, 0.0, z)), Vector3(_rng.randf_range(0.75, 0.95), 0.14, _rng.randf_range(0.55, 0.7)), 0.07, col, 0.0, 0.0, 0.02, false)
		z += 0.78
		k += 1
	# Crooked picket fence.
	var fz := yard_depth - 0.4
	for seg: Vector2 in [Vector2(-hw - 2.0, dx - 0.75), Vector2(dx + 0.75, hw + 2.0)]:
		var x := seg.x + 0.12
		while x < seg.y - 0.1:
			var ph := _rng.randf_range(0.86, 1.0)
			var lean := Basis(Vector3.BACK, _rng.randf_range(-0.06, 0.06)) * Basis(Vector3.RIGHT, _rng.randf_range(-0.04, 0.04))
			_soft(b, solid, Transform3D(lean, Vector3(x, ph * 0.5, fz)), Vector3(0.11, ph, 0.05), 0.045, TRIM.darkened(_rng.randf_range(0.0, 0.08)), 0.2, 0.0, 0.0, false)
			x += 0.24
		var mid := (seg.x + seg.y) * 0.5
		for ry in [0.32, 0.7]:
			_soft(b, solid, _at(mid, ry, fz - 0.05), Vector3(seg.y - seg.x, 0.08, 0.05), 0.03, TRIM.darkened(0.06), 0.0, 0.03, 0.01, false)
		for px in [seg.x, seg.y]:
			_soft(b, solid, _at(px, 0.58, fz), Vector3(0.17, 1.16, 0.17), 0.06, TRIM, 0.08, 0.0, 0.01, false)


func _after_build() -> void:
	var hw := width * 0.5
	var greens := [Color("#4f7f3f"), Color("#5f8f45"), Color("#6f9e4c"), Color("#3f6f3a")]
	# Ivy climbing the front left corner, spreading wider near the ground.
	var y := 0.3
	while y < PLINTH + LOWER_H + UPPER_H - 0.4:
		var t := y / (PLINTH + LOWER_H + UPPER_H)
		var s := lerpf(1.25, 0.7, t) * _rng.randf_range(0.85, 1.1)
		var xo := -hw + (0.2 if y > PLINTH + LOWER_H else 0.0)
		var spread := lerpf(1.4, 0.5, t)
		for k in 2:
			inst("bush", Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * 0.8, s * 0.45)), Vector3(xo + _rng.randf_range(0.0, spread), y - 0.35, 0.12)), greens[_rng.randi() % 4])
			inst("bush", Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3(s, s * 0.8, s * 0.45)), Vector3(xo - 0.12, y - 0.35, -_rng.randf_range(0.0, spread))), greens[_rng.randi() % 4])
		y += 0.45
	# Big bushes and flowering shrubs along the front.
	for bx in [-4.3, -2.1, 1.2, 4.2]:
		var s := _rng.randf_range(1.5, 1.9)
		inst("bush", Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * 0.85, s)), Vector3(bx, 0.0, 0.9)), greens[_rng.randi() % 4])
	for bx in [-2.6, 0.5, 3.3]:
		var col := Mats.pick(_rng, Mats.FLOWER_COLORS)
		inst("bush", Transform3D(Basis().scaled(Vector3(0.9, 0.8, 0.9)), Vector3(bx, 0.0, 1.6)), col)
	var fz := yard_depth - 0.4
	for i in 30:
		var fx := _rng.randf_range(-hw - 1.8, hw + 1.8)
		if absf(fx - door_offset) < 1.0:
			continue
		inst("flower", Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * 1.4), Vector3(fx, 0, fz - 0.35 - _rng.randf() * 0.6)), Mats.pick(_rng, Mats.FLOWER_COLORS))


func _build_colliders() -> void:
	var zc := -depth * 0.5
	var top := PLINTH + LOWER_H + UPPER_H + 0.1
	add_box("wall", Vector3(0, top * 0.5, zc), Vector3(width + 0.4, top, depth + JETTY * 2.0))
	var hx := width * 0.5 + 0.75
	var hz := depth * 0.5 + JETTY + 0.85
	add_convex("wall", PackedVector3Array([
		Vector3(-hx, top - 0.6, zc - hz), Vector3(hx, top - 0.6, zc - hz), Vector3(-hx, top - 0.6, zc + hz), Vector3(hx, top - 0.6, zc + hz),
		Vector3(-hx, top + RISE + 0.6, zc), Vector3(hx, top + RISE + 0.6, zc),
	]))
	add_box("wall", Vector3(width * 0.5 - 1.4, top + RISE * 0.5 + 0.4, zc - 1.6), Vector3(1.2, RISE + 2.0, 1.2))
	add_box("fence", Vector3(0, 0.5, yard_depth - 0.4), Vector3(width + 4.0, 1.0, 0.1))


func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


## Polygon with the winding picked from the outward direction.
func _poly_out(b: MeshBuilder, mat: Material, pts: Array, col: Color, outward: Vector3) -> void:
	var arr := PackedVector3Array(pts)
	if (arr[1] - arr[0]).cross(arr[2] - arr[0]).dot(outward) < 0.0:
		arr.reverse()
	b.poly(mat, arr, col)


## A soft rounded box in the frame `xf`: edges rounded with radius `r`, `taper` narrows the top
## (fraction of the width), `sag` bows the top down along local X, and `wobble` pushes the surface
## in and out a little so nothing is perfectly straight. Slightly darker toward the bottom.
## `fine` uses more rounding steps and splits long flat sides so the wobble shows.
func _soft(b: MeshBuilder, mat: Material, xf: Transform3D, size: Vector3, r: float, col: Color,
		taper := 0.0, sag := 0.0, wobble := 0.025, fine := true) -> void:
	_piece += 1
	var ph := float(_piece) * 1.37 + seed_value
	var h := size * 0.5
	r = minf(r, minf(h.x, minf(h.y, h.z)) * 0.9)
	var inner := h - Vector3.ONE * r
	var band: Array = [0.268, 0.577] if fine else [0.414]
	var coords: Array = []
	for ax in 3:
		var c := PackedFloat32Array()
		c.append(-h[ax])
		for k in range(band.size() - 1, -1, -1):
			c.append(-inner[ax] - r * band[k])
		var n := clampi(int(inner[ax] * 2.0 / 1.2), 1, 10) if fine else 1
		for i in n + 1:
			c.append(lerpf(-inner[ax], inner[ax], float(i) / n))
		for k in band.size():
			c.append(inner[ax] + r * band[k])
		c.append(h[ax])
		coords.append(c)
	for ax in 3:
		var u := (ax + 1) % 3
		var v := (ax + 2) % 3
		var cu: PackedFloat32Array = coords[u]
		var cv: PackedFloat32Array = coords[v]
		for s in [-1.0, 1.0]:
			var grid := []
			for j in cv.size():
				var row := []
				for i in cu.size():
					var p := Vector3.ZERO
					p[ax] = s * h[ax]
					p[u] = cu[i]
					p[v] = cv[j]
					row.append(_soft_vertex(p, ax, h, inner, r, xf, taper, sag, wobble, ph, col))
				grid.append(row)
			for j in cv.size() - 1:
				for i in cu.size() - 1:
					_tri(b, mat, grid[j][i], grid[j][i + 1], grid[j + 1][i + 1])
					_tri(b, mat, grid[j][i], grid[j + 1][i + 1], grid[j + 1][i])


func _soft_vertex(p: Vector3, ax: int, h: Vector3, inner: Vector3, r: float, xf: Transform3D,
		taper: float, sag: float, wobble: float, ph: float, col: Color) -> Array:
	var c := p.clamp(-inner, inner)
	var n := (p - c).normalized()
	var q := c + n * r
	var yn := clampf((q.y + h.y) / (2.0 * h.y), 0.0, 1.0)
	q.x *= 1.0 - taper * yn
	q.z *= 1.0 - taper * yn
	if sag != 0.0:
		var t := q.x / h.x
		q.y -= sag * (1.0 - t * t)
	if wobble > 0.0:
		q += n * wobble * (sin(q.x * 1.7 + q.y * 0.9 + ph) * 0.5 + sin(q.z * 1.3 - q.y * 1.6 + ph * 1.7) * 0.35
			+ sin((q.x + q.z) * 3.1 + ph * 0.3) * 0.15)
	var shade := lerpf(0.86, 1.04, yn)
	var uv := Vector2(p.x, p.z) if ax == 1 else Vector2(p.z if ax == 0 else p.x, -p.y)
	return [xf * q, (xf.basis * n).normalized(), uv, Color(col.r * shade, col.g * shade, col.b * shade, col.a)]


func _tri(b: MeshBuilder, mat: Material, a: Array, c1: Array, c2: Array) -> void:
	var pa: Vector3 = a[0]
	var pb: Vector3 = c1[0]
	var pc: Vector3 = c2[0]
	var geo := (pb - pa).cross(pc - pa)
	if geo.length_squared() < 1e-10:
		return
	var nsum: Vector3 = a[1] + c1[1] + c2[1]
	# Front faces are clockwise in Godot, so add in the order that gives an inward cross product.
	var order := [a, c2, c1] if geo.dot(nsum) >= 0.0 else [a, c1, c2]
	var st := b._st(mat)
	for v in order:
		st.set_color(v[3])
		st.set_normal(v[1])
		st.set_uv(v[2])
		st.add_vertex(v[0])
