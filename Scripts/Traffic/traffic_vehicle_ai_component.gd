class_name TrafficVehicleAIComponent
extends Node

@export_range(0.5, 8.0, 0.1) var arrival_distance := 3.0
@export_range(3.0, 10.0, 0.25) var intersection_arrival_distance := 6.0
@export_range(1.0, 10.0, 0.5) var intersection_target_timeout := 4.0
@export_range(1.0, 60.0, 0.5) var look_ahead_distance := 35.0
@export_range(1.0, 60.0, 0.5) var following_distance := 35.0
@export_range(1.0, 60.0, 0.5) var steering_sensitivity_degrees := 32.0
@export_range(0.0, 1.0, 0.05) var cautious_throttle := 0.35
@export_range(0.0, 1.0, 0.05) var cruise_throttle := 0.75
@export_range(0.0, 8.0, 0.1) var brake_speed_margin := 3.0
@export_range(0.0, 6.0, 0.1) var curve_brake_angle_degrees := 24.0
@export_range(0.0, 4.0, 0.1) var lane_block_margin := 1.35
@export_range(0.1, 3.0, 0.05) var reaction_time := 1.15
@export_range(0.5, 15.0, 0.25) var comfortable_deceleration := 2.5
@export_range(1.0, 25.0, 0.25) var emergency_deceleration := 6.0
@export_range(0.5, 12.0, 0.1) var standstill_gap := 6.0
@export_range(0.5, 4.0, 0.1) var following_time := 2.1
@export_range(0.5, 4.0, 0.1) var pedestrian_probe_half_width := 1.35
@export_flags_3d_physics var obstacle_mask := 3
@export_range(2.0, 60.0, 1.0) var blocked_reroute_seconds := 12.0
@export_range(5.0, 120.0, 1.0) var blocked_recycle_seconds := 25.0

var vehicle: BaseVehicle
var network: TrafficNetwork3D
var current_waypoint: TrafficWaypoint3D
var previous_waypoint: TrafficWaypoint3D
var target_waypoint: TrafficWaypoint3D
var _random := RandomNumberGenerator.new()
var _lane_offset := 0.0
var _enabled := false
var _blocked_elapsed := 0.0
var _reroute_attempted := false
var _last_raycast_blocked := false
var _last_raycast_requires_full_stop := false
var _last_raycast_distance := INF
var _last_obstacle_blocked := false
var _recycle_requested := false
var _ignore_stale_blockers_remaining := 0.0
var _hard_stop_active := false
var _planned_route: Array[TrafficWaypoint3D] = []
var _planned_route_index := 0
var _trip_exit: TrafficWaypoint3D
var _reserved_intersection: TrafficIntersection3D
var _tracked_target_id := 0
var _target_elapsed := 0.0


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
	_reroute_attempted = false
	_last_raycast_blocked = false
	_last_raycast_requires_full_stop = false
	_last_raycast_distance = INF
	_last_obstacle_blocked = false
	_recycle_requested = false
	_ignore_stale_blockers_remaining = 0.0
	_hard_stop_active = false
	_planned_route.clear()
	_planned_route_index = 0
	_trip_exit = network.choose_reachable_exit(start_waypoint, _random)
	_tracked_target_id = 0
	_target_elapsed = 0.0
	if _trip_exit != null:
		_planned_route = network.find_route(start_waypoint, _trip_exit)
	_choose_next()


