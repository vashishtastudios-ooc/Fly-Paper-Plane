extends Pet
## A cat sitting on a landing spot, made of smooth rounded shapes: Pickle the ginger tabby
## (flight 1), Smokey the grey tabby, Snow the white cat and Domino the tuxedo cat. The tail tip flicks lazily and the ears twitch now and then; when the paper
## plane touches her she sits up, swishes her tail and flicks her ears.

## "ginger", "grey", "white" or "tuxedo".
@export var variant := "ginger"

const PALETTES := {
	"ginger": ["#e8964a", "#c76f2c", "#fbf3e6", "#7fbf4a"],
	"grey": ["#9aa0a8", "#6b717a", "#f2f0ea", "#e0b24a"],
	"white": ["#f6f3ee", "#e4ddd3", "#ffffff", "#6fb4e8"],
	"tuxedo": ["#33303a", "#2a2730", "#fbf8f0", "#8fd06a"],
}
const PINK := Color("#f2a0a8")
const BLACK := Color("#2a2522")

var FUR := Color("#e8964a")
var STRIPE := Color("#c76f2c")
var WHITE := Color("#fbf3e6")
var EYE := Color("#7fbf4a")

var _body: Node3D
var _tail: Node3D
var _tail_tip: Node3D
var _ears: Array[Node3D] = []


func _build(_b: MeshBuilder) -> void:
	var pal: Array = PALETTES.get(variant, PALETTES["ginger"])
	FUR = Color(pal[0])
	STRIPE = Color(pal[1])
	WHITE = Color(pal[2])
	EYE = Color(pal[3])
	_body = Node3D.new()
	_body.name = "Model"
	add_child(_body)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Haunches, upright body and a white chest.
	_sphere(st, Vector3(0, 0.13, -0.04), Vector3(0.15, 0.13, 0.17), FUR)
	for s in [-1.0, 1.0]:
		_sphere(st, Vector3(s * 0.1, 0.1, 0.0), Vector3(0.07, 0.1, 0.12), FUR)
		_sphere(st, Vector3(s * 0.11, 0.022, 0.07), Vector3(0.045, 0.025, 0.065), WHITE)
	_sphere(st, Vector3(0, 0.27, 0.03), Vector3(0.1, 0.17, 0.1), FUR, Basis(Vector3.RIGHT, 0.18))
	_sphere(st, Vector3(0, 0.27, 0.09), Vector3(0.065, 0.13, 0.05), WHITE, Basis(Vector3.RIGHT, 0.18))
	# Tabby stripes across the back.
	for k in 3:
		_sphere(st, Vector3(0, 0.2 + k * 0.07, -0.025 - k * 0.012), Vector3(0.102, 0.012, 0.075), STRIPE, Basis(Vector3.RIGHT, 0.18))
	# Slim front legs and white paws.
	for s in [-1.0, 1.0]:
		_capsule(st, Vector3(s * 0.05, 0.13, 0.1), 0.028, 0.26, FUR)
		_sphere(st, Vector3(s * 0.05, 0.02, 0.12), Vector3(0.035, 0.022, 0.045), WHITE)
	_body.add_child(_mesh_node(st, "BodyMesh"))
	# Head (a separate node so it can tilt), with cheeks, muzzle, nose, eyes and whiskers.
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.44, 0.06)
	_body.add_child(head)
	var hs := SurfaceTool.new()
	hs.begin(Mesh.PRIMITIVE_TRIANGLES)
	_sphere(hs, Vector3.ZERO, Vector3(0.105, 0.09, 0.095), FUR)
	for s in [-1.0, 1.0]:
		_sphere(hs, Vector3(s * 0.05, -0.03, 0.05), Vector3(0.055, 0.045, 0.05), FUR)
		_sphere(hs, Vector3(s * 0.042, 0.015, 0.082), Vector3(0.022, 0.026, 0.012), EYE)
		_sphere(hs, Vector3(s * 0.042, 0.015, 0.091), Vector3(0.007, 0.022, 0.006), BLACK)
		for w in [-1.0, 1.0]:
			_capsule(hs, Vector3(s * 0.085, -0.035 + w * 0.012, 0.075), 0.0025, 0.1, Color.WHITE, Basis(Vector3.BACK, s * (PI * 0.5 + w * 0.12)))
	_sphere(hs, Vector3(0, -0.04, 0.075), Vector3(0.04, 0.03, 0.035), WHITE)
	_sphere(hs, Vector3(0, -0.018, 0.1), Vector3(0.014, 0.01, 0.008), PINK)
	_sphere(hs, Vector3(0, 0.06, 0.04), Vector3(0.05, 0.015, 0.05), STRIPE)
	head.add_child(_mesh_node(hs, "HeadMesh"))
	# Pointed ears, each on its own pivot so they can twitch.
	for s in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.position = Vector3(s * 0.058, 0.06, 0.0)
		ear.rotation = Vector3(0, 0, -s * 0.3)
		var es := SurfaceTool.new()
		es.begin(Mesh.PRIMITIVE_TRIANGLES)
		_cone(es, Vector3.ZERO, 0.04, 0.085, FUR)
		_cone(es, Vector3(0, 0.005, 0.012), 0.025, 0.06, PINK)
		ear.add_child(_mesh_node(es, "EarMesh"))
		head.add_child(ear)
		_ears.append(ear)
	# The tail, curled round the side on the ground, with a tip that lifts and flicks.
	_tail = Node3D.new()
	_tail.name = "Tail"
	_tail.position = Vector3(0.06, 0.03, -0.18)
	var ts := SurfaceTool.new()
	ts.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curl := [Vector3(0, 0, 0), Vector3(0.1, 0, -0.03), Vector3(0.18, 0, 0.04), Vector3(0.21, 0, 0.14)]
	for i in curl.size():
		_sphere(ts, curl[i], Vector3(0.035, 0.032, 0.035), STRIPE if i % 2 == 1 else FUR)
		if i < curl.size() - 1:
			var a: Vector3 = curl[i]
			var b: Vector3 = curl[i + 1]
			_sphere(ts, (a + b) * 0.5, Vector3(0.034, 0.031, 0.034), FUR)
	_tail.add_child(_mesh_node(ts, "TailMesh"))
	_tail_tip = Node3D.new()
	_tail_tip.position = Vector3(0.21, 0, 0.14)
	var tt := SurfaceTool.new()
	tt.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var f := float(i + 1) / 4.0
		_sphere(tt, Vector3(0, f * 0.1, f * 0.03), Vector3.ONE * lerpf(0.032, 0.024, f), STRIPE if i == 3 else FUR)
	_tail_tip.add_child(_mesh_node(tt, "TipMesh"))
	_tail.add_child(_tail_tip)
	_body.add_child(_tail)


