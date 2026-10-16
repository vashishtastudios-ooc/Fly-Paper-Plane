class_name LevelRuntime
extends Node3D
## Spawns and runs one level: route (dotted line), rings, stars, thermals, landing pad,
## hazards and wayfinding helpers (guide arrow and touchdown predictor).

signal star_collected(pos: Vector3)
signal ring_passed(pos: Vector3)
signal bonus_ring_passed(pos: Vector3, points: int, message: String)

const THERMAL_SCENE := preload("res://scenes/gameplay/thermal.tscn")
const STAR_SCENE := preload("res://scenes/gameplay/star.tscn")
const GATE_SCENE := preload("res://scenes/gameplay/gate.tscn")
const PAD_SCENE := preload("res://scenes/gameplay/landing_pad.tscn")
const HAZARD_SCENE := preload("res://scenes/gameplay/hazard_line.tscn")

const DOT_SPACING := 2.4
const GATE_SPACING := 14.0
const VISIBLE_GATES := 4
const STAR_COUNT := 7
const PREDICT_RANGE := 55.0
const ARROW_AHEAD := 1.6
const ARROW_UP := 0.75
const BONUS_PASS_RADIUS := 1.45

var data: LevelData
var town: TownBuilder
var curve: Curve3D
var route_length := 0.0

var thermals: Array[Thermal] = []
var winds: Array[WindZone] = []
var stars: Array[StarPickup] = []
var gates: Array[Gate] = []
var hazards: Array[HazardLine] = []
var pad: LandingPad
var bonus_gate: Gate

var next_gate := 0
var stars_collected := 0
var rings_passed := 0
var bonus_points := 0
var bonus_taken := false

var _content: Node3D
var _dots: MultiMeshInstance3D
var _arrow: Node3D
var _marker: MeshInstance3D
var _marker_mat: StandardMaterial3D
var _arrow_mat: StandardMaterial3D


func _ready() -> void:
	_build_arrow()
	_build_marker()


# --- Building ----------------------------------------------------------------------------

func build(level_data: LevelData, town_builder: TownBuilder) -> void:
	data = level_data
	town = town_builder
	if town:
		town.set_time_of_day(data.time_of_day)
	StarPickup.set_night(data.time_of_day == "dusk")
	_arrow_mat.albedo_color = _route_color()
	if _content:
		_content.queue_free()
	_content = Node3D.new()
	_content.name = "Content"
	add_child(_content)
	thermals.clear()
	winds.clear()
	stars.clear()
	gates.clear()
	hazards.clear()
	bonus_gate = null

	curve = Curve3D.new()
	curve.bake_interval = 0.5
	var pts := data.route_points()
	for p in pts:
		curve.add_point(p)
	for i in pts.size():
		var prev := pts[maxi(i - 1, 0)]
		var next := pts[mini(i + 1, pts.size() - 1)]
		var t := (next - prev) / 6.0
		if i == 0 or i == pts.size() - 1:
			t *= 0.5
		curve.set_point_in(i, -t)
		curve.set_point_out(i, t)
	route_length = curve.get_baked_length()

	for th in data.thermals:
		var t: Thermal = THERMAL_SCENE.instantiate()
		t.radius = th.radius
		t.strength = th.strength
		t.top = th.top
		t.style = th.get("style", "lantern" if data.time_of_day == "dusk" else "golden")
		t.source_height = th.get("source", 0.0)
		t.ceiling = th.get("ceiling", INF)
		t.position = Vector3(th.x, th.get("base", Terrain.ground_height(th.x, th.z)), th.z)
		_content.add_child(t)
		thermals.append(t)
	for wz in data.wind_zones:
		var w := WindZone.new()
		w.radius = wz.get("radius", 18.0)
		w.direction = Vector3(wz.get("dx", 0.0), 0.0, wz.get("dz", 1.0))
		w.strength = wz.get("strength", 2.5)
		w.top = wz.get("top", 25.0)
		w.position = Vector3(wz.x, Terrain.surface_height(wz.x, wz.z), wz.z)
		_content.add_child(w)
		winds.append(w)

	for i in STAR_COUNT:
		var off := route_length * (0.1 + 0.8 * float(i) / float(STAR_COUNT - 1))
		_add_star(curve.sample_baked(off, true), false)
	for bp in data.bonus_stars:
		_add_star(bp, true)

	var off_g := route_length * 0.05
	while off_g <= route_length * 0.91 + 0.01:
		var gp := curve.sample_baked(off_g, true)
		# The golden bonus ring replaces route rings right next to it (e.g. under the arch).
		if not (data.has_bonus_ring and gp.distance_to(data.bonus_ring_position) < 7.5):
			var g: Gate = GATE_SCENE.instantiate()
			g.ring_radius = data.small_gate_radius if _in_small_box(gp) else data.gate_radius
			g.lantern = data.gate_style == "lantern"
			g.axis = _tangent(off_g)
			g.position = gp
			_content.add_child(g)
			gates.append(g)
		off_g += GATE_SPACING

	if data.has_bonus_ring:
		bonus_gate = GATE_SCENE.instantiate()
		bonus_gate.golden = true
		bonus_gate.ring_radius = data.bonus_ring_radius
		bonus_gate.tube = 0.07
		bonus_gate.axis = data.bonus_ring_axis
		bonus_gate.position = data.bonus_ring_position
		_content.add_child(bonus_gate)

	pad = PAD_SCENE.instantiate()
	pad.radius = data.pad_radius
	pad.pad_name = data.pad_name
	pad.position = data.pad_position
	_content.add_child(pad)

	for hz in data.hazard_lines:
		var h: HazardLine = HAZARD_SCENE.instantiate()
		h.a = hz.a
		h.b = hz.b
		h.sag = hz.get("sag", 1.0)
		h.kind = hz.get("kind", "bunting")
		h.with_posts = hz.get("posts", true)
		h.seed_value = int(absf(hz.a.z)) + 3
		_content.add_child(h)
		hazards.append(h)

	if data.decor != "":
		var decor_path := "res://scenes/gameplay/%s.tscn" % data.decor
		if ResourceLoader.exists(decor_path):
			_content.add_child((load(decor_path) as PackedScene).instantiate())
	_build_dots()
	reset_progress()


