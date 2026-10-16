extends Prop
## Harbour boats on the water: a fishing boat with a wheelhouse and a little mast, or a sailing
## boat with a tall mast and white sails. Origin = the water surface at the middle of the boat;
## the boat lies along local X with the bow toward +X. The deck is a flat landing surface.

## "fishing", "sail" or "ferry" (a little harbour ferry whose passenger cabin has big open
## windows on both sides, so the plane can fly straight through it).
@export var kind := "fishing"
@export var length := 9.0
@export var beam := 3.2
## Deck height above the water.
@export var deck_y := 0.9
@export var hull_color := Color("#2f6f8f")
@export var stripe_color := Color("#f6f1e6")
@export var cabin_color := Color("#f6f1e6")
## Gentle bobbing (visual only; the colliders stay put).
@export var bob := true

var _t := 0.0


func _hull_half(x: float) -> float:
	var t := x / (length * 0.5)
	return beam * 0.5 * (1.0 - 0.8 * maxf(0.0, t) * maxf(0.0, t)) * (1.0 - 0.12 * maxf(0.0, -t))


func _build(b: MeshBuilder) -> void:
	var paint := Mats.get_mat("paint")
	var wood := Mats.get_mat("wood")
	var solid := Mats.get_mat("solid")
	var h := length * 0.5
	var bottom := -0.7
	var rail := deck_y + 0.35
	var n := 14
	for i in n:
		var x0 := lerpf(-h, h, float(i) / n)
		var x1 := lerpf(-h, h, float(i + 1) / n)
		var w0 := _hull_half(x0)
		var w1 := _hull_half(x1)
		var k0 := 0.35
		for s in [-1.0, 1.0]:
			# Hull side: the lower part tucks in toward the keel.
			var top0 := Vector3(x0, rail, s * w0)
			var top1 := Vector3(x1, rail, s * w1)
			var mid0 := Vector3(x0, 0.05, s * w0 * 0.98)
			var mid1 := Vector3(x1, 0.05, s * w1 * 0.98)
			var low0 := Vector3(x0, bottom, s * w0 * k0)
			var low1 := Vector3(x1, bottom, s * w1 * k0)
			var pts_up := [mid0, mid1, top1, top0] if s > 0 else [mid1, mid0, top0, top1]
			var pts_lo := [low0, low1, mid1, mid0] if s > 0 else [low1, low0, mid0, mid1]
			b.quad(paint, pts_up[0], pts_up[1], pts_up[2], pts_up[3], hull_color)
			b.quad(paint, pts_lo[0], pts_lo[1], pts_lo[2], pts_lo[3], hull_color.darkened(0.25))
			# A pale stripe under the rail.
			var s0 := Vector3(x0, rail - 0.18, s * (w0 + 0.01))
			var s1 := Vector3(x1, rail - 0.18, s * (w1 + 0.01))
			var t0 := Vector3(x0, rail - 0.05, s * (w0 + 0.01))
			var t1 := Vector3(x1, rail - 0.05, s * (w1 + 0.01))
			if s > 0:
				b.quad(solid, s0, s1, t1, t0, stripe_color)
			else:
				b.quad(solid, s1, s0, t0, t1, stripe_color)
			# Inside of the bulwark above the deck.
			var d0 := Vector3(x0, deck_y, s * (w0 - 0.08))
			var d1 := Vector3(x1, deck_y, s * (w1 - 0.08))
			var r0 := Vector3(x0, rail, s * (w0 - 0.08))
			var r1 := Vector3(x1, rail, s * (w1 - 0.08))
			if s > 0:
				b.quad(paint, d1, d0, r0, r1, Color("#e8dfcc"))
			else:
				b.quad(paint, d0, d1, r1, r0, Color("#e8dfcc"))
		# Deck planks and the keel line underneath.
		b.quad(wood, Vector3(x0, deck_y, -w0 + 0.08), Vector3(x0, deck_y, w0 - 0.08), Vector3(x1, deck_y, w1 - 0.08), Vector3(x1, deck_y, -w1 + 0.08), Color("#c9a27e"))
		b.quad(paint, Vector3(x1, bottom, -w1 * k0), Vector3(x1, bottom, w1 * k0), Vector3(x0, bottom, w0 * k0), Vector3(x0, bottom, -w0 * k0), hull_color.darkened(0.3))
	# Transom (flat stern).
	var ws := _hull_half(-h)
	b.quad(paint, Vector3(-h, bottom, ws * 0.35), Vector3(-h, bottom, -ws * 0.35), Vector3(-h, rail, -ws), Vector3(-h, rail, ws), hull_color)
	if kind == "ferry":
		_build_ferry_cabin(b)
	elif kind == "fishing":
		# Wheelhouse toward the stern, a short mast with a boom, nets and floats.
		var wx := -h * 0.35
		b.box_mm(paint, Vector3(wx - 1.3, deck_y, -beam * 0.3), Vector3(wx + 1.3, deck_y + 2.1, beam * 0.3), cabin_color)
		b.box_mm(Mats.get_mat("window_lit"), Vector3(wx + 1.31, deck_y + 1.15, -beam * 0.24), Vector3(wx + 1.34, deck_y + 1.8, beam * 0.24), Color("#3d5a78"))
		b.box_mm(solid, Vector3(wx - 1.45, deck_y + 2.1, -beam * 0.36), Vector3(wx + 1.45, deck_y + 2.28, beam * 0.36), hull_color.darkened(0.2))
		b.cylinder(wood, Transform3D(Basis(), Vector3(h * 0.25, deck_y, 0)), 0.09, 0.07, 5.0, 6, Color("#8a5a3c"))
		b.cylinder(wood, Transform3D(Basis(Vector3.BACK, -1.2), Vector3(h * 0.25, deck_y + 1.4, 0)), 0.06, 0.05, 3.2, 6, Color("#8a5a3c"))
		b.box_mm(Mats.get_mat("cloth"), Vector3(-h + 0.3, deck_y, -beam * 0.3), Vector3(-h + 1.2, deck_y + 0.35, beam * 0.3), Color("#3f7d4f"))
		for z in [-1.0, 1.0]:
			b.sphere(solid, Vector3(h * 0.05, rail - 0.25, z * (_hull_half(h * 0.05) + 0.12)), Vector3(0.22, 0.22, 0.22), 4, 8, Color("#e8873a"))
	else:
		# Tall mast with a mainsail and a jib.
		var mx := h * 0.15
		var top := deck_y + 8.5
		b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(), Vector3(mx, deck_y, 0)), 0.08, 0.06, 8.5, 6, Color("#e8e8e8"))
		b.cylinder(Mats.get_mat("metal"), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(mx, deck_y + 1.3, 0)), 0.06, 0.06, h * 1.15, 6, Color("#e8e8e8"))
		var cloth := Mats.get_mat("cloth")
		var sail := Color("#fbf8f0")
		b.poly(cloth, PackedVector3Array([Vector3(mx - 0.1, deck_y + 1.35, 0.02), Vector3(mx - h * 1.1, deck_y + 1.35, 0.02), Vector3(mx - 0.1, top - 0.3, 0.02)]), sail)
		b.poly(cloth, PackedVector3Array([Vector3(mx + 0.1, deck_y + 0.6, -0.02), Vector3(mx + 0.1, top - 0.6, -0.02), Vector3(h - 0.2, deck_y + 0.5, -0.02)]), sail.darkened(0.04))
		b.box_mm(paint, Vector3(-h * 0.45, deck_y, -beam * 0.25), Vector3(0.0, deck_y + 0.55, beam * 0.25), cabin_color)


