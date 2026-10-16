class_name HarbourBuilder
extends TownBuilder
## Seaside Harbour (map 2), built procedurally like Linden Lane and sharing its sky, lighting,
## props and helpers. A bay opening to the sea toward -Z (see HarbourTerrain): a stone quay with
## a fish market and a crane, a long wooden pier with an ice-cream kiosk at its end, a stone
## breakwater, moored fishing and sailing boats, a boathouse over the water, a sandy beach with
## huts and umbrellas, the lighthouse on its headland, and the town climbing the hill behind.

const SEA_Y := Terrain.WATER_Y
const QUAY_Y := HarbourTerrain.QUAY_Y
const LIGHTHOUSE_SCENE := preload("res://props/lighthouse.tscn")
const BOAT_SCENE := preload("res://props/boat.tscn")

## The pier runs straight out to sea along x = PIER_X.
const PIER_X := -28.0
const PIER_END := -128.0
const PIER_Y := 1.7
const PIER_W := 4.4
## The boathouse stands across the waterline on the beach side (centre, half size).
const BOATHOUSE := Vector3(-62, 0, -26)
const BOATHOUSE_HALF := Vector2(5.0, 10.0)
const BREAKWATER := [Vector3(50, 0, -34), Vector3(54, 0, -78), Vector3(38, 0, -110), Vector3(10, 0, -118)]
const BREAKWATER_Y := 1.8
const CRANE := Vector3(30, 0, 0)
const HOUSE_COLORS := ["#f5f0e5", "#a9c9db", "#f2d58f", "#e9b7a1", "#cfe3e8", "#ffffff", "#b9d6a8"]

var _houses: Array[Vector3] = []


func _init() -> void:
	map_id = "harbour"
	build_steps = 12


func build() -> void:
	if is_built:
		return
	Terrain.map = "harbour"
	rng.seed = SEED + 7
	_collect_keepouts()
	batcher = Batcher.new()
	batcher.name = "Instances"
	add_child(batcher)
	_environment()
	await _step_yield()
	_h_terrain()
	await _step_yield()
	_h_sea()
	await _step_yield()
	var b := MeshBuilder.new()
	_h_quay(b)
	_h_pier(b)
	_h_breakwater(b)
	_h_boathouse(b)
	_h_market(b)
	_h_beach(b)
	await _step_yield()
	add_child(b.build_instance("HarbourStatic", true))
	await _step_yield()
	_h_lighthouse()
	await _step_yield()
	_h_boats()
	await _step_yield()
	_h_targets()
	await _step_yield()
	_h_town()
	await _step_yield()
	_h_trees()
	await _step_yield()
	_clouds_build()
	await _step_yield()
	_sun_effects()
	await _step_yield()
	_h_life()
	batcher.finalize()
	_on_quality(Settings.quality)
	is_built = true
	built.emit()


func shore(x: float) -> float:
	return HarbourTerrain.shore_z(x)


func _ground(x: float, z: float) -> float:
	return HarbourTerrain.ground_height(x, z)


# --- Ground and sea ------------------------------------------------------------------------

