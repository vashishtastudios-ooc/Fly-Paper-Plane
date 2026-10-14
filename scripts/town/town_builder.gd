class_name TownBuilder
extends Node3D
## Builds the whole golden-hour town procedurally with a fixed RNG seed so the layout is
## identical every run: terrain, river, streets, houses, shops, park, square, bridge,
## lighting, sky, ambient life and background scenery.

signal built

const SEED := 20261013
const RIVER_Z := Terrain.RIVER_Z
const WATER_Y := Terrain.WATER_Y
const LANE_START := 14.0
const LANE_END := -276.0
const MARKET_START := -332.0
const MARKET_END := -474.0
const SQUARE_START := -478.0
const SQUARE_END := -610.0
const BOUNDS_X := Terrain.BOUNDS_X

const HOUSE_SCENE := preload("res://props/house.tscn")
const SCHOOL_SCENE := preload("res://props/school.tscn")
const OPEN_HOUSE_SCENE := preload("res://props/open_house.tscn")
const BACKPACK_SCENE := preload("res://props/backpack_mat.tscn")
const SHOP_SCENE := preload("res://props/shop.tscn")
const CIVIC_SCENE := preload("res://props/civic_building.tscn")
const TOWER_SCENE := preload("res://props/clock_tower.tscn")
const BRIDGE_SCENE := preload("res://props/bridge.tscn")
const FOUNTAIN_SCENE := preload("res://props/fountain.tscn")
const BANDSTAND_SCENE := preload("res://props/bandstand.tscn")
const JETTY_SCENE := preload("res://props/jetty.tscn")
const BLANKET_SCENE := preload("res://props/picnic_blanket.tscn")
const CAFE_SCENE := preload("res://props/cafe_table.tscn")
const CAR_SCENE := preload("res://props/car.tscn")
const HAZARD_SCENE := preload("res://scenes/gameplay/hazard_line.tscn")
const BIRDS_SCENE := preload("res://scenes/ambient/birds.tscn")
const BUTTERFLIES_SCENE := preload("res://scenes/ambient/butterflies.tscn")
const DUCKS_SCENE := preload("res://scenes/ambient/ducks.tscn")
const PEDESTRIAN_SCENE := preload("res://scenes/ambient/pedestrian.tscn")
const CYCLIST_SCENE := preload("res://scenes/ambient/cyclist.tscn")
const AIR_SCENE := preload("res://scenes/ambient/air_particles.tscn")

const SHOP_NAMES := [
	"Hartley Bakery", "Paper & Quill", "Wren Florist", "Café Lumen", "Post Office", "Bramble Books",
	"Tillman Hardware", "Copper Kettle", "Marlow Tailors", "Sweet Pea Sweets", "Pemberton Chemist",
	"Fig & Thistle", "Juniper Toys", "Lantern & Wick", "Hollis Barber", "Saffron Kitchen",
	"Willow Cycles", "Bluebird Bank", "Ollie's Ices", "Hatch & Co. Hats", "Rosemary Tea Room", "The Ink Pot",
]
const AUTUMN := ["#e8873a", "#d9662f", "#f0a541", "#c9572e"]
const GREENS := ["#6f9e4c", "#5d8f43", "#7fae55", "#4f8443", "#8ab45e"]

@export var build_on_ready := true

var rng := RandomNumberGenerator.new()
var batcher: Batcher
var trees: Array = []          # Each: {pos, top, radius, handles, body}
var hazard_lines: Array = []   # Town-owned hazard lines (market bunting)
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var _route_keepouts: Array = []  # [Vector3 a, Vector3 b] segments from every level route
var _pad_keepouts: Array = []
var _clouds: Array[MeshInstance3D] = []
var _sky_mat: ProceduralSkyMaterial
var _probe: ReflectionProbe
var _sun_glow: MeshInstance3D
var _beams: MultiMeshInstance3D
var _beam_mat: ShaderMaterial
var _grass_nodes: Array[Node] = []
## "golden" (default) or "dusk" (Lantern Night).
var time_of_day := "golden"
var is_built := false


func _ready() -> void:
	if build_on_ready:
		build()


func build() -> void:
	if is_built:
		return
	rng.seed = SEED
	_collect_keepouts()
	batcher = Batcher.new()
	batcher.name = "Instances"
	add_child(batcher)
	_environment()
	_terrain()
	_water()
	_streets()
	_lane_houses()
	_lane_details()
	_park()
	_river_and_bridge()
	_market()
	_square()
	_background()
	_clouds_build()
	_grass()
	_sun_effects()
	_ambient_life()
	# Built last so the shared random sequence (and the rest of the town) stays unchanged.
	_rowan_row()
	batcher.finalize()
	_on_quality(Settings.quality)
	is_built = true
	built.emit()


func _process(delta: float) -> void:
	if _sun_glow:
		var cam := get_viewport().get_camera_3d()
		if cam:
			_sun_glow.global_position = cam.global_position + _to_sun() * 900.0
	for c in _clouds:
		c.position.x += delta * c.get_meta("speed", 1.0)
		if c.position.x > 420.0:
			c.position.x = -420.0


# --- Terrain queries (see Terrain) ----------------------------------------------------

static func ground_height(x: float, z: float) -> float:
	return Terrain.ground_height(x, z)


# --- Level-aware helpers ----------------------------------------------------------

func _collect_keepouts() -> void:
	for lvl in Game.levels:
		var pts := lvl.route_points()
		for i in pts.size() - 1:
			_route_keepouts.append([pts[i], pts[i + 1]])
		_pad_keepouts.append(lvl.pad_position)


