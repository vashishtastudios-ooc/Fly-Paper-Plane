extends Prop
## Thimble Mews (flight 10, Laundry Day): a narrow cobbled mews of tall townhouses running down the
## hill at the top of Linden Lane, behind its east side. North to south: the pigeon-loft house
## across the head of the mews (launch roof), terraces either side of stone steps, the tailor's
## bridge house spanning the mews (an open sewing room upstairs, a carriage arch below), more
## terraces, the squeeze (a 2.6 m gap between two houses), the clock-arch house, the laundry yard
## with its spinning rotary washing line, a glass walkway on stilts between the last terraces, and
## a little walled yard at the end. World coordinates (the prop sits at the origin).

## The mews' centre line and its half width (house fronts at AX -/+ AHW).
const AX := 33.0
const AHW := 3.0
## Terrace backs.
const BACK_W := 23.0
const BACK_E := 43.0
## Pigeon-loft house (launch): z range and its flat roof height above its ground.
const LOFT_Z0 := 108.0
const LOFT_Z1 := 98.0
const LOFT_H := 6.8
## Tailor's bridge house.
const BRIDGE_Z0 := 72.0
const BRIDGE_Z1 := 62.0
const UF := 3.6
const UC := 6.6
const BRIDGE_EAVE := 6.9
const ARCH_HW := 2.8
const ARCH_TOP := 3.2
## The squeeze.
const SQ_Z0 := 41.0
const SQ_Z1 := 25.0
const SQ_W := 32.2
const SQ_E := 34.8
## Clock-arch house.
const CLOCK_Z0 := 25.0
const CLOCK_Z1 := 15.0
const CLOCK_ARCH_HW := 1.6
const CLOCK_ARCH_TOP := 2.9
const CLOCK_LAMP := Vector3(33.0, 2.55, 20.0)
## Laundry yard (walls at x 26 and 40) and the rotary washing line in it.
const YARD_Z0 := 15.0
const YARD_Z1 := -6.0
const ROTARY := Vector3(33.0, 0.0, 4.0)
## Glass walkway on stilts.
const WALK_Z0 := -8.0
const WALK_Z1 := -30.0
const WALK_HW := 2.0
const WALK_FLOOR := 3.8
const WALK_ROOF := 6.2
const BASKETS := [Vector3(32.3, 5.0, -14.0), Vector3(33.7, 5.0, -22.0)]
## The end yard.
const END_Z0 := -66.0
const END_Z1 := -86.0
## Terraced stretches either side: [z_north, z_south, houses].
const TERRACES := [[97.0, 72.0, 4], [62.0, 41.0, 3], [-6.0, -66.0, 10]]

const WALLS := ["#e9b7a1", "#f2d58f", "#a9c9db", "#b9d6a8", "#e6c3da", "#f5f0e5", "#cbbbe8", "#f4c9a0", "#c9d8c0"]
const DOORS := ["#c8423b", "#2f6f8f", "#3f7d4f", "#e0a13a", "#7c4f9e", "#2d4f7c"]
const T := 0.25

var _rng := RandomNumberGenerator.new()
var _rotor: Node3D
var _rotor_body: StaticBody3D
var _vane: Node3D
var _lights: Array = []


func _draw_distance() -> float:
	return 360.0


static func gy(z: float) -> float:
	return Terrain.ground_height(AX, z)


func _build(b: MeshBuilder) -> void:
	_rng.seed = 1010
	_steps(b)
	_loft_house(b)
	var hi := 0
	for t in TERRACES:
		var z0: float = t[0]
		var z1: float = t[1]
		var n: int = t[2]
		var w := (z0 - z1) / n
		for k in n:
			var zc := z0 - w * (k + 0.5)
			for side in [-1.0, 1.0]:
				_terrace_house(b, side, zc, w, 3 if z0 > 90.0 or (hi + k) % 3 != 1 else 2, hi)
				hi += 1
	_bridge_house(b)
	_squeeze(b)
	_clock_house(b)
	_yard(b)
	_walkway(b)
	_end_yard(b)


# --- Shared pieces -------------------------------------------------------------------------

## Solid rectangles [x0, x1, y0, y1] of a wall around rectangular holes (holes must not overlap).
static func _rects(x0: float, x1: float, y0: float, y1: float, holes: Array) -> Array:
	var xs := [x0, x1]
	for h: Array in holes:
		xs.append(h[0])
		xs.append(h[1])
	xs.sort()
	var out := []
	for i in xs.size() - 1:
		var a: float = xs[i]
		var c: float = xs[i + 1]
		if c - a < 0.001:
			continue
		var col := holes.filter(func(h: Array) -> bool: return h[0] <= a + 0.001 and h[1] >= c - 0.001)
		col.sort_custom(func(p: Array, q: Array) -> bool: return p[2] < q[2])
		var y := y0
		for h: Array in col:
			if h[2] > y:
				out.append([a, c, y, h[2]])
			y = maxf(y, h[3])
		if y < y1:
			out.append([a, c, y, y1])
	return out


## A wall across the mews (in the XY plane) with holes [x0, x1, y0, y1, open]. z_out is the outer
## face, facing +1 (north) or -1 (south). Open holes get a frame; closed ones are windows.
func _wall_z(b: MeshBuilder, z_out: float, facing: float, x0: float, x1: float, y0: float, y1: float,
		holes: Array, out_col: Color, in_col: Color) -> void:
	var z_in := z_out - facing * T
	var z_mid := (z_out + z_in) * 0.5
	for r in _rects(x0, x1, y0, y1, holes):
		b.box_mm(_m("paint"), Vector3(r[0], r[2], minf(z_out, z_mid)), Vector3(r[1], r[3], maxf(z_out, z_mid)), out_col)
		b.box_mm(_m("plaster"), Vector3(r[0], r[2], minf(z_mid, z_in)), Vector3(r[1], r[3], maxf(z_mid, z_in)), in_col)
		add_box("wall", Vector3((r[0] + r[1]) * 0.5, (r[2] + r[3]) * 0.5, z_mid), Vector3(r[1] - r[0], r[3] - r[2], T))
	for h: Array in holes:
		_frame(b, h[0], h[1], h[2], h[3], z_out, z_in)
		if not h[4]:
			b.box_mm(_m("window_lit"), Vector3(h[0], h[2], z_mid - 0.02), Vector3(h[1], h[3], z_mid + 0.02), Color("#8fb8d6"))
			b.box_mm(_m("solid"), Vector3((h[0] + h[1]) * 0.5 - 0.03, h[2], z_mid - 0.05), Vector3((h[0] + h[1]) * 0.5 + 0.03, h[3], z_mid + 0.05), Mats.TRIM)
			add_box("glass", Vector3((h[0] + h[1]) * 0.5, (h[2] + h[3]) * 0.5, z_mid), Vector3(h[1] - h[0], h[3] - h[2], T))
		elif h[2] > 1.0:
			inst("flowerbox", Transform3D(Basis(Vector3.UP, 0.0 if facing > 0 else PI), Vector3((h[0] + h[1]) * 0.5, h[2] - 0.35, z_out + facing * 0.16)))


