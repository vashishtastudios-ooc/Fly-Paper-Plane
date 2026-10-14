class_name Mats
extends RefCounted
## Shared, cached materials. Builder materials use vertex color as albedo tint so many
## differently colored parts can share one material (and one draw call per mesh).

static var _cache := {}

const PALETTE_HOUSES := ["#e9b7a1", "#f2d58f", "#a9c9db", "#b9d6a8", "#e6c3da", "#f5f0e5", "#cbbbe8"]
const ROOF_SLATE := Color("#5b6270")
const ROOF_TERRACOTTA := Color("#b8644a")
const TRIM := Color("#fbf8f0")
const DOOR_COLORS := ["#c8423b", "#2f6f8f", "#3f7d4f", "#e0a13a", "#7c4f9e", "#2d4f7c", "#d9675a"]
const SHUTTER_COLORS := ["#3f6f8f", "#4f7d55", "#8a4a5a", "#2f5560", "#6b5b9a", "#c0703a"]
const FLOWER_COLORS := ["#e8546a", "#f2a33a", "#f7d046", "#d76fb4", "#ffffff", "#9b6fd9", "#ff7f50"]


static func get_mat(kind: String) -> Material:
	if _cache.has(kind):
		return _cache[kind]
	var m: Material
	match kind:
		"paint": m = _tex("siding", 1.0, 0.9)
		"plaster": m = _tex("plaster", 0.5, 0.9)
		"shingle": m = _tex("shingle", 0.8, 0.85)
		"brick": m = _tex("brick", 0.6, 0.9)
		"stone": m = _tex("stone", 0.45, 0.9)
		"wood": m = _tex("wood", 0.7, 0.8)
		"asphalt": m = _tex("asphalt", 0.25, 0.92)
		"cobble": m = _tex("cobble", 0.5, 0.85)
		"paving": m = _tex("paving", 0.5, 0.9)
		"grass": m = _tex("grass", 0.12, 1.0)
		"gravel": m = _tex("gravel", 0.4, 1.0)
		"awning": m = _tex("awning", 1.0, 0.9)
		"blanket": m = _tex("blanket", 0.6, 0.95)
		"solid":
			m = _plain(0.75)
		"metal":
			var mm := _plain(0.45)
			mm.metallic = 0.4
			m = mm
		"glass":
			var g := _plain(0.12)
			g.metallic = 0.3
			g.metallic_specular = 0.8
			m = g
		"glass_clear":
			# See-through panes (the Rowan Row greenhouse).
			var gc := _plain(0.08)
			gc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			gc.cull_mode = BaseMaterial3D.CULL_DISABLED
			gc.metallic_specular = 0.9
			gc.albedo_color = Color(1, 1, 1, 0.28)
			m = gc
		"foliage":
			# Trees, bushes and flowers sway and rustle in the wind.
			m = _shader("res://shaders/foliage.gdshader", {"sway": 0.09, "rustle": 0.022})
		"grass_wind":
			m = _shader("res://shaders/foliage.gdshader", {"sway": 0.13, "rustle": 0.035, "tip_weighted": 1.0, "tip_height": 0.45})
		"cloth_wind":
			# Washing and flags; vertex color alpha is the flutter weight.
			m = _shader("res://shaders/cloth_wind.gdshader", {"amplitude": 0.07})
		"flag_wind":
			# Bunting pennants hanging from a rope; fade out right in front of the camera.
			m = _shader("res://shaders/cloth_wind.gdshader", {"local_y_weight": 1.0, "flag_length": 0.42, "amplitude": 0.09, "near_fade": 2.0})
		"rope":
			var r := _plain(0.9)
			r.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = r
		"cloth":
			var c := _plain(0.95)
			c.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = c
		"glow":
			var gl := StandardMaterial3D.new()
			gl.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			gl.vertex_color_use_as_albedo = true
			gl.vertex_color_is_srgb = true
			gl.albedo_color = Color(1.0, 0.9, 0.6)
			m = gl
		"window_lit":
			var wl := _plain(0.3)
			wl.emission_enabled = true
			wl.emission = Color(1.0, 0.72, 0.42)
			wl.emission_energy_multiplier = 0.35
			m = wl
		"paper_plane":
			var p := StandardMaterial3D.new()
			p.albedo_texture = TexGen.get_tex("paper")
			p.cull_mode = BaseMaterial3D.CULL_DISABLED
			p.roughness = 0.9
			p.vertex_color_use_as_albedo = true
			p.vertex_color_is_srgb = true
			p.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			m = p
		"water":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://shaders/water.gdshader")
			m = sm
		_:
			m = _plain(0.8)
	_cache[kind] = m
	return m


static func _tex(tex_kind: String, scale: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = TexGen.get_tex(tex_kind)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = rough
	m.uv1_scale = Vector3(scale, scale, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func _shader(path: String, params: Dictionary) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = load(path)
	for k in params:
		sm.set_shader_parameter(k, params[k])
	return sm


static func _plain(rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = rough
	return m


## Unshaded additive material for glows, dots and beams.
static func additive(color: Color, tex: Texture2D = null, billboard := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	if tex:
		m.albedo_texture = tex
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return m


## Alpha-blended unshaded material (used for clouds and smoke).
static func soft_alpha(color: Color, tex: Texture2D, billboard := true, shaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if shaded else BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.albedo_texture = tex
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return m


static func color(hex: String) -> Color:
	return Color(hex)


static func pick(rng: RandomNumberGenerator, list: Array) -> Color:
	return Color(list[rng.randi() % list.size()])
