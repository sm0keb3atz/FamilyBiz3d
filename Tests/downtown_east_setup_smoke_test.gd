extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://Scenes/Maps/World/world.tscn") as PackedScene
	assert(scene != null)
	var world := scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	await physics_frame

	var downtown := world.get_node("Territories/DowntownEast") as Node3D
	var boundary := downtown.get_node("TerritoryBoundary") as TerritoryBoundary
	var stats := downtown.get_node("TerritoryStats") as TerritoryStatsComponent
	assert(boundary.territory_id == &"downtown_east")
	assert(boundary.display_name == "Downtown East")
	assert(boundary.stats == stats)
	assert(stats.territory_id == &"downtown_east")
	assert(stats.owner_faction == TerritoryStatsComponent.OwnerFaction.RIVAL)
	var boundary_shape := boundary.get_node("CollisionShape3D") as CollisionShape3D
	var territory_center := boundary_shape.global_position
	assert(TerritoryBoundary.find_at_position(self, territory_center) == boundary)
	var hood_east := world.get_node(
		"Territories/HoodEast/TerritoryBoundary"
	) as TerritoryBoundary
	var hood_side_of_avenue := Vector3(124.5, 0.0, 0.0)
	var downtown_side_of_avenue := Vector3(126.0, 0.0, 0.0)
	assert(hood_east.contains_world_position(hood_side_of_avenue))
	assert(not hood_east.contains_world_position(downtown_side_of_avenue))
	assert(boundary.contains_world_position(downtown_side_of_avenue))
	assert(
		TerritoryBoundary.find_at_position(self, downtown_side_of_avenue)
		== boundary
	)

	var mobility := downtown.get_node("Mobility") as TerritoryMobility3D
	var routes := mobility.get_traffic_routes() as HoodEastTrafficRoutes3D
	var pedestrians := mobility.get_pedestrian_network()
	assert(mobility.territory_id == &"downtown_east")
	assert(routes.territory_id == &"downtown_east")
	assert(routes.find_children("*", "TrafficWaypoint3D", true, false).size() > 60)
	var city_network := world.get_node(
		"Navigation/CityTrafficNetwork"
	) as TrafficNetwork3D
	assert(city_network.has_waypoint(routes.get_node("SE_In_N") as TrafficWaypoint3D))
	assert(pedestrians != null)
	assert(pedestrians.get_waypoint_count() >= 30)
	assert(pedestrians.get_validation_errors().is_empty())
	for child in pedestrians.find_children("*", "PedestrianWaypoint3D", true, false):
		var waypoint := child as PedestrianWaypoint3D
		if waypoint.destination_id != &"":
			assert(String(waypoint.destination_id).begins_with("downtown_east_"))
	for child in pedestrians.find_children("*", "PedestrianCrossing3D", true, false):
		var crossing := child as PedestrianCrossing3D
		assert(String(crossing.crossing_id).begins_with("downtown_east_"))
		assert(String(crossing.intersection_id).begins_with("downtown_east_"))

	var authored_intersections := {
		"DowntownEastBlock1/Roads/Intersection4": {
			"controller": &"downtown_east_south_east",
			"grid": Vector3(127, 0.2, -123),
		},
		"DowntownEastBlock1/Roads/Intersection3": {
			"controller": &"downtown_east_mid_east",
			"grid": Vector3(127, 0.2, -3),
		},
		"DowtownEastBlock2/Roads/Intersection6": {
			"controller": &"downtown_east_north_east",
			"grid": Vector3(127, 0.2, 133),
		},
	}
	for path in authored_intersections:
		var visual := downtown.get_node(path) as TrafficIntersectionVisual3D
		var expected := authored_intersections[path] as Dictionary
		var controller_id := expected.controller as StringName
		assert(visual.intersection_id == controller_id)
		assert(TrafficSignalController3D.find(self, controller_id) != null)
		var route_center := routes.global_transform * (expected.grid as Vector3)
		assert(route_center.distance_to(visual.global_position) < 1.0)
		for child in visual.find_children("*", "TrafficSignalVisual3D", true, false):
			var traffic_light := child as TrafficSignalVisual3D
			assert(traffic_light.get_signal_controller() != null)
			assert(traffic_light.get_signal_controller().controller_id == controller_id)

	var population := world.get_node("CivilianPopulationManager") as CivilianPopulationManager
	assert(population.get_network_count() == 3)
	var downtown_zones := get_nodes_in_group(&"dealer_activity_zone").filter(
		func(node: Node) -> bool:
			return (node as DealerActivityZone3D).territory_id == &"downtown_east"
	)
	assert(downtown_zones.size() == 2)
	for node in downtown_zones:
		var zone := node as DealerActivityZone3D
		assert(zone.get_required_member_count() == 3)
		assert(not zone.get_living_dealers().is_empty())
		assert(boundary.contains_world_position(zone.global_position))
	var wholesaler := world.get_node(
		"SpawnPoints/DowntownWholesalerSpawn"
	) as WholesalerSpawnPoint3D
	assert(wholesaler.territory_id == &"downtown_east")
	assert(boundary.contains_world_position(wholesaler.global_position))
	assert(wholesaler._territory_stats == stats)
	assert(wholesaler.get_offer_product() != null)
	assert(wholesaler.get_spawned_wholesaler() == null)
	stats.set_reputation(100.0)
	await process_frame
	assert(wholesaler.get_spawned_wholesaler() != null)

	var dispatch := world.get_node(
		"PoliceDispatchController"
	) as PoliceDispatchController
	assert(dispatch._zone_runtime.has(&"downtown_east"))
	assert(world.has_node("Navigation/DowntownEastNavigation"))
	assert(
		downtown.find_children("*", "CarDealershipController", true, false).size()
		== 1
	)

	var market := world.get_node("TerritoryMarketService") as TerritoryMarketService
	assert(market.get_buy_quote(&"downtown_east", EconomyCatalog.WEED_1G) > 0)
	print("DOWNTOWN_EAST_SETUP_SMOKE_TEST_PASS")
	world.queue_free()
	await process_frame
	await process_frame
	quit(0)
