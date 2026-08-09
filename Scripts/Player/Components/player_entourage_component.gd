class_name PlayerEntourageComponent
extends Node

signal capacity_changed(active: int, maximum: int)

const LIMIT_FEEDBACK := (
	"Motion limit reached. Send someone home or upgrade Motion."
)

@export var stats_component_path := NodePath("../StatsComponent")

var _entries: Array[Dictionary] = []


func _ready() -> void:
	var stats := _get_stats()
	if stats != null:
		stats.motion_changed.connect(_on_motion_changed)
	capacity_changed.emit(0, get_limit())


func try_register_follower(
	follower: Node,
	slot_setter: Callable,
	release_callback: Callable
) -> bool:
	_prune_invalid_entries()
	if follower == null:
		return false
	var existing := _find_index(follower)
	if existing >= 0:
		_apply_slot(existing)
		return true
	if _entries.size() >= get_limit():
		return false
	_entries.append({
		"follower": weakref(follower),
		"slot_setter": slot_setter,
		"release_callback": release_callback,
	})
	_apply_slot(_entries.size() - 1)
	capacity_changed.emit(_entries.size(), get_limit())
	return true


func unregister_follower(follower: Node) -> bool:
	_prune_invalid_entries()
	var index := _find_index(follower)
	if index < 0:
		return false
	_entries.remove_at(index)
	_refresh_slots_internal()
	capacity_changed.emit(_entries.size(), get_limit())
	return true


func is_registered(follower: Node) -> bool:
	_prune_invalid_entries()
	return _find_index(follower) >= 0


func has_capacity() -> bool:
	_prune_invalid_entries()
	return _entries.size() < get_limit()


func get_active_count() -> int:
	_prune_invalid_entries()
	return _entries.size()


func get_limit() -> int:
	var stats := _get_stats()
	return stats.get_motion_follower_limit() if stats != null else 1


func get_slot(follower: Node) -> int:
	_prune_invalid_entries()
	return _find_index(follower)


func refresh_slots() -> void:
	_prune_invalid_entries()
	_refresh_slots_internal()


func _on_motion_changed(_current: int) -> void:
	_prune_invalid_entries()
	while _entries.size() > get_limit():
		var overflow: Dictionary = _entries.pop_back() as Dictionary
		var release: Callable = overflow.get(
			"release_callback", Callable()
		) as Callable
		if release.is_valid():
			release.call()
	_refresh_slots_internal()
	capacity_changed.emit(_entries.size(), get_limit())


func _find_index(follower: Node) -> int:
	for index in _entries.size():
		if _get_follower(_entries[index]) == follower:
			return index
	return -1


func _get_follower(entry: Dictionary) -> Node:
	var reference := entry.get("follower") as WeakRef
	return reference.get_ref() as Node if reference != null else null


func _apply_slot(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	var setter := _entries[index].get("slot_setter", Callable()) as Callable
	if setter.is_valid():
		setter.call(index)


func _refresh_slots_internal() -> void:
	for index in _entries.size():
		_apply_slot(index)


func _prune_invalid_entries() -> void:
	var changed := false
	for index in range(_entries.size() - 1, -1, -1):
		if not is_instance_valid(_get_follower(_entries[index])):
			_entries.remove_at(index)
			changed = true
	if changed:
		_refresh_slots_internal()
		capacity_changed.emit(_entries.size(), get_limit())


func _get_stats() -> PlayerStatsComponent:
	return get_node_or_null(stats_component_path) as PlayerStatsComponent
