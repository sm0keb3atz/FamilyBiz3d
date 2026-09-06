shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float rain_activity : hint_range(0.0, 1.0) = 0.0;
uniform vec3 puddle_tint : source_color = vec3(0.055, 0.07, 0.085);
uniform float puddle_opacity : hint_range(0.0, 1.0) = 0.34;
uniform float puddle_roughness : hint_range(0.0, 1.0) = 0.10;
uniform float edge_softness : hint_range(0.01, 0.35) = 0.12;
uniform float ripple_normal_strength : hint_range(0.0, 0.5) = 0.14;

varying vec4 puddle_data;


vec2 ripple_ring(vec2 point, vec2 center, float phase) {
	vec2 offset = point - center;
	float distance_to_center = max(length(offset), 0.0001);
	vec2 direction = offset / distance_to_center;
	float ring_radius = fract(TIME * 0.24 + phase) * 1.35;
	float ring_distance = distance_to_center - ring_radius;
	float ring_strength = exp(-ring_distance * ring_distance * 320.0)
		* sin(ring_distance * 48.0);
	return direction * ring_strength;
}


void vertex() {
	puddle_data = INSTANCE_CUSTOM;
}


void fragment() {
	float seed = puddle_data.r;
	vec2 point = UV * 2.0 - vec2(1.0);
	point += vec2(
		sin(seed * 31.7),
		cos(seed * 27.1)
	) * 0.075;
	float angle = atan(point.y, point.x);
	float boundary = 0.76
		+ sin(angle * 3.0 + seed * 17.0) * 0.095
		+ sin(angle * 5.0 - seed * 23.0) * 0.055
		+ sin(angle * 8.0 + seed * 11.0) * 0.025;
	float radial_distance = length(point);
	float antialias_width = max(fwidth(radial_distance) * 1.5, edge_softness);
	float shape_mask = 1.0 - smoothstep(
		boundary - antialias_width,
		boundary + antialias_width,
		radial_distance
	);
	float wet_visibility = smoothstep(0.22, 0.72, wetness);
	float instance_intensity = mix(0.72, 1.0, puddle_data.a);
	float final_alpha = (
		shape_mask
		* wet_visibility
		* puddle_opacity
		* instance_intensity
	);
	if (final_alpha < 0.002) {
		discard;
	}

	vec2 first_ring = ripple_ring(
		point,
		vec2(-0.28, 0.17),
		puddle_data.b
	);
	vec2 second_ring = ripple_ring(
		point,
		vec2(0.31, -0.21),
		fract(puddle_data.b + 0.47)
	);
	vec2 ripple_normal = (
		first_ring
		+ second_ring * 0.72
	) * rain_activity * ripple_normal_strength * shape_mask;

	ALBEDO = puddle_tint;
	METALLIC = 0.0;
	ROUGHNESS = mix(0.24, puddle_roughness, wet_visibility);
	SPECULAR = 0.78;
	NORMAL_MAP = vec3(
		clamp(vec2(0.5) + ripple_normal, vec2(0.02), vec2(0.98)),
		1.0
	);
	NORMAL_MAP_DEPTH = 1.0;
	ALPHA = final_alpha;
}
