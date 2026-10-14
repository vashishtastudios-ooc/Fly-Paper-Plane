shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform, fog_disabled;

// Soft slanted sunbeam: a quad billboarded around its own axis (the light direction).
// Instance basis: Y = beam axis * length, X = width. Origin = beam center.
uniform vec4 tint : source_color = vec4(1.0, 0.82, 0.55, 1.0);
uniform float intensity = 0.09;

varying float v_fade;
varying vec2 v_uv;
varying float v_seed;

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 axis_v = MODEL_MATRIX[1].xyz;
	float len = length(axis_v);
	vec3 axis = axis_v / len;
	float width = length(MODEL_MATRIX[0].xyz);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 to_cam = normalize(cam - center);
	vec3 side = normalize(cross(axis, to_cam));
	vec3 world = center + axis * VERTEX.y * len + side * VERTEX.x * width;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	float dist = length(cam - center);
	v_fade = smoothstep(5.0, 16.0, dist) * (1.0 - smoothstep(110.0, 200.0, dist));
	v_fade *= 1.0 - abs(dot(axis, to_cam));
	v_uv = UV;
	v_seed = center.x * 0.37 + center.z * 0.21;
}

void fragment() {
	float across = 1.0 - abs(v_uv.x * 2.0 - 1.0);
	across *= across;
	// UV.y = 0 at the top (toward the sun), 1 at the ground.
	float along = smoothstep(0.0, 0.3, v_uv.y) * (1.0 - smoothstep(0.65, 1.0, v_uv.y));
	float breathe = 0.7 + 0.3 * sin(TIME * 0.35 + v_seed);
	ALBEDO = tint.rgb * intensity * across * along * breathe * v_fade;
}
