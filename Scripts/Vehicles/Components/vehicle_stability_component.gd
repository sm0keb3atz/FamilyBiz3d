class_name VehicleStabilityComponent
extends Node

var vehicle: BaseVehicle


func setup(owner_vehicle: BaseVehicle) -> void:
	vehicle = owner_vehicle


func update() -> void:
	if vehicle.linear_velocity.length_squared() <= 0.01:
		return
	_anti_roll(vehicle.front_left_wheel, vehicle.front_right_wheel)
	_anti_roll(vehicle.rear_left_wheel, vehicle.rear_right_wheel)
	_roll_stabilization()
	_drift_stability()
	if vehicle.global_basis.y.dot(Vector3.UP) > 0.25:
		var downforce := minf(
			vehicle.linear_velocity.length_squared()
			* vehicle.definition.downforce_coefficient,
			vehicle.definition.max_downforce
		)
		vehicle.apply_central_force(
			-vehicle.global_basis.y * downforce
		)


func _anti_roll(left: VehicleWheel3D, right: VehicleWheel3D) -> void:
	if not left.is_in_contact() or not right.is_in_contact():
		return
	var force := clampf(
		(_compression(left) - _compression(right))
		* vehicle.definition.anti_roll_stiffness,
		-vehicle.definition.maximum_anti_roll_force,
		vehicle.definition.maximum_anti_roll_force
	)
	var up := vehicle.global_basis.y
	vehicle.apply_force(
		up * force,
		vehicle._get_wheel_anchor_world(left) - vehicle.global_position
	)
	vehicle.apply_force(
		-up * force,
		vehicle._get_wheel_anchor_world(right) - vehicle.global_position
	)


func _compression(wheel: VehicleWheel3D) -> float:
	if not wheel.is_in_contact():
		return 0.0
	var anchor := vehicle._get_wheel_anchor_world(wheel)
	var distance := (
		anchor - wheel.get_contact_point()
	).dot(vehicle.global_basis.y.normalized())
	var length := clampf(
		distance - vehicle.definition.wheel_radius,
		0.0,
		vehicle.definition.suspension_rest_length
		+ vehicle.definition.suspension_travel
	)
	return clampf(
		vehicle.definition.suspension_rest_length - length,
		-vehicle.definition.suspension_travel,
		vehicle.definition.suspension_travel
	)


func _roll_stabilization() -> void:
	var grounded := 0
	for wheel in vehicle._get_wheels():
		if wheel.is_in_contact():
			grounded += 1
	if grounded < 2:
		return
	var forward := vehicle.global_basis.z.normalized()
	var error := vehicle.global_basis.x.normalized().dot(Vector3.UP)
	var rate := vehicle.angular_velocity.dot(forward)
	vehicle.apply_torque(
		forward * (
			-error * vehicle.definition.roll_leveling_torque
			- rate * vehicle.definition.roll_damping_torque
		)
	)


func _drift_stability() -> void:
	if vehicle.linear_velocity.length() < 2.0:
		return
	var side := vehicle.global_basis.x.normalized()
	var up := vehicle.global_basis.y.normalized()
	var assist := 1.0 - vehicle.tire_component.handbrake_amount * 0.75
	vehicle.apply_central_force(
		-side
		* vehicle.linear_velocity.dot(side)
		* vehicle.definition.drift_lateral_assist
		* assist
	)
	vehicle.apply_torque(
		-up
		* vehicle.angular_velocity.dot(up)
		* vehicle.definition.drift_yaw_damping
		* assist
	)
