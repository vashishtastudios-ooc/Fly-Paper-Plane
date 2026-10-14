extends Prop
## A house on Rowan Row with its windows and doors thrown open so the paper plane can fly
## straight through the furnished rooms. Origin = ground at the center of the footprint.
## The flight enters through the north wall (local +Z) and leaves through the south wall (-Z).
## `layout` picks the floor plan:
## - "attic": the launch bedroom under the roof, with an open gable window
## - "bedroom": upstairs bedroom and study joined by a doorway (and a little hatch)
## - "stairwell": upstairs landing over a double-height stairwell, french doors below
## - "cottage": one storey, kitchen and sitting room joined by an archway (the landing rug)
## - "greenhouse": a glass greenhouse with open doors at both ends

const T := 0.25
const GF := 0.4
const GC := 3.4
const UF := 3.6
const UC := 6.6
const AF := 6.8
const COTTAGE_CEIL := 3.6
const COTTAGE_EAVE := 3.8
const GH_WALL := 2.3

@export var layout := "bedroom"
@export var width := 11.0
@export var depth := 10.0
@export var wall_color := Color("#a9c9db")
@export var roof_color := Color("#b8644a")
@export var shutter_color := Color("#3f6f8f")
@export var door_color := Color("#c8423b")
@export var seed_value := 1

var hw := 5.5
var hd := 5.0
var _rng := RandomNumberGenerator.new()
var _built := false
## Interior lights: [position, color, energy, range].
var _lights: Array = []


func _build(b: MeshBuilder) -> void:
	_layout(b)


func _build_colliders() -> void:
	# A swapped-in "Model" skips _build; run the layout anyway for its colliders.
	if not _built:
		_layout(MeshBuilder.new())


func _after_build() -> void:
	for l in _lights:
		var o := OmniLight3D.new()
		o.position = l[0]
		o.light_color = l[1]
		o.light_energy = l[2]
		o.omni_range = l[3]
		o.shadow_enabled = false
		add_child(o)


func _layout(b: MeshBuilder) -> void:
	_built = true
	hw = width * 0.5
	hd = depth * 0.5
	_rng.seed = seed_value
	match layout:
		"attic": _attic(b)
		"stairwell": _stairwell(b)
		"cottage": _cottage(b)
		"greenhouse": _greenhouse(b)
		_: _bedroom(b)


# --- Floor plans ------------------------------------------------------------------------------

## Launch bedroom in the roof of a two-storey house. The kid stands near the north gable and
## throws out through the open window in the south gable.
func _attic(b: MeshBuilder) -> void:
	var rise := 4.4
	var in_col := Color("#f6ead2")
	var solid := _m("solid")
	var wood := _m("wood")
	_body_shell(b, AF)
	_trims(b, AF)
	for y in [2.0, 5.1]:
		for x in [-2.8, 2.8]:
			_win(Vector3.BACK, x, y)
			_win(Vector3.FORWARD, x, y)
		for s in [-1.0, 1.0]:
			_win(Vector3(s, 0, 0), -1.6, y)
			_win(Vector3(s, 0, 0), 1.6, y)
	_front_door(b, Vector3.BACK, 0.0)
	b.box_mm(wood, Vector3(-hw + 0.1, AF - 0.04, -hd + 0.1), Vector3(hw - 0.1, AF, hd - 0.1), Color("#c9a27e"), 4)
	_attic_roof(b, rise)
	var apex := AF + rise
	_gable_piece(b, [Vector2(-hw, AF), Vector2(hw, AF), Vector2(0, apex)], hd, 1.0, in_col)
	# South gable around the open window.
	var hx0 := -1.3
	var hx1 := 1.3
	var hy0 := 7.0
	var hy1 := 9.2
	var r0 := _gable_x(hy0, rise)
	var r1 := _gable_x(hy1, rise)
	_gable_piece(b, [Vector2(-hw, AF), Vector2(hw, AF), Vector2(r0, hy0), Vector2(-r0, hy0)], -hd, -1.0, in_col)
	_gable_piece(b, [Vector2(-r0, hy0), Vector2(hx0, hy0), Vector2(hx0, hy1), Vector2(-r1, hy1)], -hd, -1.0, in_col)
	_gable_piece(b, [Vector2(hx1, hy0), Vector2(r0, hy0), Vector2(r1, hy1), Vector2(hx1, hy1)], -hd, -1.0, in_col)
	_gable_piece(b, [Vector2(-r1, hy1), Vector2(r1, hy1), Vector2(0, apex)], -hd, -1.0, in_col)
	_opening(b, _hole(hx0, hx1, hy0, hy1), -hd, -1.0, T, true)
	# A round window in the north gable, above the kid.
	b.cylinder(_m("window_lit"), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, AF + rise * 0.55, hd + 0.01)), 0.38, 0.38, 0.05, 12, Color("#3d5a78"))
	b.cylinder(solid, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, AF + rise * 0.55, hd)), 0.46, 0.46, 0.04, 12, Mats.TRIM)

	# Furniture (kept low under the sloping roof).
	_rug(b, Vector2(-1.5, -2.8), Vector2(1.5, 2.6), AF, Color("#d9675a"), Color("#f2c14e"))
	_bed(b, Vector3(-4.4, AF, -0.8), Vector3(-2.5, AF, 1.7), Color("#6fb4e8"), 0.3)
	_furn(b, "solid", Vector3(2.8, AF, 1.4), Vector3(3.9, AF + 0.5, 2.2), Color("#c8423b"))
	b.box_mm(solid, Vector3(2.75, AF + 0.5, 1.35), Vector3(3.95, AF + 0.58, 2.25), Color("#e0a13a"))
	_bookshelf(b, Vector3(3.2, AF, -2.8), Vector3(3.9, AF + 0.95, -1.0), Vector3.LEFT)
	_furn(b, "wood", Vector3(-3.9, AF, -3.7), Vector3(-2.7, AF + 0.72, -2.7), Color("#b07a4f"))
	_desk_lamp(b, Vector3(-3.1, AF + 0.72, -3.4))
	b.box_mm(solid, Vector3(-3.7, AF + 0.72, -3.5), Vector3(-3.35, AF + 0.75, -3.0), Color("#fbf8f0"))
	# Paper planes on the floor and model planes hanging from the ridge.
	for p in [Vector3(1.9, AF + 0.01, 0.4), Vector3(-1.9, AF + 0.01, -1.6), Vector3(0.9, AF + 0.01, -3.3)]:
		_paper_plane(b, p, _rng.randf() * TAU, 0.0)
	for hp in [Vector3(-1.2, 9.9, -1.0), Vector3(1.4, 10.1, 0.9), Vector3(1.8, 9.7, -2.6)]:
		var top := AF + rise * (1.0 - absf(hp.x) / hw)
		b.tube(_m("rope"), PackedVector3Array([hp, Vector3(hp.x, top, hp.z)]), 0.006, 3, Color("#e8e2d2"))
		_paper_plane(b, hp, _rng.randf() * TAU, 0.25)
	# Fairy lights along both slopes.
	for s in [-1.0, 1.0]:
		var x: float = s * 3.3
		var y := AF + rise * (1.0 - 3.3 / hw) - 0.12
		var pts := PackedVector3Array()
		var z := -hd + 0.5
		var k := 0
		while z <= hd - 0.5:
			var p := Vector3(x, y - 0.1 * absf(sin(z * 1.6)), z)
			pts.append(p)
			b.sphere(_m("glow"), p + Vector3(0, -0.04, 0), Vector3(0.035, 0.045, 0.035), 3, 5, [Color("#ffd27a"), Color("#ff9ec4"), Color("#9fe3ff")][k % 3])
			z += 0.45
			k += 1
		b.tube(_m("rope"), pts, 0.006, 3, Color("#4a4640"))
	# Posters on the inside of the north gable.
	_picture(b, Vector3(-1.9, 7.8, hd - T - 0.01), Vector3.FORWARD, Vector2(0.8, 0.6), Color("#a9c9db"))
	_picture(b, Vector3(1.9, 7.8, hd - T - 0.01), Vector3.FORWARD, Vector2(0.6, 0.8), Color("#f2d58f"))
	_lights.append([Vector3(0, 9.6, 0.5), Color("#ffe2b8"), 1.0, 7.5])


