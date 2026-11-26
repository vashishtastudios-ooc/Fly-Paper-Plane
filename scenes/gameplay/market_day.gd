extends Prop
## Market Day (flight 2, Under the Old Bridge): stalls along both pavements of Market Street, a
## welcome banner strung over the street, a flower cart and a fruit stall sticking out into the
## road (a slalom with the two parked cars), the long striped market tent at the top of the Town
## Square to fly straight through, and the band's stage (the landing spot). World coordinates.

const BANNER_Z := -348.0
const BANNER_BOTTOM := 4.6
const BANNER_TOP := 5.7
## The market tent: entry (north) and exit (south) ends, half width, eave and ridge heights, the
## doorways at both ends and the hanging sign halfway along.
const TENT_Z0 := -479.0
const TENT_Z1 := -511.0
const TENT_HW := 4.2
const TENT_EAVE := 2.7
const TENT_RIDGE := 4.7
const DOOR_HW := 2.5
const DOOR_TOP := 3.5
const SIGN_Z := -495.0
const SIGN_BOTTOM := 3.0
const SIGN_TOP := 3.55
## Inside the tent: the counters' inner edge, and the little canopies above them.
const COUNTER_IN := 2.6
const CANOPY_Y := 2.15
## The band's stage: centre on the ground, half size and deck height (the landing pad sits on it).
const STAGE := Vector3(0.0, 0.0, -521.0)
const STAGE_HALF := 3.0
## Front to back: kept inside the landing pad's reach, so clipping the front edge at deck height
## hops the plane up onto the stage instead of crashing.
const STAGE_DEPTH := 2.3
const STAGE_TOP := 0.35
## Street slalom: the flower cart (west half) and the fruit stall (east half).
const CART := Vector3(-2.1, 0.0, -404.0)
const FRUIT := Vector3(2.4, 0.0, -432.0)
const LAMP_ZS := [-338.0, -358.0, -378.0, -398.0, -418.0, -438.0, -458.0]

const STRIPES := [["#c8423b", "#f7eedd"], ["#2f6f8f", "#f7eedd"], ["#3f7d4f", "#fbf3dc"], ["#e0a13a", "#fbf3dc"], ["#7c4f9e", "#f7eedd"]]
const PRODUCE := ["#e8546a", "#f2a33a", "#f7d046", "#8fc65a", "#c46ad9", "#ff7f50", "#fbf3dc"]
const WOOD := Color("#b98a5a")
const WOOD_DARK := Color("#7a5a40")
const CREAM := Color("#fbf3dc")

var _rng := RandomNumberGenerator.new()


func _draw_distance() -> float:
	return 300.0


## Where the pavement stalls stand: [side, z].
func _stall_spots() -> Array:
	var spots := []
	for side in [-1.0, 1.0]:
		var z := -342.0
		while z > -470.0:
			var clear := true
			for lz in LAMP_ZS:
				if absf(z - lz) < 2.6:
					clear = false
			# Leave the Mill Lane archway (west side) and the banner poles open.
			if side < 0.0 and z > -357.0 and z < -343.0:
				clear = false
			if absf(z - BANNER_Z) < 2.5:
				clear = false
			if clear:
				spots.append([side, z])
			z -= 9.0
	return spots


func _build(b: MeshBuilder) -> void:
	_rng.seed = 2024
	var solid := Mats.get_mat("solid")
	var wood := Mats.get_mat("wood")
	var awning := Mats.get_mat("awning")
	_banner(b, solid, wood)
	var i := 0
	for s in _stall_spots():
		_pavement_stall(b, solid, wood, awning, s[0], s[1], STRIPES[i % STRIPES.size()])
		i += 1
	_flower_cart(b, solid, wood)
	_fruit_stall(b, solid, wood, awning)
	_tent(b, solid, wood, awning)
	_stage(b, solid, wood)


# --- Market Street -------------------------------------------------------------------------------

