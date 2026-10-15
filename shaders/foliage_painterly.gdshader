shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

// Painterly vegetation (Art style: Painterly): the wind sway of foliage.gdshader, the shared
// painterly lighting, and optional leaf-brush cards (alpha texture) whose normals point out
// from the canopy center so a whole tree shades like one soft, fluffy volume.
#include "res://shaders/painterly.gdshaderinc"

uniform float sway = 0.07;
uniform float rustle = 0.02;
uniform float tip_weighted = 0.0;
uniform float tip_height = 0.45;
uniform vec3 wind_dir = vec3(1.0, 0.0, 0.35);
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_leaf_tex = false;
uniform float alpha_cut = 0.5;
// Slightly brighter, warmer tips toward the sky.
uniform float top_light = 0.18;

varying vec3 v_color;
varying vec3 v_world;
varying vec3 v_wnormal;
varying float v_up;

void vertex() {
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = 1.0;
	if (tip_weighted > 0.5) {
		w = clamp(VERTEX.y / tip_height, 0.0, 1.0);
		w *= w;
	}
	float t = TIME;
	float phase = dot(wpos.xz, vec2(0.11, 0.07));
	float gust = 0.55 + 0.45 * sin(t * 0.33 + wpos.x * 0.012 + wpos.z * 0.008);
	vec3 dir = normalize(wind_dir);
	vec3 offs = dir * (sin(t * 1.35 + phase) * 0.7 + 0.3) * sway * gust * w;
	offs += vec3(sin(t * 4.3 + wpos.y * 3.1 + phase * 7.0),
		cos(t * 3.9 + wpos.x * 2.3) * 0.4,
		cos(t * 4.7 + wpos.z * 2.9)) * rustle * w * gust;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * offs;
	v_color = srgb_to_linear(COLOR.rgb);
	v_world = wpos;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_up = v_wnormal.y;
}

void fragment() {
	float a = 1.0;
	vec3 c = v_color;
	if (use_leaf_tex) {
		vec4 lt = texture(leaf_tex, UV);
		a = lt.a;
		c *= lt.rgb;
	}
	if (a < alpha_cut) {
		discard;
	}
	c *= 1.0 + top_light * clamp(v_up, 0.0, 1.0);
	ALBEDO = c * brush(v_world, v_wnormal);
	ROUGHNESS = 1.0;
}
