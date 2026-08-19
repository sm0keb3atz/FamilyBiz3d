shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 smoke_color : source_color = vec4(0.58, 0.60, 0.62, 0.34);

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
	vec2 centered_uv = UV * 2.0 - 1.0;
	float radius = length(centered_uv);
	float angle = atan(centered_uv.y, centered_uv.x);
	float broken_edge = sin(angle * 5.0 + 0.7) * 0.055;
	broken_edge += sin(angle * 8.0 - 1.3) * 0.028;
	float soft_shape = 1.0 - smoothstep(0.24, 0.96 + broken_edge, radius);
	float cloudy_center = 0.88 + sin((centered_uv.x - centered_uv.y) * 5.5) * 0.06;

	ALBEDO = smoke_color.rgb * COLOR.rgb;
	ALPHA = soft_shape * cloudy_center * smoke_color.a * COLOR.a;
}
