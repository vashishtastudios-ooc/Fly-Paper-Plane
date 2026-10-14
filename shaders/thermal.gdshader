shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Faint golden shimmer column for rising air.
uniform vec4 tint : source_color = vec4(1.0, 0.82, 0.45, 1.0);
uniform float intensity = 0.11;
uniform float height = 12.0;

varying float v_height;

void vertex() {
	v_height = VERTEX.y / height + 0.5;
}

void fragment() {
	float t = TIME;
	float rise = sin(UV.y * 30.0 - t * 2.2 + sin(UV.x * 31.4159) * 1.3) * 0.5 + 0.5;
	float swirl = sin(UV.x * 62.83 + UV.y * 9.0 - t * 1.3) * 0.5 + 0.5;
	float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	float vfade = smoothstep(0.0, 0.15, v_height) * (1.0 - smoothstep(0.7, 1.0, v_height));
	float a = intensity * vfade * (0.35 + 0.65 * rise * swirl) * (0.4 + edge);
	ALBEDO = tint.rgb * a;
	ALPHA = 1.0;
}
