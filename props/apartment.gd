extends Prop
## Skyline Apartments: a tall brick block with a flat roof (flight 8 launches from it). Origin =
## ground at the center of the footprint; the entrance faces local -Z (south, toward the town).
## The roof has a low parapet, a water tank, a stair hut and the building's name on the edge.

@export var width := 14.0
@export var depth := 12.0
@export var storeys := 10
@export var storey_height := 3.0
@export var wall_color := Color("#c9785a")
## How far the plinth reaches below the origin (the ground slopes here).
@export var plinth_depth := 2.0

const PARAPET := 0.75


func roof_y() -> float:
	return storeys * storey_height


func _build(b: MeshBuilder) -> void:
	var hw := width * 0.5
	var hd := depth * 0.5
	var top := roof_y()
	var brick := Mats.get_mat("brick")
	var stone := Mats.get_mat("stone")
	var solid := Mats.get_mat("solid")
	var metal := Mats.get_mat("metal")
	var stone_c := Color("#e6dccb")
	b.box_mm(stone, Vector3(-hw - 0.15, -plinth_depth, -hd - 0.15), Vector3(hw + 0.15, 0.8, hd + 0.15), stone_c, 63 - 8)
	b.box_mm(brick, Vector3(-hw, 0.8, -hd), Vector3(hw, top, hd), Color.WHITE, 63 - 8 - 4)
	# Stone bands between the storeys and a cornice.
	for s in range(1, storeys):
		var y := s * storey_height
		b.box_mm(stone, Vector3(-hw - 0.06, y - 0.08, -hd - 0.06), Vector3(hw + 0.06, y + 0.08, hd + 0.06), stone_c, 63 - 8)
	b.box_mm(stone, Vector3(-hw - 0.25, top - 0.3, -hd - 0.25), Vector3(hw + 0.25, top, hd + 0.25), stone_c)
	# Flat roof, parapet and coping.
	b.box_mm(Mats.get_mat("gravel"), Vector3(-hw + 0.2, top, -hd + 0.2), Vector3(hw - 0.2, top + 0.03, hd - 0.2), Color("#b9b2a4"), 4)
	for e in _parapets():
		b.box_mm(brick, e[0], e[1], Color.WHITE)
		b.box_mm(stone, Vector3(e[0].x - 0.03, e[1].y, e[0].z - 0.03), Vector3(e[1].x + 0.03, e[1].y + 0.06, e[1].z + 0.03), stone_c)
	# Water tank on legs (north end) and a stair hut.
	var tank := Vector3(-3.0, top, hd - 2.6)
	for lx in [-0.9, 0.9]:
		for lz in [-0.9, 0.9]:
			b.cylinder(metal, Transform3D(Basis(), tank + Vector3(lx, 0, lz)), 0.08, 0.08, 1.6, 6, Color("#5b6270"))
	b.cylinder(Mats.get_mat("wood"), Transform3D(Basis(), tank + Vector3(0, 1.6, 0)), 1.3, 1.3, 2.0, 14, Color("#a87a4f"))
	b.cylinder(metal, Transform3D(Basis(), tank + Vector3(0, 3.6, 0)), 1.4, 0.15, 0.7, 14, Color("#5b6270"))
	var hut := Vector3(3.2, top, hd - 2.2)
	b.box_mm(brick, hut + Vector3(-1.4, 0, -1.2), hut + Vector3(1.4, 2.5, 1.2), Color.WHITE)
	b.box_mm(solid, hut + Vector3(-1.5, 2.5, -1.3), hut + Vector3(1.5, 2.65, 1.3), stone_c)
	b.box_mm(solid, hut + Vector3(-0.45, 0, -1.22), hut + Vector3(0.45, 2.0, -1.2), Color("#2f5560"))
	# A few planters along the south parapet, and an aerial.
	for px in [-5.0, -3.6, 3.6, 5.0]:
		b.box_mm(Mats.get_mat("wood"), Vector3(px - 0.5, top, -hd + 0.3), Vector3(px + 0.5, top + 0.4, -hd + 0.8), Color("#8a6a52"))
		b.sphere(Mats.get_mat("foliage"), Vector3(px, top + 0.55, -hd + 0.55), Vector3(0.45, 0.3, 0.25), 3, 7, Color("#6f9e4c"))
	b.cylinder(metal, Transform3D(Basis(), Vector3(5.5, top, hd - 0.8)), 0.04, 0.03, 3.5, 5, Color("#9aa3a8"))
	# Entrance on the south face: double doors, a canopy and steps.
	b.box_mm(solid, Vector3(-1.2, 0.8, -hd - 0.04), Vector3(1.2, 3.2, -hd), Color("#2f5560"))
	b.box_mm(Mats.get_mat("window_lit"), Vector3(-1.0, 1.0, -hd - 0.06), Vector3(1.0, 2.9, -hd - 0.04), Color("#8fb8d6"))
	b.box_mm(solid, Vector3(-1.8, 3.3, -hd - 1.6), Vector3(1.8, 3.5, -hd), Mats.TRIM)
	for s in 3:
		b.box_mm(stone, Vector3(-1.8, -plinth_depth, -hd - 1.4 + s * 0.4), Vector3(1.8, 0.8 - s * 0.26, -hd), stone_c)


