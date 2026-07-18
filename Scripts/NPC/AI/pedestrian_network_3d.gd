@tool
class_name PedestrianNetwork3D
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

var _waypoints: Array[PedestrianWaypoint3D] = []
var _waypoint_lookup := {}
var _adjacency := {}
var _spatial_cells := {}
var _cache_dirty := true
var _debug_dirty := true
var _editor_refresh_remaining := 0.0
var _debug_mesh_instance: MeshInstance3D
var _crossings: Array[PedestrianCrossing3D] = []


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
	_crossings.clear()
	_collect_waypoints(self)
	_collect_crossings(self)

	for waypoint in _waypoints:
		_waypoint_lookup[waypoint] = true
		_adjacency[waypoint] = []
		var cell := _get_cell(waypoint.global_position)
		if not _spatial_cells.has(cell):
			_spatial_cells[cell] = []
		(_spatial_cells[cell] as Array).append(waypoint)

	for waypoint in _waypoints:
		for connection in waypoint.connections:
			var target := waypoint.get_node_or_null(
				connection
			) as PedestrianWaypoint3D
			if (
				target == null
				or target == waypoint
				or not _waypoint_lookup.has(target)
			):
				continue
			_add_link(waypoint, target)
			_add_link(target, waypoint)

	_cache_dirty = false
	_debug_dirty = true
	_update_debug_mesh()
	update_configuration_warnings()


func get_waypoints() -> Array[PedestrianWaypoint3D]:
	_ensure_cache()
	return _waypoints.duplicate()


func get_waypoint_count() -> int:
	_ensure_cache()
	return _waypoints.size()


func get_connection_count() -> int:
	_ensure_cache()
	var directed_count := 0
	for neighbors: Array in _adjacency.values():
		directed_count += neighbors.size()
	return int(directed_count / 2)


func get_nearest_waypoint(
	world_position: Vector3,
	max_distance := INF
) -> PedestrianWaypoint3D:
	_ensure_cache()
	var nearest: PedestrianWaypoint3D
	var nearest_distance_squared := max_distance * max_distance

	if is_finite(max_distance):
		var cell_radius := ceili(max_distance / spatial_cell_size)
		var center_cell := _get_cell(world_position)
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
				for waypoint: PedestrianWaypoint3D in _spatial_cells[cell]:
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


func get_spawn_candidates(
	world_position: Vector3,
	minimum_distance: float,
	maximum_distance: float,
	maximum_results := 0
) -> Array[PedestrianWaypoint3D]:
	_ensure_cache()
	var results: Array[PedestrianWaypoint3D] = []
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
			for waypoint: PedestrianWaypoint3D in _spatial_cells[cell]:
				if not waypoint.spawn_allowed:
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


func get_next_waypoint(
	current: PedestrianWaypoint3D,
	previous: PedestrianWaypoint3D,
	random: RandomNumberGenerator
) -> PedestrianWaypoint3D:
	_ensure_cache()
	if current == null or not _adjacency.has(current):
		return null

	var neighbors: Array = _adjacency[current]
	if neighbors.is_empty():
		return null
	if neighbors.size() == 1:
		return neighbors[0] as PedestrianWaypoint3D

	var previous_index := neighbors.find(previous)
	if previous_index < 0:
		return neighbors[
			random.randi_range(0, neighbors.size() - 1)
		] as PedestrianWaypoint3D
	var candidate_index := random.randi_range(0, neighbors.size() - 2)
	if candidate_index >= previous_index:
		candidate_index += 1
	return neighbors[candidate_index] as PedestrianWaypoint3D


func find_path(
	start: PedestrianWaypoint3D,
	goal: PedestrianWaypoint3D
) -> Array[PedestrianWaypoint3D]:
	_ensure_cache()
	var empty: Array[PedestrianWaypoint3D] = []
	if start == null or goal == null or not has_waypoint(start) or not has_waypoint(goal):
		return empty
	var pending: Array[PedestrianWaypoint3D] = [start]
	var visited := {start: true}
	var came_from := {}
	while not pending.is_empty():
		var current := pending.pop_front() as PedestrianWaypoint3D
		if current == goal:
			return _reconstruct_path(came_from, current)
		for neighbor: PedestrianWaypoint3D in _adjacency.get(current, []):
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			came_from[neighbor] = current
			pending.append(neighbor)
	return empty


func is_reachable(
	start: PedestrianWaypoint3D,
	goal: PedestrianWaypoint3D
) -> bool:
	return not find_path(start, goal).is_empty()


func get_crossing_between(
	from_waypoint: PedestrianWaypoint3D,
	to_waypoint: PedestrianWaypoint3D
) -> PedestrianCrossing3D:
	_ensure_cache()
	for crossing in _crossings:
		if is_instance_valid(crossing) and crossing.connects(from_waypoint, to_waypoint):
			return crossing
	return null


func can_traverse(
	from_waypoint: PedestrianWaypoint3D,
	to_waypoint: PedestrianWaypoint3D,
	pedestrian: Node = null
) -> bool:
	var crossing := get_crossing_between(from_waypoint, to_waypoint)
	if crossing == null:
		return true
	crossing.request_walk()
	if pedestrian != null:
		return crossing.try_begin_traversal(pedestrian)
	return crossing.can_enter()


func path_requires_crossing(path: Array[PedestrianWaypoint3D]) -> bool:
	for index in range(path.size() - 1):
		if get_crossing_between(path[index], path[index + 1]) != null:
			return true
	return false


