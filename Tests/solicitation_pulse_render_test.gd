extends SceneTree

const PulseShader := preload(
	"res://Assets/VFX/Shaders/solicitation_scanner_pulse.gdshader"
)
const SCREENSHOT_PATH := (
	"res://.runtime_appdata/solicitation_pulse_render.png"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(960, 540)
	var stage := Node3D.new()
	root.add_child(stage)
	_add_environment(stage)
	_add_city_surfaces(stage)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 5.7, 10.5)
	camera.look_at_from_position(
		camera.position,
		Vector3(0.0, 0.9, 0.0)
	)
	camera.current = true
	stage.add_child(camera)
	_add_pulse(camera)

	for _frame in 24:
		await process_frame
	var image := root.get_texture().get_image()
	assert(image != null and not image.is_empty())
	assert(image.save_png(SCREENSHOT_PATH) == OK)
	print("SOLICITATION_PULSE_RENDER_TEST_PASS")
	quit(0)


func _add_environment(stage: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.008, 0.012, 0.025)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.10, 0.16, 0.27)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.2
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.0
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
	light.light_color = Color(0.62, 0.73, 1.0)
	light.light_energy = 1.15
	stage.add_child(light)


func _add_city_surfaces(stage: Node3D) -> void:
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.035, 0.045, 0.07)
	ground_material.metallic = 0.32
	ground_material.roughness = 0.52
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(24.0, 24.0)
	ground.mesh = ground_mesh
	ground.material_override = ground_material
	stage.add_child(ground)

	var building_material := StandardMaterial3D.new()
	building_material.albedo_color = Color(0.055, 0.075, 0.12)
	building_material.metallic = 0.18
	building_material.roughness = 0.38
	var placements := [
		[Vector3(-4.7, 1.4, -0.8), Vector3(1.8, 2.8, 2.0)],
		[Vector3(4.6, 1.0, 0.7), Vector3(1.5, 2.0, 2.4)],
		[Vector3(-2.2, 0.7, 4.3), Vector3(1.0, 1.4, 1.0)],
		[Vector3(2.4, 1.1, -4.1), Vector3(1.4, 2.2, 1.2)],
	]
	for placement in placements:
		var building := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = placement[1]
		building.mesh = box
		building.position = placement[0]
		building.material_override = building_material
		stage.add_child(building)


func _add_pulse(camera: Camera3D) -> void:
	var material := ShaderMaterial.new()
	material.shader = PulseShader
	material.set_shader_parameter("start_point", Transform3D.IDENTITY)
	material.set_shader_parameter("radius", 5.15)
	material.set_shader_parameter("max_radius", 8.0)
	material.set_shader_parameter("pulse_width", 0.72)
	material.set_shader_parameter("pulse_energy", 0.62)
	material.set_shader_parameter("pulse_opacity", 1.0)

	var pulse := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.material = material
	quad.flip_faces = true
	quad.size = Vector2(2.0, 2.0)
	pulse.mesh = quad
	pulse.position = Vector3(0.0, 0.0, -1.0)
	pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pulse.extra_cull_margin = 16384.0
	camera.add_child(pulse)