func _frame(b: MeshBuilder, x0: float, x1: float, y0: float, y1: float, z_out: float, z_in: float) -> void:
	var solid := _m("solid")
	var za := minf(z_out, z_in) - 0.03
	var zb := maxf(z_out, z_in) + 0.03
	for fx in [x0 - 0.09, x1]:
		b.box_mm(solid, Vector3(fx, y0, za), Vector3(fx + 0.09, y1 + 0.09, zb), Mats.TRIM)
	b.box_mm(solid, Vector3(x0 - 0.09, y1, za), Vector3(x1 + 0.09, y1 + 0.09, zb), Mats.TRIM)
	b.box_mm(solid, Vector3(x0 - 0.15, y0 - 0.1, za - 0.06), Vector3(x1 + 0.15, y0, zb + 0.06), Mats.TRIM)


func _m(kind: String) -> Material:
	return Mats.get_mat(kind)


## Gable roof with its ridge along Z over a block (centre x, z, eave height), and its collider.
func _roof_z(b: MeshBuilder, xc: float, zc: float, eave: float, width: float, length: float, rise: float, col: Color, wall_col: Color) -> void:
	var xf := Transform3D(Basis(), Vector3(xc, eave, zc))
	b.gable_roof(_m("shingle"), xf, width, length, rise, 0.3, 0.16, col)
	b.gable_wall(_m("paint"), xf, width, rise, length * 0.5, 1.0, wall_col)
	b.gable_wall(_m("paint"), xf, width, rise, -length * 0.5, -1.0, wall_col)
	var hw := width * 0.5 + 0.3
	var hl := length * 0.5
	add_convex("wall", PackedVector3Array([Vector3(xc - hw, eave, zc - hl), Vector3(xc + hw, eave, zc - hl), Vector3(xc - hw, eave, zc + hl),
		Vector3(xc + hw, eave, zc + hl), Vector3(xc, eave + rise + 0.15, zc - hl), Vector3(xc, eave + rise + 0.15, zc + hl)]))


## Gable roof with its ridge along X (spanning the mews).
func _roof_x(b: MeshBuilder, xc: float, zc: float, eave: float, span_x: float, depth_z: float, rise: float, col: Color, wall_col: Color) -> void:
	var xf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(xc, eave, zc))
	b.gable_roof(_m("shingle"), xf, depth_z, span_x, rise, 0.3, 0.16, col)
	b.gable_wall(_m("paint"), xf, depth_z, rise, span_x * 0.5, 1.0, wall_col)
	b.gable_wall(_m("paint"), xf, depth_z, rise, -span_x * 0.5, -1.0, wall_col)
	var hd := depth_z * 0.5 + 0.3
	var hs := span_x * 0.5
	add_convex("wall", PackedVector3Array([Vector3(xc - hs, eave, zc - hd), Vector3(xc + hs, eave, zc - hd), Vector3(xc - hs, eave, zc + hd),
		Vector3(xc + hs, eave, zc + hd), Vector3(xc - hs, eave + rise + 0.15, zc), Vector3(xc + hs, eave + rise + 0.15, zc)]))


## A batched window (with shutters) on a wall facing `face` (+-X or +-Z), centred at p.
func _win(face: Vector3, p: Vector3, shutter_col: Color, box := false) -> void:
	var basis := Basis(Vector3.UP, atan2(face.x, face.z))
	inst("window", Transform3D(basis, p + face * 0.02))
	inst("shutter", Transform3D(basis, p + face * 0.06 - basis.x * 0.76), shutter_col)
	inst("shutter", Transform3D(basis, p + face * 0.06 + basis.x * 0.76), shutter_col)
	if box:
		inst("flowerbox", Transform3D(basis, p + Vector3(0, -0.92, 0) + face * 0.14))


func _door(b: MeshBuilder, face: Vector3, p: Vector3, col: Color) -> void:
	var basis := Basis(Vector3.UP, atan2(face.x, face.z))
	b.box(_m("solid"), Transform3D(basis, p + Vector3(0, 1.1, 0) + face * 0.04), Vector3(1.1, 2.2, 0.08), col)
	b.box(_m("solid"), Transform3D(basis, p + Vector3(0, 1.2, 0) + face * 0.02), Vector3(1.4, 2.45, 0.05), Mats.TRIM)
	b.sphere(_m("metal"), p + Vector3(0, 1.05, 0) + face * 0.1 + basis.x * 0.35, Vector3(0.04, 0.04, 0.04), 3, 6, Color("#e0b24a"))
	b.box(_m("stone"), Transform3D(basis, p + Vector3(0, -0.08, 0) + face * 0.3), Vector3(1.6, 0.2, 0.6), Color("#d6cdbd"))


func _drainpipe(b: MeshBuilder, x: float, z: float, y0: float, y1: float) -> void:
	b.cylinder(_m("metal"), Transform3D(Basis(), Vector3(x, y0, z)), 0.06, 0.06, y1 - y0, 6, Color("#4a4f55"))
	b.cylinder(_m("metal"), Transform3D(Basis(), Vector3(x, y1 - 0.25, z)), 0.11, 0.06, 0.25, 6, Color("#4a4f55"))


# --- The street -------------------------------------------------------------------------------

## Cobbles down the mews: stone steps where it runs down the hill, flat cobbles below.
func _steps(b: MeshBuilder) -> void:
	var cobble := _m("cobble")
	var stone := _m("stone")
	var z := LOFT_Z1
	while z > END_Z1:
		var z2 := z - 1.0
		var y := maxf(gy(z), gy(z2))
		var x0 := AX - AHW
		var x1 := AX + AHW
		if z <= YARD_Z0 and z > YARD_Z1 or z <= END_Z0:
			x0 = 26.0
			x1 = 40.0
		if absf(gy(z) - gy(z2)) > 0.02:
			b.box_mm(stone, Vector3(x0, y - 0.6, z2), Vector3(x1, y + 0.02, z), Color("#d9cfbd"))
			b.box_mm(stone, Vector3(x0, y - 0.02, z - 0.12), Vector3(x1, y + 0.03, z), Color("#c9bfae"))
		else:
			b.box_mm(cobble, Vector3(x0, y - 0.3, z2), Vector3(x1, y + 0.02, z), Color(1.0, 0.98, 0.95))
		z = z2
	# Gutter stones along both house fronts.
	for gx in [AX - AHW + 0.15, AX + AHW - 0.15]:
		b.box_mm(stone, Vector3(gx - 0.15, 0.0, END_Z0), Vector3(gx + 0.15, 0.04, BRIDGE_Z0), Color("#bdb3a2"))


