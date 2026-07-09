@tool
class_name TrafficRouteVisualizer3D
extends Node3D

@export var preview_enabled := true:
	set(value):
		preview_enabled = value
		_refresh_preview()

@export_range(0.0, 2.0, 0.05) var preview_height := 0.35:
	set(value):
		preview_height = value
		_refresh_preview()

@export var draw_lane_width := true:
	set(value):
		draw_lane_width = value
		_refresh_preview()

@export var draw_arrow_heads := true:
	set(value):
		draw_arrow_heads = value
		_refresh_preview()

@export var draw_spawn_markers := true:
	set(value):
		draw_spawn_markers = value
		_refresh_preview()

@export_range(0.25, 5.0, 0.05) var arrow_size := 1.2:
	set(value):
		arrow_size = value
		_refresh_preview()

@export_range(0.1, 3.0, 0.1) var refresh_interval := 0.35

var _preview_mesh_instance: MeshInstance3D
var _refresh_remaining := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	set_process(true)
	_refresh_preview()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_refresh_remaining -= delta
	if _refresh_remaining <= 0.0:
		_refresh_remaining = refresh_interval
		_refresh_preview()


func _refresh_preview() -> void:
	if not is_inside_tree():
		return
	if not preview_enabled:
		if _preview_mesh_instance != null:
			_preview_mesh_instance.visible = false
		return

	if _preview_mesh_instance == null:
		_preview_mesh_instance = MeshInstance3D.new()
		_preview_mesh_instance.name = "TrafficRoutePreview"
		_preview_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_preview_mesh_instance, false, Node.INTERNAL_MODE_BACK)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for waypoint in _collect_waypoints():
		_draw_waypoint(mesh, waypoint)
		for connection in waypoint.connections:
			var target := waypoint.get_node_or_null(connection) as TrafficWaypoint3D
			if target == null or target == waypoint:
				continue
			_draw_connection(mesh, waypoint, target)
	mesh.surface_end()

	_preview_mesh_instance.mesh = mesh
	_preview_mesh_instance.visible = true


func _collect_waypoints() -> Array[TrafficWaypoint3D]:
	var waypoints: Array[TrafficWaypoint3D] = []
	_collect_waypoints_recursive(self, waypoints)
	return waypoints


func _collect_waypoints_recursive(
	node: Node,
	waypoints: Array[TrafficWaypoint3D]
) -> void:
	for child in node.get_children():
		if child == _preview_mesh_instance:
			continue
		if child is TrafficWaypoint3D:
			waypoints.append(child as TrafficWaypoint3D)
		_collect_waypoints_recursive(child, waypoints)


func _draw_connection(
	mesh: ImmediateMesh,
	from_waypoint: TrafficWaypoint3D,
	to_waypoint: TrafficWaypoint3D
) -> void:
	var from_position := from_waypoint.global_position
	var to_position := to_waypoint.global_position
	var direction := to_position - from_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		return
	direction = direction.normalized()

	var side := Vector3(-direction.z, 0.0, direction.x)
	var line_color := Color(0.1, 0.85, 1.0, 0.95)
	var rail_color := Color(0.1, 0.85, 1.0, 0.32)

	_add_line(mesh, from_position, to_position, line_color)
	if draw_lane_width:
		var half_width := from_waypoint.lane_half_width
		_add_line(
			mesh,
			from_position + side * half_width,
			to_position + side * half_width,
			rail_color
		)
		_add_line(
			mesh,
			from_position - side * half_width,
			to_position - side * half_width,
			rail_color
		)
	if draw_arrow_heads:
		_draw_arrow_head(mesh, from_position, to_position, direction, side)


func _draw_arrow_head(
	mesh: ImmediateMesh,
	from_position: Vector3,
	to_position: Vector3,
	direction: Vector3,
	side: Vector3
) -> void:
	var segment_length := from_position.distance_to(to_position)
	var clamped_arrow_size := minf(arrow_size, segment_length * 0.35)
	if clamped_arrow_size <= 0.05:
		return
	var tip := from_position.lerp(to_position, 0.72)
	var base := tip - direction * clamped_arrow_size
	var wing := side * clamped_arrow_size * 0.45
	var arrow_color := Color(1.0, 0.92, 0.15, 0.98)
	_add_line(mesh, base + wing, tip, arrow_color)
	_add_line(mesh, base - wing, tip, arrow_color)


func _draw_waypoint(mesh: ImmediateMesh, waypoint: TrafficWaypoint3D) -> void:
	if not draw_spawn_markers:
		return
	var size := 0.45
	var color := (
		Color(0.25, 1.0, 0.35, 0.95)
		if waypoint.spawn_allowed
		else Color(1.0, 0.28, 0.12, 0.95)
	)
	var position := waypoint.global_position
	_add_line(mesh, position + Vector3.LEFT * size, position + Vector3.RIGHT * size, color)
	_add_line(mesh, position + Vector3.FORWARD * size, position + Vector3.BACK * size, color)
	_add_line(mesh, position, position + Vector3.UP * 0.75, color)


func _add_line(
	mesh: ImmediateMesh,
	from_position: Vector3,
	to_position: Vector3,
	color: Color
) -> void:
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(to_local(from_position + Vector3.UP * preview_height))
	mesh.surface_add_vertex(to_local(to_position + Vector3.UP * preview_height))
