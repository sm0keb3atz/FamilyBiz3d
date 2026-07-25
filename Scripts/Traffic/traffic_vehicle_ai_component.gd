class_name TrafficVehicleAIComponent
extends Node

signal destination_reached

@export_range(0.5, 8.0, 0.1) var arrival_distance := 3.0
@export_range(3.0, 10.0, 0.25) var intersection_arrival_distance := 6.0
@export_range(1.0, 10.0, 0.5) var intersection_target_timeout := 4.0
@export_range(1.0, 60.0, 0.5) var look_ahead_distance := 35.0
@export_range(1.0, 60.0, 0.5) var following_distance := 35.0
@export_range(1.0, 60.0, 0.5) var steering_sensitivity_degrees := 45.0
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
@export_category("Destination Arrival")
@export_range(0.5, 4.0, 0.1) var destination_stop_gap := 1.5
@export_range(0.1, 2.0, 0.05) var destination_arrival_speed := 0.75
@export_category("Emergency Traffic")
@export_range(10.0, 100.0, 1.0) var emergency_yield_distance := 55.0
@export_range(0.5, 5.0, 0.1) var emergency_yield_duration := 2.0
@export_range(0.0, 1.0, 0.05) var emergency_yield_speed_multiplier := 0.35
@export_range(0.0, 3.0, 0.1) var emergency_yield_lateral_offset := 1.2
@export_range(6.0, 30.0, 1.0) var emergency_pass_trigger_distance := 18.0
@export_range(3.0, 12.0, 0.5) var emergency_pass_speed := 6.5
@export_range(2.0, 10.0, 0.5) var emergency_pass_timeout := 6.0
@export_range(2.0, 8.0, 0.5) var emergency_local_path_side_offset := 4.5
@export_range(8.0, 24.0, 1.0) var emergency_local_path_lookahead := 16.0

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
var _stop_at_destination := false
var _destination_reached_emitted := false
var _dynamic_destination_active := false
var _dynamic_terminal_active := false
var _dynamic_destination_position := Vector3.ZERO
var _dynamic_segment_start: TrafficWaypoint3D
var _dynamic_segment_end: TrafficWaypoint3D
var _dynamic_approach_direction := Vector3.ZERO
var _emergency_mode := false
var _emergency_yield_remaining := 0.0
var _emergency_pass_active := false
var _emergency_pass_target := Vector3.ZERO
var _emergency_pass_direction := Vector3.ZERO
var _emergency_pass_blocker: Node3D
var _emergency_pass_elapsed := 0.0
var _emergency_pass_attempt_count := 0
var _emergency_pass_activation_count := 0
var _emergency_detour_count := 0
var _emergency_planner_cooldown_remaining := 0.0


func initialize(owner_vehicle: BaseVehicle) -> void:
	vehicle = owner_vehicle


func assign_route(
	traffic_network: TrafficNetwork3D,
	start_waypoint: TrafficWaypoint3D,
	random_seed: int
) -> void:
	_initialize_route(traffic_network, start_waypoint, random_seed)
	_trip_exit = network.choose_reachable_exit(start_waypoint, _random)
	if _trip_exit != null:
		_planned_route = network.find_route(start_waypoint, _trip_exit)
	_choose_next()