func _head_height() -> float:
	return 0.6


func _collider_size() -> Vector2:
	return Vector2(0.2, 0.56)


func _animate(h: float) -> void:
	if _body == null:
		return
	# Breathing, a lazy tail-tip flick and an occasional ear twitch; swishing and alert when happy.
	_body.scale = Vector3(1, 1.0 + 0.01 * sin(_t * 2.0), 1)
	_body.position.y = absf(sin(_t * 7.0)) * 0.025 * h
	var flick := sin(_t * lerpf(1.6, 11.0, h))
	_tail_tip.rotation = Vector3(lerpf(0.0, -0.5, h), 0, flick * lerpf(0.35, 0.9, h))
	_tail.rotation = Vector3(0, sin(_t * 9.0) * 0.35 * h, 0)
	var twitch := pow(maxf(0.0, sin(_t * 0.9)), 30.0)
	for i in _ears.size():
		var s := -1.0 if i == 0 else 1.0
		_ears[i].rotation = Vector3(-0.15 * h, 0, -s * (0.3 - 0.2 * twitch - 0.15 * h * absf(sin(_t * 12.0))))
	var head := _body.get_node("Head") as Node3D
	head.rotation = Vector3(-0.1 * h, sin(_t * 0.5) * 0.15 * (1.0 - h), sin(_t * 3.0) * 0.12 * h)
