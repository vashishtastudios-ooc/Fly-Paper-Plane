extends Node
## Game state, level list, scoring rules and the save file.

signal state_changed(new_state: int)
signal cosmetics_changed

enum State { LOADING, MENU, INTRO, THROWING, FLYING, LANDED, CRASHED, RESULT }

const SAVE_PATH := "user://save.cfg"
const LEVEL_PATHS := [
	"res://levels/level_1.tres",
	"res://levels/level_2.tres",
	"res://levels/level_3.tres",
	"res://levels/level_4.tres",
]

var state: int = State.LOADING
var levels: Array[LevelData] = []
var current_level := 0
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
	load_save()


func set_state(s: int) -> void:
	if s == state:
		return
	state = s
	state_changed.emit(s)


func level() -> LevelData:
	return levels[current_level]


func is_unlocked(i: int) -> bool:
	return i < unlocked


func has_next_level() -> bool:
	return current_level + 1 < levels.size()


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

	var headline := "Bumpy landing"
	if soft_frac > 0.8 and acc_frac > 0.6:
		headline = "Feather landing"
	elif soft_frac > 0.5:
		headline = "Smooth landing"

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

func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	unlocked = clampi(int(cfg.get_value("progress", "unlocked", 1)), 1, LEVEL_PATHS.size())
	for kind in Cosmetics.DEFAULTS:
		cosmetics[kind] = str(cfg.get_value("cosmetics", kind, Cosmetics.DEFAULTS[kind]))
	tips_seen = cfg.get_value("tips", "seen", {})
	for i in LEVEL_PATHS.size():
		var key := "level_%d" % (i + 1)
		if cfg.has_section_key(key, "best_score"):
			best_scores[i] = int(cfg.get_value(key, "best_score"))
		if cfg.has_section_key(key, "ribbons"):
			best_ribbons[i] = int(cfg.get_value(key, "ribbons"))


func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", unlocked)
	for kind in cosmetics:
		cfg.set_value("cosmetics", kind, cosmetics[kind])
	cfg.set_value("tips", "seen", tips_seen)
	for i in LEVEL_PATHS.size():
		var key := "level_%d" % (i + 1)
		if best_scores.has(i):
			cfg.set_value(key, "best_score", best_scores[i])
		if best_ribbons.has(i):
			cfg.set_value(key, "ribbons", best_ribbons[i])
	cfg.save(SAVE_PATH)
