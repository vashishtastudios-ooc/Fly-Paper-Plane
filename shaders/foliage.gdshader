shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

// Vegetation that moves in the wind. Trees and bushes sway gently and rustle; grass tufts
// (tip_weighted) bend from the base. Works with MultiMesh instance colors.
uniform float sway = 0.07;
uniform float rustle = 0.02;
uniform float tip_weighted = 0.0;
uniform float tip_height = 0.45;
uniform vec3 wind_dir = vec3(1.0, 0.0, 0.35);
uniform float roughness_value = 0.95;

varying vec3 v_color;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = 1.0;
	if (tip_weighted > 0.5) {
		w = clamp(VERTEX.y / tip_height, 0.0, 1.0);
		w *= w;
	}
	float t = TIME;
	float phase = dot(wpos.xz, vec2(0.11, 0.07));
	float gust = 0.55 + 0.45 * sin(t * 0.33 + wpos.x * 0.012 + wpos.z * 0.008);
	vec3 dir = normalize(wind_dir);
	vec3 offs = dir * (sin(t * 1.35 + phase) * 0.7 + 0.3) * sway * gust * w;
	offs += vec3(sin(t * 4.3 + wpos.y * 3.1 + phase * 7.0),
		cos(t * 3.9 + wpos.x * 2.3) * 0.4,
		cos(t * 4.7 + wpos.z * 2.9)) * rustle * w * gust;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * offs;
	v_color = srgb_to_linear(COLOR.rgb);
}

void fragment() {
	ALBEDO = v_color;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.25;
}