func _banner(b: MeshBuilder, solid: Material, wood: Material) -> void:
	for sx in [-1.0, 1.0]:
		b.cylinder(wood, Transform3D(Basis(), Vector3(sx * 5.35, 0.0, BANNER_Z)), 0.08, 0.07, BANNER_TOP + 0.25, 8, WOOD_DARK)
		b.sphere(solid, Vector3(sx * 5.35, BANNER_TOP + 0.3, BANNER_Z), Vector3(0.13, 0.13, 0.13), 4, 8, Color("#f6c445"))
	b.box_mm(solid, Vector3(-5.3, BANNER_BOTTOM, BANNER_Z - 0.04), Vector3(5.3, BANNER_TOP, BANNER_Z + 0.04), CREAM)
	for y in [BANNER_BOTTOM, BANNER_TOP - 0.14]:
		b.box_mm(solid, Vector3(-5.3, y, BANNER_Z - 0.06), Vector3(5.3, y + 0.14, BANNER_Z + 0.06), Color("#c8423b"))


func _pavement_stall(b: MeshBuilder, solid: Material, wood: Material, awning: Material, side: float, z: float, stripes: Array) -> void:
	var x0 := side * 7.45
	var x1 := side * 8.75
	var lo := minf(x0, x1)
	var hi := maxf(x0, x1)
	b.box_mm(wood, Vector3(lo, 0.15, z - 1.3), Vector3(hi, 1.0, z + 1.3), WOOD)
	b.box_mm(solid, Vector3(lo - 0.04, 0.95, z - 1.34), Vector3(hi + 0.04, 1.02, z + 1.34), CREAM)
	# Produce in little heaps along the counter.
	for row in 2:
		for k in 5:
			var p := Vector3(side * (7.75 + row * 0.6), 1.12, z - 1.0 + k * 0.5)
			var col := Color(PRODUCE[_rng.randi() % PRODUCE.size()])
			b.sphere(solid, p, Vector3(0.2, 0.12, 0.2), 3, 6, col)
	for zz in [z - 1.25, z + 1.25]:
		for xx in [lo + 0.06, hi - 0.06]:
			b.box_mm(wood, Vector3(xx - 0.05, 0.15, zz - 0.05), Vector3(xx + 0.05, 2.45, zz + 0.05), WOOD_DARK)
	# A striped canopy sloping down towards the street.
	var n := 6
	for k in n:
		var zc := z - 1.4 + (k + 0.5) * (2.8 / n)
		var col := Color(stripes[k % 2])
		var xf := Transform3D(Basis(Vector3.BACK, side * 0.2), Vector3(side * 8.1, 2.4, zc))
		b.box(awning, xf, Vector3(1.9, 0.05, 2.8 / n + 0.01), col)


func _flower_cart(b: MeshBuilder, solid: Material, wood: Material) -> void:
	var c := CART
	b.box_mm(wood, c + Vector3(-1.6, 0.55, -1.1), c + Vector3(1.6, 1.2, 1.1), Color("#3f7d4f"))
	for sz in [-1.0, 1.0]:
		b.cylinder(wood, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c + Vector3(0.0, 0.48, sz * 1.15)), 0.48, 0.48, 0.08, 14, WOOD_DARK)
	b.box_mm(wood, c + Vector3(1.6, 0.9, -0.5), c + Vector3(2.3, 0.98, -0.42), WOOD_DARK)
	b.box_mm(wood, c + Vector3(1.6, 0.9, 0.42), c + Vector3(2.3, 0.98, 0.5), WOOD_DARK)
	# Buckets of flowers.
	for k in 6:
		var p := c + Vector3(-1.1 + (k % 3) * 1.1, 1.2, -0.5 + (k / 3) * 1.0)
		b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(), p), 0.26, 0.3, 0.35, 10, Color("#8fa8b8"))
		for f in 5:
			var fp := p + Vector3(_rng.randf_range(-0.2, 0.2), 0.45 + _rng.randf_range(0.0, 0.25), _rng.randf_range(-0.2, 0.2))
			b.sphere(solid, fp, Vector3(0.13, 0.11, 0.13), 3, 6, Color(Mats.FLOWER_COLORS[_rng.randi() % Mats.FLOWER_COLORS.size()]))
	# A big striped umbrella over it.
	b.cylinder(wood, Transform3D(Basis(), c + Vector3(0, 1.2, 0)), 0.05, 0.05, 1.75, 6, WOOD_DARK)
	b.cylinder(solid, Transform3D(Basis(), c + Vector3(0, 2.45, 0)), 1.7, 0.06, 0.55, 12, Color("#e8546a"))
	b.cylinder(solid, Transform3D(Basis(), c + Vector3(0, 2.42, 0)), 1.72, 1.72, 0.06, 12, CREAM)


