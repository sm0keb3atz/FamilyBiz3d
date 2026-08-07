class_name PlayerVehicleGarageComponent
extends Node

signal ownership_changed
signal storage_changed(property_id: StringName)
signal vehicle_spawned(vehicle: BaseVehicle, instance_id: StringName)
signal vehicle_removed(instance_id: StringName)

const OWNED_GROUP := &"player_owned_vehicle"
const MAXIMUM_STORE_LINEAR_SPEED := 0.75
const MAXIMUM_STORE_ANGULAR_SPEED := 1.0

@export var property_component_path := NodePath("../PropertyComponent")

@onready var properties := get_node_or_null(
	property_component_path
) as PlayerPropertyComponent

var _records: Dictionary[StringName, Dictionary] = {}
var _next_instance_number := 1


func _ready() -> void:
	if (
		properties != null
		and not properties.ownership_changed.is_connected(
			_on_property_ownership_changed
		)
	):
		properties.ownership_changed.connect(_on_property_ownership_changed)


func spawn_new_vehicle(
	vehicle_id: StringName,
	spawn_transform: Transform3D,
	container: Node3D
) -> BaseVehicle:
	var instance_id := StringName("vehicle_%06d" % _next_instance_number)
	var vehicle := _instantiate_vehicle(
		vehicle_id,
		instance_id,
		spawn_transform,
		container
	)
	if vehicle == null:
		return null
	_records[instance_id] = {
		"vehicle_id": vehicle_id,
		"node": vehicle,
		"position": spawn_transform.origin,
		"yaw": spawn_transform.basis.get_euler().y,
		"stored_at_property_id": &"",
	}
	_next_instance_number += 1
	vehicle_spawned.emit(vehicle, instance_id)
	ownership_changed.emit()
	return vehicle


func remove_owned_vehicle(vehicle: BaseVehicle) -> bool:
	return remove_owned_vehicle_by_instance_id(get_owned_instance_id(vehicle))


func remove_owned_vehicle_by_instance_id(instance_id: StringName) -> bool:
	if instance_id.is_empty() or not _records.has(instance_id):
		return false
	var record := _records[instance_id] as Dictionary
	var stored_at := StringName(record.get("stored_at_property_id", ""))
	_destroy_live_node(record.get("node") as BaseVehicle)
	_records.erase(instance_id)
	vehicle_removed.emit(instance_id)
	if not stored_at.is_empty():
		storage_changed.emit(stored_at)
	ownership_changed.emit()
	return true


func owns_vehicle(vehicle: Node) -> bool:
	if vehicle == null or not is_instance_valid(vehicle):
		return false
	var instance_id := get_owned_instance_id(vehicle)
	return not instance_id.is_empty() and _records.has(instance_id)


func get_owned_instance_id(vehicle: Node) -> StringName:
	if vehicle == null or not is_instance_valid(vehicle):
		return &""
	return StringName(str(vehicle.get_meta(&"owned_vehicle_instance_id", "")))


func get_owned_count(vehicle_id: StringName = &"") -> int:
	if vehicle_id.is_empty():
		return _records.size()
	var count := 0
	for record in _records.values():
		if StringName(record.get("vehicle_id", "")) == vehicle_id:
			count += 1
	return count


func get_owned_vehicles() -> Array[BaseVehicle]:
	var result: Array[BaseVehicle] = []
	for record in _records.values():
		var vehicle := record.get("node") as BaseVehicle
		if is_instance_valid(vehicle):
			result.append(vehicle)
	return result


func get_vehicle_record(instance_id: StringName) -> Dictionary:
	if not _records.has(instance_id):
		return {}
	return _public_record(instance_id, _records[instance_id] as Dictionary)


func get_stored_vehicle_records(
	property_id: StringName
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance_id in _records:
		var record := _records[instance_id] as Dictionary
		if StringName(record.get("stored_at_property_id", "")) == property_id:
			result.append(_public_record(instance_id, record))
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("instance_id", "")) < String(
				b.get("instance_id", "")
			)
	)
	return result


func get_stored_count(property_id: StringName) -> int:
	return get_stored_vehicle_records(property_id).size()


func get_storage_capacity(property_id: StringName) -> int:
	var definition := PropertyCatalog.get_by_id(property_id)
	return definition.vehicle_storage_capacity if definition != null else 0


