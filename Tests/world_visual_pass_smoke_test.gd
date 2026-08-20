extends SceneTree

const TimeComponentScript := preload(
	"res://Scripts/Gameplay/world_time_component.gd"
)
const WeatherScene := preload("res://Scenes/VFX/WeatherSystem.tscn")
const SurfaceStylerScript := preload("res://Scripts/World/world_surface_styler.gd")
const StaticBatcherScript := preload("res://Scripts/World/static_multimesh_batcher.gd")
const SkyShader := preload("res://Assets/VFX/Shaders/customizable_sky.gdshader")
const GrassMesh := preload(
	"res://Assets/MapStuff/Meshs/GroundTileset/SM_grass_00.glb"
)
const MuscleCarScene := preload("res://Scenes/Vehicles/MuscleCar.tscn")
const PAINT_META := &"family_business_vehicle_paint"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_environment_and_weather()
	await _test_surface_styling_and_batching()
	await _test_vehicle_paint_isolation()
	var world_scene := load("res://Scenes/Maps/World/world.tscn") as PackedScene
	assert(world_scene != null)
	print("WORLD_VISUAL_PASS_SMOKE_TEST_PASS")
	quit(0)


func _test_environment_and_weather() -> void:
	var stage := Node3D.new()
	stage.name = "VisualStage"
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

	var environment := world_environment.environment
	assert(sky_material.shader == SkyShader)
	assert("moon_strength" in SkyShader.code)
	assert("triplanar_noise" in SkyShader.code)
	assert("weather_cloud_offset" in SkyShader.code)
	assert("* TIME *" not in SkyShader.code)
	assert(environment.tonemap_mode == Environment.TONE_MAPPER_AGX)
	assert(is_equal_approx(environment.tonemap_exposure, 1.02))
	assert(is_equal_approx(environment.tonemap_agx_contrast, 1.26))
	assert(is_equal_approx(environment.tonemap_agx_white, 8.0))
	assert(is_equal_approx(environment.adjustment_saturation, 1.0))
	assert(environment.adjustment_color_correction != null)
	assert(environment.ssao_enabled)
	assert(not environment.ssr_enabled)
	assert(environment.ssil_enabled)
	assert(is_equal_approx(environment.ssil_intensity, 0.58))
	assert(not environment.sdfgi_enabled)
	assert(environment.volumetric_fog_enabled)
	assert(is_equal_approx(environment.volumetric_fog_length, 180.0))
	assert(environment.fog_enabled)

	var test_roof := MeshInstance3D.new()
	var test_roof_mesh := BoxMesh.new()
	test_roof_mesh.size = Vector3(4.0, 0.2, 4.0)
	test_roof.mesh = test_roof_mesh
	test_roof.position.y = 4.0
	stage.add_child(test_roof)
	weather._roof_meshes.clear()
	weather._roof_meshes.append(test_roof)
	assert(weather._has_cached_roof_cover())
	weather._is_sheltered = true
	weather._shelter_visual_scale = 0.0
	assert(weather.set_weather(WeatherSystem.RAIN, true))
	weather._update_weather_blend(0.0)
	assert(not (weather.get_node("RainStreaks") as GPUParticles3D).visible)
	assert(not (weather.get_node("RainStreaks") as GPUParticles3D).emitting)
	weather._roof_meshes.clear()
	weather._is_sheltered = false
	weather._shelter_visual_scale = 1.0
	weather._update_weather_blend(0.0)
	assert((weather.get_node("RainStreaks") as GPUParticles3D).visible)
	assert((weather.get_node("RainStreaks") as GPUParticles3D).emitting)
	assert(weather.set_weather(WeatherSystem.CLEAR, true))
	test_roof.queue_free()

	assert(time.set_time_of_day(8, 0))
	await process_frame
	assert(sun.light_energy > 0.75)
	assert(environment.ambient_light_energy > 0.45)

	assert(time.set_time_of_day(13, 30))
	await process_frame
	assert(sun.light_energy > 1.3)
	assert(is_equal_approx(environment.ambient_light_energy, 0.52))
	var clear_density := environment.fog_density
	var clear_volumetric_density := environment.volumetric_fog_density
	var clear_ambient := environment.ambient_light_color
	var clear_ambient_energy := environment.ambient_light_energy
	var clear_sun_energy := sun.light_energy
	assert(is_equal_approx(clear_density, 0.0012))
	assert(is_equal_approx(clear_volumetric_density, 0.0018))

	assert(weather.set_weather(WeatherSystem.RAIN, true))
	await process_frame
	assert(is_equal_approx(
		float(sky_material.get_shader_parameter("weather_overcast")),
		0.55
	))
	assert(environment.fog_density > clear_density)
	assert(environment.volumetric_fog_density > clear_volumetric_density)
	assert(environment.ambient_light_energy < clear_ambient_energy)
	assert(sun.light_energy < clear_sun_energy)

	assert(weather.set_weather(WeatherSystem.HEAVY_RAIN, true))
	await process_frame
	var heavy_density := environment.fog_density
	assert(heavy_density > clear_density)

	assert(weather.set_weather(WeatherSystem.THUNDERSTORM, true))
	await process_frame
	assert(is_equal_approx(
		float(sky_material.get_shader_parameter("weather_overcast")),
		1.0
	))
	assert(environment.fog_density > heavy_density)

	assert(weather.set_weather(WeatherSystem.CLEAR, true))
	await process_frame
	assert(is_zero_approx(
		float(sky_material.get_shader_parameter("weather_overcast"))
	))
	assert(is_equal_approx(environment.fog_density, clear_density))
	assert(environment.ambient_light_color.is_equal_approx(clear_ambient))
	assert(is_equal_approx(environment.ambient_light_energy, clear_ambient_energy))
	assert(is_equal_approx(sun.light_energy, clear_sun_energy))

	assert(time.set_time_of_day(19, 30))
	await process_frame
	assert(is_equal_approx(environment.ambient_light_energy, 0.28))
	assert(sun.light_energy < 0.021)
	assert(moon.light_energy > 0.21)
	assert(environment.fog_sky_affect > 0.7)
	assert(time.set_time_of_day(0, 0))
	await process_frame
	assert(is_equal_approx(environment.ambient_light_energy, 0.28))
	assert(is_equal_approx(moon.light_energy, 0.22))

	stage.queue_free()
	await process_frame


