class_name CityBuilder
extends TownBuilder
## City Rooftops (map 3): a grid of streets with blocks of flat-roofed buildings, water towers,
## rooftop gardens and billboards, Main Avenue down the middle and a little park with a fountain.
## Built procedurally like the other maps and sharing their sky, lighting and helpers. Buildings
## under any flight route are kept low enough not to block it (see _route_cap).

const WALLS := ["#e9d9c0", "#f2e6cf", "#d9c3a5", "#cfe0e3", "#f3d7c4", "#e3e7d9", "#f6efe0", "#e8cfc0"]
const BRICK_TINTS := ["#ffffff", "#f3dccf", "#e9c8b6", "#f7e7da"]
const AWNINGS := ["#c8423b", "#2f6f8f", "#5f9a45", "#e0a43a", "#8a5aa8", "#e8546a"]

## Flight 1 (Rooftop Hop): the roof it launches from and the rooftop garden it lands on.
const START_LOT := Rect2(-23, 30, 15, 16)
const START_STOREYS := 9
const GARDEN_LOT := Rect2(8, -142, 15, 16)
const GARDEN_STOREYS := 4
## Flight 2 (Alley Run): the roof it dives off into the long alley at x = -72, and the alley
## itself (flight routes inside it don't lower the buildings either side: they are its walls).
const ALLEY_START_LOT := Rect2(-90, 51, 15, 15)
const ALLEY_START_STOREYS := 6
const ALLEY := Rect2(-75, -120, 6, 200)
## Flight 2 lands at the café on the corner where x = -48 meets z = -72.
const CAFE := Vector3(-48, 0.0, -70)
## Warm steam from a manhole where x = -96 meets z = -24 (Flight 2 climbs on it).
const MANHOLE := Vector3(-96, 0.0, -24)
## Flight 3 (Window Express): Skyline Tower to dive off, four apartments in a row along
## x = TUNNEL_X to fly straight through (open windows on both sides: two on the 1st floor, then
## two on the 2nd, climbed to on the speed), and the low rooftop terrace it lands on.
const TUNNEL_X := -34.5
const TUNNEL_W := 3.6
const FORCED := {
	Rect2(-42, 98, 15, 16): {"storeys": 20, "roof": ["antenna"], "parapet": false, "brick": false, "wall": Color("#dfe6ea")},
	Rect2(-42, -46, 15, 16): {"storeys": 4, "tunnel": 1},
	Rect2(-42, -66, 15, 16): {"storeys": 4, "tunnel": 1},
	Rect2(-42, -94, 15, 16): {"storeys": 5, "tunnel": 2},
	Rect2(-42, -114, 15, 16): {"storeys": 5, "tunnel": 2},
	Rect2(-42, -142, 15, 16): {"storeys": 2, "roof": ["garden"], "parapet": false},
}
## The park: one whole block beside Main Avenue.
const PARK_BLOCK := Rect2(8, -66, 34, 36)

var _lots_built := 0


func _init() -> void:
	map_id = "city"
	# environment, ground, 4 groups of blocks, park, streets, skyline (see build()).
	build_steps = 9


func build() -> void:
	if is_built:
		return
	Terrain.map = "city"
	rng.seed = SEED + 11
	_collect_keepouts()
	batcher = Batcher.new()
	batcher.name = "Instances"
	add_child(batcher)
	_environment()
	await _step_yield()
	_c_ground()
	await _step_yield()
	var rows := CityTerrain.blocks()
	for k in rows.size():
		_c_block(rows[k])
		if k % 6 == 5:
			await _step_yield()
	_c_park()
	_c_cafe()
	await _step_yield()
	_c_streets()
	await _step_yield()
	_c_skyline()
	_clouds_build()
	await _step_yield()
	_sun_effects()
	_c_life()
	batcher.finalize()
	_on_quality(Settings.quality)
	build_progress = 1.0
	is_built = true
	built.emit()


func _ground(_x: float, _z: float) -> float:
	return 0.0


# --- Ground: asphalt, sidewalks and road markings ---------------------------------------------

