shader_type canvas_item;
render_mode unshaded;

uniform vec4 accent_color : source_color = vec4(1.0, 0.62, 0.02, 1.0);
uniform float alert_level : hint_range(0.0, 1.0) = 0.0;
uniform float event_flash : hint_range(0.0, 1.0) = 0.0;


float hash(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}


void fragment() {
	vec2 centered = abs(UV * 2.0 - 1.0);
	float edge = smoothstep(0.63, 1.0, max(centered.x, centered.y));
	float scanline = 0.5 + 0.5 * sin(UV.y * 520.0 + TIME * 1.8);
	float diagonal = step(0.82, fract(UV.x * 12.0 - UV.y * 5.0 - TIME * 0.12));
	float noise = hash(floor(UV * vec2(180.0, 90.0) + TIME * 2.0));
	float alert_pulse = (0.5 + 0.5 * sin(TIME * 5.6)) * alert_level;
	float energy = edge * (0.018 + alert_level * 0.025);
	energy += scanline * 0.006 + diagonal * 0.008 * alert_level;
	energy += noise * 0.004 + alert_pulse * 0.012 + event_flash * 0.085;
	vec3 rgb = accent_color.rgb * energy;
	COLOR = vec4(rgb, clamp(energy, 0.0, 0.16));
}
