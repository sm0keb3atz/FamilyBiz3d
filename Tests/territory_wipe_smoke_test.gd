extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (load("res://Scenes/Maps/World/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	await physics_frame
	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var east := TerritoryBoundary.find_at_position(self, player.global_position)
	var encounter := world.get_node("TerritoryEncounterController") as TerritoryEncounterController
	east.stats.set_reputation(99.0)
	var first_zone := world.get_node("SpawnPoints/EastDealerZoneNorth") as DealerActivityZone3D
	var first_dealer := first_zone.get_living_dealers()[0]
	first_dealer.damageable.apply_damage(first_dealer.damageable.maximum_health, player)
	assert(east.stats.owner_faction != TerritoryStatsComponent.OwnerFaction.PLAYER)
	assert(east.stats.reputation == 84.0)

	# A below-threshold kill cannot count; wait for that stable member to return.
	var time := world.get_node("WorldTimeComponent") as WorldTimeComponent
	east.stats.set_reputation(100.0)
	time.advance_minutes(WorldTimeComponent.MINUTES_PER_DAY)
	var victims: Array[DealerNPC] = []
	for node in get_nodes_in_group(&"dealer_activity_zone"):
		victims.append_array((node as DealerActivityZone3D).get_living_dealers())
	for victim in victims:
		victim.damageable.apply_damage(victim.damageable.maximum_health, player)
	assert(east.stats.owner_faction == TerritoryStatsComponent.OwnerFaction.PLAYER)
	assert(east.stats.reputation == 100.0)
	assert(not encounter.can_purchase_territory(&"hood_east"))
	assert(not encounter.claim_territory(&"hood_east", &"duplicate"))
	print("TERRITORY_WIPE_SMOKE_TEST_PASS")
	quit(0)
