extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player_scene := load("res://Scenes/Player.tscn") as PackedScene
	assert(player_scene != null)
	var player := player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame
	await process_frame

	var inventory := player.get_node(
		"Components/InventoryComponent"
	) as PlayerInventoryComponent
	var weapons := player.get_node(
		"Components/WeaponComponent"
	) as PlayerWeaponComponent
	var stats := player.get_node(
		"Components/StatsComponent"
	) as PlayerStatsComponent
	var carry := player.get_node(
		"Components/CarryWeightComponent"
	) as PlayerCarryWeightComponent
	var wallet := player.get_node(
		"Components/WalletComponent"
	) as PlayerWalletComponent
	var gun_store := player.get_node(
		"Components/GunStoreService"
	) as GunStoreService
	var trade_service := player.get_node(
		"Components/TradeService"
	) as TradeService
	assert(inventory != null and weapons != null and stats != null)
	assert(carry != null and wallet != null and gun_store != null)
	assert(trade_service != null)
	assert(weapons.pistol_definition.carry_weight_grams == 100)
	assert(weapons.draco_definition.carry_weight_grams == 200)
	assert(weapons.pistol_definition.sights_weight_grams == 10)
	assert(weapons.pistol_definition.laser_weight_grams == 10)
	assert(weapons.pistol_definition.switch_weight_grams == 5)
	assert(weapons.pistol_definition.extended_weight_grams == 25)
	assert(weapons.pistol_definition.drum_weight_grams == 50)

	var weed := EconomyCatalog.WEED_1G
	var brick := EconomyCatalog.WEED_BRICK
	assert(weed.package_size_grams == 1)
	assert(brick.package_size_grams == 100)
	assert(carry.get_max_weight_grams() == 300)
	assert(inventory.add_product(brick, 3))
	assert(carry.get_current_weight_grams() == 300)
	assert(not inventory.add_product(weed, 1))
	assert(inventory.get_quantity(weed) == 0)
	assert(inventory.break_down_product(brick))
	assert(inventory.get_quantity(brick) == 2)
	assert(inventory.get_quantity(weed) == 100)
	assert(carry.get_current_weight_grams() == 300)

	stats.import_save_data({"strength": 2})
	assert(carry.get_max_weight_grams() == 350)
	assert(inventory.add_product(weed, 50))
	assert(carry.get_current_weight_grams() == 350)
	assert(not inventory.add_product(weed, 1))

	inventory.import_save_data({})
	weapons.import_save_data({})
	stats.import_save_data({"strength": 1})
	assert(weapons.grant_weapon(weapons.pistol_definition))
	assert(carry.get_current_weight_grams() == 100)
	assert(weapons.grant_weapon(weapons.draco_definition))
	assert(carry.get_current_weight_grams() == 300)
	assert(wallet.add_clean(1000, false))
	assert(gun_store.buy_attachment(weapons.pistol_definition, &"sights"))
	var attachment_cash_before := wallet.clean_cash
	assert(not gun_store.set_attachment_equipped(
		weapons.pistol_definition,
		&"sights",
		true
	))
	assert(wallet.clean_cash == attachment_cash_before)
	assert(not weapons.is_attachment_equipped(&"pistol", &"sights"))

	stats.import_save_data({"strength": 10})
	for attachment_id in PlayerWeaponComponent.STORE_ATTACHMENT_IDS:
		if not weapons.owns_attachment(&"pistol", attachment_id):
			assert(weapons.unlock_attachment(&"pistol", attachment_id))
	assert(weapons.equip_attachment(&"pistol", &"sights", true))
	assert(weapons.equip_attachment(&"pistol", &"laser", true))
	assert(weapons.equip_attachment(&"pistol", &"switch", true))
	assert(weapons.equip_attachment(&"pistol", &"extended", true))
	assert(
		weapons.pistol_definition.get_carry_weight_grams(
			weapons.get_attachment_state(&"pistol")
		) == 150
	)
	assert(weapons.equip_attachment(&"pistol", &"drum", true))
	assert(
		weapons.pistol_definition.get_carry_weight_grams(
			weapons.get_attachment_state(&"pistol")
		) == 175
	)
	for attachment_id in [&"sights", &"laser", &"switch"]:
		assert(weapons.equip_attachment(&"pistol", attachment_id, false))
	assert(
		weapons.pistol_definition.get_carry_weight_grams(
			weapons.get_attachment_state(&"pistol")
		) == 150
	)

	assert(weapons.unlock_attachment(&"draco", &"drum"))
	assert(weapons.equip_attachment(&"draco", &"drum", true))
	assert(
		weapons.draco_definition.get_carry_weight_grams(
			weapons.get_attachment_state(&"draco")
		) == 250
	)

	# Old saves keep overweight inventory but cannot add more until unloaded.
	weapons.import_save_data({})
	stats.import_save_data({"strength": 1})
	inventory.import_save_data({"weed_1g": 400})
	assert(carry.get_current_weight_grams() == 400)
	assert(carry.is_overweight())
	assert(not inventory.add_product(weed, 1))
	assert(inventory.remove_product(weed, 101))
	assert(carry.get_current_weight_grams() == 299)
	assert(inventory.add_product(weed, 1))

	# A failed gun purchase is weight-atomic and does not spend money.
	inventory.import_save_data({"weed_1g": 250})
	wallet.add_clean(5000, false)
	var clean_before := wallet.clean_cash
	assert(not gun_store.buy_weapon(weapons.pistol_definition))
	assert(wallet.clean_cash == clean_before)
	assert(not weapons.owns_weapon(&"pistol"))
	assert(wallet.add_dirty(10000, false))
	var dirty_before := wallet.dirty_cash
	var carried_before := inventory.get_quantity(weed)
	var blocked_purchase := trade_service.buy_product(weed, &"", 51)
	assert(not blocked_purchase.success)
	assert(wallet.dirty_cash == dirty_before)
	assert(inventory.get_quantity(weed) == carried_before)

	# Stash withdrawals leave the complete source stack untouched on failure.
	assert(wallet.add_clean(10000, false))
	var property_id := PropertyCatalog.PROPERTY_IDS[0]
	var properties := player.get_node(
		"Components/PropertyComponent"
	) as PlayerPropertyComponent
	assert(properties.purchase(property_id))
	assert(properties.purchase_runner(property_id))
	assert(properties.deliver_wholesale_product(property_id, brick, 1))
	assert(properties.transfer_product(property_id, brick, 1, false) == 0)
	assert(properties.get_stashed_product_quantity(property_id, brick) == 1)

	var menu := player.get_node("PlayerInventoryMenu") as PlayerInventoryMenu
	var value_label := menu.find_child("CarryWeightValue", true, false) as Label
	var bar := menu.find_child("CarryWeightBar", true, false) as ProgressBar
	assert(value_label != null and bar != null)
	assert(value_label.text == "250g / 300g")
	inventory.import_save_data({"weed_1g": 100})
	await process_frame
	assert(
		value_label.get_theme_color("font_color")
		== Color(0.22, 0.8, 0.87)
	)
	inventory.import_save_data({"weed_1g": 180})
	await process_frame
	assert(
		value_label.get_theme_color("font_color")
		== Color(0.95, 0.67, 0.22)
	)
	inventory.import_save_data({"weed_1g": 255})
	await process_frame
	assert(
		value_label.get_theme_color("font_color")
		== Color(0.95, 0.3, 0.28)
	)

	print("CARRY_WEIGHT_SMOKE_TEST_PASS")
	quit(0)
