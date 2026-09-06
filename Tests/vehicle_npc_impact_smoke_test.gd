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
	await process_frame
	await process_frame
	await physics_frame

	var vehicle_scene := load(
		"res://Scenes/Vehicles/MuscleCar.tscn"
	) as PackedScene
	var vehicle := vehicle_scene.instantiate() as BaseVehicle
	world.get_node("Gameplay").add_child(vehicle)
	vehicle.global_position = Vector3(60, 1, -5)
	await process_frame
	await physics_frame

	var condition := vehicle.condition_component
	var impact := vehicle.impact_component
	var dealer_zone := world.get_node(
		"SpawnPoints/EastDealerZoneSouth"
	) as DealerActivityZone3D
	var npc := dealer_zone.get_spawned_dealers()[0] as BaseNPC
	assert(npc != null)
	assert(is_zero_approx(condition.damage))

	vehicle.linear_velocity = Vector3.FORWARD * 8.0
	impact.previous_linear_velocity = vehicle.linear_velocity
	vehicle._on_body_entered(npc)
	assert(npc.is_defeated())
	assert(is_equal_approx(condition.damage, 10.0))

	vehicle._on_body_entered(npc)
	assert(is_equal_approx(condition.damage, 10.0))
	var ragdoll_body := StaticBody3D.new()
	npc.add_child(ragdoll_body)
	vehicle._on_body_entered(ragdoll_body)
	assert(is_equal_approx(condition.damage, 10.0))

	var obstacle := StaticBody3D.new()
	world.get_node("Gameplay").add_child(obstacle)
	vehicle.linear_velocity = Vector3.FORWARD * 8.0
	impact.previous_linear_velocity = vehicle.linear_velocity
	vehicle._on_body_entered(obstacle)
	assert(condition.damage > 0.0)

	print("VEHICLE_NPC_IMPACT_SMOKE_TEST_PASS")
	quit(0)
