extends Node
## Game state, level list, scoring rules and the save file.

signal state_changed(new_state: int)
signal cosmetics_changed

enum State { LOADING, MENU, INTRO, THROWING, FLYING, LANDED, CRASHED, RESULT }

const SAVE_PATH := "user://save.cfg"
## Testing switch: unlocks every flight and every Hangar item without earning ribbons.
## Set to false before publishing.
const UNLOCK_ALL_FOR_TESTING := true
const LEVEL_PATHS := [
	"res://levels/level_1.tres",
	"res://levels/level_2.tres",
	"res://levels/level_3.tres",
	"res://levels/level_4.tres",
	"res://levels/level_5.tres",
	"res://levels/level_6.tres",
	"res://levels/level_7.tres",
	"res://levels/level_8.tres",
	"res://levels/harbour_1.tres",
	"res://levels/harbour_2.tres",
	"res://levels/harbour_3.tres",
	"res://levels/harbour_4.tres",
	"res://levels/harbour_5.tres",
	"res://levels/harbour_6.tres",
	"res://levels/harbour_7.tres",
	"res://levels/harbour_8.tres",
	"res://levels/city_1.tres",
]

var state: int = State.LOADING
var levels: Array[LevelData] = []
var current_level := 0
## The first-flight tutorial (Flying Lessons) is played as level index LESSONS.
const LESSONS := -1
const LESSONS_PATH := "res://levels/lessons.tres"
var lessons_level: LevelData
var lessons_done := false
var unlocked := 1
var best_scores := {}   # level index -> int
var best_ribbons := {}  # level index -> int
## Selected cosmetics: {"paper", "trail", "sticker"} ids (see Cosmetics).
var cosmetics := Cosmetics.DEFAULTS.duplicate()
## Flight tips the player has already seen.
var tips_seen := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in LEVEL_PATHS:
		levels.append(load(p) as LevelData)
	lessons_level = load(LESSONS_PATH) as LevelData
	load_save()


func set_state(s: int) -> void:
	if s == state:
		return
	state = s
	state_changed.emit(s)


func level() -> LevelData:
	return lessons_level if current_level == LESSONS else levels[current_level]


func in_lessons() -> bool:
	return current_level == LESSONS


func finish_lessons() -> void:
	lessons_done = true
	Profile.progress().lessons_done = true
	Profile.check_achievements()
	save_game()


## A map's first flight opens with the map (ribbons); later ones after the flight before them.
func is_unlocked(i: int) -> bool:
	if i == LESSONS or UNLOCK_ALL_FOR_TESTING:
		return true
	for m in MAPS:
		var lv: Array = m.levels
		var k := lv.find(i)
		if k == 0:
			return total_ribbons() >= int(m.ribbons)
		if k > 0:
			return best_scores.has(lv[k - 1]) or i < unlocked
	return i < unlocked


## A flight's number within its map (1-based), and the map's name.
func flight_number(i: int) -> int:
	for m in MAPS:
		var k := (m.levels as Array).find(i)
		if k >= 0:
			return k + 1
	return i + 1


func map_name(i: int) -> String:
	for m in MAPS:
		if (m.levels as Array).has(i):
			return m.name
	return ""


## The flight after the current one on the same map, or -1.
func next_level() -> int:
	for m in MAPS:
		var lv: Array = m.levels
		var k := lv.find(current_level)
		if k >= 0:
			return lv[k + 1] if k + 1 < lv.size() else -1
	return -1


func has_next_level() -> bool:
	return next_level() >= 0


## Maps. Each lists its flights (indices into `levels`) and the ribbons (from any flight) that
## open it; "soon" maps show as Coming soon cards on the map page.
const MAPS := [
	{"id": "linden", "name": "Linden Lane", "blurb": "Gardens, windows and the old bridge", "levels": [0, 1, 2, 3, 4, 5, 6, 7], "ribbons": 0, "thumb": 2},
	{"id": "harbour", "name": "Seaside Harbour", "blurb": "Boats, the pier and sea breezes", "levels": [8, 9, 11, 10, 12, 13, 14, 15], "ribbons": 15, "thumb": 9},
	{"id": "city", "name": "City Rooftops", "blurb": "Water towers and narrow alleys", "levels": [16], "ribbons": 30, "thumb": 17},
	{"id": "farm", "name": "Maple Farm", "blurb": "Barns, fields and the windmill", "levels": [], "ribbons": 45, "soon": true},
	{"id": "snow", "name": "Snowy Village", "blurb": "Chimney smoke and twinkling lights", "levels": [], "ribbons": 60, "soon": true},
]


func total_ribbons() -> int:
	var n := 0
	for k in best_ribbons:
		n += int(best_ribbons[k])
	return n


func set_cosmetic(kind: String, id: String) -> void:
	if not Cosmetics.is_unlocked(kind, id, total_ribbons()):
		return
	cosmetics[kind] = id
	save_game()
	cosmetics_changed.emit()


func mark_tip_seen(tip: String) -> void:
	tips_seen[tip] = true
	save_game()


func reset_tips() -> void:
	tips_seen.clear()
	save_game()


# --- Scoring ---------------------------------------------------------------

