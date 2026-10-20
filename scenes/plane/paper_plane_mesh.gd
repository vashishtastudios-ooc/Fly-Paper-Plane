class_name PaperPlaneMesh
extends RefCounted
## Low-poly folded paper planes (the Hangar's "Plane" designs). Forward is -Z. Flat shaded, double
## sided, mapped with the generated paper texture; coloured stripes come from vertex colours, so
## they show on every paper. The design is purely visual: every plane flies exactly the same.

const SCALE := 1.35
const LENGTH := 0.78 * SCALE
const SPAN := 0.64 * SCALE
## The classic dart's wingtips in plane space (used for trails).
const TIP_LEFT := Vector3(-0.32 * SCALE, 0.05 * SCALE, 0.37 * SCALE)
const TIP_RIGHT := Vector3(0.32 * SCALE, 0.05 * SCALE, 0.37 * SCALE)

## Each design: where its trails leave the wingtips (unscaled, left tip; the right one mirrors)
## and where the wing stickers sit (unscaled centre of the left one, and their size).
const SHAPES := {
	"dart": {"tip": Vector3(-0.32, 0.05, 0.37), "sticker": Vector3(-0.15, 0.04, 0.17), "sticker_size": 0.055},
	"glider": {"tip": Vector3(-0.44, 0.04, 0.3), "sticker": Vector3(-0.2, 0.025, 0.14), "sticker_size": 0.06},
	"stubby": {"tip": Vector3(-0.34, 0.05, 0.3), "sticker": Vector3(-0.15, 0.03, 0.12), "sticker_size": 0.05},
	"speedster": {"tip": Vector3(-0.22, 0.04, 0.4), "sticker": Vector3(-0.11, 0.025, 0.22), "sticker_size": 0.04},
	"swallow": {"tip": Vector3(-0.38, 0.05, 0.28), "sticker": Vector3(-0.17, 0.03, 0.1), "sticker_size": 0.05},
	"biplane": {"tip": Vector3(-0.36, 0.06, 0.12), "sticker": Vector3(-0.2, 0.065, 0.05), "sticker_size": 0.05},
	"ring": {"tip": Vector3(-0.17, 0.05, 0.3), "sticker": Vector3(-0.07, 0.015, -0.05), "sticker_size": 0.035},
	"handmade": {"tip": Vector3(-0.32, 0.05, 0.37), "sticker": Vector3(-0.15, 0.045, 0.17), "sticker_size": 0.055},
}

const PAPER := Color(1, 1, 1)
const SHADE := Color(0.95, 0.95, 0.94)
const SHADE2 := Color(0.97, 0.97, 0.96)
const KEEL := Color(0.86, 0.85, 0.82)

static var _meshes := {}


static func get_mesh(shape := "dart") -> ArrayMesh:
	if not SHAPES.has(shape):
		shape = "dart"
	if _meshes.has(shape):
		return _meshes[shape]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match shape:
		"glider": _glider(st)
		"stubby": _stubby(st)
		"speedster": _speedster(st)
		"swallow": _swallow(st)
		"biplane": _biplane(st)
		"ring": _ring(st)
		"handmade": _handmade(st)
		_: _dart(st)
	var mesh := st.commit()
	# Scale the unit plane up to its in-game size.
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] *= SCALE
	arrays[Mesh.ARRAY_VERTEX] = verts
	mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, Mats.get_mat("paper_plane"))
	_meshes[shape] = mesh
	return mesh


## Wingtip in plane space (scaled), side -1 = left, 1 = right.
static func tip(shape: String, side: float) -> Vector3:
	var t: Vector3 = SHAPES.get(shape, SHAPES.dart).tip
	return Vector3(t.x * -side, t.y, t.z) * SCALE


# --- Designs ----------------------------------------------------------------------------------

