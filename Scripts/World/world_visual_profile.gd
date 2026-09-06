class_name WorldVisualProfile
extends Resource

## Shared art-direction values for the outdoor world.  Keeping these values in
## one resource prevents the clock and weather systems from fighting over the
## same Environment and DirectionalLight3D properties.

const META_BASE_AMBIENT_COLOR := &"fb_visual_base_ambient_color"
const META_BASE_AMBIENT_ENERGY := &"fb_visual_base_ambient_energy"
const META_BASE_FOG_COLOR := &"fb_visual_base_fog_color"
const META_BASE_FOG_ENERGY := &"fb_visual_base_fog_energy"
const META_BASE_FOG_DENSITY := &"fb_visual_base_fog_density"
const META_BASE_FOG_AERIAL := &"fb_visual_base_fog_aerial"
const META_BASE_FOG_SUN_SCATTER := &"fb_visual_base_fog_sun_scatter"
const META_BASE_VOLUMETRIC_FOG_DENSITY := &"fb_visual_base_volumetric_fog_density"
const META_BASE_SUN_COLOR := &"fb_visual_base_sun_color"
const META_BASE_SUN_ENERGY := &"fb_visual_base_sun_energy"
const META_BASE_MOON_ENERGY := &"fb_visual_base_moon_energy"
const META_BASE_GRADE_COLORS := &"fb_visual_base_grade_colors"
const META_BASE_SATURATION := &"fb_visual_base_saturation"
const META_BASE_GLOW_INTENSITY := &"fb_visual_base_glow_intensity"

@export_category("Post Processing")
@export_range(0.1, 4.0, 0.01) var tonemap_exposure := 1.0
@export_range(0.5, 3.0, 0.01) var agx_contrast := 1.30
@export_range(1.0, 32.0, 0.1) var agx_white := 8.0
@export_range(0.0, 2.0, 0.01) var saturation := 0.95
@export_range(0.0, 4.0, 0.01) var glow_intensity := 0.16
@export_range(0.0, 4.0, 0.01) var glow_bloom := 0.025
@export_range(0.0, 8.0, 0.01) var glow_hdr_threshold := 1.20

@export_category("Color Grading")
@export var grade_black := Color(0.004, 0.007, 0.014)
@export var grade_shadow := Color(0.135, 0.155, 0.19)
@export var grade_mid := Color(0.50, 0.495, 0.48)
@export var grade_highlight := Color(0.855, 0.815, 0.755)
@export var grade_white := Color(1.0, 0.965, 0.91)

@export_category("Dynamic Color Grading")
@export var dynamic_color_grading_enabled := true
@export_range(0.25, 3.0, 0.05) var golden_transition_hours := 1.5
@export_range(0.0, 1.0, 0.01) var golden_grade_strength := 0.62
@export_range(0.0, 1.0, 0.01) var night_grade_strength := 0.72
@export_range(0.0, 1.0, 0.01) var storm_grade_strength := 0.68
@export var golden_grade_black := Color(0.004, 0.007, 0.014)
@export var golden_grade_shadow := Color(0.12, 0.145, 0.195)
@export var golden_grade_mid := Color(0.515, 0.49, 0.45)
@export var golden_grade_highlight := Color(0.90, 0.79, 0.67)
@export var golden_grade_white := Color(1.0, 0.945, 0.84)
@export var night_grade_black := Color(0.003, 0.006, 0.014)
@export var night_grade_shadow := Color(0.095, 0.135, 0.21)
@export var night_grade_mid := Color(0.455, 0.475, 0.515)
@export var night_grade_highlight := Color(0.78, 0.805, 0.84)
@export var night_grade_white := Color(0.94, 0.955, 0.975)
@export var storm_grade_black := Color(0.004, 0.006, 0.012)
@export var storm_grade_shadow := Color(0.115, 0.135, 0.17)
@export var storm_grade_mid := Color(0.46, 0.47, 0.475)
@export var storm_grade_highlight := Color(0.785, 0.805, 0.815)
@export var storm_grade_white := Color(0.94, 0.955, 0.965)
@export_range(0.0, 2.0, 0.01) var golden_saturation := 1.01
@export_range(0.0, 2.0, 0.01) var night_saturation := 0.96
@export_range(0.0, 2.0, 0.01) var storm_saturation := 0.92
@export_range(0.0, 4.0, 0.01) var day_glow_intensity := 0.14
@export_range(0.0, 4.0, 0.01) var golden_glow_intensity := 0.16
@export_range(0.0, 4.0, 0.01) var night_glow_intensity := 0.19
@export_range(0.0, 4.0, 0.01) var overcast_glow_intensity := 0.17

