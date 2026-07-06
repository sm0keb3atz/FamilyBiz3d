extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world_scene := load(
		"res://Scenes/Maps/World/world.tscn"
	) as PackedScene
	assert(world_scene != null)
	var world := world_scene.instantiate()
	root.add_child(world)

	var east_manager := world.get_node(
		"CivilianPopulationManager"
	) as CivilianPopulationManager
	var west_manager := world.get_node(
		"WestPopulationManager"
	) as CivilianPopulationManager
	east_manager.set_population_enabled(false)
	west_manager.set_population_enabled(false)
	await process_frame
	await physics_frame

	east_manager.minimum_spawn_distance = 0.0
	east_manager.maximum_spawn_distance = 500.0
	east_manager.high_detail_distance = 500.0
	east_manager.active_target = 15
	assert(east_manager.populate_immediately(15) == 15)
	assert(east_manager.get_active_police_count() == 1)
	west_manager.minimum_spawn_distance = 0.0
	west_manager.maximum_spawn_distance = 500.0
	west_manager.high_detail_distance = 500.0
	west_manager.active_target = 15
	assert(west_manager.populate_immediately(15) == 15)
	assert(west_manager.get_active_police_count() == 1)

	var police := east_manager.get_active_police()[0]
	assert(police.role_component is PoliceRoleComponent)
	assert(police.patrol_component is PedestrianPatrolComponent)
	assert(police.combat_component is NPCCombatComponent)
	assert(police.perception_component is PolicePerceptionComponent)
	var police_gunshot_player := police.combat_component.get(
		"_gunshot_player"
	) as AudioStreamPlayer3D
	assert(police_gunshot_player != null)
	assert(police_gunshot_player.bus == &"Gunshots")
	assert(police_gunshot_player.max_distance >= 90.0)
	police.set_detection_debug_visible(true)
	var detection_debug := police.visual.get_node(
		"PoliceDetectionDebug"
	) as MeshInstance3D
	assert(detection_debug.visible)
	police.set_detection_debug_visible(false)
	assert(not detection_debug.visible)
	assert(
		police.appearance_component.get_option_name(
			PlayerAppearanceComponent.SLOT_TOP
		) == "Police Shirt"
	)
	assert(
		police.appearance_component.get_option_name(
			PlayerAppearanceComponent.SLOT_BOTTOM
		) == "Police Pants"
	)

	var customer := east_manager.get_active_customers()[0]
	for _index in 25:
		customer.appearance_component.randomize_appearance(&"civilian")
		assert(
			not customer.appearance_component.get_option_name(
				PlayerAppearanceComponent.SLOT_TOP
			).contains("Police")
		)
		assert(
			not customer.appearance_component.get_option_name(
				PlayerAppearanceComponent.SLOT_BOTTOM
			).contains("Police")
		)

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var wanted := player.get_node(
		"Components/WantedComponent"
	) as PlayerWantedComponent
	var damage_feedback := player.get_node(
		"Components/DamageFeedbackComponent"
	) as PlayerDamageFeedbackComponent
	assert(damage_feedback.bullet_impact_sounds.size() == 3)
	var arrest := player.get_node(
		"Components/ArrestComponent"
	) as PlayerArrestComponent
	var east_boundary := world.get_node(
		"Territories/HoodEast/TerritoryBoundary"
	) as TerritoryBoundary

	east_boundary.stats.set_heat(100.0)
	assert(wanted.wanted_level == 1)
	east_manager.populate_immediately()
	assert(east_manager.get_active_police_count() == 2)
	police.tick_ai_mode(PoliceModeAction.Mode.ARREST, 0.016)
	assert(not police.combat_component.is_equipped())

	wanted.set_wanted_level(2)
	east_manager.populate_immediately()
	assert(east_manager.get_active_police_count() == 3)
	wanted.report_police_incident(player.global_position)
	assert(wanted.has_police_search_position)
	for searching_police in east_manager.get_active_police():
		searching_police.tick_ai_mode(
			PoliceModeAction.Mode.SEARCH_COMBAT,
			0.016
		)
		assert(
			int(searching_police.ai_component.get(
				"_last_search_revision"
			)) == wanted.police_search_revision
		)
	police.tick_ai_mode(PoliceModeAction.Mode.COMBAT, 0.016)
	assert(police.combat_component.is_equipped())
	wanted.report_violence(police, true)
	assert(wanted.wanted_level == 3)

	wanted.escape_seconds_per_star = 0.05
	wanted.call("_update_escape", 0.025)
	assert(wanted.wanted_level == 3)
	assert(wanted.is_escaping)
	assert(wanted.escape_progress < 1.0)
	wanted.report_police_visual_contact()
	assert(not wanted.is_escaping)
	assert(is_equal_approx(wanted.escape_progress, 1.0))
	wanted.set("_visual_contact_remaining", 0.0)
	wanted.call("_update_escape", 0.051)
	assert(wanted.wanted_level == 2)
	wanted.call("_update_escape", 0.051)
	assert(wanted.wanted_level == 1)
	wanted.call("_update_escape", 0.051)
	assert(wanted.wanted_level == 0)
	assert(is_equal_approx(east_boundary.stats.heat, 25.0))

	wanted.set_wanted_level(1)
	arrest.arrest_duration = 0.05
	for _frame in 8:
		arrest.report_police_contact()
		await process_frame
	assert(wanted.wanted_level == 0)
	assert(is_equal_approx(east_boundary.stats.heat, 25.0))

	print("POLICE_SYSTEM_SMOKE_TEST_PASS")
	quit(0)
