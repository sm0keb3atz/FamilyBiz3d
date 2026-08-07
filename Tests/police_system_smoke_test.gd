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
	east_manager.set_population_enabled(false)
	assert(world.get_node_or_null("WestPopulationManager") == null)
	assert(east_manager.get_network_count() == 2)
	await process_frame
	await physics_frame

	east_manager.minimum_spawn_distance = 0.0
	east_manager.maximum_spawn_distance = 500.0
	east_manager.high_detail_distance = 500.0
	east_manager.active_target = 15
	assert(east_manager.populate_immediately(15) == 15)
	assert(east_manager.get_active_police_count() == 1)

	var police := east_manager.get_active_police()[0]
	assert(police.role_component is PoliceRoleComponent)
	assert(police.patrol_component is PedestrianPatrolComponent)
	assert(police.combat_component is NPCCombatComponent)
	assert(police.perception_component is PolicePerceptionComponent)
	assert(police.perception_component.vision_cone_ray_count <= 16)
	assert(police.perception_component.vision_cone_update_interval >= 0.25)
	assert(police.perception_component.perception_update_interval >= 0.1)
	assert(police.perception_component.hearing_range >= 150.0)
	var stable_navigation_target := police.global_position + Vector3(4.0, 0.0, 0.0)
	assert(police.set_navigation_target(stable_navigation_target))
	assert(not police.set_navigation_target(stable_navigation_target))
	police.clear_navigation_target()
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
	var direct_pursuit_player_position := player.global_position
	player.global_position = (
		police.global_position
		+ police.visual.global_basis.z.normalized() * 4.0
	)
	police.perception_component.set("_cached_can_see_player", true)
	police.tick_ai_mode(PoliceModeAction.Mode.ARREST, 0.016)
	assert(
		not bool(
			police.movement_component.get_navigation_debug_state().has_target
		),
		"Visible police pursuit incorrectly followed the pedestrian waypoint route"
	)
	var direct_pursuit_visual_rotation := police.visual.rotation.y
	police.visual.rotation.y += PI
	police.perception_component.set("_perception_update_remaining", 0.0)
	police.perception_component.call("_process", 0.016)
	assert(
		police.perception_component.can_see_player(),
		"Police radial awareness lost a nearby player behind their facing direction"
	)
	police.visual.rotation.y = direct_pursuit_visual_rotation
	player.global_position = direct_pursuit_player_position
	var wanted := player.get_node(
		"Components/WantedComponent"
	) as PlayerWantedComponent
	var vehicle_component := player.get_node(
		"Components/VehicleComponent"
	) as PlayerVehicleComponent
	var health := player.get_node(
		"Components/HealthComponent"
	) as PlayerHealthComponent
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
	var dispatch := world.get_node(
		"PoliceDispatchController"
	) as PoliceDispatchController
	dispatch.response_profile.initial_dispatch_delays = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	dispatch.response_profile.cruiser_launch_spacing = 0.01
	arrest.arrest_duration = 999.0

	# Aiming uses the same player-relative lower-body directions while the aim
	# pose remains enabled as an independent upper-body layer.
	police.visual.rotation.y = 0.0
	var lateral_blend := (
		police.animation_component.get_aim_direction_for_world_velocity(
			Vector3.RIGHT * police.ai_component.combat_aim_move_speed,
			police.ai_component.combat_aim_move_speed
		)
	)
	assert(lateral_blend.x > 0.9)
	assert(absf(lateral_blend.y) < 0.01)
	police.animation_component.set_combat_aiming(true)
	assert(
		is_equal_approx(
			float(police.animation_tree.get(
				police.animation_component.aim_movement_blend_parameter
			)),
			1.0
		)
	)
	assert(
		is_equal_approx(
			float(police.animation_tree.get(
				police.animation_component.combat_aim_blend_parameter
			)),
			1.0
		)
	)
	police.animation_component.set_combat_aiming(false)

	# Regress the old 2D behavior contract: a nearby gunshot creates a local
	# investigation, and seeing the player at the scene identifies the suspect.
	wanted.clear_wanted(false)
	police.perception_component.set("_cached_can_see_player", true)
	var event_bus := WorldEventBus.find(world.get_tree())
	assert(event_bus != null)
	event_bus.publish_gunshot(
		player,
		police.global_position,
		police.perception_component.hearing_range,
		&"player"
	)
	assert(police.ai_component.has_active_investigation())
	assert(
		(police.ai_component.get_search_debug_state().destination as Vector3)
		.distance_to(police.global_position) <= 2.0
	)
	police.tick_ai_mode(PoliceModeAction.Mode.PATROL, 0.016)
	assert(wanted.wanted_level == 1)
	assert(wanted.active_incident != null)
	assert(
		wanted.active_incident.crime_type
		== PoliceIncident.CrimeType.WEAPON_DISCHARGE
	)
	# A second witnessed discharge follows the old escalation rule.
	event_bus.publish_gunshot(
		player,
		police.global_position,
		police.perception_component.hearing_range,
		&"player"
	)
	police.tick_ai_mode(PoliceModeAction.Mode.ARREST, 0.016)
	assert(wanted.wanted_level == 2)

	# A known wanted player firing well beyond the old 28-meter cutoff gives
	# nearby police the exact shot location immediately, without requiring the
	# player to walk into their vision cone first.
	var position_before_long_range_shot := player.global_position
	player.global_position = police.global_position + Vector3(120.0, 0.0, 0.0)
	police.perception_component.set("_cached_can_see_player", false)
	event_bus.publish_gunshot(
		player,
		player.global_position,
		150.0,
		&"player"
	)
	assert(police.has_confirmed_wanted_player_location())
	police.ai_component.set("_response_commit_remaining", 0.0)
	assert(
		police.has_confirmed_wanted_player_location(),
		"Street police abandoned an active last-known location after response commitment expired"
	)
	police.ai_component.set(
		"_response_commit_remaining",
		police.ai_component.response_commit_seconds
	)
	assert(
		wanted.active_incident.last_known_player_position.distance_to(
			player.global_position
		) < 0.01
	)
	police.tick_ai_mode(PoliceModeAction.Mode.SEARCH_COMBAT, 0.016)
	assert(police.combat_component.is_equipped())
	player.global_position = position_before_long_range_shot
	police.ai_component.set("_last_mode", PoliceModeAction.Mode.COMBAT)
	police.ai_component.set("_has_response_target", true)
	police.ai_component.set(
		"_response_commit_remaining",
		police.ai_component.response_commit_seconds
	)
	police.set_navigation_target(player.global_position + Vector3(3.0, 0.0, 0.0))
	wanted.clear_wanted(false)
	assert(not police.ai_component.has_committed_response_target())
	assert(
		int(police.ai_component.get("_last_mode")) == -1,
		"Police retained their pursuit mode after the wanted level cleared"
	)
	assert(
		not bool(police.movement_component.get_navigation_debug_state().has_target),
		"Police retained a player pursuit destination after the wanted level cleared"
	)
	assert(not police.combat_component.is_equipped())
	police.set("_retaliation_target", player)
	police.ai_component.begin_retaliation(player)
	police.tick_ai_mode(PoliceModeAction.Mode.COMBAT, 0.016)
	assert(
		int(police.ai_component.get("_last_mode"))
		== PoliceAIComponent.MODE_PATROL,
		"Stale police combat action ran after the wanted level cleared"
	)
	assert(police.get("_retaliation_target") == null)
	assert(not police.combat_component.is_equipped())
	dispatch.reset_for_load()

	east_boundary.stats.set_heat(100.0)
	assert(wanted.wanted_level == 1)
	assert(wanted.active_incident != null)
	assert(
		wanted.active_incident.crime_type
		== PoliceIncident.CrimeType.SUSPICIOUS_ACTIVITY
	)
	assert(wanted.active_incident.severity == 1)
	assert(wanted.active_incident.territory_id == &"hood_east")
	east_manager.populate_immediately()
	assert(east_manager.get_active_police_count() == 1)
	dispatch.call("_process", 0.0)
	assert(dispatch.get_active_cruisers().size() >= 1)
	assert(dispatch.get_scheduled_officer_count() == 2)
	dispatch.set(
		"_strength_deficit_elapsed",
		dispatch.response_profile.deployment_deadline_seconds + 1.0
	)
	dispatch.call("_ensure_response_strength")
	assert((dispatch.get("_fallback_officers") as Array).is_empty())
	assert(
		dispatch.get_last_dispatch_route_search_count()
		<= dispatch.maximum_route_starts_per_dispatch
	)
	var first_cruiser := dispatch.get_active_cruisers()[0]
	assert(
		first_cruiser.global_position.distance_to(player.global_position)
		>= dispatch.minimum_dispatch_distance
	)
	assert(first_cruiser.get_vehicle_id() in [&"police_sedan", &"police_suv"])
	var cruiser_ai := first_cruiser.get_node(
		"TrafficAIComponent"
	) as TrafficVehicleAIComponent
	assert(cruiser_ai.has_route())
	assert(cruiser_ai.is_emergency_mode())
	var camera := get_root().get_viewport().get_camera_3d()
	if camera != null:
		assert(not camera.is_position_in_frustum(first_cruiser.global_position + Vector3.UP))
	police.tick_ai_mode(PoliceModeAction.Mode.ARREST, 0.016)
	assert(not police.combat_component.is_equipped())

	var responses := dispatch.get("_responses") as Array
	var first_response = responses[0]
	var dynamic_stop := cruiser_ai.get_destination_position()
	assert(cruiser_ai.has_dynamic_destination())
	assert(dynamic_stop.is_finite())
	assert(first_response.destination_position == dynamic_stop)
	assert(get_nodes_in_group(&"police_staging_point").is_empty())
	var first_seat_count := int(first_response.seat_count)
	var deployment_frames := 0
	while (
		dispatch.get_unloaded_officer_count() < first_seat_count
		and deployment_frames < 1200
	):
		await physics_frame
		deployment_frames += 1
	assert(
		dispatch.get_unloaded_officer_count() == first_seat_count,
		"Police deployment stalled: states=%s first=%s elapsed=%.2f distance=%.2f speed=%.2f route=%s recycle=%s"
		% [
			dispatch.get_response_states(),
			first_response.state_name(),
			first_response.response_elapsed,
			first_cruiser.global_position.distance_to(
				dynamic_stop
			),
			first_cruiser.linear_velocity.length(),
			cruiser_ai.has_route(),
			cruiser_ai.wants_recycle(),
		]
	)
	assert(deployment_frames < 1200)
	var deployment_player_distance := first_cruiser.global_position.distance_to(
		player.global_position
	)
	assert(
		deployment_player_distance <= dispatch.response_profile.deployment_distance,
		"Cruiser deployed too far away: target=%s initial=%s player=%.2f"
		% [
			first_response.destination_position,
			dynamic_stop,
			deployment_player_distance,
		]
	)
	assert(
		first_response.state_name() in [&"deploying", &"on_scene"]
	)
	assert(
		first_response.response_elapsed
		< dispatch.response_profile.deployment_deadline_seconds * 2.0,
		"Emergency driving failed dynamic arrival: elapsed=%.2f attempts=%d activations=%d detours=%d"
		% [
			first_response.response_elapsed,
			cruiser_ai.get_emergency_pass_attempt_count(),
			cruiser_ai.get_emergency_pass_activation_count(),
			cruiser_ai.get_emergency_detour_count(),
		]
	)
	for response_officer in first_response.officers:
		assert(
			response_officer.ai_component.has_committed_response_target()
		)
		response_officer.tick_ai_mode(PoliceModeAction.Mode.ARREST, 0.016)
		assert(not response_officer.combat_component.is_equipped())
		assert(
			response_officer.get_navigation_target_update_count() > 0
			or response_officer.perception_component.has_unobstructed_line_to(
				player.global_position + Vector3.UP,
				response_officer.ai_component.direct_pursuit_range
			)
			or response_officer.global_position.distance_to(player.global_position)
			<= response_officer.ai_component.arrest_distance
		)
	var on_scene_frames := 0
	while (
		first_response.state != PoliceDispatchController.ResponseUnit.State.ON_SCENE
		and on_scene_frames < 60
	):
		await physics_frame
		on_scene_frames += 1
	assert(first_response.state == PoliceDispatchController.ResponseUnit.State.ON_SCENE)
	assert(dispatch.get_effective_officer_count() == 2)

	# Respawning resolves the old incident while surviving officers are still
	# present. A fresh nearby shooting must cancel their return, wake their AI,
	# and bind them to the new incident instead of leaving them inert.
	var returning_officer := first_response.officers[0] as PoliceNPC
	wanted.set_wanted_level(1)
	health.downed.emit()
	assert(wanted.wanted_level == 0)
	wanted.set_wanted_level(1)
	health.respawn_completed.emit()
	assert(wanted.wanted_level == 0)
	assert(first_response.state == PoliceDispatchController.ResponseUnit.State.RETURNING)
	assert(first_response.return_positions.size() == first_response.officers.size())
	for returning_response_officer in first_response.officers:
		assert(not returning_response_officer.bt_player.active)
	assert(dispatch.get_effective_officer_count() == 0)
	assert(dispatch.get_scheduled_officer_count() == 0)
	player.global_position = returning_officer.global_position + Vector3(1.0, 0.0, 0.0)
	wanted.report_police_incident(
		player.global_position,
		PoliceIncident.CrimeType.WEAPON_DISCHARGE,
		2
	)
	var reengagement_incident_id: int = wanted.active_incident.incident_id
	wanted.set_wanted_level(2)
	assert(first_response.state == PoliceDispatchController.ResponseUnit.State.ON_SCENE)
	assert(returning_officer.get_response_id() == reengagement_incident_id)
	assert(returning_officer.ai_component.has_committed_response_target())
	assert(dispatch.get_effective_officer_count() == 2)

	var casualty := first_response.officers[0] as PoliceNPC
	casualty.damageable.apply_damage(
		casualty.damageable.maximum_health,
		player
	)
	await process_frame
	dispatch.call("_audit_response")
	assert(
		(dispatch.get("_fallback_officers") as Array).size() == 1,
		"Partial casualty was not replaced: %s" % dispatch.get_response_debug_snapshot()
	)
	assert(dispatch.get_effective_officer_count() == 2)

	wanted.report_police_incident(
		player.global_position,
		PoliceIncident.CrimeType.WEAPON_DISCHARGE,
		2
	)
	wanted.set_wanted_level(2)
	assert(not wanted.is_force_authorized)
	assert(wanted.can_attempt_arrest())
	east_manager.populate_immediately()
	assert(east_manager.get_active_police_count() == 1 + first_seat_count)
	dispatch.set("_launch_remaining", 0.0)
	dispatch.call("_process", 0.0)
	assert(dispatch.get_scheduled_officer_count() == 4)
	assert(wanted.active_incident.severity == 2)
	assert(wanted.active_incident.crime_type == PoliceIncident.CrimeType.WEAPON_DISCHARGE)
	assert(wanted.has_police_search_position)
	for searching_police in east_manager.get_active_police():
		if not searching_police.is_response_assigned():
			continue
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
	assert(wanted.is_force_authorized)
	assert(not wanted.can_attempt_arrest())
	assert(wanted.active_incident.crime_type == PoliceIncident.CrimeType.OFFICER_DOWN)
	assert(wanted.active_incident.severity == 3)
	dispatch.set("_launch_remaining", 0.0)
	dispatch.call("_process", 0.0)
	assert(dispatch.get_scheduled_officer_count() == 6)

	wanted.escape_seconds_per_star = 0.05
	wanted.escape_exit_grace = 2.0
	var reported_position: Vector3 = wanted.active_incident.last_known_player_position
	player.global_position = reported_position
	wanted.set("_visual_contact_remaining", 0.0)
	wanted.call("_update_escape", 1.0)
	assert(wanted.wanted_level == 3)
	assert(not wanted.is_escaping)
	assert(is_equal_approx(wanted.escape_progress, 1.0))
	player.global_position = reported_position + Vector3(40.0, 0.0, 0.0)
	wanted.call("_update_escape", 1.0)
	assert(not wanted.is_escaping)
	player.global_position = reported_position
	wanted.call("_update_escape", 0.1)
	player.global_position = reported_position + Vector3(40.0, 0.0, 0.0)
	wanted.call("_update_escape", 1.9)
	assert(wanted.wanted_level == 3)
	assert(not wanted.is_escaping)
	wanted.call("_update_escape", 0.11)
	assert(wanted.wanted_level == 2)
	wanted.call("_update_escape", 0.051)
	assert(wanted.wanted_level == 1)
	wanted.call("_update_escape", 0.051)
	assert(wanted.wanted_level == 0)
	assert(is_equal_approx(east_boundary.stats.heat, 25.0))
	for state in dispatch.get_response_states():
		assert(state in [&"returning", &"exiting"])

	var migrated_position := player.global_position + Vector3(5.0, 0.0, 0.0)
	player.global_position = migrated_position
	wanted.import_save_data({
		"wanted_level": 2,
		"trigger_territory_id": "hood_east",
	})
	assert(wanted.wanted_level == 2)
	assert(wanted.active_incident == null)
	wanted.rehydrate_incident_after_load()
	assert(wanted.active_incident != null)
	assert(wanted.active_incident.crime_type == PoliceIncident.CrimeType.UNKNOWN)
	assert(wanted.active_incident.last_known_player_position == migrated_position)
	wanted.clear_wanted(false)

	wanted.report_police_incident(
		player.global_position,
		PoliceIncident.CrimeType.ILLEGAL_ACTIVITY,
		1
	)
	wanted.set_wanted_level(1)
	var suspended_incident_id: int = wanted.active_incident.incident_id
	wanted.set_gang_war_suppressed(true)
	assert(wanted.wanted_level == 0)
	wanted.set_gang_war_suppressed(false)
	assert(wanted.wanted_level == 1)
	assert(wanted.active_incident.incident_id == suspended_incident_id)
	assert(wanted.active_incident.crime_type == PoliceIncident.CrimeType.ILLEGAL_ACTIVITY)
	wanted.clear_wanted(false)

	wanted.set_wanted_level(1)
	arrest.arrest_duration = 0.05
	for _frame in 8:
		arrest.report_police_contact()
		await process_frame
	assert(wanted.wanted_level == 0)
	assert(east_boundary.stats.heat <= 25.0)

	# A moving player vehicle keeps the response mounted and receives a live
	# road intercept. Stopping permits pull-over, but moving again before the
	# doors open cancels deployment and resumes the chase.
	dispatch.reset_for_load()
	var pursuit_vehicle_scene := load(
		"res://Scenes/Vehicles/MuscleCar.tscn"
	) as PackedScene
	var pursuit_vehicle := pursuit_vehicle_scene.instantiate() as BaseVehicle
	pursuit_vehicle.name = "PoliceTestMuscleCar"
	world.get_node("Gameplay").add_child(pursuit_vehicle)
	pursuit_vehicle.global_position = player.global_position
	assert(vehicle_component.enter_vehicle(pursuit_vehicle))
	pursuit_vehicle.linear_velocity = Vector3.FORWARD * 8.0
	wanted.report_police_incident(
		pursuit_vehicle.global_position,
		PoliceIncident.CrimeType.ILLEGAL_ACTIVITY,
		1
	)
	wanted.set_wanted_level(1)
	dispatch.call("_process", 0.0)
	var pursuit_responses := dispatch.get("_responses") as Array
	assert(pursuit_responses.size() == 1)
	var pursuit_response = pursuit_responses[0]
	assert(pursuit_response.state_name() == &"pursuing")
	dispatch.call("_tick_mobile_response", pursuit_response, 0.1)
	assert(pursuit_response.officers.is_empty())
	assert(pursuit_response.state_name() == &"pursuing")
	var first_intercept: Vector3 = pursuit_response.destination_position
	pursuit_vehicle.global_position += Vector3(60.0, 0.0, 24.0)
	assert(dispatch.call(
		"_retarget_dynamic_response",
		pursuit_response,
		pursuit_vehicle.global_position + pursuit_vehicle.linear_velocity * 0.75,
		false,
		&"test_pursuit_retarget"
	))
	assert(
		first_intercept.distance_to(pursuit_response.destination_position) > 3.0
	)
	pursuit_vehicle.linear_velocity = Vector3.ZERO
	pursuit_response.stationary_elapsed = dispatch.response_profile.stationary_deploy_seconds
	pursuit_response.cruiser.global_position = (
		pursuit_vehicle.global_position + Vector3.RIGHT * 10.0
	)
	dispatch.call("_tick_mobile_response", pursuit_response, 0.1)
	assert(pursuit_response.state_name() == &"pull_over")
	pursuit_vehicle.linear_velocity = Vector3.FORWARD * 8.0
	dispatch.call("_tick_pull_over", pursuit_response, 0.1)
	assert(pursuit_response.state_name() == &"pursuing")
	assert(pursuit_response.officers.is_empty())
	pursuit_response.recovery_count = 2
	pursuit_response.cruiser.global_position = (
		pursuit_vehicle.global_position + Vector3.RIGHT * 80.0
	)
	dispatch.call("_recover_stalled_response", pursuit_response)
	assert(
		pursuit_response.state_name() == &"exiting"
		or pursuit_response.finished
	)
	assert(pursuit_response.officers.is_empty())
	assert(vehicle_component.exit_vehicle(true))
	wanted.clear_wanted(false)
	dispatch.reset_for_load()

	# Hood West dispatch uses its own road and nearest shared response approach.
	var west_center := world.get_node(
		"Territories/HoodWest/TerritoryBoundary/CollisionShape3D"
	) as CollisionShape3D
	player.global_position = west_center.global_position
	wanted.report_police_incident(
		player.global_position,
		PoliceIncident.CrimeType.OFFICER_DOWN,
		3
	)
	wanted.set_wanted_level(3)
	assert(wanted.active_incident.territory_id == &"hood_west")
	for _cruiser_index in 3:
		dispatch.set("_launch_remaining", 0.0)
		dispatch.call("_process", 0.0)
	assert(dispatch.get_active_cruisers().size() == 3)
	var west_responses := dispatch.get("_responses") as Array
	var used_destinations: Array[Vector3] = []
	for response in west_responses:
		assert(response.destination_position.is_finite())
		for used_destination in used_destinations:
			assert(
				used_destination.distance_to(response.destination_position)
				>= dispatch.response_destination_separation
			)
		used_destinations.append(response.destination_position)
	var west_cruisers := dispatch.get_active_cruisers()
	for first_index in west_cruisers.size():
		for second_index in range(first_index + 1, west_cruisers.size()):
			assert(
				west_cruisers[first_index].global_position.distance_to(
					west_cruisers[second_index].global_position
				) >= dispatch.spawn_clearance
			)
	var cleanup_response = west_responses[0]
	cleanup_response.ai.clear()
	cleanup_response.cruiser.global_position = player.global_position + Vector3.RIGHT * 6.0
	var cleanup_population := cleanup_response.zone.get(
		"population"
	) as CivilianPopulationManager
	var cleanup_door := cleanup_response.cruiser.call(
		"get_officer_exit_position",
		0
	) as Vector3
	var cleanup_officer := cleanup_population.spawn_response_officer(
		cleanup_door,
		wanted.active_incident.incident_id,
		player.global_position
	)
	assert(cleanup_officer != null)
	cleanup_response.officers.assign([cleanup_officer])
	cleanup_response.seat_count = 1
	cleanup_response.state = PoliceDispatchController.ResponseUnit.State.ON_SCENE
	wanted.clear_wanted(false)
	assert(cleanup_response.state_name() == &"returning")
	assert(cleanup_response.return_positions.size() == 1)
	cleanup_officer.global_position = cleanup_response.return_positions[0]
	dispatch.call("_tick_officer_return", cleanup_response, 0.016)
	assert(cleanup_response.officers.is_empty())
	assert(cleanup_response.state_name() == &"exiting" or cleanup_response.finished)
	if not cleanup_response.finished:
		cleanup_response.cruiser.global_position = player.global_position
		cleanup_response.exit_coasting = true
		cleanup_response.exit_elapsed = 0.0
		dispatch.call("_tick_cruiser_exit", cleanup_response, 0.1)
		assert(not cleanup_response.finished)
		cleanup_response.exit_elapsed = dispatch.exit_coast_timeout
		dispatch.call("_tick_cruiser_exit", cleanup_response, 0.1)
		assert(cleanup_response.finished)

	print("POLICE_SYSTEM_SMOKE_TEST_PASS")
	quit(0)
