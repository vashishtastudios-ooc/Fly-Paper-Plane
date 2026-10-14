shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

// River and fountain water: gentle animated ripples, a fresnel sky tint, reflections from the
// river reflection probe (and SSR on desktop High), plus twinkling sun glints on the ripples.
uniform vec3 deep_color : source_color = vec3(0.24, 0.47, 0.55);
uniform vec3 shallow_color : source_color = vec3(0.47, 0.7, 0.72);
uniform vec3 sky_color : source_color = vec3(0.96, 0.82, 0.68);
uniform float flow_speed = 0.35;
// Direction toward the sun (world) and its glint color; set by the town for the time of day.
uniform vec3 sun_dir = vec3(0.62, 0.36, -0.7);
uniform vec3 sun_color : source_color = vec3(1.0, 0.86, 0.62);
uniform float sparkle = 1.0;

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
	g += vec2(-0.7, -0.7) * cos(dot(p, vec2(-0.7, -0.7)) * 11.0 + t * 4.4) * 0.06;
	return g;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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
	// Darker albedo lets the probe/SSR reflections read clearly.
	ALBEDO = mix(base * 0.75, sky_color, fres * 0.35);
	ROUGHNESS = 0.035;
	METALLIC = 0.0;
	SPECULAR = 0.85;

}


// Round twinkling dots that come and go on the ripples.
float twinkle(vec2 p, float t) {
	vec2 q = p * 3.0 + vec2(t * 0.6, 0.0);
	vec2 cell = floor(q);
	vec2 f = fract(q);
	vec2 c = vec2(hash(cell), hash(cell + 17.3)) * 0.6 + 0.2;
	float on = step(0.9, hash(cell + floor(t * 5.0) * 0.731));
	return on * smoothstep(0.22, 0.0, length(f - c));
}

// Custom lighting so glints appear only where light actually reaches (respects shadows).
void light() {
	float ndl = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += ndl * ATTENUATION * LIGHT_COLOR / PI;
	vec3 h = normalize(LIGHT + VIEW);
	float nh = max(dot(NORMAL, h), 0.0);
	float spec = pow(nh, 600.0) * 4.0 + pow(nh, 60.0) * 0.25;
	float dots = pow(nh, 25.0) * twinkle(world_pos.xz, TIME) * 3.5;
	SPECULAR_LIGHT += (spec + dots) * sparkle * ATTENUATION * LIGHT_COLOR;
}
