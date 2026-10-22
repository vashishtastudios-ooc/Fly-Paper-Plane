extends Node
## The player's save: profile, progress, per-flight records, lifetime stats, achievements and
## best-run ghosts. Everything stays on the device (no account, no internet).
##
## Saved as JSON with a version, a checksum and a backup copy; writes go to a temporary file
## first, so a crash or a flat battery mid-save never leaves a broken save behind. Flights are
## stored by their file name (level_1, harbour_3...), so reordering flights keeps records safe.

signal achievement_unlocked(def: Dictionary)

const PATH := "user://profile.json"
const BACKUP_PATH := "user://profile.bak.json"
const TMP_PATH := "user://profile.tmp.json"
const GHOST_DIR := "user://ghosts"
const VERSION := 1
const NAME_MAX := 16

## Lifetime counters (see stats()).
const STAT_KEYS := ["flights", "landings", "crashes", "perfect", "bullseyes", "flight_time", "distance",
	"rings", "stars", "rolls", "gusts", "thermals", "skips", "bonus_rings"]

## Achievements. "stat" names a lifetime counter, or a special source handled in progress().
const ACHIEVEMENTS := [
	{"id": "first_landing", "title": "First touchdown", "desc": "Land your first flight", "stat": "landings", "target": 1},
	{"id": "flight_school", "title": "Flight school", "desc": "Finish the flying lessons", "stat": "lessons", "target": 1},
	{"id": "landings_25", "title": "Frequent flyer", "desc": "Land 25 times", "stat": "landings", "target": 25},
	{"id": "landings_100", "title": "Seasoned pilot", "desc": "Land 100 times", "stat": "landings", "target": 100},
	{"id": "bullseye", "title": "Bullseye", "desc": "Land within half a metre of the centre", "stat": "bullseyes", "target": 1},
	{"id": "perfect_10", "title": "Perfect ten", "desc": "Earn 3 ribbons 10 times", "stat": "perfect", "target": 10},
	{"id": "under_par_5", "title": "Speedy", "desc": "Land 5 different flights under par time", "stat": "under_par", "target": 5},
	{"id": "dist_1k", "title": "Kilometre club", "desc": "Fly 1 km in total", "stat": "distance", "target": 1000, "unit": "m"},
	{"id": "dist_10k", "title": "Long hauler", "desc": "Fly 10 km in total", "stat": "distance", "target": 10000, "unit": "m"},
	{"id": "air_10m", "title": "Head in the clouds", "desc": "Spend 10 minutes in the air", "stat": "flight_time", "target": 600, "unit": "s"},
	{"id": "air_60m", "title": "Sky dweller", "desc": "Spend an hour in the air", "stat": "flight_time", "target": 3600, "unit": "s"},
	{"id": "rings_100", "title": "Ring master", "desc": "Fly through 100 rings", "stat": "rings", "target": 100},
	{"id": "stars_100", "title": "Star catcher", "desc": "Collect 100 stars", "stat": "stars", "target": 100},
	{"id": "rolls_25", "title": "Show-off", "desc": "Do 25 barrel rolls", "stat": "rolls", "target": 25},
	{"id": "thermals_50", "title": "Thermal rider", "desc": "Ride rising air 50 times", "stat": "thermals", "target": 50},
	{"id": "gusts_100", "title": "Puff power", "desc": "Use 100 gusts", "stat": "gusts", "target": 100},
	{"id": "skips_10", "title": "Stone skipper", "desc": "Skip off the water 10 times", "stat": "skips", "target": 10},
	{"id": "secrets", "title": "Secret finder", "desc": "Find both secret bonus rings", "stat": "secrets", "target": 2},
	{"id": "linden_all", "title": "Linden Lane local", "desc": "Land every Linden Lane flight", "stat": "map_clear:linden", "target": 8},
	{"id": "linden_gold", "title": "Linden legend", "desc": "3 ribbons on every Linden Lane flight", "stat": "map_gold:linden", "target": 8},
	{"id": "harbour_all", "title": "Old sea dog", "desc": "Land every Seaside Harbour flight", "stat": "map_clear:harbour", "target": 8},
	{"id": "harbour_gold", "title": "Harbour hero", "desc": "3 ribbons on every Seaside Harbour flight", "stat": "map_gold:harbour", "target": 8},
	{"id": "trees_10", "title": "Tree hugger", "desc": "Crash into trees 10 times", "stat": "crash:tree", "target": 10},
	{"id": "splash_10", "title": "Paper boat", "desc": "Splash into water 10 times", "stat": "crash:water", "target": 10},
	{"id": "crashes_100", "title": "Never give up", "desc": "Crash 100 times (and keep flying!)", "stat": "crashes", "target": 100},
]

