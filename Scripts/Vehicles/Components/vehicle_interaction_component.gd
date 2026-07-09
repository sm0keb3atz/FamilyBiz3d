class_name VehicleInteractionComponent
extends Node

var vehicle: BaseVehicle


func setup(owner_vehicle: BaseVehicle) -> void:
	vehicle = owner_vehicle


func can_interact(player: CharacterBody3D) -> bool:
	if (
		vehicle.has_driver()
		or vehicle.is_managed_traffic()
		or vehicle.definition == null
	):
		return false
	var health := player.get_node_or_null(
		"Components/HealthComponent"
	) as PlayerHealthComponent
	return health != null and health.is_alive()


func get_prompt() -> String:
	return "E - Drive %s" % vehicle.definition.display_name


func find_safe_exit(player: CharacterBody3D) -> Vector3:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	for marker_path in vehicle.exit_marker_paths:
		var marker := vehicle.get_node_or_null(marker_path) as Marker3D
		if marker == null:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(
			Basis.IDENTITY,
			marker.global_position + Vector3.UP * 0.9
		)
		query.exclude = [player.get_rid()]
		query.collision_mask = player.collision_mask
		var hits := (
			vehicle.get_world_3d()
			.direct_space_state
			.intersect_shape(query, 1)
		)
		if hits.is_empty():
			return marker.global_position
	return Vector3.INF


func recover_upright() -> void:
	var forward := vehicle.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	vehicle.global_basis = Basis.looking_at(forward, Vector3.UP, true)
	vehicle.global_position += Vector3.UP
	vehicle.linear_velocity = Vector3.ZERO
	vehicle.angular_velocity = Vector3.ZERO
