class_name TrafficVehicleAIComponent
extends Node

@export_range(0.5, 8.0, 0.1) var arrival_distance := 3.0
@export_range(1.0, 25.0, 0.5) var look_ahead_distance := 9.0
@export_range(1.0, 25.0, 0.5) var following_distance := 10.0
@export_range(1.0, 60.0, 0.5) var steering_sensitivity_degrees := 32.0
@export_range(0.0, 1.0, 0.05) var cautious_throttle := 0.35
@export_range(0.0, 1.0, 0.05) var cruise_throttle := 0.75
@export_range(0.0, 8.0, 0.1) var brake_speed_margin := 3.0
@export_range(0.0, 6.0, 0.1) var curve_brake_angle_degrees := 24.0
@export_range(0.0, 5.0, 0.1) var stuck_creep_delay := 1.8
@export_range(1.0, 20.0, 0.5) var stuck_recycle_delay := 8.0
@export_range(0.0, 1.0, 0.05) var stuck_creep_throttle := 0.18
@export_range(0.0, 4.0, 0.1) var lane_block_margin := 1.35
@export_flags_3d_physics var obstacle_mask := 3

var vehicle: BaseVehicle
var network: TrafficNetwork3D
var current_waypoint: TrafficWaypoint3D
var previous_waypoint: TrafficWaypoint3D
var target_waypoint: TrafficWaypoint3D
var _random := RandomNumberGenerator.new()
var _lane_offset := 0.0
var _enabled := false
var _blocked_elapsed := 0.0
var _last_raycast_blocked := false
var _last_raycast_requires_full_stop := false
var _last_obstacle_blocked := false
var _recycle_requested := false
var _ignore_stale_blockers_remaining := 0.0
var _hard_stop_active := false


func initialize(owner_vehicle: BaseVehicle) -> void:
	vehicle = owner_vehicle


func assign_route(
	traffic_network: TrafficNetwork3D,
	start_waypoint: TrafficWaypoint3D,
	random_seed: int
) -> void:
	network = traffic_network
	current_waypoint = start_waypoint
	previous_waypoint = null
	target_waypoint = null
	_random.seed = random_seed
	_lane_offset = (
		_random.randf_range(-start_waypoint.lane_half_width, start_waypoint.lane_half_width)
		if start_waypoint != null else 0.0
	)
	_enabled = true
	_blocked_elapsed = 0.0
	_last_raycast_blocked = false
	_last_raycast_requires_full_stop = false
	_last_obstacle_blocked = false
	_recycle_requested = false
	_ignore_stale_blockers_remaining = 0.0
	_hard_stop_active = false
	_choose_next()


func clear() -> void:
	_enabled = false
	network = null
	current_waypoint = null
	previous_waypoint = null
	target_waypoint = null
	_blocked_elapsed = 0.0
	_last_raycast_blocked = false
	_last_raycast_requires_full_stop = false
	_last_obstacle_blocked = false
	_recycle_requested = false
	_ignore_stale_blockers_remaining = 0.0
	_hard_stop_active = false
	if vehicle != null:
		vehicle.drive_component.clear_ai_control()


