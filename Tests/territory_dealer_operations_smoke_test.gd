extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (load("res://Scenes/Maps/World/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.get_node("CivilianPopulationManager").set_population_enabled(false)
	world.get_node("WestPopulationManager").set_population_enabled(false)
	await process_frame
	await process_frame

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var wallet := player.get_node("Components/WalletComponent") as PlayerWalletComponent
	var inventory := player.get_node("Components/InventoryComponent") as PlayerInventoryComponent
	var properties := player.get_node("Components/PropertyComponent") as PlayerPropertyComponent
	var service := world.get_node("TerritoryDealerService") as TerritoryDealerService
	var encounter := world.get_node("TerritoryEncounterController") as TerritoryEncounterController
	var world_time := world.get_node("WorldTimeComponent") as WorldTimeComponent
	var east := world.get_node("Territories/HoodEast/TerritoryBoundary") as TerritoryBoundary

	assert(encounter.claim_territory(&"hood_east", &"test"))
	await process_frame
	var roster := service.get_roster(&"hood_east")
	assert(roster.size() == 6)
	for entry in roster:
		assert(not bool(entry.employed))
		assert(int(entry.level) == 1)
	for zone in get_nodes_in_group(&"dealer_activity_zone"):
		if zone.territory_id == &"hood_east":
			assert(zone.get_living_member_count() == 0)

	assert(wallet.add_clean(20000, false))
	assert(wallet.add_dirty(10000, false))
	assert(properties.purchase(&"hood_east_house_1"))
	assert(inventory.add_product(EconomyCatalog.WEED_1G, 2))
	assert(inventory.add_product(EconomyCatalog.WEED_BRICK, 1))
	assert(properties.transfer_product(&"hood_east_house_1", EconomyCatalog.WEED_1G, 2, true) == 2)
	assert(properties.transfer_product(&"hood_east_house_1", EconomyCatalog.WEED_BRICK, 1, true) == 1)

	var dirty_before := wallet.dirty_cash
	assert(service.hire_dealer(&"hood_east", &"hood_east_north", &"north_l2"))
	assert(wallet.dirty_cash == dirty_before - 500)
	var hired := _find_entry(service.get_roster(&"hood_east"), &"north_l2")
	assert(bool(hired.employed))
	assert(int(hired.level) == 1)
	assert(int(hired.sale_interval) == 120)
	assert(int(hired.upgrade_cost) == 1000)
	assert(service.upgrade_dealer(&"hood_east", &"hood_east_north", &"north_l2"))
	assert(wallet.dirty_cash == dirty_before - 1500)
	hired = _find_entry(service.get_roster(&"hood_east"), &"north_l2")
	assert(int(hired.level) == 2)
	assert(int(hired.sale_interval) == 90)
	var stash_cash_before := properties.get_stashed_dirty_cash(&"hood_east_house_1")
	var sale_minute := int(hired.next_sale_minute)
	service.process_to(sale_minute)
	assert(properties.get_stashed_product_quantity(&"hood_east_house_1", EconomyCatalog.WEED_1G) == 1)
	assert(properties.get_stashed_product_quantity(&"hood_east_house_1", EconomyCatalog.WEED_BRICK) == 1)
	var gross := player.get_node("Components/TradeService").get_sale_pricing(
		EconomyCatalog.WEED_1G, &"hood_east", 1).y
	var net := gross - roundi(float(gross) * TerritoryDealerService.COMMISSION_RATE)
	assert(properties.get_stashed_dirty_cash(&"hood_east_house_1") == stash_cash_before + net)
	assert(wallet.dirty_cash == dirty_before - 1500)
	assert(east.stats.reputation == 100.0)
	var north := _find_zone(&"hood_east_north")
	var presenting_dealer := north.get_member_dealer(&"north_l2")
	assert(presenting_dealer != null)
	var dealer_visit := presenting_dealer.get_node("DealerCustomerVisit") as StoreCustomerVisit3D
	assert(dealer_visit != null)
	assert(dealer_visit.has_pending_ticket())
	var presentation_customer := (load("res://Scenes/NPC/CustomerNPC.tscn") as PackedScene).instantiate() as CustomerNPC
	world.add_child(presentation_customer)
	await process_frame
	assert(presentation_customer.try_begin_store_visit(dealer_visit))
	assert(dealer_visit.get_reserved_destination_count() == 4)
	presentation_customer.cancel_store_visit(true)
	assert(dealer_visit.get_reserved_destination_count() == 0)
	presentation_customer.queue_free()

	var earnings := service.get_earnings_summary(&"hood_east")
	assert(int(earnings.today_gross) == gross)
	assert(int(earnings.today_net) == net)
	assert(int(earnings.today_commission) == gross - net)
	assert(world_time.daily_earned >= net)
	var daily_net := service.get_recent_daily_net(&"hood_east", 7)
	assert(daily_net.size() == 7)
	assert(daily_net[6] == net)

	# Only one remaining gram can be sold even when two dealers catch up.
	assert(service.hire_dealer(&"hood_east", &"hood_east_north", &"north_l3"))
	service.process_to(world_time.get_absolute_minute() + 180)
	assert(properties.get_stashed_product_quantity(&"hood_east_house_1", EconomyCatalog.WEED_1G) == 0)
	assert(properties.get_stashed_product_quantity(&"hood_east_house_1", EconomyCatalog.WEED_BRICK) == 1)
	assert(int(service.get_supply_summary(&"hood_east").product_units) == 0)

	assert(service.fire_dealer(&"hood_east", &"hood_east_north", &"north_l3"))
	var fired := _find_entry(service.get_roster(&"hood_east"), &"north_l3")
	assert(not bool(fired.employed))
	assert(int(fired.level) == 1)
	assert(service.hire_dealer(&"hood_east", &"hood_east_south", &"south_l1_primary"))
	var south := _find_zone(&"hood_east_south")
	var employee := south.get_member_dealer(&"south_l1_primary")
	assert(employee != null)
	south.handle_member_defeated(employee, false)
	assert(not bool(_find_entry(service.get_roster(&"hood_east"), &"south_l1_primary").employed))
	assert(south.get_member_dealer(&"south_l1_primary") == null)

	var saved := service.export_save_data()
	service.import_save_data(saved)
	assert(bool(_find_entry(service.get_roster(&"hood_east"), &"north_l2").employed))
	service.import_save_data({})
	for entry in service.get_roster(&"hood_east"):
		assert(not bool(entry.employed))

	var menu := player.get_node("PlayerInventoryMenu") as PlayerInventoryMenu
	assert(menu.layer == 40)
	assert(menu.get_node("MenuRoot/Panel/Margin/Content/DashboardBody") != null)
	assert(menu.get_node("MenuRoot/Panel/Margin/Content/DashboardBody/Navigation") != null)
	assert(menu.get_node("MenuRoot/Panel/Margin/Content/DashboardBody/TabContainer/Territory") != null)
	var territory_scroll := menu.get_node(
		"MenuRoot/Panel/Margin/Content/DashboardBody/TabContainer/Territory/TerritoryScroll"
	) as ScrollContainer
	assert(territory_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED)
	assert(territory_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED)
	menu.set_menu_open(true)
	var panel := menu.get_node("MenuRoot/Panel") as PanelContainer
	var normal_width := panel.size.x
	(menu.get_node("MenuRoot/Panel/Margin/Content/DashboardBody/TabContainer") as TabContainer).current_tab = 4
	for _frame in 30:
		await process_frame
	assert(panel.size.x > normal_width)
	assert(menu.find_child("TerritoryRevenueChart", true, false) != null)
	menu.set_menu_open(false)
	print("TERRITORY_DEALER_OPERATIONS_SMOKE_TEST_PASS")
	quit(0)


func _find_entry(entries: Array[Dictionary], member_id: StringName) -> Dictionary:
	for entry in entries:
		if StringName(entry.member_id) == member_id:
			return entry
	return {}


func _find_zone(zone_id: StringName) -> DealerActivityZone3D:
	for node in get_nodes_in_group(&"dealer_activity_zone"):
		var zone := node as DealerActivityZone3D
		if zone != null and zone.zone_id == zone_id:
			return zone
	return null
