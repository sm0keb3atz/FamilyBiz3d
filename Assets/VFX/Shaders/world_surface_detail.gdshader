shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metallic_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_albedo_texture = false;
uniform bool use_metallic_texture = false;
uniform bool use_roughness_texture = false;
uniform bool use_ao_texture = false;
uniform int metallic_channel = 0;
uniform int roughness_channel = 0;
uniform int ao_channel = 0;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec3 surface_tint : source_color = vec3(1.0);
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float metallic = 0.0;
uniform float roughness = 1.0;
uniform float macro_scale = 18.0;
uniform float macro_variation = 0.065;
uniform float roughness_variation = 0.06;
uniform float roughness_bias = 0.0;

varying vec3 world_position;


float channel_value(vec4 sample_value, int channel) {
	if (channel == 1) {
		return sample_value.g;
	}
	if (channel == 2) {
		return sample_value.b;
	}
	if (channel == 3) {
		return sample_value.a;
	}
	return sample_value.r;
}


float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec2 styled_uv = UV * uv_scale.xy + uv_offset.xy;
	vec4 base = albedo_color;
	if (use_albedo_texture) {
		base *= texture(albedo_texture, styled_uv);
	}
	float macro_noise = value_noise(world_position.xz / max(macro_scale, 0.001));
	float centered_noise = macro_noise * 2.0 - 1.0;
	ALBEDO = base.rgb * surface_tint * (1.0 + centered_noise * macro_variation);
	float final_metallic = metallic;
	if (use_metallic_texture) {
		final_metallic *= channel_value(texture(metallic_texture, styled_uv), metallic_channel);
	}
	float final_roughness = roughness;
	if (use_roughness_texture) {
		final_roughness *= channel_value(texture(roughness_texture, styled_uv), roughness_channel);
	}
	METALLIC = clamp(final_metallic, 0.0, 1.0);
	ROUGHNESS = clamp(
		final_roughness + roughness_bias + centered_noise * roughness_variation,
		0.04,
		1.0
	);
	if (use_ao_texture) {
		AO = channel_value(texture(ao_texture, styled_uv), ao_channel);
		AO_LIGHT_AFFECT = 0.35;
	}
}