## Upstairs bedroom (north) and study (south) joined by a doorway, with a small hatch to the left
## of the door (the bonus ring). The ground floor is closed.
func _bedroom(b: MeshBuilder) -> void:
	var bed_col := Color("#d5e6f0")
	var study_col := Color("#f3e3bf")
	var solid := _m("solid")
	_body_shell(b, UF)
	_trims(b, AF)
	for x in [-2.8, 2.8]:
		_win(Vector3.BACK, x, 2.0)
		_win(Vector3.FORWARD, x, 2.0)
	_win(Vector3.FORWARD, 0.0, 2.0)
	_front_door(b, Vector3.BACK, 0.0)
	for s in [-1.0, 1.0]:
		for z in [-2.6, 2.6]:
			_win(Vector3(s, 0, 0), z, 2.0)
			_win(Vector3(s, 0, 0), z, 5.1)
	_floor(b, UF, -hd + T, hd - T, Color("#c9a27e"))
	var north := [_hole(-1.2, 1.2, 4.1, 6.3), _hole(2.6, 4.4, 4.4, 6.1, "glass"), _hole(-3.9, -1.7, 4.3, 6.1)]
	_cross_wall(b, hd, 1.0, -hw, hw, UF, AF, north, wall_color, bed_col)
	var south := [_hole(-0.7, 1.7, 4.1, 6.3), _hole(-3.9, -1.7, 4.3, 6.1), _hole(3.0, 4.6, 4.4, 6.1, "glass")]
	_cross_wall(b, -hd, -1.0, -hw, hw, UF, AF, south, wall_color, study_col)
	_side_walls(b, UF, AF)
	_side_plaster(b, UF, UC, 0.1, hd - T, bed_col)
	_side_plaster(b, UF, UC, -hd + T, -0.1, study_col)
	var inner := [_hole(-0.9, 0.9, UF, 5.9, "door"), _hole(-3.3, -2.0, 4.5, 5.7, "hatch")]
	_cross_wall(b, 0.1, 1.0, -hw + T, hw - T, UF, UC, inner, bed_col, study_col, false, 0.2)
	_ceiling(b, UC, AF, -hd + T, hd - T)
	_roof(b, AF, 4.0)

	# Bedroom: bunk bed, desk, toy box, radiator under the open window, lamp and a mobile.
	_rug(b, Vector2(-1.8, 1.0), Vector2(1.8, 3.9), UF, Color("#6fb4e8"), Color("#fbf8f0"))
	_bunk_bed(b, Vector3(-5.25, UF, 1.2), Vector3(-4.15, UF, 3.6))
	_furn(b, "wood", Vector3(4.2, UF, 1.2), Vector3(5.25, UF + 0.75, 3.0), Color("#d6b48c"))
	_chair(b, Vector3(3.75, UF, 2.1), Color("#e8873a"))
	_desk_lamp(b, Vector3(4.8, UF + 0.75, 2.6))
	_furn(b, "solid", Vector3(3.5, UF, 3.8), Vector3(4.5, UF + 0.5, 4.6), Color("#3f7d4f"))
	_radiator(b, 0.0, hd - T - 0.08, UF, 1.0)
	_pendant(b, Vector3(2.4, 5.9, 2.4), UC, Color("#f2c14e"))
	for k in 5:
		var a := TAU * k / 5.0
		var mp := Vector3(-1.9 + cos(a) * 0.35, 6.05 - 0.12 * (k % 2), 3.0 + sin(a) * 0.35)
		b.tube(_m("rope"), PackedVector3Array([mp, Vector3(mp.x, UC, mp.z)]), 0.005, 3, Color("#e8e2d2"))
		b.sphere(solid, mp, Vector3(0.09, 0.09, 0.09), 3, 6, [Color("#e8546a"), Color("#f2c14e"), Color("#6fb4e8"), Color("#7fd08c"), Color("#c38be8")][k])
	_picture(b, Vector3(-hw + T + 0.01, 5.2, 4.2), Vector3.RIGHT, Vector2(0.7, 0.9), Color("#f2d58f"))
	_picture(b, Vector3(hw - T - 0.01, 5.3, 3.9), Vector3.LEFT, Vector2(0.9, 0.6), Color("#e9b7a1"))
	# Study: bookshelf, armchair, desk with a globe, lamp and a plant.
	_rug(b, Vector2(-1.6, -4.0), Vector2(1.6, -1.0), UF, Color("#7c4f9e"), Color("#f2c14e"))
	_bookshelf(b, Vector3(-5.25, UF, -4.6), Vector3(-4.85, UF + 2.5, -0.5), Vector3.RIGHT)
	_armchair(b, Vector3(-3.6, UF, -3.7), Vector3.BACK, Color("#3f7d4f"))
	_furn(b, "wood", Vector3(4.0, UF, -4.2), Vector3(5.25, UF + 0.76, -2.2), Color("#a87a4f"))
	_chair(b, Vector3(3.55, UF, -3.2), Color("#2f6f8f"))
	_globe(b, Vector3(4.7, UF + 0.76, -3.8))
	_pendant(b, Vector3(-1.9, 5.9, -2.6), UC, Color("#e8546a"))
	_plant(b, Vector3(2.3, UF, -4.3), 1.0)
	_picture(b, Vector3(hw - T - 0.01, 5.3, -1.2), Vector3.LEFT, Vector2(1.0, 0.7), Color("#b9d6a8"))
	_lights.append([Vector3(0, 6.1, 2.5), Color("#ffe2b8"), 0.8, 6.0])
	_lights.append([Vector3(0, 6.1, -2.5), Color("#ffe2b8"), 0.8, 6.0])


## Upstairs landing (north part) that ends at a banister above a double-height stairwell.
## The flight dives down the stairwell and leaves through the french doors below.
func _stairwell(b: MeshBuilder) -> void:
	var hall_col := Color("#f5ecdc")
	var living_col := Color("#e3eedb")
	var solid := _m("solid")
	var wood := _m("wood")
	var slab_z := 0.5
	_plinth(b)
	_trims(b, AF)
	_front_door(b, Vector3.BACK, 0.0)
	_floor(b, GF, -hd + T, hd - T, Color("#b98f68"))
	for s in [-1.0, 1.0]:
		for z in [-4.5, 0.0, 4.5]:
			_win(Vector3(s, 0, 0), z, 2.0)
			_win(Vector3(s, 0, 0), z, 5.1)
	var north := [_hole(-1.2, 1.2, 4.1, 6.3), _hole(-3.9, -1.7, 4.3, 6.1), _hole(2.6, 4.4, 4.4, 6.1, "glass"),
		_hole(-4.2, -2.2, 1.2, 2.8, "glass"), _hole(2.2, 4.2, 1.2, 2.8, "glass")]
	_cross_wall(b, hd, 1.0, -hw, hw, 0.0, AF, north, wall_color, hall_col)
	var south := [_hole(-1.4, 1.4, GF, 2.8, "french"), _hole(-4.4, -2.6, 1.2, 2.8, "glass"), _hole(2.6, 4.4, 1.2, 2.8, "glass"),
		_hole(-4.4, -2.6, 4.4, 6.1, "glass"), _hole(2.6, 4.4, 4.4, 6.1, "glass")]
	_cross_wall(b, -hd, -1.0, -hw, hw, 0.0, AF, south, wall_color, living_col)
	_side_walls(b, 0.0, AF)
	_side_plaster(b, GF, UC, -hd + T, hd - T, living_col)
	# Landing slab over the north part, ceiling over everything.
	b.box_mm(_m("plaster"), Vector3(-hw + T, GC, slab_z), Vector3(hw - T, UF - 0.04, hd - T), Color("#fbf7ee"))
	b.box_mm(wood, Vector3(-hw + T, UF - 0.04, slab_z), Vector3(hw - T, UF, hd - T), Color("#c9a27e"))
	add_box("wall", Vector3(0, (GC + UF) * 0.5, (slab_z + hd) * 0.5), Vector3(width, UF - GC, hd - slab_z))
	_ceiling(b, UC, AF, -hd + T, hd - T)
	_roof(b, AF, 4.0)

	# Stairs along the east wall, rising north to the landing.
	var steps := 13
	var run := 0.53
	var rise := (UF - GF) / steps
	var z0 := slab_z - steps * run
	for k in steps:
		var za := z0 + k * run
		var top := GF + (k + 1) * rise
		b.box_mm(wood, Vector3(3.6, GF, za), Vector3(hw - T, top, za + run), Color("#a87a4f"))
		b.box_mm(solid, Vector3(3.6, top - 0.02, za), Vector3(hw - T, top + 0.01, za + run * 0.4), Color("#d9675a"))
		add_box("furniture", Vector3((3.6 + hw - T) * 0.5, (GF + top) * 0.5, za + run * 0.5), Vector3(hw - T - 3.6, top - GF, run))
	var rail := PackedVector3Array([Vector3(3.62, GF + 0.95, z0), Vector3(3.62, UF + 0.95, slab_z)])
	b.tube(wood, rail, 0.035, 5, Color("#7a5236"))
	for k in steps:
		var zz := z0 + (k + 0.5) * run
		var ty := GF + (k + 1) * rise
		b.box_mm(solid, Vector3(3.6, ty, zz - 0.02), Vector3(3.65, ty + 0.95 - rise * 0.5, zz + 0.02), Mats.TRIM)
	# Banister along the edge of the landing.
	var x := -hw + T
	while x <= 3.6:
		b.box_mm(solid, Vector3(x - 0.025, UF, slab_z - 0.02), Vector3(x + 0.025, UF + 0.72, slab_z + 0.03), Mats.TRIM)
		x += 0.22
	b.box_mm(wood, Vector3(-hw + T, UF + 0.7, slab_z - 0.05), Vector3(3.65, UF + 0.78, slab_z + 0.06), Color("#7a5236"))
	add_box("banister", Vector3((-hw + T + 3.65) * 0.5, UF + 0.4, slab_z), Vector3(3.65 + hw - T, 0.8, 0.2))

	# Landing: runner, bookshelf, grandfather clock, plant and family photos.
	_rug(b, Vector2(-0.8, 1.0), Vector2(0.8, 6.3), UF, Color("#2f6f8f"), Color("#f2c14e"))
	_bookshelf(b, Vector3(-hw + T, UF, 1.4), Vector3(-hw + T + 0.4, UF + 2.2, 5.6), Vector3.RIGHT)
	_grandfather_clock(b, Vector3(4.85, UF, 3.3))
	_plant(b, Vector3(3.4, UF, 6.0), 1.1)
	for k in 3:
		_picture(b, Vector3(hw - T - 0.01, 5.1 + 0.2 * (k % 2), 1.6 + k * 0.7), Vector3.LEFT, Vector2(0.45, 0.55), [Color("#e9b7a1"), Color("#a9c9db"), Color("#f2d58f")][k])
	# Stairwell: a chandelier off to one side.
	_chandelier(b, Vector3(2.3, 5.3, -3.4), UC)
	# Living room under the stairwell: sofa, coffee table, armchair, plants by the french doors.
	_rug(b, Vector2(-4.2, -5.6), Vector2(-0.9, -1.4), GF, Color("#c8423b"), Color("#fbf3dc"))
	_sofa(b, Vector3(-hw + T, GF, -5.2), Vector3(-hw + T + 0.9, GF, -1.6), Vector3.RIGHT, Color("#6b8fb5"))
	_furn(b, "wood", Vector3(-3.3, GF, -4.1), Vector3(-2.1, GF + 0.42, -2.7), Color("#a87a4f"))
	b.cylinder(solid, Transform3D(Basis(), Vector3(-2.6, GF + 0.42, -3.2)), 0.05, 0.05, 0.1, 8, Color("#fbf8f0"))
	_armchair(b, Vector3(-2.6, GF, -0.4), Vector3.FORWARD, Color("#e0a13a"))
	for s in [-1.0, 1.0]:
		_plant(b, Vector3(s * 2.1, GF, -hd + T + 0.45), 1.4)
	_floor_lamp(b, Vector3(-4.7, GF, -0.9))
	# Dining area under the landing.
	_furn(b, "wood", Vector3(-1.5, GF, 2.4), Vector3(1.5, GF + 0.76, 4.6), Color("#a87a4f"))
	for cx in [-0.8, 0.8]:
		for cz in [2.0, 5.0]:
			_chair(b, Vector3(cx, GF, cz), Color("#3f7d4f"))
	_pendant(b, Vector3(0, 2.75, 3.5), GC, Color("#f2c14e"), false)
	_picture(b, Vector3(-hw + T + 0.01, 1.9, -3.4), Vector3.RIGHT, Vector2(1.3, 0.8), Color("#a9c9db"))
	_lights.append([Vector3(0, 5.8, -3.0), Color("#ffe2b8"), 1.0, 8.0])
	_lights.append([Vector3(0, 2.9, 3.6), Color("#ffe2b8"), 0.7, 5.5])
	_lights.append([Vector3(0, 6.1, 3.6), Color("#ffe2b8"), 0.7, 5.5])


