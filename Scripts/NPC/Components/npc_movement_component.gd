class_name NPCMovementComponent
extends Node

@export_category("Movement")
@export_range(0.1, 20.0, 0.1) var move_speed := 2.5
@export_range(0.1, 30.0, 0.1) var acceleration := 10.0
@export_range(0.1, 30.0, 0.1) var turn_speed := 8.0

@export_category("Local Obstacle Steering")
@export_range(0.5, 4.0, 0.1) var obstacle_probe_distance := 1.6
@export_range(10.0, 80.0, 1.0) var obstacle_probe_angle_degrees := 38.0
@export_range(0.02, 0.5, 0.01) var obstacle_probe_interval := 0.12
@export_range(0.0, 1.0, 0.05) var obstacle_steering_strength := 0.8
@export_range(0.1, 2.0, 0.1) var obstacle_probe_height := 0.75
@export_flags_3d_physics var obstacle_probe_collision_mask := 3

var npc
var _gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _navigation_target := Vector3.ZERO
var _has_navigation_target := false
var _navigation_target_update_count := 0
var _pending_movement_delta := 0.0
var _obstacle_probe_remaining := 0.0
var _cached_steering_direction := Vector3.ZERO
var _local_obstacle_steering_enabled := true
var _obstacle_query: PhysicsRayQueryParameters3D
var _facing_override_enabled := false
var _facing_override_position := Vector3.ZERO


func initialize(owner_npc: CharacterBody3D) -> void:
	npc = owner_npc
	_obstacle_query = PhysicsRayQueryParameters3D.new()
	_obstacle_query.collision_mask = npc.obstacle_probe_collision_mask
	_obstacle_query.exclude = [npc.get_rid()]
	_obstacle_query.collide_with_areas = false
	npc.navigation_agent.velocity_computed.connect(
		_on_navigation_velocity_computed
	)


func set_navigation_target(target: Vector3) -> bool:
	if npc.is_defeated():
		return false
	if _has_navigation_target and _navigation_target.is_equal_approx(target):
		return false
	_navigation_target = target
	_has_navigation_target = true
	_navigation_target_update_count += 1
	_obstacle_probe_remaining = 0.0
	_cached_steering_direction = Vector3.ZERO
	npc.navigation_agent.target_position = target
	return true


func clear_navigation_target() -> void:
	_has_navigation_target = false
	_navigation_target = npc.global_position


func get_navigation_target_update_count() -> int:
	return _navigation_target_update_count


func set_navigation_avoidance_enabled(enabled: bool) -> void:
	var should_enable: bool = enabled and not npc.is_defeated()
	if npc.navigation_agent.avoidance_enabled == should_enable:
		return
	if should_enable:
		npc.navigation_agent.set_velocity_forced(
			Vector3(npc.velocity.x, 0.0, npc.velocity.z)
		)
	npc.navigation_agent.avoidance_enabled = should_enable


func set_local_obstacle_steering_enabled(enabled: bool) -> void:
	if _local_obstacle_steering_enabled == enabled:
		return
	_local_obstacle_steering_enabled = enabled
	if not enabled:
		_obstacle_probe_remaining = 0.0
		_cached_steering_direction = Vector3.ZERO


func set_obstacle_probe_delay(delay: float) -> void:
	_obstacle_probe_remaining = maxf(delay, 0.0)


func set_facing_override(world_position: Vector3) -> void:
	_facing_override_enabled = true
	_facing_override_position = world_position


func clear_facing_override() -> void:
	_facing_override_enabled = false


func move_toward_navigation_target(target: Vector3, delta: float) -> void:
	set_navigation_target(target)
	advance_navigation(delta)


func advance_navigation(delta: float) -> void:
	if npc.is_defeated():
		return
	if not _has_navigation_target:
		stop_moving(delta)
		return
	var next_position: Vector3 = (
		npc.navigation_agent.get_next_path_position()
	)
	var direction: Vector3 = next_position - npc.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		stop_moving(delta)
		return
	direction = _get_obstacle_steered_direction(direction.normalized(), delta)
	var target_velocity: Vector3 = direction * npc.move_speed
	var desired_velocity := Vector3.ZERO
	desired_velocity.x = move_toward(
		npc.velocity.x, target_velocity.x, npc.acceleration * delta
	)
	desired_velocity.z = move_toward(
		npc.velocity.z, target_velocity.z, npc.acceleration * delta
	)
	_submit_horizontal_movement(desired_velocity, delta)


func stop_moving(delta: float) -> void:
	if npc.is_defeated():
		return
	var desired_velocity := Vector3.ZERO
	desired_velocity.x = move_toward(
		npc.velocity.x, 0.0, npc.acceleration * delta
	)
	desired_velocity.z = move_toward(
		npc.velocity.z, 0.0, npc.acceleration * delta
	)
	_submit_horizontal_movement(desired_velocity, delta)


