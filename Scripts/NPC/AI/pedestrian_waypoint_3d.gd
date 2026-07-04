@tool
class_name PedestrianWaypoint3D
extends Marker3D

@export var connections: Array[NodePath] = []:
	set(value):
		connections = value
		update_configuration_warnings()

@export var spawn_allowed := true
@export_range(0.1, 10.0, 0.1) var spawn_weight := 1.0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if connections.is_empty():
		warnings.append("Waypoint has no connections.")
	for connection in connections:
		if connection.is_empty():
			warnings.append("Waypoint contains an empty connection.")
			continue
		var target := get_node_or_null(connection)
		if target == self:
			warnings.append("Waypoint cannot connect to itself.")
		elif target != null and target is not PedestrianWaypoint3D:
			warnings.append(
				"Connection '%s' is not a PedestrianWaypoint3D." % connection
			)
	return warnings