static func _seg_dist_2d(p: Vector3, a: Vector3, b: Vector3) -> float:
	var p2 := Vector2(p.x, p.z)
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var ab := b2 - a2
	var t := clampf((p2 - a2).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p2.distance_to(a2 + ab * t)


## True when a tall thing (top height `top`, radius `r`) at `p` would block a level route.
func _blocks_route(p: Vector3, top: float, r: float) -> bool:
	for seg in _route_keepouts:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		if _seg_dist_2d(p, a, b) < r + 3.0 and minf(a.y, b.y) < top + 2.0:
			return true
	for pad in _pad_keepouts:
		if Vector2(p.x - pad.x, p.z - pad.z).length() < r + 7.0:
			return true
	return false


## Hides trees near the first three route segments and near the pad (re-shows all others).
func clear_trees_for_level(level: LevelData) -> void:
	var pts := level.route_points()
	for t in trees:
		var hide := false
		var p: Vector3 = t.pos
		for i in mini(3, pts.size() - 1):
			if _seg_dist_2d(p, pts[i], pts[i + 1]) < 4.0 + t.radius * 0.5:
				hide = true
		if Vector2(p.x - level.pad_position.x, p.z - level.pad_position.z).length() < 7.0:
			hide = true
		_set_tree_visible(t, not hide)


func _set_tree_visible(t: Dictionary, v: bool) -> void:
	for h in t.handles:
		batcher.set_visible_instance(h, v)
	var body: StaticBody3D = t.body
	for c in body.get_children():
		(c as CollisionShape3D).disabled = not v


# --- Environment ---------------------------------------------------------------

func _environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	_sky_mat = sky_mat
	sky_mat.sky_top_color = Color("#6699dd")
	sky_mat.sky_horizon_color = Color("#f5d1ab")
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color("#b98d6a")
	sky_mat.ground_horizon_color = Color("#f5d1ab")
	sky_mat.ground_curve = 0.06
	sky_mat.sun_angle_max = 18.0
	sky_mat.sun_curve = 0.08
	sky_mat.sky_energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64 if Settings.is_mobile else Sky.RADIANCE_SIZE_128
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 1.6
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4
	env.ssao_power = 1.4
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("#f5d2ac")
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.35
	env.fog_depth_begin = 70.0
	env.fog_depth_end = 430.0
	env.fog_depth_curve = 1.3
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.0
	env.adjustment_color_correction = _storybook_lut()
	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("#ffd3a1")
	sun.light_energy = 2.1
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.light_angular_distance = 1.2
	add_child(sun)
	var to_light := Vector3(0.62, 0.36, -0.7).normalized()
	sun.look_at_from_position(Vector3.ZERO, -to_light, Vector3.UP)
	Settings.configure_environment(env, sun)


# --- Terrain and water -----------------------------------------------------------

func _terrain() -> void:
	var x0 := -230.0
	var x1 := 230.0
	var z0 := 150.0
	var z1 := -740.0
	var step := 4.0
	var nx := int((x1 - x0) / step) + 1
	var nz := int((z0 - z1) / step) + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var noise := FastNoiseLite.new()
	noise.seed = SEED
	noise.frequency = 0.02
	var grass_a := Color("#cfe0a0")
	var grass_b := Color("#f2e6a8")
	var bank := Color("#bfa77e")
	var hillc := Color("#d8d49a")
	for iz in nz:
		var z := z0 - iz * step
		for ix in nx:
			var x := x0 + ix * step
			var h := ground_height(x, z)
			verts.append(Vector3(x, h, z))
			var hx := ground_height(x + 0.5, z) - ground_height(x - 0.5, z)
			var hz := ground_height(x, z + 0.5) - ground_height(x, z - 0.5)
			normals.append(Vector3(-hx, 1.0, -hz).normalized())
			uvs.append(Vector2(x, z) * 0.25)
			var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
			var c := grass_a.lerp(grass_b, n * 0.6)
			c = c.lerp(hillc, smoothstep(50.0, 110.0, absf(x)) * 0.5)
			var d := absf(z - RIVER_Z)
			c = c.lerp(bank, (1.0 - smoothstep(9.0, 15.0, d)))
			colors.append(c)
	for iz in nz - 1:
		for ix in nx - 1:
			var a := iz * nx + ix
			var b := a + 1
			var c := a + nx
			var d := c + 1
			# Rows go toward -Z, so (a, d, b) / (a, c, d) are clockwise seen from above.
			idx.append_array([a, d, b, a, c, d])
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
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(460, 34)
	pm.subdivide_width = 8
	var mi := MeshInstance3D.new()
	mi.name = "River"
	mi.mesh = pm
	mi.material_override = Mats.get_mat("water")
	mi.position = Vector3(0, WATER_Y, RIVER_Z)
	# Captures the bridge, banks and houses once so the river can reflect them.
	_probe = ReflectionProbe.new()
	_probe.name = "RiverReflections"
	_probe.position = Vector3(0, 4.0, RIVER_Z)
	_probe.size = Vector3(330, 26, 46)
	_probe.box_projection = true
	_probe.max_distance = 320.0
	_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	_probe.intensity = 1.0
	_probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	add_child(_probe)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# --- Streets ---------------------------------------------------------------------

func _streets() -> void:
	var b := MeshBuilder.new()
	var asphalt := Mats.get_mat("asphalt")
	var paving := Mats.get_mat("paving")
	var stone := Mats.get_mat("stone")
	var cobble := Mats.get_mat("cobble")
	var solid := Mats.get_mat("solid")
	var curb := Color("#d8d0c0")
	# Linden Lane.
	b.box_mm(asphalt, Vector3(-5, -0.05, LANE_END), Vector3(5, 0.02, LANE_START), Color.WHITE, 4)
	var z := LANE_START - 3.0
	while z > LANE_END + 2.0:
		b.box_mm(solid, Vector3(-0.08, 0.02, z - 2.0), Vector3(0.08, 0.025, z), Color("#f3ecd6"), 4)
		z -= 6.0
	for sx in [-1.0, 1.0]:
		var xi: float = sx * 5.0
		var xo: float = sx * 8.0
		b.box_mm(paving, Vector3(minf(xi, xo), 0.0, LANE_END), Vector3(maxf(xi, xo), 0.15, LANE_START), Color("#efe8da"), 63 - 8)
		var xc: float = sx * 5.1
		b.box_mm(stone, Vector3(minf(xi, xc) - 0.0, -0.02, LANE_END), Vector3(maxf(xi, xc), 0.16, LANE_START), curb, 1 | 2 | 4)
	# Approach road to the bridge, and from bridge to market.
	b.box_mm(asphalt, Vector3(-5, -0.05, MARKET_START), Vector3(5, 0.02, -324.0), Color.WHITE, 4)
	for sx in [-1.0, 1.0]:
		b.box_mm(paving, Vector3(minf(sx * 5.0, sx * 9.0), 0.0, MARKET_START), Vector3(maxf(sx * 5.0, sx * 9.0), 0.15, -326.0), Color("#efe8da"), 4 | 16)
	# Market Street: cobbles with paved sidewalks.
	b.box_mm(cobble, Vector3(-5, -0.05, MARKET_END), Vector3(5, 0.02, MARKET_START), Color.WHITE, 4)
	for sx in [-1.0, 1.0]:
		var xi: float = sx * 5.0
		var xo: float = sx * 9.0
		b.box_mm(paving, Vector3(minf(xi, xo), 0.0, MARKET_END), Vector3(maxf(xi, xo), 0.15, MARKET_START), Color("#efe8da"), 63 - 8)
		b.box_mm(stone, Vector3(minf(xi, sx * 5.1), -0.02, MARKET_END), Vector3(maxf(xi, sx * 5.1), 0.16, MARKET_START), curb, 1 | 2 | 4)
	# Town Square plaza.
	b.box_mm(cobble, Vector3(-42, -0.05, SQUARE_END - 4.0), Vector3(42, 0.03, MARKET_END), Color(1.02, 1.0, 0.97), 4)
	b.box_mm(paving, Vector3(-30, 0.03, -538), Vector3(4, 0.045, -526), Color("#f2ead8"), 4)
	for i in 4:
		var r := 6.0 + i * 0.01
		b.cylinder(paving, Transform3D(Basis(), Vector3(-13, 0.03, -532)), r, r, 0.02, 24, Color("#e9dfcb"), true)
	var mi := b.build_instance("Streets", false)
	add_child(mi)


# --- Linden Lane houses ------------------------------------------------------------

func _house_slots() -> Array:
	var slots := []
	for k in 9:
		var zl := -10.0 - 32.0 * k
		if zl < -96.0 + 6.0 and zl > -188.0 - 6.0:
			continue
		slots.append({"side": -1.0, "z": zl})
	for k in 9:
		slots.append({"side": 1.0, "z": 2.0 - 32.0 * k})
	return slots


func _lane_houses() -> void:
	var balconies := []
	for lvl in Game.levels:
		if lvl.platform_kind == "balcony":
			balconies.append(lvl.platform_position)
	var i := 0
	for slot in _house_slots():
		var side: float = slot.side
		var hz: float = slot.z
		var h: Node3D = HOUSE_SCENE.instantiate()
		h.batcher = batcher
		h.name = "House_%s_%d" % ["L" if side < 0 else "R", int(-hz)]
		h.wall_color = Color(Mats.PALETTE_HOUSES[i % Mats.PALETTE_HOUSES.size()])
		h.roof_color = Mats.ROOF_SLATE if rng.randf() < 0.55 else Mats.ROOF_TERRACOTTA
		h.door_color = Mats.pick(rng, Mats.DOOR_COLORS)
		h.shutter_color = Mats.pick(rng, Mats.SHUTTER_COLORS)
		h.width = 10.0
		h.depth = 9.0
		h.seed_value = i + 3
		h.fence_style = "picket" if rng.randf() < 0.68 else "hedge"
		h.yard_depth = 9.0
		h.curb_distance = 12.0
		# Porches sit toward +Z in world so the throw paths stay clear.
		h.porch_offset = 2.6 if side > 0 else -2.6
		h.chimney_pos = Vector2(rng.randf_range(-3.5, 3.5), -rng.randf_range(2.5, 6.5))
		# The chimney whose smoke makes the rising air in level 1.
		if side < 0 and is_equal_approx(hz, -74.0):
			h.chimney_pos = Vector2(4.0, -4.0)
		for bp in balconies:
			if signf(bp.x) == side and absf(bp.z - hz) < 6.0:
				h.balcony_height = bp.y
				h.balcony_offset = (bp.z - hz) if side > 0 else -(bp.z - hz)
				# A corner balcony: shrink the house so the balcony is flush with its end wall,
				# which keeps the throw line clear of the house corner.
				if absf(h.balcony_offset) > 2.0:
					h.width = 2.0 * (absf(h.balcony_offset) + 1.4)
					h.porch_offset = signf(h.porch_offset) * minf(2.6, h.width * 0.5 - 2.4)
		h.position = Vector3(side * 17.0, 0, hz)
		h.rotation.y = -PI * 0.5 if side > 0 else PI * 0.5
		add_child(h)
		i += 1
	# Linden Primary School at the north end of the lane, its yard opening onto the street.
	var school: Node3D = SCHOOL_SCENE.instantiate()
	school.batcher = batcher
	school.position = Vector3(0, 0, 48.0)
	add_child(school)
	# The friend waits at the bus stop down the lane with an open backpack (classroom level target).
	var mat: Node3D = BACKPACK_SCENE.instantiate()
	mat.batcher = batcher
	mat.position = Vector3(12.5, 0.0, -78.0)
	mat.rotation.y = 0.2
	add_child(mat)
	_bus_stop(Vector3(7.0, 0.15, -83.0))


## Small bus shelter on the sidewalk, facing the lane (-X).
func _bus_stop(p: Vector3) -> void:
	var b := MeshBuilder.new()
	var metal := Mats.get_mat("metal")
	var green := Color("#2f5560")
	for dz in [-1.6, 1.6]:
		for dx in [-0.55, 0.55]:
			b.cylinder(metal, Transform3D(Basis(), p + Vector3(dx, 0, dz)), 0.05, 0.05, 2.4, 6, green)
	b.box_mm(metal, p + Vector3(-0.8, 2.4, -1.8), p + Vector3(0.8, 2.52, 1.8), green)
	b.box_mm(Mats.get_mat("glass"), p + Vector3(0.5, 0.3, -1.6), p + Vector3(0.56, 2.3, 1.6), Color("#a9c9db"))
	b.box_mm(Mats.get_mat("wood"), p + Vector3(0.0, 0.45, -1.2), p + Vector3(0.45, 0.5, 1.2), Color("#b07a4f"))
	b.cylinder(metal, Transform3D(Basis(), p + Vector3(-0.9, 0, 2.2)), 0.04, 0.04, 2.6, 6, Color("#9aa3a8"))
	b.cylinder(metal, Transform3D(Basis(Vector3.BACK, PI * 0.5), p + Vector3(-0.88, 2.55, 2.2)), 0.28, 0.28, 0.04, 16, Color("#e8b03a"), true)
	add_child(b.build_instance("BusStop", true))
	var sign_label := Label3D.new()
	sign_label.text = "BUS"
	sign_label.font = UIKit.ui_font()
	sign_label.font_size = 64
	sign_label.pixel_size = 0.005
	sign_label.modulate = Color("#24324f")
	sign_label.position = p + Vector3(-0.93, 2.55, 2.2)
	sign_label.rotation.y = -PI * 0.5
	add_child(sign_label)
	_static_box("wall", p + Vector3(0, 1.26, 0), Vector3(1.6, 2.52, 3.6))
	_static_cyl("post", p + Vector3(-0.9, 0, 2.2), 0.3, 2.85)


func _add_tree(p: Vector3, scale: float, autumn := false, conifer := false, collide := true) -> void:
	var trunk_h := 2.0 * scale
	var r := 2.2 * scale
	var col := Mats.pick(rng, AUTUMN) if autumn else Mats.pick(rng, GREENS)
	var handles := []
	handles.append(batcher.add("trunk", Transform3D(Basis().scaled(Vector3(scale, trunk_h + r * 0.6, scale)), p), Color.WHITE))
	var cc := p + Vector3(0, trunk_h + r * 0.75, 0)
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r, r * (1.25 if conifer else 1.0), r))
	handles.append(batcher.add("conifer" if conifer else "canopy", Transform3D(basis, cc), col))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("kind", "tree")
	body.position = p
	var trunk_cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.2 * scale
	cyl.height = trunk_h
	trunk_cs.shape = cyl
	trunk_cs.position = Vector3(0, trunk_h * 0.5, 0)
	body.add_child(trunk_cs)
	var can_cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = r * 0.85
	can_cs.shape = sph
	can_cs.position = cc - p
	body.add_child(can_cs)
	if collide:
		add_child(body)
		trees.append({"pos": p, "top": cc.y + r, "radius": r, "handles": handles, "body": body})
	else:
		body.free()


