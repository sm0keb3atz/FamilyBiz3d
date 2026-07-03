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
	var trade := player.get_node("Components/TradeService") as TradeService
	var wallet := player.get_node(
		"Components/WalletComponent"
	) as PlayerWalletComponent
	var inventory := player.get_node(
		"Components/InventoryComponent"
	) as PlayerInventoryComponent
	var product := inventory.get_known_products()[0]
	var east := TerritoryBoundary.find_at_position(self, Vector3(64, 0, 0))
	var west := TerritoryBoundary.find_at_position(
		self, Vector3(64, 0, -256)
	)
	assert(east != null and east.territory_id == &"hood_east")
	assert(west != null and west.territory_id == &"hood_west")

	var starting_cash := wallet.dirty_cash
	assert(trade.buy_product(product).success)
	assert(wallet.dirty_cash == starting_cash - product.dealer_price)
	assert(inventory.get_quantity(product) == 1)
	assert(trade.sell_product(product, Vector3(64, 0, 0)).success)
	assert(inventory.get_quantity(product) == 0)
	assert(east.stats.heat > 0.0)
	assert(west.stats.heat == 0.0)

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
