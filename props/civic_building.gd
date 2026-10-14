extends Prop
## Town Square buildings: library, market hall and hotel.
## Origin = ground at the center of the facade, facade faces local +Z.

## "library", "market_hall" or "hotel".
@export var style := "library"
@export var width := 22.0
@export var depth := 14.0
@export var wall_color := Color("#f5f0e5")
@export var roof_color := Color("#5b6270")
@export var sign_text := "Public Library"

var _height := 9.0


func _ready() -> void:
	match style:
		"library": _height = 9.5
		"market_hall": _height = 8.5
		"hotel": _height = 4.2 + 3 * 3.2
	super._ready()


func _build(b: MeshBuilder) -> void:
	match style:
		"library": _library(b)
		"market_hall": _market_hall(b)
		"hotel": _hotel(b)


func _library(b: MeshBuilder) -> void:
	var stone := Mats.get_mat("stone")
	var solid := Mats.get_mat("solid")
	var hw := width * 0.5
	var h := _height
	var sc := Color("#efe6d4")
	b.box_mm(stone, Vector3(-hw, 0, -depth), Vector3(hw, h, 0), sc, 63 - 8)
	b.box_mm(solid, Vector3(-hw - 0.3, h - 0.5, -depth - 0.3), Vector3(hw + 0.3, h, 0.3), Mats.TRIM)
	# Low hipped roof.
	b.pyramid(Mats.get_mat("shingle"), Transform3D(Basis(), Vector3(0, h, -depth * 0.5)), Vector2(width + 0.6, depth + 0.6), 2.4, roof_color)
	# Portico: steps, columns, entablature and pediment.
	var pw := 8.0
	var pd := 3.2
	for s in 4:
		b.box_mm(stone, Vector3(-pw * 0.5 - 0.6 + s * 0.15, 0, 0), Vector3(pw * 0.5 + 0.6 - s * 0.15, 0.2 + s * 0.2, pd + 1.2 - s * 0.35), sc)
	for i in 6:
		var x := lerpf(-pw * 0.5 + 0.4, pw * 0.5 - 0.4, i / 5.0)
		b.cylinder(stone, Transform3D(Basis(), Vector3(x, 0.8, pd - 0.3)), 0.32, 0.27, h - 2.2, 10, sc, true, true)
		b.box_mm(solid, Vector3(x - 0.42, h - 1.45, pd - 0.72), Vector3(x + 0.42, h - 1.3, pd + 0.12), Mats.TRIM)
	b.box_mm(solid, Vector3(-pw * 0.5, h - 1.3, 0), Vector3(pw * 0.5, h - 0.2, pd + 0.2), Mats.TRIM)
	var pt := Vector3(0, h + 1.8, pd + 0.2)
	b.poly(stone, PackedVector3Array([Vector3(-pw * 0.5 - 0.2, h - 0.2, pd + 0.2), Vector3(pw * 0.5 + 0.2, h - 0.2, pd + 0.2), pt]), sc)
	b.quad(Mats.get_mat("shingle"), Vector3(-pw * 0.5 - 0.3, h - 0.2, pd + 0.3), pt + Vector3(0, 0.1, 0.1), Vector3(0, h + 1.9, -0.5), Vector3(-pw * 0.5 - 0.3, h - 0.2, -0.5), roof_color)
	b.quad(Mats.get_mat("shingle"), pt + Vector3(0, 0.1, 0.1), Vector3(pw * 0.5 + 0.3, h - 0.2, pd + 0.3), Vector3(pw * 0.5 + 0.3, h - 0.2, -0.5), Vector3(0, h + 1.9, -0.5), roof_color)
	# Doors and tall windows.
	b.box_mm(solid, Vector3(-1.0, 1.0, -0.02), Vector3(1.0, 4.2, 0.06), Color("#2d4f7c"))
	for x in [-hw + 2.0, -hw + 4.5, hw - 4.5, hw - 2.0]:
		b.box_mm(Mats.get_mat("window_lit"), Vector3(x - 0.7, 1.4, -0.02), Vector3(x + 0.7, h - 2.2, 0.04), Color("#3d5a78"))
		b.box_mm(solid, Vector3(x - 0.85, h - 2.2, 0.0), Vector3(x + 0.85, h - 1.9, 0.12), Mats.TRIM)
		b.box_mm(solid, Vector3(x - 0.85, 1.2, 0.0), Vector3(x + 0.85, 1.4, 0.14), Mats.TRIM)