func clear() -> void:
	_enabled = false
	network = null
	current_waypoint = null
	previous_waypoint = null
	target_waypoint = null
	_blocked_elapsed = 0.0
	_reroute_attempted = false
	_last_raycast_blocked = false
	_last_raycast_requires_full_stop = false
	_last_raycast_distance = INF
	_last_obstacle_blocked = false
	_recycle_requested = false
	_ignore_stale_blockers_remaining = 0.0
	_hard_stop_active = false
	_release_intersection_reservation()
	_planned_route.clear()
	_planned_route_index = 0
	_trip_exit = null
	_tracked_target_id = 0
	_target_elapsed = 0.0
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
	var target_id := int(target_waypoint.get_instance_id())
	if target_id != _tracked_target_id:
		_tracked_target_id = target_id
		_target_elapsed = 0.0
	else:
		_target_elapsed += delta

	var forward_speed := maxf(
		vehicle.linear_velocity.dot(vehicle.global_basis.z),
		0.0
	)
	var target_position := _get_target_position()
	var target_distance := vehicle.global_position.distance_to(target_position)
	var signal_state := _get_target_signal_state()
	var should_hold_at_signal := _should_hold_at_signal(
		signal_state,
		target_distance,
		forward_speed
	)
	var should_hold_for_intersection := not _try_reserve_target_intersection(traffic_cars)
	if (
		not should_hold_at_signal
		and not should_hold_for_intersection
		and _has_reached_target(target_distance)
	):
		previous_waypoint = current_waypoint
		current_waypoint = target_waypoint
		_tracked_target_id = 0
		_target_elapsed = 0.0
		if current_waypoint.has_role(TrafficWaypoint3D.WaypointRole.INTERSECTION_EXIT):
			_release_intersection_reservation()
		_choose_next()
		if _recycle_requested:
			_stop_vehicle()
			return
		target_position = _get_target_position()
		target_distance = vehicle.global_position.distance_to(target_position)
		signal_state = _get_target_signal_state()
		should_hold_at_signal = _should_hold_at_signal(
			signal_state,
			target_distance,
			forward_speed
		)
		should_hold_for_intersection = not _try_reserve_target_intersection(traffic_cars)

	var obstacle := _get_obstacle_ahead(
		traffic_cars,
		allow_raycast,
		forward_speed
	)
	var stopping_distance := INF
	var hard_stop_blocked := false
	var hold_stopping_distance := _get_hold_stopping_distance(target_distance)
	if should_hold_at_signal:
		stopping_distance = hold_stopping_distance
		hard_stop_blocked = signal_state == TrafficSignalController3D.SignalState.RED
	if should_hold_for_intersection and hold_stopping_distance < stopping_distance:
		stopping_distance = hold_stopping_distance
		hard_stop_blocked = true
	if bool(obstacle.get("blocked", false)):
		var obstacle_distance := float(obstacle.get("distance", INF))
		if obstacle_distance < stopping_distance:
			stopping_distance = obstacle_distance
			hard_stop_blocked = bool(obstacle.get("hard_stop", false))
	_hard_stop_active = hard_stop_blocked
	var steering := _calculate_steering(target_position)
	var target_speed := (
		minf(current_waypoint.speed_limit, target_waypoint.speed_limit)
		if is_instance_valid(target_waypoint) else 6.0
	)
	target_speed = minf(target_speed, _curve_speed_limit(steering))
	if is_finite(stopping_distance):
		target_speed = minf(
			target_speed,
			_get_safe_speed_for_distance(stopping_distance)
		)
	var controls := _calculate_speed_controls(
		forward_speed,
		target_speed,
		stopping_distance,
		hard_stop_blocked,
		steering
	)
	var legitimate_hold := should_hold_at_signal or should_hold_for_intersection
	if is_finite(stopping_distance) and not legitimate_hold and forward_speed < 0.35:
		_blocked_elapsed += delta
	else:
		_blocked_elapsed = maxf(_blocked_elapsed - delta * 2.0, 0.0)
		if _blocked_elapsed <= 0.0:
			_reroute_attempted = false
	if _blocked_elapsed >= blocked_reroute_seconds and not _reroute_attempted:
		_reroute_attempted = true
		_try_rebuild_trip_route()
	if _blocked_elapsed >= blocked_recycle_seconds:
		_recycle_requested = true
	vehicle.drive_component.set_ai_control(
		float(controls.get("throttle", 0.0)),
		float(controls.get("brake", 0.0)),
		steering
	)


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
	if not _planned_route.is_empty():
		if _planned_route_index < _planned_route.size() and _planned_route[_planned_route_index] != current_waypoint:
			_planned_route_index = _planned_route.find(current_waypoint)
		_planned_route_index += 1
		if _planned_route_index >= 0 and _planned_route_index < _planned_route.size():
			target_waypoint = _planned_route[_planned_route_index]
			return
		target_waypoint = null
		_recycle_requested = current_waypoint == _trip_exit or current_waypoint.is_exit()
		return
	target_waypoint = network.get_next_waypoint(current_waypoint, previous_waypoint, _random)
	if target_waypoint == null and current_waypoint.is_exit():
		_recycle_requested = true


