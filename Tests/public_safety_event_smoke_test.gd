extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var world_scene := load("res://Scenes/Maps/World/world.tscn") as PackedScene
	assert(world_scene != null)
	var world := world_scene.instantiate()
	root.add_child(world)
	var east_manager := world.get_node("CivilianPopulationManager") as CivilianPopulationManager
	var west_manager := world.get_node("WestPopulationManager") as CivilianPopulationManager
	east_manager.set_population_enabled(false)
	west_manager.set_population_enabled(false)
	await process_frame
	await physics_frame

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var wanted := player.get_node("Components/WantedComponent") as PlayerWantedComponent
	var bus := world.get_node("WorldEventBus") as WorldEventBus
	var evidence := world.get_node("EvidenceService") as EvidenceService
	assert(bus != null)
	assert(evidence != null)

	east_manager.minimum_spawn_distance = 0.0
	east_manager.maximum_spawn_distance = 500.0
	east_manager.active_target = 12
	east_manager.populate_immediately(12)
	var officers := east_manager.get_active_police()
	assert(not officers.is_empty())
	var officer := officers[0]

	var unknown_shot := bus.publish_gunshot(
		null,
		officer.global_position + Vector3(2.0, 0.0, 0.0),
		30.0,
		&"unknown"
	)
	await process_frame
	assert(unknown_shot.event_id > 0)
	assert(wanted.wanted_level == 0)
	assert(wanted.active_incident == null)
	assert(officer.ai_component.has_active_investigation())
	# Officers pause at the sound origin before choosing a new search point.
	officer.ai_component.search_pause_minimum = 1.0
	officer.ai_component.search_pause_maximum = 1.0
	officer.ai_component.note_investigation(officer.global_position)
	officer.tick_ai_mode(PoliceModeAction.Mode.PATROL, 0.016)
	assert(float(officer.ai_component.get("_search_pause_remaining")) > 0.9)

	var report := CrimeReport.new()
	report.event_id = unknown_shot.event_id
	report.reporter = east_manager.get_active_customers()[0]
	report.suspect = player
	report.observation_position = player.global_position
	report.observed_at_seconds = Time.get_ticks_msec() * 0.001
	report.confidence = 0.9
	report.crime_type = PoliceIncident.CrimeType.WEAPON_DISCHARGE
	report.severity = 2
	bus.submit_crime_report(report)
	await process_frame
	assert(wanted.wanted_level == 2)
	assert(wanted.active_incident != null)
	assert(wanted.active_incident.suspect_known)
	# A street officer with no local target primes the shared dispatch while the
	# patrol branch is active, breaking the old wanted/search circular dependency.
	officer.ai_component.set("_investigation_remaining", 0.0)
	officer.ai_component.set("_has_search_center", false)
	officer.ai_component.set("_has_search_destination", false)
	officer.ai_component.set("_has_response_target", false)
	officer.ai_component.set("_response_commit_remaining", 0.0)
	officer.ai_component.set("_last_search_revision", -1)
	officer.tick_ai_mode(PoliceModeAction.Mode.PATROL, 0.016)
	assert(officer.ai_component.has_actionable_wanted_location())
	var player_lkp: Vector3 = wanted.active_incident.last_known_player_position

	var dealer := world.get_node("Gameplay/EastDealer") as DealerNPC
	bus.publish_gunshot(
		dealer,
		player_lkp + Vector3(30.0, 0.0, 0.0),
		45.0,
		dealer.get_faction_id()
	)
	await process_frame
	assert(wanted.active_incident.last_known_player_position == player_lkp)
	assert(bus.get_trace_snapshot().size() >= 3)

	print("PUBLIC_SAFETY_EVENT_SMOKE_TEST_PASS")
	quit(0)
