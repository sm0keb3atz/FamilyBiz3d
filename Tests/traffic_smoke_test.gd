extends SceneTree


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

	var signal_root := Node3D.new()
	root.add_child(signal_root)
	var stop_controller := TrafficSignalController3D.new()
	signal_root.add_child(stop_controller)
	var stop_line := TrafficWaypoint3D.new()
	stop_line.is_stop_line = true
	stop_line.signal_group = &"east_west"
	signal_root.add_child(stop_line)
	await process_frame
	assert(stop_line.should_stop_for_signal())
	stop_controller.advance_phase_for_test()
	stop_controller.advance_phase_for_test()
	stop_controller.advance_phase_for_test()
	assert(not stop_line.should_stop_for_signal())
	signal_root.queue_free()

	var world_scene := load(
		"res://Scenes/Maps/World/world.tscn"
	) as PackedScene
	assert(world_scene != null)
	var world := world_scene.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame

	var east_network := world.get_node(
		"Navigation/HoodEastTrafficNetwork"
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
	assert(east_network.get_validation_errors().is_empty())
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