func _try_tree(p: Vector3, scale: float, autumn := false, conifer := false) -> bool:
	var r := 2.2 * scale
	var top := 2.0 * scale + r * 1.75
	if _blocks_route(p, top, r):
		return false
	_add_tree(p, scale, autumn, conifer)
	return true


func _lane_details() -> void:
	# Street trees along both sidewalks, avoiding mailboxes and doors.
	var z := LANE_START - 8.0
	while z > LANE_END + 6.0:
		for sx in [-1.0, 1.0]:
			if sx < 0 and z < -96.0 and z > -188.0:
				continue
			var jitter := rng.randf_range(-1.5, 1.5)
			if rng.randf() < 0.85:
				_try_tree(Vector3(sx * 6.9, 0.15, z + jitter), rng.randf_range(0.85, 1.1), rng.randf() < 0.3)
		z -= 16.0
	# Lamps.
	z = LANE_START - 2.0
	var k := 0
	while z > LANE_END + 2.0:
		var sx := -1.0 if k % 2 == 0 else 1.0
		var p := Vector3(sx * 7.6, 0.15, z)
		batcher.add("lamp", Transform3D(Basis(), p))
		_static_cyl("post", p, 0.15, 3.9)
		z -= 16.0
		k += 1
	# Front-yard and back-yard trees.
	for slot in _house_slots():
		var side: float = slot.side
		var hz: float = slot.z
		if rng.randf() < 0.55:
			_try_tree(Vector3(side * rng.randf_range(11.0, 13.5), 0, hz + rng.randf_range(-6.0, 6.0)), rng.randf_range(0.8, 1.05), rng.randf() < 0.3)
		for n in 2:
			_try_tree(Vector3(side * rng.randf_range(29.0, 40.0), 0, hz + rng.randf_range(-12.0, 12.0)), rng.randf_range(0.9, 1.3), rng.randf() < 0.3, rng.randf() < 0.15)
	# Parked cars along the curb.
	var car_z := [-20.0, -48.0, -86.0, -140.0, -176.0, -212.0, 4.0]
	var car_cols := ["#a9c9db", "#e9b7a1", "#f2d58f", "#b9d6a8", "#cbbbe8", "#c8423b", "#f5f0e5"]
	for i in car_z.size():
		var c: Node3D = CAR_SCENE.instantiate()
		c.batcher = batcher
		c.body_color = Color(car_cols[i % car_cols.size()])
		var sx := 1.0 if i % 2 == 0 else -1.0
		c.position = Vector3(sx * 3.9, 0.02, car_z[i])
		c.rotation.y = 0.0 if sx > 0 else PI
		add_child(c)


