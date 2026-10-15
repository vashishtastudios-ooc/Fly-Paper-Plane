shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Painterly surface (Art style: Painterly): vertex/instance color times an optional texture,
// with the shared painterly lighting and brush variation.
#include "res://shaders/painterly.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_tex = false;
uniform vec2 uv_scale = vec2(1.0);
uniform vec4 base_color : source_color = vec4(1.0);

varying vec3 v_world;
varying vec3 v_wnormal;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = srgb_to_linear(COLOR.rgb) * base_color.rgb;
	if (use_tex) {
		c *= texture(albedo_tex, UV * uv_scale).rgb;
	}
	ALBEDO = c * brush(v_world, v_wnormal);
	ROUGHNESS = 1.0;
}
