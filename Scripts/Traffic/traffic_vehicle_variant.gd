class_name TrafficVehicleVariant
extends Resource

@export var variant_id: StringName
@export var definition: VehicleDefinition
@export_range(0.0, 1000.0, 0.1) var spawn_weight := 1.0
@export var ambient_enabled := true


func is_valid() -> bool:
	return variant_id != &"" and definition != null and definition.visual_scene != null
