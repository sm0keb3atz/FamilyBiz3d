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
	var player_stats := player.get_node("Components/StatsComponent") as PlayerStatsComponent
	var wanted := player.get_node(
		"Components/WantedComponent"
	) as PlayerWantedComponent
	east.stats.set_reputation(-70.0)
	wanted.set_wanted_level(2)
	assert(encounter.start_gang_war())
	assert(encounter.is_war_active())
	assert(wanted.is_gang_war_suppressed())
	assert(wanted.wanted_level == 0)
	wanted.report_violence(encounter._attackers[0] as DealerNPC, true)
	assert(wanted.wanted_level == 0)
	encounter.call("_finish_war", false)
	assert(not wanted.is_gang_war_suppressed())
	assert(wanted.wanted_level == 2)
	wanted.clear_wanted(false)
	assert(encounter.get_war_wins() == 0)
	assert(east.stats.reputation == -80.0)
	encounter._cooldown_until[&"hood_east"] = 0
	assert(encounter.start_gang_war())
	var xp_before := player_stats.experience
	var attacker := encounter._attackers[0] as DealerNPC
	var attacker_level := attacker.get_role_component().dealer_level
	attacker.damageable.apply_damage(attacker.damageable.maximum_health, player)
	assert(player_stats.experience == xp_before + TerritoryEncounterController.XP_REWARDS[attacker_level - 1])
	assert(not attacker.has_corpse_loot())
	var active_save := encounter.export_save_data()
	assert(float(active_save["war_remaining"]) == TerritoryEncounterController.WAR_DURATION)
	assert((active_save["attackers"] as Array).size() == 5)
	encounter.import_save_data(active_save)
	assert(encounter.is_war_active())
	encounter.call("_finish_war", true)
	assert(encounter.get_war_wins() == 1)
	assert(east.stats.reputation == -65.0)
	assert(encounter.get_cooldown_minutes() == TerritoryEncounterController.COOLDOWN_MINUTES)

	encounter._cooldown_until[&"hood_east"] = 0
	assert(encounter.start_gang_war())
	encounter.call("_finish_war", true)
	assert(encounter.get_war_wins() == 2)
	assert(east.stats.reputation == -50.0)
	encounter._cooldown_until[&"hood_east"] = 0
	assert(encounter.start_gang_war())
	encounter.call("_finish_war", true)
	assert(encounter.get_war_wins() == 3)
	assert(east.stats.owner_faction == TerritoryStatsComponent.OwnerFaction.PLAYER)
	assert(east.stats.reputation == 100.0)
	assert(not encounter.start_gang_war())

	var saved := encounter.export_save_data()
	encounter.import_save_data(saved)
	assert(encounter.get_war_wins() == 3)
	print("GANG_WAR_SMOKE_TEST_PASS")
	quit(0)
