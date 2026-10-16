extends Node
## Platform detection, input map, quality settings, layout (portrait/landscape) and safe area.

signal layout_changed(portrait: bool)
signal quality_changed(quality: int)

const SETTINGS_PATH := "user://settings.cfg"
## Where settings are kept (a separate file when testing the phone version on PC).
var settings_file := SETTINGS_PATH
## The game used to be called "Glide Home"; on desktop its save folder was named after it.
const OLD_USER_DIR_NAME := "Glide Home"

var is_mobile := false
var touch_ui := false
## Testing the phone version on PC: the left mouse button acts as a finger.
var mouse_as_finger := false
var portrait := false
var music_volume := 0.7
var sfx_volume := 1.0
var ambience_volume := 0.8
## 0 = Low, 1 = Medium, 2 = High. Defaults to Medium on phones and High on desktop.
var quality := -1
## "storybook" (ink outlines, the original look) or "painterly" (soft painted lighting, haze and
## leafy trees). Takes effect the next time the game starts.
var art_style := "storybook"
## Steering multiplier applied to stick, touch and keyboard input.
var sensitivity := -1.0
var invert_pitch := false
var vibration := true
var show_tips := true
## "responsive" (the camera swings round quickly with the plane; phone default) or "smooth"
## (a slower, cinematic follow; desktop default). Empty until loaded.
var camera_style := ""
var show_fps := false

const QUALITY_NAMES := ["Low", "Medium", "High"]
## Default values (quality: Medium on phones, High on desktop).
const DEFAULT_MUSIC := 0.7
const DEFAULT_SFX := 1.0
const DEFAULT_AMBIENCE := 0.8
const DEFAULT_SENSITIVITY := 1.0

var _env: Environment
var _sun: DirectionalLight3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_migrate_old_saves()
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") \
		or OS.has_feature("web_android") or OS.has_feature("web_ios")
	var args := OS.get_cmdline_user_args()
	# Testing on PC: "-- --mobile" behaves like a phone (touch controls from the mouse, phone
	# defaults) and keeps its settings apart from the PC ones.
	if args.has("--mobile"):
		is_mobile = true
		settings_file = "user://settings_mobile_test.cfg"
	touch_ui = is_mobile or args.has("--touch-ui")
	# On a PC without a touchscreen the touch controls read the mouse as finger 0 themselves
	# (emulating touches from the mouse would send every click twice to the menus).
	mouse_as_finger = touch_ui and not DisplayServer.is_touchscreen_available()
	_register_inputs()
	_load()
	# Art style for this run (the command line can override it, for comparing looks).
	if args.has("--painterly"):
		art_style = "painterly"
	elif args.has("--storybook"):
		art_style = "storybook"
	# Phones always use the storybook style (the painterly look is a desktop option).
	if is_mobile:
		art_style = "storybook"
	Mats.painterly = art_style == "painterly"
	if camera_style == "":
		camera_style = default_camera_style()
	if sensitivity < 0.0:
		sensitivity = default_sensitivity()
	if quality < 0:
		quality = 1 if is_mobile else 2
	get_viewport().size_changed.connect(_on_size_changed)
	_on_size_changed()
	if is_mobile:
		# 60 fps on 60 and 120 Hz screens; on others (90 Hz...) follow the screen, since 60 fps
		# can't be shown evenly there and motion looks uneven.
		var hz := DisplayServer.screen_get_refresh_rate()
		Engine.max_fps = 0 if hz > 1.0 and fmod(hz + 1.0, 60.0) > 2.0 else 60
	apply_quality()


func _on_size_changed() -> void:
	# Keep UI at a sensible size on tall screens: the stretch base follows the orientation.
	var win := get_window().size
	var p := win.y > win.x
	var base := Vector2i(720, 1280) if p else Vector2i(1280, 720)
	if get_tree().root.content_scale_size != base:
		get_tree().root.content_scale_size = base
	if p != portrait:
		portrait = p
		layout_changed.emit(portrait)


func viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


## Safe area margins in viewport (canvas) pixels: left, top, right, bottom.
func safe_margins() -> Vector4:
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if not is_mobile or safe.size.x <= 0 or screen.x <= 0:
		return Vector4(12, 12, 12, 12)
	var vs := viewport_size()
	var sx := vs.x / float(screen.x)
	var sy := vs.y / float(screen.y)
	var l := maxf(12.0, safe.position.x * sx)
	var t := maxf(12.0, safe.position.y * sy)
	var r := maxf(12.0, (screen.x - safe.end.x) * sx)
	var b := maxf(12.0, (screen.y - safe.end.y) * sy)
	return Vector4(l, t, r, b)


## Configures the environment and sun for the current platform and quality level.
func configure_environment(env: Environment, sun: DirectionalLight3D) -> void:
	_env = env
	_sun = sun
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	env.ssil_enabled = false
	env.volumetric_fog_enabled = false
	apply_quality()