func tick_traffic(
	delta: float,
	traffic_cars: Array[BaseVehicle],
	allow_raycast := true
) -> void:
	if (
		not _enabled
		or vehicle == null
		or network == null
		or not is_instance_valid(current_waypoint)
	):
		_stop_vehicle()
		return
	if not is_instance_valid(target_waypoint):
		_choose_next()
		if not is_instance_valid(target_waypoint):
			_stop_vehicle()
			return

	var target_position := _get_target_position()
	var should_stop_for_signal := _should_stop_for_signal(target_position)
	if (
		not should_stop_for_signal and
		vehicle.global_position.distance_squared_to(target_position)
		<= arrival_distance * arrival_distance
	):
		previous_waypoint = current_waypoint
		current_waypoint = target_waypoint
		_choose_next()
		target_position = _get_target_position()
		should_stop_for_signal = _should_stop_for_signal(target_position)

	var should_stop := should_stop_for_signal
	var blocked_by_obstacle := _has_obstacle_ahead(traffic_cars, allow_raycast)
	should_stop = should_stop or blocked_by_obstacle
	var hard_stop_blocked := should_stop_for_signal or _last_raycast_requires_full_stop
	_hard_stop_active = hard_stop_blocked
	var steering := _calculate_steering(target_position)
	var forward_speed := vehicle.linear_velocity.dot(vehicle.global_basis.z)
	var target_speed := (
		minf(current_waypoint.speed_limit, target_waypoint.speed_limit)
		if is_instance_valid(target_waypoint) else 6.0
	)
	target_speed = minf(target_speed, _curve_speed_limit(steering))
	var throttle := cruise_throttle
	var brake := 0.0
	if should_stop:
		throttle = 0.0
		brake = 1.0
	elif absf(rad_to_deg(steering)) > steering_sensitivity_degrees * 0.55:
		throttle = cautious_throttle
	elif forward_speed > target_speed:
		throttle = 0.0
		if forward_speed > target_speed + brake_speed_margin:
			brake = 0.25
	if blocked_by_obstacle:
		_blocked_elapsed += delta
		if hard_stop_blocked:
			_ignore_stale_blockers_remaining = 0.0
		elif (
			_blocked_elapsed >= stuck_creep_delay
			and absf(forward_speed) < 1.0
		):
			throttle = stuck_creep_throttle
			brake = 0.0
			_ignore_stale_blockers_remaining = 0.55
		if not hard_stop_blocked and _blocked_elapsed >= stuck_recycle_delay:
			_recycle_requested = true
	else:
		_blocked_elapsed = maxf(_blocked_elapsed - delta * 2.0, 0.0)
	_ignore_stale_blockers_remaining = maxf(
		_ignore_stale_blockers_remaining - delta,
		0.0
	)
	vehicle.drive_component.set_ai_control(throttle, brake, steering)


func has_route() -> bool:
	return is_instance_valid(current_waypoint) and is_instance_valid(target_waypoint)


func get_current_waypoint() -> TrafficWaypoint3D:
	return current_waypoint


func get_target_waypoint() -> TrafficWaypoint3D:
	return target_waypoint


func get_spawn_transform() -> Transform3D:
	if not is_instance_valid(current_waypoint):
		return vehicle.global_transform
	var target := (
		target_waypoint.global_position
		if is_instance_valid(target_waypoint)
		else current_waypoint.global_position + current_waypoint.global_basis.z
	)
	var forward := target - current_waypoint.global_position
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	return Transform3D(
		Basis.looking_at(forward, Vector3.UP, true),
		current_waypoint.global_position + _get_lane_offset(
			current_waypoint,
			target_waypoint
		)
	)


func wants_recycle() -> bool:
	return _recycle_requested


func is_hard_stop_active() -> bool:
	return _hard_stop_active


func _choose_next() -> void:
	if network == null or not is_instance_valid(current_waypoint):
		target_waypoint = null
		return
	target_waypoint = network.get_next_waypoint(
		current_waypoint,
		previous_waypoint,
		_random
	)


func _get_target_position() -> Vector3:
	if not is_instance_valid(target_waypoint):
		return vehicle.global_position
	return (
		target_waypoint.global_position
		+ _get_lane_offset(current_waypoint, target_waypoint)
	)


func _get_lane_offset(
	from_waypoint: TrafficWaypoint3D,
	to_waypoint: TrafficWaypoint3D
) -> Vector3:
	if not (
		is_instance_valid(from_waypoint)
		and is_instance_valid(to_waypoint)
	):
		return Vector3.ZERO
	var direction := to_waypoint.global_position - from_waypoint.global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		return Vector3.ZERO
	return Vector3(-direction.z, 0.0, direction.x).normalized() * _lane_offset