func _try_rebuild_trip_route() -> void:
	if network == null or current_waypoint == null or _trip_exit == null:
		return
	var rebuilt := network.find_route(current_waypoint, _trip_exit)
	if rebuilt.size() < 2:
		return
	_planned_route = rebuilt
	_planned_route_index = 0
	target_waypoint = rebuilt[1]


func _try_reserve_target_intersection(
	traffic_cars: Array[BaseVehicle]
) -> bool:
	if not is_instance_valid(target_waypoint):
		return true
	if not target_waypoint.has_role(TrafficWaypoint3D.WaypointRole.INTERSECTION_ENTRY):
		return true
	if _reserved_intersection != null:
		return true
	if not _downstream_lane_is_clear(traffic_cars):
		return false
	var intersection := TrafficIntersection3D.find(get_tree(), target_waypoint.intersection_id)
	if intersection == null:
		return false
	var controller := intersection.get_signal_controller()
	if (
		controller != null
		and (
			controller.get_signal_state(target_waypoint.signal_group)
			!= TrafficSignalController3D.SignalState.GREEN
			or not controller.is_vehicle_green_allowed()
		)
	):
		return false
	if not intersection.try_reserve(vehicle, target_waypoint.movement_group):
		return false
	_reserved_intersection = intersection
	return true


func _downstream_lane_is_clear(traffic_cars: Array[BaseVehicle]) -> bool:
	var movement_index := _planned_route.find(target_waypoint)
	if movement_index < 0 or movement_index + 1 >= _planned_route.size():
		return true
	var downstream := _planned_route[movement_index + 1]
	if not downstream.has_role(TrafficWaypoint3D.WaypointRole.INTERSECTION_EXIT):
		return true
	var clear_distance := standstill_gap + downstream.lane_half_width * 2.0
	for other in traffic_cars:
		if other == null or other == vehicle or not is_instance_valid(other):
			continue
		if other.global_position.distance_to(downstream.global_position) < clear_distance:
			return false
	return true


func _release_intersection_reservation() -> void:
	if _reserved_intersection != null:
		_reserved_intersection.release(vehicle)
	_reserved_intersection = null


func _get_target_position() -> Vector3:
	if not is_instance_valid(target_waypoint):
		return vehicle.global_position
	return (
		target_waypoint.global_position
		+ _get_lane_offset(current_waypoint, target_waypoint)
	)


func _get_hold_stopping_distance(target_distance: float) -> float:
	# After arriving at a stop line, the next route target is inside the
	# intersection. If entry is denied, braking relative to that internal target
	# pulls the vehicle into the conflict area. It is already at the authored
	# hold point, so request an immediate stop instead.
	if (
		is_instance_valid(current_waypoint)
		and is_instance_valid(target_waypoint)
		and current_waypoint.has_role(TrafficWaypoint3D.WaypointRole.STOP_LINE)
		and target_waypoint.has_role(
			TrafficWaypoint3D.WaypointRole.INTERSECTION_ENTRY
		)
		and not is_instance_valid(_reserved_intersection)
	):
		return 0.0
	return target_distance


