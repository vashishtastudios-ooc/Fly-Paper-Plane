class_name CityBlock
extends Prop
## One city block of City Rooftops: up to four buildings (lots) built as a single mesh, so a
## whole block is only a handful of draws. Origin = ground at the block centre.
##
## Each lot: {"rect": Rect2 (local x, z, size x, size z), "storeys": int, "wall": Color,
## "brick": bool, "shop": bool, "awning": Color, "roof": Array of features ("tank", "hut", "ac",
## "garden", "skylight", "billboard", "antenna", "chimneys"), "parapet": bool, "seed": int}.
## Optional "tunnel": {"storey": int, "x": local x of its centre, "w": width}: an apartment you can
## fly straight through along z, in one open window and out the other (Flight 3).
## Windows are flat panes in the mesh (not instances), so tall buildings stay cheap.

const GROUND_FLOOR := 3.6
const STOREY := 3.0
const PARAPET := 0.7
const WIN_SPACING := 3.1

var lots: Array = []


static func lot_top(lot: Dictionary) -> float:
	return GROUND_FLOOR + (int(lot.storeys) - 1) * STOREY


func _build(b: MeshBuilder) -> void:
	for lot in lots:
		_lot(b, lot)


func _lot(b: MeshBuilder, lot: Dictionary) -> void:
	var r: Rect2 = lot.rect
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	var top := lot_top(lot)
	var wall: Color = lot.wall
	var wall_mat := Mats.get_mat("brick") if lot.brick else Mats.get_mat("plaster")
	var stone := Mats.get_mat("stone")
	var trim := Color("#e9dfcc")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(lot.get("seed", 1))
	# Walls (no bottom face), a stone band over the ground floor and a cornice at the top.
	var tun: Dictionary = lot.get("tunnel", {})
	if tun.is_empty():
		b.box_mm(wall_mat, Vector3(x0, 0, z0), Vector3(x1, top, z1), wall, 63 - 8 - 4)
	else:
		for part in tunnel_parts(lot):
			b.box_mm(wall_mat, part.position, part.end, wall, 63 - 8 if part.position.y > 0.0 else 63 - 8 - 4)
		_tunnel_room(b, lot)
	# (Sides only: its top would cover the floor of a 1st-floor fly-through apartment.)
	b.box_mm(stone, Vector3(x0 - 0.08, GROUND_FLOOR - 0.12, z0 - 0.08), Vector3(x1 + 0.08, GROUND_FLOOR + 0.1, z1 + 0.08), trim, 63 - 8 - 4)
	b.box_mm(stone, Vector3(x0 - 0.22, top - 0.32, z0 - 0.22), Vector3(x1 + 0.22, top, z1 + 0.22), trim, 63)
	# Roof.
	b.box_mm(Mats.get_mat("gravel"), Vector3(x0 + 0.2, top, z0 + 0.2), Vector3(x1 - 0.2, top + 0.03, z1 - 0.2), Color("#b7b0a3"), 4)
	if lot.get("parapet", true):
		for e in _parapets(r, top):
			b.box_mm(wall_mat, e[0], e[1], wall)
			b.box_mm(stone, Vector3(e[0].x - 0.03, e[1].y, e[0].z - 0.03), Vector3(e[1].x + 0.03, e[1].y + 0.06, e[1].z + 0.03), trim)
	# Windows on every face of every upper storey.
	var glass := Mats.get_mat("window_lit")
	var frame := Mats.get_mat("solid")
	var lit_cols := [Color("#8fb3cf"), Color("#a3c2d9"), Color("#f2d79a"), Color("#86a9c4")]
	for s in range(1, int(lot.storeys)):
		var y := GROUND_FLOOR + (s - 1) * STOREY + 0.75
		for face in 4:
			var along := r.size.x if face < 2 else r.size.y
			var n := maxi(1, int((along - 1.6) / WIN_SPACING))
			for i in n:
				var t := (i + 0.5) / n
				var c: Color = lit_cols[rng.randi() % lit_cols.size()]
				# No pane over the open window of a fly-through apartment.
				if not tun.is_empty() and face < 2 and s == int(tun.storey) and absf(lerpf(x0, x1, t) - float(tun.x)) < float(tun.w) * 0.5 + 0.9:
					continue
				match face:
					0: _pane(b, glass, frame, Vector3(lerpf(x0, x1, t), y, z0 - 0.03), Vector3(0, 0, -1), c)
					1: _pane(b, glass, frame, Vector3(lerpf(x0, x1, t), y, z1 + 0.03), Vector3(0, 0, 1), c)
					2: _pane(b, glass, frame, Vector3(x0 - 0.03, y, lerpf(z0, z1, t)), Vector3(-1, 0, 0), c)
					3: _pane(b, glass, frame, Vector3(x1 + 0.03, y, lerpf(z0, z1, t)), Vector3(1, 0, 0), c)
	# Ground floor: shop windows and a striped awning on the street faces, or plain doors.
	if lot.get("shop", false):
		var aw: Color = lot.get("awning", Color("#c8423b"))
		for face in lot.get("street_faces", [0]):
			_shopfront(b, r, int(face), aw)
	for f in lot.get("roof", []):
		_roof_feature(b, r, top, str(f), rng)
	if int(lot.get("fire_face", -1)) >= 0:
		_fire_escape(b, r, int(lot.fire_face), int(lot.storeys))


