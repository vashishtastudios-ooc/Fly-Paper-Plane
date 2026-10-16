shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

// Painterly vegetation (Art style: Painterly): the wind sway of foliage.gdshader with the same
// storybook lighting, plus optional leaf-brush cards (alpha texture) whose normals point out from
// the canopy center so a whole tree shades like one soft volume. Leaves let warm light through
// when the sun is behind them, so backlit trees glow instead of turning dark.
uniform float sway = 0.07;
uniform float rustle = 0.02;
uniform float tip_weighted = 0.0;
uniform float tip_height = 0.45;
uniform vec3 wind_dir = vec3(1.0, 0.0, 0.35);
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_leaf_tex = false;
uniform float alpha_cut = 0.5;
// Slightly brighter tips toward the sky, and how much light shines through the leaves.
uniform float top_light = 0.12;
uniform float translucency = 0.8;
// Soft fill so the shady side of a leafy tree stays a readable green.
uniform float fill = 0.0;
// Leaf cards: the brush texture is darker than a plain canopy, so lift it to the same brightness.
uniform float leaf_boost = 1.18;

varying vec3 v_color;
varying float v_up;

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
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	float a = 1.0;
	vec3 c = v_color;
	if (use_leaf_tex) {
		vec4 lt = texture(leaf_tex, UV);
		a = lt.a;
		c *= lt.rgb * leaf_boost;
	}
	if (a < alpha_cut) {
		discard;
	}
	if (use_leaf_tex) {
		// Both faces of a leaf card shade with the tree's outward normal, so the whole canopy
		// lights like one soft volume (the back face would otherwise face into the tree).
		if (!FRONT_FACING) {
			NORMAL = -NORMAL;
		}
		// Leaves right in front of the camera dissolve instead of filling the screen.
		float near = clamp((length(VERTEX) - 1.2) / 2.0, 0.0, 1.0);
		if (near < 1.0 && fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) > near) {
			discard;
		}
	}
	c *= 1.0 + top_light * clamp(v_up, 0.0, 1.0);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.25;
	// Warm light through the leaves from behind.
	BACKLIGHT = c * vec3(1.0, 0.92, 0.7) * translucency;
	EMISSION = c * fill;
}