func _static_cyl(kind: String, base: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("kind", kind)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	cs.shape = cyl
	body.position = base + Vector3(0, height * 0.5, 0)
	body.add_child(cs)
	add_child(body)


func _static_box(kind: String, center: Vector3, size: Vector3, yaw := 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("kind", kind)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.position = center
	body.rotation.y = yaw
	body.add_child(cs)
	add_child(body)


# --- Park --------------------------------------------------------------------------

func _park() -> void:
	var b := MeshBuilder.new()
	var gravel := Mats.get_mat("gravel")
	var path := Curve3D.new()
	for p in [Vector3(-7.5, 0, -112), Vector3(-14, 0, -117), Vector3(-19, 0, -128), Vector3(-22, 0, -137),
			Vector3(-27, 0, -146.5), Vector3(-33, 0, -150), Vector3(-30, 0, -162), Vector3(-21, 0, -168),
			Vector3(-16, 0, -178), Vector3(-7.5, 0, -184)]:
		path.add_point(p)
	_smooth_curve(path)
	var pts := path.tessellate_even_length(5, 1.5)
	_ribbon(b, gravel, pts, 2.2, 0.035, Color("#efe2c4"))
	# Branch path to the picnic lawn.
	var branch := Curve3D.new()
	for p in [Vector3(-19, 0, -128), Vector3(-25, 0, -127.5)]:
		branch.add_point(p)
	_ribbon(b, gravel, branch.tessellate_even_length(5, 1.0), 1.6, 0.036, Color("#efe2c4"))
	# Flower beds with soil rims.
	var beds := [Vector3(-16, 0, -140), Vector3(-34, 0, -136), Vector3(-36, 0, -170), Vector3(-15, 0, -160), Vector3(-24, 0, -184)]
	for bed in beds:
		var r := rng.randf_range(1.6, 2.4)
		b.cylinder(Mats.get_mat("solid"), Transform3D(Basis(), bed), r, r * 0.95, 0.18, 14, Color("#7a5236"))
		b.cylinder(Mats.get_mat("stone"), Transform3D(Basis(), bed), r + 0.2, r + 0.2, 0.12, 14, Color("#e6dccb"))
		for i in 40:
			var a := rng.randf() * TAU
			var rr := sqrt(rng.randf()) * (r - 0.15)
			batcher.add("flower", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.2, 1.8)), bed + Vector3(cos(a) * rr, 0.15, sin(a) * rr)), Mats.pick(rng, Mats.FLOWER_COLORS))
	add_child(b.build_instance("ParkGround", false))
	# Park boundary hedge along the sidewalk with entrances.
	for seg in [[-188.0, -186.0], [-182.0, -116.0], [-110.0, -96.0]]:
		var z0: float = seg[0]
		var z1: float = seg[1]
		var l := z1 - z0
		if l <= 0.5:
			continue
		var c := Vector3(-8.8, 0, (z0 + z1) * 0.5)
		batcher.add("hedge", Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3(l, 0.9, 0.9)), c), Color("#4f7f3f"))
		_static_box("fence", c + Vector3(0, 0.45, 0), Vector3(0.8, 0.9, l))
	# Bandstand, picnic blanket and benches.
	var band: Node3D = BANDSTAND_SCENE.instantiate()
	band.batcher = batcher
	band.position = Vector3(-27, 0, -142)
	band.rotation.y = 0.6
	add_child(band)
	var blanket: Node3D = BLANKET_SCENE.instantiate()
	blanket.batcher = batcher
	blanket.position = Vector3(-30, 0, -128)
	blanket.rotation.y = 0.25
	add_child(blanket)
	var benches := [[Vector3(-12.5, 0, -121), 2.1], [Vector3(-23.5, 0, -133), 1.6], [Vector3(-34, 0, -155), 0.2],
		[Vector3(-26, 0, -165), 3.0], [Vector3(-13, 0, -178), 2.5], [Vector3(-33, 0, -126), -1.4]]
	for bdat in benches:
		var p: Vector3 = bdat[0]
		var yaw: float = bdat[1]
		batcher.add("bench", Transform3D(Basis(Vector3.UP, yaw), p))
		_static_box("post", p + Vector3(0, 0.5, 0), Vector3(1.8, 1.0, 0.6), yaw)
	# Lamps along the path.
	for i in range(0, pts.size(), 9):
		var lp: Vector3 = pts[i] + Vector3(1.6, 0, 0)
		batcher.add("lamp", Transform3D(Basis(), lp))
		_static_cyl("post", lp, 0.15, 3.9)
	# Park trees, many in autumn colors.
	var placed := 0
	var tries := 0
	while placed < 26 and tries < 400:
		tries += 1
		var p := Vector3(rng.randf_range(-39.0, -11.0), 0, rng.randf_range(-187.0, -97.0))
		if p.distance_to(Vector3(-27, 0, -142)) < 8.0 or p.distance_to(Vector3(-30, 0, -128)) < 7.0:
			continue
		var near_path := false
		for q in pts:
			if Vector2(p.x - q.x, p.z - q.z).length() < 3.5:
				near_path = true
				break
		if near_path:
			continue
		var too_close := false
		for t in trees:
			if Vector2(p.x - t.pos.x, p.z - t.pos.z).length() < 5.5:
				too_close = true
				break
		if too_close:
			continue
		if _try_tree(p, rng.randf_range(0.95, 1.45), rng.randf() < 0.45, rng.randf() < 0.1):
			placed += 1
	# Bushes scattered around.
	for i in 30:
		var p := Vector3(rng.randf_range(-39.0, -11.0), 0, rng.randf_range(-187.0, -97.0))
		var s := rng.randf_range(0.7, 1.3)
		batcher.add("bush", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p), Mats.pick(rng, GREENS))


func _smooth_curve(c: Curve3D) -> void:
	var n := c.point_count
	for i in n:
		var prev := c.get_point_position(maxi(i - 1, 0))
		var next := c.get_point_position(mini(i + 1, n - 1))
		var t := (next - prev) / 6.0
		c.set_point_in(i, -t)
		c.set_point_out(i, t)


func _ribbon(b: MeshBuilder, mat: Material, pts: PackedVector3Array, width: float, y: float, col: Color) -> void:
	for i in pts.size() - 1:
		var a := pts[i]
		var c := pts[i + 1]
		var dir := (c - a).normalized()
		var side := Vector3(-dir.z, 0, dir.x) * width * 0.5
		var a0 := a - side
		var a1 := a + side
		var c0 := c - side
		var c1 := c + side
		a0.y = y
		a1.y = y
		c0.y = y
		c1.y = y
		var q := PackedVector3Array([a0, a1, c1, c0])
		var n := (q[1] - q[0]).cross(q[2] - q[0])
		if n.y < 0.0:
			q.reverse()
		b.poly(mat, q, col)


# --- River, bridge, jetty ------------------------------------------------------------

func _river_and_bridge() -> void:
	var bridge: Node3D = BRIDGE_SCENE.instantiate()
	bridge.batcher = batcher
	bridge.position = Vector3(0, 0, RIVER_Z)
	add_child(bridge)
	var jetty: Node3D = JETTY_SCENE.instantiate()
	jetty.batcher = batcher
	jetty.position = Vector3(25.75, -0.62, -309.5)
	add_child(jetty)
	# Reeds and rocks along both waterlines.
	for side in [-1.0, 1.0]:
		var x := -150.0
		while x < 150.0:
			x += rng.randf_range(2.0, 5.0)
			if absf(x) < 7.0:
				continue
			if side > 0.0 and x > 21.0 and x < 31.0:
				continue
			var zl: float = RIVER_Z + side * rng.randf_range(10.4, 12.0)
			var y := ground_height(x, zl)
			var s := rng.randf_range(0.8, 1.3)
			batcher.add("reed", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, maxf(y, WATER_Y - 0.1), zl)), Color("#7d9a4a").lerp(Color("#a3a85a"), rng.randf()))
			if rng.randf() < 0.3:
				var rz: float = RIVER_Z + side * rng.randf_range(11.0, 13.0)
				var rs := rng.randf_range(0.6, 1.4)
				batcher.add("rock", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rs, rs * 0.8, rs)), Vector3(x, ground_height(x, rz) - 0.15, rz)), Color("#c9c2b4"))
	# Trees on the banks.
	for i in 24:
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(rng.randf_range(-70.0, 70.0), 0, RIVER_Z + side * rng.randf_range(17.0, 26.0))
		if absf(p.x) < 9.0:
			continue
		p.y = ground_height(p.x, p.z)
		_try_tree(p, rng.randf_range(1.0, 1.4), rng.randf() < 0.35)


# --- Market Street ---------------------------------------------------------------------

func _market() -> void:
	var name_i := 0
	var palette := Mats.PALETTE_HOUSES
	var fronts := ["#2f5560", "#7a2f3b", "#3f5d3a", "#2d4f7c", "#6b4a32", "#4f3f6b"]
	var awnings := [["#c8423b", "#f7eedd"], ["#2f6f8f", "#f7eedd"], ["#3f7d4f", "#f7eedd"], ["#e0a13a", "#fbf3dc"], ["#7c4f9e", "#f7eedd"], ["#d9675a", "#fbf3dc"]]
	for side in [1.0, -1.0]:
		for k in 11:
			var zc: float = (-340.0 if side > 0 else -338.0) - 12.0 * k
			var s: Node3D = SHOP_SCENE.instantiate()
			s.batcher = batcher
			s.width = 11.0
			s.depth = 10.0
			s.storeys = 2 if (side > 0 and k == 0) else (3 if rng.randf() < 0.45 else 2)
			s.wall_kind = ["plaster", "brick", "paint"][rng.randi() % 3]
			s.wall_color = Color(palette[rng.randi() % palette.size()])
			s.front_color = Color(fronts[rng.randi() % fronts.size()])
			var aw: Array = awnings[rng.randi() % awnings.size()]
			s.awning_a = Color(aw[0])
			s.awning_b = Color(aw[1])
			s.sign_text = SHOP_NAMES[name_i % SHOP_NAMES.size()]
			s.shutter_color = Mats.pick(rng, Mats.SHUTTER_COLORS)
			s.seed_value = name_i + 11
			name_i += 1
			s.position = Vector3(side * 9.0, 0.15, zc)
			s.rotation.y = -PI * 0.5 if side > 0 else PI * 0.5
			add_child(s)
	# Bunting strung across the street every 24 m (town hazard).
	var z := -360.0
	while z > MARKET_END + 4.0:
		var line: Node3D = HAZARD_SCENE.instantiate()
		line.a = Vector3(-9.0, 6.6, z)
		line.b = Vector3(9.0, 6.6, z)
		line.sag = 0.8
		line.kind = "bunting"
		line.with_posts = false
		line.seed_value = int(-z)
		add_child(line)
		hazard_lines.append(line)
		z -= 24.0
	# Lamps and planters along the sidewalks.
	z = MARKET_START - 6.0
	while z > MARKET_END + 4.0:
		for sx in [-1.0, 1.0]:
			var p := Vector3(sx * 5.6, 0.15, z)
			batcher.add("lamp", Transform3D(Basis(), p))
			_static_cyl("post", p, 0.15, 3.9)
		z -= 20.0
	# Two parked cars.
	for c_dat in [[Vector3(3.9, 0.02, -420), "#cbbbe8", 0.0], [Vector3(-3.9, 0.02, -446), "#f2d58f", PI]]:
		var c: Node3D = CAR_SCENE.instantiate()
		c.batcher = batcher
		c.body_color = Color(c_dat[1])
		c.position = c_dat[0]
		c.rotation.y = c_dat[2]
		add_child(c)


