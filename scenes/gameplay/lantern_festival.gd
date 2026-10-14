extends Node3D
## Lantern Night decorations: paper lanterns floating on the river, glowing lantern posts along
## the old bridge's parapets and warm light pools around the festival on the bridge.

const RIVER_LANTERNS := 46
const BRIDGE_HALF_LEN := 24.0
## Center of the lantern raft (Lantern Night's landing target), its half size and deck height
## above the water.
const RAFT_POS := Vector3(-15.0, 0.0, -300.0)
const RAFT_HALF := 1.75
const RAFT_TOP := 0.3
const COLORS := [Color("#ff8a3d"), Color("#ffcf5a"), Color("#ff5f5f"), Color("#ffb347"), Color("#ff9ec4")]

var _floats: MultiMeshInstance3D
var _float_data: Array = []  # [x, z, phase, drift]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	glow.vertex_color_is_srgb = true
	glow.albedo_color = Color(1.4, 1.4, 1.4)

	# Lanterns floating on the river.
	var box := BoxMesh.new()
	box.size = Vector3(0.32, 0.26, 0.32)
	box.material = glow
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box
	mm.instance_count = RIVER_LANTERNS
	for i in RIVER_LANTERNS:
		var x := rng.randf_range(-60.0, 60.0)
		var z := Terrain.RIVER_Z + rng.randf_range(-8.5, 8.5)
		_float_data.append([x, z, rng.randf() * TAU, rng.randf_range(0.25, 0.6)])
		mm.set_instance_color(i, COLORS[i % COLORS.size()])
	_floats = MultiMeshInstance3D.new()
	_floats.name = "RiverLanterns"
	_floats.multimesh = mm
	_floats.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_floats.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_floats.custom_aabb = AABB(Vector3(-200, -3, Terrain.RIVER_Z - 15), Vector3(400, 6, 30))
	add_child(_floats)

	# Lantern posts along both bridge parapets.
	var b := MeshBuilder.new()
	var wood := Mats.get_mat("wood")
	var post_count := 0
	var lantern_mm := MultiMesh.new()
	lantern_mm.transform_format = MultiMesh.TRANSFORM_3D
	lantern_mm.use_colors = true
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.46
	sphere.radial_segments = 10
	sphere.rings = 5
	sphere.material = glow
	lantern_mm.mesh = sphere
	var spots: Array[Vector3] = []
	var z := -BRIDGE_HALF_LEN + 3.0
	while z < BRIDGE_HALF_LEN - 2.0:
		for sx in [-1.0, 1.0]:
			var top := _deck_top(z) + 0.9
			var base := Vector3(sx * 5.25, top, Terrain.RIVER_Z + z)
			b.cylinder(wood, Transform3D(Basis(), base), 0.05, 0.04, 1.6, 6, Color("#5a3f2e"))
			b.box(wood, Transform3D(Basis(), base + Vector3(-sx * 0.2, 1.6, 0)), Vector3(0.45, 0.05, 0.05), Color("#5a3f2e"))
			spots.append(base + Vector3(-sx * 0.38, 1.3, 0))
			post_count += 1
		z += 4.0
	lantern_mm.instance_count = spots.size()
	for i in spots.size():
		lantern_mm.set_instance_transform(i, Transform3D(Basis(), spots[i]))
		lantern_mm.set_instance_color(i, COLORS[i % COLORS.size()])
	var posts := b.build_instance("LanternPosts", false)
	add_child(posts)
	var lanterns := MultiMeshInstance3D.new()
	lanterns.name = "BridgeLanterns"
	lanterns.multimesh = lantern_mm
	lanterns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lanterns.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(lanterns)

	_build_raft(glow)

	# Warm pools of light on the bridge (desktop only, to keep phones fast).
	if not Settings.is_mobile:
		for lz in [-12.0, 0.0, 12.0]:
			var light := OmniLight3D.new()
			light.light_color = Color("#ffb066")
			light.light_energy = 1.6
			light.omni_range = 9.0
			light.position = Vector3(0, _deck_top(lz) + 2.5, Terrain.RIVER_Z + lz)
			add_child(light)


