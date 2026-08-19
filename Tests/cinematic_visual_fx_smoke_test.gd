extends SceneTree

const TimeComponentScript := preload(
	"res://Scripts/Gameplay/world_time_component.gd"
)
const WeatherScene := preload("res://Scenes/VFX/WeatherSystem.tscn")
const SkyShader := preload("res://Assets/VFX/Shaders/customizable_sky.gdshader")
const OutlineShader := preload(
	"res://Assets/VFX/Shaders/target_lock_outline.gdshader"
)
const OutlineHaloShader := preload(
	"res://Assets/VFX/Shaders/target_lock_outline_halo.gdshader"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var environment_root := Node3D.new()
	environment_root.name = "Environment"
	stage.add_child(environment_root)

	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = Environment.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SkyShader
	var sky := Sky.new()
	sky.sky_material = sky_material
	world_environment.environment.sky = sky
	environment_root.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	environment_root.add_child(sun)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	environment_root.add_child(moon)

	var gameplay := Node3D.new()
	gameplay.name = "Gameplay"
	stage.add_child(gameplay)
	var player := CharacterBody3D.new()
	player.name = "Player"
	gameplay.add_child(player)

	var time := TimeComponentScript.new() as WorldTimeComponent
	time.name = "WorldTimeComponent"
	stage.add_child(time)
	var weather := WeatherScene.instantiate() as WeatherSystem
	weather.random_weather_enabled = false
	stage.add_child(weather)
	await process_frame
	time.set_process(false)
	weather.set_process(false)

	var environment := world_environment.environment
	assert(environment.tonemap_mode == Environment.TONE_MAPPER_AGX)
	assert(is_equal_approx(environment.tonemap_exposure, 1.02))
	assert(is_equal_approx(environment.tonemap_agx_contrast, 1.26))
	assert(environment.adjustment_color_correction is GradientTexture1D)
	assert(environment.ssao_enabled)
	assert(environment.ssil_enabled)
	assert(not environment.ssr_enabled)
	assert(not environment.sdfgi_enabled)
	assert(environment.volumetric_fog_enabled)
	assert(is_equal_approx(environment.volumetric_fog_length, 58.0))
	assert(is_equal_approx(environment.glow_intensity, 0.16))
	assert("depth_gap > depth_bias && depth_gap < merge_depth_range" in OutlineShader.code)
	assert("float silhouette = smoothstep" in OutlineShader.code)
	assert("EMISSION = base_color" in OutlineShader.code)
	assert("EMISSION = glow_color" in OutlineHaloShader.code)
	assert("LIGHT1_ENABLED" in SkyShader.code)

	assert(time.set_time_of_day(13, 30))
	var clear_density := environment.volumetric_fog_density
	assert(is_equal_approx(clear_density, 0.0018))
	assert(weather.set_weather(WeatherSystem.HEAVY_RAIN, true))
	weather._apply_visuals()
	assert(environment.volumetric_fog_density > clear_density)
	assert(is_equal_approx(
		float(sky_material.get_shader_parameter("weather_overcast")),
		0.82
	))

	assert(time.set_time_of_day(0, 0))
	weather.set_weather(WeatherSystem.CLEAR, true)
	weather._apply_visuals()
	assert(is_equal_approx(
		environment.volumetric_fog_density,
		time.visual_profile.night_volumetric_fog_density
	))
	assert(moon.light_energy > sun.light_energy)

	var world_scene := load("res://Scenes/Maps/World/world.tscn") as PackedScene
	assert(world_scene != null)
	print("CINEMATIC_VISUAL_FX_SMOKE_TEST_PASS")
	quit(0)
