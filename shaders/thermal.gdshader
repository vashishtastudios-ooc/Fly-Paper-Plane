shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Faint golden shimmer column for rising air.
uniform vec4 tint : source_color = vec4(1.0, 0.82, 0.45, 1.0);
uniform float intensity = 0.11;
uniform float height = 12.0;
// Column radius (top), to know when the camera is inside or right above it.
uniform float radius = 3.0;

varying float v_height;
varying float v_inside;

void vertex() {
	v_height = VERTEX.y / height + 0.5;
	vec3 cam_local = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	// Inside the column, or flying over its top: either way the walls would fill the view.
	float inside = 1.0 - smoothstep(radius * 0.9, radius * 1.8, length(cam_local.xz));
	float above = smoothstep(height * 0.5 - 3.0, height * 0.5 + 1.0, cam_local.y);
	v_inside = max(inside, above);
}

void fragment() {
	float t = TIME;
	float rise = sin(UV.y * 30.0 - t * 2.2 + sin(UV.x * 31.4159) * 1.3) * 0.5 + 0.5;
	float swirl = sin(UV.x * 62.83 + UV.y * 9.0 - t * 1.3) * 0.5 + 0.5;
	float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	float vfade = smoothstep(0.0, 0.15, v_height) * (1.0 - smoothstep(0.7, 1.0, v_height));
	// Fade out close to the camera, so flying into the column doesn't put a big tinted patch
	// across the screen (the rising particles and the label still show it).
	float near = smoothstep(4.0, 22.0, length(VERTEX)) * mix(1.0, 0.1, v_inside);
	float a = intensity * vfade * near * (0.35 + 0.65 * rise * swirl) * (0.4 + edge);
	// A see-through tint (not added light), so the column shows over a bright sky too.
	ALBEDO = tint.rgb;
	ALPHA = clamp(a * 2.2, 0.0, 1.0);
}
