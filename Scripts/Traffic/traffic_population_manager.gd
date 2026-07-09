class_name TrafficPopulationManager
extends Node3D

@export var vehicle_scene: PackedScene
@export var network_path: NodePath
@export var player_path: NodePath
@export var vehicle_container_path: NodePath

@export_category("Population")
@export_range(1, 200, 1) var pool_capacity := 24
@export_range(0, 200, 1) var active_target := 10
@export_range(0.0, 500.0, 1.0) var minimum_spawn_distance := 28.0
@export_range(1.0, 1000.0, 1.0) var maximum_spawn_distance := 95.0
@export_range(1.0, 1000.0, 1.0) var recycle_distance := 130.0
@export_range(0.1, 10.0, 0.1) var population_update_interval := 0.8
@export_range(1, 20, 1) var maximum_activations_per_update := 1
@export_range(1, 100, 1) var recycle_checks_per_update := 8
@export_range(1.0, 20.0, 0.5) var spawn_separation := 8.0
@export_range(0.0, 5.0, 0.05) var spawn_body_height := 0.95
@export_range(1.0, 20.0, 0.5) var spawn_ground_probe_height := 7.0
@export_flags_3d_physics var spawn_ground_probe_mask := 0xffffffff
@export_category("Performance")
@export_range(8.0, 64.0, 1.0) var traffic_cell_size := 18.0
@export_range(1, 12, 1) var obstacle_raycast_interval := 3
@export_range(5.0, 250.0, 5.0) var high_detail_distance := 65.0
@export_range(0.0, 2.0, 0.05) var spawn_settle_duration := 0.25

@onready var network := get_node(network_path) as TrafficNetwork3D
@onready var player := get_node(player_path) as CharacterBody3D
@onready var vehicle_container := get_node(vehicle_container_path) as Node3D

var _active: Array[BaseVehicle] = []
var _inactive: Array[BaseVehicle] = []
var _traffic_cells := {}
var _pending_reveal := {}
var _random := RandomNumberGenerator.new()
var _update_remaining := 0.0
var _recycle_cursor := 0
var _physics_tick_index := 0
var _cached_spawn_body_height := -1.0
var _enabled := true


func _ready() -> void:
	_random.randomize()
	_update_remaining = population_update_interval


func _process(delta: float) -> void:
	if not _enabled:
		return
	_update_remaining -= delta
	if _update_remaining > 0.0:
		return
	_update_remaining = population_update_interval
	update_population()


func _physics_process(delta: float) -> void:
	if not _enabled:
		return
	_update_pending_reveals(delta)
	_rebuild_traffic_cells()
	var recycle_requests: Array[BaseVehicle] = []
	for index in range(_active.size()):
		var vehicle := _active[index]
		if not is_instance_valid(vehicle):
			continue
		_update_vehicle_detail(vehicle)
		if _pending_reveal.has(vehicle):
			vehicle.drive_component.set_ai_control(0.0, 1.0, 0.0)
			continue
		var ai := _get_ai(vehicle)
		if ai != null:
			var allow_raycast := (
				(_physics_tick_index + index)
				% maxi(obstacle_raycast_interval, 1)
			) == 0
			ai.tick_traffic(delta, _get_nearby_vehicles(vehicle), allow_raycast)
			if ai.wants_recycle():
				recycle_requests.append(vehicle)
	for vehicle in recycle_requests:
		if is_instance_valid(vehicle):
			_recycle_vehicle(vehicle)
	_physics_tick_index += 1


func update_population() -> void:
	if (
		vehicle_scene == null
		or network == null
		or player == null
		or vehicle_container == null
	):
		return
	_recycle_distant_vehicles()
	var activation_count := 0
	while (
		_active.size() < mini(active_target, pool_capacity)
		and activation_count < maximum_activations_per_update
	):
		if not _activate_one():
			break
		activation_count += 1


func populate_immediately(requested_count := -1) -> int:
	var target_count := (
		mini(active_target, pool_capacity)
		if requested_count < 0
		else mini(requested_count, pool_capacity)
	)
	var activated := 0
	while _active.size() < target_count:
		if not _activate_one():
			break
		activated += 1
	return activated


func set_population_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_process(enabled)
	set_physics_process(enabled)


func get_active_count() -> int:
	return _active.size()


func get_inactive_count() -> int:
	return _inactive.size()


func get_live_pool_count() -> int:
	return _active.size() + _inactive.size()


func get_active_vehicles() -> Array[BaseVehicle]:
	return _active.duplicate()


