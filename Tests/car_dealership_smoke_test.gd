extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definitions := VehicleCatalog.get_all()
	assert(definitions.size() == 10)
	var seen := {}
	for catalog_index in definitions.size():
		var definition := definitions[catalog_index]
		assert(definition != null)
		assert(not definition.vehicle_id.is_empty())
		assert(not seen.has(definition.vehicle_id))
		seen[definition.vehicle_id] = true
		assert(definition.catalog_order == catalog_index)
		assert(definition.purchase_price > 0)
		assert(definition.acceleration_rating in range(1, 6))
		assert(definition.handling_rating in range(1, 6))
		assert(definition.braking_rating in range(1, 6))
		assert(VehicleCatalog.get_resale_value(definition.vehicle_id)
			== definition.purchase_price * 60 / 100)
		var scene := VehicleCatalog.get_scene(definition.vehicle_id)
		assert(scene != null)
		var sample := scene.instantiate() as BaseVehicle
		assert(sample != null and sample.definition == definition)
		root.add_child(sample)
		await process_frame
		assert(sample.get_node("WheelFL") is VehicleWheel3D)
		assert(sample.get_node("WheelFR") is VehicleWheel3D)
		assert(sample.get_node("WheelRL") is VehicleWheel3D)
		assert(sample.get_node("WheelRR") is VehicleWheel3D)
		assert(sample.has_valid_wheel_bones())
		sample.queue_free()
		await process_frame
	assert(VehicleCatalog.get_by_id(&"sport_classic_02").max_forward_speed
		> VehicleCatalog.get_by_id(&"muscle").max_forward_speed)
	assert(VehicleCatalog.get_by_id(&"muscle").max_forward_speed
		> VehicleCatalog.get_by_id(&"sedan").max_forward_speed)
	assert(VehicleCatalog.get_by_id(&"van").handling_rating
		< VehicleCatalog.get_by_id(&"sport_classic_01a").handling_rating)

	var container := Node3D.new()
	container.name = "DealershipTestWorld"
	root.add_child(container)
	var player_scene := load("res://Scenes/Player.tscn") as PackedScene
	var player := player_scene.instantiate() as CharacterBody3D
	container.add_child(player)
	var dealership_scene := load(
		"res://Scenes/Maps/Buildings/CarDealership.tscn"
	) as PackedScene
	var dealership := dealership_scene.instantiate() as CarDealershipController
	container.add_child(dealership)
	await process_frame
	await physics_frame
	assert(dealership.get_bay_count() == 6)

	var wallet := player.get_node(
		"Components/WalletComponent"
	) as PlayerWalletComponent
	var garage := player.get_node(
		"Components/VehicleGarageComponent"
	) as PlayerVehicleGarageComponent
	var service := player.get_node(
		"Components/CarDealershipService"
	) as CarDealershipService
	assert(wallet.add_clean(100000, false))
	var invalid_definition := VehicleDefinition.new()
	invalid_definition.vehicle_id = &"not_in_dealership"
	invalid_definition.purchase_price = 1
	assert(service.purchase_vehicle(invalid_definition, dealership) == null)
	assert(wallet.clean_cash == 100000)
	assert(garage.get_owned_count() == 0)
	var old_pickup := VehicleCatalog.get_by_id(&"pickup_old")
	var first := service.purchase_vehicle(old_pickup, dealership)
	var second := service.purchase_vehicle(old_pickup, dealership)
	assert(first != null and second != null and first != second)
	assert(first.global_position != second.global_position)
	assert(wallet.clean_cash == 88000)
	assert(garage.get_owned_count() == 2)
	assert(garage.get_owned_count(&"pickup_old") == 2)
	assert(garage.owns_vehicle(first))
	assert(not garage.get_owned_instance_id(first).is_empty())
	for index in 4:
		assert(service.purchase_vehicle(old_pickup, dealership) != null)
	assert(garage.get_owned_count() == 6)
	var full_lot_balance := wallet.clean_cash
	assert(service.purchase_vehicle(old_pickup, dealership) == null)
	assert(wallet.clean_cash == full_lot_balance)
	assert(garage.get_owned_count() == 6)
	garage.import_save_data({}, container)
	await process_frame
	first = service.purchase_vehicle(old_pickup, dealership)
	second = service.purchase_vehicle(old_pickup, dealership)
	assert(first != null and second != null)
	assert(wallet.clean_cash == 52000)

	await physics_frame
	await physics_frame
	var parked := dealership.get_parked_owned_vehicles(garage)
	assert(parked.has(first) and parked.has(second))
	var non_owned_scene := VehicleCatalog.get_scene(&"muscle")
	var non_owned := non_owned_scene.instantiate() as BaseVehicle
	container.add_child(non_owned)
	non_owned.global_transform = first.global_transform
	await physics_frame
	assert(not service.sell_vehicle(non_owned, dealership))
	assert(wallet.clean_cash == 52000)
	container.remove_child(non_owned)
	non_owned.queue_free()

	var first_id := garage.get_owned_instance_id(first)
	first.global_position = Vector3(40, 1, 25)
	var saved := garage.export_save_data()
	garage.import_save_data(saved, container)
	await process_frame
	assert(garage.get_owned_count() == 2)
	var restored_first: BaseVehicle
	for owned in garage.get_owned_vehicles():
		if garage.get_owned_instance_id(owned) == first_id:
			restored_first = owned
	assert(restored_first != null)
	assert(restored_first.global_position.distance_to(Vector3(40, 1, 25)) < 0.01)

	await physics_frame
	await physics_frame
	parked = dealership.get_parked_owned_vehicles(garage)
	assert(parked.size() == 1)
	assert(service.sell_vehicle(parked[0], dealership))
	assert(wallet.clean_cash == 55600)
	assert(garage.get_owned_count() == 1)
	var after_sale := garage.export_save_data()
	garage.import_save_data(after_sale, container)
	await process_frame
	assert(garage.get_owned_count() == 1)
	garage.import_save_data({}, container)
	assert(garage.get_owned_count() == 0)
	assert(wallet.spend_clean(wallet.clean_cash, false))
	assert(service.purchase_vehicle(
		VehicleCatalog.get_by_id(&"sport_classic_02"),
		dealership
	) == null)
	assert(wallet.clean_cash == 0)
	assert(garage.get_owned_count() == 0)

	var menu := player.get_node("CarDealershipMenu") as CarDealershipMenu
	assert(menu.find_child("BuyTab", true, false) != null)
	assert(menu.find_child("SellTab", true, false) != null)
	assert(menu.find_child("BusinessTab", true, false) != null)
	assert(menu.find_child("BusinessManagementPanel", true, false) != null)
	var business := PropertyCatalog.get_by_id(
		PropertyCatalog.DOWNTOWN_CAR_DEALERSHIP_ID
	)
	assert(business.purchase_price == 75000)
	assert(business.business_stock_capacity == 6)
	assert(business.business_restock_unit_cost == 2000)
	assert(business.business_revenue_per_sale == 3000)

	print("CAR_DEALERSHIP_SMOKE_TEST_PASS")
	quit(0)
