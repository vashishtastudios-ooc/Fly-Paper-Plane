class_name MeshBuilder
extends RefCounted
## Accumulates procedural geometry grouped by material and commits it as one ArrayMesh
## with one surface per material. Vertex colors tint shared materials, so many differently
## colored parts can share a single draw call. UVs are in meters scaled by `uv_scale`.
## Polygons are given counter-clockwise as seen from the front (outside).

var _tools := {}
var _order: Array[Material] = []
var uv_scale := 1.0


func _st(mat: Material) -> SurfaceTool:
	var st: SurfaceTool = _tools.get(mat)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[mat] = st
		_order.append(mat)
	return st


func is_empty() -> bool:
	return _order.is_empty()


func tri(mat: Material, a: Vector3, b: Vector3, c: Vector3, col := Color.WHITE,
		ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var st := _st(mat)
	st.set_color(col)
	st.set_normal(n)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_normal(n)
	st.set_uv(uc)
	st.add_vertex(c)
	st.set_normal(n)
	st.set_uv(ub)
	st.add_vertex(b)


func tri_n(mat: Material, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		col := Color.WHITE, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	var st := _st(mat)
	st.set_color(col)
	st.set_normal(na)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_normal(nc)
	st.set_uv(uc)
	st.add_vertex(c)
	st.set_normal(nb)
	st.set_uv(ub)
	st.add_vertex(b)


## Planar-mapped polygon (convex, CCW from the front). UVs follow the first edge.
func poly(mat: Material, pts: PackedVector3Array, col := Color.WHITE, scale := -1.0) -> void:
	if pts.size() < 3:
		return
	var s := uv_scale if scale < 0.0 else scale
	var n := Vector3.ZERO
	for i in range(1, pts.size() - 1):
		n += (pts[i] - pts[0]).cross(pts[i + 1] - pts[0])
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var u_axis := (pts[1] - pts[0]).normalized()
	var v_axis := n.cross(u_axis)
	var uvs := PackedVector2Array()
	for p in pts:
		var d := p - pts[0]
		uvs.append(Vector2(d.dot(u_axis), -d.dot(v_axis)) * s)
	for i in range(1, pts.size() - 1):
		tri(mat, pts[0], pts[i], pts[i + 1], col, uvs[0], uvs[i], uvs[i + 1])


func quad(mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col := Color.WHITE, scale := -1.0) -> void:
	poly(mat, PackedVector3Array([a, b, c, d]), col, scale)


## Axis-aligned box in local space transformed by `xf`. `faces` is a bitmask: 1=+X 2=-X 4=+Y 8=-Y 16=+Z 32=-Z.
func box(mat: Material, xf: Transform3D, size: Vector3, col := Color.WHITE, faces := 63, scale := -1.0) -> void:
	var h := size * 0.5
	var x := h.x
	var y := h.y
	var z := h.z
	if faces & 1:
		quad(mat, xf * Vector3(x, -y, z), xf * Vector3(x, -y, -z), xf * Vector3(x, y, -z), xf * Vector3(x, y, z), col, scale)
	if faces & 2:
		quad(mat, xf * Vector3(-x, -y, -z), xf * Vector3(-x, -y, z), xf * Vector3(-x, y, z), xf * Vector3(-x, y, -z), col, scale)
	if faces & 4:
		quad(mat, xf * Vector3(-x, y, z), xf * Vector3(x, y, z), xf * Vector3(x, y, -z), xf * Vector3(-x, y, -z), col, scale)
	if faces & 8:
		quad(mat, xf * Vector3(-x, -y, -z), xf * Vector3(x, -y, -z), xf * Vector3(x, -y, z), xf * Vector3(-x, -y, z), col, scale)
	if faces & 16:
		quad(mat, xf * Vector3(-x, -y, z), xf * Vector3(x, -y, z), xf * Vector3(x, y, z), xf * Vector3(-x, y, z), col, scale)
	if faces & 32:
		quad(mat, xf * Vector3(x, -y, -z), xf * Vector3(-x, -y, -z), xf * Vector3(-x, y, -z), xf * Vector3(x, y, -z), col, scale)


## Convenience: box centered at `center` with an optional yaw.
func box_at(mat: Material, center: Vector3, size: Vector3, col := Color.WHITE, yaw := 0.0, faces := 63) -> void:
	box(mat, Transform3D(Basis(Vector3.UP, yaw), center), size, col, faces)


## Box spanning from `min_corner` to `max_corner` (axis aligned).
func box_mm(mat: Material, min_corner: Vector3, max_corner: Vector3, col := Color.WHITE, faces := 63) -> void:
	box(mat, Transform3D(Basis(), (min_corner + max_corner) * 0.5), max_corner - min_corner, col, faces)


## Cylinder / cone / frustum along local +Y starting at the origin of `xf`.
func cylinder(mat: Material, xf: Transform3D, r_bottom: float, r_top: float, height: float,
		segments := 8, col := Color.WHITE, caps := true, smooth := false) -> void:
	var ring_b := PackedVector3Array()
	var ring_t := PackedVector3Array()
	for i in segments + 1:
		var a := TAU * float(i) / segments
		var dir := Vector3(sin(a), 0.0, cos(a))
		ring_b.append(dir * r_bottom)
		ring_t.append(dir * r_top + Vector3(0, height, 0))
	var circ := TAU * maxf(r_bottom, r_top)
	for i in segments:
		var a0 := xf * ring_b[i]
		var a1 := xf * ring_b[i + 1]
		var b0 := xf * ring_t[i]
		var b1 := xf * ring_t[i + 1]
		var u0 := float(i) / segments * circ * uv_scale
		var u1 := float(i + 1) / segments * circ * uv_scale
		var vh := height * uv_scale
		if smooth:
			var slope := (r_bottom - r_top) / maxf(height, 0.001)
			var n0 := (xf.basis * (Vector3(sin(TAU * i / segments), slope, cos(TAU * i / segments)))).normalized()
			var n1 := (xf.basis * (Vector3(sin(TAU * (i + 1) / segments), slope, cos(TAU * (i + 1) / segments)))).normalized()
			tri_n(mat, a0, a1, b1, n0, n1, n1, col, Vector2(u0, vh), Vector2(u1, vh), Vector2(u1, 0))
			tri_n(mat, a0, b1, b0, n0, n1, n0, col, Vector2(u0, vh), Vector2(u1, 0), Vector2(u0, 0))
		else:
			if r_top > 0.0001:
				quad(mat, a0, a1, b1, b0, col)
			else:
				tri(mat, a0, a1, b0, col, Vector2(u0, vh), Vector2(u1, vh), Vector2((u0 + u1) * 0.5, 0))
	if caps:
		var cb := xf * Vector3.ZERO
		var ct := xf * Vector3(0, height, 0)
		for i in segments:
			if r_top > 0.0001:
				tri(mat, ct, xf * ring_t[i], xf * ring_t[i + 1], col)
			if r_bottom > 0.0001:
				tri(mat, cb, xf * ring_b[i + 1], xf * ring_b[i], col)


## Smooth-shaded ellipsoid-ish sphere.
func sphere(mat: Material, center: Vector3, radius: Vector3, rings := 6, segments := 10, col := Color.WHITE) -> void:
	var verts := []
	for r in rings + 1:
		var phi := PI * float(r) / rings
		var row := []
		for s in segments + 1:
			var th := TAU * float(s) / segments
			var n := Vector3(sin(phi) * sin(th), cos(phi), sin(phi) * cos(th))
			row.append(n)
		verts.append(row)
	for r in rings:
		for s in segments:
			var n00: Vector3 = verts[r][s]
			var n01: Vector3 = verts[r][s + 1]
			var n10: Vector3 = verts[r + 1][s]
			var n11: Vector3 = verts[r + 1][s + 1]
			var p00 := center + n00 * radius
			var p01 := center + n01 * radius
			var p10 := center + n10 * radius
			var p11 := center + n11 * radius
			var uv00 := Vector2(float(s) / segments, float(r) / rings) * 4.0
			var uv01 := Vector2(float(s + 1) / segments, float(r) / rings) * 4.0
			var uv10 := Vector2(float(s) / segments, float(r + 1) / rings) * 4.0
			var uv11 := Vector2(float(s + 1) / segments, float(r + 1) / rings) * 4.0
			# Outward facing, counter-clockwise from outside: p00 -> p10 -> p11 -> p01
			if r != 0:
				tri_n(mat, p00, p10, p01, n00, n10, n01, col, uv00, uv10, uv01)
			if r != rings - 1:
				tri_n(mat, p01, p10, p11, n01, n10, n11, col, uv01, uv10, uv11)


## Gable roof made of two thick slabs. Ridge runs along local Z. `xf` origin is at eave height, center.
func gable_roof(mat: Material, xf: Transform3D, width: float, length: float, rise: float,
		overhang := 0.35, thickness := 0.16, col := Color.WHITE) -> void:
	var half := width * 0.5 + overhang
	var angle := atan2(rise, width * 0.5)
	var slope_len := half / cos(angle) + thickness * 0.5
	for side in [-1.0, 1.0]:
		var mid := Vector3(side * half * 0.5, rise - half * 0.5 * tan(angle), 0.0)
		var b := Basis(Vector3.FORWARD, side * angle)
		var t := Transform3D(b, mid + b * Vector3(0, thickness * 0.5, 0))
		box(mat, xf * t, Vector3(slope_len, thickness, length + overhang * 2.0), col)


## Triangular gable wall at the end of a ridge (local Z = z_pos), base width `width`, height `rise`.
func gable_wall(mat: Material, xf: Transform3D, width: float, rise: float, z_pos: float, facing: float, col := Color.WHITE) -> void:
	var a := Vector3(-width * 0.5, 0, z_pos)
	var b := Vector3(width * 0.5, 0, z_pos)
	var c := Vector3(0, rise, z_pos)
	if facing > 0.0:
		poly(mat, PackedVector3Array([xf * a, xf * b, xf * c]), col)
	else:
		poly(mat, PackedVector3Array([xf * b, xf * a, xf * c]), col)


## Square pyramid roof, base centered at the origin of `xf`.
func pyramid(mat: Material, xf: Transform3D, base: Vector2, height: float, col := Color.WHITE) -> void:
	var hx := base.x * 0.5
	var hz := base.y * 0.5
	var apex := xf * Vector3(0, height, 0)
	var c := [xf * Vector3(-hx, 0, hz), xf * Vector3(hx, 0, hz), xf * Vector3(hx, 0, -hz), xf * Vector3(-hx, 0, -hz)]
	for i in 4:
		poly(mat, PackedVector3Array([c[i], c[(i + 1) % 4], apex]), col)


## A tube following a polyline (used for ropes and trails).
func tube(mat: Material, pts: PackedVector3Array, radius: float, sides := 4, col := Color.WHITE) -> void:
	if pts.size() < 2:
		return
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var dir := (b - a).normalized()
		var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
		var side := dir.cross(up).normalized()
		var up2 := side.cross(dir).normalized()
		for s in sides:
			var a0 := TAU * float(s) / sides
			var a1 := TAU * float(s + 1) / sides
			var o0 := (side * cos(a0) + up2 * sin(a0)) * radius
			var o1 := (side * cos(a1) + up2 * sin(a1)) * radius
			quad(mat, a + o1, a + o0, b + o0, b + o1, col)


func build(mesh: ArrayMesh = null) -> ArrayMesh:
	if mesh == null:
		mesh = ArrayMesh.new()
	for mat in _order:
		var st: SurfaceTool = _tools[mat]
		st.index()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	_tools.clear()
	_order.clear()
	return mesh


## Builds and wraps the mesh in a MeshInstance3D.
func build_instance(name := "Model", shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = build()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