func _fruit_stall(b: MeshBuilder, solid: Material, wood: Material, awning: Material) -> void:
	var c := FRUIT
	b.box_mm(wood, c + Vector3(-1.6, 0.15, -1.2), c + Vector3(1.6, 1.0, 1.2), WOOD)
	# Crates of fruit stacked in tiers.
	for k in 6:
		var p := c + Vector3(-1.05 + (k % 3) * 1.05, 1.0, -0.6 + (k / 3) * 1.2)
		b.box_mm(wood, p + Vector3(-0.45, 0.0, -0.5), p + Vector3(0.45, 0.3, 0.5), Color("#c9a06a"))
		var col := Color(PRODUCE[k % PRODUCE.size()])
		for f in 6:
			b.sphere(solid, p + Vector3(-0.27 + (f % 3) * 0.27, 0.38, -0.25 + (f / 3) * 0.5), Vector3(0.15, 0.13, 0.15), 3, 6, col)
	for sx in [-1.5, 1.5]:
		for sz in [-1.1, 1.1]:
			b.box_mm(wood, c + Vector3(sx - 0.05, 0.15, sz - 0.05), c + Vector3(sx + 0.05, 2.4, sz + 0.05), WOOD_DARK)
	for k in 6:
		var xc := -1.8 + (k + 0.5) * 0.6
		b.box_mm(awning, c + Vector3(xc - 0.3, 2.4, -1.4), c + Vector3(xc + 0.3, 2.46, 1.4), Color(STRIPES[3][k % 2]))
	b.box_mm(solid, c + Vector3(-1.8, 2.2, -1.42), c + Vector3(1.8, 2.4, -1.38), Color("#e0a13a"))


# --- The market tent -------------------------------------------------------------------------------

## A flat canvas panel seen from both sides.
func _panel(b: MeshBuilder, mat: Material, pts: PackedVector3Array, col: Color) -> void:
	b.poly(mat, pts, col)
	var rev := pts.duplicate()
	rev.reverse()
	b.poly(mat, rev, col)