## One townhouse of a terrace. side -1: west row (front faces +X), +1: east row (front faces -X).
func _terrace_house(b: MeshBuilder, side: float, zc: float, w: float, storeys: int, i: int) -> void:
	var front := AX + side * AHW
	var back := BACK_E if side > 0 else BACK_W
	var x0 := minf(front, back)
	var x1 := maxf(front, back)
	var base := gy(zc)
	var low := minf(gy(zc + w * 0.5), gy(zc - w * 0.5)) - 0.4
	var eave := base + 0.4 + storeys * 3.2
	var col := Color(WALLS[(i * 5 + 3) % WALLS.size()])
	var roof := Mats.ROOF_SLATE if i % 3 != 0 else Mats.ROOF_TERRACOTTA
	var shut := Color(Mats.SHUTTER_COLORS[i % Mats.SHUTTER_COLORS.size()])
	b.box_mm(_m("stone"), Vector3(x0 - 0.04, low, zc - w * 0.5), Vector3(x1 + 0.04, base + 0.4, zc + w * 0.5), Color("#d6cdbd"), 63 - 8)
	b.box_mm(_m("brick") if i % 4 == 1 else _m("paint"), Vector3(x0, base + 0.4, zc - w * 0.5 + 0.02), Vector3(x1, eave, zc + w * 0.5 - 0.02), Color.WHITE if i % 4 == 1 else col, 63 - 8)
	b.box_mm(_m("solid"), Vector3(x0 - 0.05, eave - 0.22, zc - w * 0.5), Vector3(x1 + 0.05, eave, zc + w * 0.5), Mats.TRIM)
	add_box("wall", Vector3((x0 + x1) * 0.5, (low + eave) * 0.5, zc), Vector3(x1 - x0, eave - low, w))
	_roof_z(b, (x0 + x1) * 0.5, zc, eave, x1 - x0, w, 2.2, roof, col)
	# Chimney stack on the ridge.
	if i % 2 == 0:
		var cz := zc + w * 0.3
		b.box_mm(_m("brick"), Vector3((x0 + x1) * 0.5 - 0.4, eave + 1.2, cz - 0.35), Vector3((x0 + x1) * 0.5 + 0.4, eave + 3.2, cz + 0.35), Color.WHITE)
		for k in 2:
			b.cylinder(_m("solid"), Transform3D(Basis(), Vector3((x0 + x1) * 0.5 - 0.17 + k * 0.34, eave + 3.2, cz)), 0.1, 0.12, 0.35, 8, Color("#c8642f"))
	var face := Vector3(-side, 0, 0)
	var fx := front
	_door(b, face, Vector3(fx, base + 0.4, zc + w * 0.22), Color(DOORS[i % DOORS.size()]))
	_win(face, Vector3(fx, base + 0.4 + 1.6, zc - w * 0.22), shut)
	for s in range(1, storeys):
		var y := base + 0.4 + 1.7 + s * 3.2
		_win(face, Vector3(fx, y, zc - w * 0.22), shut, (i + s) % 2 == 0)
		_win(face, Vector3(fx, y, zc + w * 0.22), shut, (i + s) % 2 == 1)
	# Back windows (seen from the lane and the hills).
	var bface := Vector3(side, 0, 0)
	for s in storeys:
		var y := base + 0.4 + 1.7 + s * 3.2
		_win(bface, Vector3(back, y, zc), shut)
	if i % 3 == 2:
		_drainpipe(b, fx - side * 0.12, zc + w * 0.5 - 0.15, base, eave)


## The house across the head of the mews, with the roof terrace and pigeon loft (launch spot).
func _loft_house(b: MeshBuilder) -> void:
	var zc := (LOFT_Z0 + LOFT_Z1) * 0.5
	var base := gy(zc)
	var low := gy(LOFT_Z1) - 0.4
	var top := base + LOFT_H
	var col := Color("#f4c9a0")
	b.box_mm(_m("stone"), Vector3(BACK_W, low, LOFT_Z1), Vector3(BACK_E, base + 0.4, LOFT_Z0), Color("#d6cdbd"), 63 - 8)
	b.box_mm(_m("paint"), Vector3(BACK_W, base + 0.4, LOFT_Z1), Vector3(BACK_E, top, LOFT_Z0), col, 63 - 8)
	add_box("wall", Vector3(AX, (low + top) * 0.5, zc), Vector3(BACK_E - BACK_W, top - low, LOFT_Z0 - LOFT_Z1))
	b.box_mm(_m("stone"), Vector3(BACK_W, top - 0.04, LOFT_Z1), Vector3(BACK_E, top, LOFT_Z0), Color("#cfc6b6"), 4)
	var shut := Color("#3f7d4f")
	for x in [25.0, 28.0, 38.0, 41.0]:
		_win(Vector3.FORWARD, Vector3(x, base + 2.0, LOFT_Z1), shut)
		_win(Vector3.FORWARD, Vector3(x, base + 5.1, LOFT_Z1), shut, true)
		_win(Vector3.BACK, Vector3(x, base + 5.1, LOFT_Z0), shut)
	_win(Vector3.FORWARD, Vector3(AX, base + 5.1, LOFT_Z1), shut, true)
	_door(b, Vector3.FORWARD, Vector3(AX, base + 0.4, LOFT_Z1), Color("#2f6f8f"))
	# Parapet on three sides, a low rail on the south edge (the throw goes over it).
	var stone := _m("stone")
	for seg in [[BACK_W, LOFT_Z1, BACK_W + 0.3, LOFT_Z0], [BACK_E - 0.3, LOFT_Z1, BACK_E, LOFT_Z0], [BACK_W, LOFT_Z0 - 0.3, BACK_E, LOFT_Z0]]:
		b.box_mm(stone, Vector3(seg[0], top, seg[1]), Vector3(seg[2], top + 0.8, seg[3]), Color("#e6dccb"))
		add_box("wall", Vector3((seg[0] + seg[2]) * 0.5, top + 0.4, (seg[1] + seg[3]) * 0.5), Vector3(seg[2] - seg[0], 0.8, seg[3] - seg[1]))
	var x := BACK_W + 0.4
	while x < BACK_E - 0.3:
		b.box_mm(_m("solid"), Vector3(x - 0.03, top, LOFT_Z1 + 0.08), Vector3(x + 0.03, top + 0.55, LOFT_Z1 + 0.14), Mats.TRIM)
		x += 0.35
	b.box_mm(_m("solid"), Vector3(BACK_W, top + 0.55, LOFT_Z1 + 0.04), Vector3(BACK_E, top + 0.62, LOFT_Z1 + 0.18), Mats.TRIM)
	# The pigeon loft: a little striped shed with landing perches and a few pigeons.
	var lc := Vector3(39.0, top, 104.0)
	b.box_mm(_m("wood"), lc + Vector3(-1.8, 0, -1.6), lc + Vector3(1.8, 2.0, 1.6), Color("#f2d58f"))
	b.gable_roof(_m("shingle"), Transform3D(Basis(), lc + Vector3(0, 2.0, 0)), 3.6, 3.2, 0.9, 0.2, 0.1, Color("#c8423b"))
	b.gable_wall(_m("wood"), Transform3D(Basis(), lc + Vector3(0, 2.0, 0)), 3.6, 0.9, 1.6, 1.0, Color("#f2d58f"))
	b.gable_wall(_m("wood"), Transform3D(Basis(), lc + Vector3(0, 2.0, 0)), 3.6, 0.9, -1.6, -1.0, Color("#f2d58f"))
	for k in 4:
		var hx := -1.2 + k * 0.8
		b.box_mm(_m("solid"), lc + Vector3(hx - 0.18, 1.2, -1.62), lc + Vector3(hx + 0.18, 1.55, -1.6), Color("#33303a"))
		b.box_mm(_m("wood"), lc + Vector3(hx - 0.25, 1.15, -1.9), lc + Vector3(hx + 0.25, 1.19, -1.6), Color("#a87a4f"))
	add_box("wall", lc + Vector3(0, 1.4, 0), Vector3(3.6, 2.8, 3.2))
	for p in [Vector3(25.5, top + 0.8, 107.8), Vector3(26.4, top + 0.8, 107.8), Vector3(42.8, top + 0.8, 101.0), Vector3(37.6, top + 1.2, 102.1)]:
		_pigeon(b, p)
	# Pots, a bench and a washing basket on the terrace.
	for p in [Vector3(24.2, top, 99.0), Vector3(41.6, top, 99.2), Vector3(24.3, top, 106.8)]:
		b.cylinder(_m("solid"), Transform3D(Basis(), p), 0.3, 0.38, 0.5, 10, Color("#c8642f"))
		b.sphere(_m("foliage"), p + Vector3(0, 0.75, 0), Vector3(0.45, 0.45, 0.45), 4, 8, Color("#5f9a45"))
	inst("bench", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(24.4, top, 103.0)))
	add_box("furniture", Vector3(24.4, top + 0.45, 103.0), Vector3(0.6, 0.9, 1.8))


