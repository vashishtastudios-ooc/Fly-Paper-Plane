class_name Terrain
extends RefCounted
## Analytic terrain: ground height, river and town bounds. Shared by the town builder,
## the flight model, the camera and props (kept separate to avoid preload cycles).

const RIVER_Z := -300.0
const WATER_Y := -1.55
const BED_Y := -2.6
const BOUNDS_X := 90.0
const BOUNDS_Z_MAX := 45.0
const BOUNDS_Z_MIN := -650.0


static func ground_height(x: float, z: float) -> float:
	var h := 0.0
	var ax := absf(x)
	var hill := smoothstep(44.0, 78.0, ax)
	if hill > 0.0:
		h += hill * (4.5 + 3.5 * sin(z * 0.019 + x * 0.021) + 2.2 * sin(z * 0.047 - x * 0.033) + (ax - 44.0) * 0.12)
	h += smoothstep(30.0, 90.0, z) * 5.0
	h += smoothstep(-640.0, -720.0, z) * 8.0
	var d := absf(z - RIVER_Z)
	var river := 1.0 - smoothstep(7.0, 16.0, d)
	return lerpf(h, BED_Y, river)


## Ground or water height (whichever is higher).
static func surface_height(x: float, z: float) -> float:
	return maxf(ground_height(x, z), WATER_Y)


static func is_water(x: float, z: float) -> bool:
	return ground_height(x, z) < WATER_Y


static func out_of_bounds(p: Vector3) -> bool:
	return absf(p.x) > BOUNDS_X or p.z > BOUNDS_Z_MAX or p.z < BOUNDS_Z_MIN