func _calculate_steering(target_position: Vector3) -> float:
	var direction := target_position - vehicle.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		return 0.0
	direction = direction.normalized()
	var local_direction := vehicle.global_basis.inverse() * direction
	var target_angle := atan2(local_direction.x, local_direction.z)
	var maximum := deg_to_rad(steering_sensitivity_degrees)
	return clampf(target_angle, -maximum, maximum)


func _curve_speed_limit(steering: float) -> float:
	var angle := absf(rad_to_deg(steering))
	if curve_brake_angle_degrees <= 0.0 or angle <= curve_brake_angle_degrees:
		return INF
	var turn_ratio := clampf(
		inverse_lerp(
			curve_brake_angle_degrees,
			steering_sensitivity_degrees,
			angle
		),
		0.0,
		1.0
	)
	return lerpf(8.0, 4.5, turn_ratio)


func _should_stop_for_signal(target_position: Vector3) -> bool:
	if not is_instance_valid(target_waypoint):
		return false
	if not target_waypoint.should_stop_for_signal():
		return false
	var distance_squared := vehicle.global_position.distance_squared_to(
		target_position
	)
	return distance_squared <= look_ahead_distance * look_ahead_distance


func _has_obstacle_ahead(
	traffic_cars: Array[BaseVehicle],
	allow_raycast: bool
) -> bool:
	var forward := vehicle.global_basis.z.normalized()
	var side := vehicle.global_basis.x.normalized()
	var origin := vehicle.global_position + Vector3.UP * 0.65
	for other in traffic_cars:
		if other == vehicle or not is_instance_valid(other):
			continue
		var offset := other.global_position - vehicle.global_position
		offset.y = 0.0
		var distance_squared := offset.length_squared()
		if distance_squared > following_distance * following_distance:
			continue
		if distance_squared < 0.01:
			continue
		var forward_distance := offset.dot(forward)
		if forward_distance <= 0.0:
			continue
		var lateral_distance := absf(offset.dot(side))
		var lane_width := (
			current_waypoint.lane_half_width
			if is_instance_valid(current_waypoint)
			else 0.75
		)
		if lateral_distance > lane_width + lane_block_margin:
			continue
		if (
			_ignore_stale_blockers_remaining <= 0.0
			or forward_distance < following_distance * 0.45
		):
			var other_ai := _get_traffic_ai(other)
			_last_obstacle_blocked = true
			_last_raycast_requires_full_stop = (
				other_ai != null and other_ai.is_hard_stop_active()
			)
			return true

	if not allow_raycast:
		return _last_raycast_blocked

	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + forward * following_distance,
		obstacle_mask,
		[vehicle.get_rid()]
	)
	query.collide_with_areas = true
	var hit := vehicle.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_last_raycast_blocked = false
		_last_raycast_requires_full_stop = false
		return false
	var collider := hit.get("collider") as Node
	if collider == null or collider == vehicle:
		_last_raycast_blocked = false
		_last_raycast_requires_full_stop = false
		return false
	var is_pedestrian := (
		collider is BaseNPC
		or collider.is_in_group("customer_npc")
		or collider.is_in_group("police_npc")
		or collider.is_in_group("interactable_npc")
	)
	var is_signal_blocker := collider.is_in_group("traffic_signal_blocker")
	_last_raycast_blocked = (
		collider is BaseVehicle
		or is_pedestrian
		or collider.is_in_group("traffic_vehicle")
		or is_signal_blocker
	)
	_last_raycast_requires_full_stop = is_pedestrian or is_signal_blocker
	return _last_raycast_blocked


func _stop_vehicle() -> void:
	_hard_stop_active = false
	if vehicle != null:
		vehicle.drive_component.set_ai_control(0.0, 1.0, 0.0)


func _get_traffic_ai(other: BaseVehicle) -> TrafficVehicleAIComponent:
	if other == null:
		return null
	return other.get_node_or_null("TrafficAIComponent") as TrafficVehicleAIComponent
