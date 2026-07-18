class_name TrafficIntersection3D
extends Node3D

const INTERSECTION_GROUP := &"traffic_intersection"

@export var intersection_id: StringName
@export var signal_controller_path := NodePath("SignalController")

var _reservations: Dictionary[int, StringName] = {}


func _enter_tree() -> void:
	add_to_group(INTERSECTION_GROUP)


func get_signal_controller() -> TrafficSignalController3D:
	return get_node_or_null(signal_controller_path) as TrafficSignalController3D


func try_reserve(vehicle: Node, movement_group: StringName) -> bool:
	_prune_reservations()
	if vehicle == null:
		return false
	var instance_id := int(vehicle.get_instance_id())
	if _reservations.has(instance_id):
		return true
	for reserved_group: StringName in _reservations.values():
		if not _movements_are_compatible(reserved_group, movement_group):
			return false
	_reservations[instance_id] = movement_group
	var callback := _on_vehicle_exiting.bind(instance_id)
	if not vehicle.tree_exiting.is_connected(callback):
		vehicle.tree_exiting.connect(callback, CONNECT_ONE_SHOT)
	return true


func release(vehicle: Node) -> void:
	if vehicle != null:
		_reservations.erase(int(vehicle.get_instance_id()))


func get_reserved_count() -> int:
	_prune_reservations()
	return _reservations.size()


func is_clear() -> bool:
	return get_reserved_count() == 0


func _movements_are_compatible(a: StringName, b: StringName) -> bool:
	# Matching movement groups represent parallel traffic released by the same
	# signal phase. Left-turn paths are the exception: the generated opposing
	# turns cross at the center waypoint, so releasing both together can strand
	# a turning car in the conflict area. Serialize those turns until the first
	# vehicle reaches its authored intersection exit.
	return (
		a != &""
		and a == b
		and not String(a).ends_with("_left")
	)


func _prune_reservations() -> void:
	for instance_id: int in _reservations.keys():
		if instance_from_id(instance_id) == null:
			_reservations.erase(instance_id)


func _on_vehicle_exiting(instance_id: int) -> void:
	_reservations.erase(instance_id)


static func find(tree: SceneTree, requested_id: StringName) -> TrafficIntersection3D:
	if tree == null or requested_id == &"":
		return null
	for node in tree.get_nodes_in_group(INTERSECTION_GROUP):
		var intersection := node as TrafficIntersection3D
		if intersection != null and intersection.intersection_id == requested_id:
			return intersection
	return null
