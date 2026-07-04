class_name VehicleDriveComponent
extends Node

var vehicle: BaseVehicle
var steering_input := 0.0
var throttle_amount := 0.0
var service_braking := false


func setup(owner_vehicle: BaseVehicle) -> void:
	vehicle = owner_vehicle


func reset() -> void:
	steering_input = 0.0
	throttle_amount = 0.0
	service_braking = false


func update(delta: float) -> void:
	if not vehicle.has_driver():
		_set_drive_force(0.0)
		throttle_amount = 0.0
		return
	var forward_speed := vehicle.linear_velocity.dot(vehicle.global_basis.z)
	var throttle := Input.get_action_strength("move_forward")
	var reverse := Input.get_action_strength("move_back")
	var steer_axis := Input.get_axis("move_right", "move_left")
	var tires := vehicle.tire_component
	tires.handbrake_amount = Input.get_action_strength(
		vehicle.handbrake_action
	)
	tires.update_burnout(delta, throttle, forward_speed)
	tires.update_drift(delta, throttle)
	vehicle.powertrain_component.update_automatic(
		delta,
		forward_speed,
		throttle,
		reverse
	)
	var speed_ratio := clampf(
		absf(forward_speed) / vehicle.definition.max_forward_speed,
		0.0,
		1.0
	)
	var steering_limit := deg_to_rad(
		vehicle.definition.max_steering_degrees
	) * lerpf(
		1.0,
		vehicle.definition.high_speed_steering_ratio,
		speed_ratio
	)
	steering_input = move_toward(
		steering_input,
		steer_axis * steering_limit,
		vehicle.definition.steering_speed * delta
	)
	vehicle.steering = steering_input
	var brake_force := 0.0
	var drive_force := 0.0
	throttle_amount = 0.0
	service_braking = false
	if throttle > 0.0:
		if forward_speed < -0.8:
			brake_force = vehicle.definition.service_brake_force * throttle
			service_braking = true
		elif forward_speed < vehicle.definition.max_forward_speed:
			drive_force = (
				vehicle.definition.engine_force
				* vehicle.powertrain_component.force_multiplier()
				* lerpf(
					1.0,
					vehicle.definition.drift_torque_multiplier,
					tires.drift_amount
				)
				* throttle
			)
			throttle_amount = throttle
	elif reverse > 0.0:
		if forward_speed > 0.8:
			brake_force = vehicle.definition.service_brake_force * reverse
			service_braking = true
		elif forward_speed > -vehicle.definition.max_reverse_speed:
			drive_force = -vehicle.definition.reverse_engine_force * reverse
			throttle_amount = reverse
	else:
		brake_force = 1.5
	if vehicle.powertrain_component.shift_timer > 0.0:
		drive_force = 0.0
		throttle_amount = 0.0
	if not vehicle.audio_component.engine_ready:
		drive_force = 0.0
		throttle_amount = 0.0
	if not tires.burnout_holding and tires.burnout_amount <= 0.01:
		drive_force *= 1.0 - tires.handbrake_amount
	_set_drive_force(drive_force)
	tires.update_grip(delta, throttle, forward_speed)
	if tires.burnout_holding:
		_set_burnout_brakes()
	else:
		_set_brakes(
			brake_force,
			vehicle.definition.handbrake_force
			* tires.handbrake_amount
		)


func stop() -> void:
	_set_drive_force(0.0)
	_set_brakes(vehicle.definition.service_brake_force, 0.0)
	vehicle.steering = 0.0
	reset()


func _set_drive_force(force: float) -> void:
	vehicle.engine_force = 0.0
	vehicle.rear_left_wheel.engine_force = force * 0.5
	vehicle.rear_right_wheel.engine_force = force * 0.5


func _set_brakes(service: float, handbrake: float) -> void:
	vehicle.brake = 0.0
	vehicle.front_left_wheel.brake = service
	vehicle.front_right_wheel.brake = service
	vehicle.rear_left_wheel.brake = maxf(service, handbrake)
	vehicle.rear_right_wheel.brake = maxf(service, handbrake)


func _set_burnout_brakes() -> void:
	vehicle.brake = 0.0
	vehicle.front_left_wheel.brake = (
		vehicle.definition.burnout_front_brake_force
	)
	vehicle.front_right_wheel.brake = (
		vehicle.definition.burnout_front_brake_force
	)
	vehicle.rear_left_wheel.brake = 0.0
	vehicle.rear_right_wheel.brake = 0.0