## One-storey cottage: kitchen (north) through an archway into the sitting room, where the
## landing rug lies in front of the fire.
func _cottage(b: MeshBuilder) -> void:
	var kit_col := Color("#f8f0dc")
	var sit_col := Color("#f2dcc8")
	var solid := _m("solid")
	var wood := _m("wood")
	var wall_z := 0.6
	_plinth(b)
	_trims(b, COTTAGE_EAVE)
	_floor(b, GF, -hd + T, hd - T, Color("#b98f68"))
	for s in [-1.0, 1.0]:
		for z in [-3.0, 3.0]:
			_win(Vector3(s, 0, 0), z, 2.1)
	var north := [_hole(-1.2, 1.2, GF, 2.7, "door"), _hole(2.4, 4.4, 1.4, 3.0), _hole(-4.4, -2.6, 1.4, 3.0, "glass")]
	_cross_wall(b, hd, 1.0, -hw, hw, 0.0, COTTAGE_EAVE, north, wall_color, kit_col)
	var south := [_hole(-4.4, -2.8, 1.4, 3.0, "glass"), _hole(2.8, 4.4, 1.4, 3.0, "glass")]
	_cross_wall(b, -hd, -1.0, -hw, hw, 0.0, COTTAGE_EAVE, south, wall_color, sit_col)
	_side_walls(b, 0.0, COTTAGE_EAVE)
	_side_plaster(b, GF, COTTAGE_CEIL, wall_z, hd - T, kit_col)
	_side_plaster(b, GF, COTTAGE_CEIL, -hd + T, wall_z - 0.2, sit_col)
	_cross_wall(b, wall_z, 1.0, -hw + T, hw - T, GF, COTTAGE_CEIL, [_hole(-1.6, 1.6, GF, 2.8, "arch")], kit_col, sit_col, false, 0.2)
	_ceiling(b, COTTAGE_CEIL, COTTAGE_EAVE, -hd + T, hd - T)
	_roof(b, COTTAGE_EAVE, 4.2)
	# Chimney on the south gable, above the fireplace.
	var ridge := COTTAGE_EAVE + 4.2
	b.box_mm(_m("brick"), Vector3(-0.5, COTTAGE_EAVE, -hd + 0.2), Vector3(0.5, ridge + 1.0, -hd + 1.1), Color.WHITE)
	b.box_mm(_m("stone"), Vector3(-0.6, ridge + 1.0, -hd + 0.1), Vector3(0.6, ridge + 1.14, -hd + 1.2), Color("#cfc6b6"))
	add_box("wall", Vector3(0, (COTTAGE_EAVE + ridge + 1.14) * 0.5, -hd + 0.65), Vector3(1.2, ridge + 1.14 - COTTAGE_EAVE, 1.1))

	# Kitchen: counters, fridge, stove, table and chairs, a pan rack and the cat's bowl.
	var cab := Color("#7fa58f")
	var top := Color("#efe7d6")
	_furn(b, "wood", Vector3(-hw + T, GF, 0.9), Vector3(-4.6, GF + 0.88, 4.3), cab)
	b.box_mm(solid, Vector3(-hw + T, GF + 0.88, 0.85), Vector3(-4.55, GF + 0.94, 4.35), top)
	b.box_mm(wood, Vector3(-hw + T, 2.3, 0.9), Vector3(-4.9, 3.1, 4.3), cab)
	_furn(b, "solid", Vector3(-hw + T, GF, 4.5), Vector3(-4.5, GF + 1.9, 5.5), Color("#f4f0e6"))
	b.box_mm(_m("metal"), Vector3(-4.52, GF + 1.0, 4.6), Vector3(-4.48, GF + 1.5, 4.66), Color("#9aa3a8"))
	_furn(b, "wood", Vector3(4.6, GF, 0.9), Vector3(hw - T, GF + 0.88, 5.5), cab)
	b.box_mm(solid, Vector3(4.55, GF + 0.88, 0.85), Vector3(hw - T, GF + 0.94, 5.55), top)
	b.box_mm(_m("metal"), Vector3(4.65, GF + 0.94, 1.4), Vector3(5.2, GF + 0.97, 2.2), Color("#3a3a3a"))
	for bz in [1.6, 2.0]:
		b.cylinder(_m("metal"), Transform3D(Basis(), Vector3(4.92, GF + 0.97, bz)), 0.11, 0.11, 0.02, 10, Color("#5b6270"))
	b.cylinder(_m("metal"), Transform3D(Basis(), Vector3(4.92, GF + 0.99, 1.6)), 0.12, 0.1, 0.18, 10, Color("#c8423b"))
	b.box_mm(_m("metal"), Vector3(4.7, GF + 0.9, 3.4), Vector3(5.15, GF + 0.95, 4.2), Color("#c9ced2"))
	_furn(b, "wood", Vector3(-3.9, GF, 1.8), Vector3(-2.2, GF + 0.78, 3.8), Color("#c9975a"))
	for cz in [2.3, 3.3]:
		_chair(b, Vector3(-4.3, GF, cz), Color("#c8423b"))
		_chair(b, Vector3(-1.8, GF, cz), Color("#c8423b"))
	b.cylinder(solid, Transform3D(Basis(), Vector3(-3.05, GF + 0.78, 2.8)), 0.22, 0.28, 0.1, 10, Color("#fbf8f0"))
	for k in 4:
		b.sphere(solid, Vector3(-3.05 + (k - 1.5) * 0.11, GF + 0.92, 2.8 + (k % 2) * 0.08), Vector3(0.06, 0.06, 0.06), 3, 6, [Color("#d8433b"), Color("#f2c14e"), Color("#7fae55"), Color("#e8873a")][k])
	_pendant(b, Vector3(-3.05, 2.9, 2.8), COTTAGE_CEIL, Color("#2f6f8f"))
	# Pan rack over the east counter.
	b.box_mm(_m("metal"), Vector3(3.6, 3.0, 2.0), Vector3(3.66, 3.04, 4.6), Color("#5b6270"))
	for k in 5:
		var pz := 2.2 + k * 0.55
		b.tube(_m("metal"), PackedVector3Array([Vector3(3.63, 3.0, pz), Vector3(3.63, 2.75, pz)]), 0.008, 3, Color("#5b6270"))
		b.cylinder(_m("metal"), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(3.7, 2.62, pz)), 0.14, 0.14, 0.06, 10, Color("#b8644a") if k % 2 == 0 else Color("#9aa3a8"))
	add_box("lamp", Vector3(3.63, 2.8, 3.3), Vector3(0.3, 0.5, 2.8))
	# Drying herbs across the window.
	var herbs := PackedVector3Array([Vector3(2.4, 3.2, hd - T - 0.12), Vector3(3.4, 3.12, hd - T - 0.12), Vector3(4.4, 3.2, hd - T - 0.12)])
	b.tube(_m("rope"), herbs, 0.008, 3, Color("#c9a27e"))
	for k in 5:
		var hp := Vector3(2.6 + k * 0.42, 3.05, hd - T - 0.12)
		b.sphere(_m("foliage"), hp, Vector3(0.07, 0.14, 0.07), 3, 5, Color("#7a9a4a"))
	b.cylinder(solid, Transform3D(Basis(), Vector3(-1.9, GF, 4.9)), 0.13, 0.15, 0.07, 10, Color("#6fb4e8"))
	_rug(b, Vector2(-0.9, 3.4), Vector2(0.9, 5.4), GF, Color("#e0a13a"), Color("#7a5236"))

	# Sitting room: round rug (the landing spot), fireplace, armchairs, the cat, books and a lamp.
	var rug_c := Vector3(0, GF, -2.6)
	b.cylinder(solid, Transform3D(Basis(), rug_c), 1.95, 1.95, 0.018, 28, Color("#f2c14e"))
	b.cylinder(solid, Transform3D(Basis(), rug_c), 1.75, 1.75, 0.022, 28, Color("#c8423b"))
	b.cylinder(solid, Transform3D(Basis(), rug_c), 1.1, 1.1, 0.026, 24, Color("#e8873a"))
	_fireplace(b, -hd + T)
	_armchair(b, Vector3(-3.1, GF, -3.0), Vector3.RIGHT, Color("#7c4f9e"))
	_armchair(b, Vector3(3.1, GF, -3.0), Vector3.LEFT, Color("#3f7d4f"))
	_sleeping_cat(b, Vector3(2.0, GF, -hd + 1.4))
	_bookshelf(b, Vector3(-hw + T, GF, -1.6), Vector3(-hw + T + 0.4, GF + 2.1, 0.2), Vector3.RIGHT)
	_floor_lamp(b, Vector3(4.6, GF, -4.9))
	_furn(b, "wood", Vector3(4.2, GF, -1.4), Vector3(4.9, GF + 0.6, -0.7), Color("#a87a4f"))
	b.cylinder(solid, Transform3D(Basis(), Vector3(4.55, GF + 0.6, -1.05)), 0.06, 0.05, 0.08, 8, Color("#fbf8f0"))
	_picture(b, Vector3(-hw + T + 0.01, 2.0, -3.6), Vector3.RIGHT, Vector2(0.9, 0.7), Color("#b9d6a8"))
	_picture(b, Vector3(hw - T - 0.01, 2.0, -2.6), Vector3.LEFT, Vector2(0.7, 0.9), Color("#e6c3da"))
	_lights.append([Vector3(0, 3.0, 3.2), Color("#ffe2b8"), 0.8, 6.0])
	_lights.append([Vector3(0, 3.0, -2.2), Color("#ffe2b8"), 0.7, 6.0])
	_lights.append([Vector3(0, 0.9, -4.7), Color("#ff9a4a"), 1.3, 4.5])


