extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var npc_scene := load("res://Scenes/NPC/BaseNPC.tscn") as PackedScene
	assert(npc_scene != null)
	var npc := npc_scene.instantiate() as BaseNPC
	root.add_child(npc)
	await process_frame
	await physics_frame

	var body_hitbox := npc.get_node(
		"Hitboxes/BodyHitbox"
	) as CombatHitbox
	var head_hitbox := npc.get_node(
		"Hitboxes/HeadHitbox"
	) as CombatHitbox
	assert(body_hitbox != null)
	assert(head_hitbox != null)
	assert(body_hitbox.hit_zone == "body")
	assert(head_hitbox.hit_zone == "head")

	var player_scene := load("res://Scenes/Player.tscn") as PackedScene
	assert(player_scene != null)
	var player := player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame
	await physics_frame

	var target_lock := player.get_node(
		"Components/TargetLockComponent"
	) as PlayerTargetLockComponent
	assert(target_lock != null)
	var camera_component := player.get_node(
		"Components/CameraComponent"
	) as PlayerCameraComponent
	var camera := player.get_node(
		"CameraPivot/SpringArm3D/Camera3D"
	) as Camera3D
	assert(camera_component != null)
	assert(camera.attributes is CameraAttributesPractical)
	var camera_attributes := camera.attributes as CameraAttributesPractical
	assert(camera_attributes.dof_blur_far_enabled)
	assert(is_equal_approx(
		camera_attributes.dof_blur_amount,
		camera_component.default_dof_blur_amount
	))
	var default_blur_amount := camera_attributes.dof_blur_amount
	target_lock.set_process(false)
	assert(not target_lock.cycle_locked_target(1))
	target_lock.call("_set_locked_target", npc)
	assert(target_lock.get_locked_target() == npc)
	assert(target_lock.get_outline_mesh_count() > 0)
	assert(is_equal_approx(
		float(target_lock._outline_material.get_shader_parameter("thickness")),
		7.4
	))
	assert(is_equal_approx(
		float(target_lock._outline_material.get_shader_parameter("depth_bias")),
		0.035
	))
	assert(target_lock._outline_material.next_pass == (
		target_lock._outline_glow_material
	))
	assert(target_lock._outline_glow_material.next_pass == (
		target_lock._outline_core_material
	))
	assert(is_equal_approx(
		float(target_lock._outline_material.get_shader_parameter(
			"merge_depth_range"
		)),
		0.28
	))
	camera_component._update_aim_depth_of_field(0.25, true)
	assert(camera_attributes.dof_blur_far_enabled)
	assert(camera_attributes.dof_blur_amount > default_blur_amount)
	assert(camera_attributes.dof_blur_far_distance > 1.0)
	camera_component._update_aim_depth_of_field(2.0, false)
	assert(absf(
		camera_attributes.dof_blur_amount
		- camera_component.default_dof_blur_amount
	) <= 0.0001)
	assert(camera_attributes.dof_blur_far_enabled)
	target_lock.clear_lock()
	assert(target_lock.get_outline_mesh_count() == 0)

	var starting_health := npc.damageable.health
	assert(body_hitbox.resolve_damage(
		15.0,
		player,
		npc.global_position + Vector3.UP,
		Vector3.FORWARD
	))
	assert(is_equal_approx(npc.damageable.health, starting_health - 15.0))
	assert(not npc.damageable.is_depleted())

	npc.damageable.restore_full_health()
	assert(head_hitbox.resolve_damage(
		15.0,
		player,
		npc.global_position + Vector3.UP * 1.6,
		Vector3.FORWARD
	))
	assert(npc.damageable.is_depleted())
	assert(body_hitbox.collision_layer == 0)
	assert(head_hitbox.collision_layer == 0)

	npc.reset_for_reuse()
	assert(body_hitbox.collision_layer == 4)
	assert(head_hitbox.collision_layer == 4)

	print("COMBAT_LOCK_SMOKE_TEST_PASS")
	quit(0)
