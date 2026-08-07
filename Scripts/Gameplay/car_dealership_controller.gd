class_name CarDealershipController
extends Node3D

@export var parking_lot_path := NodePath("ParkingLot")

var _bays: Array[Dictionary] = []
var _delivery_reservations: Dictionary = {}


func _ready() -> void:
	add_to_group(&"car_dealership")
	_discover_bays()


func get_first_free_delivery() -> Dictionary:
	for bay in _bays:
		var area := bay.get("area") as Area3D
		var marker := bay.get("marker") as Marker3D
		if area != null and marker != null and not _area_has_vehicle(area):
			return {
				"available": true,
				"transform": marker.global_transform,
				"area": area,
				"marker": marker,
			}
	return {"available": false}


func has_free_delivery_bay() -> bool:
	return bool(get_first_free_delivery().get("available", false))


func get_parked_owned_vehicles(
	garage: PlayerVehicleGarageComponent
) -> Array[BaseVehicle]:
	var result: Array[BaseVehicle] = []
	if garage == null:
		return result
	for bay in _bays:
		var area := bay.get("area") as Area3D
		if area == null:
			continue
		for body in area.get_overlapping_bodies():
			var vehicle := body as BaseVehicle
			if (
				vehicle != null
				and not vehicle.has_driver()
				and garage.owns_vehicle(vehicle)
				and not result.has(vehicle)
			):
				result.append(vehicle)
	return result


func is_vehicle_parked_for_sale(
	vehicle: BaseVehicle,
	garage: PlayerVehicleGarageComponent
) -> bool:
	return (
		vehicle != null
		and not vehicle.has_driver()
		and garage != null
		and garage.owns_vehicle(vehicle)
		and get_parked_owned_vehicles(garage).has(vehicle)
	)


func get_bay_count() -> int:
	return _bays.size()


func register_delivery(delivery: Dictionary, vehicle: BaseVehicle) -> void:
	var area := delivery.get("area") as Area3D
	if area != null and vehicle != null:
		_delivery_reservations[area] = weakref(vehicle)


func _discover_bays() -> void:
	_bays.clear()
	var parking_lot := get_node_or_null(parking_lot_path)
	if parking_lot == null:
		return
	var spaces := parking_lot.get_children()
	spaces.sort_custom(func(a: Node, b: Node) -> bool: return a.name < b.name)
	for space in spaces:
		var marker := space.get_node_or_null("CarSpawn") as Marker3D
		var area := space.get_node_or_null("CarSellArea") as Area3D
		if marker != null and area != null:
			_bays.append({"marker": marker, "area": area})


func _area_has_vehicle(area: Area3D) -> bool:
	for body in area.get_overlapping_bodies():
		if body is BaseVehicle:
			return true
	var reservation := _delivery_reservations.get(area) as WeakRef
	if reservation != null:
		var reserved := reservation.get_ref() as BaseVehicle
		if is_instance_valid(reserved):
			var marker: Marker3D
			for bay in _bays:
				if bay.get("area") == area:
					marker = bay.get("marker") as Marker3D
					break
			if marker != null and reserved.global_position.distance_to(
				marker.global_position
			) < 4.0:
				return true
	_delivery_reservations.erase(area)
	return false