## Glass greenhouse on a low brick base with doors open at both ends.
func _greenhouse(b: MeshBuilder) -> void:
	var glass := _m("glass_clear")
	var solid := _m("solid")
	var brick := _m("brick")
	var frame := Color("#f4f0e6")
	var pane := Color(0.85, 0.95, 1.0)
	var rise := 1.0
	var ridge := GH_WALL + rise
	var door := 1.1
	b.box_mm(_m("paving"), Vector3(-door, 0.0, -hd), Vector3(door, 0.04, hd), Color("#e8e1d3"), 4)
	# Long sides: brick base, glass, frame posts.
	for s in [-1.0, 1.0]:
		var xo: float = s * hw
		b.box_mm(brick, Vector3(minf(xo, xo - s * 0.18), 0, -hd), Vector3(maxf(xo, xo - s * 0.18), 0.5, hd), Color.WHITE)
		b.box_mm(glass, Vector3(xo - 0.015, 0.5, -hd), Vector3(xo + 0.015, GH_WALL, hd), pane)
		var z := -hd
		while z <= hd + 0.01:
			b.box_mm(solid, Vector3(xo - 0.04, 0.5, z - 0.03), Vector3(xo + 0.04, GH_WALL, z + 0.03), frame)
			z += depth / 6.0
		b.box_mm(solid, Vector3(xo - 0.05, GH_WALL - 0.05, -hd), Vector3(xo + 0.05, GH_WALL + 0.03, hd), frame)
		add_box("greenhouse", Vector3(xo - s * 0.05, GH_WALL * 0.5, 0), Vector3(0.2, GH_WALL, depth))
	# Ends: glass either side of the doorway and in the gable, doors swung open.
	for f in [-1.0, 1.0]:
		var ze: float = f * hd
		for s in [-1.0, 1.0]:
			var xa: float = s * door
			var xb: float = s * hw
			b.box_mm(glass, Vector3(minf(xa, xb), 0.0, ze - 0.015), Vector3(maxf(xa, xb), GH_WALL, ze + 0.015), pane)
			b.box_mm(solid, Vector3(xa - 0.04, 0, ze - 0.04), Vector3(xa + 0.04, GH_WALL, ze + 0.04), frame)
			add_box("greenhouse", Vector3((xa + xb) * 0.5, GH_WALL * 0.5, ze), Vector3(absf(xb - xa), GH_WALL, 0.12))
			# Door leaf swung outward.
			var dir := Vector3(-s * cos(1.75), 0, f * sin(1.75))
			var c := Vector3(xa, GH_WALL * 0.5, ze) + dir * (door * 0.5)
			var basis := Basis(Vector3.UP, atan2(-dir.z, dir.x))
			b.box(glass, Transform3D(basis, c), Vector3(door - 0.06, GH_WALL - 0.08, 0.02), pane)
			b.box(solid, Transform3D(basis, c + Vector3(0, GH_WALL * 0.5 - 0.04, 0)), Vector3(door, 0.05, 0.04), frame)
			b.box(solid, Transform3D(basis, c - Vector3(0, GH_WALL * 0.5 - 0.04, 0)), Vector3(door, 0.05, 0.04), frame)
			b.box(solid, Transform3D(basis, c + dir * (door * 0.5)), Vector3(0.05, GH_WALL, 0.04), frame)
		b.box_mm(solid, Vector3(-hw, GH_WALL - 0.04, ze - 0.04), Vector3(hw, GH_WALL + 0.03, ze + 0.04), frame)
		var tri := PackedVector3Array([Vector3(-hw, GH_WALL, ze), Vector3(hw, GH_WALL, ze), Vector3(0, ridge, ze)])
		b.poly(glass, tri, pane)
		add_convex("greenhouse", PackedVector3Array([Vector3(-hw, GH_WALL, ze - 0.06), Vector3(hw, GH_WALL, ze - 0.06), Vector3(0, ridge, ze - 0.06),
			Vector3(-hw, GH_WALL, ze + 0.06), Vector3(hw, GH_WALL, ze + 0.06), Vector3(0, ridge, ze + 0.06)]))
	# Roof panes, ridge and rafters.
	var angle := atan2(rise, hw)
	var slope_len := hw / cos(angle)
	for s in [-1.0, 1.0]:
		var mid := Vector3(s * hw * 0.5, GH_WALL + rise * 0.5, 0)
		var basis := Basis(Vector3.FORWARD, s * angle)
		b.box(glass, Transform3D(basis, mid), Vector3(slope_len, 0.02, depth), pane)
		var z := -hd
		while z <= hd + 0.01:
			b.box(solid, Transform3D(basis, Vector3(mid.x, mid.y, z) + basis * Vector3(0, 0.03, 0)), Vector3(slope_len, 0.05, 0.05), frame)
			z += depth / 6.0
		add_box_xf("greenhouse", Transform3D(basis, mid + basis * Vector3(0, 0.08, 0)), Vector3(slope_len + 0.1, 0.2, depth + 0.1))
	b.box_mm(solid, Vector3(-0.05, ridge - 0.04, -hd - 0.05), Vector3(0.05, ridge + 0.05, hd + 0.05), frame)
	# Potting benches, plants and tomatoes along both sides; a watering can in the aisle.
	for s in [-1.0, 1.0]:
		var x0: float = s * 1.35
		var x1: float = s * (hw - 0.2)
		b.box_mm(_m("wood"), Vector3(minf(x0, x1), 0.82, -hd + 0.3), Vector3(maxf(x0, x1), 0.88, hd - 0.3), Color("#a87a4f"))
		for lz in [-hd + 0.35, hd - 0.35]:
			b.box_mm(_m("wood"), Vector3(minf(x0, x1), 0, lz - 0.03), Vector3(minf(x0, x1) + 0.06, 0.82, lz + 0.03), Color("#8a6a52"))
			b.box_mm(_m("wood"), Vector3(maxf(x0, x1) - 0.06, 0, lz - 0.03), Vector3(maxf(x0, x1), 0.82, lz + 0.03), Color("#8a6a52"))
		add_box("furniture", Vector3((x0 + x1) * 0.5, 0.44, 0), Vector3(absf(x1 - x0), 0.88, depth - 0.6))
		var z := -hd + 0.6
		while z < hd - 0.4:
			var px: float = s * 1.68
			b.cylinder(brick, Transform3D(Basis(), Vector3(px, 0.88, z)), 0.1, 0.13, 0.18, 8, Color("#c46a4a"))
			var g := Color("#5f8f45").lerp(Color("#8ab45e"), _rng.randf())
			b.sphere(_m("foliage"), Vector3(px, 1.2 + _rng.randf() * 0.1, z), Vector3(0.24, 0.26, 0.24), 4, 7, g)
			if _rng.randf() < 0.6:
				for k in 3:
					b.sphere(solid, Vector3(px + _rng.randf_range(-0.15, 0.15), 1.1 + _rng.randf() * 0.25, z + _rng.randf_range(-0.15, 0.15)), Vector3(0.045, 0.045, 0.045), 3, 5, Color("#d8433b"))
			z += 0.62
	b.cylinder(_m("metal"), Transform3D(Basis(), Vector3(0.75, 0.04, 1.8)), 0.12, 0.11, 0.25, 10, Color("#3f7d4f"))
	b.tube(_m("metal"), PackedVector3Array([Vector3(0.85, 0.2, 1.8), Vector3(1.05, 0.34, 1.8)]), 0.015, 4, Color("#3f7d4f"))


# --- Shell helpers ------------------------------------------------------------------------------

func _m(kind: String) -> Material:
	return Mats.get_mat(kind)


