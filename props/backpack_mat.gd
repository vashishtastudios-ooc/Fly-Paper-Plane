extends Prop
## A blue gym mat in the schoolyard with a friend's open backpack and spilled school things.
## It is the landing target of the classroom level. Origin = ground at the mat center.

@export var size := 3.6
@export var top_height := 0.27


func _build(b: MeshBuilder) -> void:
	var solid := Mats.get_mat("solid")
	var cloth := Mats.get_mat("cloth")
	var h := size * 0.5
	var t := top_height
	# Padded mat with stitched panels.
	b.box_mm(Mats.get_mat("plaster"), Vector3(-h, 0.0, -h), Vector3(h, t, h), Color("#4f8fc8"), 63 - 8)
	for k in [-h / 3.0, h / 3.0]:
		b.box_mm(solid, Vector3(k - 0.02, t, -h), Vector3(k + 0.02, t + 0.005, h), Color("#3b74a8"), 4)
	# Open backpack lying on the mat.
	var bp := Vector3(0.7, t, -0.6)
	b.box_mm(Mats.get_mat("paint"), bp + Vector3(-0.35, 0, -0.25), bp + Vector3(0.35, 0.28, 0.25), Color("#c8423b"))
	b.box_mm(Mats.get_mat("paint"), bp + Vector3(-0.3, 0.0, -0.36), bp + Vector3(0.3, 0.2, -0.25), Color("#b53730"))
	b.quad(cloth, bp + Vector3(-0.35, 0.28, 0.25), bp + Vector3(0.35, 0.28, 0.25), bp + Vector3(0.35, 0.1, 0.7), bp + Vector3(-0.35, 0.1, 0.7), Color("#c8423b"))
	b.tube(Mats.get_mat("rope"), PackedVector3Array([bp + Vector3(-0.2, 0.28, 0.0), bp + Vector3(0, 0.45, 0.0), bp + Vector3(0.2, 0.28, 0.0)]), 0.025, 4, Color("#2a2a2a"))
	# Notebooks, a pencil case and pencils spilling out.
	var cols := [Color("#a9c9db"), Color("#f2d58f"), Color("#b9d6a8")]
	for i in 3:
		var p := Vector3(-0.4 + i * 0.35, t, 0.4 + i * 0.12)
		b.box(solid, Transform3D(Basis(Vector3.UP, 0.3 * i - 0.2), p + Vector3(0, 0.012 + i * 0.012, 0)), Vector3(0.3, 0.02, 0.4), cols[i])
	b.cylinder(solid, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.3, t + 0.06, 0.95)), 0.06, 0.06, 0.4, 8, Color("#7c4f9e"))
	for i in 3:
		b.cylinder(solid, Transform3D(Basis(Vector3.BACK, PI * 0.5).rotated(Vector3.UP, 0.4 * i), Vector3(-0.9 + i * 0.1, t + 0.01, -0.2 - i * 0.15)), 0.012, 0.012, 0.3, 6, Color(["#f2c14e", "#e8546a", "#6fb4e8"][i]))


func _casts_shadow() -> bool:
	return false


func _draw_distance() -> float:
	return 200.0
