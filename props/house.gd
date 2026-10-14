extends Prop
## Two-story clapboard house. Origin = ground level at the center of the front facade.
## The facade faces local +Z; the house body extends toward -Z.

@export var width := 10.0
@export var depth := 9.0
@export var storeys := 2
@export var storey_height := 3.4
@export var plinth := 0.6
@export var wall_color := Color("#e9b7a1")
@export var roof_color := Color("#5b6270")
@export var door_color := Color("#c8423b")
@export var shutter_color := Color("#3f6f8f")
@export var has_porch := true
@export var porch_offset := 0.0
@export var has_chimney := true
## Chimney position in local XZ.
@export var chimney_pos := Vector2(-3.0, -6.0)
## 0 = no balcony. Otherwise the height of the upstairs balcony floor.
@export var balcony_height := 0.0
@export var balcony_offset := 0.0
## Distance from the facade to the sidewalk edge and to the curb.
@export var yard_depth := 9.0
@export var curb_distance := 12.0
## "picket", "hedge" or "none".
@export var fence_style := "picket"
@export var seed_value := 1

var wall_height: float
var roof_rise: float


func _wall_h() -> float:
	return plinth + storeys * storey_height


func _build(b: MeshBuilder) -> void:
	wall_height = _wall_h()
	roof_rise = depth * 0.36
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var paint := Mats.get_mat("paint")
	var solid := Mats.get_mat("solid")
	var stone := Mats.get_mat("stone")
	var wood := Mats.get_mat("wood")
	var trim := Mats.TRIM
	var hw := width * 0.5
	var zc := -depth * 0.5

	# Foundation, walls, corner boards and frieze.
	b.box_mm(stone, Vector3(-hw - 0.06, 0, -depth - 0.06), Vector3(hw + 0.06, plinth, 0.06), Color("#d6cdbd"), 63 - 8)
	b.box_mm(paint, Vector3(-hw, plinth, -depth), Vector3(hw, wall_height, 0), wall_color, 63 - 8 - 4)
	for cx in [-hw, hw]:
		for cz in [0.0, -depth]:
			b.box_at(solid, Vector3(cx, (plinth + wall_height) * 0.5, cz), Vector3(0.2, wall_height - plinth, 0.2), trim)
	b.box_mm(solid, Vector3(-hw - 0.05, wall_height - 0.3, -0.04), Vector3(hw + 0.05, wall_height, 0.08), trim)
	b.box_mm(solid, Vector3(-hw - 0.05, wall_height - 0.3, -depth - 0.08), Vector3(hw + 0.05, wall_height, -depth + 0.04), trim)
	b.box_mm(solid, Vector3(-hw - 0.04, plinth + storey_height - 0.08, -0.03), Vector3(hw + 0.04, plinth + storey_height + 0.08, 0.05), trim)

	# Gable ends and roof (ridge runs along local X, parallel to the street).
	var r := Basis(Vector3.UP, PI * 0.5)
	var roof_xf := Transform3D(r, Vector3(0, wall_height, zc))
	b.gable_wall(paint, roof_xf, depth, roof_rise, hw, 1.0, wall_color)
	b.gable_wall(paint, roof_xf, depth, roof_rise, -hw, -1.0, wall_color)
	b.gable_roof(Mats.get_mat("shingle"), roof_xf, depth, width, roof_rise, 0.45, 0.18, roof_color)
	# Small round attic window in each gable.
	for sx in [-1.0, 1.0]:
		b.cylinder(Mats.get_mat("window_lit"), Transform3D(Basis(Vector3.BACK, sx * PI * 0.5), Vector3(sx * (hw + 0.02), wall_height + roof_rise * 0.4, zc)), 0.32, 0.32, 0.06, 10, Color("#3d5a78"))
		b.cylinder(solid, Transform3D(Basis(Vector3.BACK, sx * PI * 0.5), Vector3(sx * (hw + 0.0), wall_height + roof_rise * 0.4, zc)), 0.4, 0.4, 0.04, 10, trim)

	if has_chimney:
		var cp := Vector3(chimney_pos.x, 0, chimney_pos.y)
		var top := wall_height + roof_rise + 1.0
		b.box_mm(Mats.get_mat("brick"), Vector3(cp.x - 0.45, wall_height - 0.5, cp.z - 0.45), Vector3(cp.x + 0.45, top, cp.z + 0.45), Color.WHITE)
		b.box_mm(stone, Vector3(cp.x - 0.55, top, cp.z - 0.55), Vector3(cp.x + 0.55, top + 0.14, cp.z + 0.55), Color("#cfc6b6"))

	# Door with frame, transom and steps (or porch).
	var dx := porch_offset
	b.box_mm(solid, Vector3(dx - 0.55, plinth, -0.02), Vector3(dx + 0.55, plinth + 2.25, 0.07), door_color)
	b.box_mm(solid, Vector3(dx - 0.72, plinth, 0.0), Vector3(dx - 0.58, plinth + 2.55, 0.12), trim)
	b.box_mm(solid, Vector3(dx + 0.58, plinth, 0.0), Vector3(dx + 0.72, plinth + 2.55, 0.12), trim)
	b.box_mm(solid, Vector3(dx - 0.78, plinth + 2.55, 0.0), Vector3(dx + 0.78, plinth + 2.72, 0.16), trim)
	b.box_mm(Mats.get_mat("window_lit"), Vector3(dx - 0.55, plinth + 2.27, -0.01), Vector3(dx + 0.55, plinth + 2.53, 0.03), Color("#3d5a78"))
	b.box_mm(Mats.get_mat("metal"), Vector3(dx + 0.32, plinth + 1.0, 0.06), Vector3(dx + 0.38, plinth + 1.12, 0.12), Color("#e0b24a"))

	if has_porch:
		var pw := 2.3
		var pd := 2.4
		b.box_mm(wood, Vector3(dx - pw, plinth - 0.12, 0), Vector3(dx + pw, plinth, pd), Color("#c9a27e"))
		b.box_mm(stone, Vector3(dx - pw, 0, 0), Vector3(dx + pw, plinth - 0.12, pd), Color("#d6cdbd"), 63 - 8)
		for px in [dx - pw + 0.12, dx + pw - 0.12]:
			b.box_mm(solid, Vector3(px - 0.08, plinth, pd - 0.24), Vector3(px + 0.08, plinth + 2.8, pd - 0.08), trim)
		# Porch roof.
		var pr := Transform3D(Basis(Vector3.RIGHT, 0.22), Vector3(dx, plinth + 3.05, pd * 0.5 - 0.05))
		b.box(Mats.get_mat("shingle"), pr, Vector3(pw * 2 + 0.4, 0.12, pd + 0.6), roof_color)
		b.box_mm(solid, Vector3(dx - pw - 0.1, plinth + 2.78, pd - 0.3), Vector3(dx + pw + 0.1, plinth + 2.92, pd), trim)
		# Railing.
		for side in [-1.0, 1.0]:
			var x0: float = dx + side * 0.75
			var x1: float = dx + side * (pw - 0.1)
			b.box_mm(solid, Vector3(minf(x0, x1), plinth + 0.82, pd - 0.18), Vector3(maxf(x0, x1), plinth + 0.9, pd - 0.1), trim)
			var n := 6
			for i in n:
				var xx := lerpf(x0, x1, (i + 0.5) / n)
				b.box_mm(solid, Vector3(xx - 0.025, plinth, pd - 0.16), Vector3(xx + 0.025, plinth + 0.84, pd - 0.12), trim)
		for s in 3:
			b.box_mm(stone, Vector3(dx - 0.7, 0, pd + s * 0.3), Vector3(dx + 0.7, plinth - s * 0.2, pd + s * 0.3 + 0.3), Color("#d6cdbd"))
	else:
		for s in 3:
			b.box_mm(stone, Vector3(dx - 0.8, 0, s * 0.3), Vector3(dx + 0.8, plinth - s * 0.2, s * 0.3 + 0.3), Color("#d6cdbd"))

	if balcony_height > 0.0:
		_build_balcony(b)

	# Front path to the sidewalk.
	var path_start := 2.4 + 0.9 if has_porch else 0.9
	b.box_mm(Mats.get_mat("paving"), Vector3(dx - 0.6, 0.0, path_start), Vector3(dx + 0.6, 0.04, yard_depth), Color("#e8e1d3"), 4)

	# Fence rails.
	if fence_style == "picket":
		var fz := yard_depth - 0.45
		for seg in _fence_segments():
			b.box_mm(solid, Vector3(seg.x, 0.3, fz - 0.03), Vector3(seg.y, 0.38, fz - 0.01), trim)
			b.box_mm(solid, Vector3(seg.x, 0.7, fz - 0.03), Vector3(seg.y, 0.78, fz - 0.01), trim)
			for px in [seg.x, seg.y]:
				b.box_mm(solid, Vector3(px - 0.06, 0, fz - 0.06), Vector3(px + 0.06, 1.05, fz + 0.06), trim)