# --- Rowan Row ---------------------------------------------------------------------------

## A row of houses with their windows thrown open, behind the east side of Market Street
## (flight 6), and the gardens between them.
func _rowan_row() -> void:
	var houses := [
		["attic", Vector3(31, 0, -345.5), 11.0, 9.0, "#f2d58f", Mats.ROOF_TERRACOTTA, "#2f6f8f"],
		["bedroom", Vector3(29, 0, -367), 11.0, 10.0, "#a9c9db", Mats.ROOF_SLATE, "#c8423b"],
		["stairwell", Vector3(32, 0, -389), 11.0, 14.0, "#e6c3da", Mats.ROOF_TERRACOTTA, "#3f7d4f"],
		["greenhouse", Vector3(31.5, 0, -402), 4.2, 6.0, "#f4f0e6", Mats.ROOF_SLATE, "#3f7d4f"],
		["cottage", Vector3(31, 0, -414.5), 11.0, 13.0, "#b9d6a8", Mats.ROOF_SLATE, "#e0a13a"],
	]
	for i in houses.size():
		var d: Array = houses[i]
		var h: Node3D = OPEN_HOUSE_SCENE.instantiate()
		h.batcher = batcher
		h.name = "RowanRow_%d" % (i + 1)
		h.layout = d[0]
		h.position = d[1]
		h.width = d[2]
		h.depth = d[3]
		h.wall_color = Color(d[4])
		h.roof_color = d[5]
		h.door_color = Color(d[6])
		h.shutter_color = Color(Mats.SHUTTER_COLORS[(i * 2 + 1) % Mats.SHUTTER_COLORS.size()])
		h.seed_value = 70 + i
		add_child(h)

	var b := MeshBuilder.new()
	var solid := Mats.get_mat("solid")
	var paving := Mats.get_mat("paving")
	var wood := Mats.get_mat("wood")
	var metal := Mats.get_mat("metal")
	var r := RandomNumberGenerator.new()
	r.seed = 4417
	# Picket fences down both sides and across the far end.
	var z0 := -337.0
	var z1 := -425.0
	for fx in [22.5, 40.0]:
		var z := z0
		while z > z1:
			batcher.add("picket", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(fx, 0, z)))
			z -= 0.17
		for ry in [0.3, 0.7]:
			b.box_mm(solid, Vector3(fx - 0.03, ry, z1), Vector3(fx + 0.03, ry + 0.08, z0), Mats.TRIM)
		_static_box("fence", Vector3(fx, 0.5, (z0 + z1) * 0.5), Vector3(0.2, 1.0, z0 - z1))
	var x := 22.6
	while x < 40.0:
		batcher.add("picket", Transform3D(Basis(), Vector3(x, 0, z1)))
		x += 0.17
	_static_box("fence", Vector3(31.25, 0.5, z1), Vector3(17.5, 1.0, 0.2))
	# Gardens: stepping stones, flower borders and bushes.
	var gardens := [[-337.5, -341.0], [-350.0, -362.0], [-372.0, -382.0], [-396.0, -408.0], [-421.0, -424.5]]
	for g in gardens:
		var ga: float = g[0]
		var gb: float = g[1]
		var z := ga - 0.6
		while z > gb + 0.4:
			var sx := 30.6 + sin(z * 0.7) * 0.3 + r.randf_range(-0.1, 0.1)
			b.cylinder(paving, Transform3D(Basis(), Vector3(sx, 0.0, z)), 0.32, 0.32, 0.04, 10, Color("#e8e1d3"))
			z -= 0.85
		for side in [[22.8, 23.4], [38.6, 39.7]]:
			for k in int((ga - gb) * 3.0):
				var p := Vector3(r.randf_range(side[0], side[1]), 0, r.randf_range(gb + 0.3, ga - 0.3))
				batcher.add("flower", Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * r.randf_range(1.1, 1.6)), p), Mats.pick(r, Mats.FLOWER_COLORS))
			var s := r.randf_range(0.8, 1.15)
			batcher.add("bush", Transform3D(Basis().scaled(Vector3(s, s * 0.9, s)), Vector3((side[0] + side[1]) * 0.5, 0, gb + 1.2)), Color("#5f8f45").lerp(Color("#7aa65a"), r.randf()))
	for t in [[Vector3(25.0, 0, -355.5), 0.85], [Vector3(38.3, 0, -372.0), 0.9], [Vector3(25.2, 0, -403.0), 0.8], [Vector3(38.2, 0, -401.0), 0.85]]:
		_try_tree(t[0], t[1], true)
	# Trampoline in the first garden.
	var tp := Vector3(35.0, 0, -356.0)
	for k in 6:
		var a := TAU * k / 6.0
		b.tube(metal, PackedVector3Array([tp + Vector3(cos(a) * 1.35, 0, sin(a) * 1.35), tp + Vector3(cos(a) * 1.35, 0.75, sin(a) * 1.35)]), 0.04, 5, Color("#5b6270"))
	b.cylinder(solid, Transform3D(Basis(), tp + Vector3(0, 0.72, 0)), 1.45, 1.45, 0.08, 20, Color("#2f6f8f"))
	b.cylinder(solid, Transform3D(Basis(), tp + Vector3(0, 0.73, 0)), 1.15, 1.15, 0.08, 20, Color("#2a2522"))
	_static_cyl("fence", tp, 1.45, 0.8)
	# Sun-warmed patio with a table, chairs and a parasol (the rising air in the second garden).
	b.box_mm(paving, Vector3(28.0, 0.0, -380.0), Vector3(34.0, 0.05, -375.0), Color("#efe2c4"), 4)
	var tc := Vector3(35.6, 0, -379.4)
	b.cylinder(metal, Transform3D(Basis(), tc), 0.04, 0.04, 0.72, 6, Color("#3a3a3a"))
	b.cylinder(solid, Transform3D(Basis(), tc + Vector3(0, 0.72, 0)), 0.55, 0.55, 0.04, 14, Color("#fbf8f0"))
	b.cylinder(metal, Transform3D(Basis(), tc), 0.025, 0.025, 2.3, 5, Color("#d8d8d8"))
	b.cylinder(Mats.get_mat("cloth"), Transform3D(Basis(), tc + Vector3(0, 1.9, 0)), 1.3, 0.05, 0.45, 12, Color("#e8546a"))
	for a in [0.4, 2.6]:
		var cp := tc + Vector3(cos(a) * 0.9, 0, sin(a) * 0.9)
		b.box_mm(solid, cp + Vector3(-0.2, 0.42, -0.2), cp + Vector3(0.2, 0.46, 0.2), Color("#fbf8f0"))
		b.box_mm(solid, cp + Vector3(-0.2, 0.0, -0.2), cp + Vector3(-0.17, 0.42, 0.2), Color("#fbf8f0"))
		b.box_mm(solid, cp + Vector3(0.17, 0.0, -0.2), cp + Vector3(0.2, 0.42, 0.2), Color("#fbf8f0"))
	_static_cyl("post", tc, 0.6, 2.4)
	# Third garden: vegetable bed, wheelbarrow, a gnome and a bird bath.
	b.box_mm(wood, Vector3(23.6, 0, -407.2), Vector3(26.4, 0.3, -405.2), Color("#8a6a52"))
	b.box_mm(solid, Vector3(23.7, 0.3, -407.1), Vector3(26.3, 0.33, -405.3), Color("#6b4a32"))
	for k in 8:
		b.sphere(Mats.get_mat("foliage"), Vector3(23.95 + (k % 4) * 0.65, 0.45, -406.7 + (k / 4) * 0.95), Vector3(0.22, 0.16, 0.22), 3, 6, Color("#6f9e4c"))
	var gn := Vector3(28.2, 0, -398.2)
	b.cylinder(solid, Transform3D(Basis(), gn), 0.11, 0.12, 0.22, 8, Color("#2f6f8f"))
	b.sphere(solid, gn + Vector3(0, 0.3, 0), Vector3(0.09, 0.09, 0.09), 3, 6, Color("#f1c9a5"))
	b.sphere(solid, gn + Vector3(0, 0.26, -0.05), Vector3(0.08, 0.07, 0.05), 3, 6, Color("#fbf8f0"))
	b.cylinder(solid, Transform3D(Basis(), gn + Vector3(0, 0.36, 0)), 0.1, 0.0, 0.26, 8, Color("#c8423b"))
	var bb := Vector3(37.6, 0, -398.0)
	b.cylinder(Mats.get_mat("stone"), Transform3D(Basis(), bb), 0.15, 0.1, 0.8, 10, Color("#d6cdbd"))
	b.cylinder(Mats.get_mat("stone"), Transform3D(Basis(), bb + Vector3(0, 0.8, 0)), 0.2, 0.45, 0.15, 14, Color("#d6cdbd"))
	b.cylinder(Mats.get_mat("glass"), Transform3D(Basis(), bb + Vector3(0, 0.9, 0)), 0.38, 0.38, 0.03, 14, Color("#9cc3dd"))
	_static_cyl("post", bb, 0.45, 1.0)
	var wb := Vector3(26.8, 0, -400.0)
	b.box(Mats.get_mat("metal"), Transform3D(Basis(Vector3.RIGHT, 0.2), wb + Vector3(0, 0.45, 0)), Vector3(0.6, 0.3, 0.9), Color("#3f7d4f"))
	b.cylinder(solid, Transform3D(Basis(Vector3.BACK, PI * 0.5), wb + Vector3(0.05, 0.18, -0.5)), 0.17, 0.17, 0.1, 10, Color("#2a2522"))
	for s in [-1.0, 1.0]:
		b.tube(wood, PackedVector3Array([wb + Vector3(s * 0.25, 0.35, -0.3), wb + Vector3(s * 0.3, 0.5, 0.85)]), 0.025, 4, Color("#8a6a52"))
	add_child(b.build_instance("RowanRowGardens", true))
	var sign_post := Vector3(23.4, 0, -338.3)
	_static_cyl("post", sign_post, 0.1, 1.9)
	var sb := MeshBuilder.new()
	sb.cylinder(wood, Transform3D(Basis(), sign_post), 0.06, 0.06, 1.9, 6, Color("#8a6a52"))
	sb.box_mm(wood, sign_post + Vector3(-0.05, 1.35, -0.7), sign_post + Vector3(0.05, 1.8, 0.7), Color("#c9a27e"))
	add_child(sb.build_instance("RowanRowSign", true))
	var label := Label3D.new()
	label.text = "Rowan Row"
	label.font = UIKit.display_font()
	label.font_size = 72
	label.pixel_size = 0.006
	label.modulate = Color("#3a2c28")
	label.outline_size = 0
	label.shaded = false
	label.position = sign_post + Vector3(-0.06, 1.58, 0)
	label.rotation.y = -PI * 0.5
	add_child(label)


