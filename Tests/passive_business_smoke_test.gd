extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player_scene := load("res://Scenes/Player.tscn") as PackedScene
	var player := player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame
	var wallet := player.get_node("Components/WalletComponent") as PlayerWalletComponent
	var properties := player.get_node("Components/PropertyComponent") as PlayerPropertyComponent
	assert(wallet.add_clean(100000, false))
	assert(wallet.add_dirty(10000, false))
	assert(properties.purchase(PropertyCatalog.CLOTHING_STORE_ID, 8 * 60))
	assert(properties.purchase(PropertyCatalog.GUN_STORE_ID, 8 * 60))

	var dirty_before := wallet.dirty_cash
	assert(not properties.restock_business(PropertyCatalog.CLOTHING_STORE_ID, 31))
	assert(wallet.dirty_cash == dirty_before)
	assert(properties.get_business_stock(PropertyCatalog.CLOTHING_STORE_ID) == 0)
	assert(properties.restock_business(PropertyCatalog.CLOTHING_STORE_ID, 12))
	assert(properties.get_business_total_restock_spent(PropertyCatalog.CLOTHING_STORE_ID) == 1200)
	assert(not properties.restock_business(PropertyCatalog.CLOTHING_STORE_ID, 19))
	assert(properties.get_business_stock(PropertyCatalog.CLOTHING_STORE_ID) == 12)

	# Clothing sales begin one full interval after opening and stop before close.
	properties.process_businesses_to(9 * 60 + 59)
	assert(properties.get_business_stock(PropertyCatalog.CLOTHING_STORE_ID) == 12)
	properties.process_businesses_to(10 * 60)
	assert(properties.get_business_stock(PropertyCatalog.CLOTHING_STORE_ID) == 11)
	assert(properties.get_business_accumulated_earnings(PropertyCatalog.CLOTHING_STORE_ID) == 150)
	properties.process_businesses_to(21 * 60)
	assert(properties.get_business_stock(PropertyCatalog.CLOTHING_STORE_ID) == 1)
	assert(properties.get_business_accumulated_earnings(PropertyCatalog.CLOTHING_STORE_ID) == 1650)
	assert(properties.get_business_total_sales(PropertyCatalog.CLOTHING_STORE_ID) == 11)
	assert(properties.get_business_daily_revenue(PropertyCatalog.CLOTHING_STORE_ID, 0) == 1650)

	# A saved ledger produces the same result for the same elapsed game time.
	var saved := properties.export_save_data()
	properties.process_businesses_to(WorldTimeComponent.MINUTES_PER_DAY + 12 * 60)
	var expected_stock := properties.get_business_stock(PropertyCatalog.CLOTHING_STORE_ID)
	var expected_pending := properties.get_business_accumulated_earnings(PropertyCatalog.CLOTHING_STORE_ID)
	properties.import_save_data(saved)
	properties.process_businesses_to(WorldTimeComponent.MINUTES_PER_DAY + 12 * 60)
	assert(properties.get_business_stock(PropertyCatalog.CLOTHING_STORE_ID) == expected_stock)
	assert(properties.get_business_accumulated_earnings(PropertyCatalog.CLOTHING_STORE_ID) == expected_pending)

	# Reset to a clean owned state for authoritative clock and report coverage.
	properties.import_save_data({
		"owned_ids": [String(PropertyCatalog.CLOTHING_STORE_ID)],
		"businesses": {
			String(PropertyCatalog.CLOTHING_STORE_ID): {
				"stock": 0,
				"accumulated_earnings": 0,
				"total_earned": 0,
				"last_processed_absolute_minute": 8 * 60,
			},
		},
	})
	var time := WorldTimeComponent.new()
	root.add_child(time)
	time.connect_wallet(wallet)
	time.minute_advanced.connect(properties.process_businesses_to)
	time.day_ending.connect(func(_date: String) -> void: properties.settle_business_earnings())
	var report := {}
	time.day_ended.connect(func(_date: String, earned: int, spent: int) -> void:
		report["earned"] = earned
		report["spent"] = spent
	)
	time.daily_earned = 0
	time.daily_spent = 0
	assert(properties.restock_business(PropertyCatalog.CLOTHING_STORE_ID, 11))
	assert(time.daily_spent == 1100)
	var clean_before := wallet.clean_cash
	time.advance_to_next_morning(0)
	assert(properties.get_business_stock(PropertyCatalog.CLOTHING_STORE_ID) == 0)
	assert(properties.get_business_accumulated_earnings(PropertyCatalog.CLOTHING_STORE_ID) == 0)
	assert(properties.get_business_total_earned(PropertyCatalog.CLOTHING_STORE_ID) == 1650)
	assert(wallet.clean_cash == clean_before + 1650)
	assert(int(report.get("earned", -1)) == 1650)
	assert(int(report.get("spent", -1)) == 1100)

	# Both store menus expose management, while the home wardrobe does not.
	var gun_menu := player.get_node("GunStoreMenu") as GunStoreMenu
	var clothing_menu := player.get_node("ClothingStoreMenu") as ClothingStoreMenu
	assert(gun_menu.find_child("ShopTab", true, false) != null)
	assert(gun_menu.find_child("BusinessTab", true, false) != null)
	assert(gun_menu.find_child("BusinessManagementPanel", true, false) != null)
	assert(clothing_menu.find_child("ShopTab", true, false) != null)
	assert(clothing_menu.find_child("BusinessTab", true, false) != null)
	assert(clothing_menu.find_child("BusinessManagementPanel", true, false) != null)
	clothing_menu.open_wardrobe()
	assert(not (clothing_menu.find_child("StoreTabs", true, false) as Control).visible)
	assert(not (clothing_menu.find_child("BusinessManagementPanel", true, false) as Control).visible)
	clothing_menu.close()
	properties.import_save_data({})
	clothing_menu.open_store()
	clothing_menu.call("_set_store_tab", true)
	var management := clothing_menu.find_child("BusinessManagementPanel", true, false) as Control
	var summary := management.find_child("BusinessSummary", true, false) as Label
	var action := management.find_child("BusinessActionButton", true, false) as Button
	assert(summary.text.contains("PURCHASE PRICE"))
	action.pressed.emit()
	assert(properties.owns(PropertyCatalog.CLOTHING_STORE_ID))
	var dashboard := management.find_child("BusinessDashboard", true, false) as Control
	assert(dashboard.visible)
	assert((management.find_child("TotalRevenueValue", true, false) as Label).text == "$0")
	var restock_action := management.find_child("DashboardRestockButton", true, false) as Button
	restock_action.pressed.emit()
	assert(properties.get_business_stock(PropertyCatalog.CLOTHING_STORE_ID) == 1)
	clothing_menu.close()

	print("PASSIVE_BUSINESS_SMOKE_TEST_PASS")
	quit(0)
