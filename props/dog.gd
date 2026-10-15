extends Pet
## A friendly sitting dog made of smooth rounded shapes: Biscuit the golden dog (flight 7, in his
## bed in the den), Pepper the black-and-white collie, Bramble the beagle and Marshmallow the
## white dog. The tail wags
## gently all the time, and happily (with a little bounce) when the paper plane touches the dog.

## "golden", "collie", "beagle" or "white".
@export var variant := "golden"

## Fur, pale parts, ears, collar and (for the beagle) the dark saddle on the back.
const PALETTES := {
	"golden": ["#d9a066", "#f6e2c2", "#8a5a32", "#c8423b", ""],
	"collie": ["#34303a", "#fbf8f0", "#34303a", "#2f6f8f", ""],
	"beagle": ["#c98a4b", "#fbf8f0", "#6b4429", "#3f7d4f", "#3a2c24"],
	"white": ["#f4f1ea", "#ffffff", "#d9cfc2", "#e8546a", ""],
}
const BLACK := Color("#2a2522")

var FUR := Color("#d9a066")
var LIGHT := Color("#f6e2c2")
var DARK := Color("#8a5a32")
var COLLAR := Color("#c8423b")

var _tail: Node3D
var _body: MeshInstance3D


func _build(_b: MeshBuilder) -> void:
	var pal: Array = PALETTES.get(variant, PALETTES["golden"])
	FUR = Color(pal[0])
	LIGHT = Color(pal[1])
	DARK = Color(pal[2])
	COLLAR = Color(pal[3])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if pal[4] != "":
		# The beagle's dark saddle across the back.
		_sphere(st, Vector3(0, 0.36, -0.05), Vector3(0.172, 0.17, 0.2), Color(pal[4]), Basis(Vector3.RIGHT, 0.22))
	# Seated rump and thighs.
	_sphere(st, Vector3(0, 0.24, -0.08), Vector3(0.24, 0.24, 0.27), FUR)
	for s in [-1.0, 1.0]:
		_sphere(st, Vector3(s * 0.16, 0.17, -0.0), Vector3(0.11, 0.16, 0.19), FUR)
		_sphere(st, Vector3(s * 0.17, 0.035, 0.08), Vector3(0.065, 0.04, 0.1), LIGHT)
	# Upright chest and a pale bib.
	_sphere(st, Vector3(0, 0.47, 0.05), Vector3(0.17, 0.27, 0.17), FUR, Basis(Vector3.RIGHT, 0.22))
	_sphere(st, Vector3(0, 0.47, 0.15), Vector3(0.11, 0.19, 0.08), LIGHT, Basis(Vector3.RIGHT, 0.22))
	# Front legs and paws.
	for s in [-1.0, 1.0]:
		_capsule(st, Vector3(s * 0.085, 0.22, 0.16), 0.048, 0.42, FUR)
		_sphere(st, Vector3(s * 0.085, 0.032, 0.2), Vector3(0.058, 0.036, 0.075), LIGHT)
	# Neck, head, muzzle, nose, tongue, eyes and floppy ears.
	_sphere(st, Vector3(0, 0.66, 0.09), Vector3(0.11, 0.13, 0.11), FUR)
	_sphere(st, Vector3(0, 0.79, 0.12), Vector3(0.145, 0.135, 0.15), FUR)
	_sphere(st, Vector3(0, 0.745, 0.245), Vector3(0.075, 0.062, 0.1), LIGHT)
	_sphere(st, Vector3(0, 0.775, 0.34), Vector3(0.03, 0.024, 0.02), BLACK)
	_sphere(st, Vector3(0, 0.705, 0.29), Vector3(0.03, 0.012, 0.04), Color("#e8788a"))
	for s in [-1.0, 1.0]:
		_sphere(st, Vector3(s * 0.062, 0.825, 0.245), Vector3(0.024, 0.026, 0.016), BLACK)
		_sphere(st, Vector3(s * 0.058, 0.833, 0.258), Vector3(0.007, 0.007, 0.004), Color.WHITE)
		_sphere(st, Vector3(s * 0.135, 0.765, 0.1), Vector3(0.035, 0.12, 0.075), DARK, Basis(Vector3.BACK, s * 0.28))
	# Red collar with a gold tag.
	var collar := TorusMesh.new()
	collar.inner_radius = 0.1
	collar.outer_radius = 0.125
	collar.rings = 20
	collar.ring_segments = 8
	_part(st, collar, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, 0.655, 0.095)), COLLAR)
	_sphere(st, Vector3(0, 0.59, 0.2), Vector3(0.025, 0.025, 0.012), Color("#e0b24a"))
	_body = _mesh_node(st, "Model")
	add_child(_body)
	# The tail: a curve of shrinking balls on a pivot at the base, so it can wag.
	_tail = Node3D.new()
	_tail.name = "Tail"
	_tail.position = Vector3(0, 0.12, -0.32)
	var ts := SurfaceTool.new()
	ts.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var f := float(i) / 6.0
		var p := Vector3(0, 0.03 + f * 0.24 + sin(f * PI) * 0.02, -0.04 - sin(f * PI * 0.8) * 0.14)
		var r := lerpf(0.05, 0.028, f)
		_sphere(ts, p, Vector3(r, r, r), LIGHT if i == 6 else FUR)
	_tail.add_child(_mesh_node(ts, "TailMesh"))
	add_child(_tail)


func _head_height() -> float:
	return 0.95


func _collider_size() -> Vector2:
	return Vector2(0.27, 0.92)


func _animate(h: float) -> void:
	var amp := lerpf(0.22, 0.8, h)
	var speed := lerpf(4.0, 17.0, h)
	if _tail:
		_tail.rotation = Vector3(0.15 + 0.15 * h, sin(_t * speed) * amp, sin(_t * speed) * amp * 0.25)
	if _body:
		# Breathing, and a happy little bounce.
		_body.scale = Vector3(1, 1.0 + 0.012 * sin(_t * 2.4), 1)
		_body.position.y = absf(sin(_t * 8.0)) * 0.03 * h
		_tail.position.y = 0.12 + _body.position.y