func _pigeon(b: MeshBuilder, p: Vector3) -> void:
	b.sphere(_m("solid"), p + Vector3(0, 0.12, 0), Vector3(0.12, 0.1, 0.16), 3, 8, Color("#9aa0a8"))
	b.sphere(_m("solid"), p + Vector3(0, 0.24, 0.1), Vector3(0.06, 0.06, 0.06), 3, 6, Color("#6b717a"))


# --- The tailor's bridge house ---------------------------------------------------------------

func _bridge_house(b: MeshBuilder) -> void:
	var col := Color("#cbbbe8")
	var in_col := Color("#fbf1dc")
	var z0 := BRIDGE_Z0
	var z1 := BRIDGE_Z1
	var zc := (z0 + z1) * 0.5
	# Ground floor: blocks either side of the carriage arch.
	for seg in [[BACK_W, AX - ARCH_HW], [AX + ARCH_HW, BACK_E]]:
		b.box_mm(_m("paint"), Vector3(seg[0], -0.3, z1), Vector3(seg[1], UF, z0), col, 63 - 8)
		add_box("wall", Vector3((seg[0] + seg[1]) * 0.5, (UF - 0.3) * 0.5, zc), Vector3(seg[1] - seg[0], UF + 0.3, z0 - z1))
	b.box_mm(_m("plaster"), Vector3(AX - ARCH_HW, ARCH_TOP, z1), Vector3(AX + ARCH_HW, UF, z0), Color("#efe6d4"))
	add_box("ceiling", Vector3(AX, (ARCH_TOP + UF) * 0.5, zc), Vector3(ARCH_HW * 2.0, UF - ARCH_TOP, z0 - z1))
	# Arch trims and a lamp on each face.
	for zf in [z0, z1]:
		var f := 1.0 if zf > zc else -1.0
		for sx in [-1.0, 1.0]:
			b.box_mm(_m("stone"), Vector3(AX + sx * ARCH_HW - 0.25, 0, minf(zf, zf + f * 0.12)), Vector3(AX + sx * ARCH_HW + 0.25, ARCH_TOP, maxf(zf, zf + f * 0.12)), Color("#e6dccb"))
		b.box_mm(_m("stone"), Vector3(AX - ARCH_HW - 0.25, ARCH_TOP - 0.05, minf(zf, zf + f * 0.12)), Vector3(AX + ARCH_HW + 0.25, ARCH_TOP + 0.35, maxf(zf, zf + f * 0.12)), Color("#e6dccb"))
		b.box_mm(_m("stone"), Vector3(AX - 0.3, ARCH_TOP - 0.1, minf(zf, zf + f * 0.2)), Vector3(AX + 0.3, ARCH_TOP + 0.45, maxf(zf, zf + f * 0.2)), Color("#d6cdbd"))
		# Ground-floor shop windows beside the arch.
		for wx in [26.0, 40.0]:
			_win(Vector3(0, 0, f), Vector3(wx, 1.7, zf), Color("#7c4f9e"))
	# Upstairs: the open sewing room.
	var north := [[AX - 1.2, AX + 1.2, 4.1, 6.3, true], [25.5, 27.3, 4.3, 6.1, false], [38.7, 40.5, 4.3, 6.1, false]]
	_wall_z(b, z0, 1.0, BACK_W, BACK_E, UF, BRIDGE_EAVE, north, col, in_col)
	var south := [[AX - 1.2, AX + 1.2, 4.1, 6.3, true], [25.5, 27.3, 4.3, 6.1, false], [38.7, 40.5, 4.3, 6.1, false]]
	_wall_z(b, z1, -1.0, BACK_W, BACK_E, UF, BRIDGE_EAVE, south, col, in_col)
	for sx in [BACK_W, BACK_E - T]:
		b.box_mm(_m("paint"), Vector3(sx, UF, z1 + T), Vector3(sx + T, BRIDGE_EAVE, z0 - T), col)
		add_box("wall", Vector3(sx + T * 0.5, (UF + BRIDGE_EAVE) * 0.5, zc), Vector3(T, BRIDGE_EAVE - UF, z0 - z1))
	b.box_mm(_m("wood"), Vector3(BACK_W + T, UF - 0.02, z1 + T), Vector3(BACK_E - T, UF + 0.02, z0 - T), Color("#c9a27e"), 4)
	b.box_mm(_m("plaster"), Vector3(BACK_W + T, UC, z1 + T), Vector3(BACK_E - T, BRIDGE_EAVE, z0 - T), Color("#fbf7ee"))
	add_box("ceiling", Vector3(AX, (UC + BRIDGE_EAVE) * 0.5, zc), Vector3(BACK_E - BACK_W, BRIDGE_EAVE - UC, z0 - z1))
	b.box_mm(_m("solid"), Vector3(BACK_W - 0.05, BRIDGE_EAVE - 0.22, z1 - 0.05), Vector3(BACK_E + 0.05, BRIDGE_EAVE, z0 + 0.05), Mats.TRIM)
	_roof_x(b, AX, zc, BRIDGE_EAVE, BACK_E - BACK_W, z0 - z1, 3.0, Mats.ROOF_TERRACOTTA, col)
	# A hanging shop sign over the arch: "Thimble & Thread".
	# Cutting table with rolls of cloth (west), sewing machines and dress forms (east).
	var wood := _m("wood")
	var solid := _m("solid")
	b.box_mm(wood, Vector3(24.4, UF, 63.6), Vector3(28.6, UF + 0.9, 70.4), Color("#b98a5a"))
	add_box("furniture", Vector3(26.5, UF + 0.45, 67.0), Vector3(4.2, 0.9, 6.8))
	var roll_cols := [Color("#e8546a"), Color("#6fb4e8"), Color("#f2c14e"), Color("#7fd08c"), Color("#c46ad9")]
	for k in 5:
		b.cylinder(_m("cloth"), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(25.2 + k * 0.75, UF + 1.08, 67.0)), 0.18, 0.18, 2.6, 10, roll_cols[k])
	for k in 3:
		var mx := 37.6 + k * 1.3
		var mp := Vector3(mx, UF, 70.0 - k * 0.4)
		b.cylinder(wood, Transform3D(Basis(), mp), 0.22, 0.22, 0.05, 8, Color("#7a5236"))
		b.cylinder(wood, Transform3D(Basis(), mp), 0.03, 0.03, 0.9, 5, Color("#7a5236"))
		b.sphere(solid, mp + Vector3(0, 1.3, 0), Vector3(0.24, 0.42, 0.18), 4, 10, [Color("#f4f0e6"), Color("#e6c3da"), Color("#a9c9db")][k])
		add_cylinder("furniture", mp, 0.28, 1.75)
	b.box_mm(wood, Vector3(37.0, UF, 62.6), Vector3(41.8, UF + 0.78, 64.2), Color("#a87a4f"))
	add_box("furniture", Vector3(39.4, UF + 0.39, 63.4), Vector3(4.8, 0.78, 1.6))
	for k in 2:
		var sp := Vector3(38.2 + k * 2.2, UF + 0.78, 63.4)
		b.box_mm(solid, sp + Vector3(-0.35, 0, -0.15), sp + Vector3(0.35, 0.12, 0.15), Color("#33303a"))
		b.box_mm(solid, sp + Vector3(0.15, 0.12, -0.08), sp + Vector3(0.3, 0.4, 0.08), Color("#33303a"))
		b.box_mm(solid, sp + Vector3(-0.3, 0.34, -0.07), sp + Vector3(0.3, 0.42, 0.07), Color("#33303a"))
	# Shelves of folded fabric along both end walls, spools, pendant lamps off the flight line.
	for sx in [BACK_W + T, BACK_E - T - 0.45]:
		b.box_mm(wood, Vector3(sx, UF, 62.6), Vector3(sx + 0.45, UF + 2.2, 63.4), Color("#8a6a52"))
		for k in 4:
			for j in 3:
				b.box_mm(_m("cloth"), Vector3(sx + 0.05, UF + 0.15 + k * 0.52, 62.65 + j * 0.25), Vector3(sx + 0.4, UF + 0.42 + k * 0.52, 62.85 + j * 0.25), roll_cols[(k + j) % 5])
	for p in [Vector3(26.5, UC - 0.7, 67.0), Vector3(39.5, UC - 0.7, 67.0)]:
		b.cylinder(_m("metal"), Transform3D(Basis(), p + Vector3(0, 0.15, 0)), 0.012, 0.012, 0.55, 4, Color("#4a4640"))
		b.cylinder(_m("solid"), Transform3D(Basis(), p - Vector3(0, 0.12, 0)), 0.3, 0.07, 0.28, 12, Color("#f2c14e"))
		b.sphere(_m("glow"), p - Vector3(0, 0.1, 0), Vector3(0.08, 0.08, 0.08), 3, 6, Color("#fff1c9"))
	_lights.append([Vector3(AX, 6.0, 69.5), Color("#ffe2b8"), 0.9, 7.0])
	_lights.append([Vector3(AX, 6.0, 64.5), Color("#ffe2b8"), 0.9, 7.0])