func _has_reached_target(distance: float) -> bool:
	if not is_instance_valid(target_waypoint):
		return false
	var threshold := arrival_distance
	if (
		target_waypoint.has_role(TrafficWaypoint3D.WaypointRole.INTERSECTION_ENTRY)
		or target_waypoint.has_role(TrafficWaypoint3D.WaypointRole.INTERSECTION_EXIT)
	):
		threshold = maxf(threshold, intersection_arrival_distance)
	if distance <= threshold:
		return true
	if _has_passed_intersection_target():
		return true
	return (
		target_waypoint.has_role(TrafficWaypoint3D.WaypointRole.INTERSECTION_ENTRY)
		and _target_elapsed >= intersection_target_timeout
		and distance <= intersection_arrival_distance * 2.0
	)


func _has_passed_intersection_target() -> bool:
	if not is_instance_valid(current_waypoint) or not is_instance_valid(target_waypoint):
		return false
	if not (
		target_waypoint.has_role(TrafficWaypoint3D.WaypointRole.INTERSECTION_ENTRY)
		or target_waypoint.has_role(TrafficWaypoint3D.WaypointRole.INTERSECTION_EXIT)
	):
		return false
	var segment := target_waypoint.global_position - current_waypoint.global_position
	segment.y = 0.0
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.01:
		return false
	var traveled := vehicle.global_position - current_waypoint.global_position
	traveled.y = 0.0
	return traveled.dot(segment) / segment_length_squared >= 0.9


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


func _get_target_signal_state() -> int:
	if not is_instance_valid(target_waypoint):
		return -1
	return target_waypoint.get_signal_state()


func _should_hold_at_signal(
	state: int,
	distance: float,
	forward_speed: float
) -> bool:
	# The signal grants entry at the stop line. Once this vehicle owns the
	# intersection reservation, changing phases must not strand it in the
	# conflict area; obstacle detection still remains active while it clears.
	if is_instance_valid(_reserved_intersection):
		return false
	if distance > maxf(look_ahead_distance, _get_stopping_distance(forward_speed)):
		return false
	if state == TrafficSignalController3D.SignalState.RED:
		return true
	if state == TrafficSignalController3D.SignalState.YELLOW:
		return distance >= _get_stopping_distance(forward_speed)
	return false


func _get_stopping_distance(forward_speed: float) -> float:
	var speed := maxf(forward_speed, 0.0)
	return (
		speed * reaction_time
		+ (speed * speed) / (2.0 * maxf(comfortable_deceleration, 0.1))
		+ standstill_gap
	)


func _get_safe_speed_for_distance(distance: float) -> float:
	var usable_distance := maxf(distance - standstill_gap, 0.0)
	return sqrt(2.0 * maxf(comfortable_deceleration, 0.1) * usable_distance)


func _calculate_speed_controls(
	forward_speed: float,
	target_speed: float,
	stopping_distance: float,
	hard_stop: bool,
	steering: float
) -> Dictionary:
	var throttle := 0.0
	var brake := 0.0
	if forward_speed > target_speed + 0.15:
		var required_deceleration := 0.0
		if is_finite(stopping_distance):
			var usable_distance := maxf(stopping_distance - standstill_gap, 0.15)
			required_deceleration = maxf(
				(forward_speed * forward_speed - target_speed * target_speed)
				/ (2.0 * usable_distance),
				0.0
			)
		brake = clampf(
			maxf(
				0.2,
				required_deceleration / maxf(comfortable_deceleration, 0.1)
			),
			0.0,
			1.0
		)
	elif target_speed > forward_speed + 0.45:
		throttle = (
			cautious_throttle
			if absf(rad_to_deg(steering)) > steering_sensitivity_degrees * 0.55
			else cruise_throttle
		)
	if (
		is_finite(stopping_distance)
		and target_speed <= 0.25
		and stopping_distance <= standstill_gap + 0.45
	):
		throttle = 0.0
		brake = 1.0 if forward_speed > 0.35 else 0.35
	# A hard-stop obstacle means the vehicle must eventually reach zero speed;
	# it does not mean throttle must be cut the instant a probe sees one. Probes
	# can see a pedestrian or a car queued at the next light from well beyond the
	# intersection. Cutting throttle at that range can strand this vehicle in the
	# conflict area and create a network-wide jam.
	if (
		hard_stop
		and is_finite(stopping_distance)
		and stopping_distance <= _get_stopping_distance(forward_speed)
	):
		throttle = 0.0
	return {"throttle": throttle, "brake": brake}


