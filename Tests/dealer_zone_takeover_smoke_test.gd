extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (load("res://Scenes/Maps/World/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	await physics_frame

	var zones := get_nodes_in_group(&"dealer_activity_zone")
	assert(zones.size() == 4)
	var north := world.get_node("SpawnPoints/EastDealerZoneNorth") as DealerActivityZone3D
	var south := world.get_node("SpawnPoints/EastDealerZoneSouth") as DealerActivityZone3D
	var west_north := world.get_node("SpawnPoints/WestDealerZoneNorth") as DealerActivityZone3D
	var west_south := world.get_node("SpawnPoints/WestDealerZoneSouth") as DealerActivityZone3D
	assert(north.zone_id == &"hood_east_north")
	assert(south.zone_id == &"hood_east_south")
	assert(west_north.zone_id == &"hood_west_north")
	assert(west_south.zone_id == &"hood_west_south")
	assert(north.get_required_member_count() == 3)
	assert(south.get_required_member_count() == 3)
	assert(west_north.get_required_member_count() == 3)
	assert(west_south.get_required_member_count() == 3)
	var zone_count_by_territory := {}
	var has_level_one_by_territory := {}
	for node in zones:
		var zone := node as DealerActivityZone3D
		assert(zone != null)
		assert(zone.get_required_member_count() >= 3)
		assert(zone.get_required_member_count() <= 5)
		zone_count_by_territory[zone.territory_id] = int(
			zone_count_by_territory.get(zone.territory_id, 0)
		) + 1
		for zone_dealer in zone.get_living_dealers():
			var role := zone_dealer.get_role_component()
			if role != null and role.dealer_level == 1:
				has_level_one_by_territory[zone.territory_id] = true
	assert(int(zone_count_by_territory.get(&"hood_east", 0)) == 2)
	assert(int(zone_count_by_territory.get(&"hood_west", 0)) == 2)
	assert(bool(has_level_one_by_territory.get(&"hood_east", false)))
	assert(bool(has_level_one_by_territory.get(&"hood_west", false)))
	assert(north.get_reinforcement_world_positions().size() == 2)
	assert(world.get_node("Gameplay/EastDealer") is DealerNPC)
	for _frame in range(120):
		var presentations_ready := true
		for north_dealer in north.get_living_dealers():
			if not north_dealer.is_zone_presentation_configured():
				presentations_ready = false
				break
		if presentations_ready:
			break
		await physics_frame
	var north_talkers: Array[DealerNPC] = []
	for north_dealer in north.get_living_dealers():
		if north_dealer.get_zone_activity_animation() == &"Talking":
			north_talkers.append(north_dealer)
	assert(north_talkers.size() == 2)
	var first_talker := north_talkers[0]
	var second_talker := north_talkers[1]
	var first_to_second := (
		second_talker.get_zone_presentation_target()
		- first_talker.get_zone_presentation_target()
	)
	var second_to_first := -first_to_second
	assert(absf(angle_difference(
		first_talker.get_zone_presentation_yaw(),
		atan2(first_to_second.x, first_to_second.z)
	)) < 0.01)
	assert(absf(angle_difference(
		second_talker.get_zone_presentation_yaw(),
		atan2(second_to_first.x, second_to_first.z)
	)) < 0.01)
	var original_talker_ids := PackedStringArray([
		String(first_talker.zone_member_id),
		String(second_talker.zone_member_id),
	])
	original_talker_ids.sort()
	north._configure_group_presentation()
	var rotated_talker_ids := PackedStringArray()
	for north_dealer in north.get_living_dealers():
		if north_dealer.get_zone_activity_animation() == &"Talking":
			rotated_talker_ids.append(String(north_dealer.zone_member_id))
	rotated_talker_ids.sort()
	assert(rotated_talker_ids.size() == 2)
	assert(rotated_talker_ids != original_talker_ids)

	# A known south-zone wall produces a lean assignment with a safe approach.
	for _frame in range(120):
		var south_ready := true
		for south_dealer in south.get_living_dealers():
			if not south_dealer.is_zone_presentation_configured():
				south_ready = false
				break
		if south_ready:
			break
		await physics_frame
	var south_leaner: DealerNPC
	for south_dealer in south.get_living_dealers():
		if south_dealer.get_zone_activity_animation() in [
			&"LeaningOnWall1", &"LeaningOnWall2"
		]:
			south_leaner = south_dealer
			break
	assert(south_leaner != null)
	assert(south_leaner.get_zone_navigation_target().is_finite())
	assert(south_leaner.get_zone_presentation_target().is_finite())

	# With wall collision disabled, the third dealer paces locally and idles.
	var original_wall_mask := north.lean_wall_collision_mask
	north.lean_wall_collision_mask = 0
	north._configure_group_presentation()
	var pacing_dealer: DealerNPC
	for north_dealer in north.get_living_dealers():
		if north_dealer.get_zone_activity_animation() != &"Talking":
			pacing_dealer = north_dealer
			break
	assert(pacing_dealer != null)
	assert(pacing_dealer.get_zone_activity_animation() == &"Idle")
	assert(
		pacing_dealer.get_zone_presentation_target().distance_to(
			north.global_position
		) <= north.hangout_radius + 1.5
	)
	north.lean_wall_collision_mask = original_wall_mask

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var stats := player.get_node("Components/StatsComponent") as PlayerStatsComponent
	var wallet := player.get_node("Components/WalletComponent") as PlayerWalletComponent
	var inventory := player.get_node("Components/InventoryComponent") as PlayerInventoryComponent
	var east := TerritoryBoundary.find_at_position(self, player.global_position)
	var dealer := world.get_node("Gameplay/EastDealer") as DealerNPC
	var stock_before := dealer.get_stock_quantity(EconomyCatalog.WEED_1G)
	var xp_before := stats.experience
	var shop_menu := player.get_node("DealerShopMenu") as DealerShopMenu
	shop_menu.open_for(dealer)
	assert(dealer.is_shop_interaction_active())
	var dealer_to_player := player.global_position - dealer.global_position
	assert(absf(angle_difference(
		dealer.visual.rotation.y,
		atan2(dealer_to_player.x, dealer_to_player.z)
	)) < 0.01)
	var activity_player := dealer.get_node(
		"Visual/PlayerTest2/ActivityAnimationPlayer"
	) as AnimationPlayer
	assert(activity_player.current_animation == &"Talking")
	shop_menu.close()
	assert(not dealer.is_shop_interaction_active())
	dealer.damageable.apply_damage(1.0, player, dealer.global_position + Vector3.UP)
	assert(is_equal_approx(east.stats.reputation, -5.0))
	assert(not dealer.is_zone_activity_playing())
	var alerted_ally := false
	for south_dealer in south.get_living_dealers():
		if south_dealer != dealer and south_dealer.is_hostile():
			alerted_ally = true
	assert(alerted_ally)
	dealer.damageable.apply_damage(1.0, player, dealer.global_position + Vector3.UP)
	assert(is_equal_approx(east.stats.reputation, -5.0))
	dealer.damageable.apply_damage(dealer.damageable.maximum_health, player, dealer.global_position + Vector3.UP)
	assert(is_equal_approx(east.stats.reputation, -15.0))
	assert(is_equal_approx(stats.experience, xp_before + 25.0))
	assert(dealer.has_corpse_loot())
	var dirty_before := wallet.dirty_cash
	var carried_before := inventory.get_quantity(EconomyCatalog.WEED_1G)
	dealer.collect_corpse_loot(player)
	assert(not dealer.has_corpse_loot())
	assert(wallet.dirty_cash >= dirty_before + 100)
	assert(wallet.dirty_cash <= dirty_before + 250)
	assert(inventory.get_quantity(EconomyCatalog.WEED_1G) == carried_before + stock_before)
	var dirty_after := wallet.dirty_cash
	dealer.collect_corpse_loot(player)
	assert(wallet.dirty_cash == dirty_after)

	var time := world.get_node("WorldTimeComponent") as WorldTimeComponent
	var saved_zone := south.export_save_data()
	var saved_members := saved_zone["members"] as Dictionary
	assert(bool(saved_members["south_l1_primary"]["dead"]))
	var legacy_dead_state := saved_members["south_l1_primary"] as Dictionary
	legacy_dead_state["respawn_minute"] = (
		time.get_absolute_minute() + WorldTimeComponent.MINUTES_PER_DAY
	)
	saved_members["south_l1_primary"] = legacy_dead_state
	south.import_save_data(saved_zone)
	var migrated_members := (
		south.export_save_data()["members"] as Dictionary
	)
	assert(
		int(migrated_members["south_l1_primary"]["respawn_minute"])
		<= time.get_absolute_minute() + 60
	)
	assert(south.dealer_respawn_minutes == 60)
	east.stats.set_reputation(100.0)
	time.advance_minutes(south.dealer_respawn_minutes)
	assert(south.get_living_member_count() == 2)
	east.stats.set_reputation(0.0)
	time.advance_minutes(1)
	assert(south.get_living_member_count() == 3)
	for _frame in range(120):
		var respawn_presentations_ready := true
		for south_dealer in south.get_living_dealers():
			if not south_dealer.is_zone_presentation_configured():
				respawn_presentations_ready = false
				break
		if respawn_presentations_ready:
			break
		await physics_frame
	for south_dealer in south.get_living_dealers():
		assert(south_dealer.is_zone_presentation_configured())

	var encounter := world.get_node("TerritoryEncounterController") as TerritoryEncounterController
	assert(is_equal_approx(encounter.get_hourly_chance(-10.0), 0.05))
	assert(is_equal_approx(encounter.get_hourly_chance(-30.0), 0.15))
	assert(is_equal_approx(encounter.get_hourly_chance(-60.0), 0.30))
	assert(is_equal_approx(encounter.get_hourly_chance(-80.0), 0.50))
	assert(is_equal_approx(encounter.get_hourly_chance(0.0), 0.0))

	east.stats.set_reputation(100.0)
	wallet.add_dirty(TerritoryEncounterController.PURCHASE_PRICE)
	assert(encounter.can_purchase_territory(&"hood_east"))
	var purchase_result := encounter.purchase_territory(&"hood_east", player)
	assert(purchase_result.contains("purchased"))
	assert(east.stats.owner_faction == TerritoryStatsComponent.OwnerFaction.PLAYER)
	assert(east.stats.reputation == 100.0)
	assert(north.faction == TerritoryStatsComponent.OwnerFaction.PLAYER)
	assert(south.faction == TerritoryStatsComponent.OwnerFaction.PLAYER)
	assert(not encounter.claim_territory(&"hood_east", &"duplicate"))

	print("DEALER_ZONE_TAKEOVER_SMOKE_TEST_PASS")
	quit(0)