func _tent(b: MeshBuilder, solid: Material, wood: Material, awning: Material) -> void:
	var red := Color("#c8423b")
	var cream := Color("#f7eedd")
	var seg := 2.0
	var n := int(round((TENT_Z0 - TENT_Z1) / seg))
	var rise := TENT_RIDGE - TENT_EAVE
	for k in n:
		var za := TENT_Z0 - k * seg
		var zb := za - seg
		var col := red if k % 2 == 0 else cream
		# Side walls.
		for sx in [-1.0, 1.0]:
			b.box_mm(awning, Vector3(sx * TENT_HW - 0.04, 0.0, zb), Vector3(sx * TENT_HW + 0.04, TENT_EAVE, za), col)
			# Scalloped valance along the eaves.
			b.box_mm(solid, Vector3(sx * (TENT_HW + 0.06) - 0.03, TENT_EAVE - 0.35, zb), Vector3(sx * (TENT_HW + 0.06) + 0.03, TENT_EAVE, za), red if col == cream else cream)
		b.gable_roof(awning, Transform3D(Basis(), Vector3(0, TENT_EAVE, (za + zb) * 0.5)), TENT_HW * 2.0, seg, rise, 0.0, 0.08, col)
	# Frame: poles along the walls and at the doorways.
	var z := TENT_Z0
	while z >= TENT_Z1 - 0.01:
		for sx in [-1.0, 1.0]:
			b.box_mm(wood, Vector3(sx * TENT_HW - 0.07, 0.0, z - 0.07), Vector3(sx * TENT_HW + 0.07, TENT_EAVE, z + 0.07), WOOD_DARK)
		z -= 8.0
	# Gable ends with a big doorway.
	for ze in [TENT_Z0, TENT_Z1]:
		var c2 := red
		for sx in [-1.0, 1.0]:
			b.box_mm(awning, Vector3(minf(sx * TENT_HW, sx * DOOR_HW), 0.0, ze - 0.04), Vector3(maxf(sx * TENT_HW, sx * DOOR_HW), TENT_EAVE, ze + 0.04), c2)
			_panel(b, awning, PackedVector3Array([Vector3(sx * TENT_HW, TENT_EAVE, ze), Vector3(sx * DOOR_HW, TENT_EAVE, ze), Vector3(sx * DOOR_HW, DOOR_TOP, ze)]), c2)
			b.box_mm(wood, Vector3(sx * DOOR_HW - 0.08, 0.0, ze - 0.08), Vector3(sx * DOOR_HW + 0.08, DOOR_TOP, ze + 0.08), WOOD_DARK)
		var top_w := TENT_HW * 2.0 * (1.0 - (DOOR_TOP - TENT_EAVE) / rise)
		var top_h := TENT_RIDGE - DOOR_TOP
		_panel(b, awning, PackedVector3Array([Vector3(-top_w * 0.5, DOOR_TOP, ze), Vector3(top_w * 0.5, DOOR_TOP, ze), Vector3(0, DOOR_TOP + top_h, ze)]), cream)
		b.box_mm(wood, Vector3(-DOOR_HW - 0.08, DOOR_TOP - 0.08, ze - 0.08), Vector3(DOOR_HW + 0.08, DOOR_TOP + 0.08, ze + 0.08), WOOD_DARK)
		# Flag on the ridge.
		b.cylinder(wood, Transform3D(Basis(), Vector3(0, TENT_RIDGE, ze)), 0.04, 0.04, 1.1, 6, WOOD_DARK)
		_panel(b, solid, PackedVector3Array([Vector3(0, TENT_RIDGE + 1.05, ze), Vector3(0, TENT_RIDGE + 0.7, ze), Vector3(0.7, TENT_RIDGE + 0.88, ze)]), Color("#f6c445"))
	# Counters and their little canopies along both sides inside.
	var cz := TENT_Z0 - 2.2
	var ci := 0
	while cz - 3.0 > TENT_Z1 + 2.0:
		for sx in [-1.0, 1.0]:
			var lo := minf(sx * COUNTER_IN, sx * (TENT_HW - 0.15))
			var hi := maxf(sx * COUNTER_IN, sx * (TENT_HW - 0.15))
			b.box_mm(wood, Vector3(lo, 0.0, cz - 3.0), Vector3(hi, 1.0, cz), WOOD)
			for f in 8:
				var p := Vector3(sx * (COUNTER_IN + 0.35 + (f % 2) * 0.6), 1.1, cz - 0.4 - (f / 2) * 0.7)
				var cake := (ci + f) % 3 == 0
				if cake:
					b.cylinder(solid, Transform3D(Basis(), p + Vector3(0, -0.08, 0)), 0.2, 0.2, 0.22, 10, Color(["#f7d046", "#e6c3da", "#fbf3dc"][f % 3]))
					b.sphere(solid, p + Vector3(0, 0.17, 0), Vector3(0.05, 0.05, 0.05), 2, 5, Color("#c8423b"))
				else:
					b.sphere(solid, p, Vector3(0.18, 0.12, 0.18), 3, 6, Color(PRODUCE[(ci * 3 + f) % PRODUCE.size()]))
			var stripes: Array = STRIPES[(ci + (1 if sx > 0 else 0)) % STRIPES.size()]
			for k in 5:
				var za2 := cz - k * 0.6
				b.box_mm(awning, Vector3(lo, CANOPY_Y, za2 - 0.6), Vector3(hi, CANOPY_Y + 0.05, za2), Color(stripes[k % 2]))
		ci += 1
		cz -= 3.6
	# The hanging sign halfway along, on ropes from the ridge.
	b.box_mm(solid, Vector3(-TENT_HW + 0.2, SIGN_BOTTOM, SIGN_Z - 0.05), Vector3(TENT_HW - 0.2, SIGN_TOP, SIGN_Z + 0.05), Color("#f2d58f"))
	b.box_mm(solid, Vector3(-TENT_HW + 0.15, SIGN_BOTTOM - 0.05, SIGN_Z - 0.07), Vector3(TENT_HW - 0.15, SIGN_BOTTOM + 0.05, SIGN_Z + 0.07), WOOD_DARK)
	for sx in [-2.5, 2.5]:
		b.box_mm(solid, Vector3(sx - 0.02, SIGN_TOP, SIGN_Z - 0.02), Vector3(sx + 0.02, TENT_RIDGE - 0.6, SIGN_Z + 0.02), WOOD_DARK)


