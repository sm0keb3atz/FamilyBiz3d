extends SceneTree


class PatrolProbe:
	extends Node3D

	var stop_calls := 0
	var advance_calls := 0
	var navigation_target := Vector3.ZERO


	func stop_moving(_delta: float) -> void:
		stop_calls += 1


	func set_navigation_target(target: Vector3) -> void:
		navigation_target = target


	func advance_navigation(_delta: float) -> void:
		advance_calls += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var controller := TrafficSignalController3D.new()
	root.add_child(controller)
	await process_frame
	assert(
		controller.get_signal_state(&"north_south")
		== TrafficSignalController3D.SignalState.GREEN
	)
	assert(
		controller.get_signal_state(&"east_west")
		== TrafficSignalController3D.SignalState.RED
	)
	controller.advance_phase_for_test()
	assert(
		controller.get_signal_state(&"north_south")
		== TrafficSignalController3D.SignalState.YELLOW
	)
	controller.advance_phase_for_test()
	assert(
		controller.get_signal_state(&"north_south")
		== TrafficSignalController3D.SignalState.RED
	)
	assert(
		controller.get_signal_state(&"east_west")
		== TrafficSignalController3D.SignalState.RED
	)
	controller.advance_phase_for_test()
	assert(
		controller.get_signal_state(&"east_west")
		== TrafficSignalController3D.SignalState.GREEN
	)
	controller.queue_free()

	var demand_intersection := TrafficIntersection3D.new()
	demand_intersection.intersection_id = &"demand_test_intersection"
	root.add_child(demand_intersection)
	var demand_controller := TrafficSignalController3D.new()
	demand_intersection.add_child(demand_controller)
	await process_frame
	var crossing_id := &"test_crosswalk"
	demand_controller.request_pedestrian_crossing(crossing_id, &"east_west")
	assert(
		demand_controller.get_pedestrian_state(crossing_id)
		== TrafficSignalController3D.PedestrianState.DONT_WALK
	)
	assert(demand_controller.is_vehicle_green_allowed())
	assert(
		not demand_controller.can_enter_pedestrian_crossing(
			crossing_id,
			5.0,
			&"east_west"
		)
	)
	demand_controller.advance_phase_for_test()
	demand_controller.advance_phase_for_test()
	demand_controller.advance_phase_for_test()
	demand_controller.advance_phase_for_test()
	demand_controller.advance_phase_for_test()
	var turning_car := Node.new()
	root.add_child(turning_car)
	assert(demand_intersection.try_reserve(turning_car, &"north_south_left"))
	demand_controller.advance_phase_for_test()
	assert(not demand_controller._pedestrian_phase_active)
	assert(
		demand_controller.get_signal_state(&"north_south")
		== TrafficSignalController3D.SignalState.RED
	)
	assert(
		demand_controller.get_signal_state(&"east_west")
		== TrafficSignalController3D.SignalState.RED
	)
	demand_intersection.release(turning_car)
	demand_controller.advance_phase_for_test()
	assert(demand_controller._pedestrian_phase_active)
	assert(not demand_controller.is_vehicle_green_allowed())
	assert(
		demand_controller.get_pedestrian_state(crossing_id)
		== TrafficSignalController3D.PedestrianState.WALK
	)
	assert(
		demand_controller.can_enter_pedestrian_crossing(
			crossing_id,
			5.0,
			&"east_west"
		)
	)
	demand_controller.set_crossing_occupancy(crossing_id, 1)
	demand_controller.advance_phase_for_test()
	assert(
		demand_controller.get_pedestrian_state(crossing_id)
		== TrafficSignalController3D.PedestrianState.CLEARANCE
	)
	assert(
		not demand_controller.can_enter_pedestrian_crossing(
			crossing_id,
			5.0,
			&"east_west"
		)
	)
	demand_controller.advance_phase_for_test()
	assert(demand_controller._pedestrian_phase_active)
	demand_controller.set_crossing_occupancy(crossing_id, 0)
	demand_controller.advance_phase_for_test()
	assert(not demand_controller._pedestrian_phase_active)
	assert(
		demand_controller.get_signal_state(&"north_south")
		== TrafficSignalController3D.SignalState.GREEN
	)
	turning_car.queue_free()
	demand_intersection.queue_free()

	var patrol_controller := TrafficSignalController3D.new()
	patrol_controller.controller_id = &"patrol_test_intersection"
	root.add_child(patrol_controller)
	var patrol_network := PedestrianNetwork3D.new()
	root.add_child(patrol_network)
	var patrol_curb_a := PedestrianWaypoint3D.new()
	patrol_curb_a.name = "CurbA"
	patrol_network.add_child(patrol_curb_a)
	var patrol_curb_b := PedestrianWaypoint3D.new()
	patrol_curb_b.name = "CurbB"
	patrol_curb_b.position = Vector3(0.0, 0.0, 10.0)
	patrol_network.add_child(patrol_curb_b)
	var patrol_crossing := PedestrianCrossing3D.new()
	patrol_crossing.crossing_id = &"patrol_test_crosswalk"
	patrol_crossing.intersection_id = &"patrol_test_intersection"
	patrol_crossing.curb_a_path = NodePath("../CurbA")
	patrol_crossing.curb_b_path = NodePath("../CurbB")
	patrol_network.add_child(patrol_crossing)
	patrol_network.rebuild_cache()
	patrol_controller.request_pedestrian_crossing(
		patrol_crossing.crossing_id,
		patrol_crossing.conflicting_signal_group
	)
	patrol_controller.advance_phase_for_test()
	patrol_controller.advance_phase_for_test()
	patrol_controller.advance_phase_for_test()
	patrol_controller.advance_phase_for_test()
	patrol_controller.advance_phase_for_test()
	patrol_controller.advance_phase_for_test()
	var patrol_probe := PatrolProbe.new()
	root.add_child(patrol_probe)
	var patrol_component := PedestrianPatrolComponent.new()
	patrol_probe.add_child(patrol_component)
	patrol_component.npc = patrol_probe
	patrol_component.network = patrol_network
	patrol_component.current_waypoint = patrol_curb_a
	patrol_component.target_waypoint = patrol_curb_b
	patrol_component.tick_patrol(0.1)
	assert(patrol_component._active_crossing == patrol_crossing)
	assert(patrol_probe.advance_calls == 1)
	var civilian_crossing_probe := CustomerNPC.new()
	civilian_crossing_probe._network = patrol_network
	civilian_crossing_probe._current_waypoint = patrol_curb_a
	civilian_crossing_probe._route_target = patrol_curb_b
	assert(
		bool(civilian_crossing_probe.call("_can_traverse_route_segment"))
	)
	assert(civilian_crossing_probe._active_route_crossing == patrol_crossing)
	assert(patrol_crossing.get_occupant_count() == 2)
	patrol_controller.advance_phase_for_test()
	patrol_component.tick_patrol(0.1)
	assert(patrol_probe.stop_calls == 0)
	assert(patrol_probe.advance_calls == 2)
	assert(
		bool(civilian_crossing_probe.call("_can_traverse_route_segment"))
	)
	patrol_component.clear()
	civilian_crossing_probe.call("_release_active_route_crossing")
	assert(patrol_crossing.get_occupant_count() == 0)
	patrol_controller.advance_phase_for_test()
	assert(
		not bool(civilian_crossing_probe.call("_can_traverse_route_segment"))
	)
	civilian_crossing_probe.free()
	patrol_probe.queue_free()
	patrol_network.queue_free()
	patrol_controller.queue_free()

	var reservation := TrafficIntersection3D.new()
	root.add_child(reservation)
	var vehicle_a := Node.new()
	var vehicle_b := Node.new()
	var vehicle_c := Node.new()
	root.add_child(vehicle_a)
	root.add_child(vehicle_b)
	root.add_child(vehicle_c)
	assert(reservation.try_reserve(vehicle_a, &"north_south"))
	assert(reservation.try_reserve(vehicle_b, &"north_south"))
	assert(not reservation.try_reserve(vehicle_c, &"east_west"))
	reservation.release(vehicle_a)
	reservation.release(vehicle_b)
	assert(reservation.try_reserve(vehicle_c, &"east_west"))
	reservation.release(vehicle_c)
	assert(reservation.try_reserve(vehicle_a, &"north_south_left"))
	assert(not reservation.try_reserve(vehicle_b, &"north_south_left"))
	reservation.queue_free()
	vehicle_a.queue_free()
	vehicle_b.queue_free()
	vehicle_c.queue_free()

	var port_network := TrafficNetwork3D.new()
	port_network.discover_territory_mobility = false
	root.add_child(port_network)
	var exit_port := TrafficWaypoint3D.new()
	exit_port.name = "TestExitPort"
	exit_port.spawn_allowed = false
	exit_port.is_external_connector = true
	exit_port.connector_id = &"test_boundary_lane"
	exit_port.connector_direction = TrafficWaypoint3D.ConnectorDirection.EXIT
	exit_port.role_flags = TrafficWaypoint3D.WaypointRole.EXIT
	port_network.add_child(exit_port)
	var entry_port := TrafficWaypoint3D.new()
	entry_port.name = "TestEntryPort"
	entry_port.position = Vector3(0.0, 0.0, 2.0)
	entry_port.spawn_allowed = false
	entry_port.is_external_connector = true
	entry_port.connector_id = &"test_boundary_lane"
	entry_port.connector_direction = TrafficWaypoint3D.ConnectorDirection.ENTRY
	entry_port.role_flags = TrafficWaypoint3D.WaypointRole.ENTRY
	port_network.add_child(entry_port)
	port_network.rebuild_cache()
	assert(port_network.find_route(exit_port, entry_port).size() == 2)
	entry_port.basis = Basis(Vector3.UP, PI)
	port_network.rebuild_cache()
	assert(port_network.find_route(exit_port, entry_port).is_empty())
	port_network.queue_free()

	var speed_control_probe := TrafficVehicleAIComponent.new()
	var distant_hard_stop := speed_control_probe.call(
		"_calculate_speed_controls",
		0.0,
		8.0,
		30.0,
		true,
		0.0
	) as Dictionary
	assert(float(distant_hard_stop.get("throttle", 0.0)) > 0.0)
	assert(float(distant_hard_stop.get("brake", 0.0)) == 0.0)
	var close_hard_stop := speed_control_probe.call(
		"_calculate_speed_controls",
		4.0,
		0.0,
		4.0,
		true,
		0.0
	) as Dictionary
	assert(float(close_hard_stop.get("throttle", 1.0)) == 0.0)
	assert(float(close_hard_stop.get("brake", 0.0)) > 0.0)
	assert(
		bool(
			speed_control_probe.call(
				"_should_hold_at_signal",
				TrafficSignalController3D.SignalState.RED,
				5.0,
				2.0
			)
		)
	)
	var committed_intersection := TrafficIntersection3D.new()
	speed_control_probe._reserved_intersection = committed_intersection
	assert(
		not bool(
			speed_control_probe.call(
				"_should_hold_at_signal",
				TrafficSignalController3D.SignalState.RED,
				5.0,
				2.0
			)
		)
	)
	speed_control_probe._reserved_intersection = null
	committed_intersection.free()
	var hold_stop_line := TrafficWaypoint3D.new()
	hold_stop_line.role_flags = TrafficWaypoint3D.WaypointRole.STOP_LINE
	var hold_movement := TrafficWaypoint3D.new()
	hold_movement.role_flags = TrafficWaypoint3D.WaypointRole.INTERSECTION_ENTRY
	speed_control_probe.current_waypoint = hold_stop_line
	speed_control_probe.target_waypoint = hold_movement
	assert(
		is_zero_approx(
			float(
				speed_control_probe.call(
					"_get_hold_stopping_distance",
					18.0
				)
			)
		)
	)
	speed_control_probe.current_waypoint = null
	speed_control_probe.target_waypoint = null
	hold_stop_line.free()
	hold_movement.free()
	speed_control_probe.free()

	var signal_root := Node3D.new()
	root.add_child(signal_root)
	var stop_controller := TrafficSignalController3D.new()
	stop_controller.name = "TrafficSignalController3D"
	signal_root.add_child(stop_controller)
	var stop_line := TrafficWaypoint3D.new()
	stop_line.is_stop_line = true
	stop_line.signal_group = &"east_west"
	stop_line.signal_controller_path = NodePath("../TrafficSignalController3D")
	signal_root.add_child(stop_line)
	await process_frame
	assert(stop_line.should_stop_for_signal())
	stop_controller.advance_phase_for_test()
	stop_controller.advance_phase_for_test()
	stop_controller.advance_phase_for_test()
	assert(not stop_line.should_stop_for_signal())
	signal_root.queue_free()

	var intersection_scene := load(
		"res://Scenes/Maps/RoadPieces/intersection.tscn"
	) as PackedScene
	assert(intersection_scene != null)
	var intersection := intersection_scene.instantiate()
	root.add_child(intersection)
	await process_frame
	var intersection_controller := intersection.get_node(
		"SignalController"
	) as TrafficSignalController3D
	assert(intersection_controller != null)
	for light_path in [
		"TrafficLights/NorthSouthLightA",
		"TrafficLights/NorthSouthLightB",
		"TrafficLights/EastWestLightA",
		"TrafficLights/EastWestLightB",
	]:
		var light := intersection.get_node(light_path) as TrafficSignalVisual3D
		assert(light != null)
		assert(light.get_signal_controller() == intersection_controller)
	assert(
		(intersection.get_node("TrafficLights/NorthSouthLightA") as TrafficSignalVisual3D)
		.get_active_state() == TrafficSignalController3D.SignalState.GREEN
	)
	assert(
		(intersection.get_node("TrafficLights/EastWestLightA") as TrafficSignalVisual3D)
		.get_active_state() == TrafficSignalController3D.SignalState.RED
	)
	var red_light_blocker := intersection.get_node(
		"TrafficLights/EastWestLightA/RedSignalBlocker/CollisionShape3D"
	) as CollisionShape3D
	assert(red_light_blocker != null)
	assert(red_light_blocker.disabled)
	assert(
		(
			intersection.get_node(
				"TrafficLights/EastWestLightA/RedSignalBlocker"
			) as Area3D
		).collision_layer == 0
	)
	intersection.queue_free()

	var edge_scene := load(
		"res://Scenes/Maps/RoadPieces/EdgeIntersection.tscn"
	) as PackedScene
	var corner_scene := load(
		"res://Scenes/Maps/RoadPieces/CornerInterSection.tscn"
	) as PackedScene
	assert(edge_scene != null and corner_scene != null)
	var edge_intersection := edge_scene.instantiate()
	var corner_intersection := corner_scene.instantiate()
	root.add_child(edge_intersection)
	root.add_child(corner_intersection)
	assert(edge_intersection.get_node("TrafficLights").get_child_count() == 3)
	assert(corner_intersection.get_node("TrafficLights").get_child_count() == 2)
	var edge_main_a := edge_intersection.get_node(
		"TrafficLights/MainLightA"
	) as TrafficSignalVisual3D
	var edge_main_b := edge_intersection.get_node(
		"TrafficLights/MainLightB"
	) as TrafficSignalVisual3D
	var edge_stem := edge_intersection.get_node(
		"TrafficLights/StemLight"
	) as TrafficSignalVisual3D
	assert(edge_main_a.signal_group == &"north_south")
	assert(edge_main_b.signal_group == &"east_west")
	assert(edge_stem.signal_group == &"east_west")
	var corner_light_a := corner_intersection.get_node(
		"TrafficLights/BendLightA"
	) as TrafficSignalVisual3D
	var corner_light_b := corner_intersection.get_node(
		"TrafficLights/BendLightB"
	) as TrafficSignalVisual3D
	assert(corner_light_a.signal_group == &"north_south")
	assert(corner_light_b.signal_group == &"east_west")
	edge_intersection.queue_free()
	corner_intersection.queue_free()

	var world_scene := load(
		"res://Scenes/Maps/World/world.tscn"
	) as PackedScene
	assert(world_scene != null)
	var world := world_scene.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	var east_routes := world.get_node(
		"Territories/HoodEast/Mobility/TrafficRoutes"
	) as HoodEastTrafficRoutes3D
	assert(
		east_routes._preview_mesh_instance == null
		or not east_routes._preview_mesh_instance.visible
	)
	var authored_intersections := {
		"Territories/HoodEast/HoodEastBlock1/Roads/Intersection4": &"hood_east_south_west",
		"Territories/HoodEast/HoodEastBlock1/Roads/Intersection3": &"hood_east_south_east",
		"Territories/HoodEast/HoodEastBlock1/Roads/Intersection7": &"hood_east_mid_west",
		"Territories/HoodEast/HoodEastBlock1/Roads/Intersection2": &"hood_east_mid_east",
		"Territories/HoodEast/HoodEastBlock2/Roads/Intersection5": &"hood_east_north_west",
		"Territories/HoodEast/HoodEastBlock2/Roads/Intersection6": &"hood_east_north_east",
	}
	for intersection_path in authored_intersections:
		var road_intersection := world.get_node(intersection_path) as TrafficIntersectionVisual3D
		var controller_id := authored_intersections[intersection_path] as StringName
		assert(road_intersection.intersection_id == controller_id)
		var territory_controller := TrafficSignalController3D.find(self, controller_id)
		assert(territory_controller != null)
		var bound_light_count := 0
		var visible_signal_groups := {}
		for child in road_intersection.find_children(
			"*", "TrafficSignalVisual3D", true, false
		):
			var bound_light := child as TrafficSignalVisual3D
			assert(bound_light.get_signal_controller() == territory_controller)
			visible_signal_groups[bound_light.signal_group] = true
			bound_light_count += 1
		assert(bound_light_count >= 2)
		for waypoint in east_routes.find_children(
			"*", "TrafficWaypoint3D", true, false
		):
			var authored_stop_line := waypoint as TrafficWaypoint3D
			if (
				authored_stop_line.is_stop_line
				and authored_stop_line.intersection_id == controller_id
			):
				assert(visible_signal_groups.has(authored_stop_line.signal_group))

	var corner_controller := TrafficSignalController3D.find(
		self,
		&"hood_east_north_west"
	)
	assert(corner_controller != null)
	assert(not corner_controller.single_vehicle_group)
	assert(
		corner_controller.get_signal_state(&"north_south")
		== TrafficSignalController3D.SignalState.GREEN
	)
	corner_controller.advance_phase_for_test()
	corner_controller.advance_phase_for_test()
	corner_controller.advance_phase_for_test()
	assert(
		corner_controller.get_signal_state(&"east_west")
		== TrafficSignalController3D.SignalState.GREEN
	)
	corner_controller.advance_phase_for_test()
	corner_controller.advance_phase_for_test()
	corner_controller.advance_phase_for_test()

	var east_network := world.get_node(
		"Navigation/CityTrafficNetwork"
	) as TrafficNetwork3D
	var west_network := world.get_node(
		"Navigation/HoodWestTrafficNetwork"
	) as TrafficNetwork3D
	assert(east_network != null)
	assert(west_network != null)
	east_network.rebuild_cache()
	west_network.rebuild_cache()
	assert(east_network.get_waypoint_count() > 0)
	assert(east_network.get_connection_count() > 0)
	var east_validation := east_network.get_validation_errors()
	assert(east_validation.is_empty(), str(east_validation))
	assert(east_network.get_entry_waypoints().size() >= 5)
	assert(east_network.get_exit_waypoints().size() >= 5)
	assert(east_network.get_dispatch_candidates().size() >= 5)
	var eastbound_lane := east_routes.get_node(
		"Road_SW_SE_E"
	) as TrafficWaypoint3D
	var westbound_lane := east_routes.get_node(
		"Road_SE_SW_W"
	) as TrafficWaypoint3D
	assert(eastbound_lane.position.distance_to(westbound_lane.position) >= 6.0)
	var crosses_both_blocks := false
	for entry in east_network.get_entry_waypoints():
		var reachable_exits := east_network.get_reachable_exits(entry)
		assert(not reachable_exits.is_empty())
		for exit_waypoint in reachable_exits:
			var route := east_network.find_route(entry, exit_waypoint)
			assert(route.size() >= 2)
			var minimum_z := INF
			var maximum_z := -INF
			for waypoint in route:
				minimum_z = minf(minimum_z, waypoint.global_position.z)
				maximum_z = maxf(maximum_z, waypoint.global_position.z)
			if minimum_z < -100.0 and maximum_z > 90.0:
				crosses_both_blocks = true
	assert(crosses_both_blocks)
	var pedestrian_network := world.get_node(
		"Territories/HoodEast/Mobility/PedestrianNetwork"
	) as PedestrianNetwork3D
	assert(pedestrian_network != null)
	assert(pedestrian_network.get_validation_errors().is_empty())
	var destination_count := 0
	for waypoint in pedestrian_network.get_waypoints():
		if waypoint.has_role(PedestrianWaypoint3D.WaypointRole.DESTINATION):
			destination_count += 1
	assert(destination_count >= 6)
	var south_curb := pedestrian_network.get_node(
		"SouthNorthWest"
	) as PedestrianWaypoint3D
	var north_curb := pedestrian_network.get_node(
		"NorthSouthWest"
	) as PedestrianWaypoint3D
	var pedestrian_route := pedestrian_network.find_path(south_curb, north_curb)
	assert(pedestrian_route.size() == 2)
	assert(pedestrian_network.path_requires_crossing(pedestrian_route))
	if west_network.get_waypoint_count() > 0:
		assert(west_network.get_connection_count() > 0)
		assert(west_network.get_validation_errors().is_empty())

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var parked_vehicle: BaseVehicle = world.get_node("Gameplay/MuscleCar")
	assert(parked_vehicle.drive_component is VehicleDriveComponent)
	parked_vehicle.drive_component.set_ai_control(0.5, 0.0, 0.1)
	assert(parked_vehicle.drive_component.is_ai_control_enabled())
	parked_vehicle.drive_component.clear_ai_control()
	assert(not parked_vehicle.drive_component.is_ai_control_enabled())

	var east_manager := world.get_node(
		"TrafficPopulationManager"
	) as TrafficPopulationManager
	var west_manager := world.get_node(
		"WestTrafficPopulationManager"
	) as TrafficPopulationManager
	assert(east_manager != null)
	assert(west_manager != null)
	west_manager.set_population_enabled(false)
	east_manager.set_population_enabled(false)
	east_manager.minimum_spawn_distance = 0.0
	east_manager.maximum_spawn_distance = 500.0
	east_manager.recycle_distance = 500.0
	east_manager.active_target = 2
	east_manager.pool_capacity = 4
	assert(east_manager.populate_immediately(2) == 2)
	assert(east_manager.get_active_count() == 2)
	assert(east_manager.get_live_pool_count() <= east_manager.pool_capacity)
	await process_frame
	await physics_frame

	for traffic_vehicle in east_manager.get_active_vehicles():
		assert(traffic_vehicle is BaseVehicle)
		assert(traffic_vehicle.is_managed_traffic())
		assert(traffic_vehicle.is_in_group("traffic_vehicle"))
		assert(not traffic_vehicle.can_interact(player))
		var ai := traffic_vehicle.get_node_or_null(
			"TrafficAIComponent"
		) as TrafficVehicleAIComponent
		assert(ai != null)
		assert(ai.has_route())
		assert(ai.get_current_waypoint() != null)
		assert(ai.get_target_waypoint() != null)

	print("TRAFFIC_SMOKE_TEST_PASS")
	quit(0)
