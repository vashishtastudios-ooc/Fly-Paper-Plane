class_name Gate
extends Node3D
## A torus gate along the route. Faces along `axis` (local Y of the torus = flight direction).

enum Look { HIDDEN, FUTURE, NEXT, PASSED }

const PASS_RADIUS := 2.3

@export var ring_radius := 1.7
@export var tube := 0.08
@export var golden := false

var axis := Vector3.FORWARD
var look := Look.FUTURE
var _mesh: MeshInstance3D
var _t := 0.0

static var _next_mat: StandardMaterial3D
static var _future_mat: StandardMaterial3D
static var _gold_mat: StandardMaterial3D


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
	_gold_mat = _next_mat.duplicate()
	_gold_mat.emission_energy_multiplier = 2.8


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
	if golden:
		_mesh.material_override = _gold_mat
	else:
		_mesh.material_override = _next_mat if l == Look.NEXT else _future_mat
	_mesh.scale = Vector3.ONE


func _process(delta: float) -> void:
	if look == Look.NEXT or golden:
		_t += delta
		var s := 1.0 + 0.07 * sin(_t * 5.0)
		_mesh.scale = Vector3(s, 1.0, s)
