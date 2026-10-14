shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

// Flags, pennants and washing fluttering in the wind.
// local_y_weight = 1: the cloth hangs down from y = 0 (bunting pennants), so tips move most.
// Otherwise the vertex color alpha is the flutter weight.
uniform float local_y_weight = 0.0;
uniform float flag_length = 0.42;
uniform float amplitude = 0.08;
uniform float near_fade = 0.0;

varying vec3 v_color;
varying float v_dist;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = local_y_weight > 0.5 ? clamp(-VERTEX.y / flag_length, 0.0, 1.0) : COLOR.a;
	float t = TIME;
	float ph = wpos.x * 1.7 + wpos.z * 1.3;
	float gust = 0.6 + 0.4 * sin(t * 0.5 + wpos.x * 0.05);
	VERTEX.z += sin(t * 7.0 + ph) * amplitude * w * gust;
	VERTEX.x += sin(t * 5.3 + ph * 0.7) * amplitude * 0.35 * w * gust;
	v_color = srgb_to_linear(COLOR.rgb);
	v_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	if (near_fade > 0.0) {
		float n = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
		if (n > smoothstep(near_fade * 0.4, near_fade, v_dist)) {
			discard;
		}
	}
	ALBEDO = v_color;
	ROUGHNESS = 0.95;
}
