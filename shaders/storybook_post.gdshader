shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

// Full-screen storybook pass (drawn last): a soft warm ink outline found from depth
// discontinuities, a gentle vignette and a faint paper grain. Color grading itself is done
// by the environment's color-correction LUT.
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec3 line_color : source_color = vec3(0.23, 0.14, 0.1);
uniform float line_strength = 0.55;
uniform float line_far = 150.0;
uniform float vignette = 0.3;
uniform vec3 vignette_color : source_color = vec3(0.32, 0.18, 0.1);
uniform float grain = 0.014;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float d_at(vec2 uv) {
	return texture(depth_tex, uv).r;
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float d0 = d_at(uv);
	float dl = d_at(uv - vec2(px.x, 0.0));
	float dr = d_at(uv + vec2(px.x, 0.0));
	float du = d_at(uv - vec2(0.0, px.y));
	float dd = d_at(uv + vec2(0.0, px.y));
	vec4 v = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, d0, 1.0);
	float z = -v.z / v.w;
	// Raw depth is linear across flat surfaces, so its Laplacian only lights up at creases
	// and silhouettes.
	float lap = abs(dl + dr - 2.0 * d0) + abs(du + dd - 2.0 * d0);
	float edge = smoothstep(0.06, 0.3, lap / max(max(d0, max(dl, dr)), 1e-6));
	edge *= 1.0 - smoothstep(line_far * 0.35, line_far, z);
	edge *= line_strength;

	vec2 c = (uv - 0.5) * vec2(1.0, 0.82);
	float vig = smoothstep(0.32, 0.78, length(c)) * vignette;

	float n = fract(sin(dot(floor(FRAGCOORD.xy * 0.5), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;

	float a = max(edge, vig);
	vec3 col = edge >= vig ? line_color : vignette_color;
	ALBEDO = col + vec3(n * 0.08);
	ALPHA = clamp(a + abs(n) * grain, 0.0, 1.0);
}
