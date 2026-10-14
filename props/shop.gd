extends Prop
## Market Street shop with a striped awning and a painted signboard.
## Origin = ground at the center of the facade, facade faces local +Z.

@export var width := 11.0
@export var depth := 10.0
@export var storeys := 2
@export var ground_height := 3.8
@export var upper_height := 3.2
@export var wall_color := Color("#f2d58f")
## "paint", "plaster" or "brick".
@export var wall_kind := "plaster"
@export var front_color := Color("#2f5560")
@export var awning_a := Color("#c8423b")
@export var awning_b := Color("#f7eedd")
@export var sign_text := "Shop"
@export var sign_text_color := Color("#fbf3dc")
@export var shutter_color := Color("#3f6f8f")
@export var seed_value := 1


func roof_height() -> float:
	return ground_height + (storeys - 1) * upper_height


func _build(b: MeshBuilder) -> void:
	var hw := width * 0.5
	var rh := roof_height()
	var solid := Mats.get_mat("solid")
	var trim := Mats.TRIM
	var wall_mat := Mats.get_mat(wall_kind)
	var wc := wall_color if wall_kind != "brick" else Color.WHITE
	b.box_mm(wall_mat, Vector3(-hw, 0, -depth), Vector3(hw, rh, 0), wc, 63 - 8 - 4)
	# Parapet, cornice and flat roof.
	b.box_mm(wall_mat, Vector3(-hw, rh, -0.3), Vector3(hw, rh + 0.55, 0), wc, 63 - 8)
	b.box_mm(wall_mat, Vector3(-hw, rh, -depth), Vector3(hw, rh + 0.55, -depth + 0.3), wc, 63 - 8)
	b.box_mm(wall_mat, Vector3(-hw, rh, -depth), Vector3(-hw + 0.3, rh + 0.55, 0), wc, 63 - 8)
	b.box_mm(wall_mat, Vector3(hw - 0.3, rh, -depth), Vector3(hw, rh + 0.55, 0), wc, 63 - 8)
	b.box_mm(Mats.get_mat("gravel"), Vector3(-hw + 0.3, rh - 0.05, -depth + 0.3), Vector3(hw - 0.3, rh + 0.02, -0.3), Color("#b9b2a4"), 4)
	b.box_mm(solid, Vector3(-hw - 0.12, rh + 0.5, -0.4), Vector3(hw + 0.12, rh + 0.66, 0.2), trim)
	b.box_mm(solid, Vector3(-hw - 0.08, rh - 0.3, -0.1), Vector3(hw + 0.08, rh - 0.1, 0.14), trim)
	# Floor band between storeys.
	for s in range(1, storeys):
		var y := ground_height + (s - 1) * upper_height
		b.box_mm(solid, Vector3(-hw - 0.04, y - 0.1, -0.05), Vector3(hw + 0.04, y + 0.1, 0.08), trim)
	# Roof hatch and a little vent so the roof isn't empty.
	b.box_mm(Mats.get_mat("metal"), Vector3(-hw + 1.5, rh, -depth + 2), Vector3(-hw + 2.4, rh + 0.6, -depth + 2.9), Color("#9aa3a8"))

	# Shopfront: pilasters, fascia sign, display window and door.
	var fc := front_color
	b.box_mm(solid, Vector3(-hw, 0, 0), Vector3(-hw + 0.45, ground_height - 0.2, 0.18), fc)
	b.box_mm(solid, Vector3(hw - 0.45, 0, 0), Vector3(hw, ground_height - 0.2, 0.18), fc)
	b.box_mm(solid, Vector3(-hw + 0.2, ground_height - 1.05, 0), Vector3(hw - 0.2, ground_height - 0.2, 0.22), fc)
	b.box_mm(solid, Vector3(-hw + 0.45, 0, 0), Vector3(hw - 0.45, 0.55, 0.12), fc)
	b.box_mm(Mats.get_mat("window_lit"), Vector3(-hw + 0.45, 0.55, -0.02), Vector3(hw - 0.45, ground_height - 1.05, 0.04), Color("#4a6a86"))
	var door_x := hw - 1.6
	b.box_mm(solid, Vector3(door_x - 0.6, 0, -0.01), Vector3(door_x + 0.6, 2.4, 0.09), fc.darkened(0.25))
	b.box_mm(Mats.get_mat("window_lit"), Vector3(door_x - 0.45, 1.0, 0.0), Vector3(door_x + 0.45, 2.2, 0.1), Color("#4a6a86"))
	# Mullions.
	var n := 4
	for i in range(1, n):
		var x := lerpf(-hw + 0.45, door_x - 0.6, float(i) / n)
		b.box_mm(solid, Vector3(x - 0.04, 0.55, 0.0), Vector3(x + 0.04, ground_height - 1.05, 0.08), fc)
	b.box_mm(solid, Vector3(door_x - 0.66, 0.55, 0.0), Vector3(door_x - 0.6, ground_height - 1.05, 0.1), fc)

	# Striped awning.
	var stripes := int(width / 0.55)
	var top_y := ground_height - 1.15
	var low_y := ground_height - 2.05
	var out := 1.7
	for i in stripes:
		var x0 := lerpf(-hw + 0.3, hw - 0.3, float(i) / stripes)
		var x1 := lerpf(-hw + 0.3, hw - 0.3, float(i + 1) / stripes)
		var c := awning_a if i % 2 == 0 else awning_b
		var cl := Mats.get_mat("cloth")
		b.quad(cl, Vector3(x0, low_y, out), Vector3(x1, low_y, out), Vector3(x1, top_y, 0.15), Vector3(x0, top_y, 0.15), c)
		# Scalloped valance.
		b.poly(cl, PackedVector3Array([Vector3(x0, low_y, out), Vector3((x0 + x1) * 0.5, low_y - 0.28, out), Vector3(x1, low_y, out)]), c)
		b.quad(cl, Vector3(x0, low_y - 0.12, out), Vector3(x1, low_y - 0.12, out), Vector3(x1, low_y, out), Vector3(x0, low_y, out), c)
	for sx in [-hw + 0.35, hw - 0.35]:
		b.box_mm(Mats.get_mat("metal"), Vector3(sx - 0.02, low_y, 0.1), Vector3(sx + 0.02, top_y, out), Color("#3a3a3a"))


