extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world_scene := load(
		"res://Scenes/Maps/World/world.tscn"
	) as PackedScene
	assert(world_scene != null)
	var world := world_scene.instantiate()
	root.add_child(world)

	var population_manager := world.get_node_or_null(
		"CivilianPopulationManager"
	) as CivilianPopulationManager
	if population_manager != null:
		population_manager.set_population_enabled(false)

	await process_frame
	await physics_frame

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var components := player.get_node("Components")
	var health := components.get_node(
		"HealthComponent"
	) as PlayerHealthComponent
	var respawn := components.get_node(
		"RespawnComponent"
	) as PlayerRespawnComponent
	var movement := components.get_node(
		"MovementComponent"
	) as PlayerMovementComponent
	var collision := player.get_node(
		"CollisionShape3D"
	) as CollisionShape3D
	var police_spawn := world.get_node(
		"SpawnPoints/PoliceStation"
	) as Marker3D

	# Reproduce the state created by fatal police damage: the character is
	# downed, ragdoll movement is stopped, and the main capsule is disabled.
	health.call("_set_state", PlayerHealthComponent.State.DOWNED)
	movement.set_physics_process(false)
	collision.disabled = true
	respawn.set("_sequence_id", 41)
	respawn.call("_complete_arrest_sequence", 41)

	assert(
		health.is_alive(),
		"Police death did not complete the DOWNED -> RESPAWNING -> ALIVE path"
	)
	assert(
		player.global_position.distance_to(police_spawn.global_position) < 0.01,
		"Police death did not use the police-station respawn marker"
	)

	await process_frame
	for _frame in 6:
		await physics_frame

	assert(
		not collision.disabled,
		"Player capsule stayed disabled after a police-death respawn"
	)
	assert(
		movement.is_physics_processing(),
		"Player movement did not resume after collision was restored"
	)
	assert(
		player.global_position.y > -0.2,
		"Player fell through the police-station ground after respawning"
	)
	assert(
		Vector2(
			player.global_position.x,
			player.global_position.z
		).distance_to(Vector2(
			police_spawn.global_position.x,
			police_spawn.global_position.z
		)) < 0.1,
		"Player drifted away from the police-station marker during respawn"
	)

	print("PLAYER_POLICE_RESPAWN_SMOKE_TEST_PASS")
	world.queue_free()
	await process_frame
	quit()
