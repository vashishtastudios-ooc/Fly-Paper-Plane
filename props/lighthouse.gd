extends Prop
## Seaside Harbour's lighthouse: a red-and-white striped tower with a railed gallery, a glass
## lantern room and a red cap, and the keeper's cottage at its foot. Origin = ground at the
## centre of the tower. The gallery (the launch spot of the harbour's first flight) faces -Z.

@export var height := 17.0
@export var base_radius := 3.0
@export var top_radius := 2.2
## Band colour (red, or green for the little lighthouse across the bay) and the keeper's cottage.
@export var band_color := Color("#c8423b")
@export var with_cottage := true

const GALLERY_R := 3.5
const WHITE := Color("#f6f1e6")
var RED: Color:
	get: return band_color

var _beam: Node3D


## Top of the gallery floor (local).
func gallery_y() -> float:
	return height + 0.3


func _build(b: MeshBuilder) -> void:
	var paint := Mats.get_mat("plaster")
	var stone := Mats.get_mat("stone")
	var solid := Mats.get_mat("solid")
	var metal := Mats.get_mat("metal")
	# Stone footing, then the tapering tower in alternating red and white bands.
	b.cylinder(stone, Transform3D(Basis(), Vector3(0, -1.5, 0)), base_radius + 0.8, base_radius + 0.6, 2.2, 20, Color("#cfc6b6"))
	var bands := 5
	for i in bands:
		var y0 := height * i / bands
		var y1 := height * (i + 1) / bands
		var r0 := lerpf(base_radius, top_radius, float(i) / bands)
		var r1 := lerpf(base_radius, top_radius, float(i + 1) / bands)
		b.cylinder(paint, Transform3D(Basis(), Vector3(0, 0.7 + y0 - 0.7 * float(i) / bands, 0)), r0, r1, y1 - y0 + 0.02, 20, RED if i % 2 == 1 else WHITE, false, true)
	# Door and little windows facing the sea.
	b.box(solid, Transform3D(Basis(), Vector3(0, 1.8, -base_radius + 0.05)), Vector3(1.1, 2.2, 0.2), Color("#2f5560"))
	for k in 3:
		var y := 5.0 + k * 4.0
		var r := lerpf(base_radius, top_radius, y / height)
		b.box(Mats.get_mat("window_lit"), Transform3D(Basis(), Vector3(0, y, -r + 0.04)), Vector3(0.6, 0.9, 0.12), Color("#3d5a78"))
	# Gallery: a stone ring floor with a railing.
	var gy := gallery_y()
	b.cylinder(stone, Transform3D(Basis(), Vector3(0, gy - 0.35, 0)), GALLERY_R, GALLERY_R, 0.35, 24, Color("#d8cdbb"))
	b.cylinder(stone, Transform3D(Basis(), Vector3(0, gy - 1.0, 0)), top_radius, GALLERY_R - 0.3, 0.65, 24, Color("#cfc6b6"), false)
	var posts := 24
	for i in posts:
		var a := TAU * i / posts
		b.box(metal, Transform3D(Basis(Vector3.UP, -a), Vector3(sin(a), 0, cos(a)) * (GALLERY_R - 0.12) + Vector3(0, gy + 0.5, 0)), Vector3(0.06, 1.0, 0.06), Color("#2f3a40"))
	var ring := PackedVector3Array()
	for i in 41:
		var a := TAU * i / 40.0
		ring.append(Vector3(sin(a), 0, cos(a)) * (GALLERY_R - 0.12) + Vector3(0, gy + 1.0, 0))
	b.tube(metal, ring, 0.05, 4, Color("#2f3a40"))
	# Lantern room: glass with a warm lamp inside, a red cap and a ball on top.
	b.cylinder(solid, Transform3D(Basis(), Vector3(0, gy, 0)), 1.6, 1.6, 0.5, 16, WHITE)
	b.cylinder(Mats.get_mat("glass"), Transform3D(Basis(), Vector3(0, gy + 0.5, 0)), 1.45, 1.45, 2.0, 16, Color("#a9c9db"), false, true)
	b.sphere(Mats.get_mat("glow"), Vector3(0, gy + 1.5, 0), Vector3(0.55, 0.65, 0.55), 5, 8, Color("#ffd27a"))
	b.cylinder(solid, Transform3D(Basis(), Vector3(0, gy + 2.5, 0)), 1.85, 0.25, 1.5, 16, RED)
	b.sphere(metal, Vector3(0, gy + 4.15, 0), Vector3(0.28, 0.28, 0.28), 4, 8, Color("#2f3a40"))
	if not with_cottage:
		return
	# The keeper's cottage beside the tower.
	var kc := Transform3D(Basis(), Vector3(base_radius + 4.2, 0, 1.0))
	b.box(paint, kc * Transform3D(Basis(), Vector3(0, 1.5, 0)), Vector3(5.0, 3.0, 4.2), WHITE)
	b.gable_roof(Mats.get_mat("shingle"), kc * Transform3D(Basis(), Vector3(0, 3.0, 0)), 4.2, 5.0, 1.7, 0.3, 0.16, RED)
	b.gable_wall(paint, kc * Transform3D(Basis(), Vector3(0, 3.0, 0)), 4.2, 1.7, 2.5, 1.0, WHITE)
	b.gable_wall(paint, kc * Transform3D(Basis(), Vector3(0, 3.0, 0)), 4.2, 1.7, -2.5, -1.0, WHITE)
	b.box(solid, kc * Transform3D(Basis(), Vector3(0, 1.1, -2.12)), Vector3(0.9, 2.0, 0.1), Color("#2f5560"))
	for x in [-1.5, 1.5]:
		b.box(Mats.get_mat("window_lit"), kc * Transform3D(Basis(), Vector3(x, 1.8, -2.12)), Vector3(0.8, 0.8, 0.08), Color("#3d5a78"))


func _build_colliders() -> void:
	add_cylinder("wall", Vector3(0, -1.5, 0), base_radius + 0.7, 2.2)
	add_cylinder("wall", Vector3.ZERO, (base_radius + top_radius) * 0.5, height)
	var gy := gallery_y()
	add_cylinder("wall", Vector3(0, gy - 0.35, 0), GALLERY_R, 0.35)
	add_cylinder("wall", Vector3(0, gy, 0), 1.6, 4.4)
	if with_cottage:
		add_box("wall", Vector3(base_radius + 4.2, 2.3, 1.0), Vector3(5.0, 4.6, 4.2))


## The lamp's beam: two long soft cones turning slowly, shown at dusk.
func _after_build() -> void:
	_beam = Node3D.new()
	_beam.name = "Beam"
	_beam.position = Vector3(0, gallery_y() + 1.5, 0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.0, 0.85, 0.5, 0.06)
	m.disable_receive_shadows = true
	for s in [-1.0, 1.0]:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.3
		cm.bottom_radius = 3.2
		cm.height = 70.0
		cm.cap_top = false
		cm.cap_bottom = false
		cm.radial_segments = 16
		cone.mesh = cm
		cone.material_override = m
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.rotation = Vector3(0, 0, s * PI * 0.5 + 0.03 * s)
		cone.position = Vector3(s * 35.0, -1.0, 0)
		_beam.add_child(cone)
	_beam.visible = false
	add_child(_beam)


func _process(delta: float) -> void:
	if _beam == null:
		return
	var town := get_parent() as TownBuilder
	_beam.visible = town != null and town.time_of_day == "dusk"
	if _beam.visible:
		_beam.rotate_y(delta * 0.6)