## Fly-through apartments: the room spans the tunnel width; each end wall (north = entry,
## south = exit) has window openings WIN_W x WIN_H. "in"/"out" are the open ones and
## "closed_in"/"closed_out" glazed ones (offsets from the room centre). Optional "lamp":
## [x offset, depth fraction] hanging low in the room, and "divider": [depth fraction, door
## offset], a bookshelf wall across the room with one doorway.
const WIN_W := 3.0
const WIN_H := 2.3
const SILL := 0.35
const END_WALL := 0.3
const DOOR_W := 2.4
const DOOR_H := 2.4


static func _flat_y(t: Dictionary) -> float:
	return GROUND_FLOOR + (int(t.storey) - 1) * STOREY


## The solid pieces of a lot with a fly-through apartment: below and above it, either side,
## and the two end walls round their windows.
static func tunnel_parts(lot: Dictionary) -> Array[AABB]:
	var r: Rect2 = lot.rect
	var top := lot_top(lot)
	var t: Dictionary = lot.tunnel
	var y0 := _flat_y(t)
	var y1 := y0 + STOREY
	var tx := float(t.x)
	var tx0 := tx - float(t.w) * 0.5
	var tx1 := tx + float(t.w) * 0.5
	var out: Array[AABB] = []
	out.append(AABB(Vector3(r.position.x, 0, r.position.y), Vector3(r.size.x, y0, r.size.y)))
	out.append(AABB(Vector3(r.position.x, y1, r.position.y), Vector3(r.size.x, top - y1, r.size.y)))
	out.append(AABB(Vector3(r.position.x, y0, r.position.y), Vector3(tx0 - r.position.x, STOREY, r.size.y)))
	out.append(AABB(Vector3(tx1, y0, r.position.y), Vector3(r.end.x - tx1, STOREY, r.size.y)))
	for end in [[r.end.y - END_WALL, t.get("in", 0.0), t.get("closed_in", [])], [r.position.y, t.get("out", 0.0), t.get("closed_out", [])]]:
		var z: float = end[0]
		var holes := [float(end[1])]
		for c in end[2]:
			holes.append(float(c))
		holes.sort()
		var x := tx0
		for h in holes:
			var hx0: float = tx + h - WIN_W * 0.5
			var hx1: float = tx + h + WIN_W * 0.5
			if hx0 > x:
				out.append(AABB(Vector3(x, y0, z), Vector3(hx0 - x, STOREY, END_WALL)))
			out.append(AABB(Vector3(hx0, y0, z), Vector3(WIN_W, SILL, END_WALL)))
			out.append(AABB(Vector3(hx0, y0 + SILL + WIN_H, z), Vector3(WIN_W, STOREY - SILL - WIN_H, END_WALL)))
			x = hx1
		if x < tx1:
			out.append(AABB(Vector3(x, y0, z), Vector3(tx1 - x, STOREY, END_WALL)))
	return out


