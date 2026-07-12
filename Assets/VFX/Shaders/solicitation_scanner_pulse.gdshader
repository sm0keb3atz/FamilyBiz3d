// Solicitation scanner pulse adapted from Watt Interactive's CC0
// "Sci-Fi Scanner Pulse (Godot 4 update)" for Godot 4.3+ reverse-Z.
shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, cull_disabled, blend_add;

uniform mat4 start_point = mat4(1.0);
uniform float radius = 0.0;
uniform float pulse_width : hint_range(0.05, 8.0) = 0.65;
uniform vec4 pulse_color : source_color = vec4(0.16, 0.95, 1.0, 0.82);
uniform float pulse_energy : hint_range(0.0, 4.0) = 1.25;
uniform float pulse_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float edge_sharpness : hint_range(0.1, 8.0) = 2.25;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.18;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

float sphere_distance(vec3 position, float sphere_radius) {
	return length(position) - sphere_radius;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = textureLod(DEPTH_TEXTURE, SCREEN_UV, 0.0).x;
	if (depth <= 0.0001) {
		discard;
	}

	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 world_position = world.xyz / world.w;
	vec3 local_position = (inverse(start_point) * vec4(world_position, 1.0)).xyz;

	float distance_to_shell = abs(sphere_distance(local_position, radius));
	float ring_mask = 1.0 - smoothstep(pulse_width * 0.2, pulse_width, distance_to_shell);
	float leading_edge = 1.0 - smoothstep(0.0, pulse_width * 0.18, distance_to_shell);
	float world_scanline = sin((world_position.y + world_position.x * 0.07) * 34.0);
	float scanline = mix(1.0, 0.72 + world_scanline * 0.28, scanline_strength);

	float pulse_alpha = pow(clamp(ring_mask, 0.0, 1.0), edge_sharpness);
	float edge_alpha = leading_edge * 0.5;
	vec3 pulse = pulse_color.rgb * pulse_energy * pulse_opacity * scanline;
	float alpha = (
		clamp(pulse_alpha + edge_alpha, 0.0, 1.0)
		* pulse_color.a
		* pulse_opacity
	);
	if (alpha <= 0.01) {
		discard;
	}

	ALBEDO = pulse;
	ALPHA = alpha;
}
