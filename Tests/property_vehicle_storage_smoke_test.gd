extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (
		load("res://Scenes/Maps/World/world.tscn") as PackedScene
	).instantiate()
	root.add_child(world)
	world.get_node("CivilianPopulationManager").set_population_enabled(false)
	await process_frame
	await physics_frame

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var properties := player.get_node(
		"Components/PropertyComponent"
	) as PlayerPropertyComponent
	var wallet := player.get_node(
		"Components/WalletComponent"
	) as PlayerWalletComponent
	var garage := player.get_node(
		"Components/VehicleGarageComponent"
	) as PlayerVehicleGarageComponent
	var property_id := &"hood_east_house_1"
	var definition := PropertyCatalog.get_by_id(property_id)
	var property_ids: Array[StringName] = [
		property_id,
		&"hood_east_house_2",
		&"hood_east_house_3",
		&"hood_east_house_4",
	]
	for hood_property_id in property_ids:
		assert(
			PropertyCatalog.get_by_id(
				hood_property_id
			).vehicle_storage_capacity == 2
		)
	assert(wallet.add_clean(definition.purchase_price * property_ids.size(), false))
	for hood_property_id in property_ids:
		assert(properties.purchase(hood_property_id))

	var building: PropertyBuilding
	var verified_garages := 0
	for node in get_nodes_in_group(&"property_buildings"):
		var candidate := node as PropertyBuilding
		if candidate == null or not property_ids.has(candidate.property_id):
			continue
		var candidate_controller := (
			candidate.get_node("Garage") as PropertyGarageController
		)
		assert(candidate_controller != null and candidate_controller.is_available())
		verified_garages += 1
		if candidate.property_id == property_id:
			building = candidate
	assert(verified_garages == property_ids.size())
	assert(building != null)
	var controller := building.get_node("Garage") as PropertyGarageController
	assert(controller != null and controller.is_available())
	assert(controller.get_node("GarageArea") is Area3D)
	assert(controller.get_node("CarSpawn") is Marker3D)
	assert(controller.get_node("SpawnClearance") is Area3D)
	assert(controller.get_node("GarageInteraction") is PropertyGarageInteraction)
	var blocker := CharacterBody3D.new()
	var blocker_shape := CollisionShape3D.new()
	blocker_shape.shape = BoxShape3D.new()
	(blocker_shape.shape as BoxShape3D).size = Vector3(1, 2, 1)
	blocker.add_child(blocker_shape)
	world.get_node("Gameplay").add_child(blocker)
	blocker.global_position = controller.get_spawn_transform().origin + Vector3.UP
	await physics_frame
	assert(controller.get_spawn_block_reason().contains("people"))
	blocker.get_parent().remove_child(blocker)
	blocker.queue_free()
	await physics_frame

	var container := player.get_parent() as Node3D
	var first := garage.spawn_new_vehicle(
		&"pickup_old",
		Transform3D(Basis.IDENTITY, Vector3(10, 1, 10)),
		container
	)
	var second := garage.spawn_new_vehicle(
		&"sedan",
		Transform3D(Basis.IDENTITY, Vector3(16, 1, 10)),
		container
	)
	var third := garage.spawn_new_vehicle(
		&"van",
		Transform3D(Basis.IDENTITY, Vector3(22, 1, 10)),
		container
	)
	assert(first != null and second != null and third != null)
	var first_id := garage.get_owned_instance_id(first)
	var second_id := garage.get_owned_instance_id(second)
	var third_id := garage.get_owned_instance_id(third)
	assert(bool(garage.store_vehicle(property_id, first).success))
	assert(bool(garage.store_vehicle(property_id, second).success))
	assert(garage.get_stored_count(property_id) == 2)
	var full_result := garage.store_vehicle(property_id, third)
	assert(not bool(full_result.success))
	assert(String(full_result.message).contains("full"))

	var retrieve_result := garage.retrieve_vehicle(
		property_id,
		first_id,
		Transform3D(Basis.IDENTITY, Vector3(28, 1, 10)),
		container
	)
	assert(bool(retrieve_result.success))
	var retrieved := retrieve_result.vehicle as BaseVehicle
	assert(retrieved != null)
	assert(garage.get_owned_instance_id(retrieved) == first_id)
	assert(garage.get_stored_count(property_id) == 1)
	assert(bool(garage.store_vehicle(property_id, third).success))
	assert(garage.get_stored_count(property_id) == 2)

	var non_owned := (
		VehicleCatalog.get_scene(&"muscle") as PackedScene
	).instantiate() as BaseVehicle
	container.add_child(non_owned)
	var non_owned_result := garage.store_vehicle(property_id, non_owned)
	assert(not bool(non_owned_result.success))
	non_owned.queue_free()

	var saved := garage.export_save_data()
	garage.import_save_data(saved, container)
	await process_frame
	assert(garage.get_owned_count() == 3)
	assert(garage.get_stored_count(property_id) == 2)
	assert(garage.get_vehicle_record(second_id).is_stored)
	assert(garage.get_vehicle_record(third_id).is_stored)
	assert(not garage.get_vehicle_record(first_id).is_stored)

	var legacy := {
		"next_instance_number": 2,
		"owned": [{
			"instance_id": "vehicle_000001",
			"vehicle_id": "sedan",
			"position": [40.0, 1.0, 40.0],
			"yaw": 0.0,
		}],
	}
	garage.import_save_data(legacy, container)
	await process_frame
	assert(garage.get_owned_count() == 1)
	assert(garage.get_stored_count(property_id) == 0)
	assert(garage.get_owned_vehicles().size() == 1)

	garage.import_save_data(saved, container)
	await process_frame
	properties.forfeit_stash_houses()
	await process_frame
	assert(not properties.owns(property_id))
	assert(garage.get_stored_count(property_id) == 0)
	assert(garage.get_owned_count() == 1)
	assert(not garage.get_vehicle_record(first_id).is_empty())

	assert(wallet.add_clean(definition.purchase_price, false))
	assert(properties.purchase(property_id))
	var hub := player.get_node("PropertyStashMenu") as PropertyStashMenu
	hub.open_local(building, &"stash")
	assert((hub.get_node("MenuRoot") as Control).visible)
	assert(hub.find_child("StashTab", true, false) != null)
	assert(hub.find_child("GarageTab", true, false) != null)
	assert(hub.find_child("OperationsTab", true, false) != null)
	assert(hub.find_child("InventoryGrid", true, false) != null)
	assert(hub.find_child("StashGrid", true, false) != null)
	hub.close()
	hub.open_remote(property_id, &"stash")
	var transfer := hub.find_child("TransferButton", true, false) as Button
	if transfer != null:
		assert(transfer.disabled)
	hub.call("_set_tab", &"operations")
	assert(hub.find_child("BrickStationStatus", true, false) != null)
	hub.close()

	print("PROPERTY_VEHICLE_STORAGE_SMOKE_TEST_PASS")
	quit(0)