## The bookshelf wall pieces either side of and above its doorway (empty without one).
static func divider_parts(lot: Dictionary) -> Array[AABB]:
	var t: Dictionary = lot.tunnel
	var out: Array[AABB] = []
	if not t.has("divider"):
		return out
	var r: Rect2 = lot.rect
	var y0 := _flat_y(t)
	var tx := float(t.x)
	var tx0 := tx - float(t.w) * 0.5
	var tx1 := tx + float(t.w) * 0.5
	var z := lerpf(r.end.y - END_WALL, r.position.y + END_WALL, float(t.divider[0])) - 0.2
	var d := tx + float(t.divider[1])
	out.append(AABB(Vector3(tx0, y0, z), Vector3(d - DOOR_W * 0.5 - tx0, STOREY, 0.4)))
	out.append(AABB(Vector3(d + DOOR_W * 0.5, y0, z), Vector3(tx1 - d - DOOR_W * 0.5, STOREY, 0.4)))
	out.append(AABB(Vector3(d - DOOR_W * 0.5, y0 + DOOR_H, z), Vector3(DOOR_W, STOREY - DOOR_H, 0.4)))
	return out


## Centre of the hanging lamp shade, or null.
static func lamp_pos(lot: Dictionary) -> Variant:
	var t: Dictionary = lot.tunnel
	if not t.has("lamp"):
		return null
	var r: Rect2 = lot.rect
	return Vector3(float(t.x) + float(t.lamp[0]), _flat_y(t) + STOREY - 1.15, lerpf(r.end.y - END_WALL, r.position.y + END_WALL, float(t.lamp[1])))


