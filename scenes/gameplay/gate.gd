class_name Gate
extends Node3D
## A torus gate along the route. Faces along `axis` (local Y of the torus = flight direction).

enum Look { HIDDEN, FUTURE, NEXT, PASSED }

const PASS_RADIUS := 2.3

@export var ring_radius := 1.7
@export var tube := 0.08
@export var golden := false
## Lantern Night style: a hoop of glowing paper lanterns instead of a gold ring.
@export var lantern := false

var axis := Vector3.FORWARD
var look := Look.FUTURE
var _mesh: MeshInstance3D
var _t := 0.0

static var _next_mat: StandardMaterial3D
static var _future_mat: StandardMaterial3D
static var _gold_mat: StandardMaterial3D
static var _rope_mat: StandardMaterial3D
static var _lantern_bright: StandardMaterial3D
static var _lantern_dim: StandardMaterial3D
static var _lantern_mesh: ArrayMesh
const LANTERN_COLORS := [Color("#ff8a3d"), Color("#ffcf5a"), Color("#ff5f5f"), Color("#ffb347")]


static func _mats() -> void:
	if _next_mat:
		return
	_next_mat = StandardMaterial3D.new()
	_next_mat.albedo_color = Color("#f6c445")
	_next_mat.emission_enabled = true
	_next_mat.emission = Color("#ffc94d")
	_next_mat.emission_energy_multiplier = 2.2
	_next_mat.metallic = 0.5
	_next_mat.roughness = 0.35
	_future_mat = StandardMaterial3D.new()
	_future_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_future_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_future_mat.albedo_color = Color(1, 1, 1, 0.3)
	# Bonus rings are rose-violet so they never look like the main route's gold rings.
	_gold_mat = _next_mat.duplicate()
	_gold_mat.albedo_color = Color("#e070c0")
	_gold_mat.emission = Color("#ff7ad9")
	_gold_mat.emission_energy_multiplier = 2.6
	_rope_mat = StandardMaterial3D.new()
	_rope_mat.albedo_color = Color("#4a3426")
	_rope_mat.roughness = 0.9
	# Unshaded with an HDR multiplier so the paper glows (and blooms) in its own color.
	_lantern_bright = StandardMaterial3D.new()
	_lantern_bright.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lantern_bright.vertex_color_use_as_albedo = true
	_lantern_bright.vertex_color_is_srgb = true
	_lantern_bright.albedo_color = Color(1.55, 1.55, 1.55)
	_lantern_dim = _lantern_bright.duplicate()
	_lantern_dim.albedo_color = Color(0.85, 0.85, 0.85)


## A small round paper lantern (local +Y up), colored with vertex colors.
static func lantern_mesh() -> ArrayMesh:
	if _lantern_mesh:
		return _lantern_mesh
	var b := MeshBuilder.new()
	var paper := Mats.get_mat("solid")
	b.sphere(paper, Vector3.ZERO, Vector3(0.2, 0.24, 0.2), 6, 10, Color.WHITE)
	var cap := Mats.get_mat("metal")
	b.cylinder(cap, Transform3D(Basis(), Vector3(0, 0.2, 0)), 0.09, 0.07, 0.07, 8, Color("#2a2522"))
	b.cylinder(cap, Transform3D(Basis(), Vector3(0, -0.27, 0)), 0.07, 0.09, 0.06, 8, Color("#2a2522"))
	_lantern_mesh = b.build()
	return _lantern_mesh


## Flying this close to the center passes the ring (2.3 m for the standard 1.7 m ring).
func pass_radius() -> float:
	return ring_radius + (PASS_RADIUS - 1.7)


func _ready() -> void:
	_mats()
	_mesh = MeshInstance3D.new()
	_mesh.name = "Model"
	var t := TorusMesh.new()
	t.inner_radius = ring_radius - tube
	t.outer_radius = ring_radius + tube
	t.rings = 40
	t.ring_segments = 10
	_mesh.mesh = t
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	if lantern:
		t.inner_radius = ring_radius - 0.03
		t.outer_radius = ring_radius + 0.03
		var count := 8
		for i in count:
			var a := TAU * i / count
			var l := MeshInstance3D.new()
			l.name = "Lantern%d" % i
			l.mesh = lantern_mesh()
			# World up is local -Z for a horizontal gate, so turn each lantern upright.
			l.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(cos(a) * ring_radius, 0, sin(a) * ring_radius) + Vector3(0, 0, 0.12))
			l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_mesh.add_child(l)
			_tint(l, LANTERN_COLORS[i % LANTERN_COLORS.size()])
	set_axis(axis)
	set_look(Look.NEXT if golden else Look.FUTURE)


func set_axis(a: Vector3) -> void:
	axis = a.normalized()
	var up := axis
	var ref := Vector3.UP if absf(up.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(up).normalized()
	var z := x.cross(up).normalized()
	basis = Basis(x, up, z)


func set_look(l: int) -> void:
	look = l
	visible = l == Look.FUTURE or l == Look.NEXT
	if not _mesh:
		return
	if lantern:
		_mesh.material_override = _rope_mat
		for c in _mesh.get_children():
			(c as MeshInstance3D).material_override = _lantern_bright if l == Look.NEXT else _lantern_dim
	elif golden:
		_mesh.material_override = _gold_mat
	else:
		_mesh.material_override = _next_mat if l == Look.NEXT else _future_mat
	_mesh.scale = Vector3.ONE


func _process(delta: float) -> void:
	if look == Look.NEXT or golden:
		_t += delta
		var s := 1.0 + 0.07 * sin(_t * 5.0)
		_mesh.scale = Vector3(s, 1.0, s)


## Bakes a color into a copy of the lantern mesh's vertex colors (lanterns differ in color).
func _tint(mi: MeshInstance3D, col: Color) -> void:
	var src := lantern_mesh()
	var mesh := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		if s == 0:
			for i in colors.size():
				colors[i] = col
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mi.mesh = mesh