var data := {}
## Best-run ghosts waiting to be written (with the next save).
var _pending_ghosts := {}
## True when there was no profile yet (Game then carries over the old save.cfg).
var is_new := true
var _dirty := false
var _autosave_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = _blank()
	_load()
	var p: Dictionary = data.profile
	p.sessions = int(p.sessions) + 1
	p.last_played = _now()
	_dirty = true
	# (Game is loaded after this autoload: hook into it once everything is ready.)
	_watch_game.call_deferred()


## Writes wait for a still moment: the result card, the menu or a flight's intro card.
func _watch_game() -> void:
	Game.state_changed.connect(func(st: int):
		if st in [Game.State.RESULT, Game.State.MENU, Game.State.INTRO] and (_dirty or not _pending_ghosts.is_empty()):
			save(true))


func _process(delta: float) -> void:
	# Play time counts while the game window is in front.
	if DisplayServer.window_is_focused():
		data.profile.play_time = float(data.profile.play_time) + delta
	_autosave_t += delta
	if _autosave_t > 60.0:
		_autosave_t = 0.0
		if _dirty:
			save()


func _notification(what: int) -> void:
	# Save when the app goes to the background or closes (phones may never come back).
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if _dirty or not _pending_ghosts.is_empty():
			save(true)


# --- Profile -------------------------------------------------------------------------------

func pilot_name() -> String:
	return str(data.profile.name)


func set_pilot_name(n: String) -> void:
	n = n.strip_edges().left(NAME_MAX)
	if n == pilot_name():
		return
	data.profile.name = n
	save()


func created() -> int:
	return int(data.profile.created)


func play_time() -> float:
	return float(data.profile.play_time)


# --- Flights and stats ----------------------------------------------------------------------

## A flight's record (created on first use). id: Game.level_id().
func flight(id: String) -> Dictionary:
	var f: Dictionary = data.flights
	if not f.has(id):
		f[id] = {"best_score": -1, "ribbons": 0, "best_time": -1.0, "best_dist": -1.0, "softest": -1.0,
			"stars": [], "stars_best": 0, "attempts": 0, "landings": 0, "crashes": 0, "crash_kinds": {},
			"air_time": 0.0, "first_cleared": 0, "last_played": 0, "bonus_found": false}
	return f[id]


func has_flight(id: String) -> bool:
	return (data.flights as Dictionary).has(id)


func stat(key: String) -> float:
	return float(data.stats.get(key, 0))


func crash_kinds() -> Dictionary:
	return data.stats.crash_kinds


func count(key: String, n := 1.0) -> void:
	data.stats[key] = stat(key) + n
	_dirty = true


## A throw on a flight (not the lessons).
func begin_flight(id: String) -> void:
	var f := flight(id)
	f.attempts = int(f.attempts) + 1
	f.last_played = _now()
	count("flights")


## Time and distance in the air, every frame of a flight. id may be "" (lessons).
func add_air(id: String, dt: float, dist: float) -> void:
	count("flight_time", dt)
	count("distance", dist)
	if id != "":
		var f := flight(id)
		f.air_time = float(f.air_time) + dt


