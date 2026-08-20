// Family Business island water, adapted for Godot 4.7 Forward+.
// Based on "Stylized Water for Godot 4.x" by MinhCreatorVN and its credited
// sources by kmitt91 and StayAtHomeDev.
// Source: https://godotshaders.com/shader/stylized-water-for-godot-4-x/
// The source shader and code snippets are provided under the MIT License.

shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D noise_texture_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_texture_b : repeat_enable, filter_linear_mipmap;
uniform sampler2D wave_texture : repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, repeat_enable, filter_linear_mipmap;

uniform vec4 shallow_color : source_color = vec4(0.055, 0.29, 0.35, 1.0);
uniform vec4 deep_color : source_color = vec4(0.012, 0.075, 0.12, 1.0);
uniform vec4 foam_color : source_color = vec4(0.72, 0.82, 0.80, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.24;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float water_opacity : hint_range(0.0, 1.0) = 0.78;

uniform vec2 wave_direction_a = vec2(0.82, 0.34);
uniform vec2 wave_direction_b = vec2(-0.28, 0.94);
uniform float wave_speed : hint_range(0.0, 0.2, 0.001) = 0.026;
uniform float wave_scale : hint_range(2.0, 80.0, 0.5) = 24.0;
uniform float wave_height : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float normal_scale : hint_range(1.0, 100.0, 0.5) = 18.0;
uniform float normal_strength : hint_range(0.0, 2.0, 0.01) = 0.34;

uniform float deep_distance : hint_range(0.5, 30.0, 0.1) = 8.0;
uniform float foam_width : hint_range(0.05, 4.0, 0.05) = 0.8;
uniform float foam_noise_amount : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform float refraction_strength : hint_range(0.0, 0.05, 0.001) = 0.012;
uniform float fresnel_strength : hint_range(0.0, 1.0, 0.01) = 0.28;

varying vec3 world_position;
varying float vertex_wave;

float view_depth(vec2 uv, float raw_depth, mat4 inverse_projection) {
	// Vulkan/Forward+ uses NDC z in [0, 1]. Godot 4.3+ also uses reverse-Z,
	// so reconstruct view position instead of relying on legacy near/far math.
	vec3 ndc = vec3(uv * 2.0 - 1.0, raw_depth);
	vec4 view = inverse_projection * vec4(ndc, 1.0);
	view.xyz /= max(view.w, 0.00001);
	return -view.z;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wave_uv = world_position.xz / wave_scale;
	float wave_a = texture(
		wave_texture,
		wave_uv + wave_direction_a * TIME * wave_speed
	).r;
	float wave_b = texture(
		wave_texture,
		wave_uv * 1.71 + wave_direction_b * TIME * wave_speed * 0.73
	).r;
	vertex_wave = ((wave_a + wave_b) - 1.0) * wave_height;
	VERTEX.y += vertex_wave;
}

void fragment() {
	float scene_view_depth = view_depth(
		SCREEN_UV,
		texture(depth_texture, SCREEN_UV).r,
		INV_PROJECTION_MATRIX
	);
	float surface_view_depth = view_depth(
		SCREEN_UV,
		FRAGCOORD.z,
		INV_PROJECTION_MATRIX
	);
	float depth_gap = max(scene_view_depth - surface_view_depth, 0.0);
	float depth_blend = smoothstep(0.0, deep_distance, depth_gap);

	vec2 world_uv = world_position.xz / normal_scale;
	vec2 flow_a = wave_direction_a * TIME * wave_speed * 1.35;
	vec2 flow_b = wave_direction_b * TIME * wave_speed * 0.92;
	float noise_a = texture(noise_texture_a, world_uv + flow_a).r;
	float noise_b = texture(noise_texture_b, world_uv * 1.83 + flow_b).r;
	float combined_noise = noise_a + noise_b - 1.0;

	vec2 distortion = vec2(combined_noise) * refraction_strength;
	vec3 refracted_scene = textureLod(
		screen_texture,
		SCREEN_UV + distortion,
		0.0
	).rgb;

	vec3 water_color = mix(shallow_color.rgb, deep_color.rgb, depth_blend);
	float fresnel = pow(
		1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0),
		3.0
	) * fresnel_strength;
	water_color = mix(water_color, shallow_color.rgb, fresnel);
	water_color = mix(refracted_scene, water_color, water_opacity);

	float noisy_foam_width = foam_width * mix(
		1.0 - foam_noise_amount,
		1.0 + foam_noise_amount,
		noise_a
	);
	float foam = 1.0 - smoothstep(0.05, noisy_foam_width, depth_gap);
	foam *= smoothstep(-0.10, 0.14, combined_noise + 0.18);

	ALBEDO = mix(water_color, foam_color.rgb, foam);
	NORMAL_MAP = texture(
		normal_texture,
		world_uv * 1.45 + flow_a - flow_b * 0.35
	).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = mix(roughness, 0.42, foam);
	METALLIC = metallic;
	SPECULAR = 0.55;
}
