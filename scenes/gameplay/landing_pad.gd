class_name LandingPad
extends Node3D
## The landing target: gold ground ring, center dot and a soft vertical light beam.
## Its collider lives on the LandingPads physics layer (layer 2). Origin = pad top center.

@export var radius := 2.5
@export var pad_name := "Landing spot"

var _ring: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	var t := TorusMesh.new()
	t.inner_radius = radius - 0.12
	t.outer_radius = radius + 0.06
	t.rings = 48
	t.ring_segments = 6
	_ring.mesh = t
	_ring.scale = Vector3(1, 0.25, 1)
	_ring.position.y = 0.04
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color("#f6c445")
	rm.emission_enabled = true
	rm.emission = Color("#ffc94d")
	rm.emission_energy_multiplier = 1.6
	_ring.material_override = rm
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

	var inner := MeshInstance3D.new()
	var t2 := TorusMesh.new()
	t2.inner_radius = radius * 0.55 - 0.05
	t2.outer_radius = radius * 0.55 + 0.03
	t2.rings = 36
	t2.ring_segments = 4
	inner.mesh = t2
	inner.scale = Vector3(1, 0.2, 1)
	inner.position.y = 0.035
	inner.material_override = Mats.additive(Color(1, 0.86, 0.5, 0.6))
	inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inner)

	var dot := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.22
	cm.bottom_radius = 0.22
	cm.height = 0.02
	cm.radial_segments = 20
	dot.mesh = cm
	dot.position.y = 0.04
	dot.material_override = rm
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dot)

	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	var bm := CylinderMesh.new()
	bm.top_radius = radius * 0.75
	bm.bottom_radius = radius * 0.9
	bm.height = 26.0
	bm.cap_top = false
	bm.cap_bottom = false
	bm.radial_segments = 24
	beam.mesh = bm
	beam.position.y = 13.0
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/beam.gdshader")
	beam.material_override = sm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)

	var body := StaticBody3D.new()
	body.name = "PadBody"
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("kind", "pad")
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 0.1
	cs.shape = cyl
	cs.position.y = -0.05
	body.add_child(cs)
	add_child(body)


func _process(delta: float) -> void:
	_t += delta
	var s := 1.0 + 0.03 * sin(_t * 3.0)
	_ring.scale = Vector3(s, 0.25, s)
