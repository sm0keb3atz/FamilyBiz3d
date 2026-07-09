class_name VehicleDriveComponent
extends Node

var vehicle: BaseVehicle
var steering_input := 0.0
var throttle_amount := 0.0
var service_braking := false
var _ai_control_enabled := false
var _ai_throttle := 0.0
var _ai_brake := 0.0
var _ai_steering := 0.0
var _ai_handbrake := 0.0


func setup(owner_vehicle: BaseVehicle) -> void:
	vehicle = owner_vehicle


func reset() -> void:
	steering_input = 0.0
	throttle_amount = 0.0
	service_braking = false
	_ai_control_enabled = false
	_ai_throttle = 0.0
	_ai_brake = 0.0
	_ai_steering = 0.0
	_ai_handbrake = 0.0


func update(delta: float) -> void:
	if _ai_control_enabled and not vehicle.has_driver():
		_update_ai(delta)
		return
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


func set_ai_control(
	throttle: float,
	brake: float,
	steering: float,
	handbrake := 0.0
) -> void:
	_ai_control_enabled = true
	_ai_throttle = clampf(throttle, 0.0, 1.0)
	_ai_brake = clampf(brake, 0.0, 1.0)
	_ai_steering = clampf(
		steering,
		-deg_to_rad(vehicle.definition.max_steering_degrees),
		deg_to_rad(vehicle.definition.max_steering_degrees)
	)
	_ai_handbrake = clampf(handbrake, 0.0, 1.0)


func clear_ai_control() -> void:
	_ai_control_enabled = false
	_ai_throttle = 0.0
	_ai_brake = 0.0
	_ai_steering = 0.0
	_ai_handbrake = 0.0
	if vehicle != null and vehicle.definition != null:
		_set_drive_force(0.0)
		_set_brakes(vehicle.definition.service_brake_force, 0.0)


func is_ai_control_enabled() -> bool:
	return _ai_control_enabled


func _update_ai(delta: float) -> void:
	var forward_speed := vehicle.linear_velocity.dot(vehicle.global_basis.z)
	var tires := vehicle.tire_component
	tires.handbrake_amount = _ai_handbrake
	tires.update_burnout(delta, _ai_throttle, forward_speed)
	tires.update_drift(delta, _ai_throttle)
	vehicle.powertrain_component.update_automatic(
		delta,
		forward_speed,
		_ai_throttle,
		0.0
	)
	steering_input = move_toward(
		steering_input,
		_ai_steering,
		vehicle.definition.steering_speed * delta
	)
	vehicle.steering = steering_input
	var drive_force := 0.0
	throttle_amount = 0.0
	service_braking = _ai_brake > 0.01
	if (
		_ai_throttle > 0.0
		and _ai_brake <= 0.01
		and forward_speed < vehicle.definition.max_forward_speed
	):
		drive_force = (
			vehicle.definition.engine_force
			* vehicle.powertrain_component.force_multiplier()
			* _ai_throttle
		)
		throttle_amount = _ai_throttle
	if vehicle.powertrain_component.shift_timer > 0.0:
		drive_force = 0.0
		throttle_amount = 0.0
	_set_drive_force(drive_force)
	tires.update_grip(delta, _ai_throttle, forward_speed)
	_set_brakes(
		vehicle.definition.service_brake_force * _ai_brake,
		vehicle.definition.handbrake_force * _ai_handbrake
	)


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