# --- Town Square ------------------------------------------------------------------------

func _square() -> void:
	var lib: Node3D = CIVIC_SCENE.instantiate()
	lib.batcher = batcher
	lib.style = "library"
	lib.width = 22.0
	lib.depth = 14.0
	lib.sign_text = "Public Library"
	lib.position = Vector3(-24, 0.03, -505)
	lib.rotation.y = PI * 0.5
	add_child(lib)
	var hall: Node3D = CIVIC_SCENE.instantiate()
	hall.batcher = batcher
	hall.style = "market_hall"
	hall.width = 26.0
	hall.depth = 16.0
	hall.sign_text = "Market Hall"
	hall.position = Vector3(24, 0.03, -520)
	hall.rotation.y = -PI * 0.5
	add_child(hall)
	var hotel: Node3D = CIVIC_SCENE.instantiate()
	hotel.batcher = batcher
	hotel.style = "hotel"
	hotel.width = 18.0
	hotel.depth = 12.0
	hotel.wall_color = Color("#e6c3da")
	hotel.sign_text = "Hotel Mirabel"
	hotel.position = Vector3(-24, 0.03, -566)
	hotel.rotation.y = PI * 0.5
	add_child(hotel)
	# Extra shops around the square.
	var extra := [[Vector3(24, 0.03, -556), -PI * 0.5, "Town Gazette", "#a9c9db"], [Vector3(24, 0.03, -572), -PI * 0.5, "Lark Music", "#f2d58f"],
		[Vector3(24, 0.03, -490), -PI * 0.5, "Cobble & Crumb", "#b9d6a8"], [Vector3(-24, 0.03, -486), PI * 0.5, "Meadow Gallery", "#f5f0e5"],
		[Vector3(-24, 0.03, -584), PI * 0.5, "Bell & Book", "#e9b7a1"], [Vector3(24, 0.03, -588), -PI * 0.5, "Harbour Maps", "#cbbbe8"]]
	for e in extra:
		var s: Node3D = SHOP_SCENE.instantiate()
		s.batcher = batcher
		s.width = 12.0
		s.storeys = 3
		s.wall_color = Color(e[3])
		s.sign_text = e[2]
		s.seed_value = int(absf(e[0].z))
		s.position = e[0]
		s.rotation.y = e[1]
		add_child(s)
	var tower: Node3D = TOWER_SCENE.instantiate()
	tower.batcher = batcher
	tower.position = Vector3(0, 0.0, -603)
	add_child(tower)
	var fountain: Node3D = FOUNTAIN_SCENE.instantiate()
	fountain.batcher = batcher
	fountain.position = Vector3(-13, 0.03, -532)
	add_child(fountain)
	var umb := [["#2f6f8f", "#f7eedd"], ["#c8423b", "#f7eedd"], ["#3f7d4f", "#fbf3dc"]]
	var tables := [Vector3(11, 0.03, -536), Vector3(16, 0.03, -542), Vector3(10.5, 0.03, -548), Vector3(16.5, 0.03, -554), Vector3(11.5, 0.03, -561), Vector3(17, 0.03, -566)]
	for i in tables.size():
		var t: Node3D = CAFE_SCENE.instantiate()
		t.batcher = batcher
		t.umbrella_a = Color(umb[i % 3][0])
		t.umbrella_b = Color(umb[i % 3][1])
		t.position = tables[i]
		t.rotation.y = rng.randf() * TAU
		add_child(t)
	# Benches around the fountain and trees at the square corners.
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		var p := Vector3(-13 + sin(a) * 7.2, 0.03, -532 + cos(a) * 7.2)
		batcher.add("bench", Transform3D(Basis(Vector3.UP, a + PI), p))
		_static_box("post", p + Vector3(0, 0.5, 0), Vector3(1.8, 1.0, 0.6), a + PI)
	for p in [Vector3(-18, 0, -484), Vector3(18, 0, -484), Vector3(-18, 0, -596), Vector3(18, 0, -596), Vector3(-19, 0, -548), Vector3(19, 0, -505), Vector3(-19, 0, -520)]:
		_try_tree(p, rng.randf_range(0.95, 1.15), rng.randf() < 0.4)
	for i in 10:
		var a := TAU * i / 10.0
		var p := Vector3(sin(a) * 26.0, 0.03, -545 + cos(a) * 50.0)
		if absf(p.x) < 8.0:
			continue
		batcher.add("lamp", Transform3D(Basis(), p))
		_static_cyl("post", p, 0.15, 3.9)
	for i in 14:
		batcher.add("cobble_post", Transform3D(Basis(), Vector3(-8.8 if i % 2 == 0 else 8.8, 0.03, -478 - (i / 2) * 3.0)))


# --- Background: hills, distant rows, extra trees -------------------------------------------

