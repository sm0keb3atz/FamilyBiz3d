@tool
class_name TrafficWaypoint3D
extends Marker3D

@export var connections: Array[NodePath] = []:
	set(value):
		connections = value
		update_configuration_warnings()

@export var spawn_allowed := true
@export_range(0.1, 10.0, 0.1) var spawn_weight := 1.0
@export_range(0.05, 10.0, 0.05) var route_weight := 1.0
@export_range(0.0, 4.0, 0.05) var lane_half_width := 0.75
@export_range(1.0, 40.0, 0.5) var speed_limit := 13.0
@export var is_external_connector := false
@export var is_stop_line := false
@export var signal_group: StringName = &""
@export var signal_controller_path: NodePath


func should_stop_for_signal() -> bool:
	var state := get_signal_state()
	return state != -1 and state != TrafficSignalController3D.SignalState.GREEN


func get_signal_state() -> int:
	if not is_stop_line or signal_group == &"":
		return -1
	var controller := get_signal_controller()
	if controller == null:
		return -1
	return controller.get_signal_state(signal_group)


func get_signal_controller() -> TrafficSignalController3D:
	if signal_controller_path.is_empty():
		return null
	return get_node_or_null(signal_controller_path) as TrafficSignalController3D


func can_spawn_traffic() -> bool:
	if not spawn_allowed:
		return false
	# Curves inside the reusable intersection are route-only. Traffic must begin
	# on a real road segment, never in the middle of a junction.
	var route_parent := get_parent()
	return (
		route_parent == null
		or route_parent.get_parent() == null
		or not route_parent.get_parent() is TrafficRouteVisualizer3D
	)


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
	if is_stop_line and signal_controller_path.is_empty():
		warnings.append("Stop line needs an explicit signal controller path.")
	return warnings
