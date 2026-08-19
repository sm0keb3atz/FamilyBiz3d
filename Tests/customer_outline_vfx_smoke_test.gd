extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var customer_scene := load("res://Scenes/NPC/CustomerNPC.tscn") as PackedScene
	assert(customer_scene != null)
	var customer := customer_scene.instantiate() as CustomerNPC
	root.add_child(customer)
	await process_frame

	customer.call("_apply_solicitation_outline")
	assert(customer.get_solicitation_outline_mesh_count() > 0)
	var halo := customer._solicitation_outline_material as ShaderMaterial
	var glow := customer._solicitation_outline_glow_material as ShaderMaterial
	var core := customer._solicitation_outline_core_material as ShaderMaterial
	assert(halo != null)
	assert(glow != null)
	assert(core != null)
	assert(halo.next_pass == glow)
	assert(glow.next_pass == core)
	assert(float(halo.get_shader_parameter("outline_energy")) < 0.5)
	assert(float(glow.get_shader_parameter("outline_energy")) < 1.1)
	assert(float(core.get_shader_parameter("outline_energy")) <= 1.5)
	assert(float(core.get_shader_parameter("thickness")) > 3.5)
	assert(halo.shader != core.shader)
	assert(is_equal_approx(
		float(halo.get_shader_parameter("merge_depth_range")),
		0.28
	))

	customer.apply_customer_level_style(2)
	var expected_color := Vector3(0.02, 0.32, 1.0)
	assert(halo.get_shader_parameter("outline_color") == expected_color)
	assert(glow.get_shader_parameter("outline_color") == expected_color)
	assert(core.get_shader_parameter("outline_color") == expected_color)

	customer.call("_clear_solicitation_outline")
	assert(customer.get_solicitation_outline_mesh_count() == 0)
	assert(is_zero_approx(float(
		halo.get_shader_parameter("outline_transparency")
	)))
	assert(is_zero_approx(float(
		glow.get_shader_parameter("outline_transparency")
	)))
	assert(is_zero_approx(float(
		core.get_shader_parameter("outline_transparency")
	)))
	print("CUSTOMER_OUTLINE_VFX_SMOKE_TEST_PASS")
	quit(0)