## Inside the fly-through apartment: wooden floor, papered walls, rug, pictures, a ceiling
## light, the bookshelf and the hanging lamp when it has them, and frames round every window
## (glass in the closed ones).
func _tunnel_room(b: MeshBuilder, lot: Dictionary) -> void:
	var r: Rect2 = lot.rect
	var t: Dictionary = lot.tunnel
	var y0 := _flat_y(t)
	var y1 := y0 + STOREY
	var tx := float(t.x)
	var tx0 := tx - float(t.w) * 0.5
	var tx1 := tx + float(t.w) * 0.5
	var z0 := r.position.y + END_WALL
	var z1 := r.end.y - END_WALL
	var seed_i := int(lot.get("seed", 0))
	var paper: Color = [Color("#f3e3c8"), Color("#dfe9e0"), Color("#f1d9d2"), Color("#e2e4ef")][seed_i % 4]
	var plaster := Mats.get_mat("plaster")
	var solid := Mats.get_mat("solid")
	b.box_mm(Mats.get_mat("wood"), Vector3(tx0, y0, z0), Vector3(tx1, y0 + 0.04, z1), Color("#b98a5e"), 4)
	b.quad(plaster, Vector3(tx0, y1 - 0.04, z0), Vector3(tx1, y1 - 0.04, z0), Vector3(tx1, y1 - 0.04, z1), Vector3(tx0, y1 - 0.04, z1), Color("#f6f1e6"))
	b.quad(plaster, Vector3(tx0 + 0.01, y0, z1), Vector3(tx0 + 0.01, y0, z0), Vector3(tx0 + 0.01, y1, z0), Vector3(tx0 + 0.01, y1, z1), paper)
	b.quad(plaster, Vector3(tx1 - 0.01, y0, z0), Vector3(tx1 - 0.01, y0, z1), Vector3(tx1 - 0.01, y1, z1), Vector3(tx1 - 0.01, y1, z0), paper)
	var zc := (z0 + z1) * 0.5
	b.box_mm(Mats.get_mat("cloth"), Vector3(tx - 1.6, y0 + 0.04, zc - 2.4), Vector3(tx + 1.6, y0 + 0.06, zc + 2.4), Color(["#c8423b", "#2f6f8f", "#8a5aa8"][seed_i % 3]), 4)
	for side in [-1.0, 1.0]:
		var wx := tx0 + 0.03 if side < 0.0 else tx1 - 0.03
		for k in 2:
			var pz := lerpf(z0 + 3.0, z1 - 3.0, k)
			b.box_mm(solid, Vector3(wx - 0.02, y0 + 1.3, pz - 0.45), Vector3(wx + 0.02, y0 + 2.1, pz + 0.45), Color(["#6ec6ff", "#f6a96b", "#8fe3b0", "#ff7eb6"][(k + int(side) + 1) % 4]))
	# Window frames (and glass in the closed ones) on both end walls, inside and out.
	var white := Color("#f6f1e6")
	for end in [[r.end.y, t.get("in", 0.0), t.get("closed_in", [])], [r.position.y, t.get("out", 0.0), t.get("closed_out", [])]]:
		var zf: float = end[0]
		var inward := -1.0 if zf > zc else 1.0
		var all := [[float(end[1]), false]]
		for c in end[2]:
			all.append([float(c), true])
		for w in all:
			var hx := tx + float(w[0])
			var wy0 := y0 + SILL
			var wy1 := wy0 + WIN_H
			for zz in [zf - inward * 0.05, zf + inward * (END_WALL + 0.05)]:
				b.box_mm(solid, Vector3(hx - WIN_W * 0.5 - 0.16, wy0 - 0.05, zz - 0.05), Vector3(hx - WIN_W * 0.5, wy1 + 0.05, zz + 0.05), white)
				b.box_mm(solid, Vector3(hx + WIN_W * 0.5, wy0 - 0.05, zz - 0.05), Vector3(hx + WIN_W * 0.5 + 0.16, wy1 + 0.05, zz + 0.05), white)
				b.box_mm(solid, Vector3(hx - WIN_W * 0.5 - 0.16, wy1, zz - 0.05), Vector3(hx + WIN_W * 0.5 + 0.16, wy1 + 0.16, zz + 0.05), white)
				b.box_mm(solid, Vector3(hx - WIN_W * 0.5 - 0.22, wy0 - 0.1, zz - 0.1), Vector3(hx + WIN_W * 0.5 + 0.22, wy0, zz + 0.1), Color("#e4dccd"))
			if w[1]:
				# Closed: glass with a cross bar.
				var zg := zf + inward * END_WALL * 0.5
				b.box_mm(Mats.get_mat("glass"), Vector3(hx - WIN_W * 0.5, wy0, zg - 0.02), Vector3(hx + WIN_W * 0.5, wy1, zg + 0.02), Color("#a9c9db"))
				b.box_mm(solid, Vector3(hx - 0.04, wy0, zg - 0.04), Vector3(hx + 0.04, wy1, zg + 0.04), white)
				b.box_mm(solid, Vector3(hx - WIN_W * 0.5, (wy0 + wy1) * 0.5 - 0.04, zg - 0.04), Vector3(hx + WIN_W * 0.5, (wy0 + wy1) * 0.5 + 0.04, zg + 0.04), white)
	# The bookshelf wall with its doorway: wood, with rows of coloured books on both sides.
	var books := [Color("#c8423b"), Color("#2f6f8f"), Color("#e0a43a"), Color("#5f9a45"), Color("#8a5aa8")]
	for part in divider_parts(lot):
		b.box_mm(Mats.get_mat("wood"), part.position, part.end, Color("#8a6a52"))
		if part.size.y > 1.0:
			for row in 4:
				var yy := part.position.y + 0.35 + row * 0.62
				var xx := part.position.x + 0.1
				var k := row
				while xx < part.end.x - 0.25:
					var bw := 0.12 + float((k * 7) % 5) * 0.03
					for zz in [part.position.z - 0.02, part.end.z]:
						b.box_mm(solid, Vector3(xx, yy, zz), Vector3(xx + bw, yy + 0.42, zz + 0.02), books[k % books.size()])
					xx += bw + 0.03
					k += 1
	# The hanging lamp: a cord and a big round shade (solid: fly round it).
	var lp: Variant = lamp_pos(lot)
	if lp != null:
		b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(), lp + Vector3(0, 0.3, 0)), 0.015, 0.015, y1 - lp.y - 0.3, 4, Color("#3b3f46"))
		b.cylinder(Mats.get_mat("cloth"), Transform3D(Basis(), lp - Vector3(0, 0.25, 0)), 0.42, 0.18, 0.55, 12, Color("#f2d58f"))
		b.sphere(Mats.get_mat("glow"), lp - Vector3(0, 0.22, 0), Vector3(0.14, 0.12, 0.14), 3, 6, Color("#ffd27a"))
	else:
		b.sphere(Mats.get_mat("glow"), Vector3(tx, y1 - 0.12, zc), Vector3(0.22, 0.08, 0.22), 3, 8, Color("#ffd27a"))


