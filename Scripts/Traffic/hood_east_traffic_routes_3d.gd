@tool
class_name HoodEastTrafficRoutes3D
extends TrafficRouteVisualizer3D

const DIRECTIONS := {
	"E": Vector3.RIGHT,
	"W": Vector3.LEFT,
	"N": Vector3.BACK,
	"S": Vector3.FORWARD,
}
const OPPOSITE := {"E": "W", "W": "E", "N": "S", "S": "N"}

@export_category("Lane Layout")
@export_range(1.5, 5.0, 0.1) var lane_center_offset := 3.2:
	set(value):
		lane_center_offset = value
		_queue_network_rebuild()
@export_range(0.0, 1.0, 0.05) var lane_wander_half_width := 0.35:
	set(value):
		lane_wander_half_width = value
		_queue_network_rebuild()
@export_range(11.0, 20.0, 0.5) var stop_line_distance := 15.0:
	set(value):
		stop_line_distance = value
		_queue_network_rebuild()

var _waypoints := {}
var _rebuild_queued := false


func _enter_tree() -> void:
	_rebuild_reference_network()


func _queue_network_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_rebuild_reference_network")


func _rebuild_reference_network() -> void:
	_rebuild_queued = false
	for child in get_children():
		if child is TrafficWaypoint3D:
			remove_child(child)
			child.free()
	_waypoints.clear()
	_build_reference_network()


func _build_reference_network() -> void:
	if get_node_or_null("SW_In_N") != null:
		return
	var intersections := {
		"SW": {"position": Vector3(7, 0.2, -123), "arms": ["N", "E", "S"], "id": &"hood_east_south_west"},
		"SE": {"position": Vector3(127, 0.2, -123), "arms": ["N", "E", "S", "W"], "id": &"hood_east_south_east"},
		"MW": {"position": Vector3(7, 0.2, -3), "arms": ["N", "E", "S"], "id": &"hood_east_mid_west"},
		"ME": {"position": Vector3(127, 0.2, -3), "arms": ["N", "E", "S", "W"], "id": &"hood_east_mid_east"},
		"NW": {"position": Vector3(7, 0.2, 117), "arms": ["E", "S"], "id": &"hood_east_north_west"},
		"NE": {"position": Vector3(127, 0.2, 117), "arms": ["E", "S", "W"], "id": &"hood_east_north_east"},
	}
	for key: String in intersections:
		_build_intersection(key, intersections[key])
	_connect_road("SW", "E", "SE", "E")
	_connect_road("SE", "W", "SW", "W")
	_connect_road("MW", "E", "ME", "E")
	_connect_road("ME", "W", "MW", "W")
	_connect_road("NW", "E", "NE", "E")
	_connect_road("NE", "W", "NW", "W")
	_connect_road("SW", "N", "MW", "N")
	_connect_road("MW", "S", "SW", "S")
	_connect_road("MW", "N", "NW", "N")
	_connect_road("NW", "S", "MW", "S")
	_connect_road("SE", "N", "ME", "N")
	_connect_road("ME", "S", "SE", "S")
	_connect_road("ME", "N", "NE", "N")
	_connect_road("NE", "S", "ME", "S")
	_add_boundary_pair("SE", "E", "east_south", 22.0)
	_add_boundary_pair("ME", "E", "east_mid", 22.0)
	_add_boundary_pair("NE", "E", "east_north", 22.0)
	_add_boundary_pair("SE", "S", "south_east", 22.0)
	_add_boundary_pair("SW", "S", "south_west", 22.0)
	_refresh_preview.call_deferred()


func _build_intersection(key: String, data: Dictionary) -> void:
	var center := data.position as Vector3
	var arms := data.arms as Array
	var intersection_id := data.id as StringName
	for travel_direction: String in DIRECTIONS:
		var inbound_arm := OPPOSITE[travel_direction] as String
		if inbound_arm not in arms:
			continue
		var direction := DIRECTIONS[travel_direction] as Vector3
		var lane_right := _get_lane_right(direction)
		var stop_line := _add_waypoint(
			"%s_In_%s" % [key, travel_direction],
			center - direction * stop_line_distance + lane_right * lane_center_offset,
			TrafficWaypoint3D.WaypointRole.STOP_LINE
		)
		stop_line.is_stop_line = true
		stop_line.spawn_allowed = false
		stop_line.signal_group = _signal_group_for_direction(travel_direction)
		stop_line.signal_controller_id = intersection_id
		stop_line.intersection_id = intersection_id
	for travel_direction: String in DIRECTIONS:
		if travel_direction not in arms:
			continue
		var direction := DIRECTIONS[travel_direction] as Vector3
		var lane_right := _get_lane_right(direction)
		var exit := _add_waypoint(
			"%s_Out_%s" % [key, travel_direction],
			center + direction * stop_line_distance + lane_right * lane_center_offset,
			TrafficWaypoint3D.WaypointRole.INTERSECTION_EXIT
		)
		exit.spawn_allowed = false
		exit.intersection_id = intersection_id
	for inbound_direction: String in DIRECTIONS:
		var inbound_arm := OPPOSITE[inbound_direction] as String
		if inbound_arm not in arms:
			continue
		var stop_line := _get_waypoint("%s_In_%s" % [key, inbound_direction])
		for outbound_direction: String in DIRECTIONS:
			if outbound_direction not in arms or outbound_direction == OPPOSITE[inbound_direction]:
				continue
			var turn_name := "%s_Move_%s_%s" % [key, inbound_direction, outbound_direction]
			var inbound_vector := DIRECTIONS[inbound_direction] as Vector3
			var outbound_vector := DIRECTIONS[outbound_direction] as Vector3
			var turn_offset := (
				(inbound_vector + outbound_vector) * 1.5
				+ (
					_get_lane_right(inbound_vector)
					+ _get_lane_right(outbound_vector)
				) * lane_center_offset * 0.5
			)
			var movement := _add_waypoint(
				turn_name,
				center + turn_offset,
				TrafficWaypoint3D.WaypointRole.INTERSECTION_ENTRY
			)
			movement.spawn_allowed = false
			movement.intersection_id = intersection_id
			movement.signal_group = _signal_group_for_direction(inbound_direction)
			movement.signal_controller_id = intersection_id
			movement.movement_group = _movement_group(inbound_direction, outbound_direction)
			movement.speed_limit = 3.8 if inbound_direction != outbound_direction else 7.0
			_connect(stop_line, movement)
			_connect(movement, _get_waypoint("%s_Out_%s" % [key, outbound_direction]))