func _market_hall(b: MeshBuilder) -> void:
	var brick := Mats.get_mat("brick")
	var solid := Mats.get_mat("solid")
	var stone := Mats.get_mat("stone")
	var hw := width * 0.5
	var h := _height
	b.box_mm(brick, Vector3(-hw, 0, -depth), Vector3(hw, h, 0), Color.WHITE, 63 - 8)
	# Arcade of arches with stone surrounds.
	var arches := 6
	for i in arches:
		var x := lerpf(-hw + 2.2, hw - 2.2, float(i) / (arches - 1))
		b.box_mm(solid, Vector3(x - 1.1, 0, -0.02), Vector3(x + 1.1, 3.0, 0.04), Color("#3a2c28"))
		b.cylinder(solid, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 3.0, -0.02)), 1.1, 1.1, 0.06, 12, Color("#3a2c28"), true)
		b.box_mm(stone, Vector3(x - 1.35, 0, 0), Vector3(x - 1.1, 3.0, 0.14), Color("#e6dccb"))
		b.box_mm(stone, Vector3(x + 1.1, 0, 0), Vector3(x + 1.35, 3.0, 0.14), Color("#e6dccb"))
		# Upper windows.
		b.box_mm(Mats.get_mat("window_lit"), Vector3(x - 0.6, 5.0, -0.02), Vector3(x + 0.6, 7.0, 0.04), Color("#3d5a78"))
		b.box_mm(stone, Vector3(x - 0.75, 4.85, 0.0), Vector3(x + 0.75, 5.0, 0.14), Color("#e6dccb"))
	b.box_mm(stone, Vector3(-hw - 0.1, 4.2, -0.05), Vector3(hw + 0.1, 4.45, 0.12), Color("#e6dccb"))
	b.box_mm(stone, Vector3(-hw - 0.25, h - 0.35, -depth - 0.25), Vector3(hw + 0.25, h, 0.25), Color("#e6dccb"))
	# Hipped slate roof with a cupola.
	b.pyramid(Mats.get_mat("shingle"), Transform3D(Basis(), Vector3(0, h, -depth * 0.5)), Vector2(width + 0.5, depth + 0.5), 4.5, roof_color)
	var cy := h + 3.0
	b.box_mm(Mats.get_mat("paint"), Vector3(-1.2, cy, -depth * 0.5 - 1.2), Vector3(1.2, cy + 2.2, -depth * 0.5 + 1.2), Color("#f5f0e5"))
	b.pyramid(Mats.get_mat("metal"), Transform3D(Basis(), Vector3(0, cy + 2.2, -depth * 0.5)), Vector2(3.0, 3.0), 1.8, Color("#5e9a8c"))
	b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(), Vector3(0, cy + 4.0, -depth * 0.5)), 0.04, 0.02, 1.0, 4, Color("#d4a63a"))


func _hotel(b: MeshBuilder) -> void:
	var plaster := Mats.get_mat("plaster")
	var solid := Mats.get_mat("solid")
	var hw := width * 0.5
	var h := _height
	b.box_mm(plaster, Vector3(-hw, 0, -depth), Vector3(hw, h, 0), wall_color, 63 - 8)
	b.box_mm(Mats.get_mat("stone"), Vector3(-hw - 0.05, 0, -depth - 0.05), Vector3(hw + 0.05, 1.0, 0.05), Color("#d6cdbd"), 63 - 8)
	# Mansard roof.
	var m := 1.2
	var rh := 2.8
	var sh := Mats.get_mat("shingle")
	b.quad(sh, Vector3(-hw - 0.2, h, 0.2), Vector3(hw + 0.2, h, 0.2), Vector3(hw - m, h + rh, -m), Vector3(-hw + m, h + rh, -m), roof_color)
	b.quad(sh, Vector3(hw + 0.2, h, -depth - 0.2), Vector3(-hw - 0.2, h, -depth - 0.2), Vector3(-hw + m, h + rh, -depth + m), Vector3(hw - m, h + rh, -depth + m), roof_color)
	b.quad(sh, Vector3(hw + 0.2, h, 0.2), Vector3(hw + 0.2, h, -depth - 0.2), Vector3(hw - m, h + rh, -depth + m), Vector3(hw - m, h + rh, -m), roof_color)
	b.quad(sh, Vector3(-hw - 0.2, h, -depth - 0.2), Vector3(-hw - 0.2, h, 0.2), Vector3(-hw + m, h + rh, -m), Vector3(-hw + m, h + rh, -depth + m), roof_color)
	b.box_mm(Mats.get_mat("gravel"), Vector3(-hw + m, h + rh - 0.02, -depth + m), Vector3(hw - m, h + rh, -m), Color("#9aa3a8"), 4)
	b.box_mm(solid, Vector3(-hw - 0.25, h - 0.25, -depth - 0.25), Vector3(hw + 0.25, h, 0.25), Mats.TRIM)
	# Dormers.
	for i in 4:
		var x := lerpf(-hw + 2.5, hw - 2.5, i / 3.0)
		b.box_mm(Mats.get_mat("paint"), Vector3(x - 0.6, h + 0.6, -0.9), Vector3(x + 0.6, h + 2.0, -0.2), Mats.TRIM)
		b.box_mm(Mats.get_mat("window_lit"), Vector3(x - 0.4, h + 0.8, -0.2), Vector3(x + 0.4, h + 1.8, -0.16), Color("#3d5a78"))
	# Entrance canopy.
	b.box_mm(solid, Vector3(-1.8, 3.1, 0), Vector3(1.8, 3.3, 2.6), Color("#7a2f3b"))
	for x in [-1.6, 1.6]:
		b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(), Vector3(x, 0, 2.4)), 0.06, 0.06, 3.1, 6, Color("#c9a24a"))
	b.box_mm(solid, Vector3(-1.0, 0, -0.02), Vector3(1.0, 2.8, 0.06), Color("#5a2a32"))
	b.box_mm(Mats.get_mat("window_lit"), Vector3(-0.8, 0.4, 0.0), Vector3(0.8, 2.5, 0.08), Color("#4a6a86"))
	# Balconies with railings on upper floors.
	for f in 3:
		var y := 4.2 + f * 3.2
		for i in 4:
			var x := lerpf(-hw + 2.3, hw - 2.3, i / 3.0)
			b.box_mm(Mats.get_mat("window_lit"), Vector3(x - 0.55, y + 0.1, -0.02), Vector3(x + 0.55, y + 2.2, 0.04), Color("#3d5a78"))
			b.box_mm(solid, Vector3(x - 0.7, y + 2.2, 0.0), Vector3(x + 0.7, y + 2.4, 0.12), Mats.TRIM)
			b.box_mm(Mats.get_mat("stone"), Vector3(x - 0.9, y - 0.12, 0), Vector3(x + 0.9, y, 0.8), Color("#e6dccb"))
			b.box_mm(Mats.get_mat("metal"), Vector3(x - 0.9, y + 0.85, 0.74), Vector3(x + 0.9, y + 0.9, 0.8), Color("#2f3d36"))
			for k in 7:
				var xx := lerpf(x - 0.85, x + 0.85, k / 6.0)
				b.box_mm(Mats.get_mat("metal"), Vector3(xx - 0.015, y, 0.75), Vector3(xx + 0.015, y + 0.86, 0.79), Color("#2f3d36"))


