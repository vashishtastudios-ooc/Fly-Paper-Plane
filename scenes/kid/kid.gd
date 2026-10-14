extends Node3D
## The kid on the balcony who throws the paper plane. Built from primitives.
## Faces local -Z. Call throw() to play the throw; `released` fires at the release point.

signal released(hand_position: Vector3)

const HOLD_ANGLE := 2.9
const WINDUP_ANGLE := 3.75
const RELEASE_ANGLE := 1.75
const FOLLOW_ANGLE := 0.9

@export var shirt_color := Color("#e8873a")
@export var shorts_color := Color("#3f5d8a")
@export var hair_color := Color("#6b3f22")
@export var skin_color := Color("#f1c9a5")

var _arm_r: Node3D
var _arm_l: Node3D
var _held: MeshInstance3D
var _body: Node3D
var _head: Node3D
var _throwing := false
var _t := 0.0
var _released := false


func _ready() -> void:
	if has_node("Model"):
		_body = get_node("Model")
	else:
		_build()
	reset()


func _build() -> void:
	var m := Mats.get_mat("solid")
	_body = Node3D.new()
	_body.name = "Model"
	add_child(_body)
	var b := MeshBuilder.new()
	# Legs and shoes.
	for sx in [-0.09, 0.09]:
		b.cylinder(m, Transform3D(Basis(), Vector3(sx, 0.08, 0)), 0.065, 0.07, 0.42, 7, skin_color)
		b.box(m, Transform3D(Basis(), Vector3(sx, 0.05, -0.04)), Vector3(0.12, 0.1, 0.22), Color("#e04a3a"))
		b.box(m, Transform3D(Basis(), Vector3(sx, 0.03, -0.04)), Vector3(0.125, 0.04, 0.23), Color("#fbf8f0"))
	# Shorts, t-shirt torso.
	b.cylinder(m, Transform3D(Basis(), Vector3(0, 0.46, 0)), 0.19, 0.18, 0.2, 10, shorts_color, true, true)
	b.cylinder(m, Transform3D(Basis(), Vector3(0, 0.64, 0)), 0.18, 0.2, 0.5, 10, shirt_color, true, true)
	b.sphere(m, Vector3(0, 1.12, 0), Vector3(0.2, 0.06, 0.16), 3, 10, shirt_color)
	_body.add_child(b.build_instance("Body"))
	# Head with hair, eyes and a smile.
	_head = Node3D.new()
	_head.position = Vector3(0, 1.32, 0)
	var hb := MeshBuilder.new()
	hb.cylinder(m, Transform3D(Basis(), Vector3(0, -0.2, 0)), 0.06, 0.06, 0.1, 6, skin_color)
	hb.sphere(m, Vector3.ZERO, Vector3(0.17, 0.19, 0.17), 6, 10, skin_color)
	hb.sphere(m, Vector3(0, 0.06, 0.02), Vector3(0.185, 0.16, 0.18), 5, 10, hair_color)
	hb.sphere(m, Vector3(0.05, 0.13, -0.12), Vector3(0.08, 0.05, 0.06), 3, 6, hair_color)
	for sx in [-0.06, 0.06]:
		hb.sphere(m, Vector3(sx, 0.01, -0.158), Vector3(0.022, 0.03, 0.012), 3, 6, Color("#2a2522"))
		hb.sphere(m, Vector3(sx * 1.5, -0.05, -0.14), Vector3(0.03, 0.02, 0.01), 3, 6, Color("#f0a0a0"))
	hb.box(m, Transform3D(Basis(), Vector3(0, -0.075, -0.162)), Vector3(0.06, 0.012, 0.01), Color("#a0453a"))
	hb.sphere(m, Vector3(-0.172, 0.0, 0), Vector3(0.03, 0.05, 0.035), 3, 6, skin_color)
	hb.sphere(m, Vector3(0.172, 0.0, 0), Vector3(0.03, 0.05, 0.035), 3, 6, skin_color)
	_head.add_child(hb.build_instance("Head"))
	_body.add_child(_head)
	# Arms (pivot at the shoulder, hanging down local -Y).
	_arm_r = _make_arm(Vector3(0.21, 1.08, 0))
	_arm_l = _make_arm(Vector3(-0.21, 1.08, 0))
	_held = MeshInstance3D.new()
	_held.name = "HeldPlane"
	_held.mesh = PaperPlaneMesh.get_mesh()
	_held.scale = Vector3.ONE * 0.55
	_held.position = Vector3(0, -0.5, -0.02)
	_arm_r.add_child(_held)


