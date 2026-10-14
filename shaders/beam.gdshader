shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Soft vertical light beam over the landing pad.
uniform vec4 tint : source_color = vec4(1.0, 0.86, 0.5, 1.0);
uniform float intensity = 0.35;

void fragment() {
	float h = 1.0 - UV.y;
	float edge = pow(abs(dot(NORMAL, VIEW)), 1.6);
	float pulse = 0.85 + 0.15 * sin(TIME * 2.0 - h * 6.0);
	float a = intensity * pow(1.0 - h, 1.8) * edge * pulse;
	ALBEDO = tint.rgb * a;
}
