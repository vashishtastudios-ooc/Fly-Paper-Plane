extends Prop
## A two-storey building on Market Street with an arched carriage passage through its ground
## floor ("Mill Lane"), leading to the millpond behind the shops.
## Origin = ground at the center of the facade, facade faces local +Z (like the shops).

@export var width := 13.0
@export var depth := 10.0
@export var height := 7.0
@export var wall_color := Color("#e9b7a1")
@export var lane_name := "Mill Lane"

## Passage: half width, the height its arch springs from, and the arch crown.
const HALF_W := 1.7
const SPRING_Y := 3.0
const CROWN_Y := 4.0
const SLICES := 10


func arch_y(x: float) -> float:
	var t := clampf(x / HALF_W, -1.0, 1.0)
	return SPRING_Y + (CROWN_Y - SPRING_Y) * sqrt(1.0 - t * t)


func _build(b: MeshBuilder) -> void:
	var brick := Mats.get_mat("brick")
	var stone := Mats.get_mat("stone")
	var solid := Mats.get_mat("solid")
	var hw := width * 0.5
	var stone_c := Color("#e6dccb")
	# The two sides of the building and the block over the passage.
	b.box_mm(brick, Vector3(-hw, 0, -depth), Vector3(-HALF_W, height, 0), Color.WHITE, 63 - 8)
	b.box_mm(brick, Vector3(HALF_W, 0, -depth), Vector3(hw, height, 0), Color.WHITE, 63 - 8)
	b.box_mm(brick, Vector3(-HALF_W, CROWN_Y, -depth), Vector3(HALF_W, height, 0), Color.WHITE, 63 - 8 - 4)
	# The vault: slices that follow the arch, with stone voussoirs on both faces.
	for i in SLICES:
		var x0 := lerpf(-HALF_W, HALF_W, float(i) / SLICES)
		var x1 := lerpf(-HALF_W, HALF_W, float(i + 1) / SLICES)
		var y := arch_y((x0 + x1) * 0.5)
		b.box_mm(stone, Vector3(x0, y, -depth), Vector3(x1, CROWN_Y, 0), stone_c.darkened(0.08), 63 - 4)
		for fz in [0.0, -depth]:
			b.box_mm(stone, Vector3(x0, y, fz - 0.02), Vector3(x1, y + 0.4, fz + 0.02), stone_c)
	# Stone jambs either side of the opening.
	for fz in [0.0, -depth]:
		b.box_mm(stone, Vector3(-HALF_W - 0.3, 0, fz - 0.02), Vector3(-HALF_W, SPRING_Y + 0.2, fz + 0.02), stone_c)
		b.box_mm(stone, Vector3(HALF_W, 0, fz - 0.02), Vector3(HALF_W + 0.3, SPRING_Y + 0.2, fz + 0.02), stone_c)
	# Cobbles through the passage.
	b.box_mm(stone, Vector3(-HALF_W, 0.0, -depth), Vector3(HALF_W, 0.03, 0), Color("#cbbfa8"), 4)
	# Parapet, cornice and flat roof.
	b.box_mm(brick, Vector3(-hw, height, -0.3), Vector3(hw, height + 0.55, 0), Color.WHITE, 63 - 8)
	b.box_mm(brick, Vector3(-hw, height, -depth), Vector3(hw, height + 0.55, -depth + 0.3), Color.WHITE, 63 - 8)
	b.box_mm(brick, Vector3(-hw, height, -depth), Vector3(-hw + 0.3, height + 0.55, 0), Color.WHITE, 63 - 8)
	b.box_mm(brick, Vector3(hw - 0.3, height, -depth), Vector3(hw, height + 0.55, 0), Color.WHITE, 63 - 8)
	b.box_mm(Mats.get_mat("gravel"), Vector3(-hw + 0.3, height - 0.05, -depth + 0.3), Vector3(hw - 0.3, height + 0.02, -0.3), Color("#b9b2a4"), 4)
	b.box_mm(solid, Vector3(-hw - 0.12, height + 0.5, -0.4), Vector3(hw + 0.12, height + 0.66, 0.2), Mats.TRIM)
	# Painted band and windows on both faces.
	for face in [1.0, -1.0]:
		var fz: float = 0.02 if face > 0 else -depth - 0.02
		b.box_mm(solid, Vector3(-hw, 4.35, fz - 0.03), Vector3(hw, 4.5, fz + 0.03), wall_color.darkened(0.15))


func _after_build() -> void:
	# Framed windows (the same ones as the shops), upstairs and either side of the arch.
	for face in [1.0, -1.0]:
		var xf := Transform3D(Basis(Vector3.UP, 0.0 if face > 0 else PI), Vector3(0, 0, 0.0 if face > 0 else -depth))
		for wx in [-4.6, -2.4, 2.4, 4.6]:
			inst("window", xf * Transform3D(Basis(), Vector3(wx, 5.6, 0.02)))
		for wx in [-4.4, 4.4]:
			inst("window", xf * Transform3D(Basis(), Vector3(wx, 1.9, 0.02)))
	for face in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = lane_name
		l.font = UIKit.display_font()
		l.font_size = 120
		l.pixel_size = 0.0045
		l.modulate = Color("#fbf3dc")
		l.outline_modulate = Color("#3a2c28")
		l.outline_size = 14
		l.shaded = false
		l.position = Vector3(0, CROWN_Y + 0.12, 0.06 if face > 0 else -depth - 0.06)
		l.rotation.y = 0.0 if face > 0 else PI
		add_child(l)


func _build_colliders() -> void:
	var hw := width * 0.5
	add_box("wall", Vector3((-hw - HALF_W) * 0.5, (height + 0.55) * 0.5, -depth * 0.5), Vector3(hw - HALF_W, height + 0.55, depth))
	add_box("wall", Vector3((hw + HALF_W) * 0.5, (height + 0.55) * 0.5, -depth * 0.5), Vector3(hw - HALF_W, height + 0.55, depth))
	add_box("wall", Vector3(0, (CROWN_Y + height + 0.55) * 0.5, -depth * 0.5), Vector3(HALF_W * 2.0, height + 0.55 - CROWN_Y, depth))
	for i in SLICES:
		var x0 := lerpf(-HALF_W, HALF_W, float(i) / SLICES)
		var x1 := lerpf(-HALF_W, HALF_W, float(i + 1) / SLICES)
		var y := minf(arch_y(x0), arch_y(x1))
		add_box("wall", Vector3((x0 + x1) * 0.5, (y + CROWN_Y) * 0.5, -depth * 0.5), Vector3(x1 - x0, CROWN_Y - y, depth))