## 1. Classic dart: a nose, two folded wings, a keel and little upturned winglets.
static func _dart(st: SurfaceTool) -> void:
	var nose := Vector3(0, 0.0, -0.41)
	var tail_c := Vector3(0, 0.0, 0.37)
	var tail_keel := Vector3(0, -0.1, 0.37)
	var keel_front := Vector3(0, -0.015, -0.3)
	var tip_l := Vector3(-0.32, 0.05, 0.37)
	var tip_r := Vector3(0.32, 0.05, 0.37)
	var root_l := Vector3(-0.035, 0.0, 0.37)
	var root_r := Vector3(0.035, 0.0, 0.37)
	var mid_l := Vector3(-0.12, 0.015, 0.05)
	var mid_r := Vector3(0.12, 0.015, 0.05)
	_tri(st, nose, mid_l, root_l, PAPER)
	_tri(st, nose, tip_l, mid_l, SHADE)
	_tri(st, mid_l, tip_l, root_l, SHADE2)
	_tri(st, nose, root_r, mid_r, PAPER)
	_tri(st, nose, mid_r, tip_r, SHADE)
	_tri(st, mid_r, root_r, tip_r, SHADE2)
	_tri(st, nose, root_l, tail_keel, KEEL)
	_tri(st, nose, tail_keel, root_r, Color(0.88, 0.87, 0.84))
	_tri(st, keel_front, tail_keel, tail_c, Color(0.84, 0.83, 0.8))
	_tri(st, tip_l, tip_l + Vector3(0.0, 0.07, -0.02), tip_l + Vector3(0.03, 0.0, -0.14), Color(0.93, 0.93, 0.92))
	_tri(st, tip_r, tip_r + Vector3(-0.03, 0.0, -0.14), tip_r + Vector3(0.0, 0.07, -0.02), Color(0.93, 0.93, 0.92))


## 2. Wide glider: broad wings with square tips and two green stripes near each tip.
static func _glider(st: SurfaceTool) -> void:
	var green := Color("#6fa47e")
	var nose := Vector3(0, 0, -0.38)
	for side in [-1.0, 1.0]:
		var s: float = side
		var lead := func(x: float) -> Vector3: return Vector3(s * x, 0.04 * x / 0.44, -0.38 + x / 0.44 * 0.5)
		var trail := func(x: float) -> Vector3: return Vector3(s * x, 0.04 * x / 0.44, 0.32 - (x - 0.03) / 0.41 * 0.02)
		var root := Vector3(s * 0.03, 0, 0.32)
		var mid_lead: Vector3 = lead.call(0.2)
		var mid_trail: Vector3 = trail.call(0.2)
		_tri_s(st, s, nose, mid_lead, root, PAPER)
		_tri_s(st, s, mid_lead, mid_trail, root, SHADE2)
		# Outer wing in bands: plain, stripe, plain, stripe, plain.
		var xs := [0.2, 0.29, 0.32, 0.35, 0.38, 0.44]
		for k in xs.size() - 1:
			var a: Vector3 = lead.call(xs[k])
			var b: Vector3 = lead.call(xs[k + 1])
			var c: Vector3 = trail.call(xs[k + 1])
			var d: Vector3 = trail.call(xs[k])
			_quad_s(st, s, a, b, c, d, green if k == 1 or k == 3 else SHADE)
	_keel(st, nose, Vector3(0, -0.11, 0.3), 0.03, 0.32)


## 3. Stubby: short and wide-swept, with red wingtips and a red tail fin.
static func _stubby(st: SurfaceTool) -> void:
	var red := Color("#e06a52")
	var nose := Vector3(0, 0, -0.28)
	for side in [-1.0, 1.0]:
		var s: float = side
		var tip := Vector3(s * 0.34, 0.05, 0.3)
		var root := Vector3(s * 0.04, 0, 0.26)
		var mid := Vector3(s * 0.12, 0.02, 0.02)
		var tip_front := Vector3(s * 0.27, 0.04, 0.16)
		var tip_back := Vector3(s * 0.25, 0.04, 0.28)
		_tri_s(st, s, nose, mid, root, PAPER)
		_tri_s(st, s, nose, tip_front, mid, SHADE)
		_tri_s(st, s, mid, tip_front, tip_back, SHADE2)
		_tri_s(st, s, mid, tip_back, root, SHADE2)
		_tri_s(st, s, tip_front, tip, tip_back, red)
		# Upturned red winglet.
		_tri_s(st, s, tip, tip + Vector3(0, 0.08, -0.02), tip + Vector3(-s * 0.04, 0, -0.1), red)
	_keel(st, nose, Vector3(0, -0.1, 0.26), 0.04, 0.26)
	_tri(st, Vector3(0, 0, 0.12), Vector3(0, 0.14, 0.3), Vector3(0, 0, 0.27), red)
	_tri(st, Vector3(0, -0.08, -0.26), Vector3(0, 0, -0.28), Vector3(0, -0.02, -0.18), red)