func _after_build() -> void:
	var label := Label3D.new()
	label.text = sign_text
	label.font = UIKit.display_font()
	label.font_size = 120
	label.pixel_size = 0.008
	label.shaded = false
	label.modulate = Color("#3a3f4a") if style != "hotel" else Color("#c9a24a")
	match style:
		"library": label.position = Vector3(0, _height - 0.75, 3.45)
		"market_hall": label.position = Vector3(0, 3.75, 0.16)
		"hotel": label.position = Vector3(0, 3.55, 2.62)
	label.visibility_range_end = 160.0
	add_child(label)
	if style == "market_hall":
		# A few produce crates by the arches.
		for i in 5:
			var x := lerpf(-width * 0.5 + 2.0, width * 0.5 - 2.0, i / 4.0)
			inst("flowerbox", Transform3D(Basis(), Vector3(x, 0, 0.6)))


func _build_colliders() -> void:
	var hw := width * 0.5
	add_box("wall", Vector3(0, _height * 0.5, -depth * 0.5), Vector3(width, _height, depth))
	match style:
		"library":
			_roof_pyramid(Vector2(width + 0.6, depth + 0.6), 2.4)
			var pw := 8.0
			var pd := 3.2
			for i in 6:
				var x := lerpf(-pw * 0.5 + 0.4, pw * 0.5 - 0.4, i / 5.0)
				add_cylinder("wall", Vector3(x, 0.8, pd - 0.3), 0.28, _height - 2.2)
			add_box("wall", Vector3(0, _height - 0.75, pd * 0.5 + 0.1), Vector3(pw, 1.1, pd + 0.2))
			add_box("wall", Vector3(0, 0.4, (pd + 1.2) * 0.5), Vector3(pw + 1.2, 0.8, pd + 1.2))
		"market_hall":
			_roof_pyramid(Vector2(width + 0.5, depth + 0.5), 4.5)
			add_box("wall", Vector3(0, _height + 4.1, -depth * 0.5), Vector3(2.4, 2.2, 2.4))
		"hotel":
			var m := 1.2
			var rh := 2.8
			add_convex("wall", PackedVector3Array([
				Vector3(-hw - 0.2, _height, 0.2), Vector3(hw + 0.2, _height, 0.2), Vector3(-hw - 0.2, _height, -depth - 0.2), Vector3(hw + 0.2, _height, -depth - 0.2),
				Vector3(-hw + m, _height + rh, -m), Vector3(hw - m, _height + rh, -m), Vector3(-hw + m, _height + rh, -depth + m), Vector3(hw - m, _height + rh, -depth + m)]))
			add_box("wall", Vector3(0, 3.2, 1.3), Vector3(3.6, 0.2, 2.6))


func _roof_pyramid(base: Vector2, rise: float) -> void:
	var h := _height
	var zc := -depth * 0.5
	add_convex("wall", PackedVector3Array([
		Vector3(-base.x * 0.5, h, zc - base.y * 0.5), Vector3(base.x * 0.5, h, zc - base.y * 0.5),
		Vector3(-base.x * 0.5, h, zc + base.y * 0.5), Vector3(base.x * 0.5, h, zc + base.y * 0.5),
		Vector3(0, h + rise, zc)]))
