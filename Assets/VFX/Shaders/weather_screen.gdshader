shader_type canvas_item;

uniform float rain_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float lightning : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Keep only a nearly invisible cool edge haze. The previous procedural
	// streaks looked like short impact lines stuck to the screen.
	float edge_haze = smoothstep(0.24, 0.7, distance(UV, vec2(0.5)));
	float rain_alpha = edge_haze * rain_intensity * 0.012;
	vec3 rain_color = vec3(0.44, 0.54, 0.68);
	vec3 flash_color = vec3(0.76, 0.84, 1.0);
	COLOR = vec4(mix(rain_color, flash_color, lightning), rain_alpha + lightning * 0.16);
}
