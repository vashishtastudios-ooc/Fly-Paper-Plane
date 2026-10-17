extends Prop
## Market Street shop with a striped awning and a painted signboard.
## Origin = ground at the center of the facade, facade faces local +Z.

@export var width := 11.0
@export var depth := 10.0
@export var storeys := 2
@export var ground_height := 3.8
@export var upper_height := 3.2
@export var wall_color := Color("#f2d58f")
## "paint", "plaster" or "brick".
@export var wall_kind := "plaster"
@export var front_color := Color("#2f5560")
@export var awning_a := Color("#c8423b")
@export var awning_b := Color("#f7eedd")
@export var sign_text := "Shop"
@export var sign_text_color := Color("#fbf3dc")
@export var shutter_color := Color("#3f6f8f")
@export var seed_value := 1
## Upstairs is an open flower room with a wide window in the front and back walls, so the plane
## can fly straight through (flight 3). Only for two-storey shops.
@export var open_upstairs := false

## Open upstairs: half width of the windows, their sill and head above the upper floor.
const OPEN_HALF_W := 1.3
const OPEN_SILL := 0.4
const OPEN_HEAD := 2.7
const WALL_T := 0.25


## Far-away shop: a block with its flat roof, shop front, awning strip and upstairs windows.
func _build_far(b: MeshBuilder) -> void:
	var solid := Mats.get_mat("solid")
	var glass := Mats.get_mat("window_lit")
	var hw := width * 0.5
	var rh := roof_height()
	b.box_mm(solid, Vector3(-hw, 0, -depth), Vector3(hw, rh + 0.55, 0), wall_color, 63 - 8)
	b.box_mm(solid, Vector3(-hw + 0.45, 0, 0), Vector3(hw - 0.45, ground_height - 0.2, 0.06), front_color, 16)
	b.box_mm(glass, Vector3(-hw + 0.6, 0.6, 0.06), Vector3(hw - 0.6, ground_height - 1.1, 0.09), Color("#4a6a86"), 16)
	b.box(solid, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, ground_height - 0.3, 0.8)), Vector3(width - 0.6, 0.08, 1.8), awning_a, 4 | 8 | 16)
	for s in storeys - 1:
		var y := ground_height + s * upper_height + 1.5
		for x in [-hw * 0.55, 0.0, hw * 0.55]:
			b.box_mm(glass, Vector3(x - 0.5, y - 0.7, 0.0), Vector3(x + 0.5, y + 0.7, 0.03), Color("#3d5a78"), 16)


func roof_height() -> float:
	return ground_height + (storeys - 1) * upper_height