func record_crash(id: String, kind: String) -> void:
	count("crashes")
	var ck: Dictionary = data.stats.crash_kinds
	var k := "water" if kind == "soaked" else kind
	ck[k] = int(ck.get(k, 0)) + 1
	var f := flight(id)
	f.crashes = int(f.crashes) + 1
	var fk: Dictionary = f.crash_kinds
	fk[k] = int(fk.get(k, 0)) + 1


## A scored landing. stats: the flight stats from MainScene; score: Game.compute_landing_score().
## star_ids: indices of the stars collected on this flight.
func record_landing(id: String, stats: Dictionary, score: Dictionary, star_ids: Array) -> void:
	count("landings")
	if int(score.ribbons) >= 3:
		count("perfect")
	if float(stats.dist) <= 0.5:
		count("bullseyes")
	var f := flight(id)
	f.landings = int(f.landings) + 1
	if int(f.first_cleared) == 0:
		f.first_cleared = _now()
	f.best_score = maxi(int(f.best_score), int(score.total))
	f.ribbons = maxi(int(f.ribbons), int(score.ribbons))
	f.best_time = _better(float(f.best_time), float(stats.time))
	f.best_dist = _better(float(f.best_dist), float(stats.dist))
	f.softest = _better(float(f.softest), float(stats.vertical_impact))
	var got: Array = f.stars
	for s in star_ids:
		if not got.has(int(s)):
			got.append(int(s))
	f.stars_best = maxi(int(f.stars_best), star_ids.size())
	if int(stats.get("bonus", 0)) > 0:
		f.bonus_found = true


func _better(old: float, new: float) -> float:
	return new if old < 0.0 else minf(old, new)


# --- Progress (owned by Game, stored here) ------------------------------------------------------

func progress() -> Dictionary:
	return data.progress


func cosmetics() -> Dictionary:
	return data.cosmetics


# --- Achievements -------------------------------------------------------------------------------

## [current, target] for an achievement.
func progress_of(def: Dictionary) -> Vector2:
	var target := float(def.target)
	var src: String = def.stat
	var cur := 0.0
	if src == "lessons":
		cur = 1.0 if bool(data.progress.lessons_done) else 0.0
	elif src == "under_par":
		for i in Game.levels.size():
			var id := Game.level_id(i)
			if has_flight(id):
				var t := float(flight(id).best_time)
				if t > 0.0 and t <= Game.levels[i].par_time:
					cur += 1.0
	elif src == "secrets":
		for id in data.flights:
			if bool(data.flights[id].get("bonus_found", false)):
				cur += 1.0
	elif src.begins_with("map_clear:") or src.begins_with("map_gold:"):
		var gold := src.begins_with("map_gold:")
		var map_id := src.get_slice(":", 1)
		for m in Game.MAPS:
			if m.id == map_id:
				target = (m.levels as Array).size()
				for i in m.levels:
					var id := Game.level_id(i)
					if has_flight(id) and int(flight(id).landings) > 0 and (not gold or int(flight(id).ribbons) >= 3):
						cur += 1.0
	elif src.begins_with("crash:"):
		cur = float(crash_kinds().get(src.get_slice(":", 1), 0))
	else:
		cur = stat(src)
	return Vector2(minf(cur, target), target)


func is_achieved(id: String) -> bool:
	return (data.achievements as Dictionary).has(id)


func achieved_count() -> int:
	return (data.achievements as Dictionary).size()


## Unlocks every achievement that has been reached. Returns the newly unlocked ones.
func check_achievements() -> Array:
	var fresh := []
	for def in ACHIEVEMENTS:
		if is_achieved(def.id):
			continue
		var p := progress_of(def)
		if p.x >= p.y:
			data.achievements[def.id] = _now()
			fresh.append(def)
			achievement_unlocked.emit(def)
	if not fresh.is_empty():
		_dirty = true
	return fresh


# --- Ghosts -------------------------------------------------------------------------------------

## A flight's best run: samples of [time, x, y, z, pitch, yaw, roll] packed one after another.
func save_ghost(id: String, samples: PackedFloat32Array) -> void:
	_pending_ghosts[id] = samples


