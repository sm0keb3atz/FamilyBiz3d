shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette_strength : hint_range(0.0, 0.2) = 0.045;
uniform float grain_strength : hint_range(0.0, 0.05) = 0.006;
uniform float dither_strength : hint_range(0.0, 0.02) = 0.0039;


float hash12(vec2 point) {
	vec3 value = fract(vec3(point.xyx) * 0.1031);
	value += dot(value, value.yzx + 33.33);
	return fract((value.x + value.y) * value.z);
}


void fragment() {
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	float vignette_shape = smoothstep(0.52, 1.42, dot(centered, centered));
	float vignette = vignette_shape * vignette_strength;

	vec2 pixel = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	float stable_dither = hash12(pixel) - 0.5;
	float temporal_grain = hash12(pixel + vec2(fract(TIME * 17.0) * 97.0)) - 0.5;
	vec3 finished = scene * (1.0 - vignette);
	finished += vec3(stable_dither * dither_strength);
	finished += vec3(temporal_grain * grain_strength);
	COLOR = vec4(max(finished, vec3(0.0)), 1.0);
}