## The lantern raft moored just west of the bridge: the landing target for Lantern Night.
func _build_raft(glow: Material) -> void:
	var c := Vector3(RAFT_POS.x, Terrain.WATER_Y, RAFT_POS.z)
	var top := c.y + RAFT_TOP
	var b := MeshBuilder.new()
	var wood := Mats.get_mat("wood")
	# Logs lashed side by side, with a plank deck on top.
	for i in 7:
		var lz := lerpf(-RAFT_HALF + 0.24, RAFT_HALF - 0.24, i / 6.0)
		b.cylinder(wood, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), c + Vector3(-RAFT_HALF, top - c.y - 0.3, lz)), 0.22, 0.22, RAFT_HALF * 2.0, 8, Color("#8a6a52").darkened(0.05 * (i % 2)))
	for i in 9:
		var x0 := lerpf(-RAFT_HALF, RAFT_HALF, i / 9.0) + 0.02
		var x1 := lerpf(-RAFT_HALF, RAFT_HALF, (i + 1) / 9.0) - 0.02
		b.box_mm(wood, c + Vector3(x0, top - c.y - 0.08, -RAFT_HALF), c + Vector3(x1, top - c.y, RAFT_HALF), Color("#b48a64").darkened(0.05 * (i % 3)))
	# Two lantern poles on the far (west) side, clear of the way in.
	var spots: Array[Vector3] = []
	for pz in [-1.3, 1.3]:
		var base := Vector3(c.x - RAFT_HALF + 0.2, top, c.z + pz)
		b.cylinder(wood, Transform3D(Basis(), base), 0.05, 0.04, 1.5, 6, Color("#5a3f2e"))
		spots.append(base + Vector3(0, 1.3, 0))
	add_child(b.build_instance("LanternRaft", true))
	var lanterns := MultiMesh.new()
	lanterns.transform_format = MultiMesh.TRANSFORM_3D
	lanterns.use_colors = true
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.46
	sphere.radial_segments = 10
	sphere.rings = 5
	sphere.material = glow
	lanterns.mesh = sphere
	lanterns.instance_count = spots.size()
	for i in spots.size():
		lanterns.set_instance_transform(i, Transform3D(Basis(), spots[i]))
		lanterns.set_instance_color(i, COLORS[(i + 1) % COLORS.size()])
	var lmi := MultiMeshInstance3D.new()
	lmi.name = "RaftLanterns"
	lmi.multimesh = lanterns
	lmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lmi)
	# Colliders: the raft itself (just under the landing surface) and the poles with lanterns.
	var body := StaticBody3D.new()
	body.name = "RaftBody"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("kind", "post")
	var raft := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(RAFT_HALF * 2.0, 0.5, RAFT_HALF * 2.0)
	raft.shape = box
	raft.position = Vector3(c.x, top - 0.1 - 0.25, c.z)
	body.add_child(raft)
	for sp in spots:
		var pole := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.06
		cyl.height = 1.5
		pole.shape = cyl
		pole.position = Vector3(sp.x, top + 0.75, sp.z)
		body.add_child(pole)
		var lamp := CollisionShape3D.new()
		var ball := SphereShape3D.new()
		ball.radius = 0.2
		lamp.shape = ball
		lamp.position = sp
		body.add_child(lamp)
	add_child(body)
	# Light under the arch and over the raft so the way in can be seen at night.
	var under := OmniLight3D.new()
	under.light_color = Color("#ffb066")
	under.light_energy = 1.2
	under.omni_range = 10.0
	under.position = Vector3(0, -0.4, Terrain.RIVER_Z)
	add_child(under)
	var raft_light := OmniLight3D.new()
	raft_light.light_color = Color("#ffc27a")
	raft_light.light_energy = 1.4
	raft_light.omni_range = 7.0
	raft_light.position = c + Vector3(-1.0, 2.2, 0)
	add_child(raft_light)


## Same deck profile as the bridge prop (cosine rise of 1.5 m at the middle).
func _deck_top(z: float) -> float:
	return 0.05 + 1.5 * 0.5 * (1.0 + cos(PI * z / BRIDGE_HALF_LEN))


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var mm := _floats.multimesh
	for i in _float_data.size():
		var d: Array = _float_data[i]
		var x: float = fposmod(d[0] + t * d[3] + 70.0, 140.0) - 70.0
		var y := Terrain.WATER_Y + 0.1 + sin(t * 1.6 + d[2]) * 0.04
		var rot := Basis(Vector3.UP, d[2] + t * 0.2).rotated(Vector3.RIGHT, sin(t * 1.3 + d[2]) * 0.08)
		mm.set_instance_transform(i, Transform3D(rot, Vector3(x, y, d[1])))
