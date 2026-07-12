shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 outer_color : source_color = vec4(1.0, 0.58, 0.22, 1.0);
uniform vec4 focus_color : source_color = vec4(0.72, 0.1, 0.035, 1.0);
uniform float alert_level : hint_range(0.0, 1.0) = 0.35;
uniform float focus_strength : hint_range(0.0, 1.0) = 0.0;
uniform float outer_opacity : hint_range(0.0, 1.0) = 0.07;
uniform float focus_opacity : hint_range(0.0, 1.0) = 0.2;

void fragment() {
	float radial = clamp(UV.y, 0.0, 1.0);
	float angular = clamp(UV.x, 0.0, 1.0);
	float side_distance = min(angular, 1.0 - angular);

	float side_fade = smoothstep(0.0, 0.018, side_distance);
	float near_fade = smoothstep(0.015, 0.08, radial);
	float far_fade = 1.0 - smoothstep(0.985, 1.0, radial);
	float cone_mask = side_fade * near_fade * far_fade;

	float center_width = mix(0.025, 0.085, radial);
	float center_distance = abs(angular - 0.5);
	float focus_wedge = 1.0 - smoothstep(center_width, center_width + 0.018, center_distance);
	focus_wedge *= smoothstep(0.04, 0.12, radial);
	focus_wedge *= 1.0 - smoothstep(0.56, 0.72, radial);

	float contact = clamp(focus_strength, 0.0, 1.0);
	float alert = clamp(alert_level, 0.0, 1.0);
	float outer_alpha = outer_opacity * cone_mask * mix(0.65, 1.0, alert);
	float focus_alpha = focus_opacity * focus_wedge * cone_mask * mix(0.12, 1.0, contact);

	vec3 color = outer_color.rgb;
	color = mix(color, focus_color.rgb, focus_wedge * mix(0.22, 0.78, contact));

	ALBEDO = color;
	EMISSION = color * (0.05 + focus_alpha * 0.18);
	ALPHA = clamp(outer_alpha + focus_alpha, 0.0, 0.32);
}