func _build(b: MeshBuilder) -> void:
	var hw := width * 0.5
	var rh := roof_height()
	var solid := Mats.get_mat("solid")
	var trim := Mats.TRIM
	var wall_mat := Mats.get_mat(wall_kind)
	var wc := wall_color if wall_kind != "brick" else Color.WHITE
	if open_upstairs:
		_build_open_upstairs(b, wall_mat, wc)
	else:
		b.box_mm(wall_mat, Vector3(-hw, 0, -depth), Vector3(hw, rh, 0), wc, 63 - 8 - 4)
	# Parapet, cornice and flat roof.
	b.box_mm(wall_mat, Vector3(-hw, rh, -0.3), Vector3(hw, rh + 0.55, 0), wc, 63 - 8)
	b.box_mm(wall_mat, Vector3(-hw, rh, -depth), Vector3(hw, rh + 0.55, -depth + 0.3), wc, 63 - 8)
	b.box_mm(wall_mat, Vector3(-hw, rh, -depth), Vector3(-hw + 0.3, rh + 0.55, 0), wc, 63 - 8)
	b.box_mm(wall_mat, Vector3(hw - 0.3, rh, -depth), Vector3(hw, rh + 0.55, 0), wc, 63 - 8)
	b.box_mm(Mats.get_mat("gravel"), Vector3(-hw + 0.3, rh - 0.05, -depth + 0.3), Vector3(hw - 0.3, rh + 0.02, -0.3), Color("#b9b2a4"), 4)
	b.box_mm(solid, Vector3(-hw - 0.12, rh + 0.5, -0.4), Vector3(hw + 0.12, rh + 0.66, 0.2), trim)
	b.box_mm(solid, Vector3(-hw - 0.08, rh - 0.3, -0.1), Vector3(hw + 0.08, rh - 0.1, 0.14), trim)
	# Floor band between storeys.
	for s in range(1, storeys):
		var y := ground_height + (s - 1) * upper_height
		b.box_mm(solid, Vector3(-hw - 0.04, y - 0.1, -0.05), Vector3(hw + 0.04, y + 0.1, 0.08), trim)
	# Roof hatch and a little vent so the roof isn't empty.
	b.box_mm(Mats.get_mat("metal"), Vector3(-hw + 1.5, rh, -depth + 2), Vector3(-hw + 2.4, rh + 0.6, -depth + 2.9), Color("#9aa3a8"))

	# Shopfront: pilasters, fascia sign, display window and door.
	var fc := front_color
	b.box_mm(solid, Vector3(-hw, 0, 0), Vector3(-hw + 0.45, ground_height - 0.2, 0.18), fc)
	b.box_mm(solid, Vector3(hw - 0.45, 0, 0), Vector3(hw, ground_height - 0.2, 0.18), fc)
	b.box_mm(solid, Vector3(-hw + 0.2, ground_height - 1.05, 0), Vector3(hw - 0.2, ground_height - 0.2, 0.22), fc)
	b.box_mm(solid, Vector3(-hw + 0.45, 0, 0), Vector3(hw - 0.45, 0.55, 0.12), fc)
	b.box_mm(Mats.get_mat("window_lit"), Vector3(-hw + 0.45, 0.55, -0.02), Vector3(hw - 0.45, ground_height - 1.05, 0.04), Color("#4a6a86"))
	var door_x := hw - 1.6
	b.box_mm(solid, Vector3(door_x - 0.6, 0, -0.01), Vector3(door_x + 0.6, 2.4, 0.09), fc.darkened(0.25))
	b.box_mm(Mats.get_mat("window_lit"), Vector3(door_x - 0.45, 1.0, 0.0), Vector3(door_x + 0.45, 2.2, 0.1), Color("#4a6a86"))
	# Mullions.
	var n := 4
	for i in range(1, n):
		var x := lerpf(-hw + 0.45, door_x - 0.6, float(i) / n)
		b.box_mm(solid, Vector3(x - 0.04, 0.55, 0.0), Vector3(x + 0.04, ground_height - 1.05, 0.08), fc)
	b.box_mm(solid, Vector3(door_x - 0.66, 0.55, 0.0), Vector3(door_x - 0.6, ground_height - 1.05, 0.1), fc)

	# Striped awning.
	var stripes := int(width / 0.55)
	var top_y := ground_height - 1.15
	var low_y := ground_height - 2.05
	var out := 1.7
	for i in stripes:
		var x0 := lerpf(-hw + 0.3, hw - 0.3, float(i) / stripes)
		var x1 := lerpf(-hw + 0.3, hw - 0.3, float(i + 1) / stripes)
		var c := awning_a if i % 2 == 0 else awning_b
		var cl := Mats.get_mat("cloth")
		b.quad(cl, Vector3(x0, low_y, out), Vector3(x1, low_y, out), Vector3(x1, top_y, 0.15), Vector3(x0, top_y, 0.15), c)
		# Scalloped valance.
		b.poly(cl, PackedVector3Array([Vector3(x0, low_y, out), Vector3((x0 + x1) * 0.5, low_y - 0.28, out), Vector3(x1, low_y, out)]), c)
		b.quad(cl, Vector3(x0, low_y - 0.12, out), Vector3(x1, low_y - 0.12, out), Vector3(x1, low_y, out), Vector3(x0, low_y, out), c)
	for sx in [-hw + 0.35, hw - 0.35]:
		b.box_mm(Mats.get_mat("metal"), Vector3(sx - 0.02, low_y, 0.1), Vector3(sx + 0.02, top_y, out), Color("#3a3a3a"))


