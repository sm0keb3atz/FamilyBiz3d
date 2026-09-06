extends SceneTree

const SkyShader := preload("res://Assets/VFX/Shaders/customizable_sky.gdshader")
const OutlineShader := preload(
	"res://Assets/VFX/Shaders/target_lock_outline.gdshader"
)
const SurfaceShader := preload(
	"res://Assets/VFX/Shaders/world_surface_detail.gdshader"
)
const PuddleShader := preload(
	"res://Assets/VFX/Shaders/rain_puddle_overlay.gdshader"
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

	var wet_ground := MeshInstance3D.new()
	var wet_ground_mesh := PlaneMesh.new()
	wet_ground_mesh.size = Vector2(6.0, 7.0)
	wet_ground.mesh = wet_ground_mesh
	wet_ground.position = Vector3(3.0, 0.012, 0.0)
	var wet_material := ShaderMaterial.new()
	wet_material.shader = SurfaceShader
	wet_material.set_shader_parameter("albedo_color", Color(0.075, 0.08, 0.09))
	wet_material.set_shader_parameter("surface_tint", Color.WHITE)
	wet_material.set_shader_parameter("roughness", 0.72)
	wet_material.set_shader_parameter("wetness", 1.0)
	wet_material.set_shader_parameter("wet_response", 1.0)
	wet_material.set_shader_parameter("wet_darkening", 0.17)
	wet_material.set_shader_parameter("wet_roughness", 0.30)
	wet_material.set_shader_parameter("planar_normal_stabilization", 1.0)
	wet_ground.material_override = wet_material
	stage.add_child(wet_ground)

	var puddle_overlay := MeshInstance3D.new()
	var puddle_overlay_mesh := PlaneMesh.new()
	puddle_overlay_mesh.size = Vector2(4.4, 2.7)
	puddle_overlay.mesh = puddle_overlay_mesh
	puddle_overlay.position = Vector3(3.0, 0.032, 0.15)
	puddle_overlay.rotation.y = 0.32
	var puddle_material := ShaderMaterial.new()
	puddle_material.shader = PuddleShader
	puddle_material.set_shader_parameter("wetness", 1.0)
	puddle_material.set_shader_parameter("rain_activity", 0.75)
	puddle_material.set_shader_parameter("puddle_opacity", 0.34)
	puddle_material.set_shader_parameter("puddle_roughness", 0.14)
	puddle_material.set_shader_parameter("edge_softness", 0.12)
	puddle_overlay.material_override = puddle_material
	stage.add_child(puddle_overlay)

	var wet_wall := MeshInstance3D.new()
	var wet_wall_mesh := BoxMesh.new()
	wet_wall_mesh.size = Vector3(6.0, 4.0, 0.25)
	wet_wall.mesh = wet_wall_mesh
	wet_wall.position = Vector3(3.0, 2.0, -3.5)
	var wet_wall_material := wet_material.duplicate() as ShaderMaterial
	wet_wall_material.set_shader_parameter(
		"albedo_color",
		Color(0.24, 0.12, 0.075)
	)
	wet_wall_material.set_shader_parameter("wet_response", 0.75)
	wet_wall_material.set_shader_parameter("wet_darkening", 0.10)
	wet_wall_material.set_shader_parameter("wet_roughness", 0.24)
	wet_wall_material.set_shader_parameter("planar_normal_stabilization", 0.15)
	wet_wall.material_override = wet_wall_material
	stage.add_child(wet_wall)

	var street_light := OmniLight3D.new()
	street_light.position = Vector3(3.0, 3.2, 0.4)
	street_light.light_color = Color(1.0, 0.67, 0.34)
	street_light.light_energy = 4.0
	street_light.omni_range = 8.0
	stage.add_child(street_light)

	var foreground := MeshInstance3D.new()
	var foreground_mesh := BoxMesh.new()
	foreground_mesh.size = Vector3(1.2, 2.2, 1.0)
	foreground.mesh = foreground_mesh
	foreground.position = Vector3(-2.7, 1.1, 2.2)
	var foreground_material := StandardMaterial3D.new()
	foreground_material.albedo_color = Color(0.018, 0.022, 0.03)
	foreground_material.roughness = 0.82
	foreground.material_override = foreground_material
	stage.add_child(foreground)

	for _frame in 16:
		await process_frame
	var image := root.get_texture().get_image()
	assert(image != null and not image.is_empty())
	assert(image.save_png(SCREENSHOT_PATH) == OK)
	print("CINEMATIC_VISUAL_RENDER_TEST_PASS")
	quit(0)
