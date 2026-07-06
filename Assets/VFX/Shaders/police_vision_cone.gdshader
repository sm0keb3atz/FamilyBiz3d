shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 core_color : source_color = vec4(1.0, 0.08, 0.025, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.48, 0.08, 1.0);
uniform float base_opacity : hint_range(0.0, 1.0) = 0.045;
uniform float pulse_opacity : hint_range(0.0, 1.0) = 0.035;
uniform float pulse_speed : hint_range(0.0, 10.0) = 1.8;
uniform float pulse_density : hint_range(1.0, 30.0) = 8.0;

void fragment() {
	float distance_from_officer = clamp(UV.y, 0.0, 1.0);
	float side_fade = (
		smoothstep(0.0, 0.11, UV.x)
		* smoothstep(0.0, 0.11, 1.0 - UV.x)
	);
	float near_fade = smoothstep(0.0, 0.12, distance_from_officer);
	float far_fade = 1.0 - smoothstep(
		0.72,
		1.0,
		distance_from_officer
	);
	float pulse_wave = sin(
		distance_from_officer * pulse_density
		- TIME * pulse_speed
	);
	float pulse = smoothstep(0.7, 1.0, pulse_wave);
	float soft_mask = side_fade * near_fade * far_fade;
	float soft_rim = (
		smoothstep(0.72, 0.88, distance_from_officer)
		* (1.0 - smoothstep(0.88, 1.0, distance_from_officer))
		* side_fade
	);
	vec3 color = mix(
		core_color.rgb,
		edge_color.rgb,
		clamp(distance_from_officer * 0.45 + pulse * 0.18, 0.0, 1.0)
	);
	float alpha = (
		base_opacity
		+ pulse * pulse_opacity
	) * soft_mask + soft_rim * 0.025;
	ALBEDO = color;
	EMISSION = color * (0.06 + pulse * 0.035);
	ALPHA = clamp(alpha, 0.0, 0.12);
}
