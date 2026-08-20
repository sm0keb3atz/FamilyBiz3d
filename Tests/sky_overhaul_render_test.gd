extends SceneTree

const SkyShader := preload("res://Assets/VFX/Shaders/customizable_sky.gdshader")
const OUTPUT_DIRECTORY := "res://.runtime_appdata/sky_overhaul"

var _environment: Environment
var _sky_material: ShaderMaterial
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(960, 540)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	var stage := Node3D.new()
	root.add_child(stage)
	_build_sky(stage)
	_build_horizon_reference(stage)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.8, 4.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 2.25, -3.0))
	camera.fov = 72.0
	camera.current = true
	stage.add_child(camera)

	for _frame in 36:
		await process_frame
	await _capture_day()
	await _capture_storm()
	await _capture_night()
	print("SKY_OVERHAUL_RENDER_TEST_PASS")
	quit(0)


func _build_sky(stage: Node3D) -> void:
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = SkyShader
	_sky_material.set_shader_parameter("cloud_tex_01", _noise_texture(3191, 0.018, 3))
	_sky_material.set_shader_parameter("cloud_tex_02", _noise_texture(8807, 0.032, 4))
	_sky_material.set_shader_parameter("night_noise_01", _noise_texture(2249, 0.12, 3))
	_sky_material.set_shader_parameter("night_noise_02", _noise_texture(6113, 0.04, 3))
	var sky := Sky.new()
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.sky_material = _sky_material
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.42, 0.50, 0.65)
	_environment.ambient_light_energy = 0.52
	_environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	_environment.tonemap_exposure = 1.02
	_environment.tonemap_agx_contrast = 1.26
	_environment.fog_enabled = true
	_environment.fog_light_color = Color(0.56, 0.65, 0.73)
	_environment.fog_light_energy = 0.72
	_environment.fog_density = 0.0012
	_environment.fog_aerial_perspective = 0.42
	_environment.fog_sky_affect = 0.46
	var world_environment := WorldEnvironment.new()
	world_environment.environment = _environment
	stage.add_child(world_environment)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-75.0, -30.0, 0.0)
	_sun.light_color = Color(1.0, 0.92, 0.80)
	_sun.light_energy = 1.35
	_sun.shadow_enabled = true
	stage.add_child(_sun)
	_moon = DirectionalLight3D.new()
	_moon.rotation_degrees = Vector3(-270.0, 28.0, 0.0)
	_moon.light_color = Color(0.48, 0.62, 1.0)
	_moon.light_energy = 0.0
	stage.add_child(_moon)


func _noise_texture(seed_value: int, frequency: float, octaves: int) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	return texture


func _build_horizon_reference(stage: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.075, 0.085, 0.10)
	material.roughness = 0.86
	for placement in [
		[Vector3(-10.0, 1.4, -18.0), Vector3(7.0, 4.8, 4.0)],
		[Vector3(-2.7, 1.0, -22.0), Vector3(5.5, 4.0, 4.0)],
		[Vector3(4.5, 1.8, -20.0), Vector3(7.0, 5.6, 4.0)],
		[Vector3(11.5, 0.8, -24.0), Vector3(6.0, 3.6, 4.0)],
	]:
		var building := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = placement[1]
		building.mesh = box
		building.position = placement[0]
		building.material_override = material
		stage.add_child(building)


func _capture_day() -> void:
	_sun.rotation_degrees = Vector3(-75.0, -30.0, 0.0)
	_sun.light_energy = 1.35
	_moon.light_energy = 0.0
	_sky_material.set_shader_parameter("weather_overcast", 0.0)
	_sky_material.set_shader_parameter("weather_cloud_offset", Vector2.ZERO)
	_environment.fog_light_color = Color(0.56, 0.65, 0.73)
	_environment.fog_light_energy = 0.72
	_environment.fog_density = 0.0012
	_environment.fog_sky_affect = 0.46
	await _save_frame("clear_day.png")


func _capture_storm() -> void:
	_sky_material.set_shader_parameter("weather_overcast", 1.0)
	_sky_material.set_shader_parameter("weather_cloud_offset", Vector2(0.08, 0.03))
	_environment.fog_light_color = Color(0.25, 0.27, 0.29)
	_environment.fog_light_energy = 0.59
	_environment.fog_density = 0.0054
	_environment.fog_sky_affect = 0.58
	await _save_frame("thunderstorm.png")


func _capture_night() -> void:
	_sun.rotation_degrees = Vector3(-270.0, -30.0, 0.0)
	_sun.light_energy = 0.02
	_moon.rotation_degrees = Vector3(-90.0, 28.0, 0.0)
	_moon.light_energy = 0.22
	_sky_material.set_shader_parameter("weather_overcast", 0.0)
	_sky_material.set_shader_parameter("weather_cloud_offset", Vector2(0.01, 0.004))
	_environment.ambient_light_color = Color(0.085, 0.13, 0.23)
	_environment.ambient_light_energy = 0.28
	_environment.fog_light_color = Color(0.075, 0.115, 0.20)
	_environment.fog_light_energy = 0.44
	_environment.fog_density = 0.0012
	_environment.fog_sky_affect = 0.76
	await _save_frame("clear_night.png")


func _save_frame(file_name: String) -> void:
	for _frame in 12:
		await process_frame
	var image := root.get_texture().get_image()
	assert(image != null and not image.is_empty())
	assert(image.save_png(OUTPUT_DIRECTORY.path_join(file_name)) == OK)