## 4. Speedster: long and slim, with a blue stripe along each wing.
static func _speedster(st: SurfaceTool) -> void:
	var blue := Color("#6d8fd6")
	var nose := Vector3(0, 0, -0.55)
	for side in [-1.0, 1.0]:
		var s: float = side
		var tip := Vector3(s * 0.22, 0.04, 0.4)
		var root := Vector3(s * 0.025, 0, 0.4)
		var a := Vector3(s * 0.07, 0.012, -0.12)
		var b := Vector3(s * 0.1, 0.018, -0.02)
		var c := Vector3(s * 0.16, 0.03, 0.32)
		var d := Vector3(s * 0.12, 0.022, 0.36)
		_tri_s(st, s, nose, a, root, PAPER)
		_tri_s(st, s, nose, tip, b, SHADE)
		_tri_s(st, s, a, b, d, blue)
		_tri_s(st, s, b, c, d, blue)
		_tri_s(st, s, b, tip, c, SHADE)
		_tri_s(st, s, c, tip, d, SHADE2)
		_tri_s(st, s, d, tip, root, SHADE2)
		_tri_s(st, s, a, d, root, PAPER)
		_tri_s(st, s, nose, b, a, SHADE2)
	_keel(st, nose, Vector3(0, -0.09, 0.4), 0.025, 0.4)


## 5. Swallow tail: swept wings and a forked tail, with yellow stripes near the tips.
static func _swallow(st: SurfaceTool) -> void:
	var yellow := Color("#f2c14e")
	var nose := Vector3(0, 0, -0.4)
	for side in [-1.0, 1.0]:
		var s: float = side
		var tip := Vector3(s * 0.38, 0.05, 0.28)
		var notch := Vector3(s * 0.04, 0, 0.18)
		var fork := Vector3(s * 0.11, 0.01, 0.42)
		var inner := Vector3(s * 0.16, 0.025, 0.24)
		var mid := Vector3(s * 0.13, 0.02, 0.0)
		var s1 := Vector3(s * 0.27, 0.035, 0.13)
		var s2 := Vector3(s * 0.3, 0.04, 0.17)
		var s1b := Vector3(s * 0.25, 0.035, 0.25)
		var s2b := Vector3(s * 0.28, 0.04, 0.26)
		_tri_s(st, s, nose, mid, notch, PAPER)
		_tri_s(st, s, mid, inner, notch, SHADE2)
		_tri_s(st, s, notch, inner, fork, SHADE2)
		_tri_s(st, s, nose, s1, mid, SHADE)
		_tri_s(st, s, mid, s1, s1b, SHADE)
		_tri_s(st, s, mid, s1b, inner, SHADE)
		_quad_s(st, s, s1, s2, s2b, s1b, yellow)
		_tri_s(st, s, s2, tip, s2b, SHADE)
		_tri_s(st, s, nose, s2, s1, SHADE)
		_tri_s(st, s, nose, tip, s2, SHADE)
	_keel(st, nose, Vector3(0, -0.1, 0.18), 0.04, 0.18)


## 6. Double wing: a slim body with a top and a bottom wing, red stripes on the tips.
static func _biplane(st: SurfaceTool) -> void:
	var red := Color("#e0605a")
	var pink := Color("#eea19c")
	var nose := Vector3(0, 0, -0.42)
	_keel(st, nose, Vector3(0, -0.13, 0.36), 0.03, 0.36)
	for side in [-1.0, 1.0]:
		var s: float = side
		# Slim top fold of the body.
		_tri_s(st, s, nose, Vector3(s * 0.05, 0.01, 0.0), Vector3(s * 0.03, 0, 0.36), PAPER)
		# Top wing: straight, slightly swept.
		var y := 0.03
		var xs := [0.04, 0.27, 0.31, 0.34, 0.36]
		for k in xs.size() - 1:
			var x0: float = xs[k]
			var x1: float = xs[k + 1]
			var a := Vector3(s * x0, y + x0 * 0.08, -0.06 + x0 * 0.1)
			var b := Vector3(s * x1, y + x1 * 0.08, -0.06 + x1 * 0.1)
			var c := Vector3(s * x1, y + x1 * 0.08, 0.13 + x1 * 0.08)
			var d := Vector3(s * x0, y + x0 * 0.08, 0.13 + x0 * 0.08)
			_quad_s(st, s, a, b, c, d, red if k == 1 or k == 3 else (SHADE if k == 0 else SHADE2))
		# Bottom wing, a little shorter and further back.
		var yb := -0.1
		var xb := [0.02, 0.24, 0.28, 0.31]
		for k in xb.size() - 1:
			var x0: float = xb[k]
			var x1: float = xb[k + 1]
			var a := Vector3(s * x0, yb + x0 * 0.06, 0.02 + x0 * 0.1)
			var b := Vector3(s * x1, yb + x1 * 0.06, 0.02 + x1 * 0.1)
			var c := Vector3(s * x1, yb + x1 * 0.06, 0.19 + x1 * 0.08)
			var d := Vector3(s * x0, yb + x0 * 0.06, 0.19 + x0 * 0.08)
			_quad_s(st, s, a, b, c, d, pink if k == 1 else Color(0.9, 0.9, 0.88))
		# Little tail wing.
		_tri_s(st, s, Vector3(0, 0, 0.26), Vector3(s * 0.12, 0.02, 0.38), Vector3(0, 0, 0.38), SHADE)


