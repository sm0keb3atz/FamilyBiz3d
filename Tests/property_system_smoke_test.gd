extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for hour in [6, 12, 23]:
		var sample_time := WorldTimeComponent.new()
		root.add_child(sample_time)
		var reports: Array[String] = []
		sample_time.day_ended.connect(
			func(report_date: String, _earned: int, _spent: int) -> void:
				reports.append(report_date)
		)
		assert(sample_time.set_time_of_day(hour, 0))
		assert(sample_time.advance_to_next_morning(8))
		assert(sample_time.day == 2 and sample_time.minute_of_day == 8 * 60)
		assert(reports.size() == 1)
		sample_time.queue_free()

	var world_scene := load("res://Scenes/Maps/World/world.tscn") as PackedScene
	assert(world_scene != null)
	var world := world_scene.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var properties := player.get_node("Components/PropertyComponent") as PlayerPropertyComponent
	var wallet := player.get_node("Components/WalletComponent") as PlayerWalletComponent
	var inventory := player.get_node("Components/InventoryComponent") as PlayerInventoryComponent
	var weapons := player.get_node("Components/WeaponComponent") as PlayerWeaponComponent
	var stats := player.get_node("Components/StatsComponent") as PlayerStatsComponent
	var controller := world.get_node("WorldController") as WorldController
	var time := world.get_node("WorldTimeComponent") as WorldTimeComponent
	assert(properties != null and wallet != null and inventory != null and weapons != null)

	var buildings := get_nodes_in_group(&"property_buildings")
	assert(buildings.size() == 4)
	var seen := {}
	var first: PropertyBuilding
	for node in buildings:
		var building := node as PropertyBuilding
		assert(building != null and building.get_definition() != null)
		assert(building.get_definition().purchase_price == 10000)
		assert(not seen.has(building.property_id))
		seen[building.property_id] = true
		if building.property_id == &"hood_east_house_1":
			first = building
	assert(seen.size() == 4 and first != null)
	var front_door := first.get_node("FrontDoor")
	var back_door := first.get_node("BackDoor")
	assert(front_door != null and back_door != null)
	assert(front_door.is_in_group(&"exclude_static_batch"))
	assert(first.for_sale_visual.is_in_group(&"exclude_static_batch"))
	assert((front_door.get_node("DoorVisualPivot/SmDoorHouse01") as MeshInstance3D).visible)
	assert(bool(front_door.get("requires_property_ownership")) and bool(back_door.get("requires_property_ownership")))
	assert(front_door.call("get_interaction_prompt", player) == "LOCKED - PROPERTY FOR SALE")
	assert(front_door.get_node("HingePivot/CollisionShape3D") != null)
	assert(not properties.purchase(first.property_id))
	assert(wallet.add_clean(10000, false))
	assert(properties.purchase(first.property_id))
	assert(wallet.clean_cash == 0)
	assert(properties.owns(&"hood_east_house_1"))
	assert(not properties.owns(&"hood_east_house_2"))
	await process_frame
	await physics_frame
	assert(not first.for_sale_visual.visible)
	assert(not first.for_sale_sign.monitoring and not first.for_sale_sign.monitorable)
	assert((first.get_node("Bed") as PropertyInteraction).can_interact(player))
	assert(not (buildings.filter(func(value: Node) -> bool: return (value as PropertyBuilding).property_id == &"hood_east_house_2")[0].get_node("Bed") as PropertyInteraction).can_interact(player))
	assert(front_door.call("get_interaction_prompt", player) == "E - Open Door")
	front_door.call("interact", player)
	assert(bool(front_door.get("is_moving")))
	await create_timer(1.1).timeout
	assert(bool(front_door.get("is_open")) and not is_zero_approx((front_door.get("hinge") as Node3D).rotation.y))
	assert(is_equal_approx((front_door.get("visual_pivot") as Node3D).rotation.y, (front_door.get("hinge") as Node3D).rotation.y))
	front_door.call("interact", player)
	await create_timer(1.1).timeout
	assert(not bool(front_door.get("is_open")) and is_zero_approx((front_door.get("hinge") as Node3D).rotation.y))
	assert(back_door.call("get_interaction_prompt", player) == "E - Open Door")

	var earned_before := time.daily_earned
	var spent_before := time.daily_spent
	assert(wallet.add_dirty(1234, false))
	assert(properties.transfer_dirty_cash(first.property_id, 100, true) == 100)
	assert(properties.transfer_dirty_cash(first.property_id, 2147483647, true) == 1234)
	assert(properties.get_stashed_dirty_cash(first.property_id) == 1334)
	assert(properties.transfer_dirty_cash(first.property_id, 1000, false) == 1000)
	assert(properties.get_stash_used_capacity(first.property_id) == 0)
	assert(time.daily_earned == earned_before and time.daily_spent == spent_before)

	for product in EconomyCatalog.get_all_products():
		assert(inventory.add_product(product, 123))
		assert(properties.transfer_product(first.property_id, product, 10, true) == 10)
		assert(properties.transfer_product(first.property_id, product, 2147483647, true) == 113)
		assert(properties.transfer_product(first.property_id, product, 100, false) == 100)
		assert(properties.get_stashed_product_quantity(first.property_id, product) == 23)

	var pistol := weapons.pistol_definition
	assert(weapons.grant_weapon(pistol))
	assert(weapons.unlock_attachment(pistol.weapon_id, PlayerWeaponComponent.ATTACHMENT_LASER))
	assert(weapons.equip_attachment(pistol.weapon_id, PlayerWeaponComponent.ATTACHMENT_LASER, true))
	assert(weapons.equip_slot(1))
	assert(weapons.add_reserve_ammo_for(pistol.weapon_id, 17))
	var weapon_before := weapons.export_weapon_state(pistol.weapon_id)
	assert(properties.store_weapon(first.property_id, pistol.weapon_id))
	assert(not weapons.owns_weapon(pistol.weapon_id))
	assert(properties.take_weapon(first.property_id, pistol.weapon_id))
	var weapon_after := weapons.export_weapon_state(pistol.weapon_id)
	assert(weapon_after["magazine_ammo"] == weapon_before["magazine_ammo"])
	assert(weapon_after["reserve_ammo"] == weapon_before["reserve_ammo"])
	assert(weapon_after["attachment_unlocks"] == weapon_before["attachment_unlocks"])
	assert(weapon_after["attachment_state"] == weapon_before["attachment_state"])

	assert(properties.get_stash_used_capacity(first.property_id) == 138)
	assert(properties.get_stash_capacity(first.property_id) == 1000)
	assert(properties.get_stash_remaining_capacity(first.property_id) == 862)
	var capacity_fill := properties.get_stash_remaining_capacity(first.property_id)
	assert(inventory.add_product(EconomyCatalog.WEED_1G, capacity_fill + 20))
	assert(properties.transfer_product(first.property_id, EconomyCatalog.WEED_1G, 2147483647, true) == capacity_fill)
	assert(properties.get_stash_used_capacity(first.property_id) == 1000)
	assert(properties.get_stashed_dirty_cash(first.property_id) == 334)
	assert(not properties.store_weapon(first.property_id, pistol.weapon_id))
	assert(weapons.owns_weapon(pistol.weapon_id))
	assert(properties.transfer_product(first.property_id, EconomyCatalog.WEED_1G, 1, false) == 1)
	assert(properties.store_weapon(first.property_id, pistol.weapon_id))
	assert(properties.get_stash_used_capacity(first.property_id) == 1000)
	assert(properties.take_weapon(first.property_id, pistol.weapon_id))
	assert(properties.transfer_product(first.property_id, EconomyCatalog.WEED_1G, 1, true) == 1)
	assert(properties.transfer_product(first.property_id, EconomyCatalog.WEED_1G, capacity_fill, false) == capacity_fill)
	assert(properties.get_stash_used_capacity(first.property_id) == 138)

	var saved := properties.export_save_data()
	properties.import_save_data({})
	assert(not properties.owns(first.property_id))
	await process_frame
	await physics_frame
	assert(first.for_sale_visual.visible)
	assert(first.for_sale_sign.monitoring and first.for_sale_sign.monitorable)
	assert(front_door.call("get_interaction_prompt", player) == "LOCKED - PROPERTY FOR SALE")
	properties.import_save_data(saved)
	assert(properties.owns(first.property_id))
	assert(properties.get_stashed_dirty_cash(first.property_id) == 334)
	assert(properties.get_stashed_product_quantity(first.property_id, EconomyCatalog.WEED_1G) == 23)
	await process_frame
	await physics_frame
	assert(not first.for_sale_visual.visible)
	assert(properties.get_stash_used_capacity(first.property_id) == 138)

	stats.take_damage(25.0)
	assert(stats.consume_stamina(10.0))
	var next_day := time.day + 1
	assert(time.set_time_of_day(6, 0))
	assert(controller.sleep_at_property(first.property_id))
	assert(time.day == next_day and time.minute_of_day == 8 * 60)
	assert(is_equal_approx(stats.health, stats.get_max_health()))
	assert(is_equal_approx(stats.stamina, stats.get_max_stamina()))
	paused = false

	var stash_menu := player.get_node("PropertyStashMenu") as PropertyStashMenu
	stash_menu.open_stash(first.property_id)
	assert(stash_menu.get_node("MenuRoot").visible)
	assert(stash_menu.get_node("MenuRoot/SafeArea/Page/Summary/Margin/Metrics/Capacity/CapacityBar") != null)
	assert((stash_menu.get_node("MenuRoot/SafeArea/Page/Body/ItemsPanel/Margin/Content/ItemScroll/ItemGrid") as GridContainer).get_child_count() >= 7)
	stash_menu.call("_set_category", "drugs")
	assert((stash_menu.get_node("MenuRoot/SafeArea/Page/Body/ItemsPanel/Margin/Content/ItemScroll/ItemGrid") as GridContainer).get_child_count() == 6)
	assert((stash_menu.get_node("MenuRoot/SafeArea/Page/Body/DetailsPanel/Margin/Details/Actions/StoreButton") as Button).text == "STORE")
	stash_menu.close()

	var wardrobe_menu := player.get_node("ClothingStoreMenu") as ClothingStoreMenu
	wardrobe_menu.open_wardrobe()
	assert(bool(wardrobe_menu.get("_wardrobe_mode")))
	for definition in wardrobe_menu.call("_get_visible_items") as Array:
		assert((player.get_node("Components/WardrobeComponent") as PlayerWardrobeComponent).owns(definition.clothing_id))
	wardrobe_menu.close()

	var inventory_scene := load("res://Scenes/UI/PlayerInventoryMenu.tscn") as PackedScene
	var inventory_menu := inventory_scene.instantiate()
	assert(inventory_menu.get_node("MenuRoot/Panel/Margin/Content/TabContainer/Property/PropertyScroll/PropertyList") != null)
	inventory_menu.free()

	print("PROPERTY_SYSTEM_SMOKE_TEST_PASS")
	quit(0)