static func _hole(x0: float, x1: float, y0: float, y1: float, kind := "window") -> Dictionary:
	return {"x0": x0, "x1": x1, "y0": y0, "y1": y1, "kind": kind}


## Solid rectangles [x0, x1, y0, y1] of a wall spanning x0..x1, y0..y1 around the holes.
## Holes may be stacked above each other but must not overlap.
static func _rects(x0: float, x1: float, y0: float, y1: float, holes: Array) -> Array:
	var xs := [x0, x1]
	for h: Dictionary in holes:
		xs.append(h.x0)
		xs.append(h.x1)
	xs.sort()
	var out := []
	for i in xs.size() - 1:
		var a: float = xs[i]
		var c: float = xs[i + 1]
		if c - a < 0.001:
			continue
		var col := holes.filter(func(h: Dictionary) -> bool: return h.x0 <= a + 0.001 and h.x1 >= c - 0.001)
		col.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p.y0 < q.y0)
		var y := y0
		for h: Dictionary in col:
			if h.y0 > y:
				out.append([a, c, y, h.y0])
			y = maxf(y, h.y1)
		if y < y1:
			out.append([a, c, y, y1])
	return out


## A wall across the house (in the XY plane) with openings. z_out is its outer face and
## facing (+1 north, -1 south) points outward. Exterior walls have siding outside and plaster
## inside; partitions are plaster on both sides (out_col on the z_out side).
func _cross_wall(b: MeshBuilder, z_out: float, facing: float, x0: float, x1: float, y0: float, y1: float,
		holes: Array, out_col: Color, in_col: Color, exterior := true, thick := T) -> void:
	var z_mid := z_out - facing * thick * 0.5
	var z_in := z_out - facing * thick
	var out_mat := _m("paint") if exterior else _m("plaster")
	for r in _rects(x0, x1, y0, y1, holes):
		b.box_mm(out_mat, Vector3(r[0], r[2], minf(z_out, z_mid)), Vector3(r[1], r[3], maxf(z_out, z_mid)), out_col)
		b.box_mm(_m("plaster"), Vector3(r[0], r[2], minf(z_mid, z_in)), Vector3(r[1], r[3], maxf(z_mid, z_in)), in_col)
		add_box("wall", Vector3((r[0] + r[1]) * 0.5, (r[2] + r[3]) * 0.5, (z_out + z_in) * 0.5), Vector3(r[1] - r[0], r[3] - r[2], thick))
	for h: Dictionary in holes:
		_opening(b, h, z_out, facing, thick, exterior)


## Frame, sill and casements (or door leaves, or a closed pane) for one opening.
func _opening(b: MeshBuilder, h: Dictionary, z_out: float, facing: float, thick: float, exterior: bool) -> void:
	var solid := _m("solid")
	var trim := Mats.TRIM
	var x0: float = h.x0
	var x1: float = h.x1
	var y0: float = h.y0
	var y1: float = h.y1
	var kind: String = h.kind
	var z_in := z_out - facing * thick
	var za := minf(z_out, z_in) - 0.03
	var zb := maxf(z_out, z_in) + 0.03
	var fw := 0.09
	var cx := (x0 + x1) * 0.5
	var cy := (y0 + y1) * 0.5
	for fx in [x0 - fw, x1]:
		b.box_mm(solid, Vector3(fx, y0, za), Vector3(fx + fw, y1 + fw, zb), trim)
	b.box_mm(solid, Vector3(x0 - fw, y1, za), Vector3(x1 + fw, y1 + fw, zb), trim)
	if kind in ["window", "glass", "hatch"]:
		b.box_mm(solid, Vector3(x0 - 0.15, y0 - 0.1, za - 0.06), Vector3(x1 + 0.15, y0, zb + 0.06), trim)
	match kind:
		"window":
			_leaves(b, x0, x1, y0, y1, z_out, facing, false)
			if exterior and y0 > 1.2:
				inst("flowerbox", Transform3D(Basis(Vector3.UP, 0.0 if facing > 0 else PI), Vector3(cx, y0 - 0.35, z_out + facing * 0.16)))
		"french":
			_leaves(b, x0, x1, y0, y1, z_out, facing, true)
		"glass":
			var zm := z_out - facing * thick * 0.5
			b.box_mm(_m("window_lit"), Vector3(x0, y0, zm - 0.02), Vector3(x1, y1, zm + 0.02), Color("#8fb8d6"))
			b.box_mm(solid, Vector3(cx - 0.03, y0, zm - 0.05), Vector3(cx + 0.03, y1, zm + 0.05), trim)
			b.box_mm(solid, Vector3(x0, cy - 0.03, zm - 0.05), Vector3(x1, cy + 0.03, zm + 0.05), trim)
			add_box("glass", Vector3(cx, cy, zm), Vector3(x1 - x0, y1 - y0, thick))
			if exterior:
				var basis := Basis(Vector3.UP, 0.0 if facing > 0 else PI) * Basis.from_scale(Vector3(1, (y1 - y0) / 1.4, 1))
				for sx in [x0 - 0.3, x1 + 0.3]:
					inst("shutter", Transform3D(basis, Vector3(sx, cy, z_out + facing * 0.05)), shutter_color)
		"door":
			# Door swung open into the room, flat against the wall beside the hinge.
			var w := x1 - x0 - 0.04
			var dir := Vector3(cos(1.7), 0, -facing * sin(1.7))
			var c := Vector3(x0 + 0.02, y0 + (y1 - y0 - 0.04) * 0.5, z_in) + dir * (w * 0.5)
			var basis := Basis(Vector3.UP, atan2(-dir.z, dir.x))
			var dc := door_color if exterior else Color("#f4f0e6")
			b.box(solid, Transform3D(basis, c), Vector3(w, y1 - y0 - 0.04, 0.05), dc)
			for py in [0.55, -0.35]:
				b.box(solid, Transform3D(basis, c + Vector3(0, py, 0)), Vector3(w * 0.7, 0.6, 0.065), dc.darkened(0.08))
			b.sphere(_m("metal"), c + dir * (w * 0.4) + Vector3(0, -0.1, 0) + basis.z * 0.05, Vector3(0.035, 0.035, 0.035), 3, 6, Color("#e0b24a"))
			if exterior:
				b.box_mm(_m("stone"), Vector3(x0 - 0.2, 0, z_out), Vector3(x1 + 0.2, y0, z_out + facing * 0.6), Color("#d6cdbd"))
		"hatch":
			b.box_mm(_m("wood"), Vector3(x0, y0 - 0.02, za), Vector3(x1, y0, zb), Color("#a87a4f"))


## Two casements (windows) or glazed door leaves swung outward on hinges at the opening's sides.
func _leaves(b: MeshBuilder, x0: float, x1: float, y0: float, y1: float, z_out: float, facing: float, doors: bool) -> void:
	var solid := _m("solid")
	var pw := (x1 - x0) * 0.5 - 0.02
	var ph := y1 - y0 - 0.04
	var cy := (y0 + y1) * 0.5
	var ang := 1.75 if doors else 1.65
	for side in [0, 1]:
		var hinge_x: float = x0 if side == 0 else x1
		var dir := Vector3(cos(ang) * (1.0 if side == 0 else -1.0), 0.0, facing * sin(ang))
		var c := Vector3(hinge_x, cy, z_out + facing * 0.02) + dir * (pw * 0.5)
		var basis := Basis(Vector3.UP, atan2(-dir.z, dir.x))
		var fc := Color("#f4f0e6") if not doors else door_color
		b.box(_m("window_lit"), Transform3D(basis, c), Vector3(pw - 0.12, ph - 0.12, 0.02), Color("#9cc3dd"))
		b.box(solid, Transform3D(basis, c + Vector3(0, ph * 0.5 - 0.03, 0)), Vector3(pw, 0.06, 0.05), fc)
		b.box(solid, Transform3D(basis, c - Vector3(0, ph * 0.5 - 0.03, 0)), Vector3(pw, 0.06 if not doors else 0.3, 0.05), fc)
		b.box(solid, Transform3D(basis, c + dir * (pw * 0.5 - 0.03)), Vector3(0.06, ph, 0.05), fc)
		b.box(solid, Transform3D(basis, c - dir * (pw * 0.5 - 0.03)), Vector3(0.06, ph, 0.05), fc)
		b.box(solid, Transform3D(basis, c), Vector3(pw, 0.04, 0.04), fc)


## Siding walls along both long sides (x = +-hw), full depth. Interiors get _side_plaster.
func _side_walls(b: MeshBuilder, y0: float, y1: float) -> void:
	for s in [-1.0, 1.0]:
		var xo: float = s * hw
		var xi: float = s * (hw - T)
		b.box_mm(_m("paint"), Vector3(minf(xo, xi), y0, -hd), Vector3(maxf(xo, xi), y1, hd), wall_color)
		add_box("wall", Vector3((xo + xi) * 0.5, (y0 + y1) * 0.5, 0), Vector3(T, y1 - y0, depth))


func _side_plaster(b: MeshBuilder, y0: float, y1: float, z0: float, z1: float, col: Color) -> void:
	for s in [-1.0, 1.0]:
		var xi: float = s * (hw - T)
		b.box_mm(_m("plaster"), Vector3(minf(xi, xi - s * 0.02), y0, z0), Vector3(maxf(xi, xi - s * 0.02), y1, z1), col)


## A closed lower block (plinth plus siding up to `top`) with its collider.
func _body_shell(b: MeshBuilder, top: float) -> void:
	_plinth(b)
	b.box_mm(_m("paint"), Vector3(-hw, GF, -hd), Vector3(hw, top, hd), wall_color, 63 - 8 - 4)
	add_box("wall", Vector3(0, top * 0.5, 0), Vector3(width, top, depth))