func validate_store_vehicle(
	property_id: StringName,
	vehicle: BaseVehicle
) -> Dictionary:
	var definition := PropertyCatalog.get_by_id(property_id)
	if definition == null or definition.vehicle_storage_capacity <= 0:
		return _result(false, "This property has no vehicle storage.")
	if properties == null or not properties.owns(property_id):
		return _result(false, "You do not own this property.")
	if vehicle == null or not is_instance_valid(vehicle) or not owns_vehicle(vehicle):
		return _result(false, "Only an owned vehicle can be stored here.")
	if vehicle.has_driver():
		return _result(false, "Exit the vehicle before storing it.")
	if (
		vehicle.linear_velocity.length() > MAXIMUM_STORE_LINEAR_SPEED
		or vehicle.angular_velocity.length() > MAXIMUM_STORE_ANGULAR_SPEED
	):
		return _result(false, "Wait for the vehicle to stop moving.")
	if get_stored_count(property_id) >= definition.vehicle_storage_capacity:
		return _result(false, "This garage is full.")
	return _result(true, "Vehicle can be stored.")


func store_vehicle(
	property_id: StringName,
	vehicle: BaseVehicle
) -> Dictionary:
	var validation := validate_store_vehicle(property_id, vehicle)
	if not bool(validation.get("success", false)):
		return validation
	var instance_id := get_owned_instance_id(vehicle)
	var record := _records[instance_id] as Dictionary
	record["position"] = vehicle.global_position
	record["yaw"] = vehicle.global_rotation.y
	record["stored_at_property_id"] = property_id
	record["node"] = null
	_destroy_live_node(vehicle)
	storage_changed.emit(property_id)
	ownership_changed.emit()
	return _result(true, "Vehicle stored.", instance_id)


func validate_retrieve_vehicle(
	property_id: StringName,
	instance_id: StringName
) -> Dictionary:
	if properties == null or not properties.owns(property_id):
		return _result(false, "You do not own this property.")
	if not _records.has(instance_id):
		return _result(false, "That vehicle is no longer owned.")
	var record := _records[instance_id] as Dictionary
	if StringName(record.get("stored_at_property_id", "")) != property_id:
		return _result(false, "That vehicle is not stored at this property.")
	if is_instance_valid(record.get("node") as BaseVehicle):
		return _result(false, "That vehicle is already out.")
	return _result(true, "Vehicle can be retrieved.", instance_id)


func retrieve_vehicle(
	property_id: StringName,
	instance_id: StringName,
	spawn_transform: Transform3D,
	container: Node3D
) -> Dictionary:
	var validation := validate_retrieve_vehicle(property_id, instance_id)
	if not bool(validation.get("success", false)):
		return validation
	var record := _records[instance_id] as Dictionary
	var vehicle_id := StringName(record.get("vehicle_id", ""))
	var vehicle := _instantiate_vehicle(
		vehicle_id,
		instance_id,
		spawn_transform,
		container
	)
	if vehicle == null:
		return _result(false, "Vehicle retrieval failed.")
	record["node"] = vehicle
	record["position"] = spawn_transform.origin
	record["yaw"] = spawn_transform.basis.get_euler().y
	record["stored_at_property_id"] = &""
	storage_changed.emit(property_id)
	vehicle_spawned.emit(vehicle, instance_id)
	ownership_changed.emit()
	return {
		"success": true,
		"message": "Vehicle retrieved.",
		"instance_id": instance_id,
		"vehicle": vehicle,
	}


func forfeit_stored_at_property(property_id: StringName) -> int:
	var removed: Array[StringName] = []
	for instance_id in _records:
		var record := _records[instance_id] as Dictionary
		if StringName(record.get("stored_at_property_id", "")) == property_id:
			removed.append(instance_id)
	for instance_id in removed:
		_records.erase(instance_id)
		vehicle_removed.emit(instance_id)
	if not removed.is_empty():
		storage_changed.emit(property_id)
		ownership_changed.emit()
	return removed.size()


func export_save_data() -> Dictionary:
	var vehicles: Array[Dictionary] = []
	for instance_id in _records:
		var record := _records[instance_id] as Dictionary
		var vehicle := record.get("node") as BaseVehicle
		var position := record.get("position", Vector3.ZERO) as Vector3
		var yaw := float(record.get("yaw", 0.0))
		if is_instance_valid(vehicle):
			position = vehicle.global_position
			yaw = vehicle.global_rotation.y
		vehicles.append({
			"instance_id": String(instance_id),
			"vehicle_id": String(record.get("vehicle_id", "")),
			"position": [position.x, position.y, position.z],
			"yaw": yaw,
			"stored_at_property_id": String(
				record.get("stored_at_property_id", "")
			),
		})
	return {
		"next_instance_number": _next_instance_number,
		"owned": vehicles,
	}


