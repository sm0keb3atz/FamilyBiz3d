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

	var player := world.get_node("Gameplay/Player") as CharacterBody3D
	var vehicle_scene := load(
		"res://Scenes/Vehicles/MuscleCar.tscn"
	) as PackedScene
	var vehicle: Variant = vehicle_scene.instantiate()
	world.get_node("Gameplay").add_child(vehicle)
	vehicle.global_position = Vector3(60, 1, -5)
	await process_frame
	await physics_frame
	var vehicle_component: Variant = player.get_node(
		"Components/VehicleComponent"
	)
	var player_visual := player.get_node("Visual") as Node3D
	var player_collision := player.get_node(
		"CollisionShape3D"
	) as CollisionShape3D
	var on_foot_camera := player.get_node(
		"CameraPivot/SpringArm3D/Camera3D"
	) as Camera3D
	var sound_component := player.get_node(
		"Components/SoundComponent"
	) as PlayerSoundComponent

	assert(vehicle.get_node("WheelFL") is VehicleWheel3D)
	assert(vehicle.get_node("WheelFR") is VehicleWheel3D)
	assert(vehicle.get_node("WheelRL") is VehicleWheel3D)
	assert(vehicle.get_node("WheelRR") is VehicleWheel3D)
	assert(vehicle.get_node("Components/TireComponent") is VehicleTireComponent)
	assert(vehicle.get_node("Components/DriveComponent") is VehicleDriveComponent)
	assert(
		vehicle.get_node("Components/PowertrainComponent")
		is VehiclePowertrainComponent
	)
	assert(vehicle.get_node("Components/AudioComponent") is VehicleAudioComponent)
	assert(
		vehicle.get_node("Components/EffectsComponent")
		is VehicleEffectsComponent
	)
	assert(
		vehicle.get_node("Components/CameraComponent")
		is VehicleCameraComponent
	)
	assert(
		vehicle.get_node("Components/InteractionComponent")
		is VehicleInteractionComponent
	)
	assert(
		vehicle.get_node("Components/ImpactComponent")
		is VehicleImpactComponent
	)
	var condition := vehicle.get_node(
		"Components/ConditionComponent"
	) as VehicleConditionComponent
	assert(condition != null)
	assert(is_equal_approx(condition.get_fuel_capacity(), 16.0))
	assert(is_equal_approx(condition.fuel_gallons, 16.0))
	assert(is_zero_approx(condition.damage))
	assert(condition.consume_fuel(1.25) > 1.24)
	assert(is_equal_approx(condition.fuel_gallons, 14.75))
	assert(is_equal_approx(condition.apply_damage(50.0), 50.0))
	assert(condition.get_effective_engine_force() < vehicle.definition.engine_force)
	assert(condition.set_performance_tier(1))
	assert(condition.performance_tier == 1)
	assert(condition.repair_full() == 50.0)
	var condition_save := vehicle.export_condition_state()
	condition.consume_fuel(5.0)
	condition.apply_damage(20.0)
	vehicle.import_condition_state(condition_save)
	assert(is_equal_approx(condition.fuel_gallons, 14.75))
	assert(is_zero_approx(condition.damage))
	assert(vehicle.has_valid_wheel_bones())
	var hud := player.get_node("PlayerHUD") as PlayerHUD
	var weapon_panel := hud.get_node("WeaponPanel") as Control
	var vehicle_panel := hud.find_child("VehiclePanel", true, false) as Control
	assert(vehicle_panel != null and not vehicle_panel.visible)
	assert(vehicle_component.enter_vehicle(vehicle))
	await process_frame
	assert(vehicle_component.is_driving())
	assert(vehicle.has_driver())
	assert(not sound_component.are_footsteps_enabled())
	assert(not player_visual.visible)
	assert(not on_foot_camera.current)
	assert(vehicle_panel.visible)
	assert(not weapon_panel.visible)

	vehicle.linear_velocity = Vector3.ZERO
	assert(vehicle_component.exit_vehicle())
	await process_frame
	assert(not vehicle_component.is_driving())
	assert(not vehicle.has_driver())
	assert(sound_component.are_footsteps_enabled())
	assert(player_visual.visible)
	assert(not player_collision.disabled)
	assert(on_foot_camera.current)
	assert(not vehicle_panel.visible)
	assert(weapon_panel.visible)

	assert(vehicle_component.enter_vehicle(vehicle))
	var controller: Variant = world.get_node("WorldController")
	assert(controller.save_game())
	controller.load_game()
	await process_frame
	assert(not vehicle_component.is_driving())
	assert(sound_component.are_footsteps_enabled())
	assert(player_visual.visible)
	assert(on_foot_camera.current)

	var east_dealer_zone := world.get_node(
		"SpawnPoints/EastDealerZoneSouth"
	) as DealerActivityZone3D
	var npc := east_dealer_zone.get_spawned_dealers()[0] as BaseNPC
	assert(
		(npc as DealerNPC).role_component is DealerRoleComponent
	)
	vehicle.linear_velocity = Vector3.FORWARD * 8.0
	vehicle._on_body_entered(npc)
	assert(npc.damageable.is_depleted())
	assert(npc.is_defeated())

	print("VEHICLE_SMOKE_TEST_PASS")
	quit(0)
