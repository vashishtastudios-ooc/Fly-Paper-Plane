class_name HazardLine
extends Node3D
## A sagging line strung between two points: bunting, washing or a plain rope line.
## The plane crashes when it comes within 0.3 m of any sampled segment.

const SEGMENTS := 16
const HIT_DISTANCE := 0.3

@export var a := Vector3.ZERO
@export var b := Vector3(10, 0, 0)
@export var sag := 1.0
## "bunting", "washing", "line" or "lanterns".
@export var kind := "bunting"
@export var with_posts := true
@export var seed_value := 1

var samples := PackedVector3Array()
var _aabb := AABB()


func _ready() -> void:
	samples.clear()
	for i in SEGMENTS + 1:
		samples.append(point_at(float(i) / SEGMENTS))
	_aabb = AABB(samples[0], Vector3.ZERO)
	for p in samples:
		_aabb = _aabb.expand(p)
	_aabb = _aabb.grow(HIT_DISTANCE + 0.1)
	_build_visual()


func point_at(t: float) -> Vector3:
	return a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)


func message() -> String:
	match kind:
		"washing": return "Tangled in the washing"
		"lanterns": return "Tangled in the lantern string"
		"bunting": return "Tangled in the bunting"
	return "Snagged on a line"


## Distance from a world point to the line (polyline of SEGMENTS pieces).
func distance_to(p: Vector3) -> float:
	if not _aabb.grow(1.0).has_point(p):
		return INF
	var best := INF
	for i in samples.size() - 1:
		var s0 := samples[i]
		var s1 := samples[i + 1]
		var ab := s1 - s0
		var t := clampf((p - s0).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		best = minf(best, p.distance_to(s0 + ab * t))
	return best


func hits(p: Vector3) -> bool:
	return distance_to(p) < HIT_DISTANCE


func _build_visual() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MeshBuilder.new()
	var rope_col := Color("#f3ecd6") if kind != "line" else Color("#e8e2d2")
	var fine := PackedVector3Array()
	for i in 49:
		fine.append(point_at(float(i) / 48.0))
	mb.tube(Mats.get_mat("rope"), fine, 0.018, 4, rope_col)
	var length := a.distance_to(b)
	var cloth := Mats.get_mat("cloth")
	match kind:
		"bunting":
			# Pennants are drawn with a MultiMesh (one instance per flag).
			var cols := ["#c8423b", "#f2c14e", "#2f6f8f", "#6f9e4c", "#e6a3c3", "#fbf8f0", "#e0a13a"]
			var n := int(length / 0.42)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = PropMeshes.get_mesh("bunting_flag")
			mm.instance_count = n
			for i in n:
				var t := (i + 0.5) / n
				var p := point_at(t)
				var dir := (point_at(minf(t + 0.01, 1.0)) - point_at(maxf(t - 0.01, 0.0))).normalized()
				var side := dir.cross(Vector3.UP).normalized()
				var up := side.cross(dir).normalized()
				mm.set_instance_transform(i, Transform3D(Basis(dir, up, side), p))
				mm.set_instance_color(i, Color(cols[i % cols.size()]))
			var flags := MultiMeshInstance3D.new()
			flags.name = "Flags"
			flags.multimesh = mm
			flags.material_override = _flag_material()
			flags.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			flags.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			flags.visibility_range_end = 220.0
			add_child(flags)
		"washing":
			var cols2 := ["#fbf8f0", "#a9c9db", "#e9b7a1", "#f2d58f", "#b9d6a8", "#e6c3da", "#ffffff"]
			var x := 0.5
			var k := 0
			while x < length - 0.6:
				var t := x / length
				var p := point_at(t)
				var dir := (b - a).normalized()
				dir.y = 0.0
				dir = dir.normalized()
				var c := Color(cols2[k % cols2.size()])
				if k % 3 == 2:
					# Bedsheet.
					var w := dir * 0.55
					mb.quad(cloth, p - w + Vector3(0, -0.85, 0), p + w + Vector3(0, -0.85, 0), p + w, p - w, c)
					x += 1.4
				else:
					# Shirt shape.
					var r := dir
					var pts := PackedVector3Array([p - r * 0.28, p - r * 0.28 + Vector3(0, -0.16, 0), p - r * 0.18 + Vector3(0, -0.18, 0),
						p - r * 0.18 + Vector3(0, -0.58, 0), p + r * 0.18 + Vector3(0, -0.58, 0), p + r * 0.18 + Vector3(0, -0.18, 0),
						p + r * 0.28 + Vector3(0, -0.16, 0), p + r * 0.28])
					mb.poly(cloth, pts, c)
					x += 0.85
				# Clothes peg.
				mb.box(Mats.get_mat("wood"), Transform3D(Basis(), p + Vector3(0, -0.02, 0)), Vector3(0.03, 0.09, 0.03), Color("#c9a27e"))
				k += 1
		"lanterns":
			var n3 := int(length / 1.1)
			var lm := MultiMesh.new()
			lm.transform_format = MultiMesh.TRANSFORM_3D
			lm.use_colors = true
			var sphere := SphereMesh.new()
			sphere.radius = 0.15
			sphere.height = 0.36
			sphere.radial_segments = 10
			sphere.rings = 5
			var glow := StandardMaterial3D.new()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.vertex_color_use_as_albedo = true
			glow.vertex_color_is_srgb = true
			glow.albedo_color = Color(1.4, 1.4, 1.4)
			sphere.material = glow
			lm.mesh = sphere
			lm.instance_count = n3
			var lcols := [Color("#ff8a3d"), Color("#ffcf5a"), Color("#ff5f5f"), Color("#ffb347")]
			for i in n3:
				var p := point_at((i + 0.5) / n3) + Vector3(0, -0.24, 0)
				lm.set_instance_transform(i, Transform3D(Basis(), p))
				lm.set_instance_color(i, lcols[i % lcols.size()])
				mb.box(Mats.get_mat("rope"), Transform3D(Basis(), p + Vector3(0, 0.15, 0)), Vector3(0.012, 0.12, 0.012), Color("#4a3426"))
			var lanterns := MultiMeshInstance3D.new()
			lanterns.name = "Lanterns"
			lanterns.multimesh = lm
			lanterns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lanterns.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			add_child(lanterns)
		"line":
			var n2 := int(length / 1.5)
			for i in n2:
				var p := point_at((i + 0.5) / n2)
				var c := Color("#c8423b") if i % 2 == 0 else Color("#fbf8f0")
				mb.box(Mats.get_mat("solid"), Transform3D(Basis(), p + Vector3(0, -0.08, 0)), Vector3(0.1, 0.16, 0.1), c)
	if with_posts:
		for end in [a, b]:
			var ground := Terrain.ground_height(end.x, end.z)
			if ground < Terrain.WATER_Y:
				ground = Terrain.ground_height(end.x, end.z)
			var h: float = end.y + 0.25 - ground
			var col := Color("#fbf8f0") if kind != "line" else Color("#8a6a52")
			var mat := Mats.get_mat("wood") if kind == "line" else Mats.get_mat("solid")
			mb.cylinder(mat, Transform3D(Basis(), Vector3(end.x, ground, end.z)), 0.07, 0.06, h, 6, col)
			if kind == "washing":
				var dir := (b - a).normalized()
				var perp := Vector3(-dir.z, 0, dir.x)
				mb.box(mat, Transform3D(Basis(Vector3.UP, atan2(perp.x, perp.z)), Vector3(end.x, end.y + 0.05, end.z)), Vector3(0.06, 0.06, 0.9), col)
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			body.set_meta("kind", "post")
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.1
			cyl.height = h
			cs.shape = cyl
			body.position = Vector3(end.x, ground + h * 0.5, end.z)
			body.add_child(cs)
			add_child(body)
	var mi := mb.build_instance("Visual", false)
	add_child(mi)


static var _flag_mat: StandardMaterial3D


## Cloth for pennants that fades out right in front of the camera.
static func _flag_material() -> StandardMaterial3D:
	if _flag_mat == null:
		_flag_mat = (Mats.get_mat("cloth") as StandardMaterial3D).duplicate()
		_flag_mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		_flag_mat.distance_fade_min_distance = 0.7
		_flag_mat.distance_fade_max_distance = 2.0
	return _flag_mat
