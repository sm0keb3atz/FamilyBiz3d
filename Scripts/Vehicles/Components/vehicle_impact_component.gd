class_name VehicleImpactComponent
extends Node

var vehicle: BaseVehicle
var previous_linear_velocity := Vector3.ZERO
var _recent_impacts: Dictionary = {}


func setup(owner_vehicle: BaseVehicle) -> void:
	vehicle = owner_vehicle


func capture_velocity() -> void:
	previous_linear_velocity = vehicle.linear_velocity


func handle_body_entered(body: Node) -> void:
	var impact_velocity := vehicle.linear_velocity
	if previous_linear_velocity.length() > impact_velocity.length():
		impact_velocity = previous_linear_velocity
	_apply_vehicle_damage(body, impact_velocity)
	if impact_velocity.length() < vehicle.minimum_fatal_npc_impact_speed:
		return
	if body is not BaseNPC:
		return
	var npc := body as BaseNPC
	if npc.is_defeated():
		return
	vehicle.add_collision_exception_with(npc)
	npc.add_collision_exception_with(vehicle)
	vehicle.get_tree().create_timer(1.0).timeout.connect(
		func() -> void:
			if is_instance_valid(npc):
				vehicle.remove_collision_exception_with(npc)
				npc.remove_collision_exception_with(vehicle)
	)
	vehicle.linear_velocity = (
		impact_velocity * vehicle.npc_impact_momentum_retention
	)
	npc.apply_vehicle_impact(vehicle, impact_velocity)


func _apply_vehicle_damage(body: Node, impact_velocity: Vector3) -> void:
	if vehicle.is_managed_traffic():
		return
	var key := body.get_instance_id()
	var now := Time.get_ticks_msec()
	if now - int(_recent_impacts.get(key, 0)) < 750:
		return
	var other_velocity := Vector3.ZERO
	if body is RigidBody3D:
		other_velocity = (body as RigidBody3D).linear_velocity
	elif body is CharacterBody3D:
		other_velocity = (body as CharacterBody3D).velocity
	var relative_speed := (impact_velocity - other_velocity).length()
	var amount := minf(maxf(relative_speed - 5.0, 0.0) * 2.5, 35.0)
	if amount <= 0.0:
		return
	_recent_impacts[key] = now
	vehicle.condition_component.apply_damage(amount)