func _plinth(b: MeshBuilder) -> void:
	b.box_mm(_m("stone"), Vector3(-hw - 0.06, 0, -hd - 0.06), Vector3(hw + 0.06, GF, hd + 0.06), Color("#d6cdbd"), 63 - 8)


## Corner boards, a floor band and the eave frieze.
func _trims(b: MeshBuilder, eave: float) -> void:
	var solid := _m("solid")
	var trim := Mats.TRIM
	for cx in [-hw, hw]:
		for cz in [-hd, hd]:
			b.box_at(solid, Vector3(cx, (GF + eave) * 0.5, cz), Vector3(0.2, eave - GF, 0.2), trim)
	for f in [-1.0, 1.0]:
		var z: float = f * hd
		b.box_mm(solid, Vector3(-hw - 0.05, eave - 0.25, minf(z, z + f * 0.08)), Vector3(hw + 0.05, eave, maxf(z, z + f * 0.08)), trim)
		if eave > AF - 0.1:
			b.box_mm(solid, Vector3(-hw - 0.04, UF - 0.12, minf(z, z + f * 0.06)), Vector3(hw + 0.04, UF + 0.04, maxf(z, z + f * 0.06)), trim)
	for s in [-1.0, 1.0]:
		var x: float = s * hw
		b.box_mm(solid, Vector3(minf(x, x + s * 0.08), eave - 0.25, -hd - 0.05), Vector3(maxf(x, x + s * 0.08), eave, hd + 0.05), trim)


func _floor(b: MeshBuilder, y: float, z0: float, z1: float, col: Color) -> void:
	b.box_mm(_m("wood"), Vector3(-hw + T, y - 0.04, z0), Vector3(hw - T, y, z1), col, 4)
	add_box("floor", Vector3(0, y * 0.5, (z0 + z1) * 0.5), Vector3(width - T * 2.0, y, z1 - z0))


func _ceiling(b: MeshBuilder, y0: float, y1: float, z0: float, z1: float) -> void:
	b.box_mm(_m("plaster"), Vector3(-hw + T, y0, z0), Vector3(hw - T, y1, z1), Color("#fbf7ee"))
	add_box("ceiling", Vector3(0, (y0 + y1) * 0.5, (z0 + z1) * 0.5), Vector3(width - T * 2.0, y1 - y0, z1 - z0))


## Gable roof with the ridge along Z (over the flight line), closed gable ends and round
## attic windows.
func _roof(b: MeshBuilder, eave: float, rise: float) -> void:
	var xf := Transform3D(Basis(), Vector3(0, eave, 0))
	b.gable_roof(_m("shingle"), xf, width, depth, rise, 0.4, 0.18, roof_color)
	b.gable_wall(_m("paint"), xf, width, rise, hd, 1.0, wall_color)
	b.gable_wall(_m("paint"), xf, width, rise, -hd, -1.0, wall_color)
	for s in [-1.0, 1.0]:
		var basis := Basis(Vector3.RIGHT, s * PI * 0.5)
		b.cylinder(_m("window_lit"), Transform3D(basis, Vector3(0, eave + rise * 0.4, s * (hd + 0.01))), 0.32, 0.32, 0.05, 10, Color("#3d5a78"))
		b.cylinder(_m("solid"), Transform3D(basis, Vector3(0, eave + rise * 0.4, s * hd)), 0.4, 0.4, 0.04, 10, Mats.TRIM)
	var o := 0.4
	add_convex("wall", PackedVector3Array([
		Vector3(-hw - o, eave, -hd - o), Vector3(hw + o, eave, -hd - o), Vector3(-hw - o, eave, hd + o), Vector3(hw + o, eave, hd + o),
		Vector3(0, eave + rise + 0.2, -hd - o), Vector3(0, eave + rise + 0.2, hd + o)]))


## Roof over the attic, lined with boards inside; the slopes are the attic's colliders.
func _attic_roof(b: MeshBuilder, rise: float) -> void:
	var xf := Transform3D(Basis(), Vector3(0, AF, 0))
	b.gable_roof(_m("shingle"), xf, width, depth, rise, 0.4, 0.18, roof_color)
	var angle := atan2(rise, hw)
	var slope_len := hw / cos(angle)
	for s in [-1.0, 1.0]:
		var mid := Vector3(s * hw * 0.5, AF + rise * 0.5, 0.0)
		var basis := Basis(Vector3.FORWARD, s * angle)
		b.box(_m("wood"), Transform3D(basis, mid + basis * Vector3(0, -0.03, 0)), Vector3(slope_len, 0.06, depth - 0.1), Color("#e3cfa8"))
		add_box_xf("wall", Transform3D(basis, mid + basis * Vector3(0, 0.1, 0)), Vector3(slope_len + 0.4, 0.32, depth + 0.6))


## Half-width of an attic gable at height y.
func _gable_x(y: float, rise: float) -> float:
	return hw * (1.0 - (y - AF) / rise)


## One flat piece of a gable end (2D points counter-clockwise as seen from +Z), with siding
## outside, plaster inside and a convex collider through the wall thickness.
func _gable_piece(b: MeshBuilder, pts: Array, z_out: float, facing: float, in_col: Color) -> void:
	var outer := PackedVector3Array()
	var inner := PackedVector3Array()
	var hull := PackedVector3Array()
	var z_in := z_out - facing * T
	for p: Vector2 in pts:
		outer.append(Vector3(p.x, p.y, z_out))
		inner.append(Vector3(p.x, p.y, z_in))
		hull.append(Vector3(p.x, p.y, z_out))
		hull.append(Vector3(p.x, p.y, z_in))
	if facing < 0.0:
		outer.reverse()
	else:
		inner.reverse()
	b.poly(_m("paint"), outer, wall_color)
	b.poly(_m("plaster"), inner, in_col)
	add_convex("wall", hull)


## Batched window (with shutters) on an outer wall. face is the outward normal.
func _win(face: Vector3, along: float, y: float, shutters := true) -> void:
	var basis := Basis(Vector3.UP, atan2(face.x, face.z))
	var p := Vector3(along, y, face.z * (hd + 0.02)) if absf(face.z) > 0.5 else Vector3(face.x * (hw + 0.02), y, along)
	inst("window", Transform3D(basis, p))
	if shutters:
		inst("shutter", Transform3D(basis, p - basis.x * 0.76 + face * 0.04), shutter_color)
		inst("shutter", Transform3D(basis, p + basis.x * 0.76 + face * 0.04), shutter_color)


## A closed front door with steps (decoration only) on an outer wall.
func _front_door(b: MeshBuilder, face: Vector3, along: float) -> void:
	var solid := _m("solid")
	var z := face.z * hd
	b.box_mm(solid, Vector3(along - 0.55, GF, minf(z, z + face.z * 0.07)), Vector3(along + 0.55, GF + 2.2, maxf(z, z + face.z * 0.07)), door_color)
	b.box_mm(solid, Vector3(along - 0.72, GF, minf(z, z + face.z * 0.12)), Vector3(along + 0.72, GF + 2.4, maxf(z, z + face.z * 0.12)), Mats.TRIM, 63 - 16 - 32)
	b.box_mm(solid, Vector3(along - 0.8, GF + 2.4, minf(z, z + face.z * 0.16)), Vector3(along + 0.8, GF + 2.56, maxf(z, z + face.z * 0.16)), Mats.TRIM)
	b.sphere(_m("metal"), Vector3(along + 0.35, GF + 1.05, z + face.z * 0.1), Vector3(0.04, 0.04, 0.04), 3, 6, Color("#e0b24a"))
	b.box_mm(_m("stone"), Vector3(along - 0.8, 0, minf(z, z + face.z * 0.7)), Vector3(along + 0.8, GF, maxf(z, z + face.z * 0.7)), Color("#d6cdbd"))


# --- Furniture ---------------------------------------------------------------------------------

## A box of furniture with an optional collider ("" for none).
func _furn(b: MeshBuilder, mat_kind: String, mn: Vector3, mx: Vector3, col: Color, kind := "furniture") -> void:
	b.box_mm(_m(mat_kind), mn, mx, col)
	if kind != "":
		add_box(kind, (mn + mx) * 0.5, mx - mn)


func _rug(b: MeshBuilder, a: Vector2, c: Vector2, y: float, col: Color, border: Color) -> void:
	b.box_mm(_m("solid"), Vector3(a.x, y, a.y), Vector3(c.x, y + 0.015, c.y), border, 63 - 8)
	b.box_mm(_m("solid"), Vector3(a.x + 0.12, y, a.y + 0.12), Vector3(c.x - 0.12, y + 0.02, c.y - 0.12), col, 4)


## Bed with its head at the max-Z end. mn/mx give the footprint (y = floor).
func _bed(b: MeshBuilder, mn: Vector3, mx: Vector3, blanket: Color, frame_h: float) -> void:
	var solid := _m("solid")
	var y := mn.y
	_furn(b, "wood", Vector3(mn.x, y, mn.z), Vector3(mx.x, y + frame_h, mx.z - 0.1), Color("#a87a4f"))
	b.box_mm(_m("wood"), Vector3(mn.x, y, mx.z - 0.1), Vector3(mx.x, y + frame_h + 0.5, mx.z), Color("#8a6a52"))
	b.box_mm(solid, Vector3(mn.x + 0.04, y + frame_h, mn.z + 0.04), Vector3(mx.x - 0.04, y + frame_h + 0.18, mx.z - 0.14), Color("#fbf8f0"))
	b.box_mm(solid, Vector3(mn.x + 0.01, y + frame_h + 0.12, mn.z + 0.01), Vector3(mx.x - 0.01, y + frame_h + 0.22, mx.z - 0.75), blanket)
	b.box_mm(solid, Vector3(mn.x + 0.2, y + frame_h + 0.18, mx.z - 0.6), Vector3(mx.x - 0.2, y + frame_h + 0.32, mx.z - 0.2), Color("#ffffff"))