## Fire escape on the face +X (3) or -X (2): a platform at every upper storey with a zig-zag
## stair between them, sticking out FIRE_DEPTH from the wall.
const FIRE_DEPTH := 0.8


static func fire_platforms(r: Rect2, face: int, storeys: int) -> Array:
	var out := []
	var x_wall := r.end.x if face == 3 else r.position.x
	var dir := 1.0 if face == 3 else -1.0
	var zc := r.get_center().y
	for s in range(1, storeys):
		var y := GROUND_FLOOR + (s - 1) * STOREY
		out.append(AABB(Vector3(minf(x_wall, x_wall + dir * FIRE_DEPTH), y - 0.06, zc - 2.6), Vector3(FIRE_DEPTH, 0.08, 5.2)))
	return out


func _fire_escape(b: MeshBuilder, r: Rect2, face: int, storeys: int) -> void:
	var metal := Mats.get_mat("metal")
	var iron := Color("#3b3f46")
	var dir := 1.0 if face == 3 else -1.0
	var x_wall := r.end.x if face == 3 else r.position.x
	var plats := fire_platforms(r, face, storeys)
	for k in plats.size():
		var p: AABB = plats[k]
		b.box_mm(metal, p.position, p.end, iron)
		# Railing on the outer edge.
		var xo := x_wall + dir * (FIRE_DEPTH - 0.04)
		b.box_mm(metal, Vector3(xo - 0.03, p.end.y + 0.9, p.position.z), Vector3(xo + 0.03, p.end.y + 0.95, p.end.z), iron)
		for zz in [p.position.z, p.get_center().z, p.end.z]:
			b.box_mm(metal, Vector3(xo - 0.03, p.end.y, zz - 0.03), Vector3(xo + 0.03, p.end.y + 0.95, zz + 0.03), iron)
		# A stair up to the next platform, zig-zagging.
		if k + 1 < plats.size():
			var z_a := p.position.z + 0.6 if k % 2 == 0 else p.end.z - 0.6
			var z_b := p.end.z - 0.6 if k % 2 == 0 else p.position.z + 0.6
			var y_a := p.end.y
			var y_b: float = (plats[k + 1] as AABB).position.y
			var xm := x_wall + dir * FIRE_DEPTH * 0.5
			var mid := Vector3(xm, (y_a + y_b) * 0.5, (z_a + z_b) * 0.5)
			var run := Vector3(0, y_b - y_a, z_b - z_a)
			var basis := Basis(Vector3.RIGHT, -atan2(run.y, run.z) if run.z > 0.0 else atan2(run.y, -run.z))
			b.box(metal, Transform3D(basis, mid), Vector3(FIRE_DEPTH * 0.7, 0.06, run.length()), iron)