func _background() -> void:
	var b := MeshBuilder.new()
	var paint := Mats.get_mat("paint")
	var shingle := Mats.get_mat("shingle")
	var body := StaticBody3D.new()
	body.name = "BackgroundBody"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("kind", "wall")
	add_child(body)
	var rows := [40.0, 58.0, 76.0]
	for row in rows:
		for side in [-1.0, 1.0]:
			var z := 60.0 - rng.randf_range(0.0, 10.0)
			while z > -700.0:
				z -= rng.randf_range(18.0, 30.0)
				if absf(z - RIVER_Z) < 22.0:
					continue
				if row < 45.0 and z < MARKET_START + 10.0:
					continue
				if row < 45.0 and side < 0 and z < -90.0 and z > -195.0:
					continue
				var x: float = side * (row + rng.randf_range(-3.0, 3.0))
				var gy := ground_height(x, z) - 0.3
				var w := rng.randf_range(7.0, 10.0)
				var d := rng.randf_range(6.5, 9.0)
				var hgt := rng.randf_range(5.0, 7.5)
				var yaw := rng.randf_range(-0.15, 0.15) + (PI * 0.5 if side < 0 else -PI * 0.5)
				var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(x, gy, z))
				var wc := Color(Mats.PALETTE_HOUSES[rng.randi() % Mats.PALETTE_HOUSES.size()])
				b.box(paint, xf * Transform3D(Basis(), Vector3(0, hgt * 0.5, 0)), Vector3(w, hgt, d), wc, 63 - 8)
				var rc := Mats.ROOF_SLATE if rng.randf() < 0.5 else Mats.ROOF_TERRACOTTA
				b.gable_roof(shingle, xf * Transform3D(Basis(), Vector3(0, hgt, 0)), d, w, d * 0.36, 0.3, 0.15, rc)
				b.gable_wall(paint, xf * Transform3D(Basis(), Vector3(0, hgt, 0)), d, d * 0.36, w * 0.5, 1.0, wc)
				b.gable_wall(paint, xf * Transform3D(Basis(), Vector3(0, hgt, 0)), d, d * 0.36, -w * 0.5, -1.0, wc)
				for wx in [-w * 0.25, w * 0.25]:
					for wy in [1.8, hgt - 1.6]:
						var face_x: float = d * 0.5 + 0.02
						b.box(Mats.get_mat("window_lit"), xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-face_x if side > 0 else face_x, wy, wx)), Vector3(0.9, 1.2, 0.05), Color("#3d5a78"))
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = Vector3(w, hgt + d * 0.36, d)
				cs.shape = bs
				cs.transform = xf * Transform3D(Basis(), Vector3(0, (hgt + d * 0.36) * 0.5, 0))
				body.add_child(cs)
				# A tree or two beside each house.
				if rng.randf() < 0.8:
					var tp := Vector3(x + rng.randf_range(-6.0, 6.0), 0, z + rng.randf_range(-9.0, 9.0))
					tp.y = ground_height(tp.x, tp.z)
					_add_tree(tp, rng.randf_range(1.0, 1.5), rng.randf() < 0.35, rng.randf() < 0.3, absf(tp.x) < BOUNDS_X)
	# Houses beyond the clock tower.
	for i in 7:
		var x := -48.0 + i * 16.0 + rng.randf_range(-2.0, 2.0)
		var z := -632.0 - rng.randf_range(0.0, 8.0)
		var gy := ground_height(x, z) - 0.3
		var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.1, 0.1)), Vector3(x, gy, z))
		var wc := Color(Mats.PALETTE_HOUSES[i % Mats.PALETTE_HOUSES.size()])
		var hgt := rng.randf_range(7.0, 10.0)
		b.box(paint, xf * Transform3D(Basis(), Vector3(0, hgt * 0.5, 0)), Vector3(12, hgt, 9), wc, 63 - 8)
		b.gable_roof(shingle, xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, hgt, 0)), 9, 12, 3.2, 0.3, 0.15, Mats.ROOF_SLATE)
		b.gable_wall(paint, xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, hgt, 0)), 9, 3.2, 6, 1.0, wc)
		b.gable_wall(paint, xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, hgt, 0)), 9, 3.2, -6, -1.0, wc)
	var mi := b.build_instance("BackgroundHouses", not Settings.is_mobile)
	mi.visibility_range_begin = 0.0
	add_child(mi)
	# Hill trees (scattered, many conifers).
	for i in 260:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * rng.randf_range(46.0, 210.0)
		var z := rng.randf_range(-720.0, 70.0)
		if absf(z - RIVER_Z) < 14.0:
			continue
		var p := Vector3(x, ground_height(x, z), z)
		_add_tree(p, rng.randf_range(1.1, 1.9), rng.randf() < 0.3, rng.randf() < 0.45, absf(x) < BOUNDS_X)
	# Trees around the school grounds.
	for i in 40:
		var p := Vector3(rng.randf_range(-44.0, 44.0), 0, rng.randf_range(16.0, 105.0))
		if absf(p.x) < 21.0 and p.z < 66.0:
			continue
		p.y = ground_height(p.x, p.z)
		_try_tree(p, rng.randf_range(1.0, 1.5), rng.randf() < 0.35, rng.randf() < 0.2)
	# Trees between the town and the hills.
	for i in 60:
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(side * rng.randf_range(42.0, 50.0), 0, rng.randf_range(-640.0, 20.0))
		if absf(p.z - RIVER_Z) < 16.0:
			continue
		p.y = ground_height(p.x, p.z)
		_try_tree(p, rng.randf_range(1.0, 1.5), rng.randf() < 0.3, rng.randf() < 0.3)


func _clouds_build() -> void:
	var tex := TexGen.get_tex("cloud")
	for i in 16:
		var q := QuadMesh.new()
		var w := rng.randf_range(60.0, 120.0)
		q.size = Vector2(w, w * rng.randf_range(0.35, 0.5))
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = tex
		mat.albedo_color = Color(1.0, 0.95, 0.9, rng.randf_range(0.55, 0.85))
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		mat.disable_fog = true
		mat.disable_receive_shadows = true
		q.material = mat
		var mi := MeshInstance3D.new()
		mi.name = "Cloud%d" % i
		mi.mesh = q
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(rng.randf_range(-400.0, 400.0), rng.randf_range(75.0, 140.0), rng.randf_range(-950.0, 250.0))
		mi.set_meta("speed", rng.randf_range(0.6, 1.6))
		add_child(mi)
		_clouds.append(mi)


func _ambient_life() -> void:
	var birds := BIRDS_SCENE.instantiate()
	birds.position = Vector3(0, 30, -150)
	add_child(birds)
	var birds2 := BIRDS_SCENE.instantiate()
	birds2.position = Vector3(-10, 34, -520)
	birds2.set("orbit_radius", 50.0)
	add_child(birds2)
	var bf := BUTTERFLIES_SCENE.instantiate()
	bf.position = Vector3(-24, 0, -150)
	add_child(bf)
	var bf2 := BUTTERFLIES_SCENE.instantiate()
	bf2.position = Vector3(-13, 0, -532)
	add_child(bf2)
	var ducks := DUCKS_SCENE.instantiate()
	ducks.position = Vector3(-30, WATER_Y, RIVER_Z)
	add_child(ducks)
	var ducks2 := DUCKS_SCENE.instantiate()
	ducks2.position = Vector3(40, WATER_Y, RIVER_Z + 2.0)
	add_child(ducks2)
	# Pedestrians walking along the sidewalks.
	var walks := [
		[Vector3(6.4, 0.15, 6), Vector3(6.4, 0.15, -90)], [Vector3(-6.4, 0.15, -20), Vector3(-6.4, 0.15, -92)],
		[Vector3(6.6, 0.15, -120), Vector3(6.6, 0.15, -250)], [Vector3(7.0, 0.15, -340), Vector3(7.0, 0.15, -460)],
		[Vector3(-7.0, 0.15, -350), Vector3(-7.0, 0.15, -470)], [Vector3(-20, 0.03, -500), Vector3(6, 0.03, -580)],
		[Vector3(-12, 0.03, -116), Vector3(-30, 0.03, -165)],
	]
	var shirt := ["#c8423b", "#2f6f8f", "#3f7d4f", "#e0a13a", "#7c4f9e", "#d9675a", "#2d4f7c"]
	for i in walks.size():
		var p: Node3D = PEDESTRIAN_SCENE.instantiate()
		p.set("point_a", walks[i][0])
		p.set("point_b", walks[i][1])
		p.set("shirt_color", Color(shirt[i % shirt.size()]))
		p.set("phase", rng.randf())
		add_child(p)
	for i in 2:
		var c: Node3D = CYCLIST_SCENE.instantiate()
		c.set("lane_x", 2.4 if i == 0 else -2.4)
		c.set("phase", 0.3 + i * 0.45)
		c.set("bike_color", Color("#c8423b") if i == 0 else Color("#2f6f8f"))
		add_child(c)
	var air := AIR_SCENE.instantiate()
	add_child(air)


# --- Time of day ---------------------------------------------------------------------------------