func get_waypoint_away_from(
	current: PedestrianWaypoint3D,
	previous: PedestrianWaypoint3D,
	threat_position: Vector3,
	random: RandomNumberGenerator
) -> PedestrianWaypoint3D:
	_ensure_cache()
	if current == null or not _adjacency.has(current):
		return null
	var neighbors: Array = _adjacency[current]
	if neighbors.is_empty():
		return null

	var best: PedestrianWaypoint3D
	var best_score := -INF
	for candidate: PedestrianWaypoint3D in neighbors:
		var score := candidate.global_position.distance_squared_to(
			threat_position
		)
		if candidate == previous:
			score -= 0.5
		score += random.randf_range(0.0, 0.5)
		if score > best_score:
			best_score = score
			best = candidate
	return best


func has_waypoint(waypoint: PedestrianWaypoint3D) -> bool:
	_ensure_cache()
	return _waypoint_lookup.has(waypoint)


func get_validation_errors() -> PackedStringArray:
	_ensure_cache()
	var warnings := PackedStringArray()
	if _waypoints.is_empty():
		warnings.append("Pedestrian network has no waypoint children.")
		return warnings
	var destination_ids := {}
	for waypoint in _waypoints:
		if (_adjacency.get(waypoint, []) as Array).is_empty():
			warnings.append("Waypoint '%s' has no valid connections." % waypoint.name)
		if waypoint.has_role(PedestrianWaypoint3D.WaypointRole.DESTINATION) and waypoint.destination_id == &"":
			warnings.append("Destination waypoint '%s' has no destination_id." % waypoint.name)
		elif waypoint.has_role(PedestrianWaypoint3D.WaypointRole.DESTINATION):
			if destination_ids.has(waypoint.destination_id):
				warnings.append("Duplicate pedestrian destination ID '%s'." % waypoint.destination_id)
			destination_ids[waypoint.destination_id] = waypoint
	var crossing_ids := {}
	for crossing in _crossings:
		if crossing_ids.has(crossing.crossing_id):
			warnings.append("Duplicate pedestrian crossing ID '%s'." % crossing.crossing_id)
		crossing_ids[crossing.crossing_id] = crossing
		if crossing.get_curb_a() == null or crossing.get_curb_b() == null:
			warnings.append("Crossing '%s' has invalid curb waypoints." % crossing.name)
		elif not has_waypoint(crossing.get_curb_a()) or not has_waypoint(crossing.get_curb_b()):
			warnings.append("Crossing '%s' references curbs outside this network." % crossing.name)

	var visited := {}
	var pending: Array[PedestrianWaypoint3D] = [_waypoints[0]]
	while not pending.is_empty():
		var waypoint := pending.pop_back() as PedestrianWaypoint3D
		if visited.has(waypoint):
			continue
		visited[waypoint] = true
		for neighbor: PedestrianWaypoint3D in _adjacency.get(waypoint, []):
			if not visited.has(neighbor):
				pending.append(neighbor)
	if visited.size() != _waypoints.size():
		warnings.append(
			"Pedestrian network is disconnected: %d of %d waypoints are reachable."
			% [visited.size(), _waypoints.size()]
		)
	for waypoint in _waypoints:
		if (
			waypoint.has_role(PedestrianWaypoint3D.WaypointRole.DESTINATION)
			and not visited.has(waypoint)
		):
			warnings.append("Destination '%s' is unreachable." % waypoint.name)
	return warnings


func _get_configuration_warnings() -> PackedStringArray:
	if _cache_dirty:
		return PackedStringArray()
	return get_validation_errors()


func _collect_waypoints(node: Node) -> void:
	for child in node.get_children():
		if child is PedestrianWaypoint3D:
			_waypoints.append(child as PedestrianWaypoint3D)
		_collect_waypoints(child)


func _collect_crossings(node: Node) -> void:
	for child in node.get_children():
		if child is PedestrianCrossing3D:
			_crossings.append(child as PedestrianCrossing3D)
		_collect_crossings(child)


func _reconstruct_path(
	came_from: Dictionary,
	current: PedestrianWaypoint3D
) -> Array[PedestrianWaypoint3D]:
	var path: Array[PedestrianWaypoint3D] = [current]
	while came_from.has(current):
		current = came_from[current] as PedestrianWaypoint3D
		path.push_front(current)
	return path


func _add_link(
	from_waypoint: PedestrianWaypoint3D,
	to_waypoint: PedestrianWaypoint3D
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
		_debug_mesh_instance.name = "PedestrianNetworkDebug"
		_debug_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(
			_debug_mesh_instance,
			false,
			Node.INTERNAL_MODE_BACK
		)

	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.vertex_color_use_as_albedo = true
	line_material.no_depth_test = true

	var immediate_mesh := ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, line_material)
	for from_waypoint in _waypoints:
		for to_waypoint: PedestrianWaypoint3D in _adjacency.get(
			from_waypoint, []
		):
			if from_waypoint.get_instance_id() >= to_waypoint.get_instance_id():
				continue
			immediate_mesh.surface_set_color(Color(0.15, 0.9, 1.0, 0.9))
			immediate_mesh.surface_add_vertex(
				to_local(from_waypoint.global_position + Vector3.UP * 0.2)
			)
			immediate_mesh.surface_add_vertex(
				to_local(to_waypoint.global_position + Vector3.UP * 0.2)
			)
	immediate_mesh.surface_end()
	_debug_mesh_instance.mesh = immediate_mesh
	_debug_mesh_instance.visible = true
	_debug_dirty = false
