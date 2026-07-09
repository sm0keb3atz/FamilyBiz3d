@tool
class_name TrafficWaypoint3D
extends Marker3D

@export var connections: Array[NodePath] = []:
	set(value):
		connections = value
		update_configuration_warnings()

@export var spawn_allowed := true
@export_range(0.1, 10.0, 0.1) var spawn_weight := 1.0
@export_range(0.0, 4.0, 0.05) var lane_half_width := 0.75
@export_range(1.0, 40.0, 0.5) var speed_limit := 13.0
@export var is_stop_line := false
@export var signal_group: StringName = &""
@export var signal_controller_path: NodePath


func should_stop_for_signal() -> bool:
	if not is_stop_line or signal_group == &"":
		return false
	var controller := (
		get_node_or_null(signal_controller_path) as TrafficSignalController3D
	)
	if controller == null:
		controller = _find_signal_controller()
	if controller == null:
		return false
	return controller.should_stop(signal_group)


func _find_signal_controller() -> TrafficSignalController3D:
	var node := get_parent()
	while node != null:
		var controller := _find_signal_controller_recursive(node)
		if controller != null:
			return controller
		node = node.get_parent()
	return null


func _find_signal_controller_recursive(node: Node) -> TrafficSignalController3D:
	for child in node.get_children():
		if child is TrafficSignalController3D:
			return child as TrafficSignalController3D
		var controller := _find_signal_controller_recursive(child)
		if controller != null:
			return controller
	return null


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if connections.is_empty():
		warnings.append("Traffic waypoint has no connections.")
	for connection in connections:
		if connection.is_empty():
			warnings.append("Traffic waypoint contains an empty connection.")
			continue
		var target := get_node_or_null(connection)
		if target == self:
			warnings.append("Traffic waypoint cannot connect to itself.")
		elif target != null and target is not TrafficWaypoint3D:
			warnings.append(
				"Connection '%s' is not a TrafficWaypoint3D." % connection
			)
	if is_stop_line and signal_group == &"":
		warnings.append("Stop line has no signal group.")
	return warnings