func _h_terrain() -> void:
	var x0 := -280.0
	var x1 := 280.0
	var z0 := 240.0
	var z1 := -260.0
	var step := 4.0
	var nx := int((x1 - x0) / step) + 1
	var nz := int((z0 - z1) / step) + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var idx_sand := PackedInt32Array()
	# How sandy/rocky each vertex is: those areas get a smooth surface instead of grass.
	var bare := PackedFloat32Array()
	var noise := FastNoiseLite.new()
	noise.seed = SEED + 7
	noise.frequency = 0.02
	var grass_a := Color("#cfe0a0")
	var grass_b := Color("#f2e6a8")
	var sand := Color("#f0dfb2")
	var rock := Color("#b2a898")
	var seabed := Color("#c9c19a")
	for iz in nz:
		var z := z0 - iz * step
		for ix in nx:
			var x := x0 + ix * step
			var h := _ground(x, z)
			verts.append(Vector3(x, h, z))
			var hx := _ground(x + 0.5, z) - _ground(x - 0.5, z)
			var hz := _ground(x, z + 0.5) - _ground(x, z - 0.5)
			normals.append(Vector3(-hx, 1.0, -hz).normalized())
			uvs.append(Vector2(x, z) * 0.25)
			var d := HarbourTerrain.inland(x, z)
			var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
			var c := grass_a.lerp(grass_b, n * 0.6)
			# Sand along the shore (all but the quay), rocks to the east, seabed under the water.
			var beachy := (1.0 - smoothstep(14.0, 22.0, d)) * (1.0 - HarbourTerrain.quay_weight(x))
			c = c.lerp(sand, beachy)
			var rocky := smoothstep(HarbourTerrain.QUAY_HALF + 6.0, 64.0, x) * (1.0 - smoothstep(6.0, 18.0, d))
			rocky = maxf(rocky, exp(-pow((x - HarbourTerrain.LIGHTHOUSE.x) / 22.0, 2.0)) * (1.0 - smoothstep(-2.0, 10.0, d)) * 0.8)
			c = c.lerp(rock.lerp(rock.lightened(0.15), n), rocky)
			var b := maxf(beachy, rocky)
			if h < SEA_Y + 0.3:
				c = seabed if h < SEA_Y else sand
				b = 1.0
			colors.append(c)
			bare.append(b)
	for iz in nz - 1:
		for ix in nx - 1:
			var a := iz * nx + ix
			var bb := a + 1
			var c := a + nx
			var d := c + 1
			var w := (bare[a] + bare[bb] + bare[c] + bare[d]) * 0.25
			if w > 0.5:
				idx_sand.append_array([a, d, bb, a, c, d])
			else:
				idx.append_array([a, d, bb, a, c, d])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := (Mats.get_mat("grass") as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.uv1_scale = Vector3.ONE
	mesh.surface_set_material(0, mat)
	# Sand, rock and seabed: the same vertices, a smooth plaster-like surface tinted by color.
	arrays[Mesh.ARRAY_INDEX] = idx_sand
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var smat := (Mats.get_mat("plaster") as StandardMaterial3D).duplicate() as StandardMaterial3D
	smat.uv1_scale = Vector3.ONE * 0.5
	smat.roughness = 1.0
	mesh.surface_set_material(1, smat)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _h_sea() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(1800, 1800)
	pm.subdivide_width = 16
	pm.subdivide_depth = 16
	var mi := MeshInstance3D.new()
	mi.name = "Sea"
	mi.mesh = pm
	mi.material_override = Mats.get_mat("water")
	mi.position = Vector3(0, SEA_Y, -300)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# --- Quay, pier and breakwater ------------------------------------------------------------------

func _h_quay(b: MeshBuilder) -> void:
	var stone := Mats.get_mat("stone")
	var paving := Mats.get_mat("paving")
	var half := HarbourTerrain.QUAY_HALF
	var x := -half
	var step := 3.0
	while x < half - 0.01:
		var xa := x
		var xb := minf(x + step, half)
		var za := shore(xa)
		var zb := shore(xb)
		# Wall face down into the water and coping stones along the top.
		b.quad(stone, Vector3(xa, -3.8, za), Vector3(xb, -3.8, zb), Vector3(xb, QUAY_Y + 0.12, zb), Vector3(xa, QUAY_Y + 0.12, za), Color("#cdbfa9"))
		var mid := Vector3((xa + xb) * 0.5, QUAY_Y + 0.06, (za + zb) * 0.5 + 0.35)
		var yaw := -atan2(zb - za, xb - xa)
		b.box(stone, Transform3D(Basis(Vector3.UP, yaw), mid), Vector3(xb - xa + 0.05, 0.24, 0.8), Color("#ddd3c2"))
		_static_box("wall", Vector3((xa + xb) * 0.5, -1.4, (za + zb) * 0.5 - 0.3), Vector3(xb - xa + 0.1, 4.8, 0.6), yaw)
		# The promenade on top.
		b.quad(paving, Vector3(xa, QUAY_Y + 0.02, za + 0.7), Vector3(xa, QUAY_Y + 0.02, za + 16.0), Vector3(xb, QUAY_Y + 0.02, zb + 16.0), Vector3(xb, QUAY_Y + 0.02, zb + 0.7), Color("#e8e1d3"))
		x = xb
	# Bollards along the edge, lamps and benches facing the water.
	x = -half + 4.0
	var k := 0
	while x < half - 3.0:
		var z := shore(x)
		if absf(x - PIER_X) > 4.0:
			b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(), Vector3(x, QUAY_Y, z + 1.0)), 0.22, 0.18, 0.6, 8, Color("#2f3a40"))
		var no_lamp := _blocks_route(Vector3(x, QUAY_Y, z + 13.0), 5.5, 0.4)
		if k % 2 == 0 and absf(x - PIER_X) > 5.0 and absf(x - CRANE.x) > 5.0 and not no_lamp:
			var lp := Vector3(x, QUAY_Y, z + 13.0)
			batcher.add("lamp", Transform3D(Basis(), lp))
			_lamp_collider(lp)
		elif absf(x - PIER_X) > 5.0 and (x < -16.0 or x > 20.0):
			batcher.add("bench", Transform3D(Basis(Vector3.UP, PI), Vector3(x, QUAY_Y, z + 4.0)))
		x += 7.0
		k += 1