func _write_ghost(id: String, samples: PackedFloat32Array) -> void:
	DirAccess.make_dir_recursive_absolute(GHOST_DIR)
	var f := FileAccess.open(GHOST_DIR.path_join(id + ".ghost"), FileAccess.WRITE)
	if f:
		f.store_32(VERSION)
		f.store_var(samples)


func has_ghost(id: String) -> bool:
	return _pending_ghosts.has(id) or FileAccess.file_exists(GHOST_DIR.path_join(id + ".ghost"))


func load_ghost(id: String) -> PackedFloat32Array:
	if _pending_ghosts.has(id):
		return _pending_ghosts[id]
	var p := GHOST_DIR.path_join(id + ".ghost")
	if not FileAccess.file_exists(p):
		return PackedFloat32Array()
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null or f.get_32() != VERSION:
		return PackedFloat32Array()
	var v: Variant = f.get_var()
	return v if v is PackedFloat32Array else PackedFloat32Array()


# --- Save file ----------------------------------------------------------------------------------

func _blank() -> Dictionary:
	var stats := {"crash_kinds": {}}
	for k in STAT_KEYS:
		stats[k] = 0
	return {
		"profile": {"name": "", "created": _now(), "play_time": 0.0, "sessions": 0, "last_played": _now()},
		"progress": {"unlocked": 1, "lessons_done": false, "tips_seen": {}},
		"cosmetics": {},
		"flights": {},
		"stats": stats,
		"achievements": {},
	}


static func _now() -> int:
	return int(Time.get_unix_time_from_system())


## Writes the save. Phones write slowly, so while a flight is under way (in the air, or the
## landing / crash moment) the write is put off until the result card or the menu, unless
## `force` (the app is closing or going to the background).
func save(force := false) -> void:
	if not force and Game.state in [Game.State.THROWING, Game.State.FLYING, Game.State.LANDED, Game.State.CRASHED]:
		_dirty = true
		return
	for gid in _pending_ghosts:
		_write_ghost(gid, _pending_ghosts[gid])
	_pending_ghosts.clear()
	_dirty = false
	# Line 1: a small header with the version and a checksum of the data text on line 2.
	var body := JSON.stringify(data, "", true)
	var header := {"version": VERSION, "saved_at": _now(), "checksum": body.md5_text()}
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Profile: could not write the save (%s)" % error_string(FileAccess.get_open_error()))
		_dirty = true
		return
	f.store_string(JSON.stringify(header) + "
" + body + "
")
	f.close()
	# Keep the previous good save as the backup, then move the new one into place.
	var main := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(main, ProjectSettings.globalize_path(BACKUP_PATH))
		DirAccess.remove_absolute(main)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(TMP_PATH), main)


func _load() -> void:
	for p in [PATH, BACKUP_PATH, TMP_PATH]:
		var d := _read(p)
		if not d.is_empty():
			_merge(d)
			is_new = false
			if p != PATH:
				push_warning("Profile: main save was damaged, restored from %s" % p)
				save()
			return


## The data in a save file, or {} if it is missing or damaged.
func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var lines := FileAccess.get_file_as_string(p).split("
", false, 1)
	if lines.size() < 2:
		return {}
	var header: Variant = JSON.parse_string(lines[0])
	var body := lines[1].strip_edges()
	if not header is Dictionary or str(header.get("checksum", "")) != body.md5_text():
		return {}
	var d: Variant = JSON.parse_string(body)
	if not d is Dictionary:
		return {}
	return _upgrade(d, int(header.get("version", 1)))


## Brings saves from older versions up to date (nothing to do yet: this is version 1).
func _upgrade(d: Dictionary, _from: int) -> Dictionary:
	return d


## Loads saved values over the blank profile, so fields added later get their defaults.
func _merge(d: Dictionary) -> void:
	for section in data:
		if d.get(section) is Dictionary:
			var dst: Dictionary = data[section]
			for k in d[section]:
				dst[k] = d[section][k]
