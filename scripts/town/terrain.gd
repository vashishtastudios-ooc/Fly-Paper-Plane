class_name Terrain
extends RefCounted
## Analytic terrain: ground height, river and town bounds. Shared by the town builder,
## the flight model, the camera and props (kept separate to avoid preload cycles).

const RIVER_Z := -300.0
const WATER_Y := -1.55
const BED_Y := -2.6
const BOUNDS_X := 90.0
const BOUNDS_Z_MAX := 115.0
const BOUNDS_Z_MIN := -650.0

## Stone-walled ponds cut into the ground: [Rect2(x, z, size x, size z), water level, name].
## Edges sit on the 4 m terrain grid so the terrain mesh can leave a clean hole for them.
const PONDS := [
	[Rect2(-42, -402, 20, 48), -0.45, "the millpond"],
	[Rect2(-14, 18, 12, 12), -0.4, "the school pond"],
]
const POND_BED := -1.3


static func ground_height(x: float, z: float) -> float:
	if pond_at(x, z) >= 0:
		return POND_BED
	return land_height(x, z)


## The ground ignoring the ponds (used for the terrain mesh around their walls).
static func land_height(x: float, z: float) -> float:
	var h := 0.0
	var ax := absf(x)
	var hill := smoothstep(44.0, 78.0, ax)
	if hill > 0.0:
		h += hill * (4.5 + 3.5 * sin(z * 0.019 + x * 0.021) + 2.2 * sin(z * 0.047 - x * 0.033) + (ax - 44.0) * 0.12)
	h += smoothstep(72.0, 130.0, z) * 6.0
	h += smoothstep(-640.0, -720.0, z) * 8.0
	var d := absf(z - RIVER_Z)
	var river := 1.0 - smoothstep(7.0, 16.0, d)
	return lerpf(h, BED_Y, river)


## Index of the pond containing (x, z) (strictly inside its walls), or -1.
static func pond_at(x: float, z: float) -> int:
	for i in PONDS.size():
		var r: Rect2 = PONDS[i][0]
		if x > r.position.x and x < r.end.x and z > r.position.y and z < r.end.y:
			return i
	return -1


## Height of the water surface at (x, z): the river or a pond, or -INF on dry land.
static func water_height(x: float, z: float) -> float:
	var i := pond_at(x, z)
	if i >= 0:
		return PONDS[i][1]
	if ground_height(x, z) < WATER_Y:
		return WATER_Y
	return -INF


## What the water at (x, z) is called, for crash messages.
static func water_name(x: float, z: float) -> String:
	var i := pond_at(x, z)
	return PONDS[i][2] if i >= 0 else "the river"


## Ground or water height (whichever is higher).
static func surface_height(x: float, z: float) -> float:
	return maxf(ground_height(x, z), water_height(x, z))


static func is_water(x: float, z: float) -> bool:
	return water_height(x, z) > -INF


static func out_of_bounds(p: Vector3) -> bool:
	return absf(p.x) > BOUNDS_X or p.z > BOUNDS_Z_MAX or p.z < BOUNDS_Z_MIN