func _activate_one() -> bool:
	var chosen: TrafficWaypoint3D = _choose_spawn_waypoint()
	if chosen == null:
		return false
	var vehicle := _acquire_vehicle()
	if vehicle == null:
		return false
	var ai := _ensure_ai(vehicle)
	ai.assign_route(network, chosen, _random.randi())
	vehicle.global_transform = _get_grounded_spawn_transform(
		ai.get_spawn_transform()
	)
	vehicle.linear_velocity = Vector3.ZERO
	vehicle.angular_velocity = Vector3.ZERO
	vehicle.sleeping = false
	vehicle.process_mode = Node.PROCESS_MODE_INHERIT
	vehicle.set_managed_traffic_enabled(true)
	vehicle.drive_component.set_ai_control(0.0, 1.0, 0.0)
	vehicle.visible = spawn_settle_duration <= 0.0
	_active.append(vehicle)
	if spawn_settle_duration > 0.0:
		_pending_reveal[vehicle] = spawn_settle_duration
	return true


func _acquire_vehicle() -> BaseVehicle:
	if not _inactive.is_empty():
		return _inactive.pop_back() as BaseVehicle
	if get_live_pool_count() >= pool_capacity:
		return null
	var vehicle := vehicle_scene.instantiate() as BaseVehicle
	if vehicle == null:
		return null
	vehicle.process_mode = Node.PROCESS_MODE_DISABLED
	vehicle.visible = false
	vehicle_container.add_child(vehicle)
	vehicle.tree_exiting.connect(
		_on_vehicle_tree_exiting.bind(vehicle),
		CONNECT_ONE_SHOT
	)
	_ensure_ai(vehicle)
	return vehicle


func _choose_spawn_waypoint() -> TrafficWaypoint3D:
	var candidates := network.get_spawn_candidates(
		player.global_position,
		minimum_spawn_distance,
		maximum_spawn_distance
	)
	if candidates.is_empty():
		return null
	_shuffle_waypoints(candidates)
	var camera := get_viewport().get_camera_3d()
	for waypoint in candidates:
		if _is_spawn_occupied(waypoint.global_position):
			continue
		if camera == null or not camera.is_position_in_frustum(
			waypoint.global_position + Vector3.UP
		):
			return waypoint
	return null


func _recycle_distant_vehicles() -> void:
	if _active.is_empty():
		_recycle_cursor = 0
		return
	var checks := mini(recycle_checks_per_update, _active.size())
	var player_position := player.global_position
	var recycle_distance_squared := recycle_distance * recycle_distance
	for _index in range(checks):
		if _active.is_empty():
			break
		_recycle_cursor %= _active.size()
		var vehicle := _active[_recycle_cursor]
		if not is_instance_valid(vehicle):
			_recycle_cursor += 1
			continue
		if vehicle.global_position.distance_squared_to(player_position) > recycle_distance_squared:
			_recycle_vehicle(vehicle)
			continue
		_recycle_cursor += 1


func _recycle_vehicle(vehicle: BaseVehicle) -> void:
	_active.erase(vehicle)
	_pending_reveal.erase(vehicle)
	var ai := _get_ai(vehicle)
	if ai != null:
		ai.clear()
	vehicle.set_managed_traffic_enabled(false)
	vehicle.linear_velocity = Vector3.ZERO
	vehicle.angular_velocity = Vector3.ZERO
	vehicle.sleeping = true
	vehicle.visible = false
	vehicle.process_mode = Node.PROCESS_MODE_DISABLED
	_inactive.append(vehicle)
	if not _active.is_empty():
		_recycle_cursor %= _active.size()
	else:
		_recycle_cursor = 0


func _is_spawn_occupied(position: Vector3) -> bool:
	var separation_squared := spawn_separation * spawn_separation
	for vehicle in _active:
		if (
			is_instance_valid(vehicle)
			and vehicle.global_position.distance_squared_to(position)
			< separation_squared
		):
			return true
	return false


func _get_grounded_spawn_transform(spawn_transform: Transform3D) -> Transform3D:
	var world := get_world_3d()
	if world == null:
		return spawn_transform
	var origin := spawn_transform.origin
	var query := PhysicsRayQueryParameters3D.create(
		origin + Vector3.UP * spawn_ground_probe_height,
		origin - Vector3.UP * spawn_ground_probe_height,
		spawn_ground_probe_mask
	)
	var hit := world.direct_space_state.intersect_ray(query)
	var body_height := _get_vehicle_spawn_height()
	if hit.is_empty():
		spawn_transform.origin.y = maxf(spawn_transform.origin.y, body_height)
		return spawn_transform
	spawn_transform.origin = (hit.get("position") as Vector3) + Vector3.UP * body_height
	return spawn_transform