## Color of the dotted line and guide arrow: blue, or lantern orange with lantern hoops.
func _route_color() -> Color:
	return Color("#ffb066") if data and data.gate_style == "lantern" else UIKit.ROUTE


func _in_small_box(p: Vector3) -> bool:
	if data.small_gate_box.has_point(p):
		return true
	for box in data.small_gate_boxes:
		if box.has_point(p):
			return true
	return false


func _add_star(p: Vector3, is_bonus: bool) -> void:
	var s: StarPickup = STAR_SCENE.instantiate()
	s.bonus = is_bonus
	s.position = p
	_content.add_child(s)
	stars.append(s)


func _tangent(off: float) -> Vector3:
	var a := curve.sample_baked(maxf(0.0, off - 0.6), true)
	var b := curve.sample_baked(minf(route_length, off + 0.6), true)
	return (b - a).normalized()


func _build_dots() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# Small glowing additive dots (camera-facing), faded out right next to the lens.
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.3)
	var mat := Mats.additive(_route_color(), TexGen.get_tex("soft_dot"))
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 0.8
	mat.distance_fade_max_distance = 2.5
	q.material = mat
	mm.mesh = q
	var count := int(route_length / DOT_SPACING) + 1
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, Transform3D(Basis(), curve.sample_baked(i * DOT_SPACING, true)))
	_dots = MultiMeshInstance3D.new()
	_dots.name = "FlightLine"
	_dots.multimesh = mm
	_dots.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_content.add_child(_dots)


func _build_arrow() -> void:
	_arrow = Node3D.new()
	_arrow.name = "GuideArrow"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = UIKit.ROUTE
	_arrow_mat = mat
	mat.no_depth_test = false
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.11
	cm.height = 0.24
	cm.radial_segments = 10
	cone.mesh = cm
	cone.material_override = mat
	cone.rotation.x = -PI * 0.5
	cone.position = Vector3(0, 0, -0.22)
	_arrow.add_child(cone)
	var shaft := MeshInstance3D.new()
	var sh := CylinderMesh.new()
	sh.top_radius = 0.03
	sh.bottom_radius = 0.03
	sh.height = 0.3
	sh.radial_segments = 6
	shaft.mesh = sh
	shaft.material_override = mat
	shaft.rotation.x = -PI * 0.5
	shaft.position = Vector3(0, 0, 0.05)
	_arrow.add_child(shaft)
	for c in _arrow.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow.visible = false
	add_child(_arrow)


func _build_marker() -> void:
	_marker = MeshInstance3D.new()
	_marker.name = "TouchdownMarker"
	var t := TorusMesh.new()
	t.inner_radius = 0.62
	t.outer_radius = 0.78
	t.rings = 32
	t.ring_segments = 4
	_marker.mesh = t
	_marker.scale = Vector3(1, 0.2, 1)
	_marker_mat = Mats.additive(Color(1, 1, 1, 0.8))
	_marker.material_override = _marker_mat
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)


# --- Progress ------------------------------------------------------------------------------

func reset_progress() -> void:
	next_gate = 0
	stars_collected = 0
	rings_passed = 0
	bonus_points = 0
	bonus_taken = false
	for s in stars:
		s.reset()
	if bonus_gate:
		bonus_gate.set_look(Gate.Look.NEXT)
	_refresh_gates()
	_arrow.visible = false
	_marker.visible = false


func stars_total() -> int:
	return stars.size()


func _refresh_gates() -> void:
	for i in gates.size():
		var g := gates[i]
		if i < next_gate:
			g.set_look(Gate.Look.PASSED)
		elif i == next_gate:
			g.set_look(Gate.Look.NEXT)
		elif i < next_gate + VISIBLE_GATES:
			g.set_look(Gate.Look.FUTURE)
		else:
			g.set_look(Gate.Look.HIDDEN)


