extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var world := (load("res://Scenes/Maps/World/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	await physics_frame

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var encounter := world.get_node(
		"TerritoryEncounterController"
	) as TerritoryEncounterController
	var boundary := TerritoryBoundary.find_at_position(self, player.global_position)
	var wallet := player.get_node(
		"Components/WalletComponent"
	) as PlayerWalletComponent
	var inventory := player.get_node(
		"Components/InventoryComponent"
	) as PlayerInventoryComponent
	var wanted := player.get_node(
		"Components/WantedComponent"
	) as PlayerWantedComponent
	var weed := EconomyCatalog.WEED_1G
	var coke := EconomyCatalog.COKE_1G

	assert(encounter.get_robbery_hourly_chance(-1.0) == 0.30)
	assert(encounter.get_robbery_hourly_chance(0.0) == 0.20)
	assert(encounter.get_robbery_hourly_chance(25.0) == 0.10)
	assert(encounter.get_robbery_hourly_chance(50.0) == 0.05)
	assert(encounter.get_robbery_hourly_chance(70.0) == 0.0)

	boundary.stats.set_owner_faction(TerritoryStatsComponent.OwnerFaction.RIVAL)
	boundary.stats.set_reputation(0.0)
	wallet.import_save_data({"dirty_cash": 0, "clean_cash": 80})
	inventory.import_save_data({})
	encounter.debug_clear_event_cooldown(boundary.territory_id)
	assert(not encounter.debug_start_robbery(boundary.territory_id))
	wallet.import_save_data({"dirty_cash": 201, "clean_cash": 80})
	assert(inventory.add_product(weed, 5))
	assert(inventory.add_product(coke, 3))
	boundary.stats.set_reputation(70.0)
	assert(not encounter.debug_start_robbery(boundary.territory_id))
	boundary.stats.set_reputation(0.0)
	boundary.stats.set_owner_faction(TerritoryStatsComponent.OwnerFaction.PLAYER)
	assert(not encounter.debug_start_robbery(boundary.territory_id))
	boundary.stats.set_owner_faction(TerritoryStatsComponent.OwnerFaction.RIVAL)

	wanted.set_wanted_level(2)
	assert(encounter.debug_start_robbery(boundary.territory_id))
	assert(encounter.is_encounter_active(TerritoryEncounterController.EncounterType.ROBBERY))
	assert(not wanted.is_territory_event_suppressed())
	assert(wanted.wanted_level == 2)
	var event_bus := world.get_node("WorldEventBus") as WorldEventBus
	var exempt_shot := event_bus.publish_gunshot(
		player,
		player.global_position,
		30.0,
		&"player",
		{"police_exempt": true}
	)
	assert(bool(exempt_shot.metadata.get("police_exempt", false)))
	var approach_save := encounter.export_save_data()
	encounter.import_save_data(approach_save)
	assert(encounter.get_active_phase() == TerritoryEncounterController.RobberyPhase.APPROACH)
	assert(encounter.debug_trigger_robbery_contact())
	assert(wallet.dirty_cash == 101)
	assert(wallet.clean_cash == 80)
	assert(inventory.get_quantity(weed) == 3)
	assert(inventory.get_quantity(coke) == 2)
	wanted.report_violence(encounter.get("_robber") as RobberyEventDealer, true)
	assert(wanted.wanted_level == 2)

	var flee_save := encounter.export_save_data()
	encounter.import_save_data(flee_save)
	assert(encounter.get_active_phase() == TerritoryEncounterController.RobberyPhase.FLEE)
	var robber := encounter.get("_robber") as RobberyEventDealer
	robber.damageable.apply_damage(robber.damageable.maximum_health, player)
	assert(not encounter.is_encounter_active())
	assert(wallet.dirty_cash == 201)
	assert(wallet.clean_cash == 80)
	assert(inventory.get_quantity(weed) == 5)
	assert(inventory.get_quantity(coke) == 3)
	assert(boundary.stats.reputation == 5.0)
	assert(not wanted.is_territory_event_suppressed())
	assert(wanted.wanted_level == 2)
	assert(
		encounter.get_cooldown_minutes(boundary.territory_id)
		== TerritoryEncounterController.COOLDOWN_MINUTES
	)

	encounter.debug_clear_event_cooldown(boundary.territory_id)
	boundary.stats.set_reputation(0.0)
	wallet.import_save_data({"dirty_cash": 200, "clean_cash": 80})
	inventory.import_save_data({})
	assert(inventory.add_product(weed, 4))
	assert(encounter.debug_start_robbery(boundary.territory_id))
	assert(encounter.debug_trigger_robbery_contact())
	assert(encounter.debug_finish_robbery(false))
	assert(wallet.dirty_cash == 100)
	assert(wallet.clean_cash == 80)
	assert(inventory.get_quantity(weed) == 2)
	assert(boundary.stats.reputation == -20.0)

	encounter.debug_clear_event_cooldown(boundary.territory_id)
	boundary.stats.set_reputation(0.0)
	assert(encounter.debug_start_robbery(boundary.territory_id))
	var cash_before_cancel := wallet.dirty_cash
	var weed_before_cancel := inventory.get_quantity(weed)
	encounter.set("_robbery_remaining", 0.0)
	encounter.call("_process_robbery", 0.0)
	assert(not encounter.is_encounter_active())
	assert(wallet.dirty_cash == cash_before_cancel)
	assert(inventory.get_quantity(weed) == weed_before_cancel)
	assert(boundary.stats.reputation == 0.0)

	print("TERRITORY_ROBBERY_SMOKE_TEST_PASS")
	quit(0)