func _initialize_route(
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
	_trip_exit = null
	_stop_at_destination = false
	_destination_reached_emitted = false
	_clear_dynamic_destination()
	_emergency_yield_remaining = 0.0
	_emergency_planner_cooldown_remaining = 0.0
	_emergency_pass_attempt_count = 0
	_emergency_pass_activation_count = 0
	_emergency_detour_count = 0
	_clear_emergency_pass()
	_tracked_target_id = 0
	_target_elapsed = 0.0


func assign_route_to(
	traffic_network: TrafficNetwork3D,
	start_waypoint: TrafficWaypoint3D,
	destination: TrafficWaypoint3D,
	random_seed: int,
	stop_at_destination := true
) -> bool:
	_initialize_route(traffic_network, start_waypoint, random_seed)
	var route := traffic_network.find_route(start_waypoint, destination)
	if route.size() < 2:
		clear()
		return false
	_trip_exit = destination
	_planned_route = route
	_planned_route_index = 0
	_stop_at_destination = stop_at_destination
	_destination_reached_emitted = false
	_recycle_requested = false
	current_waypoint = start_waypoint
	previous_waypoint = null
	target_waypoint = null
	_choose_next()
	return true


func assign_route_to_world_position(
	traffic_network: TrafficNetwork3D,
	start_waypoint: TrafficWaypoint3D,
	world_position: Vector3,
	random_seed: int,
	stop_at_destination := true,
	stand_off_distance := 0.0,
	excluded_positions: Array[Vector3] = [],
	minimum_separation := 0.0
) -> bool:
	var road_target := traffic_network.find_reachable_road_target(
		start_waypoint,
		world_position,
		start_waypoint.global_position,
		stand_off_distance,
		excluded_positions,
		minimum_separation
	)
	if road_target.is_empty():
		clear()
		return false
	return assign_route_to_road_target(
		traffic_network,
		start_waypoint,
		road_target,
		random_seed,
		stop_at_destination
	)


func assign_route_to_road_target(
	traffic_network: TrafficNetwork3D,
	start_waypoint: TrafficWaypoint3D,
	road_target: Dictionary,
	random_seed: int,
	stop_at_destination := true
) -> bool:
	_initialize_route(traffic_network, start_waypoint, random_seed)
	if not _configure_dynamic_route(road_target, stop_at_destination):
		clear()
		return false
	return true


func retarget_world_position(
	world_position: Vector3,
	stop_at_destination := true,
	stand_off_distance := 0.0,
	excluded_positions: Array[Vector3] = [],
	minimum_separation := 0.0
) -> bool:
	if network == null or current_waypoint == null:
		return false
	var road_target := network.find_reachable_road_target(
		current_waypoint,
		world_position,
		vehicle.global_position if vehicle != null else Vector3.INF,
		stand_off_distance,
		excluded_positions,
		minimum_separation
	)
	if road_target.is_empty():
		return false
	return _configure_dynamic_route(road_target, stop_at_destination)


func _configure_dynamic_route(
	road_target: Dictionary,
	stop_at_destination: bool
) -> bool:
	var route := road_target.get("route", []) as Array
	var segment_start := road_target.get("segment_start") as TrafficWaypoint3D
	var segment_end := road_target.get("segment_end") as TrafficWaypoint3D
	var position := road_target.get("position", Vector3.INF) as Vector3
	if route.is_empty() or segment_start == null or segment_end == null or not position.is_finite():
		return false
	_planned_route.clear()
	for waypoint in route:
		if waypoint is TrafficWaypoint3D:
			_planned_route.append(waypoint as TrafficWaypoint3D)
	if _planned_route.is_empty():
		return false
	_trip_exit = segment_start
	_dynamic_destination_active = true
	_dynamic_terminal_active = false
	_dynamic_destination_position = position
	_dynamic_segment_start = segment_start
	_dynamic_segment_end = segment_end
	_dynamic_approach_direction = road_target.get(
		"approach_direction", Vector3.ZERO
	) as Vector3
	_stop_at_destination = stop_at_destination
	_destination_reached_emitted = false
	_recycle_requested = false
	_planned_route_index = 0
	target_waypoint = null
	_choose_next()
	return true


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
	_stop_at_destination = false
	_destination_reached_emitted = false
	_clear_dynamic_destination()
	_emergency_mode = false
	_emergency_yield_remaining = 0.0
	_clear_emergency_pass()
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
	_emergency_yield_remaining = maxf(
		_emergency_yield_remaining - delta,
		0.0
	)
	_emergency_planner_cooldown_remaining = maxf(
		_emergency_planner_cooldown_remaining - delta,
		0.0
	)
	if _emergency_mode:
		_request_lane_clearance(traffic_cars)
	_update_emergency_pass(delta)
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
	var planar_speed := Vector2(
		vehicle.linear_velocity.x,
		vehicle.linear_velocity.z
	).length()
	var control_speed := maxf(forward_speed, planar_speed)
	var target_position := _get_target_position()
	if _emergency_yield_remaining > 0.0 and not _emergency_mode:
		target_position += vehicle.global_basis.x * emergency_yield_lateral_offset
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
		and _has_reached_target(target_distance, control_speed)
	):
		if _dynamic_terminal_active:
			_complete_dynamic_destination()
			_stop_vehicle()
			return
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
		control_speed
	)
	if (
		_emergency_mode
		and not _emergency_pass_active
		and is_zero_approx(_emergency_planner_cooldown_remaining)
	):
		_try_begin_emergency_pass(obstacle, traffic_cars)
		if _emergency_pass_active:
			obstacle = _get_obstacle_ahead(
				traffic_cars,
				allow_raycast,
				control_speed
			)
	if _emergency_pass_active:
		target_position = _emergency_pass_target
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
	if _emergency_mode:
		target_speed *= 1.35
	elif _emergency_yield_remaining > 0.0:
		target_speed *= emergency_yield_speed_multiplier
	target_speed = minf(target_speed, _curve_speed_limit(steering))
	if _emergency_pass_active:
		target_speed = minf(target_speed, emergency_pass_speed)
	var terminal_approach := (
		_dynamic_terminal_active
		and _stop_at_destination
		and not _emergency_pass_active
	)
	if terminal_approach:
		var usable_terminal_distance := maxf(
			target_distance - destination_stop_gap,
			0.0
		)
		var terminal_speed := sqrt(
			2.0 * maxf(comfortable_deceleration, 0.1)
			* usable_terminal_distance
		)
		target_speed = minf(target_speed, terminal_speed)
	if is_finite(stopping_distance):
		target_speed = minf(
			target_speed,
			_get_safe_speed_for_distance(stopping_distance)
		)
	var controls := _calculate_speed_controls(
		control_speed,
		target_speed,
		stopping_distance,
		hard_stop_blocked,
		steering
	)
	if terminal_approach:
		if target_distance <= destination_stop_gap + 0.5:
			controls["throttle"] = 0.0
			controls["brake"] = 1.0 if control_speed > destination_arrival_speed else 0.35
		elif control_speed > target_speed + 0.15:
			controls["throttle"] = 0.0
			controls["brake"] = maxf(
				float(controls.get("brake", 0.0)),
				clampf(
					(control_speed - target_speed)
					/ maxf(emergency_deceleration, 0.1),
					0.2,
					1.0
				)
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


func get_destination_waypoint() -> TrafficWaypoint3D:
	return _trip_exit


func get_destination_position() -> Vector3:
	if _dynamic_destination_active:
		return _dynamic_destination_position
	return _trip_exit.global_position if is_instance_valid(_trip_exit) else Vector3.INF


func get_destination_approach_direction() -> Vector3:
	return _dynamic_approach_direction


func has_dynamic_destination() -> bool:
	return _dynamic_destination_active


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


func has_reached_destination() -> bool:
	return _destination_reached_emitted


func set_emergency_mode(enabled: bool) -> void:
	_emergency_mode = enabled


func is_emergency_mode() -> bool:
	return _emergency_mode


func request_emergency_yield(duration := -1.0) -> void:
	if _emergency_mode:
		return
	_emergency_yield_remaining = maxf(
		_emergency_yield_remaining,
		emergency_yield_duration if duration < 0.0 else duration
	)


func is_yielding_to_emergency() -> bool:
	return _emergency_yield_remaining > 0.0


func get_emergency_pass_attempt_count() -> int:
	return _emergency_pass_attempt_count


func get_emergency_pass_activation_count() -> int:
	return _emergency_pass_activation_count


func get_emergency_detour_count() -> int:
	return _emergency_detour_count


func _has_emergency_priority() -> bool:
	return _emergency_mode or _emergency_yield_remaining > 0.0


func _request_lane_clearance(traffic_cars: Array[BaseVehicle]) -> void:
	var forward := vehicle.global_basis.z.normalized()
	for other in traffic_cars:
		if other == null or other == vehicle or not is_instance_valid(other):
			continue
		var offset := other.global_position - vehicle.global_position
		offset.y = 0.0
		if (
			offset.dot(forward) <= 0.0
			or offset.length_squared()
			> emergency_yield_distance * emergency_yield_distance
		):
			continue
		var other_ai := _get_traffic_ai(other)
		if (
			other_ai == null
			or other_ai.is_emergency_mode()
			or not _is_same_lane_obstacle(other_ai)
		):
			continue
		other_ai.request_emergency_yield(emergency_yield_duration)


func _try_begin_emergency_pass(
	obstacle: Dictionary,
	traffic_cars: Array[BaseVehicle]
) -> void:
	var blocker := obstacle.get("blocker") as Node3D
	if (
		not bool(obstacle.get("blocked", false))
		or blocker == null
		or float(obstacle.get("distance", INF)) > emergency_pass_trigger_distance
		or not is_instance_valid(current_waypoint)
		or not is_instance_valid(target_waypoint)
		or current_waypoint.has_role(TrafficWaypoint3D.WaypointRole.STOP_LINE)
		or target_waypoint.has_role(TrafficWaypoint3D.WaypointRole.INTERSECTION_ENTRY)
		or target_waypoint.has_role(TrafficWaypoint3D.WaypointRole.INTERSECTION_EXIT)
	):
		return
	var blocker_speed := 0.0
	if blocker is BaseVehicle:
		blocker_speed = (blocker as BaseVehicle).linear_velocity.length()
	elif blocker is CharacterBody3D:
		blocker_speed = (blocker as CharacterBody3D).velocity.length()
	if blocker_speed > 2.0:
		return
	_emergency_pass_attempt_count += 1
	_emergency_planner_cooldown_remaining = 0.5
	var route_direction := (
		target_waypoint.global_position - current_waypoint.global_position
	)
	route_direction.y = 0.0
	if route_direction.is_zero_approx():
		return
	route_direction = route_direction.normalized()
	var lane_choice := network.find_adjacent_lane_target(
		vehicle.global_position,
		route_direction,
		emergency_local_path_lookahead
	)
	var candidates: Array[Dictionary] = []
	if not lane_choice.is_empty():
		candidates.append(lane_choice)
	var side := Vector3(-route_direction.z, 0.0, route_direction.x)
	for side_sign in [1.0, -1.0]:
		for side_scale in [1.0, 1.35]:
			candidates.append({
				"target": (
					vehicle.global_position
					+ route_direction * emergency_local_path_lookahead
					+ side * side_sign * emergency_local_path_side_offset * side_scale
				),
				"direction": route_direction,
			})
	for candidate in candidates:
		var pass_target := candidate.get("target", Vector3.ZERO) as Vector3
		var pass_direction := candidate.get(
			"direction", route_direction
		) as Vector3
		var grounded_target := _ground_local_path_point(pass_target)
		if grounded_target.is_empty():
			continue
		pass_target = grounded_target.get("position") as Vector3
		if not _is_emergency_corridor_clear(
			pass_target,
			blocker,
			traffic_cars
		):
			continue
		_emergency_pass_active = true
		_emergency_pass_target = pass_target
		_emergency_pass_direction = pass_direction.normalized()
		_emergency_pass_blocker = blocker
		_emergency_pass_elapsed = 0.0
		_emergency_pass_activation_count += 1
		return
	_try_emergency_graph_detour()


func _update_emergency_pass(delta: float) -> void:
	if not _emergency_pass_active:
		return
	_emergency_pass_elapsed += delta
	if not is_instance_valid(_emergency_pass_blocker):
		_clear_emergency_pass()
		return
	var relative := vehicle.global_position - _emergency_pass_blocker.global_position
	relative.y = 0.0
	if relative.dot(_emergency_pass_direction) >= 5.0:
		_clear_emergency_pass()
		return
	if _emergency_pass_elapsed >= emergency_pass_timeout:
		_clear_emergency_pass()
		_try_emergency_graph_detour()


func _clear_emergency_pass() -> void:
	_emergency_pass_active = false
	_emergency_pass_target = Vector3.ZERO
	_emergency_pass_direction = Vector3.ZERO
	_emergency_pass_blocker = null
	_emergency_pass_elapsed = 0.0


func _try_emergency_graph_detour() -> bool:
	if (
		network == null
		or current_waypoint == null
		or target_waypoint == null
		or _trip_exit == null
	):
		return false
	var blocked_waypoints: Array[TrafficWaypoint3D] = [target_waypoint]
	var detour := network.find_route_avoiding(
		current_waypoint,
		_trip_exit,
		blocked_waypoints
	)
	if detour.size() < 2:
		return false
	_planned_route = detour
	_planned_route_index = 0
	target_waypoint = detour[1]
	_tracked_target_id = 0
	_emergency_detour_count += 1
	return true


func _ground_local_path_point(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * 3.0,
		point - Vector3.UP * 4.0
	)
	query.collision_mask = obstacle_mask
	query.collide_with_areas = false
	query.exclude = [vehicle.get_rid()]
	var hit := vehicle.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var ground_position := hit.get("position") as Vector3
	if absf(ground_position.y - vehicle.global_position.y) > 1.0:
		return {}
	return {"position": ground_position}


func _is_emergency_corridor_clear(
	pass_target: Vector3,
	blocker: Node3D,
	traffic_cars: Array[BaseVehicle]
) -> bool:
	var start := vehicle.global_position
	var corridor := pass_target - start
	corridor.y = 0.0
	var corridor_length_squared := corridor.length_squared()
	if corridor_length_squared < 4.0:
		return false
	for other in traffic_cars:
		if (
			other == null
			or other == vehicle
			or other == blocker
			or not is_instance_valid(other)
		):
			continue
		var offset := other.global_position - start
		offset.y = 0.0
		var progress := clampf(
			offset.dot(corridor) / corridor_length_squared,
			0.0,
			1.0
		)
		var closest := start + corridor * progress
		if other.global_position.distance_to(closest) < 2.35:
			return false
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.55, 1.15, 2.5)
	for sample_index in range(1, 6):
		var blend := float(sample_index) / 5.0
		var sample := start.lerp(pass_target, blend)
		var ground := _ground_local_path_point(sample)
		if ground.is_empty():
			return false
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(
			Basis.looking_at(corridor.normalized(), Vector3.UP, true),
			(ground.get("position") as Vector3) + Vector3.UP * 1.0
		)
		query.collision_mask = obstacle_mask
		query.collide_with_areas = false
		var exclusions: Array[RID] = [vehicle.get_rid()]
		if blocker is CollisionObject3D:
			exclusions.append((blocker as CollisionObject3D).get_rid())
		query.exclude = exclusions
		if not vehicle.get_world_3d().direct_space_state.intersect_shape(
			query,
			1
		).is_empty():
			return false
	return true


