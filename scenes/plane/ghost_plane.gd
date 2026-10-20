class_name GhostPlane
extends Node3D
## A see-through plane replaying the player's best run on a flight, so they can race it.
## Also records the current run (see Profile.save_ghost for the sample layout).

const STEP := 0.1
const FIELDS := 7

var _samples := PackedFloat32Array()
var _count := 0
var _rec := PackedFloat32Array()
var _rec_t := -1.0
var _model: MeshInstance3D


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_model = MeshInstance3D.new()
	_model.mesh = PaperPlaneMesh.get_mesh()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.85, 0.93, 1.0, 0.38)
	m.disable_receive_shadows = true
	_model.material_override = m
	_model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_model)
	visible = false


## The ghost shows the same plane design as the player's.
func set_shape(shape: String) -> void:
	if _model:
		_model.mesh = PaperPlaneMesh.get_mesh(shape)


## Loads the best run to replay (empty: no ghost).
func set_run(samples: PackedFloat32Array) -> void:
	_samples = samples
	_count = samples.size() / FIELDS
	visible = false


func has_run() -> bool:
	return _count >= 2


## Shows the ghost where the best run was `t` seconds after its throw (hidden once it ended).
func play(t: float) -> void:
	if not has_run():
		visible = false
		return
	var last := _samples[(_count - 1) * FIELDS]
	if t < 0.0 or t > last:
		visible = false
		return
	var i := clampi(int(t / STEP), 0, _count - 2)
	while i > 0 and _samples[i * FIELDS] > t:
		i -= 1
	while i < _count - 2 and _samples[(i + 1) * FIELDS] < t:
		i += 1
	var a := i * FIELDS
	var b := a + FIELDS
	var span := maxf(_samples[b] - _samples[a], 1e-4)
	var w := clampf((t - _samples[a]) / span, 0.0, 1.0)
	position = Vector3(_samples[a + 1], _samples[a + 2], _samples[a + 3]).lerp(Vector3(_samples[b + 1], _samples[b + 2], _samples[b + 3]), w)
	rotation = Vector3(lerp_angle(_samples[a + 4], _samples[b + 4], w), lerp_angle(_samples[a + 5], _samples[b + 5], w), 0.0)
	_model.rotation = Vector3(0, 0, lerp_angle(_samples[a + 6], _samples[b + 6], w))
	visible = true


func start_recording() -> void:
	_rec = PackedFloat32Array()
	_rec_t = -1.0


## Called every frame of a flight with the real plane.
func record(t: float, plane: Node3D, roll: float) -> void:
	if _rec_t >= 0.0 and t - _rec_t < STEP:
		return
	_rec_t = t
	var p := plane.global_position
	_rec.append_array(PackedFloat32Array([t, p.x, p.y, p.z, plane.rotation.x, plane.rotation.y, roll]))


func recording() -> PackedFloat32Array:
	return _rec
