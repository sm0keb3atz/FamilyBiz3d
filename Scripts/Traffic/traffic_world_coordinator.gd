class_name TrafficWorldCoordinator
extends Node3D

@export_range(8.0, 64.0, 1.0) var cell_size := 18.0

var _vehicles: Array[BaseVehicle] = []
var _cells := {}


func _ready() -> void:
	process_physics_priority = -100


func _physics_process(_delta: float) -> void:
	_rebuild_cells()


func register_vehicle(vehicle: BaseVehicle) -> void:
	if is_instance_valid(vehicle) and vehicle not in _vehicles:
		_vehicles.append(vehicle)


func unregister_vehicle(vehicle: BaseVehicle) -> void:
	_vehicles.erase(vehicle)


func get_active_vehicles(excluding: BaseVehicle = null) -> Array[BaseVehicle]:
	_prune_invalid()
	var results: Array[BaseVehicle] = []
	for vehicle in _vehicles:
		if vehicle != excluding and vehicle.is_managed_traffic():
			results.append(vehicle)
	return results


func get_nearby_vehicles(
	vehicle: BaseVehicle,
	radius: float
) -> Array[BaseVehicle]:
	var results: Array[BaseVehicle] = []
	if not is_instance_valid(vehicle):
		return results
	var center := _get_cell(vehicle.global_position)
	var cell_radius := maxi(1, ceili(radius / maxf(cell_size, 1.0)))
	var radius_squared := radius * radius
	for cell_x in range(center.x - cell_radius, center.x + cell_radius + 1):
		for cell_y in range(center.y - cell_radius, center.y + cell_radius + 1):
			var cell := Vector2i(cell_x, cell_y)
			if not _cells.has(cell):
				continue
			for other: BaseVehicle in _cells[cell]:
				if (
					other != vehicle
					and is_instance_valid(other)
					and other.global_position.distance_squared_to(
						vehicle.global_position
					) <= radius_squared
				):
					results.append(other)
	return results


func is_spawn_clear(
	spawn_transform: Transform3D,
	footprint: Vector3,
	padding := 0.75
) -> bool:
	var radius := Vector2(footprint.x, footprint.z).length() * 0.5
	for vehicle in get_active_vehicles():
		var other_size := (
			vehicle.definition.collision_size
			if vehicle.definition != null
			else Vector3(2.0, 1.0, 4.5)
		)
		var other_radius := Vector2(other_size.x, other_size.z).length() * 0.5
		if vehicle.global_position.distance_to(spawn_transform.origin) < (
			radius + other_radius + padding
		):
			return false
	var shape := BoxShape3D.new()
	shape.size = footprint + Vector3(padding * 2.0, 0.2, padding * 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = spawn_transform.translated_local(
		Vector3.UP * maxf(footprint.y * 0.5, 0.5)
	)
	query.collision_mask = 3
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _rebuild_cells() -> void:
	_prune_invalid()
	_cells.clear()
	for vehicle in _vehicles:
		if not vehicle.is_managed_traffic():
			continue
		var cell := _get_cell(vehicle.global_position)
		if not _cells.has(cell):
			_cells[cell] = []
		(_cells[cell] as Array).append(vehicle)


func _prune_invalid() -> void:
	for index in range(_vehicles.size() - 1, -1, -1):
		if not is_instance_valid(_vehicles[index]):
			_vehicles.remove_at(index)


func _get_cell(world_position: Vector3) -> Vector2i:
	var size := maxf(cell_size, 1.0)
	return Vector2i(
		floori(world_position.x / size),
		floori(world_position.z / size)
	)