func _c_ground() -> void:
	var b := MeshBuilder.new()
	var asphalt := Mats.get_mat("asphalt")
	var paving := Mats.get_mat("paving")
	b.quad(asphalt, Vector3(-420, 0, 320), Vector3(420, 0, 320), Vector3(420, 0, -480), Vector3(-420, 0, -480), Color("#8d8a86"), 0.25)
	for r in CityTerrain.blocks():
		var g := r.grow(CityTerrain.SIDEWALK)
		b.box_mm(paving, Vector3(g.position.x, 0, g.position.y), Vector3(g.end.x, 0.15, g.end.y), Color("#ddd5c6"), 63 - 8)
	# Dashed centre line and zebra crossings on Main Avenue.
	var paint := Mats.get_mat("solid")
	var z := 132.0
	while z > -276.0:
		var near_street := false
		for sz in CityTerrain.STREETS_Z:
			if absf(z - sz) < 8.0:
				near_street = true
		if not near_street:
			b.box_mm(paint, Vector3(-0.12, 0.01, z - 1.5), Vector3(0.12, 0.02, z + 1.5), Color("#f3ecd8"), 4)
		z -= 6.0
	for sz in CityTerrain.STREETS_Z:
		for i in 7:
			var x := -6.0 + i * 2.0
			b.box_mm(paint, Vector3(x - 0.45, 0.01, sz + 6.4), Vector3(x + 0.45, 0.02, sz + 9.0), Color("#f3ecd8"), 4)
	var mi := b.build_instance("CityGround", false)
	add_child(mi)


# --- Blocks and their buildings ---------------------------------------------------------------

func _c_block(r: Rect2) -> void:
	if r == PARK_BLOCK:
		return
	var a := CityTerrain.alley_width(r)
	var lw := (r.size.x - a) * 0.5
	var ld := (r.size.y - a) * 0.5
	var rects := [
		Rect2(r.position.x, r.position.y, lw, ld), Rect2(r.position.x + lw + a, r.position.y, lw, ld),
		Rect2(r.position.x, r.position.y + ld + a, lw, ld), Rect2(r.position.x + lw + a, r.position.y + ld + a, lw, ld),
	]
	var centre := Vector3(r.get_center().x, 0, r.get_center().y)
	var lots := []
	for wr: Rect2 in rects:
		var lot := _lot_for(wr, r)
		if lot.is_empty():
			continue
		lot.rect = Rect2(wr.position - Vector2(centre.x, centre.z), wr.size)
		if lot.has("tunnel"):
			lot.tunnel.x = TUNNEL_X - centre.x
		lots.append(lot)
	if lots.is_empty():
		return
	var blk := CityBlock.new()
	blk.name = "Block_%d_%d" % [int(centre.x), int(centre.z)]
	blk.batcher = batcher
	blk.lots = lots
	blk.position = centre
	add_child(blk)


