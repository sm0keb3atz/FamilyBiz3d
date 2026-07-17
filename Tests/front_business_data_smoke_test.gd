extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definitions := PropertyCatalog.get_all()
	assert(definitions.size() == 6)
	for house_id in PropertyCatalog.PROPERTY_IDS:
		var house := PropertyCatalog.get_by_id(house_id)
		assert(house != null and house.is_stash_house())
		assert(not house.is_front_business())
		assert(house.stash_capacity == 1000)

	var clothing := PropertyCatalog.get_by_id(PropertyCatalog.CLOTHING_STORE_ID)
	var gun := PropertyCatalog.get_by_id(PropertyCatalog.GUN_STORE_ID)
	assert(clothing != null and clothing.is_valid() and clothing.is_front_business())
	assert(clothing.purchase_price == 15000)
	assert(clothing.business_stock_capacity == 30)
	assert(clothing.business_restock_unit_cost == 100)
	assert(clothing.business_revenue_per_sale == 150)
	assert(clothing.business_sales_interval_minutes == 60)
	assert(clothing.business_open_minute == 9 * 60)
	assert(clothing.business_close_minute == 21 * 60)
	assert(gun != null and gun.is_valid() and gun.is_front_business())
	assert(gun.purchase_price == 25000)
	assert(gun.business_stock_capacity == 20)
	assert(gun.business_restock_unit_cost == 250)
	assert(gun.business_revenue_per_sale == 400)
	assert(gun.business_sales_interval_minutes == 120)
	assert(gun.business_open_minute == 10 * 60)
	assert(gun.business_close_minute == 20 * 60)

	var player_scene := load("res://Scenes/Player.tscn") as PackedScene
	var player := player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame
	var wallet := player.get_node("Components/WalletComponent") as PlayerWalletComponent
	var properties := player.get_node("Components/PropertyComponent") as PlayerPropertyComponent
	assert(wallet.add_clean(50000, false))
	assert(properties.purchase(PropertyCatalog.CLOTHING_STORE_ID, 500))
	assert(wallet.clean_cash == 35000)
	assert(properties.purchase(PropertyCatalog.GUN_STORE_ID, 500))
	assert(wallet.clean_cash == 10000)
	assert(properties.owns(PropertyCatalog.CLOTHING_STORE_ID))
	assert(properties.owns(PropertyCatalog.GUN_STORE_ID))
	assert(properties.get_stash_capacity(PropertyCatalog.CLOTHING_STORE_ID) == 0)
	assert(properties.get_business_stock(PropertyCatalog.CLOTHING_STORE_ID) == 0)

	assert(wallet.add_dirty(1000, false))
	assert(properties.restock_business(PropertyCatalog.CLOTHING_STORE_ID, 10))
	assert(properties.get_business_stock(PropertyCatalog.CLOTHING_STORE_ID) == 10)
	assert(wallet.dirty_cash == 100)
	assert(not properties.restock_business(PropertyCatalog.CLOTHING_STORE_ID, 21))
	assert(properties.get_business_stock(PropertyCatalog.CLOTHING_STORE_ID) == 10)
	assert(wallet.dirty_cash == 100)

	var saved := properties.export_save_data()
	assert((saved.get("businesses", {}) as Dictionary).has(String(PropertyCatalog.CLOTHING_STORE_ID)))
	properties.import_save_data({})
	assert(not properties.owns(PropertyCatalog.CLOTHING_STORE_ID))
	properties.import_save_data(saved)
	assert(properties.owns(PropertyCatalog.CLOTHING_STORE_ID))
	assert(properties.get_business_stock(PropertyCatalog.CLOTHING_STORE_ID) == 10)
	assert(int(properties.get_business_state(PropertyCatalog.CLOTHING_STORE_ID)["last_processed_absolute_minute"]) == 500)

	# Version-6 property payloads contain houses/stashes only and migrate cleanly.
	properties.import_save_data({
		"owned_ids": [String(PropertyCatalog.PROPERTY_IDS[0])],
		"stashes": {String(PropertyCatalog.PROPERTY_IDS[0]): {"dirty_cash": 50}},
	})
	assert(properties.owns(PropertyCatalog.PROPERTY_IDS[0]))
	assert(properties.get_stashed_dirty_cash(PropertyCatalog.PROPERTY_IDS[0]) == 50)
	assert(not properties.owns(PropertyCatalog.CLOTHING_STORE_ID))
	assert(properties.get_business_stock(PropertyCatalog.CLOTHING_STORE_ID) == 0)

	print("FRONT_BUSINESS_DATA_SMOKE_TEST_PASS")
	quit(0)