func _h_pier(b: MeshBuilder) -> void:
	var wood := Mats.get_mat("wood")
	var solid := Mats.get_mat("solid")
	var z0 := shore(PIER_X) + 2.0
	var z1 := PIER_END
	var hw := PIER_W * 0.5
	var top := PIER_Y
	# Deck with a wider platform at the end.
	b.box_mm(wood, Vector3(PIER_X - hw, top - 0.28, z1 + 6.0), Vector3(PIER_X + hw, top, z0), Color("#b08a64"))
	b.box_mm(wood, Vector3(PIER_X - 5.0, top - 0.28, z1), Vector3(PIER_X + 5.0, top, z1 + 8.0), Color("#b08a64"))
	_static_box("wall", Vector3(PIER_X, top - 0.14, (z0 + z1 + 6.0) * 0.5), Vector3(PIER_W, 0.28, z0 - z1 - 6.0))
	_static_box("wall", Vector3(PIER_X, top - 0.14, z1 + 4.0), Vector3(10.0, 0.28, 8.0))
	# Posts down to the seabed and cross beams under the deck.
	var z := z0 - 2.0
	while z > z1 + 1.0:
		var w := 5.0 if z < z1 + 8.0 else hw + 0.1
		for sx in [-1.0, 1.0]:
			var px: float = PIER_X + sx * (w - 0.3)
			var gy := _ground(px, z)
			b.cylinder(wood, Transform3D(Basis(), Vector3(px, gy - 0.3, z)), 0.24, 0.22, top - gy + 0.05, 8, Color("#7a5a40"))
			_static_cyl("post", Vector3(px, gy - 0.3, z), 0.24, top - gy)
		b.box(wood, Transform3D(Basis(), Vector3(PIER_X, top - 0.45, z)), Vector3(w * 2.0, 0.22, 0.3), Color("#7a5a40"))
		z -= 5.0
	# Railings along both sides (low, so the plane can hop over the deck).
	for sx in [-1.0, 1.0]:
		var rx: float = PIER_X + sx * (hw - 0.1)
		b.box_mm(wood, Vector3(rx - 0.05, top + 0.85, z1 + 8.0), Vector3(rx + 0.05, top + 0.95, z0), Color("#e8dfcc"))
		_static_box("fence", Vector3(rx, top + 0.45, (z0 + z1 + 8.0) * 0.5), Vector3(0.12, 0.9, z0 - z1 - 8.0))
		var pz := z0
		while pz > z1 + 8.0:
			b.box(wood, Transform3D(Basis(), Vector3(rx, top + 0.45, pz)), Vector3(0.1, 0.9, 0.1), Color("#e8dfcc"))
			pz -= 2.5
	# Fairy lights strung along both sides just under the deck edge.
	var bulb_cols := [Color("#ffd27a"), Color("#ff9ccb"), Color("#9fd6ff"), Color("#b9f0a8")]
	for sx in [-1.0, 1.0]:
		var bz := z0 - 1.0
		var n := 0
		while bz > z1 + 1.0:
			var sag := 0.25 * absf(sin(n * PI / 6.0))
			b.sphere(Mats.get_mat("glow"), Vector3(PIER_X + sx * (hw + 0.05), top - 0.45 - sag, bz), Vector3(0.09, 0.09, 0.09), 3, 6, bulb_cols[n % 4])
			bz -= 1.25
			n += 1
	# Lamps every 15 m.
	z = z0 - 8.0
	var k := 0
	while z > z1 + 12.0:
		var lp := Vector3(PIER_X + (hw - 0.3) * (1.0 if k % 2 == 0 else -1.0), top, z)
		batcher.add("lamp", Transform3D(Basis(), lp))
		_lamp_collider(lp)
		z -= 15.0
		k += 1
	# The ice-cream kiosk at the end: a little hut with a striped roof and a big cone on top.
	var kc := Vector3(PIER_X, top, z1 + 3.0)
	b.box_mm(Mats.get_mat("paint"), kc + Vector3(-1.6, 0, -1.4), kc + Vector3(1.6, 2.4, 1.4), Color("#f6d6e0"))
	b.box_mm(Mats.get_mat("window_lit"), kc + Vector3(-1.1, 1.0, 1.41), kc + Vector3(1.1, 2.0, 1.45), Color("#3d5a78"))
	b.box_mm(solid, kc + Vector3(-1.3, 0.95, 1.4), kc + Vector3(1.3, 1.05, 1.9), Color("#fbf8f0"))
	b.box(Mats.get_mat("awning"), Transform3D(Basis(Vector3.RIGHT, -0.12), kc + Vector3(0, 2.55, 0.15)), Vector3(3.8, 0.12, 3.6), Color("#e8546a"))
	b.cylinder(solid, Transform3D(Basis(Vector3.RIGHT, PI), kc + Vector3(0, 3.75, 0)), 0.45, 0.02, 1.1, 10, Color("#e0a560"))
	b.sphere(solid, kc + Vector3(0, 3.9, 0), Vector3(0.5, 0.42, 0.5), 5, 8, Color("#f6c6d6"))
	_static_box("wall", kc + Vector3(0, 1.3, 0), Vector3(3.8, 2.6, 3.6))
	var sign := Label3D.new()
	sign.text = "ICES"
	sign.font = UIKit.display_font()
	sign.font_size = 96
	sign.pixel_size = 0.006
	sign.modulate = Color("#c8423b")
	sign.outline_size = 10
	sign.outline_modulate = Color("#fbf8f0")
	sign.position = kc + Vector3(0, 2.15, 1.47)
	add_child(sign)


func _h_breakwater(b: MeshBuilder) -> void:
	var stone := Mats.get_mat("stone")
	for i in BREAKWATER.size() - 1:
		var a: Vector3 = BREAKWATER[i]
		var c: Vector3 = BREAKWATER[i + 1]
		var mid := (a + c) * 0.5
		var length := Vector2(c.x - a.x, c.z - a.z).length() + 4.0
		var yaw := -atan2(c.z - a.z, c.x - a.x)
		var bottom := -3.6
		mid.y = (BREAKWATER_Y + bottom) * 0.5
		b.box(stone, Transform3D(Basis(Vector3.UP, yaw), mid), Vector3(length, BREAKWATER_Y - bottom, 4.6), Color("#bdb3a2"))
		b.box(Mats.get_mat("paving"), Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, BREAKWATER_Y + 0.03, mid.z)), Vector3(length - 0.4, 0.06, 3.4), Color("#e2d9c8"))
		# Big rough blocks along the sea side.
		var dir := Vector3(c.x - a.x, 0, c.z - a.z).normalized()
		var out := Vector3(dir.z, 0, -dir.x)
		var t := 0.0
		while t < length - 4.0:
			var p := a + dir * t + out * 2.9
			b.box(stone, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, rng.randf_range(-0.6, 0.4), p.z)), Vector3(2.2, 2.0, 2.0) * rng.randf_range(0.8, 1.2), Color("#a39a8c"))
			t += 3.0
		_static_box("wall", mid, Vector3(length, BREAKWATER_Y - bottom, 4.6), yaw)
	# A little red harbour light at the end.
	var e: Vector3 = BREAKWATER[BREAKWATER.size() - 1]
	b.cylinder(Mats.get_mat("paint"), Transform3D(Basis(), Vector3(e.x, BREAKWATER_Y, e.z)), 0.7, 0.55, 3.2, 12, Color("#c8423b"))
	b.sphere(Mats.get_mat("glow"), Vector3(e.x, BREAKWATER_Y + 3.5, e.z), Vector3(0.4, 0.45, 0.4), 4, 8, Color("#ff8a6a"))
	_static_cyl("post", Vector3(e.x, BREAKWATER_Y, e.z), 0.7, 3.9)


