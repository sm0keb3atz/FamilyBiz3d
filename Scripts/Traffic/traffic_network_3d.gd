@tool
class_name TrafficNetwork3D
extends Node3D

@export_range(8.0, 128.0, 1.0) var spatial_cell_size := 32.0:
	set(value):
		spatial_cell_size = value
		_cache_dirty = true

@export var debug_draw_in_editor := true:
	set(value):
		debug_draw_in_editor = value
		_debug_dirty = true

@export var debug_draw_in_game := false:
	set(value):
		debug_draw_in_game = value
		_debug_dirty = true

@export var scan_root_paths: Array[NodePath] = []:
	set(value):
		scan_root_paths = value
		_cache_dirty = true

@export var allow_empty_network := false:
	set(value):
		allow_empty_network = value
		_cache_dirty = true

@export var discover_territory_mobility := true:
	set(value):
		discover_territory_mobility = value
		_cache_dirty = true

@export_range(0.5, 50.0, 0.5) var connector_stitch_distance := 8.0
@export_range(-1.0, 1.0, 0.05) var connector_facing_min_dot := 0.5

var _waypoints: Array[TrafficWaypoint3D] = []
var _waypoint_lookup := {}
var _adjacency := {}
var _spatial_cells := {}
var _cache_dirty := true
var _debug_dirty := true
var _editor_refresh_remaining := 0.0
var _debug_mesh_instance: MeshInstance3D
var _last_reachable_target_graph_visit_count := 0


func _ready() -> void:
	rebuild_cache()
	set_process(Engine.is_editor_hint())


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_editor_refresh_remaining -= delta
	if _editor_refresh_remaining <= 0.0:
		_editor_refresh_remaining = 0.5
		rebuild_cache()


func rebuild_cache() -> void:
	_waypoints.clear()
	_waypoint_lookup.clear()
	_adjacency.clear()
	_spatial_cells.clear()
	_collect_waypoints(self)
	if discover_territory_mobility and is_inside_tree():
		for node in get_tree().get_nodes_in_group(TerritoryMobility3D.MOBILITY_GROUP):
			var mobility := node as TerritoryMobility3D
			if mobility != null:
				var routes := mobility.get_traffic_routes()
				if routes != null:
					_collect_waypoints(routes)
	for root_path in scan_root_paths:
		var root := get_node_or_null(root_path)
		if root != null and root != self:
			_collect_waypoints(root)

	for waypoint in _waypoints:
		_waypoint_lookup[waypoint] = true
		_adjacency[waypoint] = []
		var cell := _get_cell(waypoint.global_position)
		if not _spatial_cells.has(cell):
			_spatial_cells[cell] = []
		(_spatial_cells[cell] as Array).append(waypoint)

	for waypoint in _waypoints:
		for connection in waypoint.connections:
			var target := (
				waypoint.get_node_or_null(connection) as TrafficWaypoint3D
			)
			if (
				target == null
				or target == waypoint
				or not _waypoint_lookup.has(target)
			):
				continue
			_add_link(waypoint, target)
	_stitch_external_connectors()

	_cache_dirty = false
	_debug_dirty = true
	_update_debug_mesh()
	update_configuration_warnings()


func get_waypoints() -> Array[TrafficWaypoint3D]:
	_ensure_cache()
	return _waypoints.duplicate()


func get_waypoint_count() -> int:
	_ensure_cache()
	return _waypoints.size()


func get_connection_count() -> int:
	_ensure_cache()
	var count := 0
	for neighbors: Array in _adjacency.values():
		count += neighbors.size()
	return count


func get_spawn_candidates(
	world_position: Vector3,
	minimum_distance: float,
	maximum_distance: float,
	maximum_results := 0
) -> Array[TrafficWaypoint3D]:
	_ensure_cache()
	var results: Array[TrafficWaypoint3D] = []
	if maximum_distance <= 0.0:
		return results

	var minimum_squared := minimum_distance * minimum_distance
	var maximum_squared := maximum_distance * maximum_distance
	var center_cell := _get_cell(world_position)
	var cell_radius := ceili(maximum_distance / spatial_cell_size)
	for cell_x in range(
		center_cell.x - cell_radius,
		center_cell.x + cell_radius + 1
	):
		for cell_y in range(
			center_cell.y - cell_radius,
			center_cell.y + cell_radius + 1
		):
			var cell := Vector2i(cell_x, cell_y)
			if not _spatial_cells.has(cell):
				continue
			for waypoint: TrafficWaypoint3D in _spatial_cells[cell]:
				if not waypoint.can_spawn_traffic():
					continue
				var distance_squared := waypoint.global_position.distance_squared_to(
					world_position
				)
				if (
					distance_squared < minimum_squared
					or distance_squared > maximum_squared
				):
					continue
				results.append(waypoint)
				if maximum_results > 0 and results.size() >= maximum_results:
					return results
	return results