func _get_vehicle_spawn_height() -> float:
	if _cached_spawn_body_height >= 0.0:
		return _cached_spawn_body_height
	if vehicle_scene == null:
		return spawn_body_height
	var preview := vehicle_scene.instantiate() as BaseVehicle
	if preview == null or preview.definition == null:
		if preview != null:
			preview.free()
		return spawn_body_height
	var wheel := preview.get_node_or_null(
		preview.front_left_wheel_path
	) as VehicleWheel3D
	var wheel_anchor_height := 0.0
	if wheel != null:
		wheel_anchor_height = wheel.position.y
	var height := maxf(
		preview.definition.wheel_radius
		+ preview.definition.suspension_rest_length
		- wheel_anchor_height
		+ 0.02,
		0.08
	)
	preview.free()
	_cached_spawn_body_height = minf(height, spawn_body_height)
	return _cached_spawn_body_height


func _update_pending_reveals(delta: float) -> void:
	if _pending_reveal.is_empty():
		return
	var finished: Array[BaseVehicle] = []
	for key in _pending_reveal.keys():
		var vehicle := key as BaseVehicle
		if not is_instance_valid(vehicle):
			finished.append(vehicle)
			continue
		var remaining := float(_pending_reveal[vehicle]) - delta
		if remaining > 0.0:
			_pending_reveal[vehicle] = remaining
			continue
		vehicle.linear_velocity = Vector3.ZERO
		vehicle.angular_velocity = Vector3.ZERO
		vehicle.visible = true
		finished.append(vehicle)
	for vehicle in finished:
		_pending_reveal.erase(vehicle)


func _rebuild_traffic_cells() -> void:
	_traffic_cells.clear()
	for vehicle in _active:
		if not is_instance_valid(vehicle):
			continue
		var cell := _get_traffic_cell(vehicle.global_position)
		if not _traffic_cells.has(cell):
			_traffic_cells[cell] = []
		(_traffic_cells[cell] as Array).append(vehicle)


func _get_nearby_vehicles(vehicle: BaseVehicle) -> Array[BaseVehicle]:
	var nearby: Array[BaseVehicle] = []
	if not is_instance_valid(vehicle):
		return nearby
	var center := _get_traffic_cell(vehicle.global_position)
	var search_radius := 1
	for cell_x in range(center.x - search_radius, center.x + search_radius + 1):
		for cell_y in range(center.y - search_radius, center.y + search_radius + 1):
			var cell := Vector2i(cell_x, cell_y)
			if not _traffic_cells.has(cell):
				continue
			for other: BaseVehicle in _traffic_cells[cell]:
				if other != vehicle:
					nearby.append(other)
	return nearby


func _get_traffic_cell(world_position: Vector3) -> Vector2i:
	var size := maxf(traffic_cell_size, 1.0)
	return Vector2i(
		floori(world_position.x / size),
		floori(world_position.z / size)
	)


func _update_vehicle_detail(vehicle: BaseVehicle) -> void:
	if not is_instance_valid(player) or not is_instance_valid(vehicle):
		return
	var high_detail_squared := high_detail_distance * high_detail_distance
	var high_detail := (
		vehicle.global_position.distance_squared_to(player.global_position)
		<= high_detail_squared
	)
	if vehicle.has_method("set_traffic_detail_enabled"):
		vehicle.call("set_traffic_detail_enabled", high_detail)


func _ensure_ai(vehicle: BaseVehicle) -> TrafficVehicleAIComponent:
	var ai := _get_ai(vehicle)
	if ai != null:
		return ai
	ai = TrafficVehicleAIComponent.new()
	ai.name = "TrafficAIComponent"
	vehicle.add_child(ai)
	ai.initialize(vehicle)
	return ai


func _get_ai(vehicle: BaseVehicle) -> TrafficVehicleAIComponent:
	return vehicle.get_node_or_null(
		"TrafficAIComponent"
	) as TrafficVehicleAIComponent


func _shuffle_waypoints(waypoints: Array[TrafficWaypoint3D]) -> void:
	for index in range(waypoints.size() - 1, 0, -1):
		var swap_index := _random.randi_range(0, index)
		var temporary := waypoints[index]
		waypoints[index] = waypoints[swap_index]
		waypoints[swap_index] = temporary


func _on_vehicle_tree_exiting(vehicle: BaseVehicle) -> void:
	_active.erase(vehicle)
	_inactive.erase(vehicle)
