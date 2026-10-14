extends Prop
## Small rounded vintage car. Origin = ground center, facing local +Z.

@export var body_color := Color("#a9c9db")


func _build(b: MeshBuilder) -> void:
	var paint := Mats.get_mat("metal")
	var c := body_color
	var trim := Color("#f5f0e5")
	# Lower body with rounded ends.
	b.box_mm(paint, Vector3(-0.85, 0.32, -1.75), Vector3(0.85, 0.95, 1.75), c)
	for sz in [-1.0, 1.0]:
		b.cylinder(paint, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.85, 0.64, sz * 1.75)), 0.32, 0.32, 1.7, 10, c, true, true)
	# Cabin.
	var gl := Mats.get_mat("glass")
	b.box_mm(paint, Vector3(-0.78, 0.95, -0.9), Vector3(0.78, 1.0, 0.7), c)
	b.quad(gl, Vector3(-0.72, 1.0, 0.7), Vector3(0.72, 1.0, 0.7), Vector3(0.62, 1.55, 0.25), Vector3(-0.62, 1.55, 0.25), Color("#4a6a86"))
	b.quad(gl, Vector3(0.72, 1.0, -0.9), Vector3(-0.72, 1.0, -0.9), Vector3(-0.62, 1.55, -0.6), Vector3(0.62, 1.55, -0.6), Color("#4a6a86"))
	b.quad(gl, Vector3(0.72, 1.0, 0.7), Vector3(0.72, 1.0, -0.9), Vector3(0.62, 1.55, -0.6), Vector3(0.62, 1.55, 0.25), Color("#4a6a86"))
	b.quad(gl, Vector3(-0.72, 1.0, -0.9), Vector3(-0.72, 1.0, 0.7), Vector3(-0.62, 1.55, 0.25), Vector3(-0.62, 1.55, -0.6), Color("#4a6a86"))
	b.box_mm(paint, Vector3(-0.66, 1.55, -0.65), Vector3(0.66, 1.62, 0.3), trim)
	# Wheels, bumpers and lights.
	for sx in [-1.0, 1.0]:
		for sz in [-1.15, 1.15]:
			b.cylinder(Mats.get_mat("solid"), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * 0.95 if sx > 0 else -0.75, 0.32, sz)), 0.32, 0.32, 0.2, 10, Color("#2a2a2a"))
			b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * 0.97 if sx > 0 else -0.95, 0.32, sz)), 0.14, 0.14, 0.02, 8, trim)
	b.box_mm(paint, Vector3(-0.9, 0.3, 2.0), Vector3(0.9, 0.42, 2.12), Color("#d8d8d8"))
	b.box_mm(paint, Vector3(-0.9, 0.3, -2.12), Vector3(0.9, 0.42, -2.0), Color("#d8d8d8"))
	for sx in [-0.55, 0.55]:
		b.sphere(Mats.get_mat("window_lit"), Vector3(sx, 0.75, 2.02), Vector3(0.13, 0.13, 0.08), 3, 8, Color("#fff4d6"))
		b.box_mm(Mats.get_mat("glow"), Vector3(sx - 0.1, 0.7, -2.08), Vector3(sx + 0.1, 0.8, -2.04), Color("#e05a4a"))


func _build_colliders() -> void:
	add_box("car", Vector3(0, 0.63, 0), Vector3(1.7, 0.66, 4.2))
	add_box("car", Vector3(0, 1.28, -0.2), Vector3(1.4, 0.64, 1.4))


func _draw_distance() -> float:
	return 160.0