## Ferry cabin: local x -CX..CX, z -CZ..CZ, deck to deck + CH, with an open window in each long
## side (x -WX..WX, from deck + W0 to deck + W1).
const CX := 3.5
const CZ := 1.8
const CH := 2.35
const WX := 1.25
const W0 := 0.8
const W1 := 2.1


func _build_ferry_cabin(b: MeshBuilder) -> void:
	var paint := Mats.get_mat("paint")
	var solid := Mats.get_mat("solid")
	var d := deck_y
	for s in [-1.0, 1.0]:
		var z: float = s * CZ
		var z0: float = minf(z, z - s * 0.12)
		var z1: float = maxf(z, z - s * 0.12)
		b.box_mm(paint, Vector3(-CX, d, z0), Vector3(-WX, d + CH, z1), cabin_color)
		b.box_mm(paint, Vector3(WX, d, z0), Vector3(CX, d + CH, z1), cabin_color)
		b.box_mm(paint, Vector3(-WX, d, z0), Vector3(WX, d + W0, z1), cabin_color)
		b.box_mm(paint, Vector3(-WX, d + W1, z0), Vector3(WX, d + CH, z1), cabin_color)
		# Frame round the open window, and small glazed windows either side.
		b.box_mm(solid, Vector3(-WX - 0.08, d + W0 - 0.08, z0 - 0.03), Vector3(WX + 0.08, d + W0, z1 + 0.03), hull_color)
		b.box_mm(solid, Vector3(-WX - 0.08, d + W1, z0 - 0.03), Vector3(WX + 0.08, d + W1 + 0.08, z1 + 0.03), hull_color)
		for wx in [-2.5, 2.5]:
			b.box_mm(Mats.get_mat("window_lit"), Vector3(wx - 0.45, d + 1.1, z0 - 0.02), Vector3(wx + 0.45, d + 1.8, z1 + 0.02), Color("#3d5a78"))
	for s in [-1.0, 1.0]:
		var x: float = s * CX
		b.box_mm(paint, Vector3(minf(x, x - s * 0.12), d, -CZ), Vector3(maxf(x, x - s * 0.12), d + CH, CZ), cabin_color)
	b.box_mm(solid, Vector3(-CX - 0.25, d + CH, -CZ - 0.25), Vector3(CX + 0.25, d + CH + 0.16, CZ + 0.25), hull_color)
	# Benches inside, below the windows.
	for s in [-1.0, 1.0]:
		b.box_mm(Mats.get_mat("wood"), Vector3(-CX + 0.3, d, s * 0.9 - 0.25), Vector3(CX - 0.3, d + 0.45, s * 0.9 + 0.25), Color("#b08a64"))
	# A funnel and a life ring.
	b.cylinder(solid, Transform3D(Basis(), Vector3(-CX + 0.8, d + CH + 0.16, 0)), 0.35, 0.3, 1.1, 10, Color("#c8423b"))
	b.cylinder(solid, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(CX + 0.13, d + 1.4, 0)), 0.35, 0.35, 0.1, 12, Color("#e8873a"))