func get_entry_waypoints() -> Array[TrafficWaypoint3D]:
	_ensure_cache()
	var results: Array[TrafficWaypoint3D] = []
	for waypoint in _waypoints:
		if waypoint.is_entry():
			results.append(waypoint)
	return results


func get_exit_waypoints() -> Array[TrafficWaypoint3D]:
	_ensure_cache()
	var results: Array[TrafficWaypoint3D] = []
	for waypoint in _waypoints:
		if waypoint.is_exit():
			results.append(waypoint)
	return results


func get_dispatch_candidates() -> Array[TrafficWaypoint3D]:
	_ensure_cache()
	var results: Array[TrafficWaypoint3D] = []
	for waypoint in _waypoints:
		if waypoint.is_dispatch_point() and waypoint.is_entry():
			results.append(waypoint)
	return results


func get_reachable_exits(
	start: TrafficWaypoint3D
) -> Array[TrafficWaypoint3D]:
	_ensure_cache()
	var results: Array[TrafficWaypoint3D] = []
	for exit_waypoint in get_exit_waypoints():
		if exit_waypoint != start and not find_route(start, exit_waypoint).is_empty():
			results.append(exit_waypoint)
	return results


func choose_reachable_exit(
	start: TrafficWaypoint3D,
	random: RandomNumberGenerator
) -> TrafficWaypoint3D:
	var exits := get_reachable_exits(start)
	if exits.is_empty():
		return null
	return exits[random.randi_range(0, exits.size() - 1)]


func find_route(
	start: TrafficWaypoint3D,
	goal: TrafficWaypoint3D
) -> Array[TrafficWaypoint3D]:
	_ensure_cache()
	var empty: Array[TrafficWaypoint3D] = []
	if start == null or goal == null or not has_waypoint(start) or not has_waypoint(goal):
		return empty
	var frontier: Array[TrafficWaypoint3D] = [start]
	var costs := {start: 0.0}
	var came_from := {}
	while not frontier.is_empty():
		var current := _pop_lowest_cost(frontier, costs)
		if current == goal:
			return _reconstruct_route(came_from, current)
		for neighbor: TrafficWaypoint3D in _adjacency.get(current, []):
			var distance := current.global_position.distance_to(neighbor.global_position)
			var edge_cost := distance / maxf(neighbor.route_weight, 0.05)
			var new_cost := float(costs[current]) + edge_cost
			if not costs.has(neighbor) or new_cost < float(costs[neighbor]):
				costs[neighbor] = new_cost
				came_from[neighbor] = current
				if neighbor not in frontier:
					frontier.append(neighbor)
	return empty