func _connect_road(
	from_intersection: String,
	travel_direction: String,
	to_intersection: String,
	to_travel_direction: String
) -> void:
	var from := _get_waypoint("%s_Out_%s" % [from_intersection, travel_direction])
	var to := _get_waypoint("%s_In_%s" % [to_intersection, to_travel_direction])
	if from == null or to == null:
		return
	var midpoint := _add_waypoint(
		"Road_%s_%s_%s" % [from_intersection, to_intersection, travel_direction],
		from.position.lerp(to.position, 0.5),
		TrafficWaypoint3D.WaypointRole.SPAWN
	)
	midpoint.speed_limit = 13.0
	_connect(from, midpoint)
	_connect(midpoint, to)


func _add_boundary_pair(
	intersection: String,
	arm_direction: String,
	port_name: String,
	distance: float
) -> void:
	var direction := DIRECTIONS[arm_direction] as Vector3
	var outbound := _get_waypoint("%s_Out_%s" % [intersection, arm_direction])
	var inbound_direction := OPPOSITE[arm_direction] as String
	var inbound := _get_waypoint("%s_In_%s" % [intersection, inbound_direction])
	if outbound != null:
		var exit := _add_waypoint(
			"Port_%s_Exit" % port_name,
			outbound.position + direction * distance,
			TrafficWaypoint3D.WaypointRole.EXIT
		)
		exit.spawn_allowed = false
		exit.is_external_connector = true
		exit.connector_id = &"hood_east_%s_out" % port_name
		exit.connector_direction = TrafficWaypoint3D.ConnectorDirection.EXIT
		exit.allow_unpaired_connector = true
		_connect(outbound, exit)
	if inbound != null:
		var entry := _add_waypoint(
			"Port_%s_Entry" % port_name,
			inbound.position + direction * distance,
			TrafficWaypoint3D.WaypointRole.SPAWN
			| TrafficWaypoint3D.WaypointRole.ENTRY
			| TrafficWaypoint3D.WaypointRole.DISPATCH
		)
		entry.is_external_connector = true
		entry.connector_id = &"hood_east_%s_in" % port_name
		entry.connector_direction = TrafficWaypoint3D.ConnectorDirection.ENTRY
		entry.allow_unpaired_connector = true
		entry.spawn_weight = 2.0
		_connect(entry, inbound)


func _add_waypoint(name_value: String, position_value: Vector3, flags: int) -> TrafficWaypoint3D:
	var existing := get_node_or_null(name_value) as TrafficWaypoint3D
	if existing != null:
		_waypoints[name_value] = existing
		return existing
	var waypoint := TrafficWaypoint3D.new()
	waypoint.name = name_value
	waypoint.position = position_value
	waypoint.role_flags = flags
	waypoint.spawn_allowed = (flags & TrafficWaypoint3D.WaypointRole.SPAWN) != 0
	waypoint.lane_half_width = lane_wander_half_width
	add_child(waypoint)
	_waypoints[name_value] = waypoint
	return waypoint


func _get_waypoint(name_value: String) -> TrafficWaypoint3D:
	if _waypoints.has(name_value):
		return _waypoints[name_value] as TrafficWaypoint3D
	var waypoint := get_node_or_null(name_value) as TrafficWaypoint3D
	if waypoint != null:
		_waypoints[name_value] = waypoint
	return waypoint


func _connect(from: TrafficWaypoint3D, to: TrafficWaypoint3D) -> void:
	if from == null or to == null:
		return
	var forward := to.position - from.position
	forward.y = 0.0
	if not forward.is_zero_approx():
		var travel_basis := Basis.looking_at(forward.normalized(), Vector3.UP, true)
		from.basis = travel_basis
		if to.is_exit():
			to.basis = travel_basis
	var path := from.get_path_to(to)
	if path not in from.connections:
		from.connections.append(path)


func _signal_group_for_direction(direction: String) -> StringName:
	return &"east_west" if direction in ["E", "W"] else &"north_south"


func _get_lane_right(direction: Vector3) -> Vector3:
	return direction.cross(Vector3.UP).normalized()


func _movement_group(inbound: String, outbound: String) -> StringName:
	if inbound == outbound:
		return _signal_group_for_direction(inbound)
	var cross := (DIRECTIONS[inbound] as Vector3).cross(DIRECTIONS[outbound] as Vector3)
	if cross.y > 0.0:
		return &"%s_left" % _signal_group_for_direction(inbound)
	return _signal_group_for_direction(inbound)
