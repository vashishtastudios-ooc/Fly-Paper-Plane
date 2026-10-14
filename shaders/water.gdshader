shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.24, 0.47, 0.55);
uniform vec3 shallow_color : source_color = vec3(0.47, 0.7, 0.72);
uniform vec3 sky_color : source_color = vec3(0.96, 0.82, 0.68);
uniform float flow_speed = 0.35;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 wave_grad(vec2 p, float t) {
	vec2 g = vec2(0.0);
	g += vec2(0.8, 0.3) * cos(dot(p, vec2(0.8, 0.3)) * 1.7 + t * 1.4) * 0.5;
	g += vec2(-0.4, 0.9) * cos(dot(p, vec2(-0.4, 0.9)) * 2.3 + t * 1.9) * 0.35;
	g += vec2(0.2, -1.0) * cos(dot(p, vec2(0.2, -1.0)) * 3.9 + t * 2.6) * 0.18;
	g += vec2(1.0, 0.1) * cos(dot(p, vec2(1.0, 0.1)) * 6.1 + t * 3.3) * 0.1;
	return g;
}

void fragment() {
	float t = TIME;
	vec2 p = world_pos.xz + vec2(t * flow_speed, 0.0);
	vec2 g = wave_grad(p, t) * 0.09;
	vec3 n_world = normalize(vec3(-g.x, 1.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float band = 0.5 + 0.5 * sin(world_pos.z * 0.35 + sin(world_pos.x * 0.07));
	vec3 base = mix(deep_color, shallow_color, band * 0.35);
	ALBEDO = mix(base, sky_color, fres * 0.75);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
