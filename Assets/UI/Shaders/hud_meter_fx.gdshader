shader_type canvas_item;
render_mode unshaded;

uniform vec4 accent_color : source_color = vec4(0.23, 0.63, 0.98, 1.0);
uniform vec4 warning_color : source_color = vec4(0.96, 0.10, 0.20, 1.0);
uniform float fill_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float trail_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float trail_amount : hint_range(0.0, 1.0) = 0.0;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float rising_amount : hint_range(0.0, 1.0) = 0.0;
uniform float warning_amount : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.0;
uniform float sheen_speed : hint_range(0.0, 1.0) = 0.16;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.22;
uniform bool reverse_fill = false;


void fragment() {
	float amount = clamp(fill_ratio, 0.0, 1.0);
	float enabled = step(0.0005, amount);

	float start_x = reverse_fill ? 1.0 - amount : 0.0;
	float end_x = reverse_fill ? 1.0 : amount;
	float feather = max(fwidth(UV.x) * 1.25, 0.0015);
	float active = smoothstep(start_x - feather, start_x + feather, UV.x);
	active *= 1.0 - smoothstep(end_x - feather, end_x + feather, UV.x);
	active *= enabled;
	float trail_value = max(amount, clamp(trail_ratio, 0.0, 1.0));
	float trail_start = reverse_fill ? 1.0 - trail_value : amount;
	float trail_end = reverse_fill ? 1.0 - amount : trail_value;
	float trail_mask = smoothstep(trail_start - feather, trail_start + feather, UV.x);
	trail_mask *= 1.0 - smoothstep(trail_end - feather, trail_end + feather, UV.x);
	trail_mask *= step(amount + 0.0005, trail_value) * trail_amount;

	float flow_x = reverse_fill ? 1.0 - UV.x : UV.x;
	float diagonal = fract(flow_x * 1.35 + UV.y * 0.42 - TIME * sheen_speed);
	float sheen = smoothstep(0.38, 0.49, diagonal);
	sheen *= 1.0 - smoothstep(0.49, 0.62, diagonal);

	float leading_x = reverse_fill ? start_x : end_x;
	float leading_edge = 1.0 - smoothstep(0.0, 0.055, abs(UV.x - leading_x));
	float center_light = 1.0 - abs(UV.y * 2.0 - 1.0);
	float warning_wave = warning_amount * (0.5 + 0.5 * sin(TIME * 5.4));
	float pulse_wave = pulse_amount * (0.72 + 0.28 * sin(TIME * 18.0));
	float flame_noise = sin(UV.x * 54.0 + TIME * 7.2);
	flame_noise += sin(UV.x * 91.0 - TIME * 10.4) * 0.48;
	flame_noise += sin(UV.x * 143.0 + TIME * 13.0) * 0.2;
	float flame_height = 0.28 + flame_noise * 0.07;
	float flame_band = 1.0 - smoothstep(flame_height, flame_height + 0.28, UV.y);
	float ember_wave = sin(UV.x * 117.0 - TIME * 15.0);
	ember_wave *= sin(UV.x * 37.0 + TIME * 8.0);
	float embers = pow(max(ember_wave, 0.0), 10.0);
	float fire = active * rising_amount * clamp(flame_band + embers * 0.85, 0.0, 1.0);

	vec4 live_color = mix(accent_color, warning_color, warning_amount);
	live_color.rgb = mix(live_color.rgb, vec3(1.0, 0.88, 0.72), flash_amount * 0.82);
	float light = 0.82 + center_light * 0.16;
	light += sheen * (0.24 + glow_strength * 0.34);
	light += leading_edge * (0.20 + glow_strength * 0.46);
	light += warning_wave * 0.16 + pulse_wave * 0.28;
	light += flash_amount * 0.52 + rising_amount * leading_edge * 0.34;
	vec3 rgb = live_color.rgb * light;
	rgb += vec3(1.0, 0.22, 0.015) * fire * 0.58;
	rgb += vec3(1.0, 0.72, 0.08) * fire * fire * 0.42;
	float alpha = active * clamp(0.91 + sheen * 0.06 + pulse_wave * 0.03, 0.0, 1.0);
	vec3 trail_color = mix(vec3(1.0, 0.18, 0.12), vec3(1.0, 0.78, 0.42), center_light);
	vec4 main_layer = vec4(rgb, alpha * live_color.a);
	vec4 trail_layer = vec4(trail_color, trail_mask * (0.48 + flash_amount * 0.34));
	float combined_alpha = main_layer.a + trail_layer.a * (1.0 - main_layer.a);
	vec3 combined_premultiplied = main_layer.rgb * main_layer.a;
	combined_premultiplied += trail_layer.rgb * trail_layer.a * (1.0 - main_layer.a);
	COLOR = vec4(
		combined_premultiplied / max(combined_alpha, 0.0001),
		combined_alpha
	);
}
