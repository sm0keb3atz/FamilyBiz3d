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
	var wallet := player.get_node(
		"Components/WalletComponent"
	) as PlayerWalletComponent
	var inventory := player.get_node(
		"Components/InventoryComponent"
	) as PlayerInventoryComponent
	var trade := player.get_node("Components/TradeService") as TradeService
	var dealer := world.get_node("Gameplay/EastDealer") as DealerNPC
	var east := TerritoryBoundary.find_at_position(self, Vector3(64, 0, 0))
	var west := TerritoryBoundary.find_at_position(
		self,
		Vector3(64, 0, -256)
	)
	assert(east != null and east.territory_id == &"hood_east")
	assert(west != null and west.territory_id == &"hood_west")

	var weed := EconomyCatalog.WEED_1G
	var weed_brick := EconomyCatalog.WEED_BRICK
	dealer.configure_dealer(2, false)
	assert(dealer.can_interact(player))
	assert(dealer.get_interaction_prompt(player).contains("15"))
	assert(east.stats.add_reputation(15.0))
	var starting_cash := wallet.dirty_cash
	var market := world.get_node(
		"TerritoryMarketService"
	) as TerritoryMarketService
	var weed_buy_quote := market.get_buy_quote(east.territory_id, weed)
	var purchase_message := dealer.try_purchase(player, weed, 5)
	assert(purchase_message.begins_with("Purchased"))
	assert(wallet.dirty_cash == starting_cash - weed_buy_quote * 5)
	assert(inventory.get_quantity(weed) == 5)
	assert(dealer.get_stock_quantity(weed) > 0)

	assert(trade.sell_product(weed, Vector3(64, 0, 0), 3).success)
	assert(inventory.get_quantity(weed) == 2)
	assert(east.stats.heat > 0.0)
	assert(west.stats.heat == 0.0)

	assert(inventory.add_product(weed_brick, 1))
	assert(inventory.break_down_product(weed_brick))
	assert(inventory.get_quantity(weed_brick) == 0)
	assert(inventory.get_quantity(weed) == 102)

	wallet.add_dirty(1000)
	dealer.role_component.restock_cooldown = 0.05
	dealer.configure_dealer(1, false)
	var dealer_stock := dealer.get_stock_quantity(weed)
	assert(dealer_stock > 0)
	assert(dealer.try_purchase(player, weed, dealer_stock).begins_with("Purchased"))
	assert(dealer.get_stock_quantity(weed) == 0)
	assert(dealer.get_cooldown_remaining() > 0.0)
	for _frame in range(8):
		await process_frame
	assert(dealer.get_stock_quantity(weed) > 0)

	dealer.configure_dealer(1, true)
	dealer.role_component.territory_id = &"hood_east"
	assert(dealer.can_interact(player))
	assert(dealer.get_interaction_prompt(player).contains("100"))
	assert(east.stats.add_reputation(100.0))
	assert(dealer.get_interaction_prompt(player) == "E - Shop")

	var controller := world.get_node("WorldController") as WorldController
	assert(controller.save_game())
	var saved_cash := wallet.dirty_cash
	wallet.add_dirty(999)
	east.stats.add_heat(20.0)
	assert(controller.load_game())
	assert(wallet.dirty_cash == saved_cash)
	assert(east.stats.heat < 20.0)

	print("FOUNDATION_SMOKE_TEST_PASS")
	quit(0)
