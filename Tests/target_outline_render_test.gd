extends SceneTree

const OutlineShader := preload(
	"res://Assets/VFX/Shaders/target_lock_outline.gdshader"
)
const OutlineHaloShader := preload(
	"res://Assets/VFX/Shaders/target_lock_outline_halo.gdshader"
)
const SCREENSHOT_PATH := "res://.runtime_appdata/target_outline_deep_red_render.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(960, 540)
	var stage := Node3D.new()
	root.add_child(stage)
	_add_environment(stage)

	var npc_scene := load("res://Scenes/NPC/BaseNPC.tscn") as PackedScene
	assert(npc_scene != null)
	var npc := npc_scene.instantiate() as BaseNPC
	stage.add_child(npc)
	await process_frame
	npc.set_process(false)
	var role_label := npc.get_node_or_null("RoleLabel") as Label3D
	if role_label != null:
		role_label.visible = false

	var halo := _make_outline_layer(
		OutlineHaloShader,
		7.2,
		0.35,
		0.29,
		0.0,
		0.55,
		0.85
	)
	var glow := _make_outline_layer(
		OutlineHaloShader,
		4.83,
		0.79,
		0.55,
		0.02,
		0.72,
		0.90
	)
	var core := _make_outline_layer(
		OutlineShader,
		3.54,
		1.1,
		0.95,
		0.12,
		0.62,
		0.85
	)
	core.set_shader_parameter(
		"outline_color",
		Vector3(0.85, 0.0, 0.0)
	)
	halo.set_shader_parameter(
		"outline_color",
		Vector3(0.85, 0.0, 0.0)
	)
	glow.set_shader_parameter(
		"outline_color",
		Vector3(0.85, 0.0, 0.0)
	)
	halo.next_pass = glow
	glow.next_pass = core
	var outlined_count := 0
	for child in npc.get_node("Visual").find_children(
		"*",
		"MeshInstance3D",
		true,
		false
	):
		var mesh := child as MeshInstance3D
		if mesh != null and mesh.visible:
			mesh.material_overlay = halo
			mesh.extra_cull_margin = maxf(mesh.extra_cull_margin, 0.2)
			outlined_count += 1
	assert(outlined_count > 1)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.45, 5.2)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.15, 0.0))
	camera.fov = 20.0
	camera.current = true
	stage.add_child(camera)

	for _frame in 24:
		await process_frame
	var image := root.get_texture().get_image()
	assert(image != null and not image.is_empty())
	assert(image.save_png(SCREENSHOT_PATH) == OK)
	print("TARGET_OUTLINE_RENDER_TEST_PASS")
	quit(0)


func _make_outline_layer(
	shader: Shader,
	thickness: float,
	energy: float,
	transparency: float,
	rim_start: float,
	rim_end: float,
	rim_power: float
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("outline_color", Vector3(0.02, 1.0, 0.12))
	material.set_shader_parameter("thickness", thickness)
	material.set_shader_parameter("outline_energy", energy)
	material.set_shader_parameter("outline_transparency", transparency)
	material.set_shader_parameter("depth_bias", 0.035)
	material.set_shader_parameter("merge_depth_range", 0.28)
	material.set_shader_parameter("rim_start", rim_start)
	material.set_shader_parameter("rim_end", rim_end)
	material.set_shader_parameter("rim_power", rim_power)
	material.set_shader_parameter("pulse_strength", 0.0)
	return material


func _add_environment(stage: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.52, 0.58, 0.62)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.78, 0.86)
	environment.ambient_light_energy = 0.86
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.02
	environment.tonemap_agx_contrast = 1.26
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.16
	environment.glow_bloom = 0.025
	environment.glow_hdr_threshold = 1.2
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	key.light_color = Color(1.0, 0.88, 0.74)
	key.light_energy = 1.55
	stage.add_child(key)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14.0, 14.0)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.42, 0.43, 0.44)
	ground_material.roughness = 0.78
	ground.material_override = ground_material
	stage.add_child(ground)
