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
	assert(east_manager.get_active_police_count() == 5)
	west_manager.minimum_spawn_distance = 0.0
	west_manager.maximum_spawn_distance = 500.0
	west_manager.high_detail_distance = 500.0
	west_manager.active_target = 15
	assert(west_manager.populate_immediately(15) == 15)
	assert(west_manager.get_active_police_count() == 5)

	var police := east_manager.get_active_police()[0]
	assert(police.role_component is PoliceRoleComponent)
	assert(police.patrol_component is PedestrianPatrolComponent)
	assert(police.combat_component is NPCCombatComponent)
	assert(police.perception_component is PolicePerceptionComponent)
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
	var arrest := player.get_node(
		"Components/ArrestComponent"
	) as PlayerArrestComponent
	var east_boundary := world.get_node(
		"Territories/HoodEast/TerritoryBoundary"
	) as TerritoryBoundary

	east_boundary.stats.set_heat(100.0)
	assert(wanted.wanted_level == 1)
	east_manager.update_population()
	assert(east_manager.get_active_police_count() == 5)
	police.tick_ai_mode(PoliceModeAction.Mode.ARREST, 0.016)
	assert(not police.combat_component.is_equipped())

	wanted.set_wanted_level(2)
	east_manager.update_population()
	assert(east_manager.get_active_police_count() == 6)
	police.tick_ai_mode(PoliceModeAction.Mode.COMBAT, 0.016)
	assert(police.combat_component.is_equipped())
	wanted.report_violence(police, true)
	assert(wanted.wanted_level == 3)

	wanted.set_wanted_level(1)
	arrest.arrest_duration = 0.05
	for _frame in 8:
		arrest.report_police_contact()
		await process_frame
	assert(wanted.wanted_level == 0)
	assert(is_equal_approx(east_boundary.stats.heat, 25.0))

	print("POLICE_SYSTEM_SMOKE_TEST_PASS")
	quit(0)
