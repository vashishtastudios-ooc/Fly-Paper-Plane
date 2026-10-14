extends Node3D
## A simple stylized townsperson strolling back and forth between two points.

@export var point_a := Vector3.ZERO
@export var point_b := Vector3(0, 0, -20)
@export var shirt_color := Color("#2f6f8f")
@export var phase := 0.0
@export var walk_speed := 1.1

var _body: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _t := 0.0


func _ready() -> void:
	var skin: Color = [Color("#f1c9a5"), Color("#d9a27a"), Color("#a8714f"), Color("#7a4f35")][int(phase * 97.0) % 4]
	var hair: Color = [Color("#3a2a20"), Color("#8a5a2a"), Color("#d9b26a"), Color("#1f1a18"), Color("#b0b0b0")][int(phase * 53.0) % 5]
	_body = Node3D.new()
	add_child(_body)
	var b := MeshBuilder.new()
	var m := Mats.get_mat("solid")
	b.cylinder(m, Transform3D(Basis(), Vector3(0, 0.85, 0)), 0.2, 0.17, 0.62, 8, shirt_color, true, true)
	b.sphere(m, Vector3(0, 1.62, 0), Vector3(0.15, 0.17, 0.15), 5, 8, skin)
	b.sphere(m, Vector3(0, 1.69, 0.02), Vector3(0.16, 0.12, 0.16), 4, 8, hair)
	_body.add_child(b.build_instance("Torso"))
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.09, 0.86, 0)
		var lb := MeshBuilder.new()
		lb.cylinder(m, Transform3D(Basis(), Vector3(0, -0.84, 0)), 0.07, 0.08, 0.84, 6, Color("#3d4a5c"))
		lb.box(m, Transform3D(Basis(), Vector3(0, -0.84, -0.05)), Vector3(0.11, 0.07, 0.2), Color("#3a2a20"))
		leg.add_child(lb.build_instance("Leg"))
		_body.add_child(leg)
		_legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.24, 1.42, 0)
		var ab := MeshBuilder.new()
		ab.cylinder(m, Transform3D(Basis(), Vector3(0, -0.58, 0)), 0.05, 0.055, 0.58, 6, shirt_color.darkened(0.1))
		ab.sphere(m, Vector3(0, -0.6, 0), Vector3(0.05, 0.05, 0.05), 3, 5, skin)
		arm.add_child(ab.build_instance("Arm"))
		_body.add_child(arm)
		_arms.append(arm)
	_t = phase


func _process(delta: float) -> void:
	var length := point_a.distance_to(point_b)
	if length < 0.1:
		return
	_t += delta * walk_speed / length
	var u := fmod(_t, 2.0)
	var forward := u < 1.0
	var t := u if forward else 2.0 - u
	position = point_a.lerp(point_b, t)
	var dir := (point_b - point_a).normalized() * (1.0 if forward else -1.0)
	dir.y = 0.0
	if dir.length() > 0.01:
		basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	var stride := sin(_t * length / walk_speed * 6.0 * walk_speed)
	_legs[0].rotation.x = stride * 0.5
	_legs[1].rotation.x = -stride * 0.5
	_arms[0].rotation.x = -stride * 0.4
	_arms[1].rotation.x = stride * 0.4
	_body.position.y = absf(stride) * 0.04
