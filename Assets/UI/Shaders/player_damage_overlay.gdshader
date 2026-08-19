shader_type canvas_item;

uniform float hit_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float low_health : hint_range(0.0, 1.0) = 0.0;
uniform float effect_intensity : hint_range(0.0, 1.0) = 1.0;
uniform vec2 hit_direction = vec2(0.0, -1.0);

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radius = length(centered * vec2(0.82, 1.0));
	float edge = smoothstep(0.40, 1.08, radius);
	vec2 radial_direction = normalize(centered + vec2(0.0001));
	float directional = 0.38 + 0.62 * max(dot(radial_direction, hit_direction), 0.0);
	float pulse = hit_intensity * edge * directional;
	float hurt_vignette = low_health * smoothstep(0.28, 1.0, radius);
	float alpha = (pulse * 0.72 + hurt_vignette * 0.32) * effect_intensity;
	vec3 color = mix(vec3(0.26, 0.0, 0.008), vec3(0.72, 0.005, 0.012), pulse);
	COLOR = vec4(color, clamp(alpha, 0.0, 0.82));
}
