@tool
class_name TrafficSignalController3D
extends Node3D

signal signal_state_changed(group: StringName, state: int)
signal pedestrian_state_changed(crossing_id: StringName, state: int)

enum SignalState {
	RED,
	YELLOW,
	GREEN,
}

enum PedestrianState {
	DONT_WALK,
	WALK,
	CLEARANCE,
}

@export var controller_id: StringName
@export var north_south_group: StringName = &"north_south"
@export var east_west_group: StringName = &"east_west"
@export_range(1.0, 60.0, 0.5) var green_duration := 8.0
@export_range(0.5, 10.0, 0.25) var yellow_duration := 2.0
@export_range(0.0, 5.0, 0.1) var all_red_duration := 0.5
@export_range(1.0, 10.0, 0.5) var pedestrian_walk_duration := 4.0
@export_range(2.0, 20.0, 0.5) var pedestrian_clearance_timeout := 12.0
@export_range(1.0, 20.0, 0.5) var intersection_clear_wait_timeout := 6.0
@export var single_vehicle_group := false

var _phase := 0
var _phase_remaining := 0.0
var _states := {}
var _pedestrian_states := {}
var _pedestrian_signal_groups := {}
var _pedestrian_requests := {}
var _serving_crossings := {}
var _crossing_occupancy := {}
var _pedestrian_phase_active := false
var _intersection_clear_wait_elapsed := 0.0


func _enter_tree() -> void:
	add_to_group(&"traffic_signal_controller")


