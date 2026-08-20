// Family Business cinematic procedural sky.
// Triplanar cloud sampling keeps the weather stable at the horizon and avoids
// the radial stretching produced by a flat or cylindrical cloud projection.
shader_type sky;

uniform vec4 sky_day : source_color = vec4(0.045, 0.22, 0.52, 1.0);
uniform vec4 horizon_day : source_color = vec4(0.55, 0.69, 0.78, 1.0);
uniform vec4 horizon_sunset : source_color = vec4(0.95, 0.38, 0.12, 1.0);
uniform vec4 sky_sunset : source_color = vec4(0.18, 0.12, 0.28, 1.0);
uniform vec4 horizon_night : source_color = vec4(0.055, 0.085, 0.145, 1.0);
uniform vec4 sky_night : source_color = vec4(0.006, 0.012, 0.035, 1.0);
uniform sampler2D cloud_tex_01 : repeat_enable, filter_linear_mipmap;
uniform sampler2D cloud_tex_02 : repeat_enable, filter_linear_mipmap;
uniform sampler2D night_noise_01 : repeat_enable, filter_linear_mipmap;
uniform sampler2D night_noise_02 : repeat_enable, filter_linear_mipmap;
uniform vec4 cloud_color : source_color = vec4(0.72, 0.76, 0.79, 1.0);
uniform float cloud_density : hint_range(0.01, 1.0, 0.01) = 0.56;
uniform float sun_scale = 0.018;
uniform float sun_strength = 8.5;
uniform vec4 sun_color : source_color = vec4(1.0, 0.76, 0.46, 1.0);
uniform float moon_scale = 0.012;
uniform float moon_strength = 1.8;
uniform vec4 moon_color : source_color = vec4(0.62, 0.74, 1.0, 1.0);
uniform float weather_overcast : hint_range(0.0, 1.0) = 0.0;
uniform float weather_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec2 weather_cloud_offset = vec2(0.0);


