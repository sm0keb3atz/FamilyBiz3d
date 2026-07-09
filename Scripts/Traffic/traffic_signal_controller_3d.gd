class_name TrafficSignalController3D
extends Node3D

signal signal_state_changed(group: StringName, state: int)

enum SignalState {
	RED,
	YELLOW,
	GREEN,
}

@export var north_south_group: StringName = &"north_south"
@export var east_west_group: StringName = &"east_west"
@export_range(1.0, 60.0, 0.5) var green_duration := 8.0
@export_range(0.5, 10.0, 0.25) var yellow_duration := 2.0
@export_range(0.0, 5.0, 0.1) var all_red_duration := 0.5

var _phase := 0
var _phase_remaining := 0.0
var _states := {}


func _ready() -> void:
	_states.clear()
	_set_phase(0)
	set_process(true)


func _process(delta: float) -> void:
	_phase_remaining -= delta
	if _phase_remaining <= 0.0:
		_set_phase((_phase + 1) % 6)


func should_stop(group: StringName) -> bool:
	return get_signal_state(group) != SignalState.GREEN


func get_signal_state(group: StringName) -> int:
	return int(_states.get(group, SignalState.RED))


func advance_phase_for_test() -> void:
	_set_phase((_phase + 1) % 6)


func _set_phase(phase: int) -> void:
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