func get_horizontal_speed() -> float:
	return sqrt(get_horizontal_speed_squared())


func get_horizontal_speed_squared() -> float:
	return (
		npc.velocity.x * npc.velocity.x
		+ npc.velocity.z * npc.velocity.z
	)


func reset_for_reuse() -> void:
	npc.velocity = Vector3.ZERO
	_obstacle_probe_remaining = 0.0
	_cached_steering_direction = Vector3.ZERO
	_local_obstacle_steering_enabled = true
	_facing_override_enabled = false
	clear_navigation_target()


func _apply_gravity(delta: float) -> void:
	if not npc.is_on_floor():
		npc.velocity.y -= _gravity * delta
	else:
		npc.velocity.y = 0.0


func _get_obstacle_steered_direction(
	desired_direction: Vector3,
	delta: float
) -> Vector3:
	if not _local_obstacle_steering_enabled:
		return desired_direction
	_obstacle_probe_remaining = maxf(_obstacle_probe_remaining - delta, 0.0)
	if (
		_obstacle_probe_remaining > 0.0
		and not _cached_steering_direction.is_zero_approx()
	):
		return _cached_steering_direction
	_obstacle_probe_remaining = npc.obstacle_probe_interval
	var angle: float = deg_to_rad(npc.obstacle_probe_angle_degrees)
	var left_direction := desired_direction.rotated(Vector3.UP, angle)
	var right_direction := desired_direction.rotated(Vector3.UP, -angle)
	var forward_clearance_squared := _probe_obstacle_clearance_squared(
		desired_direction
	)
	var left_clearance_squared := _probe_obstacle_clearance_squared(
		left_direction
	)
	var right_clearance_squared := _probe_obstacle_clearance_squared(
		right_direction
	)
	var probe_distance_squared: float = (
		npc.obstacle_probe_distance * npc.obstacle_probe_distance
	)
	var side_clearance_squared: float = pow(
		npc.obstacle_probe_distance * 0.55,
		2.0
	)
	var steering_direction := desired_direction
	if forward_clearance_squared < probe_distance_squared:
		var detour_direction: Vector3 = (
			left_direction
			if left_clearance_squared >= right_clearance_squared
			else right_direction
		)
		steering_direction = desired_direction.lerp(
			detour_direction, npc.obstacle_steering_strength
		).normalized()
	elif left_clearance_squared < side_clearance_squared:
		steering_direction = desired_direction.lerp(
			right_direction, npc.obstacle_steering_strength * 0.35
		).normalized()
	elif right_clearance_squared < side_clearance_squared:
		steering_direction = desired_direction.lerp(
			left_direction, npc.obstacle_steering_strength * 0.35
		).normalized()
	_cached_steering_direction = steering_direction
	return steering_direction


func _probe_obstacle_clearance_squared(direction: Vector3) -> float:
	if direction.is_zero_approx():
		return npc.obstacle_probe_distance * npc.obstacle_probe_distance
	var origin: Vector3 = (
		npc.global_position + Vector3.UP * npc.obstacle_probe_height
	)
	var destination: Vector3 = (
		origin + direction * npc.obstacle_probe_distance
	)
	_obstacle_query.from = origin
	_obstacle_query.to = destination
	var hit: Dictionary = npc.get_world_3d().direct_space_state.intersect_ray(
		_obstacle_query
	)
	if hit.is_empty():
		return npc.obstacle_probe_distance * npc.obstacle_probe_distance
	var hit_position := hit.get("position", destination) as Vector3
	return origin.distance_squared_to(hit_position)


func _submit_horizontal_movement(
	desired_velocity: Vector3,
	delta: float
) -> void:
	_pending_movement_delta = delta
	if npc.navigation_agent.avoidance_enabled:
		npc.navigation_agent.velocity = Vector3(
			desired_velocity.x, 0.0, desired_velocity.z
		)
	else:
		_apply_safe_horizontal_velocity(desired_velocity)


func _on_navigation_velocity_computed(safe_velocity: Vector3) -> void:
	_apply_safe_horizontal_velocity(safe_velocity)


func _apply_safe_horizontal_velocity(safe_velocity: Vector3) -> void:
	if npc.is_defeated():
		return
	npc.velocity.x = safe_velocity.x
	npc.velocity.z = safe_velocity.z
	var facing_direction: Vector3 = (
		_facing_override_position - npc.global_position
		if _facing_override_enabled
		else Vector3(npc.velocity.x, 0.0, npc.velocity.z)
	)
	facing_direction.y = 0.0
	if facing_direction.length_squared() > 0.001:
		npc.visual.rotation.y = lerp_angle(
			npc.visual.rotation.y,
			atan2(facing_direction.x, facing_direction.z),
			minf(npc.turn_speed * _pending_movement_delta, 1.0)
		)
	_apply_gravity(_pending_movement_delta)
	npc.move_and_slide()
	npc.refresh_locomotion_animation()