@export_category("Camera Exposure")
@export var auto_exposure_enabled := true
@export_range(0.0, 3200.0, 1.0) var auto_exposure_min_sensitivity := 80.0
@export_range(0.0, 3200.0, 1.0) var auto_exposure_max_sensitivity := 220.0
@export_range(0.01, 4.0, 0.01) var auto_exposure_speed := 0.65
@export_range(0.01, 2.0, 0.01) var auto_exposure_scale := 0.45

@export_category("Lens Finish")
@export var lens_finish_enabled := true
@export_range(0.0, 0.2, 0.001) var lens_vignette_strength := 0.045
@export_range(0.0, 0.05, 0.001) var lens_grain_strength := 0.006
@export_range(0.0, 0.02, 0.0001) var lens_dither_strength := 0.0039

@export_category("Screen Space Lighting")
@export var ssil_enabled := true
@export_range(0.0, 8.0, 0.05) var ssil_radius := 3.5
@export_range(0.0, 4.0, 0.01) var ssil_intensity := 0.58
@export_range(0.0, 1.0, 0.01) var ssil_sharpness := 0.92
@export_range(0.0, 1.0, 0.01) var ssil_normal_rejection := 0.82

@export_category("Ambient Light")
@export var night_ambient_color := Color(0.10, 0.15, 0.26)
@export var day_ambient_color := Color(0.42, 0.50, 0.65)
@export_range(0.0, 4.0, 0.01) var night_ambient_energy := 0.22
@export_range(0.0, 4.0, 0.01) var day_ambient_energy := 0.52

@export_category("Sun and Moon")
@export var sunrise_sun_color := Color(1.0, 0.42, 0.24)
@export var day_sun_color := Color(1.0, 0.92, 0.80)
@export_range(0.0, 8.0, 0.01) var night_sun_energy := 0.02
@export_range(0.0, 8.0, 0.01) var day_sun_energy := 1.35
@export_range(0.0, 8.0, 0.01) var moon_energy := 0.16

@export_category("Clear Atmosphere")
@export var night_fog_color := Color(0.11, 0.16, 0.25)
@export var day_fog_color := Color(0.56, 0.65, 0.73)
@export_range(0.0, 1.0, 0.001) var night_fog_light_energy := 0.34
@export_range(0.0, 1.0, 0.001) var day_fog_light_energy := 0.72
@export_range(0.0, 0.1, 0.0001) var clear_fog_density := 0.0012
@export_range(0.0, 1.0, 0.01) var clear_fog_aerial_perspective := 0.42
@export_range(0.0, 1.0, 0.01) var clear_fog_sun_scatter := 0.08
@export_range(0.0, 1.0, 0.01) var night_fog_sky_affect := 0.76
@export_range(0.0, 1.0, 0.01) var day_fog_sky_affect := 0.46

@export_category("Local Atmosphere")
@export_range(0.0, 0.1, 0.0001) var night_volumetric_fog_density := 0.0032
@export_range(0.0, 0.1, 0.0001) var day_volumetric_fog_density := 0.0018
@export_range(0.0, 0.1, 0.0001) var weather_volumetric_fog_density := 0.0075
@export_range(8.0, 256.0, 1.0) var volumetric_fog_length := 180.0
@export_range(-0.9, 0.9, 0.01) var volumetric_fog_anisotropy := 0.36
@export_range(0.0, 1.0, 0.01) var volumetric_fog_ambient_inject := 0.22
@export_range(0.0, 1.0, 0.01) var volumetric_fog_sky_affect := 0.32
@export_range(0.0, 1.0, 0.01) var night_volumetric_fog_sky_affect := 0.64

@export_category("Weather Modifiers")
@export var storm_fog_color := Color(0.25, 0.27, 0.29)
@export var lightning_fog_color := Color(0.62, 0.70, 0.88)
@export var overcast_ambient_color := Color(0.27, 0.285, 0.31)
@export var overcast_sun_color := Color(0.64, 0.655, 0.68)
@export_range(0.0, 0.1, 0.0001) var weather_fog_density := 0.01
@export_range(0.0, 1.0, 0.01) var weather_fog_aerial_perspective := 0.48
@export_range(0.0, 1.0, 0.01) var overcast_ambient_multiplier := 0.68
@export_range(0.0, 1.0, 0.01) var overcast_sun_multiplier := 0.32