# --- Lighthouse, boathouse and boats ----------------------------------------------------------

func _h_lighthouse() -> void:
	var lh: Node3D = LIGHTHOUSE_SCENE.instantiate()
	lh.batcher = batcher
	var p := HarbourTerrain.LIGHTHOUSE
	lh.position = Vector3(p.x, _ground(p.x, p.z), p.z)
	add_child(lh)
	# A little green-and-white lighthouse on a rock islet out at sea (flight 8 circles it).
	var b := MeshBuilder.new()
	var stone := Mats.get_mat("stone")
	b.cylinder(stone, Transform3D(Basis(), Vector3(ISLET.x, SEA_Y - 3.0, ISLET.z)), 7.5, 5.5, 4.4, 14, Color("#a39a8c"))
	for k in 7:
		var a := TAU * k / 7.0 + 0.4
		b.box(stone, Transform3D(Basis(Vector3.UP, a), Vector3(ISLET.x + cos(a) * 6.0, SEA_Y + 0.4, ISLET.z + sin(a) * 6.0)), Vector3(2.6, 1.8, 2.2), Color("#b2a898"))
	add_child(b.build_instance("Islet", true))
	_static_cyl("wall", Vector3(ISLET.x, SEA_Y - 3.0, ISLET.z), 6.6, 4.6)
	var gl: Node3D = LIGHTHOUSE_SCENE.instantiate()
	gl.batcher = batcher
	gl.height = 9.0
	gl.base_radius = 1.8
	gl.top_radius = 1.3
	gl.band_color = Color("#3f8f5a")
	gl.with_cottage = false
	gl.position = Vector3(ISLET.x, ISLET_TOP, ISLET.z)
	add_child(gl)


func _h_boathouse(b: MeshBuilder) -> void:
	var c := BOATHOUSE
	var hx := BOATHOUSE_HALF.x
	var hz := BOATHOUSE_HALF.y
	var floor_y := 0.8
	var wall_h := 5.0
	var top := floor_y + wall_h
	var wood := Mats.get_mat("paint")
	var col := Color("#8a4b3a")
	var trim := Mats.TRIM
	# Side walls (full) and the end walls with big open doorways (6 m wide, 4.2 m tall).
	for sx in [-1.0, 1.0]:
		var x: float = c.x + sx * hx
		b.box_mm(wood, Vector3(x - 0.15, floor_y, c.z - hz), Vector3(x + 0.15, top, c.z + hz), col)
		_static_box("wall", Vector3(x, (floor_y + top) * 0.5, c.z), Vector3(0.3, wall_h, hz * 2.0))
	var door_w := 3.0
	var door_h := floor_y + 4.2
	for sz in [-1.0, 1.0]:
		var z: float = c.z + sz * hz
		for sx in [-1.0, 1.0]:
			var xa: float = c.x + sx * door_w
			var xb: float = c.x + sx * hx
			b.box_mm(wood, Vector3(minf(xa, xb), floor_y, z - 0.15), Vector3(maxf(xa, xb), top, z + 0.15), col)
			_static_box("wall", Vector3((xa + xb) * 0.5, (floor_y + top) * 0.5, z), Vector3(absf(xb - xa), wall_h, 0.3))
			# Big doors swung open against the wall.
			var hinge := Vector3(c.x + sx * door_w, floor_y, z + sz * 0.2)
			b.box(wood, Transform3D(Basis(Vector3.UP, sx * sz * 1.4), hinge + Vector3(-sx * 0.2, 2.1, sz * 1.4)), Vector3(0.12, 4.2, 2.9), col.lightened(0.1))
		b.box_mm(wood, Vector3(c.x - door_w, door_h, z - 0.15), Vector3(c.x + door_w, top, z + 0.15), col)
		b.box_mm(Mats.get_mat("solid"), Vector3(c.x - door_w - 0.15, door_h - 0.1, z - 0.2), Vector3(c.x + door_w + 0.15, door_h + 0.1, z + 0.2), trim)
		_static_box("wall", Vector3(c.x, (door_h + top) * 0.5, z), Vector3(door_w * 2.0, top - door_h, 0.3))
	# Gable roof along Z, a walkway inside along one wall, stilts into the water.
	var roof_xf := Transform3D(Basis(), Vector3(c.x, top, c.z))
	b.gable_roof(Mats.get_mat("shingle"), roof_xf, hx * 2.0, hz * 2.0, 2.6, 0.5, 0.18, Mats.ROOF_SLATE)
	for sz in [-1.0, 1.0]:
		b.gable_wall(wood, roof_xf, hx * 2.0, 2.6, sz * hz, sz, col)
	add_convex_body(PackedVector3Array([
		Vector3(c.x - hx - 0.6, top, c.z - hz - 0.6), Vector3(c.x + hx + 0.6, top, c.z - hz - 0.6),
		Vector3(c.x - hx - 0.6, top, c.z + hz + 0.6), Vector3(c.x + hx + 0.6, top, c.z + hz + 0.6),
		Vector3(c.x, top + 2.8, c.z - hz - 0.6), Vector3(c.x, top + 2.8, c.z + hz + 0.6)]))
	b.box_mm(Mats.get_mat("wood"), Vector3(c.x + hx - 1.6, floor_y - 0.2, c.z - hz), Vector3(c.x + hx - 0.15, floor_y, c.z + hz), Color("#b08a64"))
	for sx in [-1.0, 1.0]:
		for z in [c.z - hz, c.z, c.z + hz]:
			var px: float = c.x + sx * hx
			b.cylinder(Mats.get_mat("wood"), Transform3D(Basis(), Vector3(px, -3.6, z)), 0.25, 0.25, floor_y + 3.6, 8, Color("#6a4a34"))
	# A rowing boat inside.
	var rb: Node3D = ROWBOAT_SCENE.instantiate()
	rb.batcher = batcher
	rb.position = Vector3(c.x - 1.2, SEA_Y, c.z - 2.0)
	rb.rotation.y = PI * 0.5
	add_child(rb)


