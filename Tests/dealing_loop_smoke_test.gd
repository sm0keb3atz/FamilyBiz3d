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
	assert(is_equal_approx(stats.get_hustle_sale_multiplier(), 1.70))
	assert(is_equal_approx(stats.get_hustle_experience_multiplier(), 1.0))
	assert(stats.get_hustle_customer_limit() == 2)
	for expected_hustle in range(2, 11):
		assert(stats.purchase_hustle())
		assert(stats.hustle == expected_hustle)
	assert(not stats.purchase_hustle())
	assert(stats.get_hustle_customer_limit() == 6)
	assert(is_equal_approx(stats.get_hustle_sale_multiplier(), 3.05))
	assert(is_equal_approx(stats.get_hustle_experience_multiplier(), 2.35))
	var stats_save := stats.export_save_data()
	stats.import_save_data(stats_save)
	assert(stats.hustle == 10)

	# Better customers unlock gradually with Hustle instead of flooding new saves.
	assert(CivilianRoleComponent.get_level_weights(1) == [88, 11, 1, 0])
	assert(CivilianRoleComponent.get_level_weights(5) == [65, 24, 10, 1])
	assert(CivilianRoleComponent.get_level_weights(10) == [38, 31, 23, 8])
	stats.import_save_data({"hustle": 1})
	assert(solicitation.get_customer_inventory_cap(10) == 5)
	assert(solicitation.get_customer_inventory_cap(2) == 1)
	assert(solicitation.get_customer_inventory_cap(1) == 1)
	stats.import_save_data({"hustle": 10})
	assert(solicitation.get_customer_inventory_cap(10) == 8)

	# Customer level controls quantity only; any gram product can be assigned.
	var customers := get_nodes_in_group("customer_npc")
	for _frame in range(60):
		if not customers.is_empty():
			break
		await physics_frame
		customers = get_nodes_in_group("customer_npc")
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
	var market := world.get_node(
		"TerritoryMarketService"
	) as TerritoryMarketService
	var expected_sale := roundi(
		market.get_buy_quote(east.territory_id, EconomyCatalog.WEED_1G)
		* 2.0
		* stats.get_hustle_sale_multiplier()
	)
	assert(result.dirty_cash_delta == expected_sale)
	assert(wallet.dirty_cash == cash_before + expected_sale)
	assert(is_equal_approx(stats.experience - experience_before, 23.5))
	assert(is_equal_approx(east.stats.reputation - reputation_before, 0.3))
	assert(is_equal_approx(east.stats.heat - heat_before, 2.0))
	var failed_cash := wallet.dirty_cash
	var failed_heat := east.stats.heat
	assert(not trade.sell_product(EconomyCatalog.WEED_1G, Vector3(64, 0, 0), 1).success)
	assert(wallet.dirty_cash == failed_cash)
	assert(is_equal_approx(east.stats.heat, failed_heat))

	# Every territory has deterministic L2/L3/L4 progression suppliers.
	var east_zone := world.get_node(
		"SpawnPoints/EastDealerZoneNorth"
	) as DealerActivityZone3D
	var progression_levels: Array[int] = []
	for spawned_dealer in east_zone.get_spawned_dealers():
		progression_levels.append(
			spawned_dealer.get_role_component().dealer_level
		)
	progression_levels.sort()
	assert(progression_levels == [2, 3, 4])
	var level_two: DealerNPC
	var level_three: DealerNPC
	for progression_dealer in east_zone.get_spawned_dealers():
		var progression_level := progression_dealer.get_role_component().dealer_level
		if progression_level == 2:
			level_two = progression_dealer
		elif progression_level == 3:
			level_three = progression_dealer
	assert(level_two != null and level_three != null)
	assert(level_two.get_interaction_prompt(player).contains("15"))
	assert(level_three.get_interaction_prompt(player).contains("40"))
	var level_two_weed := level_two.get_stock_quantity(EconomyCatalog.WEED_1G)
	var level_two_coke := level_two.get_stock_quantity(EconomyCatalog.COKE_1G)
	assert(level_two_weed >= 60 and level_two_weed <= 80)
	assert(level_two_coke >= 8 and level_two_coke <= 15)
	assert(level_two.get_stock_quantity(EconomyCatalog.FENT_1G) == 0)
	var level_three_coke := level_three.get_stock_quantity(EconomyCatalog.COKE_1G)
	var level_three_fent := level_three.get_stock_quantity(EconomyCatalog.FENT_1G)
	assert(level_three.get_stock_quantity(EconomyCatalog.WEED_1G) == 0)
	assert(level_three_coke >= 60 and level_three_coke <= 80)
	assert(level_three_fent >= 8 and level_three_fent <= 15)
	assert(east.stats.add_reputation(15.0 - east.stats.reputation))
	assert(level_two.get_interaction_prompt(player) == "E - Shop")
	assert(level_three.get_interaction_prompt(player).contains("40"))

	var level_one := world.get_node("Gameplay/EastDealer") as DealerNPC
	level_one.configure_dealer(1, false)
	var level_one_stock := level_one.get_stock_quantity(EconomyCatalog.WEED_1G)
	assert(level_one_stock >= 40 and level_one_stock <= 50)

	# Legacy dealer stock rerolls once, then the upgraded stock remains stable.
	var legacy_stock := level_two.export_save_data()
	legacy_stock.erase("stock_data_version")
	var legacy_quantities := legacy_stock["stock"] as Dictionary
	for product_id in legacy_quantities.keys():
		legacy_quantities[product_id] = 1
	level_two.import_save_data(legacy_stock)
	assert(level_two.get_stock_quantity(EconomyCatalog.WEED_1G) >= 60)
	assert(level_two.get_stock_quantity(EconomyCatalog.COKE_1G) >= 8)
	var upgraded_stock := level_two.export_save_data()
	assert(
		int(upgraded_stock["stock_data_version"])
		== DealerRoleComponent.STOCK_DATA_VERSION
	)
	var preserved_weed := level_two.get_stock_quantity(EconomyCatalog.WEED_1G)
	var preserved_coke := level_two.get_stock_quantity(EconomyCatalog.COKE_1G)
	level_two.import_save_data(upgraded_stock)
	assert(level_two.get_stock_quantity(EconomyCatalog.WEED_1G) == preserved_weed)
	assert(level_two.get_stock_quantity(EconomyCatalog.COKE_1G) == preserved_coke)
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