func _after_build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 17 + 3
	var hw := width * 0.5
	for s in range(1, storeys):
		var y := ground_height + (s - 1) * upper_height + 1.55
		var count := 3 if width > 9.0 else 2
		for i in count:
			var x := lerpf(-hw + 1.8, hw - 1.8, float(i) / (count - 1))
			inst("window", Transform3D(Basis(), Vector3(x, y, 0.02)))
			if rng.randf() < 0.7:
				inst("flowerbox", Transform3D(Basis(), Vector3(x, y - 0.95, 0.14)))
			if rng.randf() < 0.5:
				inst("shutter", Transform3D(Basis(), Vector3(x - 0.76, y, 0.06)), shutter_color)
				inst("shutter", Transform3D(Basis(), Vector3(x + 0.76, y, 0.06)), shutter_color)
	# Signboard text.
	var label := Label3D.new()
	label.name = "Sign"
	label.text = sign_text
	label.font = UIKit.display_font()
	label.font_size = 96
	label.outline_size = 0
	label.pixel_size = 0.0055
	label.modulate = sign_text_color
	label.position = Vector3(0, ground_height - 0.62, 0.235)
	label.double_sided = false
	label.shaded = false
	label.width = (width - 1.2) / label.pixel_size
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.visibility_range_end = 140.0
	add_child(label)


func _build_colliders() -> void:
	var rh := roof_height()
	add_box("wall", Vector3(0, (rh + 0.55) * 0.5, -depth * 0.5), Vector3(width, rh + 0.55, depth))
	add_box("wall", Vector3(0, ground_height - 1.6, 0.9), Vector3(width - 0.6, 0.9, 1.8))
