shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform sampler2D blood_texture : source_color;
uniform vec4 blood_tint : source_color = vec4(0.38, 0.003, 0.006, 0.9);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 sample_color = texture(blood_texture, UV);
	float mask = smoothstep(0.015, 0.12, sample_color.r);
	ALBEDO = blood_tint.rgb * mix(0.54, 0.92, sample_color.r);
	ALPHA = mask * blood_tint.a;
}
