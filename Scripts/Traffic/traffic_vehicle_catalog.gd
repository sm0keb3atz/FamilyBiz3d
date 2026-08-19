class_name TrafficVehicleCatalog
extends Resource

const VariantResource := preload("res://Scripts/Traffic/traffic_vehicle_variant.gd")
const DEFAULT_TRAFFIC_ENGINE_STREAM := preload(
	"res://Assets/Audio/Vehicles/CorvetteIdle.wav"
)

const STABLE_AMBIENT_IDS := [
	&"sedan",
	&"suv",
	&"muscle",
	&"sport_classic_01",
	&"sport_classic_02",
]

const AUTHORED_VEHICLE_SCENE_PATHS := {
	&"sedan": "res://Scenes/Vehicles/Sedan.tscn",
	&"suv": "res://Scenes/Vehicles/SUV.tscn",
	&"pickup": "res://Scenes/Vehicles/Pickup.tscn",
	&"van": "res://Scenes/Vehicles/Van.tscn",
	&"muscle": "res://Scenes/Vehicles/MuscleCar.tscn",
	&"pickup_old": "res://Scenes/Vehicles/OldPickup.tscn",
	&"offroad": "res://Scenes/Vehicles/Offroad.tscn",
	&"sport_classic_01": "res://Scenes/Vehicles/SportClassic01.tscn",
	&"sport_classic_01a": "res://Scenes/Vehicles/SportClassic01A.tscn",
	&"sport_classic_02": "res://Scenes/Vehicles/SportClassic02.tscn",
}

static var BODY_COLORS := PackedColorArray([
	Color("23262b"), Color("a9adb2"), Color("d8d7d2"), Color("101114"),
	Color("24354d"), Color("5b2630"), Color("2f4938"), Color("8a795f"),
	Color("3d6075"), Color("8c6a2f"),
])

const WHEEL_REST_HEIGHTS := {
	&"sedan": Vector2(0.348836, 0.348836),
	&"suv": Vector2(0.376849, 0.376849),
	&"pickup": Vector2(0.390197, 0.390197),
	&"van": Vector2(0.376849, 0.376849),
	&"muscle": Vector2(0.378648, 0.378648),
	&"pickup_old": Vector2(0.330560, 0.330560),
	&"offroad": Vector2(0.373241, 0.373241),
	&"sport_classic_01": Vector2(0.396808, 0.396808),
	&"sport_classic_01a": Vector2(0.396808, 0.396808),
	&"sport_classic_02": Vector2(0.348836, 0.348836),
	&"tow_truck": Vector2(0.517804, 0.517804),
	&"vegetable_truck": Vector2(0.330560, 0.376849),
	&"cargo_truck_old": Vector2(0.330560, 0.376849),
	&"hearse": Vector2(0.398946, 0.398946),
}

var _variants: Array[Resource] = []


func get_variants() -> Array[Resource]:
	if _variants.is_empty():
		_build_default_catalog()
	return _variants.duplicate()


func get_variant(variant_id: StringName) -> Resource:
	for variant in get_variants():
		if variant.variant_id == variant_id:
			return variant
	return null


func get_ambient_variants() -> Array[Resource]:
	var results: Array[Resource] = []
	for variant in get_variants():
		if variant.ambient_enabled:
			results.append(variant)
	return results