# --- The squeeze ----------------------------------------------------------------------------

func _squeeze(b: MeshBuilder) -> void:
	var zc := (SQ_Z0 + SQ_Z1) * 0.5
	var length := SQ_Z0 - SQ_Z1
	var cols := [Color("#a9c9db"), Color("#f2d58f")]
	var shut := [Color("#c8423b"), Color("#2f5560")]
	for si in 2:
		var side := -1.0 if si == 0 else 1.0
		var front := SQ_W if side < 0 else SQ_E
		var back := BACK_W if side < 0 else BACK_E
		var x0 := minf(front, back)
		var x1 := maxf(front, back)
		var eave := 7.4
		b.box_mm(_m("stone"), Vector3(x0 - 0.04, -0.3, SQ_Z1), Vector3(x1 + 0.04, 0.4, SQ_Z0), Color("#d6cdbd"), 63 - 8)
		b.box_mm(_m("paint"), Vector3(x0, 0.4, SQ_Z1), Vector3(x1, eave, SQ_Z0), cols[si], 63 - 8)
		b.box_mm(_m("solid"), Vector3(x0 - 0.05, eave - 0.22, SQ_Z1), Vector3(x1 + 0.05, eave, SQ_Z0), Mats.TRIM)
		add_box("wall", Vector3((x0 + x1) * 0.5, (eave - 0.3) * 0.5, zc), Vector3(x1 - x0, eave + 0.3, length))
		_roof_z(b, (x0 + x1) * 0.5, zc, eave, x1 - x0, length, 2.4, Mats.ROOF_SLATE, cols[si])
		var face := Vector3(-side, 0, 0)
		for z in [SQ_Z0 - 3.0, zc, SQ_Z1 + 3.0]:
			_win(face, Vector3(front, 2.1, z), shut[si])
			_win(face, Vector3(front, 5.3, z), shut[si], si == 0)
		for z in [SQ_Z0 - 0.4, SQ_Z1 + 0.4]:
			_drainpipe(b, front - side * 0.1, z, 0.0, eave)
		# The ends facing the wider mews get windows too.
		for zf in [SQ_Z0, SQ_Z1]:
			var f := 1.0 if zf > zc else -1.0
			_win(Vector3(0, 0, f), Vector3((x0 + x1) * 0.5, 5.3, zf), shut[si])
	# A cat watching from a window ledge, and a sign: "Mind the draught!".
	var cat := Vector3(SQ_W + 0.18, 4.38, 33.0)
	b.box_mm(_m("solid"), Vector3(SQ_W, 4.3, 32.4), Vector3(SQ_W + 0.3, 4.36, 33.6), Mats.TRIM)
	b.sphere(_m("solid"), cat + Vector3(0, 0.15, 0), Vector3(0.14, 0.15, 0.22), 3, 8, Color("#e8964a"))
	b.sphere(_m("solid"), cat + Vector3(0.02, 0.36, 0.12), Vector3(0.1, 0.1, 0.1), 3, 8, Color("#e8964a"))
	b.tube(_m("solid"), PackedVector3Array([cat + Vector3(0, 0.05, -0.2), cat + Vector3(0.05, 0.0, -0.4), cat + Vector3(0.0, -0.25, -0.45)]), 0.03, 4, Color("#c76f2c"))


