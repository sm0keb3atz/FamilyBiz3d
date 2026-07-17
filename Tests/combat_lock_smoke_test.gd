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
	target_lock.set_process(false)
	assert(not target_lock.cycle_locked_target(1))
	target_lock.call("_set_locked_target", npc)
	assert(target_lock.get_locked_target() == npc)
	assert(target_lock.get_outline_mesh_count() > 0)
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
