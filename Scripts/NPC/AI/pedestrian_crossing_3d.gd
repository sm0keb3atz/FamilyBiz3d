@tool
class_name PedestrianCrossing3D
extends Area3D

const CROSSING_GROUP := &"pedestrian_crossing"

@export var crossing_id: StringName
@export var intersection_id: StringName
@export var conflicting_signal_group: StringName = &"east_west"
@export var curb_a_path: NodePath
@export var curb_b_path: NodePath
@export_range(1.0, 30.0, 0.5) var expected_crossing_seconds := 5.0

var _inside: Dictionary[int, WeakRef] = {}
var _committed: Dictionary[int, WeakRef] = {}


func _enter_tree() -> void:
	add_to_group(CROSSING_GROUP)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func get_curb_a() -> PedestrianWaypoint3D:
	return get_node_or_null(curb_a_path) as PedestrianWaypoint3D


func get_curb_b() -> PedestrianWaypoint3D:
	return get_node_or_null(curb_b_path) as PedestrianWaypoint3D


func connects(a: PedestrianWaypoint3D, b: PedestrianWaypoint3D) -> bool:
	var curb_a := get_curb_a()
	var curb_b := get_curb_b()
	return (a == curb_a and b == curb_b) or (a == curb_b and b == curb_a)


func request_walk() -> void:
	var controller := TrafficSignalController3D.find(get_tree(), intersection_id)
	if controller != null:
		controller.request_pedestrian_crossing(
			crossing_id,
			conflicting_signal_group
		)


func can_enter() -> bool:
	var controller := TrafficSignalController3D.find(get_tree(), intersection_id)
	return (
		controller != null
		and controller.can_enter_pedestrian_crossing(
			crossing_id,
			expected_crossing_seconds,
			conflicting_signal_group
		)
	)


func try_begin_traversal(pedestrian: Node) -> bool:
	if pedestrian == null:
		return false
	_prune_tracked_pedestrians()
	var instance_id := int(pedestrian.get_instance_id())
	if _committed.has(instance_id):
		return true
	if not can_enter():
		return false
	_committed[instance_id] = weakref(pedestrian)
	var callback := _on_body_tree_exiting.bind(instance_id)
	if not pedestrian.tree_exiting.is_connected(callback):
		pedestrian.tree_exiting.connect(callback, CONNECT_ONE_SHOT)
	_notify_controller()
	return true


func finish_traversal(pedestrian: Node) -> void:
	if pedestrian == null:
		return
	var instance_id := int(pedestrian.get_instance_id())
	_committed.erase(instance_id)
	var callback := _on_body_tree_exiting.bind(instance_id)
	if (
		not _inside.has(instance_id)
		and pedestrian.tree_exiting.is_connected(callback)
	):
		pedestrian.tree_exiting.disconnect(callback)
	_notify_controller()


func is_traversing(pedestrian: Node) -> bool:
	if pedestrian == null:
		return false
	_prune_tracked_pedestrians()
	return _committed.has(int(pedestrian.get_instance_id()))


func get_occupant_count() -> int:
	_prune_tracked_pedestrians()
	var tracked_ids := {}
	for instance_id: int in _inside:
		tracked_ids[instance_id] = true
	for instance_id: int in _committed:
		tracked_ids[instance_id] = true
	return tracked_ids.size()


func _on_body_entered(body: Node3D) -> void:
	if not _is_managed_pedestrian(body):
		return
	var instance_id := int(body.get_instance_id())
	_inside[instance_id] = weakref(body)
	var callback := _on_body_tree_exiting.bind(instance_id)
	if not body.tree_exiting.is_connected(callback):
		body.tree_exiting.connect(callback, CONNECT_ONE_SHOT)
	_notify_controller()


func _on_body_exited(body: Node3D) -> void:
	var instance_id := int(body.get_instance_id())
	_inside.erase(instance_id)
	var callback := _on_body_tree_exiting.bind(instance_id)
	if (
		not _committed.has(instance_id)
		and body.tree_exiting.is_connected(callback)
	):
		body.tree_exiting.disconnect(callback)
	_notify_controller()


func _on_body_tree_exiting(instance_id: int) -> void:
	_inside.erase(instance_id)
	_committed.erase(instance_id)
	_notify_controller()


func _notify_controller() -> void:
	var controller := TrafficSignalController3D.find(get_tree(), intersection_id)
	if controller != null:
		controller.set_crossing_occupancy(crossing_id, get_occupant_count())


func _is_managed_pedestrian(body: Node) -> bool:
	return (
		body is BaseNPC
		or body.is_in_group("customer_npc")
		or body.is_in_group("police_npc")
	)


func _prune_tracked_pedestrians() -> void:
	for instance_id: int in _inside.keys():
		var reference := _inside[instance_id] as WeakRef
		if reference == null or not is_instance_valid(reference.get_ref()):
			_inside.erase(instance_id)
	for instance_id: int in _committed.keys():
		var reference := _committed[instance_id] as WeakRef
		if reference == null or not is_instance_valid(reference.get_ref()):
			_committed.erase(instance_id)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if crossing_id == &"":
		warnings.append("Pedestrian crossing needs a stable crossing_id.")
	if intersection_id == &"":
		warnings.append("Pedestrian crossing needs an intersection_id.")
	if conflicting_signal_group == &"":
		warnings.append("Pedestrian crossing needs a conflicting signal group.")
	if get_curb_a() == null or get_curb_b() == null:
		warnings.append("Pedestrian crossing needs two valid curb waypoints.")
	return warnings
