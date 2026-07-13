extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world_scene := load(
		"res://Scenes/Maps/World/world.tscn"
	) as PackedScene
	var world := world_scene.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var stats := player.get_node(
		"Components/StatsComponent"
	) as PlayerStatsComponent
	var inventory := player.get_node(
		"Components/InventoryComponent"
	) as PlayerInventoryComponent
	var wallet := player.get_node(
		"Components/WalletComponent"
	) as PlayerWalletComponent
	var trade := player.get_node(
		"Components/TradeService"
	) as TradeService
	var solicitation := player.get_node(
		"Components/SolicitationComponent"
	) as PlayerSolicitationComponent
	var hud := player.get_node("PlayerHUD") as PlayerHUD
	var east := TerritoryBoundary.find_at_position(
		self,
		Vector3(64, 0, 0)
	)
	assert(east != null)

	# Missing Hustle data from an old save defaults safely to 1.
	stats.import_save_data({"skill_points": 9})
	assert(stats.hustle == 1)
	assert(stats.get_hustle_customer_limit() == 2)
	for expected_hustle in range(2, 11):
		assert(stats.purchase_hustle())
		assert(stats.hustle == expected_hustle)
	assert(not stats.purchase_hustle())
	assert(stats.get_hustle_customer_limit() == 6)
	assert(is_equal_approx(stats.get_hustle_sale_multiplier(), 1.45))
	var stats_save := stats.export_save_data()
	stats.import_save_data(stats_save)
	assert(stats.hustle == 10)

	# Customer level controls quantity only; any gram product can be assigned.
	var customers := get_nodes_in_group("customer_npc")
	assert(not customers.is_empty())
	var customer := customers[0] as CustomerNPC
	var expected_ranges := [
		Vector2i(1, 4),
		Vector2i(5, 10),
		Vector2i(10, 20),
		Vector2i(20, 40),
	]
	for index in range(4):
		customer.role_component.customer_level = index + 1
		assert(customer.get_solicitation_amount_range() == expected_ranges[index])
		customer.assign_solicitation_order(EconomyCatalog.COKE_1G, 1)
		assert(customer.product_wanted == EconomyCatalog.COKE_1G)

	# Active customer orders reserve stock and bricks never enter street demand.
	assert(inventory.add_product(EconomyCatalog.WEED_1G, 10))
	assert(inventory.add_product(EconomyCatalog.WEED_BRICK, 1))
	customer.assign_solicitation_order(EconomyCatalog.WEED_1G, 3)
	customer.begin_solicitation(player)
	var available := solicitation._get_unreserved_inventory()
	assert(available[&"weed_1g"] == 7)
	assert(not available.has(&"weed_brick"))
	assert(
		solicitation._get_largest_available_product(available)
		== EconomyCatalog.WEED_1G
	)

	# Hustle multiplies cash and EXP but not Rep or product Heat.
	assert(inventory.remove_product(EconomyCatalog.WEED_1G, 10))
	assert(inventory.add_product(EconomyCatalog.WEED_1G, 2))
	var cash_before := wallet.dirty_cash
	var experience_before := stats.experience
	var reputation_before := east.stats.reputation
	var heat_before := east.stats.heat
	var result := trade.sell_product(
		EconomyCatalog.WEED_1G,
		Vector3(64, 0, 0),
		2
	)
	assert(result.success)
	assert(result.dirty_cash_delta == 52)
	assert(wallet.dirty_cash == cash_before + 52)
	assert(is_equal_approx(stats.experience - experience_before, 14.5))
	assert(is_equal_approx(east.stats.reputation - reputation_before, 1.2))
	assert(is_equal_approx(east.stats.heat - heat_before, 2.0))
	var failed_cash := wallet.dirty_cash
	var failed_heat := east.stats.heat
	assert(not trade.sell_product(EconomyCatalog.WEED_1G, Vector3(64, 0, 0), 1).success)
	assert(wallet.dirty_cash == failed_cash)
	assert(is_equal_approx(east.stats.heat, failed_heat))

	# Every territory has deterministic L2/L3/L4 progression suppliers.
	var east_spawner := world.get_node(
		"SpawnPoints/EastDealerSpawn"
	) as DealerSpawner
	var progression_levels: Array[int] = []
	for spawned_dealer in east_spawner.get_spawned_dealers():
		progression_levels.append(
			spawned_dealer.get_role_component().dealer_level
		)
	progression_levels.sort()
	assert(progression_levels == [2, 3, 4])
	var level_two := east_spawner.get_spawned_dealers()[0]
	var level_three := east_spawner.get_spawned_dealers()[1]
	assert(level_two.get_interaction_prompt(player).contains("15"))
	assert(level_three.get_interaction_prompt(player).contains("40"))
	assert(east.stats.add_reputation(15.0 - east.stats.reputation))
	assert(level_two.get_interaction_prompt(player) == "E - Shop")
	assert(level_three.get_interaction_prompt(player).contains("40"))

	var level_one := world.get_node("Gameplay/EastDealer") as DealerNPC
	level_one.configure_dealer(1, false)
	var level_one_stock := level_one.get_stock_quantity(EconomyCatalog.WEED_1G)
	assert(level_one_stock >= 25 and level_one_stock <= 35)
	level_one.get_role_component().territory_id = &"hood_east"
	level_one.configure_dealer(1, true)
	assert(level_one.get_role_component().get_required_reputation() == 100.0)
	assert(level_one.get_interaction_prompt(player).contains("100"))

	# Completed transactions drive the HUD effects; non-transaction refreshes do not.
	var audio := hud.get_node("TransactionAudio") as AudioStreamPlayer
	var float_layer := hud.get_node("TransactionFloatLayer") as Control
	assert(audio.stream != null)
	var float_count := float_layer.get_child_count()
	assert(wallet.spend_dirty(1))
	assert(float_layer.get_child_count() > float_count)
	assert(audio.playing)

	print("DEALING_LOOP_SMOKE_TEST_PASS")
	quit(0)
