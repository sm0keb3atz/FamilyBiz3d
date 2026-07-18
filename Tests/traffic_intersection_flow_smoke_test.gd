extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world_scene := load("res://Scenes/Maps/World/world.tscn") as PackedScene
	assert(world_scene != null)
	var world := world_scene.instantiate()
	root.add_child(world)
	var civilians := world.get_node(
		"CivilianPopulationManager"
	) as CivilianPopulationManager
	var west_civilians := world.get_node(
		"WestPopulationManager"
	) as CivilianPopulationManager
	civilians.set_population_enabled(false)
	west_civilians.set_population_enabled(false)
	var west_traffic := world.get_node(
		"WestTrafficPopulationManager"
	) as TrafficPopulationManager
	west_traffic.set_population_enabled(false)
	var manager := world.get_node(
		"TrafficPopulationManager"
	) as TrafficPopulationManager
	manager.set_population_enabled(false)
	await process_frame
	await physics_frame

	for controller_node in get_nodes_in_group(&"traffic_signal_controller"):
		var controller := controller_node as TrafficSignalController3D
		if controller == null or controller.controller_id == &"":
			continue
		controller.green_duration = 8.0
		controller.yellow_duration = 2.0
		controller.all_red_duration = 0.5
		controller.call("_set_phase", 0)

	manager.minimum_spawn_distance = 0.0
	manager.maximum_spawn_distance = 500.0
	manager.high_detail_distance = 500.0
	manager.recycle_distance = 500.0
	manager.active_target = 6
	manager.pool_capacity = 8
	var requested_seed := OS.get_environment("TRAFFIC_TEST_SEED")
	manager._random.seed = (
		int(requested_seed) if requested_seed.is_valid_int() else 12345
	)
	manager.set_population_enabled(true)
	assert(manager.populate_immediately(6) == 6)
	await physics_frame

	var changes := {}
	var last_waypoints := {}
	var stopped_inside_frames := {}
	var maximum_stopped_inside_frames := {}
	var maximum_stopped_entry_progress := {}
	for vehicle in manager.get_active_vehicles():
		var id := int(vehicle.get_instance_id())
		changes[id] = 0
		stopped_inside_frames[id] = 0
		maximum_stopped_inside_frames[id] = 0
		maximum_stopped_entry_progress[id] = 0.0

	for _frame in range(1200):
		await physics_frame
		for vehicle in manager.get_active_vehicles():
			var ai := vehicle.get_node_or_null(
				"TrafficAIComponent"
			) as TrafficVehicleAIComponent
			if ai == null:
				continue
			var id := int(vehicle.get_instance_id())
			var current := ai.get_current_waypoint()
			if last_waypoints.has(id) and last_waypoints[id] != current:
				changes[id] = int(changes.get(id, 0)) + 1
			last_waypoints[id] = current
			var target := ai.get_target_waypoint()
			if (
				current != null
				and target != null
				and current.has_role(TrafficWaypoint3D.WaypointRole.STOP_LINE)
				and target.has_role(
					TrafficWaypoint3D.WaypointRole.INTERSECTION_ENTRY
				)
				and vehicle.linear_velocity.length() < 0.35
			):
				var entry_direction := target.global_position - current.global_position
				entry_direction.y = 0.0
				if not entry_direction.is_zero_approx():
					entry_direction = entry_direction.normalized()
					var from_stop_line := vehicle.global_position - current.global_position
					from_stop_line.y = 0.0
					maximum_stopped_entry_progress[id] = maxf(
						float(maximum_stopped_entry_progress.get(id, 0.0)),
						from_stop_line.dot(entry_direction)
					)
			var is_inside_intersection := (
				current != null
				and target != null
				and current.has_role(
					TrafficWaypoint3D.WaypointRole.INTERSECTION_ENTRY
				)
				and target.has_role(
					TrafficWaypoint3D.WaypointRole.INTERSECTION_EXIT
				)
			)
			if is_inside_intersection and vehicle.linear_velocity.length() < 0.35:
				stopped_inside_frames[id] = int(
					stopped_inside_frames.get(id, 0)
				) + 1
				maximum_stopped_inside_frames[id] = maxi(
					int(maximum_stopped_inside_frames.get(id, 0)),
					int(stopped_inside_frames[id])
				)
			else:
				stopped_inside_frames[id] = 0

	var progressing_vehicles := 0
	for count: int in changes.values():
		if count >= 1:
			progressing_vehicles += 1
	for stopped_frames: int in maximum_stopped_inside_frames.values():
		if stopped_frames >= 180:
			_fail_test(
				"Vehicle stopped inside intersection: %s; diagnostics: %s"
				% [
					str(maximum_stopped_inside_frames),
					str(_get_vehicle_diagnostics(manager)),
				]
			)
			return
	for entry_progress: float in maximum_stopped_entry_progress.values():
		if entry_progress > 4.0:
			_fail_test(
				"Vehicle stopped past the stop line: %s; diagnostics: %s"
				% [
					str(maximum_stopped_entry_progress),
					str(_get_vehicle_diagnostics(manager)),
				]
			)
			return
	if progressing_vehicles < 3:
		_fail_test("Too few vehicles advanced: %s" % str(changes))
		return
	print("TRAFFIC_INTERSECTION_FLOW_SMOKE_TEST_PASS")
	quit(0)


func _get_vehicle_diagnostics(manager: TrafficPopulationManager) -> Array:
	var diagnostics := []
	for vehicle in manager.get_active_vehicles():
		var ai := vehicle.get_node_or_null(
			"TrafficAIComponent"
		) as TrafficVehicleAIComponent
		if ai == null:
			continue
		var current := ai.get_current_waypoint()
		var target := ai.get_target_waypoint()
		var target_intersection := (
			TrafficIntersection3D.find(self, target.intersection_id)
			if target != null and target.intersection_id != &""
			else null
		)
		diagnostics.append({
			"id": int(vehicle.get_instance_id()),
			"current": current.name if current != null else "none",
			"target": target.name if target != null else "none",
			"speed": vehicle.linear_velocity.length(),
			"hard_stop": ai.is_hard_stop_active(),
			"ray_blocked": ai._last_raycast_blocked,
			"ray_distance": ai._last_raycast_distance,
			"reserved": ai._reserved_intersection != null,
			"intersection_reservations": (
				target_intersection.get_reserved_count()
				if target_intersection != null else -1
			),
		})
	return diagnostics


func _fail_test(message: String) -> void:
	push_error(message)
	quit(1)