func _test_surface_styling_and_batching() -> void:
	var stage := Node3D.new()
	stage.name = "SurfaceStage"
	root.add_child(stage)
	var surface_root := Node3D.new()
	surface_root.name = "SurfaceRoot"
	stage.add_child(surface_root)

	var grass_a := MeshInstance3D.new()
	grass_a.name = "GrassA"
	grass_a.mesh = GrassMesh
	surface_root.add_child(grass_a)
	var grass_b := MeshInstance3D.new()
	grass_b.name = "GrassB"
	grass_b.mesh = GrassMesh
	grass_b.position.x = 4.0
	surface_root.add_child(grass_b)
	var excluded_window := MeshInstance3D.new()
	excluded_window.name = "WindowGlass"
	excluded_window.mesh = GrassMesh
	excluded_window.position.x = 8.0
	surface_root.add_child(excluded_window)
	var unrelated := MeshInstance3D.new()
	unrelated.name = "UnrelatedProp"
	unrelated.mesh = BoxMesh.new()
	surface_root.add_child(unrelated)

	var styler := SurfaceStylerScript.new() as WorldSurfaceStyler
	styler.name = "WorldSurfaceStyler"
	styler.source_roots = [NodePath("../SurfaceRoot")]
	stage.add_child(styler)
	assert(styler.styled_mesh_count == 2)
	assert(styler.get_cached_material_count() == 1)
	var styled_a := grass_a.get_surface_override_material(0)
	var styled_b := grass_b.get_surface_override_material(0)
	assert(styled_a is ShaderMaterial)
	assert(styled_a == styled_b)
	assert(excluded_window.get_surface_override_material(0) == null)
	assert(unrelated.get_surface_override_material(0) == null)

	var batcher := StaticBatcherScript.new() as StaticMultiMeshBatcher
	batcher.name = "StaticMultiMeshBatcher"
	batcher.source_roots = [NodePath("../SurfaceRoot")]
	batcher.minimum_instances_per_batch = 2
	stage.add_child(batcher)
	await process_frame
	await process_frame
	assert(batcher.batch_count >= 1)
	assert(batcher.batched_instance_count >= 2)
	assert(not grass_a.visible and not grass_b.visible)

	stage.queue_free()
	await process_frame


func _test_vehicle_paint_isolation() -> void:
	var car_a := MuscleCarScene.instantiate() as BaseVehicle
	var car_b := MuscleCarScene.instantiate() as BaseVehicle
	root.add_child(car_a)
	root.add_child(car_b)
	await process_frame
	var red := Color(0.72, 0.04, 0.025)
	var blue := Color(0.03, 0.18, 0.75)
	assert(car_a.apply_traffic_body_color(red) > 0)
	assert(car_b.apply_traffic_body_color(blue) > 0)
	var paint_a := _find_paint_materials(car_a)
	var paint_b := _find_paint_materials(car_b)
	assert(not paint_a.is_empty() and not paint_b.is_empty())
	assert(paint_a[0] != paint_b[0])
	assert((paint_a[0] as BaseMaterial3D).albedo_color.is_equal_approx(red))
	assert((paint_b[0] as BaseMaterial3D).albedo_color.is_equal_approx(blue))
	for material in paint_a + paint_b:
		var paint := material as BaseMaterial3D
		assert(paint.resource_local_to_scene)
		assert(is_equal_approx(paint.roughness, 0.28))
		assert(paint.clearcoat_enabled)
		assert(is_equal_approx(paint.clearcoat, 0.8))
		assert(is_equal_approx(paint.clearcoat_roughness, 0.12))
	car_a.queue_free()
	car_b.queue_free()
	await process_frame


func _find_paint_materials(node: Node) -> Array[Material]:
	var results: Array[Material] = []
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for surface_index in mesh_instance.get_surface_override_material_count():
			var material := mesh_instance.get_surface_override_material(surface_index)
			if material != null and material.has_meta(PAINT_META):
				results.append(material)
	for child in node.get_children():
		results.append_array(_find_paint_materials(child))
	return results