func add_convex_body(points: PackedVector3Array) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("kind", "wall")
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


func _h_boats() -> void:
	# [kind, position (x, z), yaw, hull color]
	var boats := [
		["fishing", Vector2(22, -24), 0.0, "#2f6f8f"],
		["fishing", Vector2(30, -34), 0.05, "#c8423b"],
		# Flight 6: three sailing boats to slalom round (bows to the north).
		["sail", Vector2(-2, -21), -PI * 0.5, "#2d4f7c"],
		["sail", Vector2(-8, -29), -PI * 0.5, "#e0a13a"],
		["sail", Vector2(-1.5, -38), -PI * 0.5, "#c8423b"],
		# Flight 6 flies in one side of the ferry's cabin and out the other.
		["ferry", Vector2(-5, -50), 0.0, "#2f6f8f"],
		["sail", Vector2(-2, -72), 1.2, "#f6f1e6"],
		["sail", Vector2(24, -62), 1.5, "#2d4f7c"],
		["fishing", Vector2(36, -48), 1.9, "#3f7d4f"],
		# Flight 4 lands on this one's back deck (bow to the north).
		["sail", Vector2(6, -86), -PI * 0.5, "#f6f1e6"],
		["sail", Vector2(-60, -90), 0.4, "#e0a13a"],
		# Flight 3 lands on this one's back deck (bow to the east).
		["fishing", Vector2(-14, -36.9), 0.0, "#e0a13a"],
	]
	for bd in boats:
		var bt: Node3D = BOAT_SCENE.instantiate()
		bt.batcher = batcher
		bt.kind = bd[0]
		if bd[0] == "ferry":
			bt.length = 14.0
			bt.beam = 4.4
			bt.deck_y = 1.0
			bt.cabin_color = Color("#fbf8f0")
			bt.bob = false
		elif bd[0] == "sail":
			bt.length = 7.0
			bt.beam = 2.4
			bt.deck_y = 0.6
			bt.cabin_color = Color("#f6f1e6")
		bt.hull_color = Color(bd[3])
		var p: Vector2 = bd[1]
		bt.position = Vector3(p.x, SEA_Y, p.y)
		bt.rotation.y = bd[2]
		add_child(bt)
	for p in [Vector3(-86, 0, -33), Vector3(-92, 0, -36), Vector3(-44, 0, -28)]:
		var rb: Node3D = ROWBOAT_SCENE.instantiate()
		rb.batcher = batcher
		rb.position = Vector3(p.x, SEA_Y, p.z)
		rb.rotation.y = rng.randf_range(-0.4, 0.4)
		add_child(rb)


# --- Market and beach ---------------------------------------------------------------------------