func _bunk_bed(b: MeshBuilder, mn: Vector3, mx: Vector3) -> void:
	var wood := _m("wood")
	var solid := _m("solid")
	var y := mn.y
	for px in [mn.x + 0.04, mx.x - 0.04]:
		for pz in [mn.z + 0.04, mx.z - 0.04]:
			b.box_mm(wood, Vector3(px - 0.05, y, pz - 0.05), Vector3(px + 0.05, y + 2.0, pz + 0.05), Color("#a87a4f"))
	for level in [[0.3, Color("#e8873a")], [1.45, Color("#3f7d4f")]]:
		var ly: float = y + level[0]
		b.box_mm(wood, Vector3(mn.x, ly, mn.z), Vector3(mx.x, ly + 0.14, mx.z), Color("#c9a27e"))
		b.box_mm(solid, Vector3(mn.x + 0.05, ly + 0.14, mn.z + 0.05), Vector3(mx.x - 0.05, ly + 0.3, mx.z - 0.05), Color("#fbf8f0"))
		b.box_mm(solid, Vector3(mn.x + 0.03, ly + 0.26, mn.z + 0.03), Vector3(mx.x - 0.03, ly + 0.34, mx.z - 0.7), level[1])
		b.box_mm(solid, Vector3(mn.x + 0.25, ly + 0.3, mx.z - 0.55), Vector3(mx.x - 0.25, ly + 0.42, mx.z - 0.15), Color("#ffffff"))
	b.box_mm(wood, Vector3(mn.x, y + 1.75, mn.z), Vector3(mx.x, y + 1.85, mn.z + 0.06), Color("#a87a4f"))
	for k in 5:
		b.box_mm(wood, Vector3(mx.x - 0.03, y + 0.35 * (k + 1), mx.z - 0.55), Vector3(mx.x + 0.03, y + 0.35 * (k + 1) + 0.04, mx.z - 0.05), Color("#c9a27e"))
	add_box("furniture", (Vector3(mn.x, y, mn.z) + Vector3(mx.x, y + 2.0, mx.z)) * 0.5, Vector3(mx.x - mn.x, 2.0, mx.z - mn.z))


## Bookshelf against a wall; normal points into the room (+-X or +-Z).
func _bookshelf(b: MeshBuilder, mn: Vector3, mx: Vector3, normal: Vector3) -> void:
	_furn(b, "wood", mn, mx, Color("#a87a4f"))
	var along_x := absf(normal.z) > 0.5
	var length := (mx.x - mn.x) if along_x else (mx.z - mn.z)
	var front: float
	if along_x:
		front = mx.z if normal.z > 0.0 else mn.z
	else:
		front = mx.x if normal.x > 0.0 else mn.x
	var shelves := int((mx.y - mn.y) / 0.45)
	for s in shelves:
		var y := mn.y + 0.06 + s * 0.45
		var t := 0.05
		while t < length - 0.12:
			var w := _rng.randf_range(0.05, 0.11)
			var h := _rng.randf_range(0.24, 0.37)
			var col := Mats.pick(_rng, Mats.PALETTE_HOUSES + Mats.DOOR_COLORS)
			var depth_in := normal * 0.2
			var p: Vector3
			var q: Vector3
			if along_x:
				p = Vector3(mn.x + t, y, front)
				q = Vector3(mn.x + t + w, y + h, front)
			else:
				p = Vector3(front, y, mn.z + t)
				q = Vector3(front, y + h, mn.z + t + w)
			_boxp(b, _m("solid"), p - depth_in, q + normal * 0.02, col)
			t += w + 0.012


func _boxp(b: MeshBuilder, mat: Material, p: Vector3, q: Vector3, col: Color) -> void:
	b.box_mm(mat, Vector3(minf(p.x, q.x), minf(p.y, q.y), minf(p.z, q.z)), Vector3(maxf(p.x, q.x), maxf(p.y, q.y), maxf(p.z, q.z)), col)


func _chair(b: MeshBuilder, at: Vector3, col: Color) -> void:
	var solid := _m("solid")
	b.box_mm(solid, at + Vector3(-0.2, 0.42, -0.2), at + Vector3(0.2, 0.47, 0.2), col)
	for lx in [-0.17, 0.17]:
		for lz in [-0.17, 0.17]:
			b.box_mm(_m("wood"), at + Vector3(lx - 0.02, 0, lz - 0.02), at + Vector3(lx + 0.02, 0.42, lz + 0.02), Color("#8a6a52"))
	b.box_mm(solid, at + Vector3(-0.2, 0.47, 0.16), at + Vector3(0.2, 0.9, 0.2), col)


## Armchair facing `facing` (+-X or +-Z).
func _armchair(b: MeshBuilder, at: Vector3, facing: Vector3, col: Color) -> void:
	var basis := Basis(Vector3.UP, atan2(facing.x, facing.z))
	var solid := _m("solid")
	var xf := Transform3D(basis, at)
	b.box(solid, xf * Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(0.9, 0.5, 0.85), col)
	b.box(solid, xf * Transform3D(Basis(), Vector3(0, 0.75, -0.34)), Vector3(0.9, 0.55, 0.2), col)
	for s in [-1.0, 1.0]:
		b.box(solid, xf * Transform3D(Basis(), Vector3(s * 0.4, 0.62, 0.0)), Vector3(0.14, 0.3, 0.85), col.darkened(0.1))
	b.box(solid, xf * Transform3D(Basis(), Vector3(0, 0.53, 0.05)), Vector3(0.62, 0.08, 0.66), col.lightened(0.15))
	add_box("furniture", at + Vector3(0, 0.52, 0), Vector3(0.95, 1.04, 0.95))


## Sofa between mn and mx (y = floor), facing +X or -X with its back against the wall behind.
func _sofa(b: MeshBuilder, mn: Vector3, mx: Vector3, facing: Vector3, col: Color) -> void:
	var solid := _m("solid")
	var y := mn.y
	b.box_mm(solid, Vector3(mn.x, y, mn.z), Vector3(mx.x, y + 0.45, mx.z), col)
	var bx := mn.x if facing.x > 0.0 else mx.x - 0.22
	b.box_mm(solid, Vector3(bx, y + 0.45, mn.z), Vector3(bx + 0.22, y + 1.0, mx.z), col)
	for z in [mn.z, mx.z - 0.18]:
		b.box_mm(solid, Vector3(mn.x, y + 0.45, z), Vector3(mx.x, y + 0.7, z + 0.18), col.darkened(0.1))
	var c0 := bx + 0.22 if facing.x > 0.0 else mn.x + 0.05
	var c1 := mx.x - 0.05 if facing.x > 0.0 else bx
	for k in 3:
		var z0 := lerpf(mn.z + 0.2, mx.z - 0.2, k / 3.0)
		var z1 := lerpf(mn.z + 0.2, mx.z - 0.2, (k + 1) / 3.0) - 0.03
		b.box_mm(solid, Vector3(c0, y + 0.45, z0), Vector3(c1, y + 0.55, z1), col.lightened(0.12))
	add_box("furniture", (Vector3(mn.x, y, mn.z) + Vector3(mx.x, y + 1.0, mx.z)) * 0.5, Vector3(mx.x - mn.x, 1.0, mx.z - mn.z))


func _plant(b: MeshBuilder, at: Vector3, s: float) -> void:
	b.cylinder(_m("brick"), Transform3D(Basis(), at), 0.16 * s, 0.21 * s, 0.32 * s, 10, Color("#c46a4a"))
	var g := Color("#5f8f45").lerp(Color("#8ab45e"), _rng.randf())
	b.sphere(_m("foliage"), at + Vector3(0, 0.62 * s, 0), Vector3(0.3, 0.36, 0.3) * s, 4, 8, g)
	b.sphere(_m("foliage"), at + Vector3(0.1, 0.9 * s, 0.05), Vector3(0.2, 0.24, 0.2) * s, 3, 7, g.lightened(0.1))
	add_cylinder("furniture", at, 0.25 * s, 1.05 * s)


## Ceiling lamp hanging on a cord. Hitting the shade is a crash ("lamp").
func _pendant(b: MeshBuilder, at: Vector3, ceiling: float, col: Color, collide := true) -> void:
	b.cylinder(_m("metal"), Transform3D(Basis(), at + Vector3(0, 0.15, 0)), 0.012, 0.012, ceiling - at.y - 0.15, 4, Color("#4a4640"))
	b.cylinder(_m("solid"), Transform3D(Basis(), at - Vector3(0, 0.12, 0)), 0.3, 0.07, 0.28, 12, col)
	b.sphere(_m("glow"), at - Vector3(0, 0.1, 0), Vector3(0.08, 0.08, 0.08), 3, 6, Color("#fff1c9"))
	if collide:
		add_sphere("lamp", at, 0.32)


func _chandelier(b: MeshBuilder, at: Vector3, ceiling: float) -> void:
	var metal := _m("metal")
	var gold := Color("#d4a63a")
	b.cylinder(metal, Transform3D(Basis(), at), 0.015, 0.015, ceiling - at.y, 4, gold)
	b.sphere(metal, at, Vector3(0.1, 0.14, 0.1), 3, 8, gold)
	for k in 6:
		var a := TAU * k / 6.0
		var tip := at + Vector3(cos(a) * 0.45, 0.05, sin(a) * 0.45)
		b.tube(metal, PackedVector3Array([at + Vector3(0, -0.06, 0), at + Vector3(cos(a) * 0.3, -0.12, sin(a) * 0.3), tip]), 0.015, 4, gold)
		b.cylinder(_m("solid"), Transform3D(Basis(), tip), 0.025, 0.025, 0.12, 6, Color("#fbf8f0"))
		b.sphere(_m("glow"), tip + Vector3(0, 0.17, 0), Vector3(0.03, 0.05, 0.03), 3, 5, Color("#ffd27a"))
	add_sphere("lamp", at, 0.55)


