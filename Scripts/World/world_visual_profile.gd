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


func create_color_correction_texture() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 0.82, 1.0])
	gradient.colors = PackedColorArray([
		grade_black,
		grade_shadow,
		grade_mid,
		grade_highlight,
		grade_white,
	])
	var texture := GradientTexture1D.new()
	texture.width = 256
	texture.gradient = gradient
	return texture