func retarget_destination(destination: TrafficWaypoint3D) -> bool:
	if network == null or current_waypoint == null or destination == null:
		return false
	var route := network.find_route(current_waypoint, destination)
	if route.size() < 2:
		return false
	_trip_exit = destination
	_clear_dynamic_destination()
	_planned_route = route
	_planned_route_index = 0
	_stop_at_destination = true
	_destination_reached_emitted = false
	_recycle_requested = false
	target_waypoint = null
	_choose_next()
	return true


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
		if (
			current_waypoint == _trip_exit
			and _dynamic_destination_active
			and not _destination_reached_emitted
		):
			target_waypoint = _dynamic_segment_end
			_dynamic_terminal_active = true
			return
		if current_waypoint == _trip_exit and _stop_at_destination:
			if not _destination_reached_emitted:
				_destination_reached_emitted = true
				destination_reached.emit()
			_recycle_requested = false
		else:
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
		and not _has_emergency_priority()
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
		var other_ai := _get_traffic_ai(other)
		if other_ai == null:
			continue
		# Only occupancy of this exact outbound lane can block entry. The old
		# circular distance check also caught the opposing lane, allowing two
		# queues to wait on one another forever at a busy intersection.
		if not (
			other_ai.get_current_waypoint() == downstream
			or other_ai.get_target_waypoint() == downstream
		):
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
	if _dynamic_terminal_active:
		return _dynamic_destination_position
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


