extends SceneTree

const PoliceCoordinatorData := preload("res://Scripts/Gameplay/police_coordinator.gd")


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var world := (load("res://Scenes/Maps/World/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	await physics_frame

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var wanted := player.get_node(
		"Components/WantedComponent"
	) as PlayerWantedComponent
	var coordinator: Node = world.get_node("PoliceCoordinator")
	var dispatch := world.get_node("PoliceDispatchController") as PoliceDispatchController
	var population := world.get_node(
		"CivilianPopulationManager"
	) as CivilianPopulationManager

	assert(PlayerWantedComponent.MAX_WANTED_LEVEL == 6)
	assert(wanted.get_evasion_segment_seconds(1) == 8.0)
	assert(wanted.get_evasion_segment_seconds(6) == 14.0)
	assert(dispatch.response_profile.officer_targets == PackedInt32Array([0, 2, 3, 4, 6, 8, 10]))
	assert(dispatch.response_profile.cruiser_limits == PackedInt32Array([0, 1, 1, 2, 3, 4, 5]))
	assert(dispatch.response_profile.get_officer_target(6) == 10)
	assert(dispatch.response_profile.get_cruiser_target(6) == 5)

	wanted.report_police_incident(
		player.global_position,
		PoliceIncident.CrimeType.OFFICER_DOWN,
		6
	)
	wanted.set_wanted_level(6)
	assert(wanted.wanted_level == 6)
	wanted.escape_exit_grace = 0.0
	wanted.set("_visual_contact_remaining", 0.0)
	for expected_level in [5, 4, 3, 2, 1, 0]:
		wanted.set("_escape_progress", 0.001)
		wanted.call("_update_escape", 0.1)
		assert(wanted.wanted_level == expected_level)

	coordinator.report_sound(null, player.global_position, 0.75, 101)
	assert(coordinator.phase == PoliceCoordinatorData.WantedPhase.INVESTIGATING)
	var assignments := {}
	for officer_id in [1, 2, 3, 4]:
		var assignment: Dictionary = coordinator.get_search_assignment(officer_id)
		assignments[String(assignment.get("role", &""))] = true
	assert(assignments.size() == 4)

	population.set_population_enabled(false)
	population.minimum_spawn_distance = 0.0
	population.maximum_spawn_distance = 500.0
	population.high_detail_distance = 500.0
	population.active_target = 15
	population.populate_immediately(15)
	var active_police := population.get_active_police()
	assert(not active_police.is_empty())
	var police := active_police[0] as PoliceNPC
	# Test sight angles in empty space, independently of the random patrol spawn
	# and buildings/vehicles that may occupy its forward ray.
	police.global_position = Vector3(0.0, 100.0, 0.0)
	var forward := police.visual.global_basis.z.normalized()
	player.global_position = police.global_position - forward * 4.0
	assert(not bool(police.perception_component.call("_sample_can_see_player")))
	player.global_position = police.global_position + forward * 10.0
	assert(bool(police.perception_component.call("_sample_can_see_player")))

	print("POLICE_WANTED_OVERHAUL_SMOKE_TEST_PASS")
	quit(0)