## A lot's building (or {} to leave the lot empty because a flight passes too low over it).
func _lot_for(wr: Rect2, block: Rect2) -> Dictionary:
	_lots_built += 1
	var seed_v := 1000 + _lots_built * 17
	var lot := {"seed": seed_v, "parapet": true, "shop": rng.randf() < 0.7,
		"awning": Color(AWNINGS[rng.randi() % AWNINGS.size()])}
	lot.brick = rng.randf() < 0.45
	lot.wall = Color(BRICK_TINTS[rng.randi() % BRICK_TINTS.size()]) if lot.brick else Color(WALLS[rng.randi() % WALLS.size()])
	var faces := []
	if is_equal_approx(wr.position.y, block.position.y):
		faces.append(0)
	if is_equal_approx(wr.end.y, block.end.y):
		faces.append(1)
	if is_equal_approx(wr.position.x, block.position.x):
		faces.append(2)
	if is_equal_approx(wr.end.x, block.end.x):
		faces.append(3)
	lot.street_faces = faces
	if wr == START_LOT:
		lot.storeys = START_STOREYS
		lot.parapet = false
		lot.roof = ["tank", "ac"]
		return lot
	if FORCED.has(wr):
		var f: Dictionary = FORCED[wr]
		for k in f:
			lot[k] = f[k]
		lot.roof = f.get("roof", [])
		if f.has("tunnel"):
			lot.tunnel = {"storey": int(f.tunnel), "w": TUNNEL_W}
			lot.shop = false
		return lot
	if wr == ALLEY_START_LOT:
		lot.storeys = ALLEY_START_STOREYS
		lot.parapet = false
		lot.roof = ["tank"]
		lot.fire_face = 3
		return lot
	if wr == GARDEN_LOT:
		lot.storeys = GARDEN_STOREYS
		lot.parapet = false
		lot.roof = ["garden"]
		return lot
	# Taller toward downtown (the far end), with the odd tower.
	var downtown := clampf((-wr.get_center().y - 40.0) / 160.0, 0.0, 1.0)
	var storeys := rng.randi_range(3, 7) + int(downtown * 3.0)
	if rng.randf() < 0.12:
		storeys += rng.randi_range(3, 5)
	# The west blocks are Flight 2's alleys: tall enough to feel like a canyon.
	if block.get_center().x < -60.0 and block.get_center().x > -100.0:
		storeys = maxi(storeys, 4)
	var roof := []
	if rng.randf() < 0.4:
		roof.append("tank")
	if rng.randf() < 0.55:
		roof.append("hut")
	if rng.randf() < 0.6:
		roof.append("ac")
	if rng.randf() < 0.25:
		roof.append("skylight")
	if rng.randf() < 0.2:
		roof.append("chimneys")
	if storeys >= 8 and rng.randf() < 0.3:
		roof.append("billboard")
	elif rng.randf() < 0.2:
		roof.append("antenna")
	# Keep flights clear: the roof (and anything on it) stays below the route.
	var cap := _route_cap(wr)
	if cap < INF:
		var max_storeys := int(floor((cap - CityBlock.GROUND_FLOOR) / CityBlock.STOREY)) + 1
		if max_storeys < 1:
			return {}
		storeys = mini(storeys, max_storeys)
	lot.storeys = storeys
	var top := CityBlock.GROUND_FLOOR + (storeys - 1) * CityBlock.STOREY
	var tall := {"tank": 6.3, "billboard": 5.4, "antenna": 5.5, "hut": 2.7, "chimneys": 1.6, "ac": 1.0, "skylight": 0.6}
	var kept := []
	for f in roof:
		if top + float(tall[f]) <= cap:
			kept.append(f)
	lot.roof = kept
	# Fire escapes on some of the walls lining the long alley.
	if is_equal_approx(wr.end.x, ALLEY.position.x) and rng.randf() < 0.6:
		lot.fire_face = 3
	elif is_equal_approx(wr.position.x, ALLEY.end.x) and rng.randf() < 0.6:
		lot.fire_face = 2
	return lot


## The highest a roof may reach over this lot: 3.5 m under any flight route passing over it
## (INF when none does). Routes flying beside a building (down an alley or a street) leave it
## alone: it is the wall of that alley.
func _route_cap(wr: Rect2) -> float:
	var cap := INF
	var g := wr.grow(1.0)
	for seg in _route_keepouts:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var n := maxi(2, int(Vector2(b.x - a.x, b.z - a.z).length()))
		for i in n + 1:
			var p := a.lerp(b, float(i) / n)
			if ALLEY.has_point(Vector2(p.x, p.z)) and p.y < 20.0:
				continue
			if g.has_point(Vector2(p.x, p.z)):
				cap = minf(cap, p.y - 3.5)
	for pad in _pad_keepouts:
		if ALLEY.has_point(Vector2(pad.x, pad.z)):
			continue
		if g.has_point(Vector2(pad.x, pad.z)):
			cap = minf(cap, pad.y - 3.5)
	return cap


# --- The café terrace at the end of the alley (Flight 2 lands here) ---------------------------

