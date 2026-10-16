class_name Batcher
extends Node3D
## Collects transforms of small repeated props and turns them into MultiMeshInstance3D nodes,
## split into chunks along Z so frustum culling and visibility ranges work well.

const CHUNK := 80.0

## Per-kind draw distance (0 = unlimited) and whether the kind casts shadows.
const RANGES := {
	"picket": 110.0, "flower": 90.0, "flowerbox": 120.0, "shutter": 160.0, "window": 220.0,
	"bunting_flag": 160.0, "grass": 70.0, "bush": 180.0, "hedge": 200.0, "mailbox": 90.0, "bench": 110.0,
	"lamp": 200.0, "reed": 90.0, "rock": 150.0, "cobble_post": 90.0, "shirt": 120.0, "sheet": 120.0,
}
const NO_SHADOW := ["grass", "flower", "flowerbox", "shutter", "window", "reed", "bunting_flag", "cobble_post", "rock"]

var _groups := {}
var _instances := {}  # key -> MultiMeshInstance3D
## Art style: Painterly. Leafy trees and bushes don't cast shadows from every leaf card; a plain
## rounded shape cast-shadow-only stands in, so the ground gets one soft tree shadow.
const SHADOW_PROXY := ["canopy", "bush"]
var _shadows := {}  # key -> shadow-only MultiMeshInstance3D
var finalized := false


## Adds one instance. Returns a handle usable with set_visible_instance().
func add(kind: String, xf: Transform3D, col := Color.WHITE) -> Array:
	var chunk := int(floor(xf.origin.z / CHUNK))
	var key := "%s|%d" % [kind, chunk]
	var g: Dictionary = _groups.get(key, {})
	if g.is_empty():
		g = {"kind": kind, "xforms": [], "colors": []}
		_groups[key] = g
	g.xforms.append(xf)
	g.colors.append(col)
	return [key, g.xforms.size() - 1]


func finalize() -> void:
	for key in _groups:
		var g: Dictionary = _groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = PropMeshes.get_mesh(g.kind)
		mm.instance_count = g.xforms.size()
		for i in g.xforms.size():
			mm.set_instance_transform(i, g.xforms[i])
			mm.set_instance_color(i, g.colors[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = key.replace("|", "_")
		mmi.multimesh = mm
		mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		var r: float = RANGES.get(g.kind, 0.0)
		if r > 0.0:
			mmi.visibility_range_end = r
			mmi.visibility_range_end_margin = 10.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if NO_SHADOW.has(g.kind):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif g.kind == "picket" or g.kind == "bush":
			mmi.cast_shadow = Settings.shadows_for_small_props()
		add_child(mmi)
		_instances[key] = mmi
		if Mats.painterly and SHADOW_PROXY.has(g.kind) and mmi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var smm := MultiMesh.new()
			smm.transform_format = MultiMesh.TRANSFORM_3D
			smm.mesh = PropMeshes.get_mesh(g.kind + "_shadow")
			smm.instance_count = g.xforms.size()
			for i in g.xforms.size():
				smm.set_instance_transform(i, g.xforms[i])
			var sh := MultiMeshInstance3D.new()
			sh.name = mmi.name + "_shadow"
			sh.multimesh = smm
			sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			sh.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			sh.visibility_range_end = mmi.visibility_range_end
			sh.visibility_range_end_margin = mmi.visibility_range_end_margin
			add_child(sh)
			_shadows[key] = sh
	finalized = true


func set_visible_instance(handle: Array, visible_flag: bool) -> void:
	if handle.is_empty() or not _instances.has(handle[0]):
		return
	var g: Dictionary = _groups[handle[0]]
	var mmi: MultiMeshInstance3D = _instances[handle[0]]
	var xf: Transform3D = g.xforms[handle[1]]
	if not visible_flag:
		xf = Transform3D(Basis().scaled(Vector3.ONE * 0.0001), xf.origin + Vector3(0, -50, 0))
	mmi.multimesh.set_instance_transform(handle[1], xf)
	if _shadows.has(handle[0]):
		(_shadows[handle[0]] as MultiMeshInstance3D).multimesh.set_instance_transform(handle[1], xf)
