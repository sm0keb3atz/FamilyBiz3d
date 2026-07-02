shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

uniform sampler2D mark_texture : source_color;

void fragment() {
	vec4 sample_color = texture(mark_texture, UV);
	float brightness = max(sample_color.r, max(sample_color.g, sample_color.b));
	float mask = smoothstep(0.025, 0.11, brightness);
	ALBEDO = sample_color.rgb * vec3(0.45, 0.42, 0.40);
	ROUGHNESS = 0.92;
	ALPHA = mask;
}