## Pieces of the upper storey around the two open windows: [min corner, max corner].
func _open_shell() -> Array:
	var hw := width * 0.5
	var g := ground_height
	var rh := roof_height()
	var sill := g + OPEN_SILL
	var head := g + OPEN_HEAD
	var pieces := []
	for z in [[-WALL_T, 0.0], [-depth, -depth + WALL_T]]:
		var z0: float = z[0]
		var z1: float = z[1]
		pieces.append([Vector3(-hw, g, z0), Vector3(-OPEN_HALF_W, rh, z1)])
		pieces.append([Vector3(OPEN_HALF_W, g, z0), Vector3(hw, rh, z1)])
		pieces.append([Vector3(-OPEN_HALF_W, g, z0), Vector3(OPEN_HALF_W, sill, z1)])
		pieces.append([Vector3(-OPEN_HALF_W, head, z0), Vector3(OPEN_HALF_W, rh, z1)])
	pieces.append([Vector3(-hw, g, -depth), Vector3(-hw + WALL_T, rh, 0)])
	pieces.append([Vector3(hw - WALL_T, g, -depth), Vector3(hw, rh, 0)])
	pieces.append([Vector3(-hw, rh - 0.2, -depth), Vector3(hw, rh, 0)])
	return pieces


## Flower shelves along both side walls of the open upstairs room: [min, max].
func _open_shelves() -> Array:
	var hw := width * 0.5
	var g := ground_height
	return [[Vector3(-hw + WALL_T, g, -depth + 1.5), Vector3(-hw + WALL_T + 0.55, g + 1.0, -1.5)],
		[Vector3(hw - WALL_T - 0.55, g, -depth + 1.5), Vector3(hw - WALL_T, g + 1.0, -1.5)]]


func _build_open_upstairs(b: MeshBuilder, wall_mat: Material, wc: Color) -> void:
	var hw := width * 0.5
	var g := ground_height
	var rh := roof_height()
	var solid := Mats.get_mat("solid")
	var wood := Mats.get_mat("wood")
	b.box_mm(wall_mat, Vector3(-hw, 0, -depth), Vector3(hw, g, 0), wc, 63 - 8)
	for p in _open_shell():
		b.box_mm(wall_mat, p[0], p[1], wc)
	# Inside: plank floor, cream walls and ceiling, white window frames.
	var cream := Color("#f6ead2")
	b.box_mm(wood, Vector3(-hw + WALL_T, g, -depth + WALL_T), Vector3(hw - WALL_T, g + 0.03, -WALL_T), Color("#c49a6c"), 4)
	b.box_mm(solid, Vector3(-hw + WALL_T, rh - 0.21, -depth + WALL_T), Vector3(hw - WALL_T, rh - 0.2, -WALL_T), cream, 8)
	b.box_mm(solid, Vector3(-hw + WALL_T, g, -depth + WALL_T), Vector3(-hw + WALL_T + 0.01, rh - 0.2, -WALL_T), cream)
	b.box_mm(solid, Vector3(hw - WALL_T - 0.01, g, -depth + WALL_T), Vector3(hw - WALL_T, rh - 0.2, -WALL_T), cream)
	var sill := g + OPEN_SILL
	var head := g + OPEN_HEAD
	for face in [1.0, -1.0]:
		var z0: float = 0.0 if face > 0 else -depth - 0.06
		var z1: float = 0.06 if face > 0 else -depth
		b.box_mm(solid, Vector3(-OPEN_HALF_W - 0.12, sill - 0.08, z0 - 0.06 if face > 0 else z0), Vector3(OPEN_HALF_W + 0.12, sill, z1 + 0.06 if face < 0 else z1), Mats.TRIM)
		b.box_mm(solid, Vector3(-OPEN_HALF_W - 0.12, head, z0), Vector3(OPEN_HALF_W + 0.12, head + 0.12, z1), Mats.TRIM)
		for sx in [-1.0, 1.0]:
			var x: float = sx * (OPEN_HALF_W + 0.06)
			b.box_mm(solid, Vector3(x - 0.06, sill, z0), Vector3(x + 0.06, head, z1), Mats.TRIM)
	# Shelves of flower pots along the side walls.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 5 + 1
	var flowers := [Color("#e8546a"), Color("#f2c14e"), Color("#ff9ec4"), Color("#fbf8f0"), Color("#c46ad9")]
	for sh in _open_shelves():
		var a: Vector3 = sh[0]
		var c: Vector3 = sh[1]
		b.box_mm(wood, a, c, Color("#8a6a52"))
		var z := a.z + 0.4
		while z < c.z - 0.3:
			var p := Vector3((a.x + c.x) * 0.5, c.y, z)
			b.cylinder(solid, Transform3D(Basis(), p), 0.12, 0.16, 0.24, 8, Color("#c9572e"))
			b.sphere(solid, p + Vector3(0, 0.36, 0), Vector3(0.2, 0.17, 0.2), 4, 7, Color("#6f9e4c"))
			b.sphere(solid, p + Vector3(rng.randf_range(-0.06, 0.06), 0.45, rng.randf_range(-0.06, 0.06)), Vector3(0.1, 0.08, 0.1), 3, 6, flowers[rng.randi() % flowers.size()])
			z += 0.7


