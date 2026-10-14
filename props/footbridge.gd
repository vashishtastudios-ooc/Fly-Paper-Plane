extends Prop
## Wooden humpback footbridge over a pond. Origin = ground level at the middle of the span;
## the span runs along local X. The deck follows a cosine hump, so there is only room to fly
## underneath near the middle. Colliders follow the deck in slices (the gap below stays open).

@export var span := 22.0
@export var width := 2.0
@export var rise := 1.3
## Deck top at the two ends (sits on the banks).
@export var base_y := 0.12

const DECK_T := 0.12
const STRINGER_T := 0.25
const RAIL_H := 0.95


func deck_top(x: float) -> float:
	var h := span * 0.5
	if absf(x) >= h:
		return base_y
	return base_y + rise * 0.5 * (1.0 + cos(PI * x / h))


func _build(b: MeshBuilder) -> void:
	var wood := Mats.get_mat("wood")
	var plank := Color("#b48a64")
	var dark := Color("#7d5b43")
	var hw := width * 0.5
	var h := span * 0.5
	var n := 30
	for i in n:
		var x0 := lerpf(-h, h, float(i) / n)
		var x1 := lerpf(-h, h, float(i + 1) / n)
		var t0 := deck_top(x0)
		var t1 := deck_top(x1)
		var tint := plank.darkened(0.05 * float(i % 3))
		# Plank surface and underside.
		b.quad(wood, Vector3(x0, t0, hw), Vector3(x1, t1, hw), Vector3(x1, t1, -hw), Vector3(x0, t0, -hw), tint)
		b.quad(wood, Vector3(x0, t0 - DECK_T, -hw), Vector3(x1, t1 - DECK_T, -hw), Vector3(x1, t1 - DECK_T, hw), Vector3(x0, t0 - DECK_T, hw), tint.darkened(0.25))
		# Side stringers (outer face, inner face, bottom).
		for sz in [-1.0, 1.0]:
			var z: float = sz * hw
			var zo: float = z + sz * 0.1
			b.quad(wood, Vector3(x0, t0 - STRINGER_T, zo), Vector3(x1, t1 - STRINGER_T, zo), Vector3(x1, t1 + 0.04, zo), Vector3(x0, t0 + 0.04, zo), dark)
			b.quad(wood, Vector3(x0, t0 + 0.04, z), Vector3(x1, t1 + 0.04, z), Vector3(x1, t1 - STRINGER_T, z), Vector3(x0, t0 - STRINGER_T, z), dark)
			b.quad(wood, Vector3(x0, t0 - STRINGER_T, z), Vector3(x1, t1 - STRINGER_T, z), Vector3(x1, t1 - STRINGER_T, zo), Vector3(x0, t0 - STRINGER_T, zo), dark.darkened(0.2))
	# Railings: posts and a handrail on both sides.
	var posts := int(span / 1.6)
	for sz in [-1.0, 1.0]:
		var rail := PackedVector3Array()
		for k in posts + 1:
			var x := lerpf(-h + 0.2, h - 0.2, float(k) / posts)
			var top := deck_top(x)
			b.box(wood, Transform3D(Basis(), Vector3(x, top + RAIL_H * 0.5, sz * (hw + 0.05))), Vector3(0.09, RAIL_H, 0.09), dark)
			rail.append(Vector3(x, top + RAIL_H, sz * (hw + 0.05)))
		b.tube(wood, rail, 0.05, 4, plank.darkened(0.1))


func _build_colliders() -> void:
	var hw := width * 0.5
	var h := span * 0.5
	var n := 16
	for i in n:
		var x0 := lerpf(-h, h, float(i) / n)
		var x1 := lerpf(-h, h, float(i + 1) / n)
		var hi := maxf(deck_top(x0), deck_top(x1))
		var lo := minf(deck_top(x0), deck_top(x1)) - STRINGER_T
		add_box("post", Vector3((x0 + x1) * 0.5, (hi + lo) * 0.5, 0), Vector3(x1 - x0, hi - lo, width + 0.2))
		for sz in [-1.0, 1.0]:
			add_box("post", Vector3((x0 + x1) * 0.5, hi + RAIL_H * 0.5, sz * (hw + 0.05)), Vector3(x1 - x0, RAIL_H + 0.05, 0.12))


func _draw_distance() -> float:
	return 220.0
