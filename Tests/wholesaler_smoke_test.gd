extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (
		load("res://Scenes/Maps/World/world.tscn") as PackedScene
	).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	await physics_frame

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var wallet := player.get_node(
		"Components/WalletComponent"
	) as PlayerWalletComponent
	var inventory := player.get_node(
		"Components/InventoryComponent"
	) as PlayerInventoryComponent
	var stats := player.get_node(
		"Components/StatsComponent"
	) as PlayerStatsComponent
	var market := world.get_node(
		"TerritoryMarketService"
	) as TerritoryMarketService
	var time := world.get_node(
		"WorldTimeComponent"
	) as WorldTimeComponent
	var east := TerritoryBoundary.find_at_position(
		self,
		Vector3(64, 0, 0)
	)
	var west := TerritoryBoundary.find_at_position(
		self,
		Vector3(64, 0, -256)
	)
	var east_spawn := world.get_node(
		"SpawnPoints/EastWholesalerSpawn"
	) as WholesalerSpawnPoint3D
	var west_spawn := world.get_node(
		"SpawnPoints/WestWholesalerSpawn"
	) as WholesalerSpawnPoint3D
	assert(east != null and west != null)
	assert(east_spawn != null and west_spawn != null)
	assert(east_spawn.get_spawned_wholesaler() == null)
	assert(west_spawn.get_spawned_wholesaler() == null)

	east.stats.set_reputation(100.0)
	var wholesaler := east_spawn.get_spawned_wholesaler()
	assert(wholesaler != null)
	assert(west_spawn.get_spawned_wholesaler() == null)
	assert(get_nodes_in_group(&"wholesaler_npc").size() == 1)
	assert(is_equal_approx(wholesaler.damageable.maximum_health, 500.0))
	assert(wholesaler.get_combat_weapon().weapon_id == &"draco")
	assert(wholesaler.uses_automatic_fire())
	assert(wholesaler.get_minimum_purchase_quantity() == 10)

	var offer_product := east_spawn.get_offer_product()
	var initial_stock := east_spawn.remaining_stock
	assert(offer_product != null and offer_product.is_brick())
	assert(initial_stock >= 50 and initial_stock <= 100)
	var stock_items := wholesaler.get_stock_items()
	assert(stock_items.size() == 1)
	assert(stock_items[0]["product"] == offer_product)
	assert(int(stock_items[0]["quantity"]) == initial_stock)
	assert(
		int(stock_items[0]["unit_price"])
		== market.get_buy_quote(east.territory_id, offer_product)
	)

	wallet.add_dirty(1000000)
	var cash_before_invalid := wallet.dirty_cash
	var carried_before_invalid := inventory.get_quantity(offer_product)
	assert(
		wholesaler.try_purchase(player, offer_product, 9)
		== "Wholesaler minimum order is 10 bricks."
	)
	assert(wallet.dirty_cash == cash_before_invalid)
	assert(inventory.get_quantity(offer_product) == carried_before_invalid)
	assert(east_spawn.remaining_stock == initial_stock)

	var unit_price := market.get_buy_quote(east.territory_id, offer_product)
	assert(
		wholesaler.try_purchase(player, offer_product, 10).begins_with(
			"Purchased"
		)
	)
	assert(wallet.dirty_cash == cash_before_invalid - unit_price * 10)
	assert(inventory.get_quantity(offer_product) == carried_before_invalid + 10)
	assert(east_spawn.remaining_stock == initial_stock - 10)

	var preserved_stock := east_spawn.remaining_stock
	east.stats.set_reputation(99.0)
	assert(east_spawn.get_spawned_wholesaler() == null)
	east.stats.set_reputation(100.0)
	wholesaler = east_spawn.get_spawned_wholesaler()
	assert(wholesaler != null)
	assert(wholesaler.get_stock_quantity(offer_product) == preserved_stock)
	assert(get_nodes_in_group(&"wholesaler_npc").size() == 1)

	var saved_offer := east_spawn.export_save_data()
	assert(
		wholesaler.try_purchase(
			player,
			offer_product,
			preserved_stock
		).begins_with("Purchased")
	)
	assert(east_spawn.remaining_stock == 0)
	assert(wholesaler.get_cooldown_remaining() == 0.0)
	assert(not wholesaler.try_purchase(
		player,
		offer_product,
		10
	).begins_with("Purchased"))
	east_spawn.import_save_data(saved_offer)
	assert(east_spawn.remaining_stock == preserved_stock)
	assert(
		east_spawn.get_spawned_wholesaler().get_stock_quantity(
			offer_product
		) == preserved_stock
	)

	var previous_date := east_spawn.offer_date
	time.advance_to_next_morning(8)
	assert(east_spawn.offer_date == time.get_date_key())
	assert(east_spawn.offer_date != previous_date)
	assert(east_spawn.remaining_stock >= 50)
	assert(east_spawn.remaining_stock <= 100)
	assert(east_spawn.get_offer_product().is_brick())
	assert(east_spawn.get_spawned_wholesaler() != null)

	assert(time.set_calendar_date(1, 1, 3))
	assert(east_spawn.offer_date == time.get_date_key())
	assert(east_spawn.remaining_stock >= 50)
	assert(east_spawn.remaining_stock <= 100)

	west.stats.set_reputation(100.0)
	assert(west_spawn.get_spawned_wholesaler() != null)
	assert(get_nodes_in_group(&"wholesaler_npc").size() == 2)
	var west_product := west_spawn.get_offer_product()
	var west_items := west_spawn.get_spawned_wholesaler().get_stock_items()
	assert(west_items.size() == 1)
	assert(
		int(west_items[0]["unit_price"])
		== market.get_buy_quote(west.territory_id, west_product)
	)

	wholesaler = east_spawn.get_spawned_wholesaler()
	offer_product = east_spawn.get_offer_product()
	var carried_before_kill := inventory.get_quantity(offer_product)
	var total_experience_before := _get_total_experience(stats)
	var cash_before_loot := wallet.dirty_cash
	wholesaler.damageable.apply_damage(
		wholesaler.damageable.maximum_health,
		player,
		wholesaler.global_position + Vector3.UP
	)
	assert(wholesaler.is_defeated())
	assert(east_spawn.is_defeated_for_current_day())
	assert(east_spawn.get_spawned_wholesaler() == null)
	assert(is_equal_approx(east.stats.reputation, 75.0))
	assert(
		is_equal_approx(
			_get_total_experience(stats) - total_experience_before,
			DealerNPC.WHOLESALER_KILL_EXPERIENCE
		)
	)
	assert(wholesaler.has_corpse_loot())
	wholesaler.collect_corpse_loot(player)
	assert(wallet.dirty_cash == cash_before_loot + 50000)
	assert(inventory.get_quantity(offer_product) == carried_before_kill)
	assert(not wholesaler.has_corpse_loot())

	var defeated_save := east_spawn.export_save_data()
	assert(bool(defeated_save["defeated_today"]))
	east.stats.set_reputation(100.0)
	assert(east_spawn.get_spawned_wholesaler() == null)
	time.advance_to_next_morning(8)
	assert(east_spawn.get_spawned_wholesaler() != null)
	assert(not east_spawn.is_defeated_for_current_day())

	print("WHOLESALER_SMOKE_TEST_PASS")
	quit(0)


func _get_total_experience(stats: PlayerStatsComponent) -> float:
	var total := stats.experience
	for level in range(1, stats.level):
		total += stats.config.experience_per_level * float(level)
	return total
