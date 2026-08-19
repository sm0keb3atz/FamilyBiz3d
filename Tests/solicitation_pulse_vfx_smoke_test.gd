extends SceneTree

const PulseShader := preload(
	"res://Assets/VFX/Shaders/solicitation_scanner_pulse.gdshader"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player_scene := load("res://Scenes/Player.tscn") as PackedScene
	assert(player_scene != null)
	var player := player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame

	var solicitation := player.get_node(
		"Components/SolicitationComponent"
	) as PlayerSolicitationComponent
	var pulse_mesh := player.get_node(
		"CameraPivot/SpringArm3D/Camera3D/SolicitationPulse"
	) as MeshInstance3D
	assert(solicitation != null)
	assert(pulse_mesh != null)
	assert(not pulse_mesh.visible)
	assert(is_equal_approx(pulse_mesh.position.z, -1.0))

	solicitation.call("_play_pulse")
	assert(pulse_mesh.visible)
	var material := pulse_mesh.get_active_material(0) as ShaderMaterial
	assert(material != null)
	assert(material.shader == PulseShader)
	assert(is_equal_approx(
		float(material.get_shader_parameter("max_radius")),
		solicitation.solicitation_radius
	))
	assert(float(material.get_shader_parameter("core_intensity")) < 1.0)
	assert(float(material.get_shader_parameter("echo_strength")) > 0.0)
	assert(float(material.get_shader_parameter("texture_strength")) > 0.0)
	assert("float wake" in PulseShader.code)
	assert("float echo" in PulseShader.code)
	assert("ALBEDO = energy_color * 0.65" in PulseShader.code)
	assert("EMISSION = energy_color * 0.08" in PulseShader.code)

	solicitation.call("_hide_pulse")
	assert(not pulse_mesh.visible)
	print("SOLICITATION_PULSE_VFX_SMOKE_TEST_PASS")
	quit(0)
