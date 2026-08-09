extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (
		load("res://Scenes/Maps/World/world.tscn") as PackedScene
	).instantiate()
	root.add_child(world)
	world.get_node("CivilianPopulationManager").set_population_enabled(false)
	await process_frame
	await process_frame

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var properties := player.get_node(
		"Components/PropertyComponent"
	) as PlayerPropertyComponent
	var wallet := player.get_node(
		"Components/WalletComponent"
	) as PlayerWalletComponent
	var inventory := player.get_node(
		"Components/InventoryComponent"
	) as PlayerInventoryComponent
	var stats := player.get_node(
		"Components/StatsComponent"
	) as PlayerStatsComponent
	# This fixture stages a full 1,000-unit stash through carried inventory.
	stats.import_save_data({"strength": 100})
	var world_time := world.get_node(
		"WorldTimeComponent"
	) as WorldTimeComponent
	var property_id := &"hood_east_house_1"
	var definition := PropertyCatalog.get_by_id(property_id)

	assert(definition.dealer_capacity == 2)
	assert(definition.brick_station_cost == 5000)
	assert(definition.brick_station_interval_minutes == 180)
	assert(wallet.add_clean(15000, false))
	assert(properties.purchase(property_id))
	var dirty_before := wallet.dirty_cash
	assert(properties.purchase_brick_station(
		property_id,
		world_time.get_absolute_minute()
	))
	assert(wallet.clean_cash == 0)
	assert(wallet.dirty_cash == dirty_before)
	var state := properties.get_brick_station_state(property_id)
	assert(bool(state.installed))
	assert(StringName(state.selected_product_id).is_empty())

	assert(properties.set_brick_station_product(
		property_id,
		EconomyCatalog.WEED_BRICK.product_id,
		world_time.get_absolute_minute()
	))
	state = properties.get_brick_station_state(property_id)
	var first_cycle := int(state.next_process_minute)
	assert(first_cycle == (
		world_time.get_absolute_minute()
		+ definition.brick_station_interval_minutes
	))
	assert(inventory.add_product(EconomyCatalog.WEED_BRICK, 1))
	assert(properties.transfer_product(
		property_id,
		EconomyCatalog.WEED_BRICK,
		1,
		true
	) == 1)
	properties.process_brick_stations_to(first_cycle - 1)
	assert(properties.get_stashed_product_quantity(
		property_id,
		EconomyCatalog.WEED_BRICK
	) == 1)
	properties.process_brick_stations_to(first_cycle)
	assert(properties.get_stashed_product_quantity(
		property_id,
		EconomyCatalog.WEED_BRICK
	) == 0)
	assert(properties.get_stashed_product_quantity(
		property_id,
		EconomyCatalog.WEED_1G
	) == EconomyCatalog.WEED_BRICK.breakdown_amount)

	state = properties.get_brick_station_state(property_id)
	var preserved_deadline := int(state.next_process_minute)
	assert(properties.set_brick_station_product(
		property_id,
		EconomyCatalog.COKE_BRICK.product_id,
		world_time.get_absolute_minute()
	))
	assert(int(properties.get_brick_station_state(
		property_id
	).next_process_minute) == preserved_deadline)

	assert(properties.transfer_product(
		property_id,
		EconomyCatalog.WEED_1G,
		1,
		false
	) == 1)
	assert(inventory.add_product(EconomyCatalog.COKE_BRICK, 1))
	assert(properties.transfer_product(
		property_id,
		EconomyCatalog.COKE_BRICK,
		1,
		true
	) == 1)
	assert(inventory.add_product(EconomyCatalog.WEED_1G, 900))
	assert(properties.transfer_product(
		property_id,
		EconomyCatalog.WEED_1G,
		900,
		true
	) == 900)
	assert(properties.get_stash_remaining_capacity(property_id) == 0)
	properties.process_brick_stations_to(preserved_deadline)
	state = properties.get_brick_station_state(property_id)
	assert(String(state.last_block_reason).contains("FREE CAPACITY"))
	assert(properties.get_stashed_product_quantity(
		property_id,
		EconomyCatalog.COKE_BRICK
	) == 1)
	assert(properties.get_stashed_product_quantity(
		property_id,
		EconomyCatalog.COKE_1G
	) == 0)

	var saved := properties.export_save_data()
	properties.import_save_data(saved)
	state = properties.get_brick_station_state(property_id)
	assert(bool(state.installed))
	assert(StringName(state.selected_product_id) == (
		EconomyCatalog.COKE_BRICK.product_id
	))
	assert(String(state.last_block_reason).contains("FREE CAPACITY"))

	var stash_menu := player.get_node(
		"PropertyStashMenu"
	) as PropertyStashMenu
	stash_menu.open_stash(property_id)
	stash_menu.call("_set_tab", &"operations")
	assert(stash_menu.find_child(
		"BrickStationProduct",
		true,
		false
	) != null)
	stash_menu.close()

	print("PROPERTY_BRICK_STATION_SMOKE_TEST_PASS")
	quit(0)