func find_reachable_road_target(
	start: TrafficWaypoint3D,
	world_position: Vector3,
	approach_origin: Vector3 = Vector3.INF,
	stand_off_distance := 0.0,
	excluded_positions: Array[Vector3] = [],
	minimum_separation := 0.0
) -> Dictionary:
	_ensure_cache()
	_last_reachable_target_graph_visit_count = 0
	if start == null or not has_waypoint(start) or not world_position.is_finite():
		return {}
	var path_tree := _build_shortest_path_tree(start)
	var costs := path_tree.get("costs", {}) as Dictionary
	var route_distances := path_tree.get("route_distances", {}) as Dictionary
	var came_from := path_tree.get("came_from", {}) as Dictionary
	var best := {}
	var best_score := INF
	for lane_start in _waypoints:
		if not costs.has(lane_start):
			continue
		for lane_end: TrafficWaypoint3D in _adjacency.get(lane_start, []):
			if not _is_response_road_segment(lane_start, lane_end):
				continue
			var segment := lane_end.global_position - lane_start.global_position
			segment.y = 0.0
			var segment_length := segment.length()
			if segment_length <= 4.0:
				continue
			var direction := segment / segment_length
			var target_offset := world_position - lane_start.global_position
			target_offset.y = 0.0
			var projected_progress := clampf(
				target_offset.dot(direction),
				0.0,
				segment_length
			)
			var edge_margin := minf(2.0, segment_length * 0.2)
			var stop_progress := clampf(
				projected_progress - maxf(stand_off_distance, 0.0),
				edge_margin,
				segment_length - edge_margin
			)
			if lane_start == start and approach_origin.is_finite():
				var origin_offset := approach_origin - lane_start.global_position
				origin_offset.y = 0.0
				var origin_progress := origin_offset.dot(direction)
				if stop_progress < origin_progress + 3.0:
					continue
			var stop_position := lane_start.global_position + direction * stop_progress
			var separated := true
			for excluded in excluded_positions:
				if (
					excluded.is_finite()
					and excluded.distance_squared_to(stop_position)
					< minimum_separation * minimum_separation
				):
					separated = false
					break
			if not separated:
				continue
			var route_distance := float(route_distances.get(lane_start, 0.0)) + stop_progress
			var target_distance := Vector2(
				world_position.x - stop_position.x,
				world_position.z - stop_position.z
			).length()
			var score := target_distance * 4.0 + route_distance * 0.05
			if score >= best_score:
				continue
			best_score = score
			best = {
				"position": stop_position,
				"approach_direction": direction,
				"segment_start": lane_start,
				"segment_end": lane_end,
				"route_distance": route_distance,
				"target_distance": target_distance,
			}
	if best.is_empty():
		return best
	var best_segment_start := best.get("segment_start") as TrafficWaypoint3D
	best["route"] = _reconstruct_route(came_from, best_segment_start)
	return best


func get_last_reachable_target_graph_visit_count() -> int:
	return _last_reachable_target_graph_visit_count


func find_route_avoiding(
	start: TrafficWaypoint3D,
	goal: TrafficWaypoint3D,
	blocked_waypoints: Array[TrafficWaypoint3D]
) -> Array[TrafficWaypoint3D]:
	_ensure_cache()
	var empty: Array[TrafficWaypoint3D] = []
	if (
		start == null
		or goal == null
		or not has_waypoint(start)
		or not has_waypoint(goal)
	):
		return empty
	var blocked := {}
	for waypoint in blocked_waypoints:
		if waypoint != null and waypoint != start and waypoint != goal:
			blocked[waypoint] = true
	var frontier: Array[TrafficWaypoint3D] = [start]
	var costs := {start: 0.0}
	var came_from := {}
	while not frontier.is_empty():
		var current := _pop_lowest_cost(frontier, costs)
		if current == goal:
			return _reconstruct_route(came_from, current)
		for neighbor: TrafficWaypoint3D in _adjacency.get(current, []):
			if blocked.has(neighbor):
				continue
			var distance := current.global_position.distance_to(
				neighbor.global_position
			)
			var edge_cost := distance / maxf(neighbor.route_weight, 0.05)
			var new_cost := float(costs[current]) + edge_cost
			if not costs.has(neighbor) or new_cost < float(costs[neighbor]):
				costs[neighbor] = new_cost
				came_from[neighbor] = current
				if neighbor not in frontier:
					frontier.append(neighbor)
	return empty


func find_adjacent_lane_target(
	world_position: Vector3,
	travel_direction: Vector3,
	lookahead := 16.0,
	minimum_lane_separation := 2.5,
	maximum_lane_separation := 9.5
) -> Dictionary:
	_ensure_cache()
	travel_direction.y = 0.0
	if travel_direction.is_zero_approx():
		return {}
	travel_direction = travel_direction.normalized()
	var best := {}
	var best_score := INF
	for lane_start in _waypoints:
		for lane_end: TrafficWaypoint3D in _adjacency.get(lane_start, []):
			var segment := lane_end.global_position - lane_start.global_position
			segment.y = 0.0
			var segment_length := segment.length()
			if segment_length < lookahead * 0.6:
				continue
			var authored_direction := segment / segment_length
			var alignment := authored_direction.dot(travel_direction)
			if absf(alignment) < 0.72:
				continue
			var from_start := world_position - lane_start.global_position
			from_start.y = 0.0
			var progress := clampf(
				from_start.dot(authored_direction),
				0.0,
				segment_length
			)
			var closest := lane_start.global_position + authored_direction * progress
			var separation := Vector2(
				world_position.x - closest.x,
				world_position.z - closest.z
			).length()
			if (
				separation < minimum_lane_separation
				or separation > maximum_lane_separation
			):
				continue
			var pass_direction := (
				authored_direction if alignment >= 0.0 else -authored_direction
			)
			var available := (
				segment_length - progress if alignment >= 0.0 else progress
			)
			if available < lookahead * 0.65:
				continue
			var target := closest + pass_direction * minf(lookahead, available - 0.5)
			var score := separation + (1.0 - absf(alignment)) * 8.0
			if score < best_score:
				best_score = score
				best = {
					"target": target,
					"direction": pass_direction,
					"lane_start": lane_start,
					"lane_end": lane_end,
				}
	return best