# --- The clock-arch house ---------------------------------------------------------------------

func _clock_house(b: MeshBuilder) -> void:
	var col := Color("#e9b7a1")
	var z0 := CLOCK_Z0
	var z1 := CLOCK_Z1
	var zc := (z0 + z1) * 0.5
	var eave := 7.6
	for seg in [[BACK_W, AX - CLOCK_ARCH_HW], [AX + CLOCK_ARCH_HW, BACK_E]]:
		b.box_mm(_m("paint"), Vector3(seg[0], -0.3, z1), Vector3(seg[1], eave, z0), col, 63 - 8)
		add_box("wall", Vector3((seg[0] + seg[1]) * 0.5, (eave - 0.3) * 0.5, zc), Vector3(seg[1] - seg[0], eave + 0.3, z0 - z1))
	b.box_mm(_m("paint"), Vector3(AX - CLOCK_ARCH_HW, CLOCK_ARCH_TOP, z1), Vector3(AX + CLOCK_ARCH_HW, eave, z0), col, 63 - 8)
	add_box("wall", Vector3(AX, (CLOCK_ARCH_TOP + eave) * 0.5, zc), Vector3(CLOCK_ARCH_HW * 2.0, eave - CLOCK_ARCH_TOP, z0 - z1))
	b.box_mm(_m("plaster"), Vector3(AX - CLOCK_ARCH_HW, CLOCK_ARCH_TOP - 0.02, z1), Vector3(AX + CLOCK_ARCH_HW, CLOCK_ARCH_TOP, z0), Color("#efe6d4"))
	b.box_mm(_m("solid"), Vector3(BACK_W - 0.05, eave - 0.22, z1 - 0.05), Vector3(BACK_E + 0.05, eave, z0 + 0.05), Mats.TRIM)
	_roof_x(b, AX, zc, eave, BACK_E - BACK_W, z0 - z1, 3.2, Mats.ROOF_SLATE, col)
	# Rounded arch trim (stone voussoirs) on both faces.
	for zf in [z0, z1]:
		var f := 1.0 if zf > zc else -1.0
		var za := minf(zf, zf + f * 0.14)
		var zb := maxf(zf, zf + f * 0.14)
		for sx in [-1.0, 1.0]:
			var px: float = AX + sx * (CLOCK_ARCH_HW + 0.22)
			b.box_mm(_m("stone"), Vector3(px - 0.22, 0, za), Vector3(px + 0.22, CLOCK_ARCH_TOP - 0.6, zb), Color("#e6dccb"))
		for k in 9:
			var a := PI * k / 8.0
			var c := Vector3(AX + cos(a) * (CLOCK_ARCH_HW + 0.22), CLOCK_ARCH_TOP - 0.6 + sin(a) * 0.95, (za + zb) * 0.5)
			b.box(_m("stone"), Transform3D(Basis(Vector3.BACK, a - PI * 0.5), c), Vector3(0.42, 0.34, zb - za), Color("#e6dccb") if k % 2 == 0 else Color("#d6cdbd"))
		for wx in [26.5, 39.5]:
			_win(Vector3(0, 0, f), Vector3(wx, 2.0, zf), Color("#3f6f8f"))
			_win(Vector3(0, 0, f), Vector3(wx, 5.4, zf), Color("#3f6f8f"), true)
	# The clock above the arch (north face), and a little bell turret with a weathervane.
	var cc := Vector3(AX, 5.3, z0 + 0.06)
	b.cylinder(_m("solid"), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), cc), 1.22, 1.22, 0.08, 28, Color("#2f2b35"))
	b.cylinder(_m("solid"), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), cc + Vector3(0, 0, 0.04)), 1.1, 1.1, 0.06, 28, Color("#fbf3dc"))
	for k in 12:
		var a := TAU * k / 12.0
		b.box(_m("solid"), Transform3D(Basis(Vector3.BACK, -a), cc + Vector3(sin(a) * 0.92, cos(a) * 0.92, 0.09)), Vector3(0.06, 0.18 if k % 3 == 0 else 0.1, 0.02), Color("#2f2b35"))
	b.box(_m("solid"), Transform3D(Basis(Vector3.BACK, -0.9), cc + Vector3(sin(0.9) * 0.28, cos(0.9) * 0.28, 0.11)), Vector3(0.07, 0.6, 0.02), Color("#2f2b35"))
	b.box(_m("solid"), Transform3D(Basis(Vector3.BACK, -3.3), cc + Vector3(sin(3.3) * 0.38, cos(3.3) * 0.38, 0.12)), Vector3(0.05, 0.8, 0.02), Color("#2f2b35"))
	var ridge := eave + 3.2
	var tc := Vector3(AX, ridge - 0.4, zc)
	b.box_mm(_m("wood"), tc + Vector3(-0.7, 0, -0.7), tc + Vector3(0.7, 1.6, 0.7), Color("#fbf8f0"))
	b.pyramid(_m("shingle"), Transform3D(Basis(), tc + Vector3(0, 1.6, 0)), Vector2(1.7, 1.7), 1.0, Color("#3f7d4f"))
	b.cylinder(_m("metal"), Transform3D(Basis(), tc + Vector3(0, 2.6, 0)), 0.02, 0.02, 0.8, 4, Color("#d4a63a"))
	# The lamp hanging in the middle of the arch: duck under it.
	b.cylinder(_m("metal"), Transform3D(Basis(), CLOCK_LAMP + Vector3(0, 0.2, 0)), 0.01, 0.01, CLOCK_ARCH_TOP - CLOCK_LAMP.y - 0.2, 4, Color("#33303a"))
	b.cylinder(_m("metal"), Transform3D(Basis(), CLOCK_LAMP + Vector3(0, -0.16, 0)), 0.14, 0.17, 0.34, 6, Color("#33303a"))
	b.cylinder(_m("window_lit"), Transform3D(Basis(), CLOCK_LAMP + Vector3(0, -0.12, 0)), 0.11, 0.13, 0.26, 6, Color("#fff1c9"))
	add_sphere("lamp", CLOCK_LAMP, 0.22)


