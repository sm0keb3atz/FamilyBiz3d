extends SceneTree

const SkyShader := preload("res://Assets/VFX/Shaders/customizable_sky.gdshader")
const OutlineShader := preload(
	"res://Assets/VFX/Shaders/target_lock_outline.gdshader"
)
const SCREENSHOT_PATH := "res://.runtime_appdata/cinematic_visual_render.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(960, 540)
	var stage := Node3D.new()
	root.add_child(stage)

	var sky_material := ShaderMaterial.new()
	sky_material.shader = SkyShader
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.32, 0.39, 0.52)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.16
	environment.glow_hdr_threshold = 1.2
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	stage.add_child(sun)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(128.0, 28.0, 0.0)
	moon.light_energy = 0.16
	stage.add_child(moon)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.5, 6.5)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.25, 0.0))
	camera.current = true
	stage.add_child(camera)

	var base_material := StandardMaterial3D.new()
	base_material.albedo_color = Color(0.11, 0.14, 0.20)
	base_material.metallic = 0.15
	base_material.roughness = 0.42
	var outline_material := ShaderMaterial.new()
	outline_material.shader = OutlineShader
	outline_material.set_shader_parameter("thickness", 3.0)
	outline_material.set_shader_parameter("outline_energy", 2.2)

	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.62
	torso_mesh.height = 1.75
	torso.mesh = torso_mesh
	torso.position = Vector3(0.0, 1.35, 0.0)
	torso.material_override = base_material
	torso.material_overlay = outline_material
	stage.add_child(torso)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.45
	head_mesh.height = 0.9
	head.mesh = head_mesh
	head.position = Vector3(0.0, 2.45, 0.0)
	head.material_override = base_material
	head.material_overlay = outline_material
	stage.add_child(head)

	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(16.0, 16.0)
	ground.mesh = ground_mesh
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.055, 0.06, 0.075)
	ground_material.roughness = 0.72
	ground.material_override = ground_material
	stage.add_child(ground)

	for _frame in 16:
		await process_frame
	var image := root.get_texture().get_image()
	assert(image != null and not image.is_empty())
	assert(image.save_png(SCREENSHOT_PATH) == OK)
	print("CINEMATIC_VISUAL_RENDER_TEST_PASS")
	quit(0)
