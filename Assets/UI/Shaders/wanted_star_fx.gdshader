shader_type canvas_item;
render_mode unshaded;

uniform vec4 active_color : source_color = vec4(1.0, 0.67, 0.02, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.94, 0.54, 1.0);
uniform vec4 idle_color : source_color = vec4(0.55, 0.34, 0.04, 1.0);
uniform float filled : hint_range(0.0, 1.0) = 0.0;
uniform float burst : hint_range(0.0, 1.0) = 0.0;
uniform float star_index = 0.0;


float star_distance(vec2 point, float outer_radius, float inner_factor) {
	const vec2 edge_a = vec2(0.809016994375, -0.587785252292);
	const vec2 edge_b = vec2(-0.809016994375, -0.587785252292);
	point.x = abs(point.x);
	point -= 2.0 * max(dot(edge_a, point), 0.0) * edge_a;
	point -= 2.0 * max(dot(edge_b, point), 0.0) * edge_b;
	point.x = abs(point.x);
	point.y -= outer_radius;
	vec2 segment = inner_factor * vec2(-edge_a.y, edge_a.x) - vec2(0.0, 1.0);
	float projection = clamp(
		dot(point, segment) / dot(segment, segment),
		0.0,
		outer_radius
	);
	return length(point - segment * projection) * sign(
		point.y * segment.x - point.x * segment.y
	);
}


void fragment() {
	vec2 point = (UV - vec2(0.5)) * 2.0;
	point.y = -point.y;
	float distance_to_star = star_distance(point, 0.78, 0.46);
	float antialias_width = max(fwidth(distance_to_star) * 0.82, 0.0015);
	float body = 1.0 - smoothstep(
		-antialias_width,
		antialias_width,
		distance_to_star
	);
	float outline_width = 0.052;
	float outline = 1.0 - smoothstep(
		outline_width - antialias_width,
		outline_width + antialias_width,
		abs(distance_to_star)
	);
	float glow_width = 0.075 + burst * 0.035;
	float outer_glow = 1.0 - smoothstep(
		0.0,
		glow_width,
		max(distance_to_star, 0.0)
	);
	outer_glow *= 1.0 - body;

	float pulse = 0.5 + 0.5 * sin(TIME * 4.2 + star_index * 0.82);
	float sweep_position = fract(TIME * 0.32 + star_index * 0.11);
	float sweep = 1.0 - smoothstep(0.0, 0.16, abs((UV.x + UV.y) * 0.5 - sweep_position));
	float glint = pow(max(0.0, sin(TIME * 2.5 + star_index * 2.17)), 18.0);

	vec3 base = mix(idle_color.rgb, active_color.rgb, filled);
	base = mix(base, hot_color.rgb, filled * (sweep * 0.34 + burst * 0.62));
	base += hot_color.rgb * glint * filled * 0.32;
	float hollow_alpha = outline * 0.98 + body * 0.025;
	float body_alpha = mix(hollow_alpha, body, filled);
	float glow_strength = filled * (0.045 + pulse * 0.025) + burst * 0.28;
	vec3 glow_color = mix(active_color.rgb, hot_color.rgb, burst);
	float final_alpha = clamp(body_alpha + outer_glow * glow_strength, 0.0, 1.0);
	vec3 premultiplied = base * body_alpha;
	premultiplied += glow_color * outer_glow * glow_strength;
	COLOR = vec4(premultiplied / max(final_alpha, 0.0001), final_alpha);
}
