class_name PedestrianPatrolComponent
extends Node

@export_range(0.2, 3.0, 0.05) var arrival_distance := 0.75
@export_range(0.0, 2.0, 0.05) var lane_half_width := 1.0

var npc
var network: PedestrianNetwork3D
var current_waypoint: PedestrianWaypoint3D
var previous_waypoint: PedestrianWaypoint3D
var target_waypoint: PedestrianWaypoint3D
var _random := RandomNumberGenerator.new()
var _lane_offset := 0.0


func initialize(owner_npc: BaseNPC) -> void:
	npc = owner_npc


func assign_route(
	pedestrian_network: PedestrianNetwork3D,
	start_waypoint: PedestrianWaypoint3D,
	random_seed: int
) -> void:
	network = pedestrian_network
	current_waypoint = start_waypoint
	previous_waypoint = null
	target_waypoint = null
	_random.seed = random_seed
	_lane_offset = _random.randf_range(-lane_half_width, lane_half_width)
	_choose_next()


func tick_patrol(delta: float) -> void:
	if network == null or not is_instance_valid(current_waypoint):
		npc.stop_moving(delta)
		return
	if not is_instance_valid(target_waypoint):
		_choose_next()
		if not is_instance_valid(target_waypoint):
			npc.stop_moving(delta)
			return
	var target_position := _get_target_position()
	if (
		npc.global_position.distance_squared_to(target_position)
		<= arrival_distance * arrival_distance
	):
		previous_waypoint = current_waypoint
		current_waypoint = target_waypoint
		_choose_next()
		target_position = _get_target_position()
	npc.set_navigation_target(target_position)
	npc.advance_navigation(delta)


func get_spawn_position() -> Vector3:
	if not is_instance_valid(current_waypoint):
		return npc.global_position
	if not is_instance_valid(target_waypoint):
		return current_waypoint.global_position
	return (
		current_waypoint.global_position
		+ _get_lane_offset(current_waypoint, target_waypoint)
	)


func clear() -> void:
	network = null
	current_waypoint = null
	previous_waypoint = null
	target_waypoint = null


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
		return npc.global_position
	return (
		target_waypoint.global_position
		+ _get_lane_offset(current_waypoint, target_waypoint)
	)


func _get_lane_offset(
	from_waypoint: PedestrianWaypoint3D,
	to_waypoint: PedestrianWaypoint3D
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