func import_save_data(data: Dictionary, container: Node3D) -> void:
	_clear_live_vehicles()
	_next_instance_number = maxi(int(data.get("next_instance_number", 1)), 1)
	var highest_number := 0
	var stored_counts: Dictionary[StringName, int] = {}
	for value in data.get("owned", []) as Array:
		if value is not Dictionary:
			continue
		var saved := value as Dictionary
		var vehicle_id := StringName(str(saved.get("vehicle_id", "")))
		var instance_id := StringName(str(saved.get("instance_id", "")))
		var position_data := saved.get("position", []) as Array
		if (
			instance_id.is_empty()
			or _records.has(instance_id)
			or not VehicleCatalog.is_valid_vehicle_id(vehicle_id)
			or position_data.size() != 3
		):
			continue
		var position := Vector3(
			float(position_data[0]),
			float(position_data[1]),
			float(position_data[2])
		)
		var yaw := float(saved.get("yaw", 0.0))
		var stored_at := StringName(
			str(saved.get("stored_at_property_id", ""))
		)
		var definition := PropertyCatalog.get_by_id(stored_at)
		var stored_count := int(stored_counts.get(stored_at, 0))
		var storage_is_valid := (
			not stored_at.is_empty()
			and definition != null
			and definition.vehicle_storage_capacity > stored_count
			and properties != null
			and properties.owns(stored_at)
		)
		if storage_is_valid:
			_records[instance_id] = {
				"vehicle_id": vehicle_id,
				"node": null,
				"position": position,
				"yaw": yaw,
				"stored_at_property_id": stored_at,
			}
			stored_counts[stored_at] = stored_count + 1
		else:
			var transform := Transform3D(
				Basis.from_euler(Vector3(0.0, yaw, 0.0)),
				position
			)
			var vehicle := _instantiate_vehicle(
				vehicle_id,
				instance_id,
				transform,
				container
			)
			if vehicle == null:
				continue
			_records[instance_id] = {
				"vehicle_id": vehicle_id,
				"node": vehicle,
				"position": position,
				"yaw": yaw,
				"stored_at_property_id": &"",
			}
			vehicle_spawned.emit(vehicle, instance_id)
		var suffix := String(instance_id).trim_prefix("vehicle_").to_int()
		highest_number = maxi(highest_number, suffix)
	_next_instance_number = maxi(_next_instance_number, highest_number + 1)
	for property_id in stored_counts:
		storage_changed.emit(property_id)
	ownership_changed.emit()


func reset_to_new_game() -> void:
	var stored_properties: Dictionary[StringName, bool] = {}
	for record in _records.values():
		var stored_at := StringName(record.get("stored_at_property_id", ""))
		if not stored_at.is_empty():
			stored_properties[stored_at] = true
	_clear_live_vehicles()
	_next_instance_number = 1
	for property_id in stored_properties:
		storage_changed.emit(property_id)
	ownership_changed.emit()


func _instantiate_vehicle(
	vehicle_id: StringName,
	instance_id: StringName,
	spawn_transform: Transform3D,
	container: Node3D
) -> BaseVehicle:
	if container == null or not VehicleCatalog.is_valid_vehicle_id(vehicle_id):
		return null
	var scene := VehicleCatalog.get_scene(vehicle_id)
	if scene == null:
		return null
	var vehicle := scene.instantiate() as BaseVehicle
	if vehicle == null:
		return null
	vehicle.name = "Owned_%s" % String(instance_id)
	vehicle.set_meta(&"owned_vehicle_instance_id", String(instance_id))
	vehicle.add_to_group(OWNED_GROUP)
	container.add_child(vehicle)
	vehicle.global_transform = spawn_transform
	vehicle.linear_velocity = Vector3.ZERO
	vehicle.angular_velocity = Vector3.ZERO
	return vehicle


func _destroy_live_node(vehicle: BaseVehicle) -> void:
	if not is_instance_valid(vehicle):
		return
	vehicle.remove_from_group(OWNED_GROUP)
	var parent := vehicle.get_parent()
	if parent != null:
		parent.remove_child(vehicle)
	vehicle.queue_free()


func _clear_live_vehicles() -> void:
	for record in _records.values():
		_destroy_live_node(record.get("node") as BaseVehicle)
	_records.clear()


func _public_record(
	instance_id: StringName,
	record: Dictionary
) -> Dictionary:
	return {
		"instance_id": instance_id,
		"vehicle_id": StringName(record.get("vehicle_id", "")),
		"stored_at_property_id": StringName(
			record.get("stored_at_property_id", "")
		),
		"is_stored": not StringName(
			record.get("stored_at_property_id", "")
		).is_empty(),
		"node": record.get("node"),
	}


func _result(
	success: bool,
	message: String,
	instance_id: StringName = &""
) -> Dictionary:
	return {
		"success": success,
		"message": message,
		"instance_id": instance_id,
	}


func _on_property_ownership_changed(
	property_id: StringName,
	owned: bool
) -> void:
	if not owned:
		forfeit_stored_at_property(property_id)