func _has_reached_target(distance: float, speed: float) -> bool:
	if not is_instance_valid(target_waypoint):
		return false
	if _dynamic_terminal_active:
		var reached_position := (
			distance <= arrival_distance
			or _has_passed_dynamic_destination()
		)
		return reached_position and (
			not _stop_at_destination
			or speed <= destination_arrival_speed
		)
	var threshold := arrival_distance
	if (
		target_waypoint.has_role(TrafficWaypoint3D.WaypointRole.INTERSECTION_ENTRY)
		or target_waypoint.has_role(TrafficWaypoint3D.WaypointRole.INTERSECTION_EXIT)
	):
		threshold = maxf(threshold, intersection_arrival_distance)
	if distance <= threshold:
		return true
	if _has_passed_route_target():
		return true
	return (
		target_waypoint.has_role(TrafficWaypoint3D.WaypointRole.INTERSECTION_ENTRY)
		and _target_elapsed >= intersection_target_timeout
		and distance <= intersection_arrival_distance * 2.0
	)


func _has_passed_route_target() -> bool:
	if not is_instance_valid(current_waypoint) or not is_instance_valid(target_waypoint):
		return false
	var segment := target_waypoint.global_position - current_waypoint.global_position
	segment.y = 0.0
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.01:
		return false
	var traveled := vehicle.global_position - current_waypoint.global_position
	traveled.y = 0.0
	var progress := traveled.dot(segment) / segment_length_squared
	if progress < 0.9:
		return false
	var closest := segment * clampf(progress, 0.0, 1.0)
	var cross_track_error := traveled.distance_to(closest)
	var maximum_cross_track := maxf(
		arrival_distance * 2.0,
		target_waypoint.lane_half_width * 3.0
	)
	return cross_track_error <= maximum_cross_track