func _parapets() -> Array:
	var hw := width * 0.5
	var hd := depth * 0.5
	var top := roof_y()
	var t := 0.3
	return [
		[Vector3(-hw, top, -hd), Vector3(hw, top + PARAPET, -hd + t)],
		[Vector3(-hw, top, hd - t), Vector3(hw, top + PARAPET, hd)],
		[Vector3(-hw, top, -hd), Vector3(-hw + t, top + PARAPET, hd)],
		[Vector3(hw - t, top, -hd), Vector3(hw, top + PARAPET, hd)],
	]


func _after_build() -> void:
	var hw := width * 0.5
	var hd := depth * 0.5
	# Windows on every face of every storey above the ground floor.
	for s in range(1, storeys):
		var y := s * storey_height + 1.5
		for i in 5:
			var x := lerpf(-hw + 1.6, hw - 1.6, i / 4.0)
			inst("window", Transform3D(Basis(Vector3.UP, PI), Vector3(x, y, -hd - 0.02)))
			inst("window", Transform3D(Basis(), Vector3(x, y, hd + 0.02)))
		for i in 4:
			var z := lerpf(-hd + 1.6, hd - 1.6, i / 3.0)
			inst("window", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-hw - 0.02, y, z)))
			inst("window", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(hw + 0.02, y, z)))
	# The building's name along the top of the south face.
	var l := Label3D.new()
	l.text = "SKYLINE APARTMENTS"
	l.font = UIKit.ui_font()
	l.font_size = 160
	l.pixel_size = 0.006
	l.modulate = Color("#fbf3dc")
	l.outline_modulate = Color("#3a2c28")
	l.outline_size = 14
	l.shaded = false
	l.position = Vector3(0, roof_y() - 0.75, -hd - 0.07)
	l.rotation.y = PI
	add_child(l)


func _build_colliders() -> void:
	var hw := width * 0.5
	var hd := depth * 0.5
	var top := roof_y()
	add_box("wall", Vector3(0, (top - plinth_depth) * 0.5, 0), Vector3(width + 0.3, top + plinth_depth, depth + 0.3))
	for e in _parapets():
		add_box("wall", (e[0] + e[1]) * 0.5 + Vector3(0, 0.03, 0), e[1] - e[0] + Vector3(0, 0.06, 0))
	add_cylinder("post", Vector3(-3.0, top, hd - 2.6), 1.4, 4.3)
	add_box("wall", Vector3(3.2, top + 1.33, hd - 2.2), Vector3(3.0, 2.65, 2.6))
	add_box("wall", Vector3(0, 3.4, -hd - 0.8), Vector3(3.6, 0.2, 1.6))


func _draw_distance() -> float:
	return 700.0