func get_nearest_waypoint(
	world_position: Vector3,
	max_distance := INF
) -> TrafficWaypoint3D:
	_ensure_cache()
	var nearest: TrafficWaypoint3D
	var nearest_distance_squared := max_distance * max_distance
	if is_finite(max_distance):
		var center_cell := _get_cell(world_position)
		var cell_radius := ceili(max_distance / spatial_cell_size)
		for cell_x in range(
			center_cell.x - cell_radius,
			center_cell.x + cell_radius + 1
		):
			for cell_y in range(
				center_cell.y - cell_radius,
				center_cell.y + cell_radius + 1
			):
				var cell := Vector2i(cell_x, cell_y)
				if not _spatial_cells.has(cell):
					continue
				for waypoint: TrafficWaypoint3D in _spatial_cells[cell]:
					var distance_squared := waypoint.global_position.distance_squared_to(
						world_position
					)
					if distance_squared < nearest_distance_squared:
						nearest = waypoint
						nearest_distance_squared = distance_squared
		return nearest

	for waypoint in _waypoints:
		var distance_squared := waypoint.global_position.distance_squared_to(
			world_position
		)
		if distance_squared < nearest_distance_squared:
			nearest = waypoint
			nearest_distance_squared = distance_squared
	return nearest


func get_next_waypoint(
	current: TrafficWaypoint3D,
	previous: TrafficWaypoint3D,
	random: RandomNumberGenerator
) -> TrafficWaypoint3D:
	_ensure_cache()
	if current == null or not _adjacency.has(current):
		return null
	var neighbors: Array = _adjacency[current]
	if neighbors.is_empty():
		return null
	var candidates: Array[TrafficWaypoint3D] = []
	for neighbor: TrafficWaypoint3D in neighbors:
		if neighbor != previous:
			candidates.append(neighbor)
	if candidates.is_empty():
		candidates.assign(neighbors)
	if candidates.size() == 1:
		return candidates[0]
	var total_weight := 0.0
	for candidate in candidates:
		total_weight += maxf(candidate.route_weight, 0.05)
	var roll := random.randf_range(0.0, total_weight)
	for candidate in candidates:
		roll -= maxf(candidate.route_weight, 0.05)
		if roll <= 0.0:
			return candidate
	return candidates.back()


func has_waypoint(waypoint: TrafficWaypoint3D) -> bool:
	_ensure_cache()
	return _waypoint_lookup.has(waypoint)


func get_validation_errors() -> PackedStringArray:
	_ensure_cache()
	var warnings := PackedStringArray()
	if _waypoints.is_empty() and not allow_empty_network:
		warnings.append("Traffic network has no waypoint children.")
		return warnings
	for waypoint in _waypoints:
		if (
			(_adjacency.get(waypoint, []) as Array).is_empty()
			and not waypoint.is_external_connector
		):
			warnings.append("Traffic waypoint '%s' has no valid exits." % waypoint.name)
		if waypoint.is_stop_line:
			var controller := waypoint.get_signal_controller()
			if controller == null:
				warnings.append(
					"Stop line '%s' has no valid signal controller." % waypoint.name
				)
			elif (
				waypoint.signal_group != controller.north_south_group
				and waypoint.signal_group != controller.east_west_group
			):
				warnings.append(
					"Stop line '%s' uses an unknown signal group." % waypoint.name
				)
		if waypoint.can_spawn_traffic() and (
			waypoint.is_stop_line
			or waypoint.has_role(TrafficWaypoint3D.WaypointRole.INTERSECTION_ENTRY)
			or waypoint.has_role(TrafficWaypoint3D.WaypointRole.INTERSECTION_EXIT)
		):
			warnings.append("Traffic spawn '%s' is inside an intersection." % waypoint.name)
	var exits := get_exit_waypoints()
	if not exits.is_empty():
		for waypoint in _waypoints:
			if (
				waypoint.is_entry()
				or waypoint.can_spawn_traffic()
				or waypoint.is_dispatch_point()
			) and get_reachable_exits(waypoint).is_empty():
				warnings.append("Traffic origin '%s' cannot reach an exit." % waypoint.name)
	_validate_connectors(warnings)
	return warnings