func _after_build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 17 + 3
	var hw := width * 0.5
	for s in range(1, storeys):
		var y := ground_height + (s - 1) * upper_height + 1.55
		var count := 3 if width > 9.0 else 2
		for i in count:
			var x := lerpf(-hw + 1.8, hw - 1.8, float(i) / (count - 1))
			# The open flower room has its big window in the middle instead.
			var skip := open_upstairs and absf(x) < OPEN_HALF_W + 1.0
			if not skip:
				inst("window", Transform3D(Basis(), Vector3(x, y, 0.02)))
			if rng.randf() < 0.7 and not skip:
				inst("flowerbox", Transform3D(Basis(), Vector3(x, y - 0.95, 0.14)))
			if rng.randf() < 0.5 and not skip:
				inst("shutter", Transform3D(Basis(), Vector3(x - 0.76, y, 0.06)), shutter_color)
				inst("shutter", Transform3D(Basis(), Vector3(x + 0.76, y, 0.06)), shutter_color)
	# Signboard text.
	var label := Label3D.new()
	label.name = "Sign"
	label.text = sign_text
	label.font = UIKit.display_font()
	label.font_size = 96
	label.outline_size = 0
	label.pixel_size = 0.0055
	label.modulate = sign_text_color
	label.position = Vector3(0, ground_height - 0.62, 0.235)
	label.double_sided = false
	label.shaded = false
	label.width = (width - 1.2) / label.pixel_size
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.visibility_range_end = 140.0
	add_child(label)


func _build_colliders() -> void:
	var rh := roof_height()
	if open_upstairs:
		var hw := width * 0.5
		add_box("wall", Vector3(0, ground_height * 0.5, -depth * 0.5), Vector3(width, ground_height, depth))
		for p in _open_shell():
			add_box("wall", (p[0] + p[1]) * 0.5, p[1] - p[0])
		# Parapet around the roof.
		add_box("wall", Vector3(0, rh + 0.275, -0.15), Vector3(width, 0.55, 0.3))
		add_box("wall", Vector3(0, rh + 0.275, -depth + 0.15), Vector3(width, 0.55, 0.3))
		add_box("wall", Vector3(-hw + 0.15, rh + 0.275, -depth * 0.5), Vector3(0.3, 0.55, depth))
		add_box("wall", Vector3(hw - 0.15, rh + 0.275, -depth * 0.5), Vector3(0.3, 0.55, depth))
		for sh in _open_shelves():
			var a: Vector3 = sh[0]
			var c: Vector3 = sh[1]
			add_box("furniture", (a + c) * 0.5 + Vector3(0, 0.3, 0), c - a + Vector3(0, 0.6, 0))
	else:
		add_box("wall", Vector3(0, (rh + 0.55) * 0.5, -depth * 0.5), Vector3(width, rh + 0.55, depth))
	var top_y := ground_height - 1.15
	var low_y := ground_height - 2.05
	var a := Vector3(0, top_y, 0.15)
	var c := Vector3(0, low_y, 1.7)
	var slope := c - a
	var basis := Basis(Vector3.RIGHT, -atan2(slope.y, slope.z))
	add_box_xf("wall", Transform3D(basis, (a + c) * 0.5), Vector3(width - 0.6, 0.06, slope.length()))
