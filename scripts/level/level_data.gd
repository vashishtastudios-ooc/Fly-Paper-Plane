class_name LevelData
extends Resource
## Everything that defines one flight. Positions are in world meters (town runs along -Z).

@export var level_name := "Flight"
## The map this flight is flown on (see Game.MAPS): "linden" or "harbour".
@export var map := "linden"
@export var short_goal := ""
@export_multiline var goal_text := ""

@export_group("Launch")
## "balcony" or "roof". The level spawns a matching launch platform prop.
@export var platform_kind := "balcony"
## Floor center where the kid stands.
@export var platform_position := Vector3.ZERO
## Yaw the platform faces (outward, same convention as the plane: forward = (-sin, 0, -cos)).
@export var platform_yaw := 0.0
## The kid throws toward this point.
@export var aim_point := Vector3.ZERO

@export_group("Route")
## Waypoints of the intended flight line (handles are smoothed at runtime).
@export var route: Curve3D

## Radius of the gold route rings.
@export var gate_radius := 1.7
## Rings inside this box use small_gate_radius (e.g. inside a classroom).
@export var small_gate_box := AABB()
@export var small_gate_radius := 1.0
## More boxes with small rings (e.g. an archway and a window in the same flight).
@export var small_gate_boxes: Array[AABB] = []
## "gold" rings or "lantern" hoops of paper lanterns.
@export var gate_style := "gold"

@export_group("Mood")
## "golden" (golden hour) or "dusk" (Lantern Night).
@export var time_of_day := "golden"
## Optional extra scene under res://scenes/gameplay/ (e.g. "lantern_festival").
@export var decor := ""

@export_group("Landing pad")
@export var pad_position := Vector3.ZERO
@export var pad_radius := 2.5
@export var pad_name := "Landing spot"
@export var par_time := 30.0

@export_group("Air and pickups")
## Each entry: {"x", "z", "radius", "strength", "top", "style"} where style is "golden" or "smoke".
## Optional "base": height the column starts at (e.g. a classroom floor); defaults to the ground.
@export var thermals: Array = []
## Sea breezes: [{x, z, radius, dx, dz, strength, top}] (see WindZone).
@export var wind_zones: Array = []
@export var bonus_stars: PackedVector3Array = PackedVector3Array()
@export var has_bonus_ring := false
@export var bonus_ring_position := Vector3.ZERO
## Axis the bonus ring faces (the direction the plane flies through it).
@export var bonus_ring_axis := Vector3.RIGHT
@export var bonus_ring_radius := 1.0
@export var bonus_ring_points := 500
@export var bonus_ring_message := "Under the bridge! +500"

@export_group("Hazards")
## Each entry: {"a": Vector3, "b": Vector3, "sag": float, "kind": "bunting" | "washing" | "line"}.
@export var hazard_lines: Array = []


func start_yaw() -> float:
	var d := aim_point - platform_position
	return atan2(-d.x, -d.z)


func route_points() -> PackedVector3Array:
	var pts := PackedVector3Array()
	if route:
		for i in route.point_count:
			pts.append(route.get_point_position(i))
	return pts
