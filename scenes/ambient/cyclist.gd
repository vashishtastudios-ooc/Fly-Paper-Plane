extends Node3D
## A cyclist riding up and down Linden Lane.

@export var lane_x := 2.4
@export var z_start := 8.0
@export var z_end := -268.0
@export var phase := 0.0
@export var bike_color := Color("#c8423b")
@export var ride_speed := 4.2

var _wheels: Array[Node3D] = []
var _rider_legs: Array[Node3D] = []
var _t := 0.0


func _ready() -> void:
	var m := Mats.get_mat("solid")
	var metal := Mats.get_mat("metal")
	var frame := MeshBuilder.new()
	var bc := bike_color
	frame.tube(metal, PackedVector3Array([Vector3(0, 0.35, 0.5), Vector3(0, 0.75, 0.05), Vector3(0, 0.38, -0.05), Vector3(0, 0.35, 0.5)]), 0.025, 4, bc)
	frame.tube(metal, PackedVector3Array([Vector3(0, 0.75, 0.05), Vector3(0, 0.8, -0.45), Vector3(0, 0.35, -0.5)]), 0.025, 4, bc)
	frame.tube(metal, PackedVector3Array([Vector3(-0.22, 0.98, -0.42), Vector3(0.22, 0.98, -0.42)]), 0.02, 4, Color("#333333"))
	frame.box(m, Transform3D(Basis(), Vector3(0, 0.82, 0.08)), Vector3(0.12, 0.05, 0.24), Color("#3a2a20"))
	frame.box(Mats.get_mat("wood"), Transform3D(Basis(), Vector3(0, 0.82, -0.62)), Vector3(0.32, 0.2, 0.26), Color("#c9975a"))
	# Rider.
	frame.cylinder(m, Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, 0.88, 0.05)), 0.17, 0.15, 0.58, 8, Color("#f2d58f") if bc.r > 0.5 else Color("#e9b7a1"), true, true)
	frame.sphere(m, Vector3(0, 1.58, -0.15), Vector3(0.14, 0.16, 0.14), 5, 8, Color("#e9b996"))
	frame.sphere(m, Vector3(0, 1.66, -0.13), Vector3(0.16, 0.08, 0.17), 4, 8, bc.darkened(0.2))
	frame.tube(m, PackedVector3Array([Vector3(0.18, 1.32, -0.05), Vector3(0.2, 1.1, -0.3), Vector3(0.22, 0.98, -0.42)]), 0.04, 4, Color("#f2d58f"))
	frame.tube(m, PackedVector3Array([Vector3(-0.18, 1.32, -0.05), Vector3(-0.2, 1.1, -0.3), Vector3(-0.22, 0.98, -0.42)]), 0.04, 4, Color("#f2d58f"))
	add_child(frame.build_instance("Bike"))
	for z in [0.5, -0.5]:
		var w := Node3D.new()
		w.position = Vector3(0, 0.35, z)
		var wb := MeshBuilder.new()
		wb.cylinder(m, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.02, 0, 0)), 0.34, 0.34, 0.04, 14, Color("#2a2a2a"))
		wb.box(metal, Transform3D(Basis(), Vector3.ZERO), Vector3(0.05, 0.6, 0.04), Color("#cccccc"))
		w.add_child(wb.build_instance("Wheel"))
		add_child(w)
		_wheels.append(w)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.1, 0.84, 0.05)
		var lb := MeshBuilder.new()
		lb.cylinder(m, Transform3D(Basis(), Vector3(0, -0.5, 0)), 0.06, 0.07, 0.5, 6, Color("#3d4a5c"))
		leg.add_child(lb.build_instance("Leg"))
		add_child(leg)
		_rider_legs.append(leg)
	_t = phase


func _process(delta: float) -> void:
	var length := absf(z_end - z_start)
	_t += delta * ride_speed / length
	var u := fmod(_t, 2.0)
	var forward := u < 1.0
	var t := u if forward else 2.0 - u
	var x := lane_x if forward else -lane_x
	position = Vector3(x, 0.02, lerpf(z_start, z_end, t))
	rotation.y = 0.0 if forward else PI
	var spin := Time.get_ticks_msec() * 0.001 * ride_speed / 0.34
	for w in _wheels:
		w.rotation.x = -spin
	_rider_legs[0].rotation.x = sin(spin * 0.5) * 0.6
	_rider_legs[1].rotation.x = -sin(spin * 0.5) * 0.6
