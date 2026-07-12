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

var _waypoints: Array[TrafficWaypoint3D] = []
var _waypoint_lookup := {}
var _adjacency := {}
var _spatial_cells := {}
var _cache_dirty := true
var _debug_dirty := true
var _editor_refresh_remaining := 0.0
var _debug_mesh_instance: MeshInstance3D


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
