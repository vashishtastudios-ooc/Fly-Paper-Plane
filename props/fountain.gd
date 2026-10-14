extends Prop
## Tiered stone fountain with a water spray. Origin = ground at the basin center.

@export var basin_radius := 3.2


func _build(b: MeshBuilder) -> void:
	var stone := Mats.get_mat("stone")
	var sc := Color("#e6dccb")
	var r := basin_radius
	b.cylinder(stone, Transform3D(), r + 0.2, r + 0.2, 0.18, 16, sc.darkened(0.05))
	b.cylinder(stone, Transform3D(Basis(), Vector3(0, 0.18, 0)), r, r, 0.5, 16, sc)
	b.cylinder(stone, Transform3D(Basis(), Vector3(0, 0.68, 0)), r + 0.12, r + 0.12, 0.1, 16, sc.lightened(0.05))
	b.cylinder(Mats.get_mat("water"), Transform3D(Basis(), Vector3(0, 0.6, 0)), r - 0.15, r - 0.15, 0.02, 16, Color.WHITE, true)
	b.cylinder(stone, Transform3D(Basis(), Vector3(0, 0.6, 0)), 0.45, 0.3, 1.2, 10, sc, true, true)
	b.cylinder(stone, Transform3D(Basis(), Vector3(0, 1.75, 0)), 0.3, 1.5, 0.35, 14, sc, true, true)
	b.cylinder(Mats.get_mat("water"), Transform3D(Basis(), Vector3(0, 2.06, 0)), 1.4, 1.4, 0.02, 14, Color.WHITE, true)
	b.cylinder(stone, Transform3D(Basis(), Vector3(0, 2.1, 0)), 0.22, 0.16, 0.8, 8, sc, true, true)
	b.cylinder(stone, Transform3D(Basis(), Vector3(0, 2.85, 0)), 0.16, 0.8, 0.25, 12, sc, true, true)
	b.sphere(stone, Vector3(0, 3.3, 0), Vector3(0.22, 0.3, 0.22), 4, 8, sc)


func _after_build() -> void:
	var p := GPUParticles3D.new()
	p.name = "Spray"
	p.amount = 40 if Settings.is_mobile else 90
	p.lifetime = 1.3
	p.position = Vector3(0, 3.5, 0)
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 6, 8))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 22.0
	pm.initial_velocity_min = 2.6
	pm.initial_velocity_max = 3.4
	pm.gravity = Vector3(0, -7.5, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.color = Color(0.85, 0.93, 1.0, 0.75)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	q.material = Mats.soft_alpha(Color(0.9, 0.96, 1.0, 0.8), TexGen.get_tex("soft_dot"))
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	# Low bubbling jets around the lower tier.
	var p2 := p.duplicate() as GPUParticles3D
	p2.name = "LowerSpray"
	p2.position = Vector3(0, 2.1, 0)
	var pm2 := pm.duplicate() as ParticleProcessMaterial
	pm2.spread = 80.0
	pm2.initial_velocity_min = 1.2
	pm2.initial_velocity_max = 1.6
	p2.process_material = pm2
	p2.amount = 24 if Settings.is_mobile else 50
	add_child(p2)


func _build_colliders() -> void:
	add_cylinder("wall", Vector3.ZERO, basin_radius + 0.15, 0.8)
	add_cylinder("wall", Vector3(0, 0.8, 0), 0.45, 1.3)
	add_cylinder("wall", Vector3(0, 1.75, 0), 1.5, 0.4)
	add_cylinder("wall", Vector3(0, 2.1, 0), 0.25, 1.4)
