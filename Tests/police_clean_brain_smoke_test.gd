extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var world := (load("res://Scenes/Maps/World/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var population := world.get_node(
		"CivilianPopulationManager"
	) as CivilianPopulationManager
	population.set_population_enabled(false)
	await process_frame
	await physics_frame

	population.minimum_spawn_distance = 0.0
	population.maximum_spawn_distance = 500.0
	population.high_detail_distance = 500.0
	population.active_target = 15
	population.populate_immediately(15)
	var officers := population.get_active_police()
	assert(not officers.is_empty())
	var officer := officers[0] as PoliceNPC
	assert(officer.use_clean_slate_brain)
	assert(not officer.bt_player.active)
	assert(officer.brain_component.get_state_name() == &"patrol")

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var wanted := player.get_node(
		"Components/WantedComponent"
	) as PlayerWantedComponent
	var dispatch := world.get_node(
		"PoliceDispatchController"
	) as PoliceDispatchController
	dispatch.set_process(false)
	dispatch.set_physics_process(false)

	# Simulate a full-wanted search with no visual contact. The reported point is
	# deliberately away from the officer so this test proves physical movement,
	# not merely a state or blackboard assignment.
	var start_position := officer.global_position
	var search_direction := officer.visual.global_basis.z.normalized()
	var reported_position := start_position + search_direction * 12.0
	player.global_position = start_position - search_direction * 100.0
	officer.perception_component.set("_cached_can_see_player", false)
	wanted.report_police_incident(
		reported_position,
		PoliceIncident.CrimeType.OFFICER_DOWN,
		5
	)
	wanted.set_wanted_level(5)

	for _frame in 240:
		await physics_frame

	var first_debug := officer.brain_component.get_debug_state()
	assert(officer.brain_component.get_state_name() == &"search")
	assert(
		officer.global_position.distance_to(start_position) > 1.5,
		"Clean police brain entered Search without physically moving: %s"
		% first_debug
	)
	assert(
		String(first_debug.get("reason", ""))
		not in ["waiting_for_incident_location", "waiting_for_search_destination"],
		"Clean police brain has no actionable search command: %s" % first_debug
	)
	assert(officer.get_navigation_target_update_count() > 0)

	# Force arrival at the current search point. The brain must scan briefly and
	# then issue another waypoint rather than holding the question-mark state.
	officer.brain_component.force_search_for_test(officer.global_position)
	var search_continued := false
	var continuation_debug := {}
	for _frame in 360:
		await physics_frame
		continuation_debug = officer.brain_component.get_debug_state()
		var continuation_destination: Vector3 = continuation_debug.get(
			"destination",
			officer.global_position
		)
		if (
			int(continuation_debug.get("search_waypoint", 0)) > 0
			or continuation_destination.distance_to(officer.global_position) > 1.5
		):
			search_continued = true
			break
	assert(
		search_continued,
		"Clean police brain did not continue after scanning: %s"
		% continuation_debug
	)

	# Combat has a short visual-memory pursuit instead of the old one-frame stop.
	wanted.set_force_authorized(true)
	player.global_position = (
		officer.global_position
		+ officer.visual.global_basis.z.normalized() * 10.0
	)
	officer.perception_component.set("_cached_can_see_player", true)
	officer.brain_component.tick(0.016)
	assert(officer.brain_component.get_state_name() == &"combat")
	assert(officer.combat_component.is_equipped())
	player.global_position += Vector3(100.0, 0.0, 0.0)
	officer.perception_component.set("_cached_can_see_player", false)
	officer.brain_component.tick(0.1)
	assert(officer.brain_component.get_state_name() == &"combat")
	assert(
		officer.brain_component.get_debug_state().reason
		== "pursuing_recent_visual"
	)
	officer.brain_component.tick(
		officer.brain_component.visual_memory_seconds + 0.1
	)
	assert(officer.brain_component.get_state_name() == &"search")

	print("POLICE_CLEAN_BRAIN_SMOKE_TEST_PASS")
	quit(0)