func _build_balcony(b: MeshBuilder) -> void:
	var solid := Mats.get_mat("solid")
	var trim := Mats.TRIM
	var y := balcony_height
	var bx := balcony_offset
	var bd := 1.6
	var bw := 1.4
	b.box_mm(Mats.get_mat("stone"), Vector3(bx - bw, y - 0.18, 0), Vector3(bx + bw, y, bd), Color("#e6dccb"))
	b.box_mm(Mats.get_mat("wood"), Vector3(bx - bw + 0.05, y, 0.02), Vector3(bx + bw - 0.05, y + 0.02, bd - 0.05), Color("#c9a27e"), 4)
	# Brackets.
	for sx in [-bw + 0.25, bw - 0.25]:
		b.poly(solid, PackedVector3Array([Vector3(bx + sx, y - 0.18, 0.02), Vector3(bx + sx, y - 0.18, bd * 0.7), Vector3(bx + sx, y - 0.9, 0.02)]), trim)
	# Railing on three sides.
	var h := 1.0
	b.box_mm(solid, Vector3(bx - bw, y + h - 0.07, bd - 0.1), Vector3(bx + bw, y + h, bd), trim)
	b.box_mm(solid, Vector3(bx - bw, y + h - 0.07, 0), Vector3(bx - bw + 0.1, y + h, bd), trim)
	b.box_mm(solid, Vector3(bx + bw - 0.1, y + h - 0.07, 0), Vector3(bx + bw, y + h, bd), trim)
	var n := 12
	for i in n + 1:
		var xx := lerpf(bx - bw + 0.05, bx + bw - 0.05, float(i) / n)
		b.box_mm(solid, Vector3(xx - 0.025, y, bd - 0.08), Vector3(xx + 0.025, y + h, bd - 0.03), trim)
	for i in 4:
		var zz := lerpf(0.2, bd - 0.1, float(i) / 3.0)
		for sx in [bx - bw + 0.05, bx + bw - 0.05]:
			b.box_mm(solid, Vector3(sx - 0.025, y, zz - 0.025), Vector3(sx + 0.025, y + h, zz + 0.025), trim)
	# French door.
	b.box_mm(Mats.get_mat("window_lit"), Vector3(bx - 0.65, y, -0.02), Vector3(bx + 0.65, y + 2.1, 0.03), Color("#3d5a78"))
	b.box_mm(solid, Vector3(bx - 0.04, y, 0.0), Vector3(bx + 0.04, y + 2.1, 0.06), trim)
	b.box_mm(solid, Vector3(bx - 0.78, y, 0.0), Vector3(bx - 0.65, y + 2.22, 0.1), trim)
	b.box_mm(solid, Vector3(bx + 0.65, y, 0.0), Vector3(bx + 0.78, y + 2.22, 0.1), trim)
	b.box_mm(solid, Vector3(bx - 0.85, y + 2.1, 0.0), Vector3(bx + 0.85, y + 2.28, 0.14), trim)


