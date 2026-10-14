class_name Prop
extends Node3D
## Base for procedural props. Each prop lives in its own scene. On _ready it builds its
## procedural "Model" child unless the scene already contains a node named "Model"
## (drop a real model in as "Model" to replace the procedural one). Colliders are always
## created so gameplay keeps working with swapped models.

const LAYER_WORLD := 1
const LAYER_PADS := 2

## Shared instancing batcher. When null the prop creates and finalizes its own.
var batcher: Batcher
var _local_batcher := false
var _bodies := {}


func _ready() -> void:
	if batcher == null:
		batcher = Batcher.new()
		batcher.name = "Instances"
		_local_batcher = true
		add_child(batcher)
	if not has_node("Model"):
		var b := MeshBuilder.new()
		_build(b)
		if not b.is_empty():
			var model := b.build_instance("Model", _casts_shadow())
			model.visibility_range_end = _draw_distance()
			add_child(model)
	_build_colliders()
	_after_build()
	if _local_batcher:
		batcher.finalize()


## Override: add procedural geometry to the builder (local space).
func _build(_b: MeshBuilder) -> void:
	pass


## Override: add colliders using add_box / add_cylinder.
func _build_colliders() -> void:
	pass


## Override: extra nodes (particles, labels, animation).
func _after_build() -> void:
	pass


func _casts_shadow() -> bool:
	return true


## Distance beyond which the procedural model is culled (0 = never). Fog hides the cut.
func _draw_distance() -> float:
	return 340.0


## Adds a batched instance given a transform in this prop's local space.
func inst(kind: String, local_xf: Transform3D, col := Color.WHITE) -> Array:
	return batcher.add(kind, global_transform * local_xf, col)


func body(kind: String, layer := LAYER_WORLD) -> StaticBody3D:
	var key := "%s_%d" % [kind, layer]
	if _bodies.has(key):
		return _bodies[key]
	var sb := StaticBody3D.new()
	sb.name = "Body_" + kind
	sb.collision_layer = layer
	sb.collision_mask = 0
	sb.set_meta("kind", kind)
	add_child(sb)
	_bodies[key] = sb
	return sb


func add_box(kind: String, center: Vector3, size: Vector3, yaw := 0.0, layer := LAYER_WORLD) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), center)
	body(kind, layer).add_child(cs)


func add_box_xf(kind: String, xf: Transform3D, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = xf
	body(kind).add_child(cs)


func add_cylinder(kind: String, base: Vector3, radius: float, height: float, layer := LAYER_WORLD) -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	cs.position = base + Vector3(0, height * 0.5, 0)
	body(kind, layer).add_child(cs)


func add_sphere(kind: String, center: Vector3, radius: float) -> void:
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	cs.shape = shape
	cs.position = center
	body(kind).add_child(cs)


func add_convex(kind: String, points: PackedVector3Array) -> void:
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	cs.shape = shape
	body(kind).add_child(cs)