func _parapets(r: Rect2, top: float) -> Array:
	var t := 0.3
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	return [
		[Vector3(x0, top, z0), Vector3(x1, top + PARAPET, z0 + t)],
		[Vector3(x0, top, z1 - t), Vector3(x1, top + PARAPET, z1)],
		[Vector3(x0, top, z0), Vector3(x0 + t, top + PARAPET, z1)],
		[Vector3(x1 - t, top, z0), Vector3(x1, top + PARAPET, z1)],
	]


## A window pane with a pale frame, facing `out`.
func _pane(b: MeshBuilder, glass: Material, frame: Material, c: Vector3, out: Vector3, col: Color) -> void:
	# To the viewer's right when looking at the face from outside (keeps the panes front-facing).
	var side := Vector3(out.z, 0, -out.x)
	var hw := 0.6
	var hh := 0.8
	var f := 0.12
	b.quad(frame, c - side * (hw + f) - Vector3(0, hh + f, 0), c + side * (hw + f) - Vector3(0, hh + f, 0), c + side * (hw + f) + Vector3(0, hh + f, 0), c - side * (hw + f) + Vector3(0, hh + f, 0), Color("#f1ebe0"))
	var g := c + out * 0.015
	b.quad(glass, g - side * hw - Vector3(0, hh, 0), g + side * hw - Vector3(0, hh, 0), g + side * hw + Vector3(0, hh, 0), g - side * hw + Vector3(0, hh, 0), col)


func _shopfront(b: MeshBuilder, r: Rect2, face: int, aw: Color) -> void:
	var glass := Mats.get_mat("window_lit")
	var awning := Mats.get_mat("awning")
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	var out: Vector3
	var a: Vector3
	var bb: Vector3
	match face:
		0:
			out = Vector3(0, 0, -1)
			a = Vector3(x0 + 0.8, 0, z0 - 0.04)
			bb = Vector3(x1 - 0.8, 0, z0 - 0.04)
		1:
			out = Vector3(0, 0, 1)
			a = Vector3(x1 - 0.8, 0, z1 + 0.04)
			bb = Vector3(x0 + 0.8, 0, z1 + 0.04)
		2:
			out = Vector3(-1, 0, 0)
			a = Vector3(x0 - 0.04, 0, z1 - 0.8)
			bb = Vector3(x0 - 0.04, 0, z0 + 0.8)
		_:
			out = Vector3(1, 0, 0)
			a = Vector3(x1 + 0.04, 0, z0 + 0.8)
			bb = Vector3(x1 + 0.04, 0, z1 - 0.8)
	b.quad(glass, bb + Vector3(0, 0.5, 0), a + Vector3(0, 0.5, 0), a + Vector3(0, 2.7, 0), bb + Vector3(0, 2.7, 0), Color("#f3d9a2"))
	# Striped awning sloping out over the sidewalk.
	var n := 8
	for i in n:
		var p0 := a.lerp(bb, float(i) / n)
		var p1 := a.lerp(bb, float(i + 1) / n)
		var col := aw if i % 2 == 0 else Color("#fbf6ea")
		b.quad(awning, p1 + Vector3(0, 3.3, 0), p0 + Vector3(0, 3.3, 0), p0 + out * 1.4 + Vector3(0, 2.7, 0), p1 + out * 1.4 + Vector3(0, 2.7, 0), col)


