class_name HarbourTerrain
extends RefCounted
## Seaside Harbour's ground: a bay opening to the sea toward -Z. A stone quay runs round the
## middle of the bay, a sandy beach lies to the west, rocks rise to the east up to the lighthouse
## headland, and the town climbs the hill behind (toward +Z). The sea surface is Terrain.WATER_Y.

const QUAY_Y := 1.0
## Half-width of the quay along the shore (beyond it: beach to the west, rocks to the east).
const QUAY_HALF := 42.0
const LIGHTHOUSE := Vector3(104, 0, -82)
const BOUNDS_X := 175.0
const BOUNDS_Z_MAX := 175.0
const BOUNDS_Z_MIN := -235.0


## The waterline (z) along x: a bay curving in at the middle and the lighthouse point to the east.
static func shore_z(x: float) -> float:
	return -40.0 + 30.0 * exp(-pow(x / 70.0, 2.0)) - 60.0 * exp(-pow((x - LIGHTHOUSE.x) / 20.0, 2.0))


## Distance inland from the waterline (negative out at sea).
static func inland(x: float, z: float) -> float:
	return z - shore_z(x)


static func quay_weight(x: float) -> float:
	return 1.0 - smoothstep(QUAY_HALF - 4.0, QUAY_HALF + 4.0, absf(x))


static func ground_height(x: float, z: float) -> float:
	var d := inland(x, z)
	# Beach: a gentle slope from the seabed up onto the sand.
	var h := lerpf(-3.4, 0.5, smoothstep(-16.0, 10.0, d)) + smoothstep(10.0, 30.0, d) * 0.6
	# Quay: a straight stone wall down into deep water.
	var q := quay_weight(x)
	if q > 0.0:
		h = lerpf(h, QUAY_Y if d > 0.0 else -3.8, q)
	# Rocks to the east, rising to the lighthouse headland.
	var rock := smoothstep(QUAY_HALF + 4.0, 70.0, x)
	h += rock * smoothstep(-4.0, 6.0, d) * (2.4 + 1.4 * sin(z * 0.2 + x * 0.1))
	var head := exp(-pow((x - LIGHTHOUSE.x) / 22.0, 2.0)) * smoothstep(-8.0, 3.0, d)
	h = lerpf(h, maxf(h, 7.0 + sin(z * 0.15) * 0.6), head)
	# The hill the town climbs.
	h += smoothstep(16.0, 125.0, d) * 18.0 * (0.8 + 0.2 * sin(x * 0.025))
	h += smoothstep(120.0, 200.0, d) * 10.0
	return h


static func water_name(x: float, z: float) -> String:
	return "the harbour" if absf(x) < 60.0 and z > -125.0 else "the sea"


static func out_of_bounds(p: Vector3) -> bool:
	return absf(p.x) > BOUNDS_X or p.z > BOUNDS_Z_MAX or p.z < BOUNDS_Z_MIN