func _c_cafe() -> void:
	var cols := [["#c8423b", "#fbf6ea"], ["#2f6f8f", "#f7eedd"], ["#5f9a45", "#fbf6ea"]]
	for k in 3:
		var t: Node3D = CAFE_SCENE.instantiate()
		t.batcher = batcher
		t.umbrella_a = Color(cols[k][0])
		t.umbrella_b = Color(cols[k][1])
		t.position = CAFE + Vector3([-1.6, 1.6, -1.6][k], 0, -6.5 - k * 2.6)
		add_child(t)
	# A chalkboard sign by the wall, and the manhole cover the steam rises from.
	var b := MeshBuilder.new()
	b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(), MANHOLE + Vector3(0, 0.005, 0)), 0.9, 0.9, 0.03, 16, Color("#4a4f55"))
	b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(), MANHOLE + Vector3(0, 0.035, 0)), 0.6, 0.6, 0.01, 16, Color("#3b3f46"))
	var s := CAFE + Vector3(2.4, 0, 2.5)
	b.box_mm(Mats.get_mat("wood"), s + Vector3(-0.35, 0, -0.05), s + Vector3(0.35, 1.0, 0.05), Color("#7a5a40"))
	b.box_mm(Mats.get_mat("solid"), s + Vector3(-0.3, 0.35, -0.07), s + Vector3(0.3, 0.95, -0.05), Color("#2f3a36"))
	add_child(b.build_instance("CafeSign", false))


# --- The park ---------------------------------------------------------------------------------

func _c_park() -> void:
	var r := PARK_BLOCK
	var b := MeshBuilder.new()
	b.box_mm(Mats.get_mat("grass"), Vector3(r.position.x, 0.15, r.position.y), Vector3(r.end.x, 0.2, r.end.y), Color("#b5d08a"), 4)
	var c := Vector3(r.get_center().x, 0.2, r.get_center().y)
	# Paths crossing at the fountain.
	var paving := Mats.get_mat("paving")
	b.box_mm(paving, Vector3(r.position.x, 0.2, c.z - 1.5), Vector3(r.end.x, 0.23, c.z + 1.5), Color("#e6dccb"), 4)
	b.box_mm(paving, Vector3(c.x - 1.5, 0.2, r.position.y), Vector3(c.x + 1.5, 0.23, r.end.y), Color("#e6dccb"), 4)
	add_child(b.build_instance("Park", false))
	var f: Node3D = FOUNTAIN_SCENE.instantiate()
	f.batcher = batcher
	f.position = c
	add_child(f)
	_static_cyl("wall", c, 3.4, 1.0)
	for i in 18:
		var p := Vector3(rng.randf_range(r.position.x + 3.0, r.end.x - 3.0), 0.2, rng.randf_range(r.position.y + 3.0, r.end.y - 3.0))
		if absf(p.x - c.x) < 4.0 or absf(p.z - c.z) < 4.0:
			continue
		_try_tree(p, rng.randf_range(0.85, 1.2), rng.randf() < 0.35)
	for k in 4:
		var bp := c + Vector3([-7.0, 7.0, 0.0, 0.0][k], 0.0, [0.0, 0.0, -7.0, 7.0][k])
		batcher.add("bench", Transform3D(Basis(Vector3.UP, [PI * 0.5, -PI * 0.5, 0.0, PI][k]), bp + Vector3(0, 0.0, 2.6 if k < 2 else 0.0) + Vector3(2.6 if k >= 2 else 0.0, 0, 0)))


# --- Streets: trees, lamps and parked cars ----------------------------------------------------

func _c_streets() -> void:
	var cols := ["#a9c9db", "#e9b7a1", "#f2d58f", "#b9d6a8", "#cbbbe8", "#c8423b", "#f5f0e5", "#6d8fd6"]
	var k := 0
	for sx in [-1.0, 1.0]:
		var z := 128.0
		while z > -262.0:
			var crossing := false
			for sz in CityTerrain.STREETS_Z:
				if absf(z - sz) < 9.0:
					crossing = true
			if not crossing:
				var lamp := Vector3(sx * 8.7, 0.15, z)
				batcher.add("lamp", Transform3D(Basis(), lamp))
				_lamp_collider(lamp)
				_try_tree(Vector3(sx * 9.4, 0.15, z - 8.0), rng.randf_range(0.8, 1.0), rng.randf() < 0.25)
				if rng.randf() < 0.45:
					var c: Node3D = CAR_SCENE.instantiate()
					c.batcher = batcher
					c.body_color = Color(cols[k % cols.size()])
					c.position = Vector3(sx * 6.4, 0.02, z - 4.0)
					c.rotation.y = 0.0 if sx > 0 else PI
					add_child(c)
					k += 1
			z -= 16.0