func _roof_feature(b: MeshBuilder, r: Rect2, top: float, f: String, rng: RandomNumberGenerator) -> void:
	var metal := Mats.get_mat("metal")
	var wood := Mats.get_mat("wood")
	var c := Vector3(r.get_center().x, top, r.get_center().y)
	var hx := r.size.x * 0.5
	var hz := r.size.y * 0.5
	match f:
		"tank":
			# The classic wooden water tower on steel legs, with a cone hat.
			var t := c + Vector3(-hx * 0.45, 0, hz * 0.4)
			for lx in [-1.0, 1.0]:
				for lz in [-1.0, 1.0]:
					b.cylinder(metal, Transform3D(Basis(), t + Vector3(lx, 0, lz)), 0.1, 0.1, 2.6, 6, Color("#4f5560"))
			b.box_mm(metal, t + Vector3(-1.3, 2.5, -1.3), t + Vector3(1.3, 2.65, 1.3), Color("#4f5560"))
			b.cylinder(wood, Transform3D(Basis(), t + Vector3(0, 2.65, 0)), 1.5, 1.5, 2.6, 14, Color("#a87a4f"))
			for ring in 3:
				b.cylinder(metal, Transform3D(Basis(), t + Vector3(0, 2.9 + ring * 0.85, 0)), 1.53, 1.53, 0.08, 14, Color("#3b3f46"), false)
			b.cylinder(Mats.get_mat("shingle"), Transform3D(Basis(), t + Vector3(0, 5.25, 0)), 1.7, 0.12, 1.0, 14, Color("#5b5550"))
		"hut":
			var h := c + Vector3(hx * 0.4, 0, hz * 0.35)
			b.box_mm(Mats.get_mat("brick"), h + Vector3(-1.4, 0, -1.2), h + Vector3(1.4, 2.5, 1.2), Color("#c9785a"))
			b.box_mm(Mats.get_mat("solid"), h + Vector3(-1.5, 2.5, -1.3), h + Vector3(1.5, 2.65, 1.3), Color("#e6dccb"))
			b.box_mm(Mats.get_mat("solid"), h + Vector3(-0.45, 0, -1.22), h + Vector3(0.45, 2.0, -1.2), Color("#2f5560"))
		"ac":
			for i in rng.randi_range(1, 3):
				var p := c + Vector3(rng.randf_range(-hx + 1.5, hx - 1.5), 0, rng.randf_range(-hz + 1.5, -1.0))
				b.box_mm(metal, p + Vector3(-0.7, 0, -0.5), p + Vector3(0.7, 0.9, 0.5), Color("#c9ced2"))
				b.cylinder(metal, Transform3D(Basis(), p + Vector3(0, 0.9, 0)), 0.4, 0.4, 0.06, 10, Color("#5b6270"))
		"skylight":
			var s := c + Vector3(rng.randf_range(-1.5, 1.5), 0, -hz * 0.3)
			b.box_mm(Mats.get_mat("solid"), s + Vector3(-1.2, 0, -0.9), s + Vector3(1.2, 0.5, 0.9), Color("#e6dccb"))
			b.box_mm(Mats.get_mat("glass"), s + Vector3(-1.05, 0.5, -0.75), s + Vector3(1.05, 0.62, 0.75), Color("#a9c9db"))
		"garden":
			# Planters along the two side edges (the ends stay open for planes coming in to land)
			# and a little lawn.
			b.box_mm(Mats.get_mat("grass"), c + Vector3(-hx + 1.0, 0.03, -hz + 1.0), c + Vector3(hx - 1.0, 0.06, hz - 1.0), Color("#a9c97e"), 4)
			for i in 6:
				var t := float(i) / 5.0
				for side in [-1.0, 1.0]:
					var p := c + Vector3(side * (hx - 0.9), 0, lerpf(-hz + 1.5, hz - 1.5, t))
					b.box_mm(wood, p + Vector3(-0.35, 0, -0.6), p + Vector3(0.35, 0.45, 0.6), Color("#8a6a52"))
					b.sphere(Mats.get_mat("foliage"), p + Vector3(0, 0.6, 0), Vector3(0.35, 0.38, 0.55), 3, 7, Color(TownBuilder.GREENS[(i + int(side) + 1) % 5]))
		"billboard":
			var p := c + Vector3(0, 0, hz - 1.0)
			for lx in [-3.0, 3.0]:
				b.box_mm(metal, p + Vector3(lx - 0.1, 0, -0.1), p + Vector3(lx + 0.1, 3.2, 0.1), Color("#4f5560"))
			b.box_mm(Mats.get_mat("solid"), p + Vector3(-4.0, 2.4, -0.15), p + Vector3(4.0, 5.4, 0.0), Color("#f6efe0"))
			b.box_mm(Mats.get_mat("solid"), p + Vector3(-3.7, 2.7, -0.17), p + Vector3(3.7, 5.1, -0.15), Color(["#6ec6ff", "#f6a96b", "#8fe3b0", "#ff7eb6"][rng.randi() % 4]))
		"antenna":
			var p := c + Vector3(hx * 0.6, 0, -hz * 0.5)
			b.cylinder(metal, Transform3D(Basis(), p), 0.08, 0.03, 5.5, 5, Color("#9aa3a8"))
			b.box_mm(metal, p + Vector3(-0.8, 4.2, -0.03), p + Vector3(0.8, 4.26, 0.03), Color("#9aa3a8"))
		"chimneys":
			for i in 2:
				var p := c + Vector3(rng.randf_range(-hx + 1.0, hx - 1.0), 0, rng.randf_range(-hz + 1.0, hz - 1.0))
				b.box_mm(Mats.get_mat("brick"), p + Vector3(-0.4, 0, -0.4), p + Vector3(0.4, 1.6, 0.4), Color("#b4654a"))


