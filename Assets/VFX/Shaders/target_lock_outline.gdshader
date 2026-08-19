// Soft screen-space silhouette used by target lock and customer solicitation.
// Nearby depth rejection merges overlapping body and clothing meshes, while
// the view-angle mask keeps the effect on the outside contour instead of the
// front of shirts, pants, and other garments.
shader_type spatial;
render_mode cull_front, unshaded, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 outline_color : source_color = vec3(1.0, 0.1, 0.025);
uniform float thickness : hint_range(0.5, 8.0, 0.1) = 2.7;
uniform float outline_energy : hint_range(0.0, 6.0, 0.05) = 1.25;
uniform float outline_transparency : hint_range(0.0, 1.0, 0.01) = 0.9;
uniform float depth_bias : hint_range(0.0, 0.25, 0.001) = 0.035;
uniform float merge_depth_range : hint_range(0.0, 2.0, 0.01) = 0.28;
uniform float rim_start : hint_range(0.0, 1.0, 0.01) = 0.40;
uniform float rim_end : hint_range(0.0, 1.0, 0.01) = 0.84;
uniform float rim_power : hint_range(0.25, 4.0, 0.05) = 1.0;
uniform float pulse_strength : hint_range(0.0, 0.25, 0.005) = 0.02;
uniform float pulse_speed : hint_range(0.0, 12.0, 0.1) = 4.0;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying float shell_view_depth;


void vertex() {
	vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec4 clip_position = PROJECTION_MATRIX * view_position;

	// Project the normal into screen space so thickness is measured in pixels,
	// remaining crisp at both close and long lock-on distances.
	vec2 projected_normal = (
		PROJECTION_MATRIX * vec4(view_normal, 0.0)
	).xy;
	if (length(projected_normal) < 0.0001) {
		projected_normal = view_position.xy;
	}
	vec2 pixel_offset = (
		normalize(projected_normal)
		* thickness
		* 2.0
		/ max(VIEWPORT_SIZE, vec2(1.0))
	);
	clip_position.xy += pixel_offset * clip_position.w;
	shell_view_depth = -view_position.z;
	POSITION = clip_position;
}


void fragment() {
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
	vec4 view_position = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float scene_view_depth = -(view_position.z / view_position.w);

	float depth_gap = scene_view_depth - shell_view_depth;

	// Reject occluders in front of the shell. Also reject scene geometry only a
	// short distance behind it; that second case is what removes expanded
	// clothing and body shells from the front of the character.
	if (depth_gap < -depth_bias) {
		discard;
	}
	if (depth_gap > depth_bias && depth_gap < merge_depth_range) {
		discard;
	}

	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(clamp(1.0 - facing, 0.0, 1.0), rim_power);
	float silhouette = smoothstep(rim_start, rim_end, rim);
	if (silhouette <= 0.005) {
		discard;
	}

	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_strength;
	vec3 base_color = outline_color * pulse;
	ALBEDO = base_color * 0.78;
	EMISSION = base_color * outline_energy * 0.25;
	ALPHA = silhouette * outline_transparency;
}
