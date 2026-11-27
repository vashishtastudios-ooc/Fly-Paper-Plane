extends Node
## Steam for the PC build (GodotSteam GDExtension in addons/godotsteam).
## Starts Steam when the game runs on desktop with the extension present, mirrors the game's own
## achievements to Steam (same ids as Profile.ACHIEVEMENTS), and pauses the flight when the Steam
## overlay opens. On phones and the web the extension is not exported, so this quietly does nothing.
## The Steam singleton is only looked up at run time, so this script still compiles without it.

## Steam's public test app (Spacewar) until the game has its own App ID from Steamworks.
const TEST_APP_ID := 480
## Set to the game's App ID once Steamworks has issued it.
const APP_ID := TEST_APP_ID

## True once Steam started successfully.
var enabled := false
var _steam: Object


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not (OS.has_feature("windows") or OS.has_feature("linuxbsd") or OS.has_feature("macos")):
		return
	if not Engine.has_singleton("Steam"):
		return
	_steam = Engine.get_singleton("Steam")
	# A release build started outside Steam relaunches through Steam (not for the test app or editor).
	if APP_ID != TEST_APP_ID and not OS.has_feature("editor") and _steam.restartAppIfNecessary(APP_ID):
		get_tree().quit()
		return
	# Embedded callbacks: GodotSteam runs Steam's callbacks every frame for us.
	var res: Dictionary = _steam.steamInitEx(APP_ID, true)
	if int(res.get("status", -1)) != 0:
		print("Steam not started: ", res.get("verbal", "unknown"))
		return
	enabled = true
	print("Steam started for app %d" % APP_ID)
	_steam.overlay_toggled.connect(_on_overlay_toggled)
	Profile.achievement_unlocked.connect(_on_achievement)
	# Achievements earned before Steam was set up (or while offline) carry over now.
	_sync_achievements()


func _on_achievement(def: Dictionary) -> void:
	if _steam.setAchievement(def.id):
		_steam.storeStats()


func _sync_achievements() -> void:
	var any := false
	for def: Dictionary in Profile.ACHIEVEMENTS:
		if Profile.is_achieved(def.id):
			var cur: Dictionary = _steam.getAchievement(def.id)
			if cur.get("ret", false) and not cur.get("achieved", false):
				any = _steam.setAchievement(def.id) or any
	if any:
		_steam.storeStats()


func _on_overlay_toggled(active: bool, _user_initiated: bool, _app_id: int) -> void:
	if not active or get_tree().paused:
		return
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("pause_game"):
		main.pause_game()


func _exit_tree() -> void:
	if enabled:
		_steam.steamShutdown()
