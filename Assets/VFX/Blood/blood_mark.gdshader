shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

uniform sampler2D blood_texture : source_color;
uniform vec4 blood_tint : source_color = vec4(0.35, 0.005, 0.008, 0.95);

void fragment() {
	vec4 sample_color = texture(blood_texture, UV);
	float mask = smoothstep(0.015, 0.12, sample_color.r);
	ALBEDO = blood_tint.rgb * mix(0.52, 1.0, sample_color.r);
	ROUGHNESS = 0.74;
	ALPHA = mask * blood_tint.a;
}