func _desk_lamp(b: MeshBuilder, at: Vector3) -> void:
	b.cylinder(_m("metal"), Transform3D(Basis(), at), 0.07, 0.07, 0.02, 8, Color("#2f6f8f"))
	b.tube(_m("metal"), PackedVector3Array([at, at + Vector3(0.05, 0.28, 0), at + Vector3(-0.04, 0.4, 0)]), 0.012, 4, Color("#2f6f8f"))
	b.cylinder(_m("solid"), Transform3D(Basis(), at + Vector3(-0.06, 0.32, 0)), 0.1, 0.04, 0.1, 8, Color("#2f6f8f"))
	b.sphere(_m("glow"), at + Vector3(-0.06, 0.33, 0), Vector3(0.035, 0.035, 0.035), 3, 5, Color("#fff1c9"))


func _floor_lamp(b: MeshBuilder, at: Vector3) -> void:
	b.cylinder(_m("metal"), Transform3D(Basis(), at), 0.15, 0.15, 0.03, 10, Color("#4a4640"))
	b.cylinder(_m("metal"), Transform3D(Basis(), at), 0.02, 0.02, 1.5, 5, Color("#4a4640"))
	b.cylinder(_m("cloth"), Transform3D(Basis(), at + Vector3(0, 1.38, 0)), 0.24, 0.16, 0.3, 12, Color("#f6e3b8"))
	b.sphere(_m("glow"), at + Vector3(0, 1.45, 0), Vector3(0.06, 0.06, 0.06), 3, 5, Color("#fff1c9"))
	add_cylinder("furniture", at, 0.24, 1.7)


func _radiator(b: MeshBuilder, cx: float, z: float, floor_y: float, half: float) -> void:
	var solid := _m("solid")
	var n := int(half * 10.0)
	for k in n:
		var fx := cx - half + (k + 0.5) * (half * 2.0 / n)
		b.box_mm(solid, Vector3(fx - 0.04, floor_y + 0.12, z - 0.06), Vector3(fx + 0.04, floor_y + 0.42, z + 0.06), Color("#f4f0e6"))
	b.box_mm(solid, Vector3(cx - half, floor_y + 0.08, z - 0.07), Vector3(cx + half, floor_y + 0.13, z + 0.07), Color("#e6e0d2"))


func _globe(b: MeshBuilder, at: Vector3) -> void:
	b.cylinder(_m("metal"), Transform3D(Basis(), at), 0.1, 0.04, 0.1, 8, Color("#c9a24a"))
	b.sphere(_m("solid"), at + Vector3(0, 0.3, 0), Vector3(0.18, 0.18, 0.18), 6, 10, Color("#5e9ac8"))
	b.sphere(_m("foliage"), at + Vector3(0.06, 0.34, -0.04), Vector3(0.1, 0.08, 0.09), 3, 6, Color("#7fae55"))


func _grandfather_clock(b: MeshBuilder, at: Vector3) -> void:
	var wood := _m("wood")
	var solid := _m("solid")
	_furn(b, "wood", at + Vector3(-0.3, 0, -0.25), at + Vector3(0.3, 2.1, 0.25), Color("#7a5236"))
	b.cylinder(solid, Transform3D(Basis(Vector3.BACK, PI * 0.5), at + Vector3(-0.31, 1.75, 0)), 0.18, 0.18, 0.02, 14, Color("#fbf7ea"))
	b.box_mm(_m("metal"), at + Vector3(-0.32, 0.6, -0.04), at + Vector3(-0.3, 1.3, 0.04), Color("#d4a63a"))
	b.box_mm(wood, at + Vector3(-0.35, 2.1, -0.3), at + Vector3(0.35, 2.2, 0.3), Color("#6b4a32"))


## Picture frame flat on a wall; normal points into the room.
func _picture(b: MeshBuilder, center: Vector3, normal: Vector3, size: Vector2, col: Color) -> void:
	var basis := Basis(Vector3.UP, atan2(normal.x, normal.z))
	var xf := Transform3D(basis, center)
	b.box(_m("wood"), xf * Transform3D(Basis(), Vector3(0, 0, 0.015)), Vector3(size.x + 0.1, size.y + 0.1, 0.03), Color("#8a6a52"))
	b.box(_m("solid"), xf * Transform3D(Basis(), Vector3(0, 0, 0.032)), Vector3(size.x, size.y, 0.01), col)
	b.box(_m("solid"), xf * Transform3D(Basis(), Vector3(0, -size.y * 0.15, 0.04)), Vector3(size.x * 0.6, size.y * 0.25, 0.005), col.darkened(0.25))


## Small folded paper plane lying flat (tilt 0) or hanging.
func _paper_plane(b: MeshBuilder, at: Vector3, yaw: float, tilt: float) -> void:
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
	var nose := at + basis * Vector3(0, 0, -0.18)
	var l := at + basis * Vector3(-0.12, 0.02, 0.12)
	var r := at + basis * Vector3(0.12, 0.02, 0.12)
	var keel := at + basis * Vector3(0, -0.03, 0.12)
	var mat := _m("paper_plane")
	b.poly(mat, PackedVector3Array([nose, l, keel]), Color.WHITE)
	b.poly(mat, PackedVector3Array([nose, keel, r]), Color.WHITE)


## Fireplace on the south wall: brick chimney breast, glowing fire and a mantel.
func _fireplace(b: MeshBuilder, wall_z: float) -> void:
	var solid := _m("solid")
	var front := wall_z + 0.5
	b.box_mm(_m("brick"), Vector3(-1.3, GF, wall_z), Vector3(1.3, COTTAGE_CEIL, front), Color.WHITE)
	add_box("wall", Vector3(0, (GF + COTTAGE_CEIL) * 0.5, (wall_z + front) * 0.5), Vector3(2.6, COTTAGE_CEIL - GF, front - wall_z))
	b.box_mm(solid, Vector3(-0.6, GF, front - 0.02), Vector3(0.6, GF + 0.8, front + 0.01), Color("#2a2522"))
	b.box_mm(_m("stone"), Vector3(-1.0, GF, front), Vector3(1.0, GF + 0.06, front + 0.45), Color("#cfc6b6"))
	for k in 3:
		b.cylinder(_m("wood"), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-0.35 + k * 0.05, GF + 0.1 + k * 0.06, front + 0.06 - k * 0.05)), 0.06, 0.06, 0.6, 6, Color("#6b4a32"))
	for k in 5:
		var fx := -0.3 + k * 0.15
		var fh := 0.22 + 0.12 * float((k * 7) % 3)
		b.sphere(_m("glow"), Vector3(fx, GF + 0.2 + fh * 0.5, front + 0.05), Vector3(0.09, fh * 0.5, 0.06), 3, 6, Color("#ff9a3d") if k % 2 == 0 else Color("#ffd25a"))
	b.box_mm(_m("wood"), Vector3(-1.5, GF + 1.05, front - 0.05), Vector3(1.5, GF + 1.15, front + 0.22), Color("#7a5236"))
	b.box_mm(solid, Vector3(-0.15, GF + 1.15, front - 0.02), Vector3(0.15, GF + 1.45, front + 0.12), Color("#e0b24a"))
	b.cylinder(solid, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, GF + 1.32, front + 0.12)), 0.1, 0.1, 0.01, 12, Color("#fbf7ea"))
	for cx in [-1.1, -0.85, 0.9]:
		b.cylinder(solid, Transform3D(Basis(), Vector3(cx, GF + 1.15, front + 0.08)), 0.03, 0.03, 0.2, 6, Color("#fbf3dc"))
		b.sphere(_m("glow"), Vector3(cx, GF + 1.39, front + 0.08), Vector3(0.015, 0.03, 0.015), 2, 4, Color("#ffd27a"))
	_picture(b, Vector3(0, 2.6, front + 0.005), Vector3.BACK, Vector2(1.1, 0.7), Color("#a9c9db"))


func _sleeping_cat(b: MeshBuilder, at: Vector3) -> void:
	var solid := _m("solid")
	var fur := Color("#e8873a")
	b.cylinder(_m("wood"), Transform3D(Basis(), at), 0.42, 0.46, 0.16, 14, Color("#c9a27e"))
	b.cylinder(solid, Transform3D(Basis(), at + Vector3(0, 0.08, 0)), 0.36, 0.36, 0.06, 14, Color("#e6c3da"))
	b.sphere(solid, at + Vector3(0, 0.22, 0), Vector3(0.26, 0.12, 0.2), 4, 8, fur)
	b.sphere(solid, at + Vector3(0.2, 0.24, 0.08), Vector3(0.11, 0.09, 0.1), 4, 8, fur)
	for s in [-1.0, 1.0]:
		b.poly(solid, PackedVector3Array([at + Vector3(0.22, 0.3, 0.08 + s * 0.04), at + Vector3(0.26, 0.3, 0.08 + s * 0.08), at + Vector3(0.24, 0.38, 0.08 + s * 0.06)]), fur.darkened(0.15))
	b.tube(solid, PackedVector3Array([at + Vector3(-0.22, 0.18, -0.05), at + Vector3(-0.1, 0.16, 0.18), at + Vector3(0.12, 0.17, 0.2)]), 0.035, 4, fur)