func _fence_segments() -> Array[Vector2]:
	var x0 := -width * 0.5 - 2.5
	var x1 := width * 0.5 + 2.5
	var gap := 0.8
	return [Vector2(x0, porch_offset - gap), Vector2(porch_offset + gap, x1)]


func _window_xs_front(upper: bool) -> Array:
	var hw := width * 0.5
	if upper:
		return [-hw * 0.62, 0.0, hw * 0.62]
	var xs := []
	for x in [-hw * 0.62, hw * 0.62, -hw * 0.25, hw * 0.25]:
		if absf(x - porch_offset) > 1.6 and xs.size() < 2:
			xs.append(x)
	return xs


func _after_build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 7
	var hw := width * 0.5
	var wh := _wall_h()
	var y0 := plinth + 1.55
	var y1 := plinth + storey_height + 1.5
	# Front windows with shutters and flower boxes.
	for upper in [false, true]:
		var y: float = y1 if upper else y0
		for x in _window_xs_front(upper):
			if upper and balcony_height > 0.0 and absf(x - balcony_offset) < 2.0:
				continue
			if not upper and has_porch and absf(x - porch_offset) < 2.6:
				continue
			inst("window", Transform3D(Basis(), Vector3(x, y, 0.02)))
			inst("shutter", Transform3D(Basis(), Vector3(x - 0.76, y, 0.06)), shutter_color)
			inst("shutter", Transform3D(Basis(), Vector3(x + 0.76, y, 0.06)), shutter_color)
			if upper or rng.randf() < 0.6:
				inst("flowerbox", Transform3D(Basis(), Vector3(x, y - 0.95, 0.14)))
	# Side and back windows.
	for sx in [-1.0, 1.0]:
		var basis := Basis(Vector3.UP, sx * PI * 0.5)
		for y in [y0, y1]:
			inst("window", Transform3D(basis, Vector3(sx * (hw + 0.02), y, -depth * 0.5)))
	var back := Basis(Vector3.UP, PI)
	for y in [y0, y1]:
		for x in [-hw * 0.5, hw * 0.5]:
			inst("window", Transform3D(back, Vector3(x, y, -depth - 0.02)))
	# Bushes along the facade and flowers by the fence.
	for i in 4:
		var bx := lerpf(-hw + 0.8, hw - 0.8, i / 3.0)
		if absf(bx - porch_offset) < 2.8:
			continue
		var s := rng.randf_range(0.7, 1.1)
		var green := Color("#5f8f45").lerp(Color("#7aa65a"), rng.randf())
		inst("bush", Transform3D(Basis().scaled(Vector3(s, s * 0.9, s)), Vector3(bx, 0, 0.7)), green)
	var fz := yard_depth - 0.45
	if fence_style == "picket":
		for seg in _fence_segments():
			var x := seg.x + 0.1
			while x < seg.y - 0.08:
				inst("picket", Transform3D(Basis(), Vector3(x, 0, fz)))
				x += 0.17
		for i in 22:
			var fx := rng.randf_range(-hw - 2.0, hw + 2.0)
			if absf(fx - porch_offset) < 1.0:
				continue
			inst("flower", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(fx, 0, fz - 0.45 - rng.randf() * 0.4)), Mats.pick(rng, Mats.FLOWER_COLORS))
	elif fence_style == "hedge":
		for seg in _fence_segments():
			var seg_len := seg.y - seg.x
			inst("hedge", Transform3D(Basis().scaled(Vector3(seg_len, 1.0, 1.0)), Vector3((seg.x + seg.y) * 0.5, 0, fz)), Color("#4f7f3f"))
	# Mailbox at the curb.
	inst("mailbox", Transform3D(Basis(), Vector3(porch_offset + 1.6, 0.15, curb_distance - 0.45)))


