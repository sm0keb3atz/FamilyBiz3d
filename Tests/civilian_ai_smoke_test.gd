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

	var manager := world.get_node(
		"CivilianPopulationManager"
	) as CivilianPopulationManager
	manager.set_population_enabled(false)
	await process_frame
	await physics_frame

	var network := world.get_node(
		"Navigation/HoodEastPedestrianNetwork"
	) as PedestrianNetwork3D
	assert(network != null)
	network.rebuild_cache()
	assert(network.get_waypoint_count() == 32)
	assert(network.get_connection_count() == 34)
	assert(network.get_validation_errors().is_empty())

	manager.minimum_spawn_distance = 0.0
	manager.maximum_spawn_distance = 500.0
	manager.high_detail_distance = 500.0
	manager.active_target = 3
	assert(manager.populate_immediately(3) == 3)
	assert(manager.get_active_count() == 3)
	assert(manager.get_live_pool_count() <= manager.pool_capacity)
	await process_frame
	await physics_frame

	var customers := manager.get_active_customers()
	var customer := customers[0]
	assert(customer.get_state_name() == "ROAMING")
	assert(customer.get_current_waypoint() != null)
	assert(customer.get_route_target() != null)
	assert(customer.is_in_group("customer_npc"))
	assert(customer.is_in_group("interactable"))
	assert(customer.is_in_group("gunshot_listener"))
	assert(customer.collision_layer == 2)
	assert(customer.collision_mask == 1)
	assert(customer.navigation_agent.avoidance_enabled)
	assert(customer.appearance_component != null)
	assert(customer.movement_component is NPCMovementComponent)
	assert(customer.animation_component is NPCAnimationComponent)
	assert(customer.health_component is NPCHealthComponent)
	assert(customer.role_component is CivilianRoleComponent)
	assert(customer.animation_tree.active)
	assert(customer.animation_player.has_animation(&"Idle"))
	assert(customer.animation_player.has_animation(&"Walk"))
	assert(customer.animation_player.has_animation(&"Sprint"))

	var modular_skeleton := customer.get_node(
		"Visual/PlayerTest2/Armature/GeneralSkeleton"
	) as Skeleton3D
	assert(modular_skeleton.get_node("BODY_Head") is MeshInstance3D)
	assert(
		(
			modular_skeleton.get_node("TOP_01_Hoodie") as MeshInstance3D
		).visible
		!= (
			modular_skeleton.get_node("TOP_02_TShirt") as MeshInstance3D
		).visible
	)

	var player := world.get_node(
		"Gameplay/Player"
	) as CharacterBody3D
	customer.panic_minimum_duration = 0.05
	customer.panic_maximum_duration = 0.1
	customer.hear_gunshot(
		customer.global_position + Vector3.RIGHT,
		45.0
	)
	assert(customer.get_state_name() == "PANICKING")
	assert(customer.move_speed == customer.panic_move_speed)
	for _frame in range(8):
		await physics_frame
	assert(customer.get_state_name() == "ROAMING")
	assert(customer.move_speed < customer.panic_move_speed)

	var target_update_count := customer.get_navigation_target_update_count()
	await physics_frame
	await physics_frame
	assert(
		customer.get_navigation_target_update_count()
		<= target_update_count + 1
	)

	player.global_position = customer.global_position + Vector3(0.5, 0.0, 0.0)
	customer.waiting_duration = 0.05
	customer.return_timeout = 0.05
	var saved_route_target := customer.get_route_target()
	assert(customer.respond_to_solicitation(player))
	assert(customer.get_state_name() == "APPROACHING")
	await physics_frame
	assert(customer.get_state_name() == "WAITING")

	var inventory := player.get_node(
		"Components/InventoryComponent"
	) as PlayerInventoryComponent
	inventory.add_product(customer.product_wanted)
	customer.interact(player)
	assert(customer.get_state_name() == "RETURNING")
	for _frame in range(6):
		await physics_frame
	assert(customer.get_state_name() == "ROAMING")
	assert(customer.get_current_waypoint() == saved_route_target)
	assert(customer.get_route_target() != null)

	customer.damageable.apply_damage(
		10.0,
		player,
		customer.global_position + Vector3.UP,
		Vector3.FORWARD
	)
	assert(customer.damageable.health < customer.damageable.maximum_health)
	customer.prepare_for_pool_recycle()
	assert(not customer.is_pool_active())
	assert(not customer.is_in_group("customer_npc"))
	assert(not customer.visible)
	assert(not customer.animation_tree.active)

	var respawn_waypoint := network.get_waypoints()[0]
	customer.prepare_for_pool_spawn(network, respawn_waypoint, 12345)
	assert(customer.is_pool_active())
	assert(customer.damageable.health == customer.damageable.maximum_health)
	assert(customer.get_current_waypoint() == respawn_waypoint)
	assert(customer.is_in_group("customer_npc"))
	assert(customer.animation_tree.active)

	customer.waiting_duration = 0.05
	player.global_position = customer.global_position + Vector3(0.5, 0.0, 0.0)
	assert(customer.respond_to_solicitation(player))
	await physics_frame
	assert(customer.get_state_name() == "WAITING")
	for _frame in range(6):
		await physics_frame
	assert(customer.get_state_name() != "WAITING")

	print("CIVILIAN_AI_SMOKE_TEST_PASS")
	quit(0)