func _h_market(b: MeshBuilder) -> void:
	var solid := Mats.get_mat("solid")
	var wood := Mats.get_mat("wood")
	var stripes := ["#e8546a", "#2f6f8f", "#e0a13a", "#3f7d4f", "#7c4f9e"]
	var xs := [-14.0, -6.0, 2.0, 10.0, 18.0]
	for i in xs.size():
		var x: float = xs[i]
		var z := shore(x) + 9.0
		var y := QUAY_Y
		for px in [-1.6, 1.6]:
			for pz in [-1.2, 1.2]:
				b.box(solid, Transform3D(Basis(), Vector3(x + px, y + 1.2, z + pz)), Vector3(0.1, 2.4, 0.1), Color("#e8e0d0"))
		b.box(Mats.get_mat("awning"), Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(x, y + 2.55, z - 0.2)), Vector3(3.8, 0.1, 3.2), Color(stripes[i]))
		b.box_mm(wood, Vector3(x - 1.5, y, z - 1.4), Vector3(x + 1.5, y + 0.95, z - 0.7), Color("#b08a64"))
		# Crates of fish and fruit on the counter.
		for cx in [-0.9, 0.0, 0.9]:
			b.box(wood, Transform3D(Basis(), Vector3(x + cx, y + 1.08, z - 1.05)), Vector3(0.75, 0.26, 0.5), Color("#c9a27e"))
			var fill: Color = [Color("#9fb4c2"), Color("#e8873a"), Color("#d9473d"), Color("#7fae55")][(i + int(cx * 2)) % 4]
			b.box(solid, Transform3D(Basis(), Vector3(x + cx, y + 1.2, z - 1.05)), Vector3(0.66, 0.06, 0.42), fill)
		_static_box("wall", Vector3(x, y + 1.3, z - 0.2), Vector3(3.8, 2.6, 3.2))
	# A row of fish crates by the crane (flight 5 lands on top), one more stacked at the far end.
	var cz := shore(CRANE.x) + 6.0
	for i in 5:
		var p := Vector3(CRANE.x - 8.8 + i * 1.3, QUAY_Y + 0.5, cz)
		b.box(wood, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.06, 0.06)), p), Vector3(1.2, 1.0, 1.2), Color("#b08a64"))
		b.box(Mats.get_mat("solid"), Transform3D(Basis(), p + Vector3(0, 0.47, 0)), Vector3(1.05, 0.06, 1.05), Color("#9fb4c2") if i % 2 == 0 else Color("#e8873a"))
	b.box(wood, Transform3D(Basis(), Vector3(CRANE.x - 2.1, QUAY_Y + 0.5, cz)), Vector3(1.2, 1.0, 1.2), Color("#a07a54"))
	b.box(wood, Transform3D(Basis(Vector3.UP, 0.08), Vector3(CRANE.x - 2.1, QUAY_Y + 1.5, cz)), Vector3(1.2, 1.0, 1.2), Color("#a07a54"))
	_static_box("wall", Vector3(CRANE.x - 6.2, QUAY_Y + 0.5, cz), Vector3(6.4, 1.0, 1.4))
	_static_box("wall", Vector3(CRANE.x - 2.1, QUAY_Y + 1.0, cz), Vector3(1.3, 2.0, 1.3))
	# The crane: a blue tower with a boom reaching out over the water and a hook.
	var cb := Vector3(CRANE.x, QUAY_Y, shore(CRANE.x) + 3.0)
	var blue := Color("#2d6fa3")
	b.box_mm(Mats.get_mat("metal"), cb + Vector3(-1.4, 0, -1.4), cb + Vector3(1.4, 1.2, 1.4), Color("#2f3a40"))
	b.box_mm(Mats.get_mat("metal"), cb + Vector3(-0.5, 1.2, -0.5), cb + Vector3(0.5, 10.0, 0.5), blue)
	b.box_mm(Mats.get_mat("paint"), cb + Vector3(-1.2, 8.0, -0.6), cb + Vector3(1.2, 10.4, 1.6), Color("#e0a13a"))
	var boom_a := cb + Vector3(0, 10.0, 0)
	var boom_b := cb + Vector3(0, 13.0, -11.0)
	b.tube(Mats.get_mat("metal"), PackedVector3Array([boom_a, boom_b]), 0.35, 4, blue)
	b.tube(Mats.get_mat("rope"), PackedVector3Array([boom_b, boom_b + Vector3(0, -7.0, 0)]), 0.04, 4, Color("#2f3a40"))
	b.box(Mats.get_mat("metal"), Transform3D(Basis(), boom_b + Vector3(0, -7.3, 0)), Vector3(0.4, 0.6, 0.2), Color("#e0a13a"))
	_static_box("post", cb + Vector3(0, 5.2, 0), Vector3(1.4, 10.4, 1.4))
	var boom_mid := (boom_a + boom_b) * 0.5
	var bdir := (boom_b - boom_a)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("kind", "post")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = bdir.length()
	cs.shape = cap
	body.add_child(cs)
	body.transform = Transform3D(Basis(Quaternion(Vector3.UP, bdir.normalized())), boom_mid)
	add_child(body)


func _h_beach(b: MeshBuilder) -> void:
	var paint := Mats.get_mat("paint")
	var solid := Mats.get_mat("solid")
	var hut_cols := ["#e8546a", "#a9c9db", "#f2d58f", "#b9d6a8", "#f5f0e5", "#cbbbe8", "#2f6f8f"]
	var x := -134.0
	var i := 0
	while x < -74.0:
		var z := shore(x) + 19.0
		var y := _ground(x, z)
		var col := Color(hut_cols[i % hut_cols.size()])
		b.box_mm(paint, Vector3(x - 1.5, y - 0.3, z - 1.5), Vector3(x + 1.5, y + 2.4, z + 1.5), col)
		b.box_mm(solid, Vector3(x - 0.55, y, z - 1.53), Vector3(x + 0.55, y + 1.9, z - 1.49), col.darkened(0.25))
		b.gable_roof(Mats.get_mat("shingle"), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, y + 2.4, z)), 3.0, 3.0, 1.1, 0.25, 0.12, Color("#f5f0e5"))
		for sz in [-1.0, 1.0]:
			b.gable_wall(paint, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, y + 2.4, z)), 3.0, 1.1, sz * 1.5, sz, col)
		_static_box("wall", Vector3(x, y + 1.6, z), Vector3(3.2, 3.8, 3.2))
		x += 7.5
		i += 1
	# Umbrellas and towels on the sand.
	var umb_cols := ["#e8546a", "#f2a33a", "#2f6f8f", "#3f7d4f", "#f7d046"]
	for n in 16:
		var ux := rng.randf_range(-140.0, -76.0)
		var uz := shore(ux) + rng.randf_range(5.0, 13.0)
		if absf(ux - BOATHOUSE.x) < 10.0 or _near_pad(Vector3(ux, 0, uz), 6.0):
			continue
		var uy := _ground(ux, uz)
		var col := Color(umb_cols[n % umb_cols.size()])
		if n % 3 != 2:
			b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(), Vector3(ux, uy, uz)), 0.04, 0.04, 2.3, 6, Color("#e8e8e8"))
			b.cylinder(Mats.get_mat("cloth"), Transform3D(Basis(Vector3.RIGHT, rng.randf_range(-0.15, 0.15)), Vector3(ux, uy + 2.0, uz)), 1.5, 0.05, 0.55, 12, col)
			_static_cyl("post", Vector3(ux, uy, uz), 0.08, 2.3)
		var ty := rng.randf() * TAU
		b.box(Mats.get_mat("cloth"), Transform3D(Basis(Vector3.UP, ty), Vector3(ux + 1.4, uy + 0.03, uz + 0.4)), Vector3(0.9, 0.04, 1.8), Color(umb_cols[(n + 2) % umb_cols.size()]))


func _near_pad(p: Vector3, r: float) -> bool:
	for pad in _pad_keepouts:
		if Vector2(p.x - pad.x, p.z - pad.z).length() < r:
			return true
	return false


# --- Landing spots and the pets beside them -----------------------------------------------------

