// A restrained, layered solicitation scan built for Godot 4 reverse-Z depth.
// The effect is reconstructed in world space so the energy stays attached to
// streets, walls, characters, and props as the expanding wave crosses them.
shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, cull_disabled, blend_add;

uniform mat4 start_point = mat4(1.0);
uniform float radius = 0.0;
uniform float max_radius = 8.0;
uniform float pulse_width : hint_range(0.05, 8.0) = 0.72;
uniform vec4 pulse_color : source_color = vec4(0.04, 0.48, 0.62, 0.40);
uniform vec4 secondary_color : source_color = vec4(0.03, 0.12, 0.45, 0.30);
uniform vec4 core_color : source_color = vec4(0.08, 0.62, 0.74, 0.48);
uniform float pulse_energy : hint_range(0.0, 4.0) = 0.62;
uniform float pulse_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float edge_sharpness : hint_range(0.1, 8.0) = 2.4;
uniform float core_intensity : hint_range(0.0, 4.0) = 0.55;
uniform float wake_length : hint_range(0.05, 4.0) = 1.15;
uniform float echo_offset : hint_range(0.05, 4.0) = 0.78;
uniform float echo_strength : hint_range(0.0, 1.5) = 0.38;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.16;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.22;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;


float hash31(vec3 value) {
	value = fract(value * 0.1031);
	value += dot(value, value.yzx + 33.33);
	return fract((value.x + value.y) * value.z);
}


float line_pattern(float coordinate, float frequency, float sharpness) {
	float wave = 0.5 + 0.5 * cos(coordinate * frequency);
	return pow(wave, sharpness);
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
	vec3 local_position = (
		inverse(start_point) * vec4(world_position, 1.0)
	).xyz;

	float distance_from_origin = length(local_position);
	float shell_distance = distance_from_origin - radius;
	float shell_absolute = abs(shell_distance);
	float anti_alias = max(fwidth(shell_distance), 0.004);
	float core_width = max(pulse_width * 0.075, anti_alias);

	// White-hot leading edge with a wider cyan energy envelope.
	float core = 1.0 - smoothstep(
		core_width,
		core_width + anti_alias * 1.5,
		shell_absolute
	);
	float envelope = 1.0 - smoothstep(
		core_width,
		pulse_width + anti_alias,
		shell_absolute
	);
	envelope = pow(clamp(envelope, 0.0, 1.0), edge_sharpness);

	// The short interior wake gives the scan direction and volume rather than
	// leaving a perfectly symmetrical, flat-looking ring.
	float wake_distance = max(-shell_distance, 0.0);
	float wake = smoothstep(0.0, core_width * 2.5, wake_distance);
	wake *= 1.0 - smoothstep(
		core_width * 2.5,
		max(wake_length, core_width * 3.0),
		wake_distance
	);

	// A dimmer delayed echo makes the pulse feel authored while remaining
	// visually subordinate to the main wavefront.
	float echo_radius = max(radius - echo_offset, 0.0);
	float echo_distance = abs(distance_from_origin - echo_radius);
	float echo_width = max(core_width * 0.8, anti_alias);
	float echo = 1.0 - smoothstep(
		echo_width,
		echo_width + pulse_width * 0.28 + anti_alias,
		echo_distance
	);
	echo *= smoothstep(echo_offset * 0.85, echo_offset * 1.15, radius);

	// World-locked circuitry and interference break up the broad glow without
	// swimming across surfaces when the camera moves.
	float height_lines = line_pattern(
		local_position.y + local_position.x * 0.035,
		31.0,
		11.0
	);
	float angle = atan(local_position.z, local_position.x);
	float radial_lines = line_pattern(
		angle + local_position.y * 0.055,
		24.0,
		14.0
	);
	float cell_noise = hash31(floor(world_position * 3.5));
	float moving_charge = 0.5 + 0.5 * sin(
		dot(local_position, vec3(2.7, 5.1, -3.3))
		+ radius * 7.5
		- TIME * 2.0
	);
	float circuitry = clamp(
		height_lines * 0.65 + radial_lines * 0.35,
		0.0,
		1.0
	);
	float texture_modulation = mix(
		1.0 - texture_strength * 0.38,
		1.0 + texture_strength * 0.52,
		cell_noise * 0.55 + moving_charge * 0.45
	);
	float scan_detail = mix(
		1.0,
		0.82 + circuitry * 0.42,
		scanline_strength
	);

	float progress = clamp(radius / max(max_radius, 0.001), 0.0, 1.0);
	float birth = smoothstep(0.0, 0.055, progress);
	float main_energy = envelope * texture_modulation * scan_detail;
	float wake_energy = wake * (0.15 + circuitry * 0.20);
	float echo_energy = echo * echo_strength * (
		0.72 + moving_charge * 0.28
	);

	vec3 energy_color = pulse_color.rgb * main_energy;
	energy_color += mix(secondary_color.rgb, pulse_color.rgb, circuitry) * (
		wake_energy + echo_energy
	);
	energy_color += core_color.rgb * core * core_intensity;
	energy_color *= pulse_energy * pulse_opacity * birth;

	float alpha = main_energy * pulse_color.a;
	alpha += wake_energy * secondary_color.a;
	alpha += echo_energy * secondary_color.a;
	alpha += core * core_color.a * 0.65;
	alpha = clamp(alpha * pulse_opacity * birth, 0.0, 1.0);
	if (alpha <= 0.008) {
		discard;
	}

	ALBEDO = energy_color * 0.65;
	EMISSION = energy_color * 0.08;
	ALPHA = alpha;
}
