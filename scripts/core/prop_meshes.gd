class_name PropMeshes
extends RefCounted
## Procedural meshes for small repeated props that are drawn with MultiMeshInstance3D.
## To swap in a real model, save a scene at res://props/overrides/<kind>.tscn containing a
## MeshInstance3D; its mesh is used instead (sized to match: see the comments below).

static var _cache := {}


static func get_mesh(kind: String) -> Mesh:
	if _cache.has(kind):
		return _cache[kind]
	var mesh: Mesh = _override(kind)
	if mesh == null:
		mesh = _build(kind)
	_cache[kind] = mesh
	return mesh


static func _override(kind: String) -> Mesh:
	var path := "res://props/overrides/%s.tscn" % kind
	if not ResourceLoader.exists(path):
		return null
	var inst := (load(path) as PackedScene).instantiate()
	var found: Mesh = null
	var stack: Array[Node] = [inst]
	while not stack.is_empty() and found == null:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			found = n.mesh
		stack.append_array(n.get_children())
	inst.free()
	return found


static func _build(kind: String) -> Mesh:
	var b := MeshBuilder.new()
	var white := Color.WHITE
	match kind:
		"picket":
			# 0.09 wide, 0.95 tall, pointed top, base at origin.
			var m := Mats.get_mat("solid")
			b.box(m, Transform3D(Basis(), Vector3(0, 0.42, 0)), Vector3(0.09, 0.84, 0.025), white)
			var t := 0.0125
			b.poly(m, PackedVector3Array([Vector3(-0.045, 0.84, t), Vector3(0.045, 0.84, t), Vector3(0, 0.95, t)]), white)
			b.poly(m, PackedVector3Array([Vector3(0.045, 0.84, -t), Vector3(-0.045, 0.84, -t), Vector3(0, 0.95, -t)]), white)
			b.quad(m, Vector3(0.045, 0.84, t), Vector3(0.045, 0.84, -t), Vector3(0, 0.95, -t), Vector3(0, 0.95, t), white)
			b.quad(m, Vector3(-0.045, 0.84, -t), Vector3(-0.045, 0.84, t), Vector3(0, 0.95, t), Vector3(0, 0.95, -t), white)
		"flower":
			# A small blossom clump, ~0.14 m, base at origin. Tinted by instance color.
			var fm := Mats.get_mat("foliage")
			b.sphere(fm, Vector3(0, 0.1, 0), Vector3(0.07, 0.05, 0.07), 3, 6, white)
			b.sphere(fm, Vector3(0.06, 0.08, 0.03), Vector3(0.05, 0.04, 0.05), 3, 5, white)
			b.sphere(fm, Vector3(-0.05, 0.07, -0.04), Vector3(0.05, 0.04, 0.05), 3, 5, white)
		"bush":
			# Unit bush ~1 m wide, base at origin.
			var bm := Mats.get_mat("foliage")
			b.sphere(bm, Vector3(0, 0.42, 0), Vector3(0.5, 0.42, 0.5), 5, 8, white)
			b.sphere(bm, Vector3(0.28, 0.32, 0.12), Vector3(0.32, 0.3, 0.32), 4, 7, white)
			b.sphere(bm, Vector3(-0.25, 0.3, -0.15), Vector3(0.3, 0.28, 0.3), 4, 7, white)
		"hedge":
			# 1 m long hedge segment along X, 0.8 wide, 1 m tall. Scale per instance.
			var hm := Mats.get_mat("foliage")
			b.box(hm, Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(1.0, 0.9, 0.8), white)
			for i in 3:
				b.sphere(hm, Vector3(-0.33 + i * 0.33, 0.88, 0), Vector3(0.24, 0.16, 0.42), 3, 6, white)
		"canopy":
			# Round stylized canopy, radius ~1, centered at origin. Scale per instance.
			var cm := Mats.get_mat("foliage")
			b.sphere(cm, Vector3(0, 0, 0), Vector3(1.0, 0.92, 1.0), 6, 10, white)
			b.sphere(cm, Vector3(0.45, 0.35, 0.25), Vector3(0.6, 0.55, 0.6), 5, 8, white)
			b.sphere(cm, Vector3(-0.42, 0.28, -0.3), Vector3(0.62, 0.55, 0.62), 5, 8, white)
			b.sphere(cm, Vector3(0.05, -0.25, -0.5), Vector3(0.6, 0.5, 0.6), 5, 8, white)
		"conifer":
			var km := Mats.get_mat("foliage")
			b.cylinder(km, Transform3D(Basis(), Vector3(0, -1.0, 0)), 1.0, 0.0, 1.4, 9, white, true, true)
			b.cylinder(km, Transform3D(Basis(), Vector3(0, -0.2, 0)), 0.8, 0.0, 1.2, 9, white, true, true)
			b.cylinder(km, Transform3D(Basis(), Vector3(0, 0.5, 0)), 0.55, 0.0, 1.0, 9, white, true, true)
		"trunk":
			# Height 1 (scale Y per instance), base at origin.
			b.cylinder(Mats.get_mat("wood"), Transform3D(), 0.17, 0.12, 1.0, 6, Color("#8a6a52"), false, true)
		"window":
			# 1.0 x 1.4 window centered at origin, facing +Z, 0.12 deep frame.
			var fr := Mats.get_mat("solid")
			var gl := Mats.get_mat("window_lit")
			var trim := Mats.TRIM
			b.box(gl, Transform3D(Basis(), Vector3(0, 0, -0.02)), Vector3(0.9, 1.3, 0.04), Color("#3d5a78"), 16)
			b.box(fr, Transform3D(Basis(), Vector3(0, 0.68, 0.03)), Vector3(1.08, 0.08, 0.12), trim)
			b.box(fr, Transform3D(Basis(), Vector3(0, -0.7, 0.05)), Vector3(1.2, 0.08, 0.18), trim)
			b.box(fr, Transform3D(Basis(), Vector3(-0.5, 0, 0.03)), Vector3(0.08, 1.4, 0.12), trim)
			b.box(fr, Transform3D(Basis(), Vector3(0.5, 0, 0.03)), Vector3(0.08, 1.4, 0.12), trim)
			b.box(fr, Transform3D(Basis(), Vector3(0, 0.02, 0.01)), Vector3(0.9, 0.05, 0.05), trim)
			b.box(fr, Transform3D(Basis(), Vector3(0, 0.02, 0.01)), Vector3(0.05, 1.3, 0.05), trim)
		"shutter":
			# 0.42 x 1.4 louvered shutter centered at origin, facing +Z. Tinted per instance.
			var sm := Mats.get_mat("solid")
			b.box(sm, Transform3D(), Vector3(0.42, 1.4, 0.04), white)
			for i in 7:
				b.box(sm, Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(0, -0.55 + i * 0.18, 0.03)), Vector3(0.34, 0.1, 0.015), white.darkened(0.12))
		"flowerbox":
			# 1.1 m box with blossoms, origin at the box bottom center, facing +Z.
			var wm := Mats.get_mat("wood")
			var fm2 := Mats.get_mat("foliage")
			b.box(wm, Transform3D(Basis(), Vector3(0, 0.1, 0)), Vector3(1.1, 0.2, 0.24), Color("#9c6b4a"))
			var rng := RandomNumberGenerator.new()
			rng.seed = 99
			b.box(fm2, Transform3D(Basis(), Vector3(0, 0.22, 0)), Vector3(1.0, 0.08, 0.18), Color("#5f8f45"))
			for i in 7:
				var c := Mats.pick(rng, Mats.FLOWER_COLORS)
				b.sphere(fm2, Vector3(-0.45 + i * 0.15, 0.3 + rng.randf() * 0.05, rng.randf_range(-0.05, 0.05)), Vector3(0.08, 0.07, 0.08), 3, 5, c)
		"bunting_flag":
			# Triangle pennant 0.32 wide, hanging 0.4 down from the origin, in the XY plane.
			var cl := Mats.get_mat("cloth")
			b.poly(cl, PackedVector3Array([Vector3(-0.16, 0, 0), Vector3(0, -0.4, 0), Vector3(0.16, 0, 0)]), white)
		"shirt":
			# Laundry item ~0.6 wide, hanging down from the origin.
			var cl2 := Mats.get_mat("cloth")
			b.poly(cl2, PackedVector3Array([Vector3(-0.3, 0, 0), Vector3(-0.3, -0.18, 0), Vector3(-0.2, -0.2, 0), Vector3(-0.2, -0.62, 0),
				Vector3(0.2, -0.62, 0), Vector3(0.2, -0.2, 0), Vector3(0.3, -0.18, 0), Vector3(0.3, 0, 0)]), white)
		"sheet":
			var cl3 := Mats.get_mat("cloth")
			b.quad(cl3, Vector3(-0.6, -0.9, 0), Vector3(0.6, -0.9, 0), Vector3(0.6, 0, 0), Vector3(-0.6, 0, 0), white)
		"lamp":
			# Street lamp, 3.8 m tall, base at origin.
			var mm := Mats.get_mat("metal")
			var dark := Color("#2f3d36")
			b.cylinder(mm, Transform3D(), 0.14, 0.09, 0.5, 8, dark)
			b.cylinder(mm, Transform3D(Basis(), Vector3(0, 0.5, 0)), 0.06, 0.05, 3.0, 6, dark)
			b.cylinder(mm, Transform3D(Basis(), Vector3(0, 3.45, 0)), 0.12, 0.22, 0.12, 6, dark)
			b.cylinder(Mats.get_mat("window_lit"), Transform3D(Basis(), Vector3(0, 3.5, 0)), 0.15, 0.2, 0.38, 6, Color("#fff1c9"))
			b.cylinder(mm, Transform3D(Basis(), Vector3(0, 3.88, 0)), 0.26, 0.02, 0.22, 6, dark)
		"mailbox":
			var wm2 := Mats.get_mat("wood")
			var mb := Mats.get_mat("metal")
			b.box(wm2, Transform3D(Basis(), Vector3(0, 0.5, 0)), Vector3(0.1, 1.0, 0.1), Color("#e8e0d0"))
			b.box(mb, Transform3D(Basis(), Vector3(0, 1.12, 0)), Vector3(0.24, 0.24, 0.48), Color("#c8423b"))
			b.cylinder(mb, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.24, -0.24)), 0.12, 0.12, 0.48, 8, Color("#c8423b"), true)
			b.box(mb, Transform3D(Basis(), Vector3(0.14, 1.26, 0.1)), Vector3(0.02, 0.2, 0.06), Color("#f2d58f"))
		"bench":
			var bw := Mats.get_mat("wood")
			var bmet := Mats.get_mat("metal")
			var iron := Color("#2f3d36")
			for x in [-0.75, 0.75]:
				b.box(bmet, Transform3D(Basis(), Vector3(x, 0.22, 0)), Vector3(0.06, 0.44, 0.45), iron)
				b.box(bmet, Transform3D(Basis(), Vector3(x, 0.65, -0.2)), Vector3(0.06, 0.5, 0.06), iron)
			for i in 3:
				b.box(bw, Transform3D(Basis(), Vector3(0, 0.46, -0.15 + i * 0.15)), Vector3(1.7, 0.04, 0.12), Color("#b07a4f"))
			for i in 2:
				b.box(bw, Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, 0.65 + i * 0.16, -0.22)), Vector3(1.7, 0.1, 0.03), Color("#b07a4f"))
		"reed":
			var rm := Mats.get_mat("cloth")
			for i in 7:
				var a := TAU * i / 7.0
				var base := Vector3(cos(a), 0, sin(a)) * 0.12
				var tip := base * 2.5 + Vector3(0, 1.1 + 0.3 * sin(i * 2.1), 0)
				b.poly(rm, PackedVector3Array([base + Vector3(-0.02, 0, 0), base + Vector3(0.02, 0, 0), tip]), white)
				if i % 2 == 0:
					b.cylinder(Mats.get_mat("solid"), Transform3D(Basis(), tip - Vector3(0, 0.25, 0)), 0.03, 0.03, 0.2, 5, Color("#7a5236"), true)
		"rock":
			b.sphere(Mats.get_mat("stone"), Vector3(0, 0.25, 0), Vector3(0.6, 0.4, 0.5), 3, 6, white)
		"cobble_post":
			b.cylinder(Mats.get_mat("stone"), Transform3D(), 0.12, 0.1, 0.8, 8, Color("#d8d0c0"))
		_:
			b.box(Mats.get_mat("solid"), Transform3D(), Vector3.ONE * 0.3, Color.MAGENTA)
	return b.build()
