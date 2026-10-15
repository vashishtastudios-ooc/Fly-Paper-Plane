// Shared painterly lighting (Art style: Painterly). Soft two-band light instead of smooth
// shading, warm sun with cool lavender shadows, a glow on edges that face into the sun (rim
// light) and no shiny highlights. Plus a subtle world-space brush-stroke variation of color.

uniform vec3 shadow_tint : source_color = vec3(0.58, 0.55, 0.86);
uniform float shadow_lift = 0.06;
uniform float band_soft = 0.16;
uniform float rim_strength = 0.3;
uniform float brush_amount = 0.09;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

float p_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float p_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(p_hash(i), p_hash(i + vec2(1.0, 0.0)), f.x),
		mix(p_hash(i + vec2(0.0, 1.0)), p_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Directional brush strokes: noise stretched along one axis, picked by the surface's facing.
float brush(vec3 wp, vec3 wn) {
	vec3 a = abs(wn);
	vec2 uv = a.y > max(a.x, a.z) ? wp.xz : (a.x > a.z ? wp.zy : wp.xy);
	float n = p_noise(uv * vec2(1.6, 5.0)) * 0.6 + p_noise(uv * vec2(4.0, 11.0) + 7.3) * 0.4;
	return 1.0 + (n - 0.5) * 2.0 * brush_amount;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrapped = ndl * 0.5 + 0.5;
	// Two soft bands: shadow side, half-lit, full light.
	float lit = smoothstep(0.42, 0.42 + band_soft, wrapped) * 0.65 + smoothstep(0.68, 0.68 + band_soft, wrapped) * 0.35;
	float shade = lit * mix(0.12, 1.0, ATTENUATION);
	DIFFUSE_LIGHT += shade * LIGHT_COLOR / PI;
	if (LIGHT_IS_DIRECTIONAL) {
		// Shadows lean cool and lavender rather than grey.
		DIFFUSE_LIGHT += shadow_tint * (1.0 - shade) * shadow_lift * length(LIGHT_COLOR) / PI;
		// Edges glow warm when the sun is behind them.
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		rim *= clamp(dot(LIGHT, -VIEW) * 0.7 + 0.3, 0.0, 1.0);
		DIFFUSE_LIGHT += rim * rim_strength * LIGHT_COLOR * ATTENUATION / PI;
	}
}
