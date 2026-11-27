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
	"stall": ["One plane, extra crispy!", "Into the apples! Five a day, done.", "Nobody wanted those tomatoes anyway."],
	"tent": ["Flump! Into the canvas.", "The tent is not a trampoline."],
	"banner": ["Wrapped up like a present!", "You were meant to read it, not hug it."],
	"sheet": ["Folded and put away!", "Fresh, clean and stuck.", "Now it smells of lavender."],
	"washing": ["Pegged out to dry!", "One sock, one shirt, one plane."],
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


## A tip for after a crash, by what went wrong. `near` = it came down close to the landing spot.
static func crash_tip(kind: String, near: bool) -> String:
	match kind:
		"ground", "stopped":
			if near:
				return "So close! Keep the nose up a touch at the end, or tap %s for a little lift." % Settings.key_label("gust")
			return "Ran out of height. Ride the rising air to climb, and don't dive too early."
		"tree":
			return "Trees are sticky! Stay over the dotted line and climb in rising air to clear them."
		"water", "soaked":
			return "Water pulls the plane down. Keep your speed up when you fly low over it."
		"wall", "bridge", "car":
			return "Start turning earlier. Hold %s or %s while turning for a sharper turn." % [Settings.key_label("roll_left"), Settings.key_label("roll_right")]
		"glass", "greenhouse":
			return "That window was shut. Look for the open one right next to it."
		"lamp", "furniture", "banister", "ceiling", "fan":
			return "Indoors, line up early and keep the plane steady through the room."
		"line":
			return "Lines and washing: fly under or over them, never through!"
		"stall", "tent":
			return "Line up early for the gaps, and keep the plane steady between the stalls."
		"banner":
			return "Duck under the banners and signs: stay low and level as you go through."
		"sheet":
			return "Each wall of sheets has one gap, and it moves from side to side. Line up early!"
		"washing":
			return "Watch the washing lines: over one, under the next. The rings show the way."
		"out":
			return "Follow the dotted line and the arrow at the top to stay on course."
	return "Follow the dotted line through the rings: it always leads to the landing spot."


## Tips shown on the loading screen, one at a time.
const LOADING_TIPS := [
	"Tip: land in the gold bullseye for three ribbons and a bonus.",
	"Tip: rising air lifts you. Fly through it, or circle inside a wide one.",
	"Tip: diving builds speed, and speed can be traded back for height.",
	"Tip: hold a roll key while turning for a sharper turn.",
	"Tip: rings in a row make a streak. How long can you keep it?",
	"Tip: your best run comes back as a ghost to race.",
	"Tip: earn ribbons to unlock new planes, papers and trails in the Hangar.",
	"Tip: every star collected is worth 100 points.",
	"Tip: slow down and come in gently for a soft touchdown.",
]


const ZONE := {
	"bullseye": ["Dead centre! Show-off.", "Right on the dot!", "Pilot of the year!", "Did you see that?!"],
	"inner": ["So close to perfect!", "A whisker off the bullseye.", "Smooth flying, captain."],
	"outer": ["On target. Now aim for the gold!", "Landed! Closer next time?", "Not bad. The centre is waiting."],
	"edge": ["Phew, just made it!", "Paper down! That counts.", "A bit wobbly, but home!"],
}


static func landing_zone(zone: String) -> String:
	var pool: Array = ZONE.get(zone, ZONE.outer)
	return pool[randi() % pool.size()]


static func landing(ribbons: int) -> String:
	var pool: Array = LAND.get(clampi(ribbons, 1, 3))
	return pool[randi() % pool.size()]
