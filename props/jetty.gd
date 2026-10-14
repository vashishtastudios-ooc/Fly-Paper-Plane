extends Prop
## Wooden fishing jetty. Origin = center of the deck top surface.

@export var half_width := 2.25
@export var half_length := 4.5
## How far below the deck the posts reach (to the river bed).
@export var post_depth := 2.2


func _build(b: MeshBuilder) -> void:
	var wood := Mats.get_mat("wood")
	var plank := Color("#b48a64")
	var n := 18
	for i in n:
		var z0 := lerpf(-half_length, half_length, float(i) / n) + 0.02
		var z1 := lerpf(-half_length, half_length, float(i + 1) / n) - 0.02
		var tint := plank.darkened(0.06 * float(i % 3))
		b.box_mm(wood, Vector3(-half_width, -0.12, z0), Vector3(half_width, 0.0, z1), tint)
	for sx in [-1.0, 1.0]:
		b.box_mm(wood, Vector3(sx * half_width - 0.1, -0.32, -half_length), Vector3(sx * half_width + 0.1, -0.12, half_length), plank.darkened(0.2))
		for k in 4:
			var z := lerpf(-half_length + 0.2, half_length - 0.2, k / 3.0)
			var top := 0.75 if absf(z) > half_length - 0.5 else -0.05
			b.cylinder(wood, Transform3D(Basis(), Vector3(sx * half_width, -post_depth, z)), 0.13, 0.13, post_depth + top, 8, Color("#8a6a52"))
	# Bucket, rod and a coil of rope at the river end.
	b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(), Vector3(-1.4, 0, half_length - 0.8)), 0.16, 0.2, 0.32, 10, Color("#5e8fa8"))
	b.cylinder(Mats.get_mat("solid"), Transform3D(Basis(Vector3.RIGHT, -1.1), Vector3(1.2, 0.05, half_length - 1.5)), 0.02, 0.008, 2.8, 4, Color("#6b4a32"))
	b.cylinder(Mats.get_mat("rope"), Transform3D(Basis(), Vector3(1.5, 0, -half_length + 0.7)), 0.3, 0.3, 0.12, 10, Color("#d8c39a"))


func _build_colliders() -> void:
	add_box("post", Vector3(0, -0.25, 0), Vector3(half_width * 2.0, 0.3, half_length * 2.0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			add_cylinder("post", Vector3(sx * half_width, -post_depth, sz * (half_length - 0.2)), 0.15, post_depth + 0.75)


func _draw_distance() -> float:
	return 160.0
