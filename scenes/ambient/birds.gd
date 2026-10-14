extends Node3D
## A small flock of birds circling lazily with flapping wings.

@export var count := 9
@export var orbit_radius := 70.0
@export var speed := 0.09

var _birds: Array = []
var _t := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.z * 13.0) + 5
	var mesh := _bird_mesh()
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_birds.append({"node": mi, "offset": Vector3(rng.randf_range(-6, 6), rng.randf_range(-3, 3), rng.randf_range(-6, 6)),
			"phase": rng.randf() * TAU, "flap": rng.randf_range(7.0, 10.0)})
	_t = rng.randf() * TAU


func _bird_mesh() -> ArrayMesh:
	# Two wings that the vertex shader-free approach animates via node scale (simple V shape).
	var b := MeshBuilder.new()
	var m := Mats.get_mat("cloth")
	var c := Color("#3a3530")
	b.poly(m, PackedVector3Array([Vector3(0, 0, -0.18), Vector3(0.55, 0.1, 0.05), Vector3(0, 0, 0.12)]), c)
	b.poly(m, PackedVector3Array([Vector3(0, 0, -0.18), Vector3(0, 0, 0.12), Vector3(-0.55, 0.1, 0.05)]), c)
	b.box(m, Transform3D(Basis(), Vector3(0, -0.02, 0)), Vector3(0.08, 0.06, 0.38), c)
	return b.build()


func _process(delta: float) -> void:
	_t += delta * speed
	var center := Vector3(cos(_t) * orbit_radius, sin(_t * 2.3) * 4.0, sin(_t) * orbit_radius * 0.6)
	var tangent := Vector3(-sin(_t) * orbit_radius, 0, cos(_t) * orbit_radius * 0.6).normalized()
	for bd in _birds:
		var n: MeshInstance3D = bd.node
		var wob := Vector3(sin(_t * 7.0 + bd.phase) * 1.5, sin(_t * 5.0 + bd.phase) * 0.8, cos(_t * 6.0 + bd.phase) * 1.5)
		n.position = center + bd.offset + wob
		n.basis = Basis.looking_at(tangent, Vector3.UP)
		var flap := sin(Time.get_ticks_msec() * 0.001 * bd.flap + bd.phase)
		n.scale = Vector3(1.0, 1.0 + flap * 2.2, 1.0)
