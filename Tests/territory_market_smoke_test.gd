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

	var east := TerritoryBoundary.find_at_position(self, Vector3(64, 0, 0))
	var west := TerritoryBoundary.find_at_position(self, Vector3(64, 0, -256))
	var market := world.get_node(
		"TerritoryMarketService"
	) as TerritoryMarketService
	var time := world.get_node("WorldTimeComponent") as WorldTimeComponent
	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var wallet := player.get_node(
		"Components/WalletComponent"
	) as PlayerWalletComponent
	var inventory := player.get_node(
		"Components/InventoryComponent"
	) as PlayerInventoryComponent
	var trade := player.get_node(
		"Components/TradeService"
	) as TradeService
	var stats := player.get_node(
		"Components/StatsComponent"
	) as PlayerStatsComponent
	var hud := player.get_node("PlayerHUD") as PlayerHUD
	assert(east != null and west != null and market != null)

	# Pass 1: signed Reputation, thresholds, ownership, migration, and signals.
	var pressure_changes: Array[int] = []
	var takeover_changes: Array[bool] = []
	east.stats.pressure_tier_changed.connect(
		func(tier: TerritoryStatsComponent.RivalPressureTier) -> void:
			pressure_changes.append(int(tier))
	)
	east.stats.takeover_availability_changed.connect(
		func(available: bool) -> void:
			takeover_changes.append(available)
	)
	assert(east.stats.set_reputation(10.0))
	assert(east.stats.add_reputation(-20.0))
	assert(east.stats.reputation == -10.0)
	assert(east.stats.set_reputation(-25.0))
	assert(east.stats.get_pressure_tier() == TerritoryStatsComponent.RivalPressureTier.LOW)
	assert(east.stats.set_reputation(-50.0))
	assert(east.stats.get_pressure_tier() == TerritoryStatsComponent.RivalPressureTier.MEDIUM)
	assert(east.stats.set_reputation(-75.0))
	assert(east.stats.get_pressure_tier() == TerritoryStatsComponent.RivalPressureTier.HIGH)
	assert(east.stats.set_reputation(-500.0))
	assert(east.stats.reputation == -100.0)
	assert(not east.stats.add_reputation(-1.0))
	assert(east.stats.set_reputation(500.0))
	assert(east.stats.reputation == 100.0)
	assert(not east.stats.add_reputation(1.0))
	assert(east.stats.is_takeover_available())
	assert(east.stats.set_owner_faction(TerritoryStatsComponent.OwnerFaction.PLAYER))
	assert(not east.stats.is_takeover_available())
	assert(not pressure_changes.is_empty())
	assert(takeover_changes == [true, false])

	east.stats.import_save_data({"reputation": 42.0, "heat": 3.0})
	assert(east.stats.reputation == 42.0)
	assert(east.stats.owner_faction == TerritoryStatsComponent.OwnerFaction.NEUTRAL)
	assert(DealerRoleComponent.DEALER_REP_REQUIREMENTS == [0.0, 15.0, 40.0, 80.0])
	assert(DealerRoleComponent.WHOLESALER_REP_REQUIREMENT == 100.0)

	# Pass 2: all products and territories receive bounded, stable daily quotes.
	assert(market.generated_date == time.get_date_key())
	var saved_market := market.export_save_data()
	for territory in [east, west]:
		for product in EconomyCatalog.get_all_products():
			var buy := market.get_buy_quote(territory.territory_id, product)
			var sell := market.get_sell_quote(territory.territory_id, product)
			assert(buy >= maxi(roundi(product.dealer_price * 0.70), 1))
			assert(buy <= maxi(roundi(product.dealer_price * 1.30), 1))
			assert(sell == buy)
	var territories_differ := false
	for product in EconomyCatalog.get_all_products():
		if (
			market.get_buy_quote(east.territory_id, product)
			!= market.get_buy_quote(west.territory_id, product)
			or market.get_sell_quote(east.territory_id, product)
			!= market.get_sell_quote(west.territory_id, product)
		):
			territories_differ = true
			break
	assert(territories_differ)
	assert(not market.ensure_quotes(time.get_date_key()))
	assert(market.export_save_data() == saved_market)

	var restored_market := TerritoryMarketService.new()
	world.add_child(restored_market)
	restored_market.import_save_data(saved_market, time.get_date_key())
	assert(restored_market.export_save_data() == saved_market)
	restored_market.queue_free()
	await process_frame

	# Dealer purchases and street sales use local quotes and preserve atomicity.
	stats.import_save_data({"hustle": 1})
	east.stats.set_reputation(15.0)
	var dealer := world.get_node("Gameplay/EastDealer") as DealerNPC
	dealer.configure_dealer(1, false)
	var weed := EconomyCatalog.WEED_1G
	var buy_quote := market.get_buy_quote(east.territory_id, weed)
	var cash_before := wallet.dirty_cash
	assert(dealer.try_purchase(player, weed, 1).begins_with("Purchased"))
	assert(wallet.dirty_cash == cash_before - buy_quote)
	var quote_snapshot := market.export_save_data()
	var stock_before := dealer.get_stock_quantity(weed)
	assert(not dealer.try_purchase(player, weed, stock_before + 1).begins_with("Purchased"))
	assert(dealer.get_stock_quantity(weed) == stock_before)
	assert(market.export_save_data() == quote_snapshot)

	assert(inventory.add_product(weed, 1))
	var customer_payout := roundi(
		market.get_buy_quote(east.territory_id, weed)
		* stats.get_hustle_sale_multiplier()
	)
	var sale := trade.sell_product(weed, Vector3(64, 0, 0), 1)
	assert(sale.success and sale.dirty_cash_delta == customer_payout)
	var failed_cash := wallet.dirty_cash
	assert(not trade.sell_product(weed, Vector3(64, 0, 0), 999).success)
	assert(wallet.dirty_cash == failed_cash)
	assert(market.export_save_data() == quote_snapshot)

	# HUD has one aligned gram-product entry and the correct local sell quote.
	player.global_position = Vector3(64, 0, 0)
	hud._refresh_territory()
	assert(hud.market_quote_row.get_child_count() == 3)
	for product in EconomyCatalog.get_gram_products():
		var label := hud._market_price_labels.get(product.product_id) as Label
		assert(label != null)
		assert(label.text == "$%d/g" % market.get_buy_quote(east.territory_id, product))
	player.global_position = Vector3(1000, 0, 1000)
	hud._refresh_territory()
	for label in hud._market_price_labels.values():
		assert((label as Label).text == "$—/g")

	var old_date := market.generated_date
	var market_changes: Array[String] = []
	market.market_changed.connect(
		func(date_key: String) -> void:
			market_changes.append(date_key)
	)
	assert(time.advance_to_next_morning(8))
	assert(market.generated_date == time.get_date_key())
	assert(market.generated_date != old_date)
	assert(market_changes == [time.get_date_key()])

	print("TERRITORY_MARKET_SMOKE_TEST_PASS")
	quit(0)
