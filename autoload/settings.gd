extends Node
## Platform detection, input map, quality settings, layout (portrait/landscape) and safe area.

signal layout_changed(portrait: bool)

const SETTINGS_PATH := "user://settings.cfg"

var is_mobile := false
var touch_ui := false
var portrait := false
var music_volume := 0.7
var sfx_volume := 1.0
var ambience_volume := 0.8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") \
		or OS.has_feature("web_android") or OS.has_feature("web_ios")
	var args := OS.get_cmdline_user_args()
	touch_ui = is_mobile or args.has("--touch-ui")
	if touch_ui and not is_mobile:
		Input.emulate_touch_from_mouse = true
	_register_inputs()
	_load()
	get_viewport().size_changed.connect(_on_size_changed)
	_on_size_changed()
	if is_mobile:
		get_viewport().scaling_3d_scale = 0.8
		get_viewport().msaa_3d = Viewport.MSAA_2X
		Engine.max_fps = 60


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


## Configures the environment and sun for the current platform.
func configure_environment(env: Environment, sun: DirectionalLight3D) -> void:
	env.ssao_enabled = not is_mobile
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	env.ssil_enabled = false
	env.volumetric_fog_enabled = false
	if is_mobile:
		env.glow_levels_set_extra = false
		sun.shadow_blur = 1.0
		sun.directional_shadow_max_distance = 90.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	else:
		sun.shadow_blur = 1.6
		sun.directional_shadow_max_distance = 160.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


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
	if cfg.load(SETTINGS_PATH) == OK:
		music_volume = cfg.get_value("audio", "music", music_volume)
		sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
		ambience_volume = cfg.get_value("audio", "ambience", ambience_volume)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ambience", ambience_volume)
	cfg.save(SETTINGS_PATH)


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
