shader_type canvas_item;
render_mode unshaded;

uniform vec4 rival_color : source_color = vec4(0.96, 0.10, 0.20, 1.0);
uniform vec4 player_color : source_color = vec4(0.23, 0.63, 0.98, 1.0);
uniform float influence : hint_range(-1.0, 1.0) = 0.0;


float line_mask(float value, float width) {
	float centered = abs(fract(value) - 0.5);
	return smoothstep(width, min(width + 0.025, 0.5), centered);
}


void fragment() {
	float left_weight = 1.0 - smoothstep(0.0, 0.68, UV.x);
	float right_weight = smoothstep(0.32, 1.0, UV.x);
	vec3 side_color = rival_color.rgb * left_weight + player_color.rgb * right_weight;
	float grid = line_mask(UV.x * 18.0, 0.465) + line_mask(UV.y * 9.0, 0.475);
	float center_line = 1.0 - smoothstep(0.0, 0.006, abs(UV.x - 0.5));
	float sweep_position = fract(TIME * 0.055);
	float sweep = 1.0 - smoothstep(0.0, 0.085, abs(UV.x - sweep_position));
	float contested = 1.0 - abs(influence);
	float energy = 0.008 + grid * 0.007 + center_line * 0.018 * contested;
	energy += sweep * 0.009;
	vec3 rgb = side_color * energy;
	COLOR = vec4(rgb, clamp(energy, 0.0, 0.07));
}
