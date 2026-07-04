class_name VehicleImpactComponent
extends Node

var vehicle: BaseVehicle
var previous_linear_velocity := Vector3.ZERO


func setup(owner_vehicle: BaseVehicle) -> void:
	vehicle = owner_vehicle


func capture_velocity() -> void:
	previous_linear_velocity = vehicle.linear_velocity


func handle_body_entered(body: Node) -> void:
	var impact_velocity := vehicle.linear_velocity
	if previous_linear_velocity.length() > impact_velocity.length():
		impact_velocity = previous_linear_velocity
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
