class_name PropertyGarageController
extends Node3D

@export var building_path := NodePath("..")
@export var garage_area_path := NodePath("GarageArea")
@export var spawn_marker_path := NodePath("CarSpawn")
@export var spawn_clearance_path := NodePath("SpawnClearance")

@onready var building := get_node(building_path) as PropertyBuilding
@onready var garage_area := get_node(garage_area_path) as Area3D
@onready var spawn_marker := get_node(spawn_marker_path) as Marker3D
@onready var spawn_clearance := get_node(spawn_clearance_path) as Area3D


func _ready() -> void:
	add_to_group(&"property_garages")


func get_property_id() -> StringName:
	return building.property_id if building != null else &""


func is_available() -> bool:
	if building == null or not building.is_owned():
		return false
	var definition := building.get_definition()
	return definition != null and definition.vehicle_storage_capacity > 0


func get_spawn_transform() -> Transform3D:
	return spawn_marker.global_transform


func get_spawn_block_reason() -> String:
	if not is_available():
		return "This garage is unavailable."
	for body in spawn_clearance.get_overlapping_bodies():
		if (
			not is_instance_valid(body)
			or not body.is_inside_tree()
			or body.is_queued_for_deletion()
		):
			continue
		if body is BaseVehicle:
			return "Move the vehicle out of the retrieval bay."
		if body is CharacterBody3D:
			return "The retrieval bay must be clear of people."
	return ""


func is_spawn_clear() -> bool:
	return get_spawn_block_reason().is_empty()


func get_parked_owned_vehicles(
	garage: PlayerVehicleGarageComponent
) -> Array[BaseVehicle]:
	var result: Array[BaseVehicle] = []
	if garage == null:
		return result
	for body in garage_area.get_overlapping_bodies():
		if (
			not is_instance_valid(body)
			or not body.is_inside_tree()
			or body.is_queued_for_deletion()
		):
			continue
		var vehicle := body as BaseVehicle
		if (
			vehicle != null
			and not vehicle.has_driver()
			and garage.owns_vehicle(vehicle)
			and not result.has(vehicle)
		):
			result.append(vehicle)
	return result