func _stage(b: MeshBuilder, solid: Material, wood: Material) -> void:
	var c := STAGE
	var h := STAGE_HALF
	var d := STAGE_DEPTH
	b.box_mm(wood, c + Vector3(-h, 0.0, -d), c + Vector3(h, STAGE_TOP, d), Color("#a8754a"))
	for k in 6:
		var x := -h + 0.5 + k * 1.0
		b.box_mm(solid, c + Vector3(x - 0.02, STAGE_TOP, -d), c + Vector3(x + 0.02, STAGE_TOP + 0.005, d), Color("#8a5f3a"))
	# Bunting skirt along the front, steps at the back.
	for k in 10:
		var x := -h + 0.3 + k * 0.6
		var col := Color(STRIPES[k % STRIPES.size()][0])
		_panel(b, solid, PackedVector3Array([c + Vector3(x - 0.25, STAGE_TOP - 0.05, d + 0.03), c + Vector3(x + 0.25, STAGE_TOP - 0.05, d + 0.03), c + Vector3(x, STAGE_TOP - 0.3, d + 0.03)]), col)
	for k in 2:
		b.box_mm(wood, c + Vector3(-1.0, 0.0, -d - 0.4 * (k + 1)), c + Vector3(1.0, STAGE_TOP * (1.0 - (k + 1) / 3.0), -d - 0.4 * k), Color("#8a5f3a"))
	# Corner posts with strings of flags above the back.
	for sx in [-1.0, 1.0]:
		b.cylinder(wood, Transform3D(Basis(), c + Vector3(sx * (h - 0.1), STAGE_TOP, -d + 0.1)), 0.06, 0.06, 2.9, 6, WOOD_DARK)
	for k in 12:
		var x := -h + 0.35 + k * 0.5
		var sag := 0.35 * (1.0 - pow((x / h), 2.0))
		var y := STAGE_TOP + 3.4 - sag
		_panel(b, solid, PackedVector3Array([c + Vector3(x - 0.2, y, -d + 0.1), c + Vector3(x + 0.2, y, -d + 0.1), c + Vector3(x, y - 0.35, -d + 0.1)]), Color(STRIPES[k % STRIPES.size()][0]))
	# A drum and a music stand in the back corners (clear of the landing spot).
	b.cylinder(solid, Transform3D(Basis(), c + Vector3(2.4, STAGE_TOP, -2.0)), 0.38, 0.38, 0.45, 14, Color("#c8423b"))
	b.cylinder(solid, Transform3D(Basis(), c + Vector3(2.4, STAGE_TOP + 0.45, -2.0)), 0.39, 0.39, 0.03, 14, CREAM)
	b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(), c + Vector3(-2.4, STAGE_TOP, -2.0)), 0.02, 0.02, 1.1, 5, Color("#3a3a3a"))
	b.box_mm(Mats.get_mat("metal"), c + Vector3(-2.7, STAGE_TOP + 1.05, -2.03), c + Vector3(-2.1, STAGE_TOP + 1.4, -1.97), Color("#3a3a3a"))


# --- Colliders -------------------------------------------------------------------------------------

