class_name CollisionDebug
extends Node3D
## Testing aid: draws every collision shape as lines so you can see exactly what the plane can
## hit. Walls and props are orange, landing pads green, strings and their hanging items red,
## and the plane's own collision ball white. Toggle with F3 or Settings (test builds only).

var plane: PaperPlane
var _lines: MeshInstance3D
var _ball: MeshInstance3D


func _ready() -> void:
	_lines = MeshInstance3D.new()
	_lines.name = "Shapes"
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lines.extra_cull_margin = 16384.0
	_lines.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.render_priority = 20
	_lines.material_override = m
	add_child(_lines)
	_ball = MeshInstance3D.new()
	_ball.name = "PlaneBall"
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(1, 1, 1, 0.35)
	sm.no_depth_test = true
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	sphere.material = sm
	_ball.mesh = sphere
	_ball.top_level = true
	add_child(_ball)
	visible = false


func toggle() -> void:
	set_shown(not visible)


func set_shown(on: bool) -> void:
	visible = on
	if on:
		rebuild()


## Collects all collision shapes and hazard lines in the scene into one line mesh.
func rebuild() -> void:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CollisionShape3D and not (n as CollisionShape3D).disabled:
			var cs := n as CollisionShape3D
			var owner_body := cs.get_parent() as CollisionObject3D
			if cs.shape and owner_body and cs.is_visible_in_tree():
				var col := Color(0.5, 2.2, 0.6) if owner_body.collision_layer & 2 else Color(2.4, 1.1, 0.15)
				_append_shape(cs.shape, cs.global_transform, col, verts, colors)
		elif n is HazardLine:
			_append_hazard(n as HazardLine, verts, colors)
		stack.append_array(n.get_children())
	var mesh := ArrayMesh.new()
	if verts.size() > 0:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	_lines.mesh = mesh


func _append_shape(shape: Shape3D, xf: Transform3D, col: Color, verts: PackedVector3Array, colors: PackedColorArray) -> void:
	var dm := shape.get_debug_mesh()
	if dm == null or dm.get_surface_count() == 0:
		return
	var arrays := dm.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx = arrays[Mesh.ARRAY_INDEX]
	if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
		for i in idx:
			verts.append(xf * v[i])
			colors.append(col)
	else:
		for p in v:
			verts.append(xf * p)
			colors.append(col)


func _append_hazard(h: HazardLine, verts: PackedVector3Array, colors: PackedColorArray) -> void:
	var red := Color(2.6, 0.25, 0.3)
	for i in h.samples.size() - 1:
		verts.append(h.samples[i])
		verts.append(h.samples[i + 1])
		colors.append(red)
		colors.append(red)
	for t in h.tris:
		for k in 3:
			verts.append(t[k])
			verts.append(t[(k + 1) % 3])
			colors.append(red)
			colors.append(red)
	for sp in h.spheres:
		var c: Vector3 = sp[0]
		var r: float = sp[1]
		for k in 12:
			var a0 := TAU * k / 12.0
			var a1 := TAU * (k + 1) / 12.0
			for plane_axes in [[Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.UP], [Vector3.RIGHT, Vector3.FORWARD]]:
				var u: Vector3 = plane_axes[0]
				var w: Vector3 = plane_axes[1]
				verts.append(c + (u * cos(a0) + w * sin(a0)) * r)
				verts.append(c + (u * cos(a1) + w * sin(a1)) * r)
				colors.append(red)
				colors.append(red)


func _process(_delta: float) -> void:
	if visible and plane:
		_ball.visible = plane.visible
		_ball.global_position = plane.get_global_transform_interpolated().origin