static func _seg_point_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Called by the plane every physics tick with the previous and new positions.
func process_flight(prev: Vector3, pos: Vector3) -> void:
	for s in stars:
		if not s.collected and _seg_point_dist(s.global_position, prev, pos) < StarPickup.PICKUP_RADIUS:
			s.collect()
			stars_collected += 1
			star_collected.emit(s.global_position)
	var changed := false
	while next_gate < gates.size():
		var g := gates[next_gate]
		var gp := g.global_position
		if _seg_point_dist(gp, prev, pos) < g.pass_radius():
			rings_passed += 1
			next_gate += 1
			changed = true
			ring_passed.emit(gp)
			continue
		if (pos - gp).dot(g.axis) > 0.5 and pos.distance_to(gp) < 25.0:
			next_gate += 1
			changed = true
			continue
		break
	if changed:
		_refresh_gates()
	if bonus_gate and not bonus_taken and _seg_point_dist(bonus_gate.global_position, prev, pos) < BONUS_PASS_RADIUS \
			and (pos - bonus_gate.global_position).dot(bonus_gate.axis) > -0.05:
		bonus_taken = true
		bonus_points += data.bonus_ring_points
		bonus_gate.set_look(Gate.Look.PASSED)
		bonus_ring_passed.emit(bonus_gate.global_position, data.bonus_ring_points, data.bonus_ring_message)


# --- Air -----------------------------------------------------------------------------------

## Sideways wind (m/s) at a point, from the level's sea breezes.
func wind_at(p: Vector3) -> Vector3:
	var w := Vector3.ZERO
	for z in winds:
		w += z.wind_at(p)
	return w


func lift_at(p: Vector3) -> float:
	var l := 0.0
	for t in thermals:
		l += t.lift_at(p)
	if Terrain.is_water(p.x, p.z):
		l -= 0.3
	return l


# --- Pad and hazards ----------------------------------------------------------------------------

func pad_top() -> float:
	return data.pad_position.y


func pad_radius() -> float:
	return data.pad_radius


func horizontal_distance_to_pad(p: Vector3) -> float:
	return Vector2(p.x - data.pad_position.x, p.z - data.pad_position.z).length()


func pad_surface_under(p: Vector3) -> float:
	if horizontal_distance_to_pad(p) < data.pad_radius:
		return pad_top()
	return -INF


## Height above the pad surface at which the plane counts as touching down.
const TOUCHDOWN_HEIGHT := 0.3


## True when the plane has actually reached the pad surface (within TOUCHDOWN_HEIGHT),
## so it can glide over the pad and settle near the center.
func is_landing(_prev: Vector3, pos: Vector3) -> bool:
	if horizontal_distance_to_pad(pos) >= data.pad_radius + 0.4:
		return false
	var dy := pos.y - pad_top()
	return dy >= -0.3 and dy <= TOUCHDOWN_HEIGHT


func pad_contact_point(pos: Vector3) -> Vector3:
	return Vector3(pos.x, pad_top() + 0.03, pos.z)


## Checks the plane's movement against level and town hazard lines.
## Returns {"message", "point"} on contact, or an empty dictionary.
func hazard_hit(prev: Vector3, pos: Vector3) -> Dictionary:
	var lines: Array = hazards.duplicate()
	if town:
		lines.append_array(town.hazard_lines)
	for h in lines:
		var pt = h.hit_point(prev, pos)
		if pt != null:
			return {"message": h.message(), "point": pt}
	return {}


# --- Wayfinding ------------------------------------------------------------------------------

## The current target: the next ring, or the pad after the last ring.
func current_target() -> Dictionary:
	if next_gate < gates.size():
		return {"position": gates[next_gate].global_position, "label": "Ring %d of %d" % [next_gate + 1, gates.size()], "is_pad": false}
	return {"position": data.pad_position + Vector3(0, 0.3, 0), "label": data.pad_name, "is_pad": true}


## Updates the 3D guide arrow and the touchdown predictor. Call every frame while flying.
func update_guides(plane: PaperPlane) -> void:
	if plane == null or plane.mode != PaperPlane.Mode.FLYING:
		_arrow.visible = false
		_marker.visible = false
		return
	var p := plane.get_global_transform_interpolated().origin
	var tgt: Vector3 = current_target().position
	var flat := Vector3(-sin(plane.state.yaw), 0, -cos(plane.state.yaw))
	var ap := p + flat * ARROW_AHEAD + Vector3.UP * ARROW_UP
	_arrow.visible = p.distance_to(tgt) > 5.0
	if _arrow.visible:
		_arrow.global_position = ap
		if ap.distance_to(tgt) > 0.01:
			var up := Vector3.UP if absf((tgt - ap).normalized().dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
			_arrow.look_at(tgt, up)
	if horizontal_distance_to_pad(p) < PREDICT_RANGE:
		var pred := plane.predict_touchdown()
		_marker.visible = pred.hit
		if pred.hit:
			_marker.global_position = pred.position + Vector3(0, 0.05, 0)
			var inside := horizontal_distance_to_pad(pred.position) < data.pad_radius
			_marker_mat.albedo_color = Color(0.45, 1.0, 0.5, 0.95) if inside else Color(1.0, 0.95, 0.85, 0.75)
	else:
		_marker.visible = false


func hide_guides() -> void:
	_arrow.visible = false
	_marker.visible = false