func _build_default_catalog() -> void:
	# id, display name, file, weight, collision size/offset, FL, FR, RL, RR.
	# Wheel coordinates are already rotated into BaseVehicle space.
	var entries: Array[Array] = [
		[&"sedan", "Sedan", "SK_veh_Sedan_01.gltf", 24.0, Vector3(2.2, 1.05, 4.85), Vector3(0, .72, .05), Vector3(.886, .45, 1.631), Vector3(-.887, .45, 1.631), Vector3(.886, .45, -1.321), Vector3(-.887, .45, -1.321)],
		[&"suv", "SUV", "SK_veh_SUV_01.gltf", 18.0, Vector3(2.15, 1.55, 4.55), Vector3(0, .95, -.05), Vector3(.838, .48, 1.604), Vector3(-.838, .48, 1.604), Vector3(.838, .48, -1.424), Vector3(-.838, .48, -1.424)],
		[&"pickup", "Pickup", "SK_veh_Pickup_01.gltf", 12.0, Vector3(2.15, 1.45, 5.25), Vector3(0, .9, -.2), Vector3(.842, .49, 1.775), Vector3(-.842, .49, 1.775), Vector3(.842, .49, -1.582), Vector3(-.842, .49, -1.582)],
		[&"van", "Van", "SK_veh_Van_01.gltf", 10.0, Vector3(2.25, 1.65, 4.75), Vector3(0, 1, 0), Vector3(.863, .48, 1.778), Vector3(-.863, .48, 1.778), Vector3(.863, .48, -1.43), Vector3(-.863, .48, -1.43)],
		[&"muscle", "Muscle Car", "SK_veh_Muscle_01.gltf", 8.0, Vector3(1.9, .8, 4.7), Vector3(0, .83, 0), Vector3(.806, .48, 1.517), Vector3(-.806, .48, 1.517), Vector3(.806, .48, -1.523), Vector3(-.806, .48, -1.523)],
		[&"pickup_old", "Old Pickup", "SK_veh_PickupOld_01.gltf", 6.0, Vector3(2.1, 1.25, 4.45), Vector3(0, .8, 0), Vector3(.81, .43, 1.66), Vector3(-.81, .43, 1.66), Vector3(.81, .43, -1.298), Vector3(-.81, .43, -1.298)],
		[&"offroad", "Offroad", "SK_veh_Offroad_01.gltf", 5.0, Vector3(1.75, 1.55, 3.45), Vector3(0, .95, -.1), Vector3(.649, .48, 1.069), Vector3(-.649, .48, 1.069), Vector3(.649, .48, -1.262), Vector3(-.649, .48, -1.262)],
		[&"sport_classic_01", "Sport Classic 01", "SK_veh_SportClassic_01.gltf", 3.0, Vector3(1.95, 1, 4.55), Vector3(0, .75, .1), Vector3(.886, .5, 1.402), Vector3(-.886, .5, 1.402), Vector3(.893, .5, -1.333), Vector3(-.893, .5, -1.333)],
		[&"sport_classic_01a", "Sport Classic 01A", "SK_veh_SportClassic_01a.gltf", 3.0, Vector3(1.95, 1, 4.55), Vector3(0, .75, .1), Vector3(.886, .5, 1.402), Vector3(-.886, .5, 1.402), Vector3(.893, .5, -1.333), Vector3(-.893, .5, -1.333)],
		[&"sport_classic_02", "Sport Classic 02", "SK_veh_SportClassic_02.gltf", 3.0, Vector3(1.95, .95, 4.5), Vector3(0, .72, 0), Vector3(.797, .45, 1.483), Vector3(-.797, .45, 1.483), Vector3(.797, .45, -1.421), Vector3(-.797, .45, -1.421)],
		[&"tow_truck", "Tow Truck", "SK_veh_TruckTow.gltf", 3.0, Vector3(2.35, 2, 6.55), Vector3(0, 1.25, -.35), Vector3(1.034, .62, 2.29), Vector3(-1.034, .62, 2.29), Vector3(.831, .62, -2.086), Vector3(-.831, .62, -2.086)],
		[&"vegetable_truck", "Vegetable Truck", "SK_veh_VegetableTruck.gltf", 2.0, Vector3(2.15, 1.35, 4.85), Vector3(0, .85, -.15), Vector3(.81, .43, 1.66), Vector3(-.81, .43, 1.66), Vector3(.838, .48, -1.654), Vector3(-.838, .48, -1.654)],
		[&"cargo_truck_old", "Old Cargo Truck", "SK_veh_CargoTruckOld.gltf", 1.0, Vector3(2.15, 1.35, 4.85), Vector3(0, .85, -.15), Vector3(.81, .43, 1.66), Vector3(-.81, .43, 1.66), Vector3(.838, .48, -1.654), Vector3(-.838, .48, -1.654)],
		[&"hearse", "Hearse", "SK_veh_Hearse.gltf", 1.0, Vector3(2.2, 1.1, 5.35), Vector3(0, .78, -.15), Vector3(.874, .5, 1.688), Vector3(-.874, .5, 1.688), Vector3(.874, .5, -1.792), Vector3(-.874, .5, -1.792)],
	]
	for entry in entries:
		_add_entry(entry)


func _add_entry(entry: Array) -> void:
	var definition := VehicleDefinition.new()
	definition.vehicle_id = entry[0] as StringName
	definition.display_name = str(entry[1])
	definition.visual_scene = load(
		"res://Assets/MapStuff/Meshs/Vehicles/%s" % str(entry[2])
	) as PackedScene
	definition.collision_size = entry[4] as Vector3
	definition.collision_offset = entry[5] as Vector3
	definition.front_left_wheel_anchor = entry[6] as Vector3
	definition.front_right_wheel_anchor = entry[7] as Vector3
	definition.rear_left_wheel_anchor = entry[8] as Vector3
	definition.rear_right_wheel_anchor = entry[9] as Vector3
	var rest_heights := WHEEL_REST_HEIGHTS.get(
		definition.vehicle_id, Vector2(definition.wheel_radius, definition.wheel_radius)
	) as Vector2
	definition.front_left_wheel_anchor.y = rest_heights.x + definition.suspension_rest_length
	definition.front_right_wheel_anchor.y = rest_heights.x + definition.suspension_rest_length
	definition.rear_left_wheel_anchor.y = rest_heights.y + definition.suspension_rest_length
	definition.rear_right_wheel_anchor.y = rest_heights.y + definition.suspension_rest_length
	definition.wheel_radius = (rest_heights.x + rest_heights.y) * 0.5
	definition.mass = clampf(
		definition.collision_size.x * definition.collision_size.z * 135.0,
		900.0,
		2600.0
	)
	# Ambient traffic needs enough steering lock to stay in its lane through
	# the compact authored intersections. The generic vehicle default is tuned
	# for player handling and gives these AI cars an excessively wide arc.
	definition.max_steering_degrees = 45.0
	definition.max_forward_speed = 35.0
	# Runtime traffic definitions replace the definitions authored on the car
	# scenes, so their engine stream must be carried over explicitly.
	definition.engine_stream = DEFAULT_TRAFFIC_ENGINE_STREAM
	var variant := VariantResource.new()
	variant.variant_id = definition.vehicle_id
	variant.definition = definition
	var authored_scene_path := str(
		AUTHORED_VEHICLE_SCENE_PATHS.get(definition.vehicle_id, "")
	)
	if not authored_scene_path.is_empty():
		variant.vehicle_scene = load(authored_scene_path) as PackedScene
	variant.spawn_weight = float(entry[3])
	variant.ambient_enabled = definition.vehicle_id in STABLE_AMBIENT_IDS
	_variants.append(variant)