float triplanar_noise(sampler2D noise_tex, vec3 sample_position, vec3 direction) {
	vec3 weights = pow(abs(direction), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	float sample_x = texture(noise_tex, sample_position.yz).r;
	float sample_y = texture(noise_tex, sample_position.xz).r;
	float sample_z = texture(noise_tex, sample_position.xy).r;
	return dot(vec3(sample_x, sample_y, sample_z), weights);
}


float hash31(vec3 value) {
	value = fract(value * 0.1031);
	value += dot(value, value.yzx + 33.33);
	return fract((value.x + value.y) * value.z);
}


float cloud_layer(
	sampler2D shape_tex,
	sampler2D detail_tex,
	vec3 direction,
	vec3 wind_offset,
	float scale,
	float coverage,
	float detail_weight
) {
	vec3 sample_position = direction * scale + wind_offset;
	float broad_shape = triplanar_noise(shape_tex, sample_position, direction);
	float detail = triplanar_noise(
		detail_tex,
		sample_position * 2.73 - wind_offset * 0.38,
		direction
	);
	float sculpted = mix(broad_shape, broad_shape * mix(0.72, 1.24, detail), detail_weight);
	float threshold = 1.0 - coverage;
	return smoothstep(threshold, threshold + mix(0.22, 0.10, weather_overcast), sculpted);
}


void sky() {
	vec3 view_direction = normalize(EYEDIR);
	float view_height = view_direction.y;
	float horizon = pow(1.0 - abs(view_height), 3.2);
	float sun_elevation = LIGHT0_DIRECTION.y;
	float daylight = smoothstep(-0.10, 0.20, sun_elevation);
	float night = 1.0 - smoothstep(-0.16, 0.03, sun_elevation);

	vec3 night_gradient = mix(sky_night.rgb, horizon_night.rgb, horizon);
	vec3 day_gradient = mix(sky_day.rgb, horizon_day.rgb, horizon);
	vec3 result = mix(night_gradient, day_gradient, daylight);

	// A directional twilight band gives sunrise and sunset depth without
	// painting the entire horizon orange.
	vec2 view_azimuth = view_direction.xz / max(length(view_direction.xz), 0.0001);
	vec2 sun_azimuth = LIGHT0_DIRECTION.xz / max(length(LIGHT0_DIRECTION.xz), 0.0001);
	float facing_sun = pow(clamp(dot(view_azimuth, sun_azimuth) * 0.5 + 0.5, 0.0, 1.0), 2.0);
	float twilight = 1.0 - smoothstep(0.03, 0.30, abs(sun_elevation + 0.035));
	vec3 twilight_gradient = mix(sky_sunset.rgb, horizon_sunset.rgb, horizon);
	result = mix(
		result,
		twilight_gradient,
		twilight * horizon * mix(0.18, 0.78, facing_sun)
	);
	vec3 overcast_atmosphere = mix(
		vec3(0.022, 0.024, 0.030),
		vec3(0.105, 0.110, 0.118),
		daylight
	);
	result = mix(result, overcast_atmosphere, weather_overcast * 0.88);

	// The weather system integrates this offset frame by frame. Changing wind
	// speed or direction therefore bends the cloud path naturally instead of
	// re-evaluating TIME at a new multiplier and making the sky fast-forward.
	vec3 wind_offset = vec3(weather_cloud_offset.x, 0.0, weather_cloud_offset.y);
	float coverage = mix(cloud_density, 0.76, weather_overcast);
	float high_layer = cloud_layer(
		cloud_tex_01,
		cloud_tex_02,
		view_direction,
		wind_offset,
		0.62,
		coverage,
		mix(0.32, 0.52, weather_overcast)
	);
	float low_layer = cloud_layer(
		cloud_tex_02,
		cloud_tex_01,
		view_direction,
		wind_offset * 0.61 + vec3(1.7, 0.2, -0.9),
		1.05,
		mix(cloud_density * 0.58, 0.70, weather_overcast),
		0.42
	);
	float upper_hemisphere = smoothstep(-0.065, 0.13, view_height);
	float cloud_shape = mix(high_layer, max(high_layer, low_layer * 0.88), weather_overcast);
	float cloud_opacity = cloud_shape * upper_hemisphere;

	float broad_cloud_light = triplanar_noise(
		cloud_tex_01,
		view_direction * 0.84 + wind_offset * 0.18 + vec3(-0.4, 1.1, 0.7),
		view_direction
	);
	float medium_cloud_light = triplanar_noise(
		cloud_tex_02,
		view_direction * 1.70 - wind_offset * 0.12,
		view_direction
	);
	float micro_cloud_light = triplanar_noise(
		cloud_tex_02,
		view_direction * 4.1 + wind_offset * 0.31,
		view_direction
	);
	float cloud_detail = clamp(
		mix(broad_cloud_light, medium_cloud_light, 0.34)
		+ (micro_cloud_light - 0.5) * 0.10,
		0.0,
		1.0
	);
	vec3 cloud_night = mix(vec3(0.025, 0.038, 0.070), vec3(0.075, 0.095, 0.145), cloud_detail);
	vec3 cloud_day = mix(
		vec3(0.43, 0.48, 0.55),
		cloud_color.rgb * 1.08,
		cloud_detail
	);
	vec3 fair_cloud_light = mix(cloud_night, cloud_day, daylight);
	vec3 storm_cloud_light = mix(
		vec3(0.026, 0.027, 0.031),
		mix(vec3(0.082, 0.086, 0.092), vec3(0.315, 0.320, 0.326), cloud_detail),
		daylight
	);
	vec3 active_cloud_light = mix(fair_cloud_light, storm_cloud_light, weather_overcast);
	float silver_lining = smoothstep(0.22, 0.72, cloud_shape) * (1.0 - smoothstep(0.72, 0.98, cloud_shape));
	active_cloud_light += sun_color.rgb * silver_lining * facing_sun * daylight * (1.0 - weather_overcast) * 0.12;
	result = mix(result, active_cloud_light, cloud_opacity * mix(0.84, 0.97, weather_overcast));

	// The distant cloud bank and aerial haze share the same horizon mask, so
	// there is no day/night seam where fog meets the sky.
	float distant_bank = smoothstep(-0.045, 0.035, view_height) * (1.0 - smoothstep(0.08, 0.28, view_height));
	vec3 horizon_haze_color = mix(horizon_night.rgb, horizon_day.rgb, daylight);
	horizon_haze_color = mix(horizon_haze_color, vec3(0.185, 0.192, 0.202), weather_overcast);
	result = mix(
		result,
		horizon_haze_color,
		distant_bank * mix(0.30, 0.74, weather_overcast)
	);

	float sky_visibility = (1.0 - cloud_opacity) * (1.0 - weather_overcast * 0.94);
	float sun_alignment = clamp(dot(view_direction, LIGHT0_DIRECTION), 0.0, 1.0);
	float sun_disc = smoothstep(cos(sun_scale * 1.12), cos(sun_scale * 0.88), sun_alignment);
	float sun_inner = smoothstep(cos(sun_scale * 0.72), 1.0, sun_alignment);
	float sun_halo = pow(sun_alignment, 180.0) * 0.09 + pow(sun_alignment, 1400.0) * 0.14;
	result += sun_color.rgb * sun_strength * daylight * sky_visibility * (
		sun_disc * 0.52 + sun_inner * 0.34 + sun_halo
	);

	if (LIGHT1_ENABLED) {
		float moon_alignment = clamp(dot(view_direction, LIGHT1_DIRECTION), 0.0, 1.0);
		float moon_disc = smoothstep(cos(moon_scale * 1.12), cos(moon_scale * 0.90), moon_alignment);
		float moon_texture = triplanar_noise(
			night_noise_02,
			view_direction * 7.0,
			view_direction
		);
		float moon_surface = mix(0.72, 1.08, moon_texture);
		float moon_corona = pow(moon_alignment, 260.0) * 0.12 + pow(moon_alignment, 1250.0) * 0.10;
		result += moon_color.rgb * moon_strength * night * sky_visibility * (
			moon_disc * moon_surface + moon_corona
		);
	}

	float star_variation = triplanar_noise(
		night_noise_02,
		view_direction * 11.3 + vec3(2.1, -1.7, 0.4),
		view_direction
	);
	vec3 fine_star_cell = floor(view_direction * 720.0);
	vec3 bright_star_cell = floor(view_direction * 310.0 + vec3(13.0, 7.0, 29.0));
	float stars = smoothstep(0.9985, 0.9998, hash31(fine_star_cell));
	stars += smoothstep(0.9995, 0.99995, hash31(bright_star_cell)) * 1.25;
	stars *= mix(0.58, 1.18, star_variation);
	stars *= night * sky_visibility * smoothstep(0.015, 0.24, view_height);
	result += mix(vec3(0.62, 0.72, 1.0), vec3(1.0, 0.86, 0.66), star_variation) * stars * 0.82;

	// Lightning illuminates the cloud volume more than the clear portions of
	// the sky, which preserves cloud definition during a flash.
	vec3 lightning_color = vec3(0.64, 0.73, 1.0);
	float lightning_mix = weather_flash * mix(0.56, 0.90, cloud_opacity);
	result = mix(result, lightning_color, lightning_mix);
	result += lightning_color * weather_flash * cloud_opacity * 0.18;
	COLOR = max(result, vec3(0.0));
}
