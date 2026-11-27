extends Prop
## Laundry Day (flight 10) on Thimble Mews: three curtains of bedsheets strung across the mews,
## each with one gap (left, right, left) that sway in the breeze, a tin-can telephone between two
## windows in the squeeze, and the giant laundry basket in the end yard (the landing spot).
## World coordinates.

## Curtains: [z, gap x0, gap x1]. Sheets hang from the line at LINE_Y down to SHEET_BOTTOM.
const CURTAINS := [[55.0, 31.6, 33.4], [49.0, 32.8, 34.6], [43.0, 31.8, 33.6]]
const LINE_Y := 4.0
const SHEET_BOTTOM := 0.6
const MEWS_X0 := 30.0
const MEWS_X1 := 36.0
const BASKET := Vector3(33.0, 0.0, -76.0)
const BASKET_R := 1.5
const BASKET_TOP := 0.7
const PHONE := [Vector3(32.2, 4.6, 33.0), Vector3(34.8, 4.6, 33.0)]

const SHEET_COLS := ["#fbf8f0", "#a9c9db", "#f2d58f", "#e6c3da", "#b9d6a8", "#f4c9a0", "#ffffff"]

var _curtains: Array[Node3D] = []
var _t := 0.0


func _ready() -> void:
	super._ready()
	for i in CURTAINS.size():
		var c: Array = CURTAINS[i]
		var pivot := Node3D.new()
		pivot.name = "Curtain_%d" % i
		pivot.position = Vector3(0, LINE_Y, c[0])
		add_child(pivot)
		var b := MeshBuilder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 300 + i
		var spans := [[MEWS_X0, c[1]], [c[2], MEWS_X1]]
		var k := 0
		for s: Array in spans:
			var x0: float = s[0]
			var x1: float = s[1]
			var n := maxi(1, ceili((x1 - x0) / 1.6))
			for j in n:
				var xa := x0 + (x1 - x0) * j / n + 0.03
				var xb := x0 + (x1 - x0) * (j + 1) / n - 0.03
				var col := Color(SHEET_COLS[(i * 3 + k) % SHEET_COLS.size()])
				var bottom := SHEET_BOTTOM - LINE_Y + rng.randf_range(-0.05, 0.25)
				b.box_mm(Mats.get_mat("cloth"), Vector3(xa, bottom, -0.02), Vector3(xb, -0.04, 0.02), col)
				# A stripe or two on some sheets.
				if k % 2 == 1:
					b.box_mm(Mats.get_mat("cloth"), Vector3(xa, bottom + 0.3, -0.025), Vector3(xb, bottom + 0.45, 0.025), col.darkened(0.18))
				for px in [xa + 0.1, xb - 0.1]:
					b.box(Mats.get_mat("wood"), Transform3D(Basis(), Vector3(px, -0.02, 0)), Vector3(0.03, 0.1, 0.05), Color("#c9a27e"))
				k += 1
		b.tube(Mats.get_mat("rope"), PackedVector3Array([Vector3(MEWS_X0, 0, 0), Vector3((MEWS_X0 + MEWS_X1) * 0.5, -0.04, 0), Vector3(MEWS_X1, 0, 0)]), 0.012, 3, Color("#f3ecd6"))
		pivot.add_child(b.build_instance("Sheets", false))
		_curtains.append(pivot)
	set_process(true)


func _build(b: MeshBuilder) -> void:
	var solid := Mats.get_mat("solid")
	# The laundry basket: woven sides, a rolled rim, two handles and a heap of folded washing.
	var wicker := Color("#c99a5a")
	b.cylinder(Mats.get_mat("wood"), Transform3D(Basis(), BASKET), BASKET_R, BASKET_R + 0.1, BASKET_TOP, 24, wicker)
	for k in 4:
		b.cylinder(Mats.get_mat("wood"), Transform3D(Basis(), BASKET + Vector3(0, 0.1 + k * 0.15, 0)), BASKET_R + 0.04 + k * 0.025, BASKET_R + 0.04 + k * 0.025, 0.05, 24, wicker.darkened(0.15))
	b.cylinder(Mats.get_mat("wood"), Transform3D(Basis(), BASKET + Vector3(0, BASKET_TOP - 0.02, 0)), BASKET_R + 0.16, BASKET_R + 0.16, 0.09, 24, wicker.lightened(0.1))
	for s in [-1.0, 1.0]:
		b.tube(Mats.get_mat("wood"), PackedVector3Array([BASKET + Vector3(s * (BASKET_R + 0.12), 0.45, -0.4), BASKET + Vector3(s * (BASKET_R + 0.3), 0.6, 0.0), BASKET + Vector3(s * (BASKET_R + 0.12), 0.45, 0.4)]), 0.04, 5, wicker.darkened(0.1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 9:
		var a := TAU * k / 9.0
		var r := 0.85 if k % 3 else 0.35
		var p := BASKET + Vector3(cos(a) * r, BASKET_TOP - 0.1, sin(a) * r)
		b.box(Mats.get_mat("cloth"), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), Vector3(0.6, 0.12, 0.45), Color(SHEET_COLS[k % SHEET_COLS.size()]))
	b.cylinder(Mats.get_mat("cloth"), Transform3D(Basis(), BASKET + Vector3(0, BASKET_TOP - 0.15, 0)), BASKET_R - 0.05, BASKET_R - 0.05, 0.12, 24, Color("#f4f0e6"))
	# A peg bag on the wall and a sock that missed the basket.
	b.box_mm(Mats.get_mat("cloth"), Vector3(26.25, 1.0, -73.4), Vector3(26.3, 1.4, -72.9), Color("#e8546a"))
	b.box(Mats.get_mat("cloth"), Transform3D(Basis(Vector3.UP, 0.6), BASKET + Vector3(2.1, 0.03, 0.8)), Vector3(0.12, 0.04, 0.35), Color("#6fb4e8"))
	# The tin-can telephone: a can at each window ledge (the string is a level hazard line).
	for p: Vector3 in PHONE:
		var inward := 1.0 if p.x < 33.5 else -1.0
		b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(Vector3.BACK, PI * 0.5), p + Vector3(inward * 0.1, 0, 0)), 0.07, 0.07, 0.16, 8, Color("#c9ced2"))
		b.box_mm(solid, Vector3(minf(p.x, p.x + inward * 0.3), p.y - 0.12, p.z - 0.2), Vector3(maxf(p.x, p.x + inward * 0.3), p.y - 0.08, p.z + 0.2), Mats.TRIM)


func _build_colliders() -> void:
	for c in CURTAINS:
		var spans := [[MEWS_X0, c[1]], [c[2], MEWS_X1]]
		for s: Array in spans:
			add_box("sheet", Vector3((s[0] + s[1]) * 0.5, (LINE_Y + SHEET_BOTTOM) * 0.5, c[0]), Vector3(s[1] - s[0], LINE_Y - SHEET_BOTTOM, 0.35))
	add_cylinder("furniture", BASKET, BASKET_R + 0.1, BASKET_TOP - 0.05)


func _process(delta: float) -> void:
	_t += delta
	for i in _curtains.size():
		_curtains[i].rotation.x = sin(_t * 1.3 + i * 1.7) * 0.06
