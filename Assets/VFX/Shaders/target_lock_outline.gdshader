// Lock-on silhouette outline inspired by:
// https://godotshaders.com/shader/inverted-hull-outline-with-group-merge/
shader_type spatial;
render_mode cull_front, unshaded, blend_mix, depth_draw_opaque, shadows_disabled;

uniform vec3 outline_color : source_color = vec3(1.0, 0.08, 0.03);
uniform float thickness : hint_range(0.0, 0.3) = 0.028;
uniform float outline_energy : hint_range(0.0, 4.0) = 1.4;
uniform float outline_transparency : hint_range(0.0, 1.0) = 0.9;
uniform float silhouette_start : hint_range(0.0, 1.0) = 0.18;
uniform float silhouette_end : hint_range(0.0, 1.0) = 0.42;
uniform bool merge_group = true;
uniform float merge_depth_range : hint_range(0.1, 100.0) = 10.0;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

varying float v_view_z;

void vertex() {
	vec3 d = VERTEX - vec3(0.0, 0.05, 0.0);
	vec3 dir = length(d) > 0.001 ? normalize(d) : vec3(0.0, -1.0, 0.0);
	vec3 view_n = normalize((MODELVIEW_MATRIX * vec4(dir, 0.0)).xyz);
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view_pos.xyz += view_n * thickness;
	v_view_z = view_pos.z;
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	if (merge_group) {
		float raw = texture(DEPTH_TEXTURE, SCREEN_UV).r;
		vec4 vs = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
		float scene_dist = -(vs.xyz / vs.w).z;
		float frag_dist = -v_view_z;
		float gap = scene_dist - frag_dist;
		if (gap > 0.01 && gap < merge_depth_range) {
			discard;
		}
	}
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float alpha = smoothstep(silhouette_start, silhouette_end, rim);
	if (alpha <= 0.01) {
		discard;
	}
	ALBEDO = outline_color * outline_energy;
	ALPHA = alpha * outline_transparency;
}
