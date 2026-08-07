extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (load("res://Scenes/Maps/World/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.get_node("CivilianPopulationManager").set_population_enabled(false)
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
	assert(roster.size() == 8)
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
	assert(service.hire_dealer(
		&"hood_east",
		&"hood_east_north",
		&"north_l2",
		&"hood_east_house_1"
	))
	assert(wallet.dirty_cash == dirty_before - 500)
	var hired := _find_entry(service.get_roster(&"hood_east"), &"north_l2")
	assert(bool(hired.employed))
	assert(StringName(hired.property_id) == &"hood_east_house_1")
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
	var gross: int = player.get_node("Components/TradeService").get_sale_pricing(
		EconomyCatalog.WEED_1G, &"hood_east", 1).y
	var net: int = gross - roundi(
		float(gross) * TerritoryDealerService.COMMISSION_RATE
	)
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
	assert(service.hire_dealer(
		&"hood_east",
		&"hood_east_north",
		&"north_l3",
		&"hood_east_house_1"
	))
	assert(not service.hire_dealer(
		&"hood_east",
		&"hood_east_north",
		&"north_l4",
		&"hood_east_house_1"
	))
	assert(service.get_property_roster(&"hood_east_house_1").size() == 2)
	assert(int(service.get_earnings_summary(&"hood_east").total_slots) == 2)
	assert(properties.purchase(&"hood_east_house_2"))
	assert(inventory.add_product(EconomyCatalog.COKE_1G, 1))
	assert(properties.transfer_product(
		&"hood_east_house_2",
		EconomyCatalog.COKE_1G,
		1,
		true
	) == 1)
	assert(service.reassign_dealer(
		&"hood_east",
		&"hood_east_north",
		&"north_l3",
		&"hood_east_house_2"
	))
	assert(service.get_property_roster(&"hood_east_house_1").size() == 1)
	assert(service.get_property_roster(&"hood_east_house_2").size() == 1)
	assert(service.reassign_dealer(
		&"hood_east",
		&"hood_east_north",
		&"north_l3",
		&"hood_east_house_1"
	))
	assert(service.get_property_roster(&"hood_east_house_1").size() == 2)
	service.process_to(world_time.get_absolute_minute() + 180)
	assert(properties.get_stashed_product_quantity(&"hood_east_house_1", EconomyCatalog.WEED_1G) == 0)
	assert(properties.get_stashed_product_quantity(&"hood_east_house_1", EconomyCatalog.WEED_BRICK) == 1)
	assert(int(service.get_property_supply_summary(
		&"hood_east_house_1"
	).product_units) == 0)
	assert(int(service.get_property_supply_summary(
		&"hood_east_house_2"
	).product_units) == 1)
	assert(properties.get_stashed_product_quantity(
		&"hood_east_house_2",
		EconomyCatalog.COKE_1G
	) == 1)

	# Every hired dealer can be called. While following, sale clocks pause,
	# stash supply is untouched, and the assignment survives save/import.
	assert(inventory.add_product(EconomyCatalog.WEED_1G, 2))
	assert(properties.transfer_product(
		&"hood_east_house_1", EconomyCatalog.WEED_1G, 2, true
	) == 2)
	assert(service.call_dealer(
		&"hood_east", &"hood_east_north", &"north_l2"
	))
	assert(service.call_dealer(
		&"hood_east", &"hood_east_north", &"north_l3"
	))
	assert(service.get_following_dealers().size() == 2)
	assert(north.get_member_dealer(&"north_l2").is_bodyguard_following())
	assert(north.get_member_dealer(&"north_l3").is_bodyguard_following())
	var paused_supply := properties.get_stashed_product_quantity(
		&"hood_east_house_1", EconomyCatalog.WEED_1G
	)
	var paused_cash := properties.get_stashed_dirty_cash(
		&"hood_east_house_1"
	)
	service.process_to(world_time.get_absolute_minute() + 1000)
	assert(properties.get_stashed_product_quantity(
		&"hood_east_house_1", EconomyCatalog.WEED_1G
	) == paused_supply)
	assert(properties.get_stashed_dirty_cash(
		&"hood_east_house_1"
	) == paused_cash)
	var following_save := service.export_save_data()
	service.import_save_data(following_save)
	await process_frame
	await process_frame
	assert(service.get_following_dealers().size() == 2)
	assert(bool(_find_entry(
		service.get_roster(&"hood_east"), &"north_l2"
	).following))
	var menu := player.get_node("PlayerInventoryMenu") as PlayerInventoryMenu
	menu.set_menu_open(true)
	(menu.get_node(
		"MenuRoot/Panel/Margin/Content/DashboardBody/TabContainer"
	) as TabContainer).current_tab = 4
	for _frame in 3:
		await process_frame
	assert(_has_button_text(menu, "MANAGE  >"))
	menu._select_owned_territory(&"hood_east")
	await process_frame
	assert(_has_button_text(menu, "MANAGE  >"))
	assert(_has_button_text(menu, "<  ALL TERRITORIES"))
	menu._set_territory_management_tab(&"dealers")
	await process_frame
	assert(_has_button_text(menu, "SEND HOME"))
	menu._set_territory_management_tab(&"properties")
	await process_frame
	assert(_has_button_text(menu, "MANAGE  >"))
	menu._manage_property_from_territory(&"hood_east_house_1")
	await process_frame
	assert(_has_button_text(menu, "SEND BACK"))
	assert(_has_button_text(menu, "<  ALL PROPERTIES"))
	menu._select_sidebar_tab(4)
	menu._show_owned_territory_list()
	await process_frame
	assert(_has_button_text(menu, "MANAGE  >"))
	menu.set_menu_open(false)

	var paused_l2 := int((
		(following_save["hood_east"] as Dictionary)["slots"] as Dictionary
	)["hood_east_north/north_l2"].get("paused_sale_minutes", -1))
	assert(service.send_dealer_back(
		&"hood_east", &"hood_east_north", &"north_l2"
	))
	hired = _find_entry(service.get_roster(&"hood_east"), &"north_l2")
	assert(not bool(hired.following))
	assert(int(hired.next_sale_minute) == (
		world_time.get_absolute_minute() + paused_l2
	))
	service.process_to(int(hired.next_sale_minute))
	assert(properties.get_stashed_product_quantity(
		&"hood_east_house_1", EconomyCatalog.WEED_1G
	) == paused_supply - 1)
	assert(service.send_dealer_back(
		&"hood_east", &"hood_east_north", &"north_l3"
	))
	assert(service.fire_dealer(&"hood_east", &"hood_east_north", &"north_l3"))
	var fired := _find_entry(service.get_roster(&"hood_east"), &"north_l3")
	assert(not bool(fired.employed))
	assert(int(fired.level) == 1)
	assert(service.hire_dealer(&"hood_east", &"hood_east_south", &"south_l1_primary"))
	var south := _find_zone(&"hood_east_south")
	var employee := south.get_member_dealer(&"south_l1_primary")
	assert(employee != null)
	assert(service.call_dealer(
		&"hood_east", &"hood_east_south", &"south_l1_primary"
	))
	employee.damageable.apply_damage(
		employee.damageable.maximum_health,
		null,
		employee.global_position + Vector3.UP,
		Vector3.FORWARD
	)
	await process_frame
	assert(not bool(_find_entry(service.get_roster(&"hood_east"), &"south_l1_primary").employed))
	assert(south.get_member_dealer(&"south_l1_primary") == null)
	var replacement_cash := wallet.dirty_cash
	assert(service.hire_dealer(
		&"hood_east", &"hood_east_south", &"south_l1_primary"
	))
	assert(wallet.dirty_cash == replacement_cash - TerritoryDealerService.HIRE_FEE)

	var saved := service.export_save_data()
	service.import_save_data(saved)
	assert(bool(_find_entry(service.get_roster(&"hood_east"), &"north_l2").employed))
	var legacy := saved.duplicate(true)
	var legacy_slots := (
		(legacy["hood_east"] as Dictionary)["slots"] as Dictionary
	)
	for slot_state in legacy_slots.values():
		(slot_state as Dictionary).erase("duty")
		(slot_state as Dictionary).erase("paused_sale_minutes")
		(slot_state as Dictionary).erase("follow_slot")
		(slot_state as Dictionary).erase("property_id")
	service.import_save_data(legacy)
	await process_frame
	assert(not bool(_find_entry(
		service.get_roster(&"hood_east"), &"north_l2"
	).following))
	assert(StringName(_find_entry(
		service.get_roster(&"hood_east"), &"north_l2"
	).property_id) == &"hood_east_house_1")
	assert(wallet.add_clean(20000, false))
	assert(wallet.add_dirty(10000, false))
	assert(properties.purchase(&"hood_east_house_3"))
	assert(properties.purchase(&"hood_east_house_4"))
	var expansion_properties: Array[StringName] = [
		&"hood_east_house_2",
		&"hood_east_house_2",
		&"hood_east_house_3",
		&"hood_east_house_3",
		&"hood_east_house_4",
		&"hood_east_house_4",
	]
	var candidates := service.get_available_candidates(&"hood_east")
	assert(candidates.size() == 6)
	for index in candidates.size():
		var candidate := candidates[index]
		assert(service.hire_dealer(
			&"hood_east",
			StringName(candidate.zone_id),
			StringName(candidate.member_id),
			expansion_properties[index]
		))
	assert(int(service.get_earnings_summary(&"hood_east").staffed) == 8)
	assert(int(service.get_earnings_summary(&"hood_east").total_slots) == 8)
	for property_id in PropertyCatalog.PROPERTY_IDS:
		assert(service.get_property_roster(property_id).size() == 2)
	properties.forfeit_stash_houses()
	await process_frame
	for entry in service.get_roster(&"hood_east"):
		assert(not bool(entry.employed))
	service.import_save_data({})
	for entry in service.get_roster(&"hood_east"):
		assert(not bool(entry.employed))

	assert(menu.layer == 40)
	assert(menu.get_node("MenuRoot/Panel/Margin/Content/DashboardBody") != null)
	assert(menu.get_node("MenuRoot/Panel/Margin/Content/DashboardBody/Navigation") != null)
	assert(menu.get_node("MenuRoot/Panel/Margin/Content/DashboardBody/TabContainer/Territory") != null)
	var territory_scroll := menu.get_node(
		"MenuRoot/Panel/Margin/Content/DashboardBody/TabContainer/Territory/TerritoryScroll"
	) as ScrollContainer
	assert(territory_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED)
	menu.set_menu_open(true)
	var panel := menu.get_node("MenuRoot/Panel") as PanelContainer
	var normal_width := panel.size.x
	(menu.get_node("MenuRoot/Panel/Margin/Content/DashboardBody/TabContainer") as TabContainer).current_tab = 4
	for _frame in 30:
		await process_frame
	assert(panel.size.x > normal_width)
	assert(territory_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO)
	assert(_has_button_text(menu, "MANAGE  >"))
	menu._select_owned_territory(&"hood_east")
	await process_frame
	assert(territory_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED)
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


func _has_button_text(root_node: Node, button_text: String) -> bool:
	for node in root_node.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == button_text:
			return true
	return false