func _get_configuration_warnings() -> PackedStringArray:
	if _cache_dirty:
		return PackedStringArray()
	return get_validation_errors()


func _collect_waypoints(node: Node) -> void:
	for child in node.get_children():
		if child is TrafficWaypoint3D:
			_waypoints.append(child as TrafficWaypoint3D)
		_collect_waypoints(child)


func _stitch_external_connectors() -> void:
	var by_id := {}
	for waypoint in _waypoints:
		if not waypoint.is_external_connector or waypoint.connector_id == &"":
			continue
		if not by_id.has(waypoint.connector_id):
			by_id[waypoint.connector_id] = []
		(by_id[waypoint.connector_id] as Array).append(waypoint)
	for connectors: Array in by_id.values():
		for from_waypoint: TrafficWaypoint3D in connectors:
			if from_waypoint.connector_direction != TrafficWaypoint3D.ConnectorDirection.EXIT:
				continue
			for to_waypoint: TrafficWaypoint3D in connectors:
				if (
					to_waypoint != from_waypoint
					and to_waypoint.connector_direction == TrafficWaypoint3D.ConnectorDirection.ENTRY
					and _ports_are_compatible(from_waypoint, to_waypoint)
				):
					_add_link(from_waypoint, to_waypoint)


func _validate_connectors(warnings: PackedStringArray) -> void:
	var by_key := {}
	for waypoint in _waypoints:
		if not waypoint.is_external_connector:
			continue
		if waypoint.connector_id == &"":
			warnings.append("External connector '%s' has no connector_id." % waypoint.name)
			continue
		var key := "%s:%d" % [waypoint.connector_id, waypoint.connector_direction]
		if by_key.has(key):
			warnings.append("Duplicate directed connector '%s'." % key)
		by_key[key] = waypoint
		if waypoint.connector_direction == TrafficWaypoint3D.ConnectorDirection.NONE:
			warnings.append("External connector '%s' has no direction." % waypoint.name)
		elif not waypoint.allow_unpaired_connector:
			var complementary := (
				TrafficWaypoint3D.ConnectorDirection.EXIT
				if waypoint.connector_direction == TrafficWaypoint3D.ConnectorDirection.ENTRY
				else TrafficWaypoint3D.ConnectorDirection.ENTRY
			)
			var pair_key := "%s:%d" % [waypoint.connector_id, complementary]
			if not by_key.has(pair_key):
				# A later connector in the list may be the matching side. Validate in a
				# second pass below instead of reporting order-dependent warnings.
				pass
	for waypoint in _waypoints:
		if (
			waypoint.is_external_connector
			and not waypoint.allow_unpaired_connector
			and waypoint.connector_id != &""
		):
			var complementary := (
				TrafficWaypoint3D.ConnectorDirection.EXIT
				if waypoint.connector_direction == TrafficWaypoint3D.ConnectorDirection.ENTRY
				else TrafficWaypoint3D.ConnectorDirection.ENTRY
			)
			if not by_key.has("%s:%d" % [waypoint.connector_id, complementary]):
				warnings.append("Connector '%s' has no complementary port." % waypoint.name)
	for connectors: Array in _group_connectors_by_id().values():
		for exit_port: TrafficWaypoint3D in connectors:
			if exit_port.connector_direction != TrafficWaypoint3D.ConnectorDirection.EXIT:
				continue
			for entry_port: TrafficWaypoint3D in connectors:
				if entry_port.connector_direction != TrafficWaypoint3D.ConnectorDirection.ENTRY:
					continue
				if not _ports_are_compatible(exit_port, entry_port):
					warnings.append(
						"Connector '%s' ports exceed stitch distance or face different travel directions."
						% exit_port.connector_id
					)


func _group_connectors_by_id() -> Dictionary:
	var grouped := {}
	for waypoint in _waypoints:
		if not waypoint.is_external_connector or waypoint.connector_id == &"":
			continue
		if not grouped.has(waypoint.connector_id):
			grouped[waypoint.connector_id] = []
		(grouped[waypoint.connector_id] as Array).append(waypoint)
	return grouped


