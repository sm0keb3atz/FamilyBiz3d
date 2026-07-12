// Customizable Sky Shader by binbun, adapted for Family Business.
// Source: https://godotshaders.com/shader/customizable-sky-shader/ (CC0 1.0)
shader_type sky;

uniform vec4 sky_day : source_color = vec4(0.0, 0.3, 0.7, 1.0);
uniform vec4 horizon_day : source_color = vec4(0.75, 0.85, 0.85, 1.0);
uniform vec4 horizon_sunset : source_color = vec4(0.9, 0.4, 0.1, 1.0);
uniform vec4 sky_sunset : source_color = vec4(0.15, 0.2, 0.4, 1.0);
uniform vec4 horizon_night : source_color = vec4(0.1, 0.15, 0.2, 1.0);
uniform vec4 sky_night : source_color = vec4(0.015, 0.03, 0.08, 1.0);
uniform sampler2D cloud_tex_01;
uniform sampler2D cloud_tex_02;
uniform sampler2D night_noise_01;
uniform sampler2D night_noise_02;
uniform vec4 cloud_color : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform vec2 wind_speed = vec2(0.025, 0.012);
uniform float cloud_density : hint_range(0.01, 5.0, 0.1) = 0.7;
uniform float sun_scale = 0.05;
uniform float sun_strength = 15.0;
uniform vec4 sun_color : source_color = vec4(1.0, 0.9, 0.0, 1.0);

float cloud_height(sampler2D tex, vec2 uv) {
	return pow(clamp((texture(tex, uv).r - (1.0 - cloud_density)) / cloud_density, 0.0, 1.0), 2.0);
}

void sky() {
	float blend = LIGHT0_DIRECTION.y;
	float t = 1.0 / max(EYEDIR.y, 0.02);
	float clouds = 0.0;
	if (EYEDIR.y > 0.0) {
		vec2 wind = wind_speed * TIME * 0.1;
		// The infinite plane projection explodes as the view approaches the
		// horizon. Capping its distance prevents radial streaks and curtains.
		vec2 uv = EYEDIR.xz * min(t, 8.0) * 0.2;
		float first = cloud_height(cloud_tex_01, uv + wind);
		float second = cloud_height(cloud_tex_02, uv + wind * 0.5);
		clouds = min(first, first * second) * smoothstep(0.0, 0.2, EYEDIR.y);
	}
	float night = clamp(-blend, 0.0, 1.0);
	float stars = smoothstep(0.9, 0.95, texture(night_noise_01, EYEDIR.xz).r) * night;
	stars += texture(night_noise_02, EYEDIR.xz).r * 0.01 * night;
	stars *= 1.0 - clouds;
	vec3 horizon = mix(horizon_sunset.rgb, horizon_day.rgb, clamp(blend, 0.0, 1.0));
	horizon = mix(horizon_night.rgb, horizon, pow(clamp(1.0 + blend, 0.0, 1.0), 4.0));
	vec3 upper = mix(sky_sunset.rgb, sky_day.rgb, clamp(blend, 0.0, 1.0));
	upper = mix(sky_night.rgb, upper, pow(clamp(1.0 + blend, 0.0, 1.0), 4.0));
	vec3 result = mix(upper, horizon, pow(1.0 - abs(EYEDIR.y), 2.0));
	result = mix(result, cloud_color.rgb * mix(0.18, 1.0, clamp(blend + 0.25, 0.0, 1.0)), pow(clouds, 0.8));
	float sun_distance = clamp(1.0 - distance(EYEDIR, LIGHT0_DIRECTION) - clouds, 0.0, 1.0);
	result += sun_color.rgb * sun_strength * max(smoothstep(1.0 - sun_scale, 1.0, sun_distance), pow(sun_distance, 4.0) * 0.07);
	COLOR = result + stars;
}