## Phones, far away: plain blocks with a darker band per storey.
func _build_far(b: MeshBuilder) -> void:
	var solid := Mats.get_mat("solid")
	for lot in lots:
		var r: Rect2 = lot.rect
		var top := lot_top(lot)
		var wall: Color = lot.wall
		if lot.brick:
			wall = wall.lerp(Color("#b5674c"), 0.6)
		b.box_mm(solid, Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, top, r.end.y), wall, 63 - 8)


func _build_colliders() -> void:
	for lot in lots:
		var r: Rect2 = lot.rect
		var top := lot_top(lot)
		var c := Vector3(r.get_center().x, 0, r.get_center().y)
		if (lot.get("tunnel", {}) as Dictionary).is_empty():
			add_box("wall", c + Vector3(0, top * 0.5, 0), Vector3(r.size.x, top, r.size.y))
		else:
			for part in tunnel_parts(lot):
				add_box("wall", part.get_center(), part.size)
			for part in divider_parts(lot):
				add_box("furniture", part.get_center(), part.size)
			var t: Dictionary = lot.tunnel
			for end in [[r.end.y, t.get("closed_in", [])], [r.position.y, t.get("closed_out", [])]]:
				for cx in end[1]:
					var zg: float = end[0] - END_WALL * 0.5 if end[0] > r.get_center().y else end[0] + END_WALL * 0.5
					add_box("glass", Vector3(float(t.x) + float(cx), _flat_y(t) + SILL + WIN_H * 0.5, zg), Vector3(WIN_W, WIN_H, 0.1))
			var lp: Variant = lamp_pos(lot)
			if lp != null:
				add_cylinder("lamp", lp - Vector3(0, 0.55, 0), 0.42, 0.6)
		if lot.get("parapet", true):
			for e in _parapets(r, top):
				add_box("wall", (e[0] + e[1]) * 0.5 + Vector3(0, 0.03, 0), e[1] - e[0] + Vector3(0, 0.06, 0))
		var hx := r.size.x * 0.5
		var hz := r.size.y * 0.5
		if int(lot.get("fire_face", -1)) >= 0:
			for p: AABB in fire_platforms(r, int(lot.fire_face), int(lot.storeys)):
				# The platform and its railing.
				add_box("wall", p.get_center() + Vector3(0, 0.45, 0), p.size + Vector3(0, 0.9, 0))
		for f in lot.get("roof", []):
			match str(f):
				"tank": add_cylinder("post", c + Vector3(-hx * 0.45, top, hz * 0.4), 1.6, 6.25)
				"hut": add_box("wall", c + Vector3(hx * 0.4, top + 1.33, hz * 0.35), Vector3(3.0, 2.65, 2.6))
				"billboard": add_box("wall", c + Vector3(0, top + 2.7, hz - 1.0), Vector3(8.2, 5.4, 0.4))


func _draw_distance() -> float:
	return 700.0