@export_category("Surface Response")
@export_range(0.0, 0.25, 0.005) var ground_macro_variation := 0.065
@export_range(1.0, 64.0, 0.5) var ground_macro_scale := 18.0
@export_range(0.0, 0.25, 0.005) var ground_roughness_variation := 0.06
@export_range(0.0, 1.0, 0.01) var vehicle_paint_roughness := 0.28
@export_range(0.0, 1.0, 0.01) var vehicle_clearcoat := 0.80
@export_range(0.0, 1.0, 0.01) var vehicle_clearcoat_roughness := 0.12

@export_category("Surface Wetness")
@export var surface_wetness_enabled := true
@export_range(0.0, 1.0, 0.001) var wetness_accumulation_per_second := 0.12
@export_range(0.0, 1.0, 0.001) var wetness_drying_per_second := 0.006
@export_range(0.0, 1.0, 0.01) var active_rain_wetness_floor := 0.50
@export_range(0.0, 0.5, 0.01) var heavy_rain_wetness_boost := 0.22
@export_range(0.0, 0.3, 0.005) var wet_road_darkening := 0.17
@export_range(0.0, 1.0, 0.01) var wet_road_roughness := 0.30
@export_range(0.0, 1.0, 0.01) var puddle_roughness := 0.14

@export_category("Puddle Overlays")
@export var puddle_overlays_enabled := true
@export_range(0.1, 4.0, 0.1) var puddles_per_100_square_meters := 0.9
@export_range(1, 8, 1) var maximum_puddles_per_road_mesh := 4
@export_range(0.5, 8.0, 0.1) var puddle_minimum_diameter := 1.8
@export_range(0.5, 12.0, 0.1) var puddle_maximum_diameter := 5.2
@export_range(0.2, 1.0, 0.01) var puddle_minimum_aspect := 0.48
@export_range(0.0, 1.0, 0.01) var puddle_overlay_opacity := 0.34
@export_range(0.01, 0.35, 0.01) var puddle_edge_softness := 0.12
@export_range(0.0, 0.5, 0.01) var puddle_ripple_normal_strength := 0.14
@export_range(0.001, 0.1, 0.001) var puddle_surface_offset := 0.018
@export_range(20.0, 300.0, 5.0) var puddle_visibility_distance := 140.0

@export_category("Street Lights")
@export var streetlight_fade_enabled := true
@export_range(0.1, 8.0, 0.1) var streetlight_fade_seconds := 1.5


func get_day_grade_colors() -> PackedColorArray:
	return PackedColorArray([
		grade_black,
		grade_shadow,
		grade_mid,
		grade_highlight,
		grade_white,
	])


func get_golden_grade_colors() -> PackedColorArray:
	return blend_grade_colors(
		get_day_grade_colors(),
		PackedColorArray([
			golden_grade_black,
			golden_grade_shadow,
			golden_grade_mid,
			golden_grade_highlight,
			golden_grade_white,
		]),
		golden_grade_strength
	)


func get_night_grade_colors() -> PackedColorArray:
	return blend_grade_colors(
		get_day_grade_colors(),
		PackedColorArray([
			night_grade_black,
			night_grade_shadow,
			night_grade_mid,
			night_grade_highlight,
			night_grade_white,
		]),
		night_grade_strength
	)


func get_storm_grade_colors() -> PackedColorArray:
	return blend_grade_colors(
		get_day_grade_colors(),
		PackedColorArray([
			storm_grade_black,
			storm_grade_shadow,
			storm_grade_mid,
			storm_grade_highlight,
			storm_grade_white,
		]),
		storm_grade_strength
	)


func blend_grade_colors(
	from_colors: PackedColorArray,
	to_colors: PackedColorArray,
	weight: float
) -> PackedColorArray:
	var result := PackedColorArray()
	var safe_weight := clampf(weight, 0.0, 1.0)
	var count := mini(from_colors.size(), to_colors.size())
	for index in count:
		result.append(from_colors[index].lerp(to_colors[index], safe_weight))
	return result


func create_color_correction_texture(
	colors: PackedColorArray = PackedColorArray()
) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 0.82, 1.0])
	gradient.colors = get_day_grade_colors() if colors.is_empty() else colors
	var texture := GradientTexture1D.new()
	texture.width = 256
	texture.gradient = gradient
	return texture
