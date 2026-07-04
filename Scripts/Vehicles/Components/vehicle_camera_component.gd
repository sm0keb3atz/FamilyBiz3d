class_name VehicleCameraComponent
extends Node

var vehicle: BaseVehicle
var pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var pitch := deg_to_rad(-10.0)
var yaw_offset := 0.0
var recenter_timer := 0.0
var turn_lag := 0.0
var longitudinal_acceleration := 0.0
var previous_forward_speed := 0.0


func setup(owner_vehicle: BaseVehicle) -> void:
	vehicle = owner_vehicle
	pivot = vehicle.get_node(vehicle.camera_pivot_path) as Node3D
	spring_arm = vehicle.get_node(vehicle.spring_arm_path) as SpringArm3D
	camera = vehicle.get_node(vehicle.camera_path) as Camera3D
	camera.current = false
	apply_definition()
	snap()


func apply_definition() -> void:
	spring_arm.spring_length = vehicle.definition.camera_distance
	pivot.position.y = vehicle.definition.camera_height


func activate() -> void:
	yaw_offset = 0.0
	recenter_timer = 0.0
	turn_lag = 0.0
	longitudinal_acceleration = 0.0
	previous_forward_speed = vehicle.linear_velocity.dot(vehicle.global_basis.z)
	camera.current = true
	snap()


func deactivate() -> void:
	camera.current = false


func handle_mouse_motion(event: InputEventMouseMotion) -> void:
	yaw_offset -= event.relative.x * vehicle.definition.camera_sensitivity
	recenter_timer = vehicle.definition.camera_recenter_delay
	pitch = clampf(
		pitch - event.relative.y * vehicle.definition.camera_sensitivity,
		deg_to_rad(-35.0),
		deg_to_rad(15.0)
	)


func update(delta: float) -> void:
	if vehicle.definition == null or delta <= 0.0:
		return
	recenter_timer = maxf(recenter_timer - delta, 0.0)
	if recenter_timer <= 0.0:
		var recenter_weight := 1.0 - exp(
			-vehicle.definition.camera_recenter_speed * delta
		)
		yaw_offset = lerp_angle(yaw_offset, 0.0, recenter_weight)
	var forward_speed := vehicle.linear_velocity.dot(vehicle.global_basis.z)
	var raw_acceleration := clampf(
		(forward_speed - previous_forward_speed) / delta,
		-15.0,
		15.0
	)
	previous_forward_speed = forward_speed
	var acceleration_weight := 1.0 - exp(
		-vehicle.definition.camera_acceleration_response * delta
	)
	longitudinal_acceleration = lerpf(
		longitudinal_acceleration,
		raw_acceleration,
		acceleration_weight
	)
	var speed_ratio := clampf(
		vehicle.linear_velocity.length()
		/ vehicle.definition.max_forward_speed,
		0.0,
		1.0
	)
	var response_weight := 1.0 - exp(
		-vehicle.definition.camera_response_speed * delta
	)
	var target_distance := (
		vehicle.definition.camera_distance
		+ vehicle.definition.camera_speed_distance_bonus * speed_ratio
		+ maxf(longitudinal_acceleration, 0.0)
		* vehicle.definition.camera_acceleration_distance
		- maxf(-longitudinal_acceleration, 0.0)
		* vehicle.definition.camera_braking_distance
	)
	spring_arm.spring_length = lerpf(
		spring_arm.spring_length,
		maxf(target_distance, 2.0),
		response_weight
	)
	camera.fov = lerpf(
		camera.fov,
		vehicle.definition.camera_base_fov
		+ vehicle.definition.camera_speed_fov_bonus * speed_ratio,
		response_weight
	)
	pivot.position = pivot.position.lerp(
		Vector3(0.0, vehicle.definition.camera_height, 0.0),
		response_weight
	)
	var acceleration_pitch := clampf(
		longitudinal_acceleration
		* vehicle.definition.camera_acceleration_pitch_degrees,
		-5.0,
		5.0
	)
	pivot.rotation.x = lerp_angle(
		pivot.rotation.x,
		pitch + deg_to_rad(acceleration_pitch),
		response_weight
	)
	var yaw_rate := vehicle.angular_velocity.dot(
		vehicle.global_basis.y.normalized()
	)
	var turn_speed_scale := clampf(
		vehicle.linear_velocity.length() / 8.0,
		0.0,
		1.0
	)
	var target_turn_lag := clampf(
		-yaw_rate
		* vehicle.definition.camera_turn_lag_strength
		* turn_speed_scale,
		-deg_to_rad(vehicle.definition.camera_max_turn_lag_degrees),
		deg_to_rad(vehicle.definition.camera_max_turn_lag_degrees)
	)
	var turn_lag_weight := 1.0 - exp(
		-vehicle.definition.camera_turn_lag_response * delta
	)
	turn_lag = lerp_angle(turn_lag, target_turn_lag, turn_lag_weight)
	pivot.rotation.y = lerp_angle(
		pivot.rotation.y,
		PI + yaw_offset + turn_lag,
		response_weight
	)
	pivot.rotation.z = 0.0


func snap() -> void:
	if vehicle.definition == null:
		return
	turn_lag = 0.0
	longitudinal_acceleration = 0.0
	previous_forward_speed = vehicle.linear_velocity.dot(vehicle.global_basis.z)
	pivot.position = Vector3(0.0, vehicle.definition.camera_height, 0.0)
	pivot.rotation = Vector3(pitch, PI + yaw_offset, 0.0)
	spring_arm.spring_length = vehicle.definition.camera_distance
	camera.fov = vehicle.definition.camera_base_fov
