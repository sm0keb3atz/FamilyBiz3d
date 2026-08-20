shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform float scanline_density : hint_range(300.0, 1800.0) = 1080.0;

float random_noise(vec2 value) {
	return fract(sin(dot(value, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 centered = uv - vec2(0.5);
	float edge = smoothstep(0.42, 0.72, length(centered * vec2(1.15, 0.88)));
	float scan = 0.5 + 0.5 * sin(uv.y * scanline_density * 3.14159265);
	float grain = random_noise(floor(uv * vec2(960.0, 540.0)) + floor(TIME * 24.0));
	float sweep = pow(max(0.0, 1.0 - abs(fract(uv.y - TIME * 0.045) - 0.5) * 24.0), 2.0);
	float flicker = 0.92 + 0.08 * sin(TIME * 17.0);
	float alpha = edge * 0.38 + scan * 0.035 + grain * 0.018 + sweep * 0.025;
	vec3 tint = mix(vec3(0.0), vec3(0.015, 0.075, 0.055), sweep + grain * 0.15);
	COLOR = vec4(tint, alpha * strength * flicker);
}