## Applies the graphics quality level to the viewport, environment and sun.
func apply_quality() -> void:
	var vp := get_viewport()
	match quality:
		0:
			vp.scaling_3d_scale = 0.7
			vp.msaa_3d = Viewport.MSAA_DISABLED
		1:
			vp.scaling_3d_scale = 0.8 if is_mobile else 0.9
			vp.msaa_3d = Viewport.MSAA_2X
		_:
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_2X if is_mobile else Viewport.MSAA_4X
	if _env:
		_env.ssao_enabled = quality >= 2 and not is_mobile
		_env.glow_enabled = quality >= 1
		# Screen-space reflections (river) only on desktop High; phones use the reflection probe.
		_env.ssr_enabled = quality >= 2 and not is_mobile
		_env.ssr_max_steps = 48
		_env.ssr_fade_in = 0.12
		_env.ssr_fade_out = 2.0
		_env.ssr_depth_tolerance = 0.4
	if _sun:
		_sun.shadow_enabled = true
		match quality:
			0:
				_sun.shadow_blur = 0.8
				_sun.directional_shadow_max_distance = 50.0
				_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			1:
				_sun.shadow_blur = 1.0
				_sun.directional_shadow_max_distance = 90.0
				_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			_:
				_sun.shadow_blur = 1.6
				_sun.directional_shadow_max_distance = 160.0 if not is_mobile else 110.0
				_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if not is_mobile else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	quality_changed.emit(quality)


## Puts every setting back to its default and saves.
func reset_to_defaults() -> void:
	music_volume = DEFAULT_MUSIC
	sfx_volume = DEFAULT_SFX
	ambience_volume = DEFAULT_AMBIENCE
	quality = 1 if is_mobile else 2
	sensitivity = default_sensitivity()
	invert_pitch = false
	vibration = true
	show_tips = true
	camera_style = default_camera_style()
	show_fps = false
	apply_volumes()
	apply_quality()
	_save()


func set_quality(q: int) -> void:
	quality = clampi(q, 0, 2)
	apply_quality()
	_save()


func set_option(option: String, value: Variant) -> void:
	match option:
		"sensitivity": sensitivity = clampf(value, 0.5, 1.6)
		"invert_pitch": invert_pitch = value
		"vibration": vibration = value
		"show_tips": show_tips = value
		"art_style": art_style = value
		"camera_style": camera_style = value
		"show_fps": show_fps = value
	_save()


func default_sensitivity() -> float:
	return 1.2 if is_mobile else DEFAULT_SENSITIVITY


func default_camera_style() -> String:
	return "responsive" if is_mobile else "smooth"


## Short haptic tick on phones (when enabled).
func vibrate(ms: int) -> void:
	if is_mobile and vibration:
		Input.vibrate_handheld(ms)


func shadows_for_small_props() -> GeometryInstance3D.ShadowCastingSetting:
	return GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if is_mobile else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func set_volume(bus_name: String, linear: float) -> void:
	match bus_name:
		"Music": music_volume = linear
		"SFX": sfx_volume = linear
		"Ambience": ambience_volume = linear
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	_save()


func apply_volumes() -> void:
	for pair in [["Music", music_volume], ["SFX", sfx_volume], ["Ambience", ambience_volume]]:
		var idx := AudioServer.get_bus_index(pair[0])
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(pair[1], 0.0001)))


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_file) == OK:
		music_volume = cfg.get_value("audio", "music", music_volume)
		sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
		ambience_volume = cfg.get_value("audio", "ambience", ambience_volume)
		quality = int(cfg.get_value("video", "quality", -1))
		sensitivity = float(cfg.get_value("controls", "sensitivity", -1.0))
		invert_pitch = bool(cfg.get_value("controls", "invert_pitch", false))
		vibration = bool(cfg.get_value("controls", "vibration", true))
		show_tips = bool(cfg.get_value("controls", "show_tips", true))
		art_style = str(cfg.get_value("video", "art_style", "storybook"))
		camera_style = str(cfg.get_value("controls", "camera", ""))
		show_fps = bool(cfg.get_value("video", "show_fps", false))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "art_style", art_style)
	cfg.set_value("controls", "sensitivity", sensitivity)
	cfg.set_value("controls", "invert_pitch", invert_pitch)
	cfg.set_value("controls", "vibration", vibration)
	cfg.set_value("controls", "show_tips", show_tips)
	cfg.set_value("controls", "camera", camera_style)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ambience", ambience_volume)
	cfg.save(settings_file)


# --- Input map -------------------------------------------------------------

func _register_inputs() -> void:
	_action("turn_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_action("turn_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_action("climb", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_action("dive", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_action("gust", [KEY_SPACE], [JOY_BUTTON_A], [])
	_action("roll_left", [KEY_Q], [JOY_BUTTON_LEFT_SHOULDER], [])
	_action("roll_right", [KEY_E], [JOY_BUTTON_RIGHT_SHOULDER], [])
	_action("throw", [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE], [JOY_BUTTON_A], [])
	_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])


func _action(name: String, keys: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name, 0.2)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(name, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(name, jb)
	for a in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = a[0]
		jm.axis_value = a[1]
		InputMap.action_add_event(name, jm)


## Copies settings and progress from the old "Glide Home" save folder (desktop) the first time
## the renamed game runs. On phones the save folder belongs to the app and is unaffected.
func _migrate_old_saves() -> void:
	if FileAccess.file_exists(SETTINGS_PATH) or FileAccess.file_exists("user://save.cfg"):
		return
	var old_dir := OS.get_user_data_dir().get_base_dir().path_join(OLD_USER_DIR_NAME)
	for f in ["settings.cfg", "save.cfg"]:
		var src := old_dir.path_join(f)
		if FileAccess.file_exists(src):
			DirAccess.copy_absolute(src, "user://" + f)