func _ports_are_compatible(
	exit_port: TrafficWaypoint3D,
	entry_port: TrafficWaypoint3D
) -> bool:
	if exit_port.global_position.distance_to(entry_port.global_position) > connector_stitch_distance:
		return false
	var exit_forward := exit_port.global_basis.z.normalized()
	var entry_forward := entry_port.global_basis.z.normalized()
	return exit_forward.dot(entry_forward) >= connector_facing_min_dot


func _pop_lowest_cost(
	frontier: Array[TrafficWaypoint3D],
	costs: Dictionary
) -> TrafficWaypoint3D:
	var best_index := 0
	var best_cost := float(costs[frontier[0]])
	for index in range(1, frontier.size()):
		var cost := float(costs[frontier[index]])
		if cost < best_cost:
			best_index = index
			best_cost = cost
	return frontier.pop_at(best_index) as TrafficWaypoint3D


func _build_shortest_path_tree(start: TrafficWaypoint3D) -> Dictionary:
	var frontier: Array[TrafficWaypoint3D] = [start]
	var costs := {start: 0.0}
	var route_distances := {start: 0.0}
	var came_from := {}
	while not frontier.is_empty():
		var current := _pop_lowest_cost(frontier, costs)
		_last_reachable_target_graph_visit_count += 1
		for neighbor: TrafficWaypoint3D in _adjacency.get(current, []):
			var distance := current.global_position.distance_to(
				neighbor.global_position
			)
			var new_cost := (
				float(costs[current])
				+ distance / maxf(neighbor.route_weight, 0.05)
			)
			if costs.has(neighbor) and new_cost >= float(costs[neighbor]):
				continue
			costs[neighbor] = new_cost
			route_distances[neighbor] = float(route_distances[current]) + distance
			came_from[neighbor] = current
			if neighbor not in frontier:
				frontier.append(neighbor)
	return {
		"costs": costs,
		"route_distances": route_distances,
		"came_from": came_from,
	}


func _reconstruct_route(
	came_from: Dictionary,
	current: TrafficWaypoint3D
) -> Array[TrafficWaypoint3D]:
	var route: Array[TrafficWaypoint3D] = [current]
	while came_from.has(current):
		current = came_from[current] as TrafficWaypoint3D
		route.push_front(current)
	return route


func _is_response_road_segment(
	lane_start: TrafficWaypoint3D,
	lane_end: TrafficWaypoint3D
) -> bool:
	if lane_start == null or lane_end == null:
		return false
	return not (
		lane_start.has_role(TrafficWaypoint3D.WaypointRole.INTERSECTION_ENTRY)
		or lane_end.has_role(TrafficWaypoint3D.WaypointRole.INTERSECTION_ENTRY)
	)


func _add_link(
	from_waypoint: TrafficWaypoint3D,
	to_waypoint: TrafficWaypoint3D
) -> void:
	var neighbors := _adjacency[from_waypoint] as Array
	if to_waypoint not in neighbors:
		neighbors.append(to_waypoint)


func _get_cell(world_position: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_position.x / spatial_cell_size),
		floori(world_position.z / spatial_cell_size)
	)


func _ensure_cache() -> void:
	if _cache_dirty:
		rebuild_cache()


func _update_debug_mesh() -> void:
	var should_draw := (
		(debug_draw_in_editor and Engine.is_editor_hint())
		or (debug_draw_in_game and not Engine.is_editor_hint())
	)
	if not should_draw:
		if _debug_mesh_instance != null:
			_debug_mesh_instance.visible = false
		return

	if _debug_mesh_instance == null:
		_debug_mesh_instance = MeshInstance3D.new()
		_debug_mesh_instance.name = "TrafficNetworkDebug"
		_debug_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_debug_mesh_instance, false, Node.INTERNAL_MODE_BACK)

	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.vertex_color_use_as_albedo = true
	line_material.no_depth_test = true

	var immediate_mesh := ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, line_material)
	for from_waypoint in _waypoints:
		for to_waypoint: TrafficWaypoint3D in _adjacency.get(
			from_waypoint,
			[]
		):
			immediate_mesh.surface_set_color(Color(1.0, 0.78, 0.18, 0.9))
			immediate_mesh.surface_add_vertex(
				to_local(from_waypoint.global_position + Vector3.UP * 0.35)
			)
			immediate_mesh.surface_add_vertex(
				to_local(to_waypoint.global_position + Vector3.UP * 0.35)
			)
	immediate_mesh.surface_end()
	_debug_mesh_instance.mesh = immediate_mesh
	_debug_mesh_instance.visible = true
	_debug_dirty = false