func _make_arm(shoulder: Vector3) -> Node3D:
	var m := Mats.get_mat("solid")
	var arm := Node3D.new()
	arm.position = shoulder
	var ab := MeshBuilder.new()
	ab.sphere(m, Vector3(0, -0.03, 0), Vector3(0.07, 0.07, 0.07), 3, 7, shirt_color)
	ab.cylinder(m, Transform3D(Basis(), Vector3(0, -0.44, 0)), 0.045, 0.05, 0.42, 6, skin_color)
	ab.sphere(m, Vector3(0, -0.47, 0), Vector3(0.055, 0.06, 0.055), 3, 6, skin_color)
	arm.add_child(ab.build_instance("Arm"))
	_body.add_child(arm)
	return arm


func reset() -> void:
	_throwing = false
	_released = false
	_t = 0.0
	if _held:
		_held.visible = true
	_pose_hold(0.0)


func throw() -> void:
	if _throwing:
		return
	_throwing = true
	_released = false
	_t = 0.0


func is_throwing() -> bool:
	return _throwing


## World position of the held plane (the launch point).
func hand_position() -> Vector3:
	if _held:
		return _held.global_position
	return global_position + Vector3(0, 1.3, 0)


func _pose_hold(time: float) -> void:
	if _arm_r == null:
		return
	_arm_r.rotation = Vector3(HOLD_ANGLE + sin(time * 2.0) * 0.05, 0, -0.15)
	_arm_l.rotation = Vector3(0.25 + sin(time * 1.6) * 0.05, 0, 0.12)
	_held.rotation = Vector3(-HOLD_ANGLE + 0.15, 0, 0)
	_body.position.y = sin(time * 2.0) * 0.008


func _process(delta: float) -> void:
	if _arm_r == null:
		return
	_t += delta
	if not _throwing:
		_pose_hold(_t)
		return
	# Wind-up 0.35 s, swing 0.18 s (release), follow-through 0.4 s.
	var a: float
	if _t < 0.35:
		a = lerpf(HOLD_ANGLE, WINDUP_ANGLE, smoothstep(0.0, 0.35, _t))
		_body.rotation.x = lerpf(0.0, 0.12, _t / 0.35)
	elif _t < 0.53:
		var k := (_t - 0.35) / 0.18
		a = lerpf(WINDUP_ANGLE, FOLLOW_ANGLE, k * k)
		_body.rotation.x = lerpf(0.12, -0.18, k)
	else:
		var k2 := clampf((_t - 0.53) / 0.6, 0.0, 1.0)
		a = lerpf(FOLLOW_ANGLE, 0.3, smoothstep(0.0, 1.0, k2))
		_body.rotation.x = lerpf(-0.18, 0.0, k2)
	_arm_r.rotation = Vector3(a, 0, -0.15)
	_arm_l.rotation = Vector3(0.25, 0, 0.12)
	if not _released:
		_held.rotation = Vector3(-a + 0.15, 0, 0)
		# Release at the right point of the swing, even if a slow frame skipped past it.
		if _t >= 0.35 and (a <= RELEASE_ANGLE or _t >= 0.5):
			if a < RELEASE_ANGLE:
				_arm_r.rotation.x = RELEASE_ANGLE
				_held.rotation.x = -RELEASE_ANGLE + 0.15
			_released = true
			var hp := hand_position()
			_held.visible = false
			released.emit(hp)