# --- The laundry yard --------------------------------------------------------------------------

func _yard(b: MeshBuilder) -> void:
	_garden_walls(b, YARD_Z0, YARD_Z1)
	# Flower beds along the walls and a bench.
	for z in range(int(YARD_Z1) + 1, int(YARD_Z0) - 1, 2):
		for fx in [26.6, 39.4]:
			inst("flower", Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(1.1, 1.6)), Vector3(fx, 0, z)), Mats.pick(_rng, Mats.FLOWER_COLORS))
	inst("bench", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(27.2, 0, 10.0)))
	add_box("furniture", Vector3(27.2, 0.45, 10.0), Vector3(0.6, 0.9, 1.8))
	b.cylinder(_m("wood"), Transform3D(Basis(), Vector3(38.6, 0, 11.5)), 0.4, 0.4, 0.9, 10, Color("#6fa0b8"))
	add_cylinder("furniture", Vector3(38.6, 0, 11.5), 0.42, 0.95)
	# The rotary washing line: a pole and four arms of clothes that turn in the breeze.
	b.cylinder(_m("metal"), Transform3D(Basis(), ROTARY), 0.05, 0.04, 2.1, 6, Color("#c9ced2"))
	add_cylinder("lamp", ROTARY, 0.08, 2.1)


func _garden_walls(b: MeshBuilder, z0: float, z1: float) -> void:
	for wx in [26.0, 40.0]:
		b.box_mm(_m("brick"), Vector3(wx - 0.2, 0, z1), Vector3(wx + 0.2, 1.5, z0), Color.WHITE)
		b.box_mm(_m("stone"), Vector3(wx - 0.27, 1.5, z1), Vector3(wx + 0.27, 1.6, z0), Color("#d6cdbd"))
		add_box("wall", Vector3(wx, 0.8, (z0 + z1) * 0.5), Vector3(0.4, 1.6, z0 - z1))


## The arms, hanging washing and their colliders, built once and spun in _process.
func _build_rotor() -> void:
	_rotor = Node3D.new()
	_rotor.name = "Rotary"
	_rotor.position = ROTARY + Vector3(0, 2.05, 0)
	add_child(_rotor)
	var b := MeshBuilder.new()
	var cols := [Color("#fbf8f0"), Color("#a9c9db"), Color("#e9b7a1"), Color("#f2d58f"), Color("#b9d6a8"), Color("#e6c3da")]
	for k in 4:
		var a := TAU * k / 4.0
		var dir := Vector3(sin(a), 0, cos(a))
		b.tube(_m("metal"), PackedVector3Array([Vector3.ZERO, dir * 1.7 + Vector3(0, -0.15, 0)]), 0.02, 4, Color("#c9ced2"))
		var side := Vector3(dir.z, 0, -dir.x)
		for j in 2:
			var p := dir * (0.8 + j * 0.65) + Vector3(0, -0.1, 0)
			var c: Color = cols[(k * 2 + j) % cols.size()]
			b.quad(_m("cloth"), p - side * 0.28 + Vector3(0, -0.6, 0), p + side * 0.28 + Vector3(0, -0.6, 0), p + side * 0.28, p - side * 0.28, c)
			b.quad(_m("cloth"), p - side * 0.28, p + side * 0.28, p + side * 0.28 + Vector3(0, -0.6, 0), p - side * 0.28 + Vector3(0, -0.6, 0), c)
	_rotor.add_child(b.build_instance("Arms", false))
	_rotor_body = StaticBody3D.new()
	_rotor_body.collision_layer = LAYER_WORLD
	_rotor_body.collision_mask = 0
	_rotor_body.set_meta("kind", "washing")
	_rotor.add_child(_rotor_body)
	for k in 4:
		var a := TAU * k / 4.0
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.6, 0.75, 1.75)
		cs.shape = box
		cs.transform = Transform3D(Basis(Vector3.UP, a), Vector3(sin(a) * 0.95, -0.4, cos(a) * 0.95))
		_rotor_body.add_child(cs)


# --- The glass walkway ---------------------------------------------------------------------------