func _build_colliders() -> void:
	var w := beam * 0.9
	add_box("wall", Vector3(0, (deck_y - 0.7) * 0.5, 0), Vector3(length * 0.9, deck_y + 0.7, w))
	if kind == "ferry":
		var d := deck_y
		for s in [-1.0, 1.0]:
			var z: float = s * (CZ - 0.06)
			add_box("wall", Vector3(-(CX + WX) * 0.5, d + CH * 0.5, z), Vector3(CX - WX, CH, 0.12))
			add_box("wall", Vector3((CX + WX) * 0.5, d + CH * 0.5, z), Vector3(CX - WX, CH, 0.12))
			add_box("wall", Vector3(0, d + W0 * 0.5, z), Vector3(WX * 2.0, W0, 0.12))
			add_box("wall", Vector3(0, d + (W1 + CH) * 0.5, z), Vector3(WX * 2.0, CH - W1, 0.12))
			add_box("wall", Vector3(s * (CX - 0.06), d + CH * 0.5, 0), Vector3(0.12, CH, CZ * 2.0))
		add_box("wall", Vector3(0, d + CH + 0.08, 0), Vector3(CX * 2.0 + 0.5, 0.16, CZ * 2.0 + 0.5))
		add_box("post", Vector3(-CX + 0.8, d + CH + 0.7, 0), Vector3(0.7, 1.1, 0.7))
		return
	if kind == "fishing":
		add_box("wall", Vector3(-length * 0.5 * 0.35, deck_y + 1.15, 0), Vector3(2.9, 2.3, beam * 0.72))
		add_box("post", Vector3(length * 0.5 * 0.25, deck_y + 2.5, 0), Vector3(0.2, 5.0, 0.2))
	else:
		add_box("post", Vector3(length * 0.5 * 0.15, deck_y + 4.25, 0), Vector3(0.2, 8.5, 0.2))
		add_box("wall", Vector3(-length * 0.5 * 0.22, deck_y + 0.28, 0), Vector3(length * 0.5 * 0.45, 0.55, beam * 0.5))


func _ready() -> void:
	super._ready()
	_t = randf() * TAU
	set_process(bob)


func _process(delta: float) -> void:
	_t += delta
	var model := get_node_or_null("Model") as Node3D
	if model:
		model.position.y = sin(_t * 0.9) * 0.06
		model.rotation = Vector3(sin(_t * 0.7) * 0.025, 0, sin(_t * 0.9 + 1.0) * 0.02)
