class_name Cosmetics
extends RefCounted
## Cosmetic plane customization: plane design, paper, trail and wing sticker. Purely visual (no stat changes).
## Items unlock with the total number of ribbons earned across all flights.

## Plane designs (PaperPlaneMesh.SHAPES). Every design flies exactly the same.
const SHAPES := [
	{"id": "dart", "name": "Classic Dart", "req": 0},
	{"id": "glider", "name": "Wide Glider", "req": 1},
	{"id": "stubby", "name": "Stubby", "req": 3},
	{"id": "speedster", "name": "Speedster", "req": 5},
	{"id": "swallow", "name": "Swallow Tail", "req": 8},
	{"id": "handmade", "name": "Handmade", "req": 11},
	{"id": "biplane", "name": "Double Wing", "req": 14},
	{"id": "ring", "name": "Ring Wing", "req": 18},
]
const PAPERS := [
	{"id": "notebook", "name": "Notebook", "req": 0},
	{"id": "graph", "name": "Graph paper", "req": 2},
	{"id": "origami", "name": "Red origami", "req": 4},
	{"id": "news", "name": "Newspaper", "req": 6},
	{"id": "map", "name": "Old map", "req": 8},
	{"id": "construction", "name": "Sky blue card", "req": 10},
	{"id": "polka", "name": "Polka dot", "req": 12},
]
const TRAILS := [
	{"id": "white", "name": "Classic white", "req": 0},
	{"id": "rainbow", "name": "Rainbow ribbon", "req": 3},
	{"id": "gold", "name": "Gold sparkles", "req": 5},
	{"id": "confetti", "name": "Confetti", "req": 7},
	{"id": "comet", "name": "Comet glow", "req": 9},
]
const STICKERS := [
	{"id": "none", "name": "No sticker", "req": 0},
	{"id": "star", "name": "Gold star", "req": 0},
	{"id": "heart", "name": "Heart", "req": 1},
	{"id": "smile", "name": "Smiley", "req": 2},
	{"id": "bolt", "name": "Lightning", "req": 6},
	{"id": "seven", "name": "Lucky 7", "req": 11},
]
const DEFAULTS := {"shape": "dart", "paper": "notebook", "trail": "white", "sticker": "none"}

static var _paper_mats := {}
static var _sticker_meshes := {}


static func items(kind: String) -> Array:
	match kind:
		"shape": return SHAPES
		"paper": return PAPERS
		"trail": return TRAILS
		"sticker": return STICKERS
	return []


static func requirement(kind: String, id: String) -> int:
	for it in items(kind):
		if it.id == id:
			return it.req
	return 999


static func is_unlocked(kind: String, id: String, ribbons: int) -> bool:
	return Game.UNLOCK_ALL_FOR_TESTING or requirement(kind, id) <= ribbons


## Items that unlock exactly at `ribbons` (used to announce new unlocks).
static func newly_unlocked(before: int, after: int) -> Array[String]:
	var out: Array[String] = []
	for kind in ["shape", "paper", "trail", "sticker"]:
		for it in items(kind):
			if it.req > before and it.req <= after:
				out.append(it.name)
	return out


static func paper_material(id: String) -> Material:
	if id == "notebook" or id == "":
		return Mats.get_mat("paper_plane")
	if _paper_mats.has(id):
		return _paper_mats[id]
	var m := StandardMaterial3D.new()
	m.albedo_texture = TexGen.get_tex("paper_" + id)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_paper_mats[id] = m
	return m


## A pair of sticker decals sitting on top of both wings (plane space, forward = -Z).
static func sticker_mesh(id: String, shape := "dart") -> Mesh:
	if id == "none" or id == "":
		return null
	var key := id + "/" + shape
	if _sticker_meshes.has(key):
		return _sticker_meshes[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = TexGen.get_tex("sticker_" + id)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var k := PaperPlaneMesh.SCALE
	var spec: Dictionary = PaperPlaneMesh.SHAPES.get(shape, PaperPlaneMesh.SHAPES.dart)
	var half: float = spec.sticker_size * k
	var at: Vector3 = spec.sticker
	for side in [-1.0, 1.0]:
		var c := Vector3(side * absf(at.x), at.y, at.z) * k
		# Corners: u along +x, v toward the nose so the sticker reads upright from behind.
		var p00 := c + Vector3(-half, 0, half)
		var p10 := c + Vector3(half, 0, half)
		var p11 := c + Vector3(half, 0, -half)
		var p01 := c + Vector3(-half, 0, -half)
		for v in [[p00, Vector2(0, 1)], [p11, Vector2(1, 0)], [p10, Vector2(1, 1)], [p00, Vector2(0, 1)], [p01, Vector2(0, 0)], [p11, Vector2(1, 0)]]:
			st.set_normal(Vector3.UP)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var mesh := st.commit()
	mesh.surface_set_material(0, m)
	_sticker_meshes[key] = mesh
	return mesh


## Applies design, paper and sticker to a MeshInstance3D showing the paper plane.
static func apply(mi: MeshInstance3D, paper: String, sticker: String, shape := "dart") -> void:
	if mi == null:
		return
	mi.mesh = PaperPlaneMesh.get_mesh(shape)
	mi.material_override = null if paper == "notebook" else paper_material(paper)
	var decal: MeshInstance3D = mi.get_node_or_null("Sticker")
	if decal == null:
		decal = MeshInstance3D.new()
		decal.name = "Sticker"
		decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(decal)
	decal.mesh = sticker_mesh(sticker, shape)
	decal.visible = decal.mesh != null


## Trail color for a point at position t (0 = tail, 1 = at the wingtip).
static func trail_color(style: String, t: float, index: int, time: float) -> Color:
	var a := t * t
	match style:
		"rainbow":
			var c := Color.from_hsv(fposmod(index * 0.035 - time * 0.25, 1.0), 0.55, 1.0)
			return Color(c, 0.75 * a)
		"gold":
			return Color(1.0, 0.82, 0.38, 0.7 * a)
		"confetti":
			var cols := [Color("#e8546a"), Color("#f2c14e"), Color("#6fb4e8"), Color("#7fd08c"), Color("#c38be8")]
			var cc: Color = cols[(index / 3) % cols.size()]
			return Color(cc, 0.7 * a)
		"comet":
			return Color(Color("#ffb36b").lerp(Color("#8fe8ff"), t), 0.9 * a)
	return Color(1, 1, 1, 0.55 * a)


static func trail_width(style: String) -> float:
	match style:
		"comet": return 1.8
		"rainbow": return 1.3
	return 1.0