func _build_colliders() -> void:
	# Banner and its poles.
	add_box("banner", Vector3(0, (BANNER_BOTTOM + BANNER_TOP) * 0.5, BANNER_Z), Vector3(10.6, BANNER_TOP - BANNER_BOTTOM, 0.14))
	for sx in [-1.0, 1.0]:
		add_cylinder("lamp", Vector3(sx * 5.35, 0, BANNER_Z), 0.1, BANNER_TOP + 0.4)
	for s in _stall_spots():
		add_box("stall", Vector3(s[0] * 8.1, 1.3, s[1]), Vector3(1.9, 2.6, 2.9))
	add_box("stall", CART + Vector3(0, 0.95, 0), Vector3(3.3, 1.9, 2.4))
	add_cylinder("stall", CART + Vector3(0, 2.4, 0), 1.72, 0.6)
	add_cylinder("stall", CART + Vector3(0, 1.2, 0), 0.06, 1.3)
	add_box("stall", FRUIT + Vector3(0, 1.25, 0), Vector3(3.6, 2.5, 2.8))
	# Tent walls, roof, gable ends around the doorways, counters, canopies and the sign.
	var mid := (TENT_Z0 + TENT_Z1) * 0.5
	var length := TENT_Z0 - TENT_Z1
	for sx in [-1.0, 1.0]:
		add_box("tent", Vector3(sx * TENT_HW, TENT_EAVE * 0.5, mid), Vector3(0.2, TENT_EAVE, length))
		var ang := atan2(TENT_RIDGE - TENT_EAVE, TENT_HW)
		var slope := Vector3(sx * TENT_HW * 0.5, (TENT_EAVE + TENT_RIDGE) * 0.5, mid)
		add_box_xf("tent", Transform3D(Basis(Vector3.FORWARD, sx * ang), slope), Vector3(TENT_HW / cos(ang), 0.2, length))
		for ze in [TENT_Z0, TENT_Z1]:
			add_box("tent", Vector3(sx * (TENT_HW + DOOR_HW) * 0.5, TENT_EAVE * 0.5, ze), Vector3(TENT_HW - DOOR_HW, TENT_EAVE, 0.2))
		add_box("stall", Vector3(sx * (COUNTER_IN + TENT_HW) * 0.5, 0.5, mid), Vector3(TENT_HW - COUNTER_IN, 1.0, length - 4.0))
		add_box("stall", Vector3(sx * (COUNTER_IN + TENT_HW) * 0.5, CANOPY_Y + 0.03, mid), Vector3(TENT_HW - COUNTER_IN, 0.12, length - 4.0))
	for ze in [TENT_Z0, TENT_Z1]:
		add_box("tent", Vector3(0, (DOOR_TOP + TENT_RIDGE) * 0.5, ze), Vector3(DOOR_HW * 2.0 + 0.2, TENT_RIDGE - DOOR_TOP, 0.2))
	add_box("banner", Vector3(0, (SIGN_BOTTOM + SIGN_TOP) * 0.5, SIGN_Z), Vector3(TENT_HW * 2.0, SIGN_TOP - SIGN_BOTTOM, 0.12))
	# The stage (landing on its pad is handled by the landing pad's own collider) and its props.
	add_box("wall", STAGE + Vector3(0, STAGE_TOP * 0.5, 0), Vector3(STAGE_HALF * 2.0, STAGE_TOP, STAGE_DEPTH * 2.0))
	add_cylinder("furniture", STAGE + Vector3(2.4, STAGE_TOP, -2.0), 0.4, 0.5)
	add_cylinder("furniture", STAGE + Vector3(-2.4, STAGE_TOP, -2.0), 0.3, 1.4)


func _after_build() -> void:
	_label("MARKET DAY!", Vector3(0, (BANNER_BOTTOM + BANNER_TOP) * 0.5, BANNER_Z), 100, Color("#c8423b"))
	_label("Covered Market", Vector3(0, DOOR_TOP + 0.45, TENT_Z0), 56, Color("#2d4f7c"))
	_label("Cakes & Bakes", Vector3(0, (SIGN_BOTTOM + SIGN_TOP) * 0.5, SIGN_Z), 64, Color("#7a2f3b"))
	# Warm light inside the tent (not on phones: the glowing lanterns are enough there).
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.3, 1.05, 0.7)
	var lb := MeshBuilder.new()
	var z := TENT_Z0 - 3.0
	while z > TENT_Z1 + 2.0:
		if absf(z - SIGN_Z) > 1.5:
			lb.sphere(glow, Vector3(0, TENT_RIDGE - 0.75, z), Vector3(0.2, 0.24, 0.2), 4, 8, Color("#ffcf7a"))
		z -= 3.0
	var lanterns := lb.build_instance("Lanterns", false)
	add_child(lanterns)
	if not Settings.is_mobile:
		for lz in [TENT_Z0 - 8.0, TENT_Z1 + 8.0]:
			var l := OmniLight3D.new()
			l.position = Vector3(0, TENT_RIDGE - 1.0, lz)
			l.light_color = Color("#ffd9a1")
			l.light_energy = 1.4
			l.omni_range = 9.0
			add_child(l)


## Painted text on both faces of a sign or banner.
func _label(text: String, at: Vector3, size: int, col: Color) -> void:
	for face in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = text
		l.font = UIKit.display_font()
		l.font_size = size
		l.pixel_size = 0.008
		l.modulate = col
		l.outline_size = 0
		l.double_sided = false
		l.shaded = true
		l.position = at + Vector3(0, 0, face * 0.07)
		l.rotation.y = 0.0 if face > 0.0 else PI
		add_child(l)