func _walkway(b: MeshBuilder) -> void:
	var x0 := AX - WALK_HW
	var x1 := AX + WALK_HW
	var z0 := WALK_Z0
	var z1 := WALK_Z1
	var zc := (z0 + z1) * 0.5
	var stone := _m("stone")
	var solid := _m("solid")
	b.box_mm(_m("wood"), Vector3(x0, WALK_FLOOR - 0.25, z1), Vector3(x1, WALK_FLOOR, z0), Color("#a87a4f"))
	add_box("floor", Vector3(AX, WALK_FLOOR - 0.12, zc), Vector3(WALK_HW * 2.0, 0.25, z0 - z1))
	for z in [z0 - 0.3, zc, z1 + 0.3]:
		for sx in [x0 + 0.2, x1 - 0.2]:
			b.box_mm(stone, Vector3(sx - 0.18, 0, z - 0.18), Vector3(sx + 0.18, WALK_FLOOR - 0.25, z + 0.18), Color("#e6dccb"))
			add_box("wall", Vector3(sx, (WALK_FLOOR - 0.25) * 0.5, z), Vector3(0.36, WALK_FLOOR - 0.25, 0.36))
	# Glass sides and roof with white frames.
	for sx in [x0, x1]:
		b.box_mm(_m("window_lit"), Vector3(sx - 0.02, WALK_FLOOR, z1), Vector3(sx + 0.02, WALK_ROOF, z0), Color("#bfe0ee"))
		add_box("greenhouse", Vector3(sx, (WALK_FLOOR + WALK_ROOF) * 0.5, zc), Vector3(0.12, WALK_ROOF - WALK_FLOOR, z0 - z1))
		var z := z1
		while z <= z0 + 0.01:
			b.box_mm(solid, Vector3(sx - 0.05, WALK_FLOOR, z - 0.05), Vector3(sx + 0.05, WALK_ROOF, z + 0.05), Mats.TRIM)
			z += 2.0
		for y in [WALK_FLOOR + 0.05, (WALK_FLOOR + WALK_ROOF) * 0.5]:
			b.box_mm(solid, Vector3(sx - 0.05, y - 0.04, z1), Vector3(sx + 0.05, y + 0.04, z0), Mats.TRIM)
	b.box_mm(_m("window_lit"), Vector3(x0, WALK_ROOF, z1), Vector3(x1, WALK_ROOF + 0.04, z0), Color("#cfe8f2"))
	add_box("ceiling", Vector3(AX, WALK_ROOF + 0.1, zc), Vector3(WALK_HW * 2.0, 0.2, z0 - z1))
	var z2 := z1
	while z2 <= z0 + 0.01:
		b.box_mm(solid, Vector3(x0, WALK_ROOF, z2 - 0.05), Vector3(x1, WALK_ROOF + 0.1, z2 + 0.05), Mats.TRIM)
		z2 += 2.0
	b.box_mm(solid, Vector3(AX - 0.05, WALK_ROOF, z1), Vector3(AX + 0.05, WALK_ROOF + 0.1, z0), Mats.TRIM)
	# Planters with little lemon trees along both sides inside.
	for sx in [x0 + 0.38, x1 - 0.38]:
		b.box_mm(_m("wood"), Vector3(sx - 0.3, WALK_FLOOR, z1 + 0.6), Vector3(sx + 0.3, WALK_FLOOR + 0.45, z0 - 0.6), Color("#6b4a32"))
		add_box("furniture", Vector3(sx, WALK_FLOOR + 0.22, zc), Vector3(0.6, 0.45, z0 - z1 - 1.2))
		var z := z1 + 2.0
		while z < z0 - 1.5:
			b.cylinder(wood_mat(), Transform3D(Basis(), Vector3(sx, WALK_FLOOR + 0.45, z)), 0.04, 0.03, 0.5, 5, Color("#7a5236"))
			b.sphere(_m("foliage"), Vector3(sx, WALK_FLOOR + 1.1, z), Vector3(0.32, 0.3, 0.32), 4, 8, Color("#5f9a45"))
			for k in 3:
				b.sphere(solid, Vector3(sx + _rng.randf_range(-0.22, 0.22), WALK_FLOOR + 1.0 + _rng.randf_range(-0.1, 0.15), z + _rng.randf_range(-0.22, 0.22)), Vector3(0.06, 0.06, 0.06), 3, 5, Color("#f7d046"))
			add_sphere("tree", Vector3(sx, WALK_FLOOR + 1.1, z), 0.3)
			z += 3.0
	# Hanging flower baskets: weave left, then right.
	for p: Vector3 in BASKETS:
		b.tube(_m("metal"), PackedVector3Array([p + Vector3(0, 0.2, 0), Vector3(p.x, WALK_ROOF, p.z)]), 0.008, 3, Color("#33303a"))
		b.sphere(_m("wood"), p, Vector3(0.3, 0.2, 0.3), 4, 10, Color("#8a6a52"))
		b.sphere(_m("foliage"), p + Vector3(0, 0.15, 0), Vector3(0.36, 0.2, 0.36), 4, 10, Color("#5f9a45"))
		for k in 6:
			var a := TAU * k / 6.0
			b.sphere(solid, p + Vector3(cos(a) * 0.3, 0.12, sin(a) * 0.3), Vector3(0.07, 0.07, 0.07), 3, 5, Color(Mats.FLOWER_COLORS[k % Mats.FLOWER_COLORS.size()]))
		add_sphere("furniture", p, 0.34)


func wood_mat() -> Material:
	return _m("wood")


func _end_yard(b: MeshBuilder) -> void:
	_garden_walls(b, END_Z0, END_Z1)
	b.box_mm(_m("brick"), Vector3(26.0, 0, END_Z1 - 0.2), Vector3(31.8, 1.5, END_Z1 + 0.2), Color.WHITE)
	b.box_mm(_m("brick"), Vector3(34.2, 0, END_Z1 - 0.2), Vector3(40.0, 1.5, END_Z1 + 0.2), Color.WHITE)
	add_box("wall", Vector3(28.9, 0.75, END_Z1), Vector3(5.8, 1.5, 0.4))
	add_box("wall", Vector3(37.1, 0.75, END_Z1), Vector3(5.8, 1.5, 0.4))
	b.box_mm(_m("wood"), Vector3(31.8, 0, END_Z1 - 0.05), Vector3(34.2, 1.3, END_Z1 + 0.05), Color("#3f7d4f"))
	add_box("wall", Vector3(AX, 0.65, END_Z1), Vector3(2.4, 1.3, 0.1))
	for p in [Vector3(27.0, 0, -70.0), Vector3(39.0, 0, -73.0), Vector3(27.2, 0, -81.0), Vector3(38.8, 0, -83.5)]:
		b.cylinder(_m("solid"), Transform3D(Basis(), p), 0.32, 0.4, 0.55, 10, Color("#c8642f"))
		b.sphere(_m("foliage"), p + Vector3(0, 0.8, 0), Vector3(0.5, 0.5, 0.5), 4, 8, Color("#5f9a45"))
		add_cylinder("furniture", p, 0.42, 1.2)
	# A little garden shed in the corner.
	var sc := Vector3(38.2, 0, -80.0)
	b.box_mm(_m("wood"), sc + Vector3(-1.2, 0, -1.0), sc + Vector3(1.2, 2.0, 1.0), Color("#b9d6a8"))
	b.gable_roof(_m("shingle"), Transform3D(Basis(), sc + Vector3(0, 2.0, 0)), 2.4, 2.0, 0.7, 0.15, 0.08, Color("#5b6270"))
	add_box("wall", sc + Vector3(0, 1.3, 0), Vector3(2.4, 2.6, 2.0))


func _after_build() -> void:
	_build_rotor()
	for l in _lights:
		var o := OmniLight3D.new()
		o.position = l[0]
		o.light_color = l[1]
		o.light_energy = l[2]
		o.omni_range = l[3]
		o.shadow_enabled = false
		add_child(o)


func _process(delta: float) -> void:
	if _rotor:
		_rotor.rotation.y += delta * 0.9