## Switches the whole town between golden hour and dusk (lit windows, deeper sky, low sun).
func set_time_of_day(mode: String) -> void:
	if mode == time_of_day or world_env == null:
		return
	time_of_day = mode
	var dusk := mode == "dusk"
	var env := world_env.environment
	_sky_mat.sky_top_color = Color("#27325f") if dusk else Color("#6699dd")
	_sky_mat.sky_horizon_color = Color("#f0906a") if dusk else Color("#f5d1ab")
	_sky_mat.ground_horizon_color = _sky_mat.sky_horizon_color
	_sky_mat.ground_bottom_color = Color("#4a3442") if dusk else Color("#b98d6a")
	_sky_mat.sky_energy_multiplier = 0.9 if dusk else 1.0
	sun.light_color = Color("#ff9466") if dusk else Color("#ffd3a1")
	sun.light_energy = 0.7 if dusk else 2.1
	var to_light := Vector3(0.66, 0.1, -0.74) if dusk else Vector3(0.62, 0.36, -0.7)
	sun.look_at_from_position(Vector3.ZERO, -to_light.normalized(), Vector3.UP)
	env.ambient_light_energy = 0.55 if dusk else 0.9
	env.fog_light_color = Color("#8e6a86") if dusk else Color("#f5d2ac")
	env.fog_depth_end = 330.0 if dusk else 430.0
	env.tonemap_exposure = 1.08 if dusk else 0.92
	env.glow_intensity = 0.95 if dusk else 0.55
	env.glow_hdr_threshold = 0.85 if dusk else 1.0
	env.adjustment_saturation = 1.12 if dusk else 1.06
	# Every window and street lamp glows warmly at dusk.
	var lit := Mats.get_mat("window_lit") as StandardMaterial3D
	lit.emission = Color(1.0, 0.68, 0.36) if dusk else Color(1.0, 0.72, 0.42)
	lit.emission_energy_multiplier = 2.4 if dusk else 0.35
	var water := Mats.get_mat("water") as ShaderMaterial
	water.set_shader_parameter("sky_color", Color(0.78, 0.5, 0.52) if dusk else Color(0.96, 0.82, 0.68))
	water.set_shader_parameter("deep_color", Color(0.12, 0.22, 0.33) if dusk else Color(0.24, 0.47, 0.55))
	_update_sun_uniforms()
	for c in _clouds:
		var m := (c.mesh as QuadMesh).material as StandardMaterial3D
		var a := m.albedo_color.a
		m.albedo_color = Color(0.95, 0.66, 0.68, a) if dusk else Color(1.0, 0.95, 0.9, a)


# --- Storybook look, grass, sunbeams --------------------------------------------------------

## Direction toward the sun for the current time of day.
func _to_sun() -> Vector3:
	return (Vector3(0.66, 0.1, -0.74) if time_of_day == "dusk" else Vector3(0.62, 0.36, -0.7)).normalized()


## A soft "storybook" color grade as a 3D LUT: lifted warm shadows, creamy highlights,
## slightly softened contrast and a touch more saturation.
static func _storybook_lut() -> ImageTexture3D:
	var n := 17
	var images: Array[Image] = []
	for bz in n:
		var img := Image.create(n, n, false, Image.FORMAT_RGB8)
		for gy in n:
			for rx in n:
				var c := Vector3(float(rx), float(gy), float(bz)) / float(n - 1)
				var lum := c.dot(Vector3(0.3, 0.59, 0.11))
				c = c * 0.96 + Vector3.ONE * 0.018
				c += Vector3(0.03, 0.01, 0.045) * pow(1.0 - lum, 2.0)
				c += Vector3(0.03, 0.012, -0.025) * pow(lum, 2.0)
				c = Vector3(lum, lum, lum).lerp(c, 1.06)
				img.set_pixel(rx, gy, Color(clampf(c.x, 0, 1), clampf(c.y, 0, 1), clampf(c.z, 0, 1)))
		images.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, n, n, n, false, images)
	return tex


## Grass tufts that bend in the wind: front and back yards, the park and the river banks.
func _grass() -> void:
	var count := 3200 if Settings.is_mobile else 9000
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 4:
		tries += 1
		var region := rng.randi() % 10
		var p := Vector3.ZERO
		if region < 5:
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var far := rng.randf() < 0.45
			p = Vector3(side * (rng.randf_range(27.0, 42.0) if far else rng.randf_range(8.8, 16.6)), 0, rng.randf_range(-276.0, 14.0))
		elif region < 8:
			p = Vector3(rng.randf_range(-39.5, -10.0), 0, rng.randf_range(-187.0, -97.0))
		else:
			var bank := -1.0 if rng.randf() < 0.5 else 1.0
			p = Vector3(rng.randf_range(-70.0, 70.0), 0, RIVER_Z + bank * rng.randf_range(12.5, 17.0))
			if absf(p.x) < 7.0 or (bank > 0 and p.x > 22.0 and p.x < 30.0):
				continue
		var near_pad := false
		for pad in _pad_keepouts:
			if Vector2(p.x - pad.x, p.z - pad.z).length() < 3.2:
				near_pad = true
		if near_pad or p.distance_to(Vector3(-27, 0, -142)) < 5.0:
			continue
		p.y = ground_height(p.x, p.z)
		if p.y < WATER_Y + 0.05:
			continue
		var s := rng.randf_range(0.7, 1.35)
		var tint := Color("#8fbf5a").lerp(Color("#c3d870"), rng.randf()).lerp(Color("#d9b25a"), rng.randf() * 0.12)
		batcher.add("grass", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s)), p), tint)
		placed += 1


## Horizon sun glow and soft slanted sunbeams through gaps in the trees.
func _sun_effects() -> void:
	_sun_glow = MeshInstance3D.new()
	_sun_glow.name = "SunGlow"
	var q := QuadMesh.new()
	q.size = Vector2(520, 520)
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.albedo_texture = TexGen.get_tex("soft_dot")
	gm.albedo_color = Color(1.0, 0.78, 0.5, 0.42)
	gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gm.disable_fog = true
	gm.disable_receive_shadows = true
	q.material = gm
	_sun_glow.mesh = q
	_sun_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sun_glow.extra_cull_margin = 2000.0
	_sun_glow.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_sun_glow)

	# Beams start in the canopies and slant down along the light direction.
	var spots: Array[Vector3] = []
	for t in trees:
		var p: Vector3 = t.pos
		if absf(p.x) > 44.0 or p.z > 40.0 or p.z < -620.0:
			continue
		if rng.randf() < 0.35:
			spots.append(p + Vector3(rng.randf_range(-2.0, 2.0), 0, rng.randf_range(-2.0, 2.0)))
	var max_beams := 18 if Settings.is_mobile else 40
	while spots.size() > max_beams:
		spots.remove_at(rng.randi() % spots.size())
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bq := QuadMesh.new()
	bq.size = Vector2(1, 1)
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = load("res://shaders/sunbeam.gdshader")
	bq.material = _beam_mat
	mm.mesh = bq
	mm.instance_count = spots.size()
	var light_dir := -_to_sun()
	for i in spots.size():
		var ground := spots[i]
		var length := rng.randf_range(16.0, 24.0)
		var width := rng.randf_range(1.6, 3.2)
		var center := ground - light_dir * length * 0.5
		var axis := -light_dir
		var x := axis.cross(Vector3.UP).normalized()
		var z := x.cross(axis).normalized()
		mm.set_instance_transform(i, Transform3D(Basis(x * width, axis * length, z), center))
	_beams = MultiMeshInstance3D.new()
	_beams.name = "Sunbeams"
	_beams.multimesh = mm
	_beams.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beams.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_beams.custom_aabb = AABB(Vector3(-80, -10, -700), Vector3(160, 60, 800))
	add_child(_beams)
	Settings.quality_changed.connect(_on_quality)
	_on_quality(Settings.quality)
	_update_sun_uniforms()


func _on_quality(q: int) -> void:
	if _beams:
		_beams.visible = q >= 1 and time_of_day != "dusk"
	for node in batcher.get_children():
		if node.name.begins_with("grass_"):
			(node as Node3D).visible = q >= 1


func _update_sun_uniforms() -> void:
	var dusk := time_of_day == "dusk"
	var water := Mats.get_mat("water") as ShaderMaterial
	water.set_shader_parameter("sun_dir", _to_sun())
	water.set_shader_parameter("sun_color", Color(1.0, 0.6, 0.38) if dusk else Color(1.0, 0.86, 0.62))
	if _sun_glow:
		var gm := (_sun_glow.mesh as QuadMesh).material as StandardMaterial3D
		gm.albedo_color = Color(1.0, 0.55, 0.32, 0.55) if dusk else Color(1.0, 0.78, 0.5, 0.42)
	if _beams:
		_beams.visible = Settings.quality >= 1 and not dusk
	if _probe:
		# Nudge the probe so it re-captures the town under the new lighting.
		_probe.size = Vector3(330, 26, 46) + (Vector3(0.01, 0, 0) if dusk else Vector3.ZERO)