func _ready() -> void:
	_states.clear()
	_set_phase(0)
	set_process(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	_phase_remaining -= delta
	if _pedestrian_phase_active:
		_process_pedestrian_phase()
		return
	if _phase_remaining > 0.0:
		return
	var next_phase := _get_next_phase(_phase)
	if _phase == 5 and _has_pending_pedestrian_request():
		if _intersection_is_clear():
			_start_pedestrian_phase()
		else:
			_apply_states(SignalState.RED, SignalState.RED)
			_intersection_clear_wait_elapsed += delta
			if _intersection_clear_wait_elapsed >= intersection_clear_wait_timeout:
				_intersection_clear_wait_elapsed = 0.0
				_set_phase(next_phase)
			else:
				_phase_remaining = 0.1
		return
	_set_phase(next_phase)


func should_stop(group: StringName) -> bool:
	return get_signal_state(group) != SignalState.GREEN


func get_signal_state(group: StringName) -> int:
	return int(_states.get(group, SignalState.RED))


func advance_phase_for_test() -> void:
	if _pedestrian_phase_active:
		if _has_walking_crossing():
			_start_pedestrian_clearance()
		elif _get_total_pedestrian_occupancy() == 0:
			_finish_pedestrian_phase()
		return
	var next_phase := _get_next_phase(_phase)
	if _phase == 5 and _has_pending_pedestrian_request():
		if _intersection_is_clear():
			_start_pedestrian_phase()
		return
	_set_phase(next_phase)


func request_pedestrian_crossing(
	crossing_id: StringName,
	conflicting_signal_group: StringName = &"east_west"
) -> void:
	if crossing_id == &"":
		return
	_pedestrian_signal_groups[crossing_id] = conflicting_signal_group
	if (
		_pedestrian_phase_active
		and _serving_crossings.has(crossing_id)
		and get_pedestrian_state(crossing_id) == PedestrianState.WALK
	):
		return
	_pedestrian_requests[crossing_id] = true
	if not _pedestrian_states.has(crossing_id):
		_pedestrian_states[crossing_id] = PedestrianState.DONT_WALK


func get_pedestrian_state(crossing_id: StringName) -> int:
	return int(_pedestrian_states.get(crossing_id, PedestrianState.DONT_WALK))


func can_enter_pedestrian_crossing(
	crossing_id: StringName,
	_expected_seconds := 0.0,
	conflicting_signal_group: StringName = &"east_west"
) -> bool:
	request_pedestrian_crossing(crossing_id, conflicting_signal_group)
	return (
		_pedestrian_phase_active
		and _serving_crossings.has(crossing_id)
		and get_pedestrian_state(crossing_id) == PedestrianState.WALK
	)


func set_crossing_occupancy(crossing_id: StringName, count: int) -> void:
	_crossing_occupancy[crossing_id] = maxi(count, 0)


func is_vehicle_green_allowed() -> bool:
	return not _pedestrian_phase_active


func _get_next_phase(phase: int) -> int:
	var next_phase := (phase + 1) % 6
	if single_vehicle_group and next_phase == 3:
		next_phase = 5
	return next_phase


func _set_phase(phase: int) -> void:
	_pedestrian_phase_active = false
	_intersection_clear_wait_elapsed = 0.0
	_phase = phase
	match _phase:
		0:
			_apply_states(SignalState.GREEN, SignalState.RED)
			_phase_remaining = green_duration
		1:
			_apply_states(SignalState.YELLOW, SignalState.RED)
			_phase_remaining = yellow_duration
		2:
			_apply_states(SignalState.RED, SignalState.RED)
			_phase_remaining = all_red_duration
		3:
			_apply_states(SignalState.RED, SignalState.GREEN)
			_phase_remaining = green_duration
		4:
			_apply_states(SignalState.RED, SignalState.YELLOW)
			_phase_remaining = yellow_duration
		_:
			_apply_states(SignalState.RED, SignalState.RED)
			_phase_remaining = all_red_duration


func _start_pedestrian_phase() -> void:
	_pedestrian_phase_active = true
	_intersection_clear_wait_elapsed = 0.0
	_serving_crossings = _pedestrian_requests.duplicate()
	_pedestrian_requests.clear()
	_apply_states(SignalState.RED, SignalState.RED)
	for crossing_id: StringName in _serving_crossings:
		_set_pedestrian_state(crossing_id, PedestrianState.WALK)
	_phase_remaining = pedestrian_walk_duration


func _process_pedestrian_phase() -> void:
	if _has_walking_crossing():
		if _phase_remaining <= 0.0:
			_start_pedestrian_clearance()
		return
	if _get_total_pedestrian_occupancy() == 0:
		_finish_pedestrian_phase()
	elif _phase_remaining <= 0.0:
		_finish_pedestrian_phase()


func _start_pedestrian_clearance() -> void:
	for crossing_id: StringName in _serving_crossings:
		_set_pedestrian_state(crossing_id, PedestrianState.CLEARANCE)
	_phase_remaining = pedestrian_clearance_timeout


func _finish_pedestrian_phase() -> void:
	for crossing_id: StringName in _serving_crossings:
		_set_pedestrian_state(crossing_id, PedestrianState.DONT_WALK)
	_serving_crossings.clear()
	_pedestrian_phase_active = false
	_set_phase(0)


func _has_walking_crossing() -> bool:
	for crossing_id: StringName in _serving_crossings:
		if get_pedestrian_state(crossing_id) == PedestrianState.WALK:
			return true
	return false


func _has_pending_pedestrian_request() -> bool:
	return not _pedestrian_requests.is_empty()


func _intersection_is_clear() -> bool:
	var intersection := get_parent() as TrafficIntersection3D
	return intersection == null or intersection.is_clear()


func _get_total_pedestrian_occupancy() -> int:
	var total := 0
	for crossing_id: StringName in _serving_crossings:
		total += int(_crossing_occupancy.get(crossing_id, 0))
	return total


func _set_pedestrian_state(crossing_id: StringName, state: int) -> void:
	if int(_pedestrian_states.get(crossing_id, -1)) == state:
		return
	_pedestrian_states[crossing_id] = state
	pedestrian_state_changed.emit(crossing_id, state)


func _apply_states(north_south_state: int, east_west_state: int) -> void:
	_set_group_state(north_south_group, north_south_state)
	_set_group_state(east_west_group, east_west_state)


func _set_group_state(group: StringName, state: int) -> void:
	if group == &"":
		return
	if int(_states.get(group, -1)) == state:
		return
	_states[group] = state
	signal_state_changed.emit(group, state)


static func find(tree: SceneTree, requested_id: StringName) -> TrafficSignalController3D:
	if tree == null or requested_id == &"":
		return null
	for node in tree.get_nodes_in_group(&"traffic_signal_controller"):
		var controller := node as TrafficSignalController3D
		if controller != null and controller.controller_id == requested_id:
			return controller
	return null