func _has_passed_dynamic_destination() -> bool:
	if not _dynamic_terminal_active or not is_instance_valid(_dynamic_segment_start):
		return false
	var segment := (
		_dynamic_destination_position
		- _dynamic_segment_start.global_position
	)
	segment.y = 0.0
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.01:
		return false
	var traveled := vehicle.global_position - _dynamic_segment_start.global_position
	traveled.y = 0.0
	var progress := traveled.dot(segment) / segment_length_squared
	if progress < 1.0:
		return false
	var closest := segment * clampf(progress, 0.0, 1.0)
	return traveled.distance_to(closest) <= maxf(
		arrival_distance * 2.0,
		target_waypoint.lane_half_width * 3.0
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
	var steering_target := _get_segment_lookahead(target_position)
	var direction := steering_target - vehicle.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		return 0.0
	direction = direction.normalized()
	var local_direction := vehicle.global_basis.inverse() * direction
	var target_angle := atan2(local_direction.x, local_direction.z)
	var maximum := deg_to_rad(steering_sensitivity_degrees)
	return clampf(target_angle, -maximum, maximum)


func _get_segment_lookahead(fallback: Vector3) -> Vector3:
	if not is_instance_valid(current_waypoint) or not is_instance_valid(target_waypoint):
		return fallback
	var start := (
		current_waypoint.global_position
		+ _get_lane_offset(current_waypoint, target_waypoint)
	)
	var finish := (
		_dynamic_destination_position
		if _dynamic_terminal_active
		else (
			target_waypoint.global_position
			+ _get_lane_offset(current_waypoint, target_waypoint)
		)
	)
	var segment := finish - start
	segment.y = 0.0
	var length := segment.length()
	if length <= 0.01:
		return fallback
	var direction := segment / length
	var from_start := vehicle.global_position - start
	from_start.y = 0.0
	var progress := clampf(from_start.dot(direction), 0.0, length)
	var speed := vehicle.linear_velocity.length()
	var lookahead := clampf(3.0 + speed * 0.45, 3.0, 10.0)
	return start + direction * minf(progress + lookahead, length)


func get_route_cross_track_error() -> float:
	if not is_instance_valid(current_waypoint) or not is_instance_valid(target_waypoint):
		return 0.0
	var start := current_waypoint.global_position
	var finish := target_waypoint.global_position
	var segment := finish - start
	segment.y = 0.0
	var length_squared := segment.length_squared()
	if length_squared <= 0.01:
		return vehicle.global_position.distance_to(finish)
	var offset := vehicle.global_position - start
	offset.y = 0.0
	var progress := clampf(offset.dot(segment) / length_squared, 0.0, 1.0)
	return offset.distance_to(segment * progress)


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
	if _has_emergency_priority():
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
	var result := {
		"blocked": false,
		"distance": INF,
		"hard_stop": false,
		"blocker": null,
	}
	var forward := vehicle.global_basis.z.normalized()
	var side := vehicle.global_basis.x.normalized()
	var origin := vehicle.global_position + Vector3.UP * 0.65
	var effective_following_distance := following_distance * (0.6 if _emergency_mode else 1.0)
	var detection_distance := maxf(
		effective_following_distance,
		maxf(
			_get_stopping_distance(forward_speed),
			forward_speed * following_time + standstill_gap
		)
	)
	for other in traffic_cars:
		if other == vehicle or not is_instance_valid(other):
			continue
		if _emergency_pass_active and other == _emergency_pass_blocker:
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
		if other_ai != null and not _is_same_lane_obstacle(other_ai):
			continue
		_record_obstacle(
			result,
			forward_distance,
			other_ai != null and other_ai.is_hard_stop_active(),
			other
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
		var exclusions: Array[RID] = [vehicle.get_rid()]
		if (
			_emergency_pass_active
			and is_instance_valid(_emergency_pass_blocker)
			and _emergency_pass_blocker is CollisionObject3D
		):
			exclusions.append(
				(_emergency_pass_blocker as CollisionObject3D).get_rid()
			)
		var query := PhysicsRayQueryParameters3D.create(
			probe_origin,
			probe_origin + forward * detection_distance,
			obstacle_mask,
			exclusions
		)
		query.collide_with_areas = true
		var hit := vehicle.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var collider := hit.get("collider") as Node
		if collider == null or collider == vehicle:
			continue
		var is_human := _is_human_obstacle(collider)
		var blocking_vehicle := _find_vehicle_ancestor(collider)
		var is_vehicle := blocking_vehicle != null
		if not (is_human or is_vehicle):
			continue
		# A ray hit is a real body in the driven corridor. Never discard it merely
		# because another manager or route reports a different waypoint pair.
		var hit_position := hit.get("position") as Vector3
		var hit_distance := maxf((hit_position - probe_origin).dot(forward), 0.0)
		var is_hard_stop := is_human
		_record_obstacle(
			result,
			hit_distance,
			is_hard_stop,
			blocking_vehicle if blocking_vehicle != null else collider
		)
		_last_raycast_blocked = true
		_last_raycast_requires_full_stop = (
			_last_raycast_requires_full_stop or is_hard_stop
		)
		_last_raycast_distance = minf(_last_raycast_distance, hit_distance)
	return result


func _record_obstacle(
	result: Dictionary,
	distance: float,
	hard_stop: bool,
	blocker: Node = null
) -> void:
	if distance < float(result.get("distance", INF)):
		result["blocked"] = true
		result["distance"] = distance
		result["hard_stop"] = hard_stop
		result["blocker"] = blocker


func _find_vehicle_ancestor(node: Node) -> BaseVehicle:
	var current := node
	while current != null:
		if current is BaseVehicle:
			return current as BaseVehicle
		current = current.get_parent()
	return null


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


func _complete_dynamic_destination() -> void:
	_dynamic_terminal_active = false
	target_waypoint = null
	if not _destination_reached_emitted:
		_destination_reached_emitted = true
		destination_reached.emit()
	_recycle_requested = false


func _clear_dynamic_destination() -> void:
	_dynamic_destination_active = false
	_dynamic_terminal_active = false
	_dynamic_destination_position = Vector3.ZERO
	_dynamic_segment_start = null
	_dynamic_segment_end = null
	_dynamic_approach_direction = Vector3.ZERO


func _get_traffic_ai(other: BaseVehicle) -> TrafficVehicleAIComponent:
	if other == null:
		return null
	return other.get_node_or_null("TrafficAIComponent") as TrafficVehicleAIComponent


func _is_same_lane_obstacle(other_ai: TrafficVehicleAIComponent) -> bool:
	if other_ai == null:
		return true
	var other_current := other_ai.get_current_waypoint()
	var other_target := other_ai.get_target_waypoint()
	if not is_instance_valid(current_waypoint) or not is_instance_valid(target_waypoint):
		return true
	if (
		other_current == current_waypoint
		or other_current == target_waypoint
		or other_target == current_waypoint
		or other_target == target_waypoint
	):
		return true
	if not is_instance_valid(other_current) or not is_instance_valid(other_target):
		return true
	var our_direction := target_waypoint.global_position - current_waypoint.global_position
	var other_direction := other_target.global_position - other_current.global_position
	our_direction.y = 0.0
	other_direction.y = 0.0
	if our_direction.is_zero_approx() or other_direction.is_zero_approx():
		return true
	if our_direction.normalized().dot(other_direction.normalized()) < 0.65:
		return false
	var lateral := absf(
		(other_ai.vehicle.global_position - vehicle.global_position).dot(
			Vector3(-our_direction.z, 0.0, our_direction.x).normalized()
		)
	)
	return lateral <= current_waypoint.lane_half_width * 2.0 + lane_block_margin
