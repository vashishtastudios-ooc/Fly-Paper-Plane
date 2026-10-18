class_name Quips
## Little jokes for the result card: one picked at random after a crash or a landing.

const CRASH := [
	"Paper planes don't need seatbelts. Lucky!",
	"That was a test flight. Totally on purpose.",
	"Fold, flatten, fly again!",
	"Every great pilot starts with a crumple.",
	"Nothing a little smoothing out can't fix.",
	"Ten out of ten for enthusiasm!",
	"The plane says it's fine. Mostly.",
	"Who put that there?!",
	"Note to self: steer next time.",
	"New crease, same brave plane.",
]

const BY_KIND := {
	"tree": ["The tree wanted a closer look.", "Leaves 1, Plane 0.", "Now it's a bird's nest."],
	"water": ["Instant paper boat!", "Paper and water: not best friends.", "Glug glug glug..."],
	"soaked": ["Soggy, but smiling.", "Paper and water: not best friends."],
	"wall": ["Walls don't move. Noted.", "Bonk! It came out of nowhere.", "That wall had it coming."],
	"bridge": ["The bridge wins this round.", "Under, not into!"],
	"glass": ["Rude! Who closed the window?", "So clean you couldn't see it!"],
	"greenhouse": ["The tomatoes saw everything.", "So clean you couldn't see it!"],
	"fan": ["Wheee... whack!", "Round and round and... down."],
	"lamp": ["Clonk! Lights out.", "Lamps are not landing spots."],
	"furniture": ["Mind the furniture, captain!", "That chair came out of nowhere."],
	"banister": ["Banisters are for sliding, not flying."],
	"ceiling": ["Aim lower, superstar!", "Too high! Ouch."],
	"line": ["Tangled up! Whoops.", "Strings are for kites."],
	"out": ["Off on an adventure without you.", "Bye bye, plane! See you next town."],
	"stopped": ["So close! A little further next time.", "Nearly there! Keep the nose up."],
	"ground": ["So close! A little further next time.", "The ground came up fast!"],
}

const LAND := {
	3: ["Nailed it!", "Like a bird. A paper bird.", "Pilot of the year!", "Did you see that?!"],
	2: ["Nice one!", "Smooth flying, captain.", "The crowd goes wild!"],
	1: ["Paper down! That counts.", "Landed! The rest is details.", "A bit wobbly, but home!"],
}


static func crash(kind: String) -> String:
	var pool: Array = BY_KIND.get(kind, [])
	# Mix in the general ones too, so the same line doesn't keep coming back.
	if pool.is_empty() or randf() < 0.35:
		pool = CRASH
	return pool[randi() % pool.size()]


static func landing(ribbons: int) -> String:
	var pool: Array = LAND.get(clampi(ribbons, 1, 3))
	return pool[randi() % pool.size()]