## Returns the full landing score breakdown.
## stats: {dist, radius, vertical_impact, speed, stars, stars_total, time, par, rings, rolls, bonus}
func compute_landing_score(stats: Dictionary) -> Dictionary:
	var r: float = stats.radius
	var acc_frac := clampf(1.0 - stats.dist / (r + 0.4), 0.0, 1.0)
	var accuracy := maxi(0, roundi(acc_frac * 500.0))
	var soft_frac := clampf(1.0 - (stats.vertical_impact - 0.6) / 3.2, 0.0, 1.0) \
		* clampf(1.0 - (stats.speed - 11.0) / 8.0, 0.3, 1.0)
	var soft := roundi(soft_frac * 300.0)
	var stars_pts: int = stats.stars * 100
	var time_bonus := maxi(0, roundi((stats.par - stats.time) * 10.0))
	var ring_pts: int = stats.rings * 25
	var roll_pts: int = stats.rolls * 50
	var bonus_pts: int = stats.bonus
	var total := accuracy + soft + stars_pts + time_bonus + ring_pts + roll_pts + bonus_pts

	var headline := "Bumpy, but home!"
	if soft_frac > 0.8 and acc_frac > 0.6:
		headline = "Feather-soft!"
	elif soft_frac > 0.5:
		headline = "Smooth landing!"

	var missed: int = stats.stars_total - stats.stars
	var ribbons := 1
	if acc_frac > 0.6 and soft_frac > 0.6 and missed <= 1:
		ribbons = 3
	elif acc_frac > 0.45 and soft_frac > 0.45:
		ribbons = 2

	return {
		"headline": headline,
		"ribbons": ribbons,
		"accuracy": accuracy,
		"accuracy_frac": acc_frac,
		"soft": soft,
		"soft_frac": soft_frac,
		"stars": stars_pts,
		"time_bonus": time_bonus,
		"tricks": ring_pts + roll_pts + bonus_pts,
		"rings_pts": ring_pts,
		"rolls_pts": roll_pts,
		"bonus_pts": bonus_pts,
		"total": total,
	}


## Stores a successful landing. Returns true when it is a new best score.
func record_landing(level_index: int, total: int, ribbons: int) -> bool:
	var is_best := total > int(best_scores.get(level_index, -1))
	if is_best:
		best_scores[level_index] = total
	best_ribbons[level_index] = maxi(ribbons, int(best_ribbons.get(level_index, 0)))
	unlocked = clampi(maxi(unlocked, level_index + 2), 1, levels.size())
	save_game()
	return is_best


# --- Save ------------------------------------------------------------------
# Progress lives in the player's Profile (user://profile.json). The old save.cfg is only read
# once, to carry earlier progress over.

## A flight's stable id for the save: its file name (level_1, harbour_3...); "lessons" for the
## Flying Lessons.
func level_id(i: int) -> String:
	if i == LESSONS:
		return "lessons"
	return LEVEL_PATHS[i].get_file().get_basename()


func load_save() -> void:
	if Profile.is_new:
		_load_old_save()
		save_game()
		return
	var pr := Profile.progress()
	unlocked = clampi(int(pr.get("unlocked", 1)), 1, LEVEL_PATHS.size())
	lessons_done = bool(pr.get("lessons_done", false))
	tips_seen = (pr.get("tips_seen", {}) as Dictionary).duplicate()
	var cs := Profile.cosmetics()
	for kind in Cosmetics.DEFAULTS:
		cosmetics[kind] = str(cs.get(kind, Cosmetics.DEFAULTS[kind]))
	for i in LEVEL_PATHS.size():
		var id := level_id(i)
		if Profile.has_flight(id):
			var f := Profile.flight(id)
			if int(f.best_score) >= 0:
				best_scores[i] = int(f.best_score)
			if int(f.ribbons) > 0:
				best_ribbons[i] = int(f.ribbons)


## Progress from the save file used before the profile (version 1.1.4 and earlier).
func _load_old_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	unlocked = clampi(int(cfg.get_value("progress", "unlocked", 1)), 1, LEVEL_PATHS.size())
	for kind in Cosmetics.DEFAULTS:
		cosmetics[kind] = str(cfg.get_value("cosmetics", kind, Cosmetics.DEFAULTS[kind]))
	tips_seen = cfg.get_value("tips", "seen", {})
	lessons_done = bool(cfg.get_value("progress", "lessons_done", false))
	for i in LEVEL_PATHS.size():
		var key := "level_%d" % (i + 1)
		var f := Profile.flight(level_id(i))
		if cfg.has_section_key(key, "best_score"):
			best_scores[i] = int(cfg.get_value(key, "best_score"))
			f.best_score = best_scores[i]
			f.landings = maxi(int(f.landings), 1)
		if cfg.has_section_key(key, "ribbons"):
			best_ribbons[i] = int(cfg.get_value(key, "ribbons"))
			f.ribbons = best_ribbons[i]


func save_game() -> void:
	var pr := Profile.progress()
	pr.unlocked = unlocked
	pr.lessons_done = lessons_done
	pr.tips_seen = tips_seen.duplicate()
	var cs := Profile.cosmetics()
	for kind in cosmetics:
		cs[kind] = cosmetics[kind]
	for i in LEVEL_PATHS.size():
		if best_scores.has(i) or best_ribbons.has(i):
			var f := Profile.flight(level_id(i))
			f.best_score = maxi(int(f.best_score), int(best_scores.get(i, -1)))
			f.ribbons = maxi(int(f.ribbons), int(best_ribbons.get(i, 0)))
	Profile.save()