## [level index, "cat"/"dog", variant, position] (y from the ground when it is 0).
const HARBOUR_PETS := [
	[8, "cat", "ginger", Vector3(-85.6, 0.0, -21.6)],
	[9, "dog", "collie", Vector3(-24.2, PIER_Y, -127.0)],
	# On the fishing boat's wheelhouse roof, the sailing boat's bow and the fish crates.
	[10, "cat", "tuxedo", Vector3(-15.6, 1.65, -36.9)],
	[11, "dog", "beagle", Vector3(6.0, -0.95, -84.0)],
	[12, "cat", "grey", Vector3(21.6, 2.0, -9.03)],
	[13, "dog", "golden", Vector3(-4.8, RAFT_TOP, -62.8)],
	# Flight 7 lands on the back deck of this fishing boat; its dog waits on the wheelhouse roof.
	[14, "dog", "collie", Vector3(20.4, 1.65, -24.0)],
	[15, "cat", "ginger", Vector3(101.0, 0.0, -89.6)],
]
## Flight 8: the rock islet with the little green lighthouse.
const ISLET := Vector3(44, 0, -146)
const ISLET_TOP := Terrain.WATER_Y + 1.4
## Flight 6: the attic bedroom it starts in, and the swim raft it lands on.
const ATTIC_HOUSE := Vector3(6, 1.35, 19.78)
const RAFT := Vector3(-6, 0, -64)
const RAFT_TOP := Terrain.WATER_Y + 0.35
## Flight 6 starts from a wooden lookout at the top of the hill lane.
const LOOKOUT := Vector3(40, 0, 108)


func _h_targets() -> void:
	# The striped beach towel (flight 1's landing spot), with a bucket and spade.
	var b := MeshBuilder.new()
	var t := Vector3(-82.0, _ground(-82.0, -24.5), -24.5)
	var cloth := Mats.get_mat("cloth")
	for i in 6:
		var col := Color("#e8546a") if i % 2 == 0 else Color("#fbf8f0")
		b.box(cloth, Transform3D(Basis(Vector3.UP, 0.35), t + Basis(Vector3.UP, 0.35) * Vector3(0, 0.02, -1.75 + 0.3 + i * 0.6)), Vector3(2.4, 0.03, 0.6), col)
	b.cylinder(Mats.get_mat("solid"), Transform3D(Basis(), t + Vector3(2.0, 0, 1.4)), 0.22, 0.28, 0.4, 10, Color("#2f6f8f"))
	# The hilltop lookout: a wooden deck on posts with a low rail.
	var lk := Vector3(LOOKOUT.x, _ground(LOOKOUT.x, LOOKOUT.z), LOOKOUT.z)
	var deck_y := lk.y + 4.0
	var wood := Mats.get_mat("wood")
	b.box_mm(wood, lk + Vector3(-1.8, 3.75, -1.8), lk + Vector3(1.8, 4.0, 1.8), Color("#b08a64"))
	for px in [-1.6, 1.6]:
		for pz in [-1.6, 1.6]:
			b.box(wood, Transform3D(Basis(), lk + Vector3(px, 1.9, pz)), Vector3(0.22, 3.9, 0.22), Color("#7a5a40"))
	for side in [Vector3(0, 0, 1.75), Vector3(-1.75, 0, 0), Vector3(1.75, 0, 0)]:
		var sz := Vector3(3.6, 0.08, 0.08) if side.x == 0.0 else Vector3(0.08, 0.08, 3.6)
		b.box(wood, Transform3D(Basis(), lk + side + Vector3(0, 4.85, 0)), sz, Color("#e8dfcc"))
	_static_box("wall", lk + Vector3(0, 3.87, 0), Vector3(3.6, 0.26, 3.6))
	_static_box("post", lk + Vector3(0, 1.9, 0), Vector3(3.4, 3.8, 3.4))
	# Swim raft: a wooden pontoon on floats with a little ladder.
	var rp := Vector3(RAFT.x, RAFT_TOP, RAFT.z)
	b.box_mm(wood, rp + Vector3(-1.6, -0.18, -1.6), rp + Vector3(1.6, 0.0, 1.6), Color("#c9a27e"))
	for fx in [-1.1, 1.1]:
		for fz in [-1.1, 1.1]:
			b.cylinder(Mats.get_mat("solid"), Transform3D(Basis(), rp + Vector3(fx, -0.55, fz)), 0.35, 0.35, 0.4, 10, Color("#f6f1e6"))
	b.box(Mats.get_mat("metal"), Transform3D(Basis(), rp + Vector3(0, 0.3, 1.62)), Vector3(0.6, 0.6, 0.05), Color("#c0c6ca"))
	_static_box("wall", rp + Vector3(0, -0.4, 0), Vector3(3.2, 0.8, 3.2))
	add_child(b.build_instance("BeachTowel", false))
	# The attic bedroom flight 6 starts in (its window looks out to sea, -Z).
	var ah: Node3D = OPEN_HOUSE_SCENE.instantiate()
	ah.batcher = batcher
	ah.layout = "attic"
	ah.wall_color = Color("#a9c9db")
	ah.roof_color = Mats.ROOF_TERRACOTTA
	ah.position = ATTIC_HOUSE
	add_child(ah)
	_houses.append(ATTIC_HOUSE)
	for d in HARBOUR_PETS:
		var li: int = d[0]
		if li >= Game.levels.size():
			continue
		var pet: Node3D = (CAT_SCENE if d[1] == "cat" else DOG_SCENE).instantiate()
		pet.batcher = batcher
		pet.variant = d[2]
		var p: Vector3 = d[3]
		if p.y == 0.0:
			p.y = _ground(p.x, p.z)
		pet.position = p
		var to_pad: Vector3 = (Game.levels[li] as LevelData).pad_position - p
		pet.rotation.y = atan2(to_pad.x, to_pad.z)
		add_child(pet)


