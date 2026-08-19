// Customizable Sky Shader by binbun, adapted for Family Business.
// Source: https://godotshaders.com/shader/customizable-sky-shader/ (CC0 1.0)
shader_type sky;

uniform vec4 sky_day : source_color = vec4(0.045, 0.22, 0.52, 1.0);
uniform vec4 horizon_day : source_color = vec4(0.55, 0.69, 0.78, 1.0);
uniform vec4 horizon_sunset : source_color = vec4(0.95, 0.38, 0.12, 1.0);
uniform vec4 sky_sunset : source_color = vec4(0.18, 0.12, 0.28, 1.0);
uniform vec4 horizon_night : source_color = vec4(0.075, 0.11, 0.18, 1.0);
uniform vec4 sky_night : source_color = vec4(0.01, 0.02, 0.055, 1.0);
uniform sampler2D cloud_tex_01;
uniform sampler2D cloud_tex_02;
uniform sampler2D night_noise_01;
uniform sampler2D night_noise_02;
uniform vec4 cloud_color : source_color = vec4(0.72, 0.76, 0.79, 1.0);
uniform vec2 wind_speed = vec2(0.025, 0.012);
uniform float cloud_density : hint_range(0.01, 5.0, 0.1) = 0.62;
// Angular radius in radians. 0.018 is a readable stylized sun without the
// giant billboard look of the original distance-based calculation.
uniform float sun_scale = 0.018;
uniform float sun_strength = 8.5;
uniform vec4 sun_color : source_color = vec4(1.0, 0.76, 0.46, 1.0);
uniform float moon_scale = 0.012;
uniform float moon_strength = 1.8;
uniform vec4 moon_color : source_color = vec4(0.62, 0.74, 1.0, 1.0);
uniform float weather_overcast : hint_range(0.0, 1.0) = 0.0;
uniform float weather_flash : hint_range(0.0, 1.0) = 0.0;

float cloud_height(sampler2D tex, vec2 uv, float density) {
	return pow(clamp((texture(tex, uv).r - (1.0 - density)) / density, 0.0, 1.0), 2.0);
}

void sky() {
	float blend = LIGHT0_DIRECTION.y;
	float clouds = 0.0;
	float cloud_detail = 0.5;
	if (EYEDIR.y > 0.0) {
		vec2 wind = wind_speed * TIME * mix(0.1, 0.26, weather_overcast);
		// A flat cloud plane stretches toward infinity at the horizon. Blend to
		// cylindrical coordinates there so clouds stay horizontal and never
		// turn into downward curtains, while retaining the overhead projection.
		float horizon_u = atan(EYEDIR.z, EYEDIR.x) / TAU + 0.5;
		vec2 horizon_uv = vec2(horizon_u * 2.4, EYEDIR.y * 1.35);
		vec2 overhead_uv = EYEDIR.xz / max(EYEDIR.y, 0.18) * 0.2;
		float projection_blend = smoothstep(0.12, 0.42, EYEDIR.y);
		vec2 uv = mix(horizon_uv, overhead_uv, projection_blend);
		float density = mix(cloud_density, 1.55, weather_overcast);
		float first = cloud_height(cloud_tex_01, uv + wind, density);
		float second = cloud_height(cloud_tex_02, uv + wind * 0.5, density);
		cloud_detail = second;
		float fair_clouds = min(first, first * second);
		float storm_clouds = max(first, second) * 0.94;
		clouds = mix(fair_clouds, storm_clouds, weather_overcast) * smoothstep(0.06, 0.28, EYEDIR.y);
	}
	float night = clamp(-blend, 0.0, 1.0);
	float stars = smoothstep(0.9, 0.95, texture(night_noise_01, EYEDIR.xz).r) * night;
	stars += texture(night_noise_02, EYEDIR.xz).r * 0.01 * night;
	stars *= (1.0 - clouds) * (1.0 - weather_overcast);
	vec3 horizon = mix(horizon_sunset.rgb, horizon_day.rgb, clamp(blend, 0.0, 1.0));
	horizon = mix(horizon_night.rgb, horizon, pow(clamp(1.0 + blend, 0.0, 1.0), 4.0));
	vec3 upper = mix(sky_sunset.rgb, sky_day.rgb, clamp(blend, 0.0, 1.0));
	upper = mix(sky_night.rgb, upper, pow(clamp(1.0 + blend, 0.0, 1.0), 4.0));
	vec3 result = mix(upper, horizon, pow(1.0 - abs(EYEDIR.y), 2.0));
	float storm_daylight = clamp(blend + 0.3, 0.12, 1.0);
	vec3 storm_sky = vec3(0.035, 0.045, 0.065) + vec3(0.12, 0.13, 0.15) * storm_daylight;
	result = mix(result, storm_sky, weather_overcast * 0.72);
	vec3 active_cloud_color = mix(cloud_color.rgb, vec3(0.16, 0.18, 0.22), weather_overcast);
	float cloud_light = mix(0.72, 1.06, cloud_detail);
	result = mix(result, active_cloud_color * cloud_light * mix(0.18, 1.0, clamp(blend + 0.25, 0.0, 1.0)), pow(clouds, mix(0.9, 0.72, weather_overcast)));
	float sun_alignment = clamp(dot(EYEDIR, LIGHT0_DIRECTION), 0.0, 1.0);
	float sun_occlusion = 1.0 - clouds;
	float sun_core = smoothstep(cos(sun_scale), 1.0, sun_alignment);
	float sun_halo = pow(sun_alignment, 1200.0) * 0.1;
	result += sun_color.rgb * sun_strength * (1.0 - weather_overcast * 0.94) * sun_occlusion * (sun_core * 0.62 + sun_halo);
	if (LIGHT1_ENABLED) {
		float moon_alignment = clamp(dot(EYEDIR, LIGHT1_DIRECTION), 0.0, 1.0);
		float moon_core = smoothstep(cos(moon_scale), 1.0, moon_alignment);
		float moon_corona = pow(moon_alignment, 520.0) * 0.12;
		result += moon_color.rgb * moon_strength * night * (1.0 - weather_overcast * 0.88) * (1.0 - clouds) * (moon_core + moon_corona);
	}
	float horizon_haze = pow(1.0 - abs(EYEDIR.y), 7.0);
	result += mix(vec3(0.018, 0.028, 0.055), sun_color.rgb * 0.075, clamp(blend + 0.2, 0.0, 1.0)) * horizon_haze * (1.0 - weather_overcast * 0.55);
	result += stars;
	result = mix(result, vec3(0.7, 0.8, 1.0), weather_flash * 0.82);
	COLOR = result + vec3(weather_flash * 0.22);
}
