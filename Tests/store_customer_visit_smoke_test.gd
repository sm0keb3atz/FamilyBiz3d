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
	var east_manager := world.get_node(
		"CivilianPopulationManager"
	) as CivilianPopulationManager
	var west_manager := world.get_node(
		"WestPopulationManager"
	) as CivilianPopulationManager
	east_manager.set_population_enabled(false)
	west_manager.set_population_enabled(false)
	await process_frame
	await physics_frame

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var wallet := player.get_node(
		"Components/WalletComponent"
	) as PlayerWalletComponent
	var properties := player.get_node(
		"Components/PropertyComponent"
	) as PlayerPropertyComponent
	var world_time := world.get_node(
		"WorldTimeComponent"
	) as WorldTimeComponent
	var clothing_visit := _get_visit(PropertyCatalog.CLOTHING_STORE_ID)
	var gun_visit := _get_visit(PropertyCatalog.GUN_STORE_ID)
	assert(clothing_visit != null)
	assert(gun_visit != null)
	assert(clothing_visit.get_destinations().size() == 4)
	assert(gun_visit.get_destinations().size() == 4)

	player.global_position = clothing_visit.global_position
	properties.business_sale_processed.emit(
		PropertyCatalog.CLOTHING_STORE_ID,
		world_time.get_absolute_minute()
	)
	assert(not clothing_visit.has_pending_ticket())
	assert(wallet.add_clean(100000, false))
	assert(wallet.add_dirty(10000, false))
	assert(properties.purchase(
		PropertyCatalog.CLOTHING_STORE_ID,
		world_time.get_absolute_minute()
	))
	assert(properties.purchase(
		PropertyCatalog.GUN_STORE_ID,
		world_time.get_absolute_minute()
	))
	properties.business_sale_processed.emit(
		PropertyCatalog.CLOTHING_STORE_ID,
		world_time.get_absolute_minute()
	)
	assert(not clothing_visit.has_pending_ticket())
	assert(world_time.set_time_of_day(10, 0))
	properties.business_sale_processed.emit(
		PropertyCatalog.CLOTHING_STORE_ID,
		world_time.get_absolute_minute()
	)
	assert(not clothing_visit.has_pending_ticket())
	assert(properties.restock_business(PropertyCatalog.CLOTHING_STORE_ID, 3))
	assert(properties.restock_business(PropertyCatalog.GUN_STORE_ID, 3))

	east_manager.minimum_spawn_distance = 0.0
	east_manager.maximum_spawn_distance = 500.0
	east_manager.high_detail_distance = 500.0
	east_manager.active_target = 2
	assert(east_manager.populate_immediately(2) == 2)
	await process_frame
	await physics_frame
	var customers := east_manager.get_active_customers()
	assert(customers.size() == 2)
	var network := world.get_node(
		"Navigation/HoodEastPedestrianNetwork"
	) as PedestrianNetwork3D
	var clothing_side_waypoint := network.get_node(
		"SouthSouth2"
	) as PedestrianWaypoint3D
	for customer in customers:
		customer.activity_attempt_chance = 0.0
		customer.return_timeout = 0.05
		customer.store_visit_travel_timeout = 2.0
		customer.assign_route(network, clothing_side_waypoint)
	for destination in clothing_visit.get_destinations():
		destination.minimum_duration = 0.02
		destination.maximum_duration = 0.02
	clothing_visit.get_destination(1).animation_name = &"MissingStoreAnimation"
	customers[0].global_position = clothing_visit.entrance.global_position
	customers[1].global_position = (
		clothing_visit.entrance.global_position + Vector3.RIGHT
	)

	assert(world_time.set_time_of_day(9, 59))
	world_time.advance_minutes(1)
	await process_frame
	await physics_frame
	var visitor := clothing_visit.get_active_visitor()
	assert(visitor != null)
	assert(visitor.is_visiting_store())
	assert(clothing_visit.get_reserved_destination_count() == 4)
	var other := customers[1] if visitor == customers[0] else customers[0]
	assert(not other.try_begin_store_visit(clothing_visit))
	assert(properties.get_business_stock(PropertyCatalog.CLOTHING_STORE_ID) == 2)
	assert(
		properties.get_business_accumulated_earnings(
			PropertyCatalog.CLOTHING_STORE_ID
		) == 150
	)

	for expected_stage in range(4):
		assert(visitor.get_store_visit_stage() == expected_stage)
		var destination := clothing_visit.get_destination(expected_stage)
		visitor.global_position = destination.get_slot_position(
			destination.get_reserved_slot(visitor)
		)
		await physics_frame
		await physics_frame
		if expected_stage == 1:
			var activity_player := visitor.get_node(
				"Visual/PlayerTest2/ActivityAnimationPlayer"
			) as AnimationPlayer
			assert(activity_player.current_animation == &"Idle")
		for _frame in range(4):
			await physics_frame
	assert(clothing_visit.get_reserved_destination_count() == 0)
	for _frame in range(8):
		await physics_frame
	assert(visitor.get_state_name() == "ROAMING")

	# Panic, damage, solicitation, pooling, recruitment, death, and removal
	# all unwind the full itinerary through the same release path.
	assert(visitor.try_begin_store_visit(clothing_visit))
	visitor.hear_gunshot(visitor.global_position + Vector3.RIGHT, 45.0)
	assert(clothing_visit.get_reserved_destination_count() == 0)
	var damage_customer := (
		load("res://Scenes/NPC/CustomerNPC.tscn") as PackedScene
	).instantiate() as CustomerNPC
	world.add_child(damage_customer)
	await process_frame
	assert(damage_customer.try_begin_store_visit(clothing_visit))
	damage_customer.damageable.apply_damage(
		1.0,
		other,
		damage_customer.global_position + Vector3.UP,
		Vector3.FORWARD
	)
	assert(clothing_visit.get_reserved_destination_count() == 0)
	var solicitation_customer := (
		load("res://Scenes/NPC/CustomerNPC.tscn") as PackedScene
	).instantiate() as CustomerNPC
	world.add_child(solicitation_customer)
	await process_frame
	assert(solicitation_customer.try_begin_store_visit(clothing_visit))
	solicitation_customer.begin_solicitation(player)
	assert(clothing_visit.get_reserved_destination_count() == 0)
	var pooled_customer := (
		load("res://Scenes/NPC/CustomerNPC.tscn") as PackedScene
	).instantiate() as CustomerNPC
	world.add_child(pooled_customer)
	await process_frame
	assert(pooled_customer.try_begin_store_visit(clothing_visit))
	pooled_customer.prepare_for_pool_recycle()
	assert(clothing_visit.get_reserved_destination_count() == 0)

	var temporary := (
		load("res://Scenes/NPC/CustomerNPC.tscn") as PackedScene
	).instantiate() as CustomerNPC
	world.add_child(temporary)
	await process_frame
	assert(temporary.try_begin_store_visit(clothing_visit))
	var roster := player.get_node(
		"Components/GirlfriendComponent"
	) as PlayerGirlfriendComponent
	roster._entries.append({
		"npc": temporary,
		"name": "Visit Test",
		"level": temporary.get_customer_level(),
		"status": PlayerGirlfriendComponent.STATUS_FOLLOWING,
		"relationship": 0,
		"relationship_elapsed": 0.0,
	})
	temporary.begin_girlfriend_following(player, roster, 0)
	assert(clothing_visit.get_reserved_destination_count() == 0)
	temporary.queue_free()
	await process_frame

	var death_customer := (
		load("res://Scenes/NPC/CustomerNPC.tscn") as PackedScene
	).instantiate() as CustomerNPC
	world.add_child(death_customer)
	await process_frame
	assert(death_customer.try_begin_store_visit(clothing_visit))
	death_customer.damageable.apply_damage(
		death_customer.damageable.maximum_health,
		other,
		death_customer.global_position + Vector3.UP,
		Vector3.FORWARD
	)
	assert(clothing_visit.get_reserved_destination_count() == 0)

	var removed_customer := (
		load("res://Scenes/NPC/CustomerNPC.tscn") as PackedScene
	).instantiate() as CustomerNPC
	world.add_child(removed_customer)
	await process_frame
	assert(removed_customer.try_begin_store_visit(clothing_visit))
	removed_customer.queue_free()
	await process_frame
	assert(clothing_visit.get_reserved_destination_count() == 0)

	# The second store receives the same current-time presentation signal.
	other.assign_route(
		network,
		network.get_node("SouthSouth3") as PedestrianWaypoint3D
	)
	other.global_position = gun_visit.entrance.global_position
	player.global_position = gun_visit.global_position
	assert(world_time.set_time_of_day(11, 59))
	world_time.advance_minutes(1)
	await process_frame
	await physics_frame
	assert(gun_visit.get_active_visitor() == other)
	assert(gun_visit.get_reserved_destination_count() == 4)
	other.cancel_store_visit(true)
	assert(gun_visit.get_reserved_destination_count() == 0)

	# Off-screen and historical processing remains ledger-only.
	player.global_position = Vector3(1000.0, 0.0, 1000.0)
	var stock_before := properties.get_business_stock(
		PropertyCatalog.GUN_STORE_ID
	)
	var earnings_before := properties.get_business_accumulated_earnings(
		PropertyCatalog.GUN_STORE_ID
	)
	assert(world_time.set_time_of_day(13, 59))
	world_time.advance_minutes(1)
	await process_frame
	assert(not gun_visit.has_pending_ticket())
	assert(gun_visit.get_active_visitor() == null)
	assert(
		properties.get_business_stock(PropertyCatalog.GUN_STORE_ID)
		== stock_before - 1
	)
	assert(
		properties.get_business_accumulated_earnings(
			PropertyCatalog.GUN_STORE_ID
		) == earnings_before + 400
	)
	player.global_position = gun_visit.global_position
	properties.process_businesses_to(18 * 60)
	await process_frame
	assert(not gun_visit.has_pending_ticket())
	assert(gun_visit.get_reserved_destination_count() == 0)

	print("STORE_CUSTOMER_VISIT_SMOKE_TEST_PASS")
	quit(0)


func _get_visit(property_id: StringName) -> StoreCustomerVisit3D:
	for node in get_nodes_in_group(&"store_customer_visit"):
		var visit := node as StoreCustomerVisit3D
		if visit != null and visit.property_id == property_id:
			return visit
	return null