# --- Town ----------------------------------------------------------------------------------

func _h_town() -> void:
	var rows := [32.0, 56.0, 82.0]
	for r in rows.size():
		var d: float = rows[r]
		var x := -122.0 + r * 6.0
		while x < 92.0:
			var jx := x + rng.randf_range(-1.5, 1.5)
			var z := shore(jx) + d + rng.randf_range(-1.5, 1.5)
			# Keep the headland clear for the lighthouse, a gap for the lane up the hill, and no
			# house in the way of a flight.
			if (jx > 66.0 and d < 60.0) or absf(jx - 40.0) < 6.0 or _blocks_route(Vector3(jx, 0, z), _ground(jx, z) + 13.0, 6.0):
				x += 16.0
				continue
			var h: Node3D = HOUSE_SCENE.instantiate()
			h.batcher = batcher
			h.wall_color = Color(HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()])
			h.roof_color = Mats.ROOF_TERRACOTTA if rng.randf() < 0.6 else Mats.ROOF_SLATE
			h.door_color = Mats.pick(rng, Mats.DOOR_COLORS)
			h.shutter_color = Mats.pick(rng, Mats.SHUTTER_COLORS)
			h.width = rng.randf_range(8.5, 10.0)
			h.depth = 8.0
			h.storeys = 2 if rng.randf() < 0.75 else 3
			h.has_porch = rng.randf() < 0.4
			h.fence_style = "none"
			h.yard_depth = 3.0
			h.curb_distance = 4.0
			h.seed_value = 300 + r * 40 + int(x)
			h.chimney_pos = Vector2(rng.randf_range(-3.0, 3.0), -rng.randf_range(2.0, 6.0))
			# Facing the sea (-Z), standing on the ground at its front.
			h.position = Vector3(jx, _ground(jx, z) - 0.15, z)
			h.rotation.y = PI
			add_child(h)
			_houses.append(h.position)
			x += 16.0
	# A lane up the hill.
	var lane := MeshBuilder.new()
	var paving := Mats.get_mat("paving")
	var z := shore(40.0) + 16.0
	while z < shore(40.0) + 110.0:
		var z2 := z + 4.0
		lane.quad(paving, Vector3(37.5, _ground(37.5, z) + 0.04, z), Vector3(42.5, _ground(42.5, z) + 0.04, z), Vector3(42.5, _ground(42.5, z2) + 0.04, z2), Vector3(37.5, _ground(37.5, z2) + 0.04, z2), Color("#e2d9c8"))
		z = z2
	add_child(lane.build_instance("HillLane", false))


func _h_trees() -> void:
	var placed := 0
	var tries := 0
	while placed < 90 and tries < 900:
		tries += 1
		var x := rng.randf_range(-170.0, 150.0)
		var d := rng.randf_range(18.0, 170.0)
		var z := shore(x) + d
		var p := Vector3(x, _ground(x, z), z)
		var ok := true
		for hp in _houses:
			if Vector2(hp.x - x, hp.z - z).length() < 9.0:
				ok = false
				break
		if not ok or absf(x - 40.0) < 5.0 or Vector2(x - HarbourTerrain.LIGHTHOUSE.x, z - HarbourTerrain.LIGHTHOUSE.z).length() < 14.0:
			continue
		if _try_tree(p, rng.randf_range(0.8, 1.25), rng.randf() < 0.15, d > 90.0 and rng.randf() < 0.5):
			placed += 1
	# A few bushes along the top of the beach.
	for n in 40:
		var x := rng.randf_range(-150.0, -48.0)
		var z := shore(x) + rng.randf_range(15.5, 24.0)
		var s := rng.randf_range(0.8, 1.4)
		batcher.add("bush", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.8, s)), Vector3(x, _ground(x, z), z)), Mats.pick(rng, GREENS))


func _h_life() -> void:
	for p in [Vector3(-10, 22, -60), Vector3(60, 28, -40), Vector3(-90, 20, -30)]:
		var birds := BIRDS_SCENE.instantiate()
		birds.position = p
		add_child(birds)
	var air := AIR_SCENE.instantiate()
	add_child(air)


## Showreel clips flown behind the menu while the harbour is loaded: [points, start, end].
func showreel() -> Array:
	var lh := HarbourTerrain.LIGHTHOUSE
	return [
		[PackedVector3Array([Vector3(lh.x - 2, 20, lh.z - 4), Vector3(80, 14, -100), Vector3(50, 9, -118), Vector3(20, 6, -100), Vector3(0, 5, -70), Vector3(-15, 4, -40)]), 0.0, 1.0],
		[PackedVector3Array([Vector3(PIER_X - 1.0, 0.3, -20), Vector3(PIER_X, 0.2, -60), Vector3(PIER_X + 0.5, 0.25, -100), Vector3(PIER_X - 4, 3.5, -140)]), 0.0, 1.0],
		[PackedVector3Array([Vector3(BOATHOUSE.x, 3.0, BOATHOUSE.z + 30), Vector3(BOATHOUSE.x, 2.8, BOATHOUSE.z + 5), Vector3(BOATHOUSE.x, 2.6, BOATHOUSE.z - 15), Vector3(BOATHOUSE.x + 12, 3.5, BOATHOUSE.z - 40)]), 0.0, 1.0],
		[PackedVector3Array([Vector3(-30, 9, 20), Vector3(0, 7, 0), Vector3(CRANE.x - 4, 6, -14), Vector3(45, 7, -40), Vector3(60, 10, -70)]), 0.0, 1.0],
	]