func _build_colliders() -> void:
	var wh := _wall_h()
	var rise := depth * 0.36
	var hw := width * 0.5
	add_box("wall", Vector3(0, wh * 0.5, -depth * 0.5), Vector3(width, wh, depth))
	var o := 0.45
	add_convex("wall", PackedVector3Array([
		Vector3(-hw - o, wh, 0.0 + o), Vector3(hw + o, wh, o), Vector3(-hw - o, wh, -depth - o), Vector3(hw + o, wh, -depth - o),
		Vector3(-hw - o, wh + rise, -depth * 0.5), Vector3(hw + o, wh + rise, -depth * 0.5),
	]))
	if has_chimney:
		var top := wh + rise + 1.14
		add_box("wall", Vector3(chimney_pos.x, (wh + top) * 0.5, chimney_pos.y), Vector3(1.0, top - wh, 1.0))
	if has_porch:
		add_box("wall", Vector3(porch_offset, (plinth + 3.2) * 0.5, 1.2), Vector3(4.8, plinth + 3.2, 2.6))
	if balcony_height > 0.0:
		# Slab, plus a slightly lowered railing so the throw clears it.
		add_box("wall", Vector3(balcony_offset, balcony_height - 0.1, 0.8), Vector3(2.8, 0.2, 1.6))
		add_box("wall", Vector3(balcony_offset, balcony_height + 0.42, 1.55), Vector3(2.8, 0.84, 0.1))
	if fence_style != "none":
		var fz := yard_depth - 0.45
		for seg in _fence_segments():
			add_box("fence", Vector3((seg.x + seg.y) * 0.5, 0.5, fz), Vector3(seg.y - seg.x, 1.0, 0.2))
	add_box("post", Vector3(porch_offset + 1.6, 0.75, curb_distance - 0.45), Vector3(0.3, 1.2, 0.5))