# --- The skyline beyond the edge of the map -----------------------------------------------------

func _c_skyline() -> void:
	var b := MeshBuilder.new()
	var solid := Mats.get_mat("solid")
	var placed := 0
	var tries := 0
	while placed < 90 and tries < 2000:
		tries += 1
		var x := rng.randf_range(-330.0, 330.0)
		var z := rng.randf_range(-470.0, 300.0)
		if absf(x) < 200.0 and z > -330.0 and z < 185.0:
			continue
		var w := rng.randf_range(14.0, 30.0)
		var d := rng.randf_range(14.0, 30.0)
		var h := rng.randf_range(18.0, 70.0) * (1.25 if z < -300.0 else 1.0)
		var col := Color("#cdbfb2").lerp(Color("#b9c3cf"), rng.randf())
		b.box_mm(solid, Vector3(x - w * 0.5, 0, z - d * 0.5), Vector3(x + w * 0.5, h, z + d * 0.5), col, 63 - 8)
		# Faint bands of windows, one per storey (two quads per face, no instancing).
		var band := col.darkened(0.16)
		var y := 4.0
		while y < h - 2.0:
			var y1 := y + 1.2
			var x0 := x - w * 0.5 - 0.05
			var x1 := x + w * 0.5 + 0.05
			var z0 := z - d * 0.5 - 0.05
			var z1 := z + d * 0.5 + 0.05
			b.quad(solid, Vector3(x1 - 1, y, z0), Vector3(x0 + 1, y, z0), Vector3(x0 + 1, y1, z0), Vector3(x1 - 1, y1, z0), band)
			b.quad(solid, Vector3(x0 + 1, y, z1), Vector3(x1 - 1, y, z1), Vector3(x1 - 1, y1, z1), Vector3(x0 + 1, y1, z1), band)
			b.quad(solid, Vector3(x0, y, z0 + 1), Vector3(x0, y, z1 - 1), Vector3(x0, y1, z1 - 1), Vector3(x0, y1, z0 + 1), band)
			b.quad(solid, Vector3(x1, y, z1 - 1), Vector3(x1, y, z0 + 1), Vector3(x1, y1, z0 + 1), Vector3(x1, y1, z1 - 1), band)
			y += 3.2
		if rng.randf() < 0.3:
			b.cylinder(solid, Transform3D(Basis(), Vector3(x, h, z)), 1.6, 1.6, 3.0, 8, col.darkened(0.1))
		placed += 1
	add_child(b.build_instance("Skyline", false))


func _c_life() -> void:
	for p in [Vector3(-20, 34, -20), Vector3(30, 30, -110), Vector3(-50, 28, -180), Vector3(40, 32, 40)]:
		var birds := BIRDS_SCENE.instantiate()
		birds.position = p
		add_child(birds)
	add_child(AIR_SCENE.instantiate())


## Showreel clips flown behind the menu while the city is loaded: [points, start, end].
func showreel() -> Array:
	return [
		[PackedVector3Array([Vector3(0, 7, 90), Vector3(0, 6, 40), Vector3(0.5, 5.5, -10), Vector3(1, 6.5, -60), Vector3(3, 9, -110)]), 0.0, 1.0],
		[PackedVector3Array([Vector3(-60, 34, 70), Vector3(-36, 31, 30), Vector3(-10, 28, -10), Vector3(14, 26, -60), Vector3(30, 24, -100)]), 0.0, 1.0],
		[PackedVector3Array([Vector3(-25, 5.5, 74), Vector3(-25, 5, 50), Vector3(-25, 5, 28), Vector3(-24, 6, 0), Vector3(-20, 8, -30)]), 0.0, 1.0],
	]
