shader_type sky;

// Painted sky (Art style: Painterly): soft gradient bands from a deep top through a pink-peach
// band to a warm horizon, a big glowing sun, and a lavender haze below the horizon.
uniform vec3 top_color : source_color = vec3(0.3, 0.52, 0.8);
uniform vec3 mid_color : source_color = vec3(0.86, 0.66, 0.74);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.8, 0.58);
uniform vec3 ground_color : source_color = vec3(0.72, 0.6, 0.66);
uniform vec3 sun_color : source_color = vec3(1.0, 0.82, 0.55);
uniform float sun_size = 0.035;
uniform float sun_glow = 0.18;
uniform float energy = 1.0;

void sky() {
	float y = EYEDIR.y;
	vec3 col;
	if (y > 0.0) {
		float h = pow(y, 0.55);
		col = mix(horizon_color, mid_color, smoothstep(0.0, 0.35, h));
		col = mix(col, top_color, smoothstep(0.3, 1.0, h));
	} else {
		col = mix(horizon_color, ground_color, smoothstep(0.0, 0.25, -y));
	}
	// Sun disc and a wide warm glow around it (brighter toward the horizon).
	float s = dot(EYEDIR, LIGHT0_DIRECTION);
	float disc = smoothstep(cos(sun_size), cos(sun_size * 0.6), s);
	float glow = pow(max(s, 0.0), 8.0) * sun_glow + pow(max(s, 0.0), 64.0) * 0.6;
	col += sun_color * (disc * 4.0 + glow);
	COLOR = col * energy;
}
