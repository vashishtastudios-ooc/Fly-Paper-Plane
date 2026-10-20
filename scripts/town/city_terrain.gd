class_name CityTerrain
extends RefCounted
## City Rooftops' ground: a flat grid of streets. Main Avenue runs along z at x = 0 (the town
## runs toward -Z like the other maps), with side streets every 48 m each way. The blocks between
## the streets hold the buildings (CityBlock), split into four lots by two narrow alleys.

## Centre lines of the north-south streets and the east-west streets.
const STREETS_X := [-96.0, -48.0, 0.0, 48.0, 96.0]
const STREETS_Z := [72.0, 24.0, -24.0, -72.0, -120.0, -168.0, -216.0]
const STREET_W := 12.0
const AVENUE_W := 16.0
const ALLEY_W := 4.0
## The west column of blocks has a wider alley down its middle at x = -72 (Flight 2's Alley Run).
const WIDE_ALLEY_W := 6.0
const ALLEY_RUN_X := -72.0
const SIDEWALK := 2.2
const BOUNDS_X := 150.0
const BOUNDS_Z_MAX := 130.0
const BOUNDS_Z_MIN := -280.0


static func ground_height(_x: float, _z: float) -> float:
	return 0.0


static func street_width(x_street: float) -> float:
	return AVENUE_W if x_street == 0.0 else STREET_W


## The blocks as Rect2 (x, z, size x, size z) between the streets, not counting the sidewalks.
static func blocks() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in STREETS_X.size() - 1:
		var x0: float = STREETS_X[i] + street_width(STREETS_X[i]) * 0.5
		var x1: float = STREETS_X[i + 1] - street_width(STREETS_X[i + 1]) * 0.5
		for j in STREETS_Z.size() - 1:
			var z1: float = STREETS_Z[j] - STREET_W * 0.5
			var z0: float = STREETS_Z[j + 1] + STREET_W * 0.5
			out.append(Rect2(x0, z0, x1 - x0, z1 - z0))
	return out


## Width of the alleys inside a block.
static func alley_width(block: Rect2) -> float:
	return WIDE_ALLEY_W if block.get_center().x < -60.0 else ALLEY_W


static func water_name(_x: float, _z: float) -> String:
	return "the fountain"


static func out_of_bounds(p: Vector3) -> bool:
	return absf(p.x) > BOUNDS_X or p.z > BOUNDS_Z_MAX or p.z < BOUNDS_Z_MIN
