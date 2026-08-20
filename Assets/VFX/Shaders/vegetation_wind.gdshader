shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// Lightweight shoreline vegetation wind. The phase and speed are derived
// from each instance's world position, so normal MeshInstance3D nodes and
// runtime MultiMesh batches never sway in lockstep.

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_albedo_texture = false;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_normal_texture = false;
uniform float normal_scale : hint_range(0.0, 4.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.35;

uniform vec2 wind_direction = vec2(0.86, 0.52);
uniform float wind_strength : hint_range(0.0, 0.5) = 0.16;
uniform float wind_speed : hint_range(0.0, 4.0) = 0.72;
uniform float anchor_height = 0.0;
uniform float full_sway_height = 11.0;
uniform float flutter_strength : hint_range(0.0, 0.1) = 0.018;
uniform float weather_wind_multiplier : hint_range(1.0, 4.0) = 1.0;
uniform float weather_speed_multiplier : hint_range(1.0, 2.0) = 1.0;
uniform float weather_gustiness : hint_range(0.0, 1.0) = 0.0;

varying float wind_weight;

float hash_21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}

void vertex() {
	vec2 instance_position = MODEL_MATRIX[3].xz;
	float phase_seed = hash_21(floor(instance_position * 3.17) + vec2(17.0, 43.0));
	float speed_seed = hash_21(floor(instance_position * 1.91) + vec2(79.0, 11.0));
	float phase = phase_seed * TAU;
	float instance_speed = (
		wind_speed
		* weather_speed_multiplier
		* mix(0.78, 1.24, speed_seed)
	);
	float height_range = max(full_sway_height - anchor_height, 0.001);
	wind_weight = smoothstep(
		0.0,
		1.0,
		clamp((VERTEX.y - anchor_height) / height_range, 0.0, 1.0)
	);
	wind_weight *= wind_weight;

	float broad_sway = sin(TIME * instance_speed + phase);
	float uneven_gust = sin(TIME * instance_speed * 0.43 + phase * 1.73);
	float storm_pulse = pow(max(
		sin(TIME * instance_speed * 0.19 + phase * 0.37),
		0.0
	), 3.0) * weather_gustiness;
	float local_flutter = sin(
		TIME * instance_speed * 2.65
		+ phase * 2.31
		+ VERTEX.y * 1.37
		+ VERTEX.x * 0.41
	);
	float amplitude = (
		wind_strength
		* weather_wind_multiplier
		* mix(0.76, 1.22, phase_seed)
	);
	vec2 direction = normalize(wind_direction + vec2(speed_seed - 0.5, phase_seed - 0.5) * 0.28);
	float gust_mix = mix(0.38, 0.78, weather_gustiness);
	vec2 offset = direction * (
		broad_sway
		+ uneven_gust * gust_mix
		+ storm_pulse * mix(0.0, 0.72, phase_seed)
	) * amplitude;
	offset += direction.yx * local_flutter * flutter_strength;
	VERTEX.xz += offset * wind_weight;
}

void fragment() {
	vec2 mapped_uv = UV * uv_scale.xy + uv_offset.xy;
	vec4 base = albedo_color;
	if (use_albedo_texture) {
		base *= texture(albedo_texture, mapped_uv);
	}
	ALBEDO = base.rgb * COLOR.rgb;
	ALPHA = base.a * COLOR.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	if (use_normal_texture) {
		NORMAL_MAP = texture(normal_texture, mapped_uv).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
}
