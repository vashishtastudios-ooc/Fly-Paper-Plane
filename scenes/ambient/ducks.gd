extends Node3D
## A family of ducks paddling slow circles on the river.

@export var count := 5

var _ducks: Array = []


func _ready() -> void:
	var mesh := _duck_mesh()
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var s := 1.0 if i == 0 else 0.65
		mi.scale = Vector3.ONE * s
		add_child(mi)
		_ducks.append(mi)


func _duck_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	var m := Mats.get_mat("solid")
	b.sphere(m, Vector3(0, 0.08, 0), Vector3(0.18, 0.11, 0.28), 4, 8, Color("#8a6a4a"))
	b.sphere(m, Vector3(0, 0.12, -0.05), Vector3(0.14, 0.08, 0.2), 3, 7, Color("#7a5a3a"))
	b.sphere(m, Vector3(0, 0.28, -0.22), Vector3(0.09, 0.09, 0.09), 4, 7, Color("#2f6f4f"))
	b.sphere(m, Vector3(0, 0.26, -0.33), Vector3(0.04, 0.025, 0.06), 3, 5, Color("#f2a33a"))
	b.cylinder(m, Transform3D(Basis(), Vector3(0, 0.14, -0.2)), 0.05, 0.05, 0.12, 6, Color("#fbf8f0"))
	return b.build()


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001 * 0.12
	for i in _ducks.size():
		var d: MeshInstance3D = _ducks[i]
		var tt := t - i * 0.08
		var p := Vector3(sin(tt) * 9.0, 0.0, cos(tt * 0.7) * 3.0)
		var p2 := Vector3(sin(tt + 0.01) * 9.0, 0.0, cos((tt + 0.01) * 0.7) * 3.0)
		d.position = p + Vector3(0, sin(Time.get_ticks_msec() * 0.003 + i) * 0.02, 0)
		var dir := p2 - p
		if dir.length() > 0.0001:
			d.basis = Basis.looking_at(dir.normalized(), Vector3.UP).scaled(d.scale)
