// Rim-only lock highlight inspired by:
// https://godotshaders.com/shader/inverted-hull-outline-with-group-merge/
shader_type spatial;
render_mode cull_disabled, unshaded, blend_mix, depth_draw_never, shadows_disabled;

uniform vec3 outline_color : source_color = vec3(1.0, 0.08, 0.03);
uniform float thickness : hint_range(0.0, 0.3) = 0.02;
uniform float outline_energy : hint_range(0.0, 4.0) = 1.4;
uniform float outline_transparency : hint_range(0.0, 1.0) = 0.9;
uniform float rim_start : hint_range(0.0, 1.0) = 0.56;
uniform float rim_end : hint_range(0.0, 1.0) = 0.94;
uniform bool merge_group = true;

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float alpha = smoothstep(rim_start, rim_end, rim) * outline_transparency;
	if (alpha <= 0.01) {
		discard;
	}
	ALBEDO = outline_color * outline_energy;
	ALPHA = alpha;
}
