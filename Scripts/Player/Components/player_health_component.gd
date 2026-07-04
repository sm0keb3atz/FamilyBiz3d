class_name PlayerHealthComponent
extends Node

enum State {
	ALIVE,
	DOWNED,
	RESPAWNING,
}

signal state_changed(previous: State, current: State)
signal downed
signal respawn_started
signal respawn_completed

@export var stats_component_path := NodePath("../StatsComponent")

var state: State:
	get:
		return _state

@onready var stats_component := (
	get_node(stats_component_path) as PlayerStatsComponent
)

var _state := State.ALIVE


func _ready() -> void:
	stats_component.health_depleted.connect(_on_health_depleted)
	if is_zero_approx(stats_component.health):
		_set_state(State.DOWNED)


func is_alive() -> bool:
	return _state == State.ALIVE


func is_downed() -> bool:
	return _state == State.DOWNED


func is_respawning() -> bool:
	return _state == State.RESPAWNING


func begin_respawn() -> bool:
	if _state != State.DOWNED:
		return false

	_set_state(State.RESPAWNING)
	respawn_started.emit()
	return true


func begin_forced_respawn() -> bool:
	if _state == State.RESPAWNING:
		return false
	_set_state(State.RESPAWNING)
	respawn_started.emit()
	return true


func complete_respawn() -> bool:
	if _state != State.RESPAWNING:
		return false

	stats_component.heal(stats_component.get_max_health())
	stats_component.restore_stamina(stats_component.get_max_stamina())
	_set_state(State.ALIVE)
	respawn_completed.emit()
	return true


func _on_health_depleted() -> void:
	if _state != State.ALIVE:
		return

	_set_state(State.DOWNED)
	downed.emit()


func _set_state(next_state: State) -> void:
	if next_state == _state:
		return

	var previous_state := _state
	_state = next_state
	state_changed.emit(previous_state, _state)