func _get_obstacle_ahead(
	traffic_cars: Array[BaseVehicle],
	allow_raycast: bool,
	forward_speed: float
) -> Dictionary:
	var result := {"blocked": false, "distance": INF, "hard_stop": false}
	var forward := vehicle.global_basis.z.normalized()
	var side := vehicle.global_basis.x.normalized()
	var origin := vehicle.global_position + Vector3.UP * 0.65
	var detection_distance := maxf(
		following_distance,
		maxf(
			_get_stopping_distance(forward_speed),
			forward_speed * following_time + standstill_gap
		)
	)
	for other in traffic_cars:
		if other == vehicle or not is_instance_valid(other):
			continue
		var offset := other.global_position - vehicle.global_position
		offset.y = 0.0
		var distance_squared := offset.length_squared()
		if distance_squared > detection_distance * detection_distance:
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
		var other_ai := _get_traffic_ai(other)
		_record_obstacle(
			result,
			forward_distance,
			other_ai != null and other_ai.is_hard_stop_active()
		)

	if not allow_raycast:
		if not bool(result.get("blocked", false)) and _last_raycast_blocked:
			_record_obstacle(
				result,
				_last_raycast_distance,
				_last_raycast_requires_full_stop
			)
		return result

	_last_raycast_blocked = false
	_last_raycast_requires_full_stop = false
	_last_raycast_distance = INF
	var probe_offsets: PackedFloat32Array = PackedFloat32Array([
		0.0,
		-pedestrian_probe_half_width,
		pedestrian_probe_half_width,
	])
	for lateral_offset: float in probe_offsets:
		var probe_origin: Vector3 = origin + side * lateral_offset
		var query := PhysicsRayQueryParameters3D.create(
			probe_origin,
			probe_origin + forward * detection_distance,
			obstacle_mask,
			[vehicle.get_rid()]
		)
		query.collide_with_areas = true
		var hit := vehicle.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var collider := hit.get("collider") as Node
		if collider == null or collider == vehicle:
			continue
		var is_human := _is_human_obstacle(collider)
		var is_vehicle := collider is BaseVehicle or collider.is_in_group("traffic_vehicle")
		if not (is_human or is_vehicle):
			continue
		var hit_position := hit.get("position") as Vector3
		var hit_distance := maxf((hit_position - probe_origin).dot(forward), 0.0)
		var is_hard_stop := is_human
		_record_obstacle(result, hit_distance, is_hard_stop)
		_last_raycast_blocked = true
		_last_raycast_requires_full_stop = (
			_last_raycast_requires_full_stop or is_hard_stop
		)
		_last_raycast_distance = minf(_last_raycast_distance, hit_distance)
	return result


func _record_obstacle(
	result: Dictionary,
	distance: float,
	hard_stop: bool
) -> void:
	if distance < float(result.get("distance", INF)):
		result["blocked"] = true
		result["distance"] = distance
		result["hard_stop"] = hard_stop


func _is_human_obstacle(collider: Node) -> bool:
	return (
		collider is BaseNPC
		or collider.is_in_group("traffic_obstacle")
		or collider.is_in_group("player")
		or collider.is_in_group("customer_npc")
		or collider.is_in_group("police_npc")
		or collider.is_in_group("interactable_npc")
	)


func _stop_vehicle() -> void:
	_hard_stop_active = false
	if vehicle != null:
		vehicle.drive_component.set_ai_control(0.0, 1.0, 0.0)


func _get_traffic_ai(other: BaseVehicle) -> TrafficVehicleAIComponent:
	if other == null:
		return null
	return other.get_node_or_null("TrafficAIComponent") as TrafficVehicleAIComponent
