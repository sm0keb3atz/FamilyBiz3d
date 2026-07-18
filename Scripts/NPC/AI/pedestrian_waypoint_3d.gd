@tool
class_name PedestrianWaypoint3D
extends Marker3D

enum WaypointRole {
	SIDEWALK = 0,
	CURB = 1,
	DESTINATION = 2,
	EXTERNAL = 4,
}

@export var connections: Array[NodePath] = []:
	set(value):
		connections = value
		update_configuration_warnings()

@export var spawn_allowed := true
@export_range(0.1, 10.0, 0.1) var spawn_weight := 1.0
@export_flags("Curb:1", "Destination:2", "External:4") var role_flags := 0
@export var destination_id: StringName


func has_role(role: int) -> bool:
	return (role_flags & role) != 0


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
