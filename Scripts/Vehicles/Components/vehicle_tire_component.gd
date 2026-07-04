class_name VehicleTireComponent
extends Node

var vehicle: BaseVehicle
var definition: VehicleDefinition
var rear_grip := 2.9
var handbrake_amount := 0.0
var drift_amount := 0.0
var burnout_amount := 0.0
var burnout_holding := false
var burnout_release_grace := 0.0


func setup(owner_vehicle: BaseVehicle) -> void:
	vehicle = owner_vehicle
	definition = vehicle.definition
	rear_grip = definition.rear_wheel_friction_slip


func reset() -> void:
	handbrake_amount = 0.0
	drift_amount = 0.0
	burnout_amount = 0.0
	burnout_holding = false
	burnout_release_grace = 0.0
	rear_grip = definition.rear_wheel_friction_slip
	vehicle.rear_left_wheel.wheel_friction_slip = rear_grip
	vehicle.rear_right_wheel.wheel_friction_slip = rear_grip


func update_burnout(delta: float, throttle: float, forward_speed: float) -> void:
	var can_start := (
		absf(forward_speed) <= definition.burnout_start_max_speed
		or burnout_amount > 0.05
	)
	burnout_holding = (
		can_start
		and throttle >= definition.burnout_throttle_threshold
		and handbrake_amount >= 0.5
	)
	if burnout_holding:
		burnout_release_grace = 0.35
		burnout_amount = move_toward(
			burnout_amount,
			1.0,
			definition.burnout_engagement_speed * delta
		)
		return
	burnout_release_grace = maxf(burnout_release_grace - delta, 0.0)
	var recovery_speed := definition.burnout_grip_recovery_speed
	if throttle < 0.1:
		recovery_speed *= 3.0
	burnout_amount = move_toward(
		burnout_amount,
		0.0,
		recovery_speed * delta
	)
	if (
		burnout_release_grace > 0.0
		or burnout_amount <= 0.0
		or burnout_amount > 0.2
	):
		return
	var rear_wheel_speed := (
		absf(vehicle.rear_left_wheel.get_rpm())
		+ absf(vehicle.rear_right_wheel.get_rpm())
	) * 0.5 * TAU / 60.0 * definition.wheel_radius
	var longitudinal_slip_speed := maxf(
		rear_wheel_speed - absf(forward_speed),
		0.0
	)
	if longitudinal_slip_speed <= definition.burnout_traction_slip_speed:
		burnout_amount = 0.0


func update_drift(delta: float, throttle: float) -> void:
	var planar_velocity := Vector3(
		vehicle.linear_velocity.x,
		0.0,
		vehicle.linear_velocity.z
	)
	var speed := planar_velocity.length()
	var lateral_speed := absf(
		planar_velocity.dot(vehicle.global_basis.x.normalized())
	)
	var slip_ratio := lateral_speed / maxf(speed, 0.1)
	var slip_amount := smoothstep(
		definition.drift_slip_start,
		definition.drift_slip_full,
		slip_ratio
	)
	var throttle_amount := inverse_lerp(
		definition.drift_throttle_threshold,
		1.0,
		throttle
	)
	var target_drift := (
		slip_amount * clampf(throttle_amount, 0.0, 1.0)
		if speed > 3.0
		else 0.0
	)
	var response_speed := (
		definition.drift_engagement_speed
		if target_drift > drift_amount
		else definition.drift_release_speed
	)
	drift_amount = move_toward(
		drift_amount,
		target_drift,
		response_speed * delta
	)


func update_grip(
	delta: float,
	throttle: float,
	forward_speed: float
) -> void:
	var speed_factor := clampf(absf(forward_speed) / 14.0, 0.2, 1.0)
	var power_slip := clampf(
		throttle * definition.power_slide_strength * speed_factor,
		0.0,
		1.0
	)
	var curved_power_slip := smoothstep(0.0, 1.0, power_slip)
	var curved_handbrake_slip := smoothstep(
		0.0,
		1.0,
		clampf(handbrake_amount, 0.0, 1.0)
	)
	var target_grip := lerpf(
		definition.rear_wheel_friction_slip,
		definition.power_slide_rear_friction_slip,
		curved_power_slip
	)
	target_grip = lerpf(
		target_grip,
		definition.handbrake_rear_friction_slip,
		curved_handbrake_slip
	)
	target_grip = lerpf(
		target_grip,
		definition.burnout_rear_friction_slip,
		burnout_amount
	)
	var response_speed := (
		definition.traction_loss_speed
		if target_grip < rear_grip
		else definition.traction_recovery_speed
	)
	rear_grip = move_toward(rear_grip, target_grip, response_speed * delta)
	vehicle.rear_left_wheel.wheel_friction_slip = rear_grip
	vehicle.rear_right_wheel.wheel_friction_slip = rear_grip