## 7. Ring wing: a dart nose with a paper hoop for a wing, blue checks around the hoop.
static func _ring(st: SurfaceTool) -> void:
	var blue := Color("#7d9fd8")
	var nose := Vector3(0, 0, -0.42)
	for side in [-1.0, 1.0]:
		var s: float = side
		_tri_s(st, s, nose, Vector3(s * 0.09, 0.01, 0.12), Vector3(s * 0.03, 0, 0.3), PAPER)
	_keel(st, nose, Vector3(0, -0.08, 0.3), 0.03, 0.3)
	var centre := Vector3(0, 0.05, 0)
	var r := 0.17
	var n := 16
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := centre + Vector3(cos(a0) * r, sin(a0) * r * 0.75, 0)
		var p1 := centre + Vector3(cos(a1) * r, sin(a1) * r * 0.75, 0)
		var col := blue if i % 4 == 1 else (SHADE if i % 2 == 0 else SHADE2)
		_quad(st, p0 + Vector3(0, 0, 0.18), p1 + Vector3(0, 0, 0.18), p1 + Vector3(0, 0, 0.32), p0 + Vector3(0, 0, 0.32), col)


## 8. Handmade: the classic dart, a little crumpled.
static func _handmade(st: SurfaceTool) -> void:
	var tmp := SurfaceTool.new()
	tmp.begin(Mesh.PRIMITIVE_TRIANGLES)
	_dart(tmp)
	var arr := tmp.commit().surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var tris := []
	if idx.is_empty():
		for i in range(0, v.size(), 3):
			tris.append([v[i], v[i + 2], v[i + 1], c[i]])
	else:
		for i in range(0, idx.size(), 3):
			tris.append([v[idx[i]], v[idx[i + 2]], v[idx[i + 1]], c[idx[i]]])
	# Split each facet in four and nudge the new corners: creases everywhere.
	for t in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var cc: Vector3 = t[2]
		var ab := _crumple((a + b) * 0.5)
		var bc := _crumple((b + cc) * 0.5)
		var ca := _crumple((cc + a) * 0.5)
		var col: Color = t[3]
		_tri(st, a, ab, ca, col)
		_tri(st, ab, b, bc, col.darkened(0.03))
		_tri(st, ca, bc, cc, col.darkened(0.05))
		_tri(st, ab, bc, ca, col.lightened(0.02))


## A small, repeatable bump (the same point always moves the same way, so shared edges stay joined).
static func _crumple(p: Vector3) -> Vector3:
	var h := sin(p.x * 91.7 + p.z * 47.3) * 43758.5453
	var k := (h - floorf(h)) - 0.5
	return p + Vector3(k * 0.02, k * 0.07, k * 0.02)


# --- Helpers ----------------------------------------------------------------------------------

## The two folded halves under the body, from the nose back to the tail.
static func _keel(st: SurfaceTool, nose: Vector3, keel_tail: Vector3, root_x: float, root_z: float) -> void:
	_tri(st, nose, Vector3(-root_x, 0, root_z), keel_tail, KEEL)
	_tri(st, nose, keel_tail, Vector3(root_x, 0, root_z), Color(0.88, 0.87, 0.84))


## A triangle given for the left wing (side -1) or the right one (side 1, winding flipped so
## both faces point up).
static func _tri_s(st: SurfaceTool, side: float, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	if side < 0.0:
		_tri(st, a, b, c, col)
	else:
		_tri(st, a, c, b, col)


static func _quad_s(st: SurfaceTool, side: float, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri_s(st, side, a, b, c, col)
	_tri_s(st, side, a, c, d, col)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(st, a, b, c, col)
	_tri(st, a, c, d, col)


static func _uv(p: Vector3) -> Vector2:
	return Vector2(p.x / (SPAN / SCALE) + 0.5, (p.z + 0.41) / (LENGTH / SCALE)) * Vector2(0.92, 0.92) + Vector2(0.04, 0.04)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	for p in [a, c, b]:
		st.set_color(col)
		st.set_normal(n)
		st.set_uv(_uv(p))
		st.add_vertex(p)
