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
	var west_manager := world.get_node(
		"WestPopulationManager"
	) as CivilianPopulationManager
	manager.set_population_enabled(false)
	west_manager.set_population_enabled(false)
	manager.minimum_spawn_distance = 0.0
	manager.maximum_spawn_distance = 500.0
	manager.high_detail_distance = 500.0
	manager.active_target = 3
	assert(manager.populate_immediately(3) == 3)
	await process_frame
	await physics_frame

	var customers := manager.get_active_customers()
	assert(customers.size() == 3)
	for customer in customers:
		customer.activity_attempt_chance = 0.0
		customer.return_timeout = 0.05

	var spot := ActivitySpot3D.new()
	spot.name = "ActivitySpotTest"
	spot.allowed_roles = PackedStringArray(["civilian"])
	world.add_child(spot)
	spot.global_position = customers[0].global_position

	assert(spot.try_reserve(customers[0]) == 0)
	assert(spot.try_reserve(customers[1]) == -1)
	assert(spot.get_reserved_count() == 1)
	spot.release(customers[0])
	assert(spot.get_reserved_count() == 0)
	spot.allowed_roles = PackedStringArray(["police"])
	assert(spot.try_reserve(customers[0]) == -1)
	spot.allowed_roles = PackedStringArray(["civilian"])
	spot.capacity = 2
	assert(spot.try_reserve(customers[0]) == 0)
	assert(spot.try_reserve(customers[1]) == 1)
	assert(spot.get_reserved_count() == 2)
	spot.release(customers[0])
	spot.release(customers[1])

	spot.capacity = 1
	spot.animation_name = &"MissingActivityAnimation"
	spot.minimum_duration = 0.05
	spot.maximum_duration = 0.05
	spot.global_position = customers[0].global_position
	assert(customers[0].try_begin_activity(spot))
	assert(customers[0].get_state_name() == "TRAVELING_TO_ACTIVITY")
	for _frame in range(3):
		await physics_frame
	assert(customers[0].is_performing_activity())
	assert(not customers[0].animation_tree.active)
	var activity_player := customers[0].get_node(
		"Visual/PlayerTest2/ActivityAnimationPlayer"
	) as AnimationPlayer
	assert(activity_player.current_animation == &"Idle")
	for _frame in range(12):
		await physics_frame
	assert(spot.get_reserved_count() == 0)
	assert(customers[0].get_state_name() == "ROAMING")
	assert(customers[0].animation_tree.active)

	spot.animation_name = &"Talking"
	spot.global_position = customers[1].global_position
	assert(customers[1].try_begin_activity(spot))
	customers[1].hear_gunshot(
		customers[1].global_position + Vector3.RIGHT,
		45.0
	)
	assert(customers[1].get_state_name() == "PANICKING")
	assert(spot.get_reserved_count() == 0)

	spot.global_position = customers[2].global_position
	assert(customers[2].try_begin_activity(spot))
	customers[2].damageable.apply_damage(
		1.0,
		customers[0],
		customers[2].global_position + Vector3.UP,
		Vector3.FORWARD
	)
	assert(spot.get_reserved_count() == 0)
	assert(customers[2].get_state_name() == "RETURNING")

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var inventory := player.get_node(
		"Components/InventoryComponent"
	) as PlayerInventoryComponent
	var solicitation_customer := (
		load("res://Scenes/NPC/CustomerNPC.tscn") as PackedScene
	).instantiate() as CustomerNPC
	world.add_child(solicitation_customer)
	await process_frame
	spot.global_position = solicitation_customer.global_position
	assert(solicitation_customer.try_begin_activity(spot))
	inventory.add_product(
		solicitation_customer.product_wanted,
		solicitation_customer.amount_wanted
	)
	assert(solicitation_customer.respond_to_solicitation(player))
	assert(solicitation_customer.get_state_name() == "APPROACHING")
	assert(spot.get_reserved_count() == 0)

	for _frame in range(8):
		await physics_frame
	spot.global_position = customers[0].global_position
	assert(customers[0].try_begin_activity(spot))
	customers[0].prepare_for_pool_recycle()
	assert(spot.get_reserved_count() == 0)

	var temporary := (
		load("res://Scenes/NPC/CustomerNPC.tscn") as PackedScene
	).instantiate() as CustomerNPC
	world.add_child(temporary)
	await process_frame
	assert(spot.try_reserve(temporary) == 0)
	temporary.queue_free()
	await process_frame
	assert(spot.get_reserved_count() == 0)

	var death_customer := (
		load("res://Scenes/NPC/CustomerNPC.tscn") as PackedScene
	).instantiate() as CustomerNPC
	world.add_child(death_customer)
	await process_frame
	spot.global_position = death_customer.global_position
	assert(death_customer.try_begin_activity(spot))
	death_customer.damageable.apply_damage(
		death_customer.damageable.maximum_health,
		customers[1],
		death_customer.global_position + Vector3.UP,
		Vector3.FORWARD
	)
	assert(death_customer.is_defeated())
	assert(spot.get_reserved_count() == 0)

	print("NPC_ACTIVITY_SPOT_SMOKE_TEST_PASS")
	quit(0)
