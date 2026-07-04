class_name VehiclePowertrainComponent
extends Node

var vehicle: BaseVehicle
var current_gear := 1
var shift_timer := 0.0


func setup(owner_vehicle: BaseVehicle) -> void:
	vehicle = owner_vehicle


func reset() -> void:
	current_gear = 1
	shift_timer = 0.0


func update_automatic(
	delta: float,
	forward_speed: float,
	throttle: float,
	reverse: float
) -> void:
	shift_timer = maxf(shift_timer - delta, 0.0)
	if reverse > 0.0 and forward_speed <= 0.8:
		current_gear = -1
		return
	if throttle <= 0.0:
		if forward_speed >= -0.8 and current_gear < 1:
			current_gear = 1
		return
	if current_gear <= 0:
		current_gear = 1
	if shift_timer > 0.0:
		return
	if (
		vehicle.tire_component.drift_amount > 0.2
		or vehicle.tire_component.burnout_amount > 0.1
	):
		return
	var limits := vehicle.definition.forward_gear_speed_limits
	if limits.is_empty():
		return
	var speed := maxf(forward_speed, 0.0)
	var index := clampi(current_gear - 1, 0, limits.size() - 1)
	if speed >= limits[index] and current_gear < limits.size():
		current_gear += 1
		shift_timer = vehicle.definition.shift_duration
	elif current_gear > 1:
		var previous_limit := limits[current_gear - 2]
		if speed < previous_limit * 0.72:
			current_gear -= 1
			shift_timer = vehicle.definition.shift_duration


func force_multiplier() -> float:
	if current_gear <= 0:
		return 1.0
	var multipliers := vehicle.definition.forward_gear_force_multipliers
	if multipliers.is_empty():
		return 1.0
	return multipliers[
		clampi(current_gear - 1, 0, multipliers.size() - 1)
	]


func calculate_target_rpm(
	forward_speed: float,
	throttle_amount: float
) -> float:
	if current_gear < 0:
		var ratio := clampf(
			absf(forward_speed) / vehicle.definition.max_reverse_speed,
			0.0,
			1.0
		)
		return lerpf(
			vehicle.definition.idle_rpm,
			vehicle.definition.maximum_rpm,
			maxf(ratio, throttle_amount * 0.35)
		)
	var limits := vehicle.definition.forward_gear_speed_limits
	if limits.is_empty():
		return vehicle.definition.idle_rpm
	var index := clampi(current_gear - 1, 0, limits.size() - 1)
	var lower := 0.0 if index == 0 else limits[index - 1] * 0.72
	var upper := limits[index]
	var speed_ratio := clampf(
		(maxf(forward_speed, 0.0) - lower) / maxf(upper - lower, 0.1),
		0.0,
		1.0
	)
	var minimum_rpm := (
		vehicle.definition.idle_rpm
		if forward_speed < 0.5
		else vehicle.definition.idle_rpm + 550.0
	)
	return lerpf(
		minimum_rpm,
		vehicle.definition.maximum_rpm,
		maxf(speed_ratio, throttle_amount * 0.18)
	)
