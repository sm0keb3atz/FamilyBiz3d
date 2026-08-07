class_name VehicleCatalog
extends RefCounted

const RESALE_PERCENT := 60

const VEHICLE_IDS: Array[StringName] = [
	&"pickup_old",
	&"sedan",
	&"van",
	&"pickup",
	&"offroad",
	&"suv",
	&"muscle",
	&"sport_classic_01",
	&"sport_classic_01a",
	&"sport_classic_02",
]

const DEFINITION_PATHS := {
	&"pickup_old": "res://Scripts/Vehicles/Resources/old_pickup_definition.tres",
	&"sedan": "res://Scripts/Vehicles/Resources/sedan_definition.tres",
	&"van": "res://Scripts/Vehicles/Resources/van_definition.tres",
	&"pickup": "res://Scripts/Vehicles/Resources/pickup_definition.tres",
	&"offroad": "res://Scripts/Vehicles/Resources/offroad_definition.tres",
	&"suv": "res://Scripts/Vehicles/Resources/suv_definition.tres",
	&"muscle": "res://Scripts/Vehicles/Resources/muscle_car_definition.tres",
	&"sport_classic_01": "res://Scripts/Vehicles/Resources/sport_classic_01_definition.tres",
	&"sport_classic_01a": "res://Scripts/Vehicles/Resources/sport_classic_01a_definition.tres",
	&"sport_classic_02": "res://Scripts/Vehicles/Resources/sport_classic_02_definition.tres",
}

const SCENE_PATHS := {
	&"pickup_old": "res://Scenes/Vehicles/OldPickup.tscn",
	&"sedan": "res://Scenes/Vehicles/Sedan.tscn",
	&"van": "res://Scenes/Vehicles/Van.tscn",
	&"pickup": "res://Scenes/Vehicles/Pickup.tscn",
	&"offroad": "res://Scenes/Vehicles/Offroad.tscn",
	&"suv": "res://Scenes/Vehicles/SUV.tscn",
	&"muscle": "res://Scenes/Vehicles/MuscleCar.tscn",
	&"sport_classic_01": "res://Scenes/Vehicles/SportClassic01.tscn",
	&"sport_classic_01a": "res://Scenes/Vehicles/SportClassic01A.tscn",
	&"sport_classic_02": "res://Scenes/Vehicles/SportClassic02.tscn",
}


static func get_all() -> Array[VehicleDefinition]:
	var result: Array[VehicleDefinition] = []
	for vehicle_id in VEHICLE_IDS:
		var definition := get_by_id(vehicle_id)
		if definition != null:
			result.append(definition)
	return result


static func get_by_id(vehicle_id: StringName) -> VehicleDefinition:
	var path := String(DEFINITION_PATHS.get(vehicle_id, ""))
	return load(path) as VehicleDefinition if not path.is_empty() else null


static func get_scene(vehicle_id: StringName) -> PackedScene:
	var path := String(SCENE_PATHS.get(vehicle_id, ""))
	return load(path) as PackedScene if not path.is_empty() else null


static func get_resale_value(vehicle_id: StringName) -> int:
	var definition := get_by_id(vehicle_id)
	if definition == null:
		return 0
	return definition.purchase_price * RESALE_PERCENT / 100


static func is_valid_vehicle_id(vehicle_id: StringName) -> bool:
	return DEFINITION_PATHS.has(vehicle_id) and SCENE_PATHS.has(vehicle_id)
