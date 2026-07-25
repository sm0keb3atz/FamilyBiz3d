class_name PoliceResponseProfile
extends Resource

@export var officer_targets := PackedInt32Array([0, 2, 4, 6])
@export var cruiser_limits := PackedInt32Array([0, 1, 2, 3])
@export var initial_dispatch_delays := PackedFloat32Array([0.0, 2.0, 1.0, 0.25])
@export var target_arrival_minimums := PackedFloat32Array([0.0, 8.0, 6.0, 5.0])
@export var target_arrival_maximums := PackedFloat32Array([0.0, 12.0, 9.0, 7.0])
@export var awareness_radii := PackedFloat32Array([0.0, 55.0, 110.0, 220.0])
@export_range(0.25, 10.0, 0.25) var cruiser_launch_spacing := 1.5
@export_range(4.0, 40.0, 0.5) var deployment_distance := 15.0
@export_range(0.25, 5.0, 0.25) var stationary_deploy_seconds := 1.5
@export_range(0.1, 5.0, 0.1) var stationary_speed := 2.0
@export_range(1.0, 15.0, 0.5) var response_audit_interval := 1.0
@export_range(1.0, 10.0, 0.5) var stalled_reroute_seconds := 4.0
@export_range(5.0, 30.0, 0.5) var deployment_deadline_seconds := 15.0


func get_officer_target(level: int) -> int:
	return _get_int(officer_targets, level, level * 2)


func get_cruiser_limit(level: int) -> int:
	return _get_int(cruiser_limits, level, level)


func get_cruiser_target(level: int) -> int:
	return get_cruiser_limit(level)


func get_dispatch_delay(level: int) -> float:
	return _get_float(initial_dispatch_delays, level, 1.0)


func get_arrival_minimum(level: int) -> float:
	return _get_float(target_arrival_minimums, level, 5.0)


func get_arrival_maximum(level: int) -> float:
	return _get_float(target_arrival_maximums, level, 12.0)


func get_awareness_radius(level: int) -> float:
	return _get_float(awareness_radii, level, 55.0)


func _get_int(values: PackedInt32Array, level: int, fallback: int) -> int:
	return values[clampi(level, 0, values.size() - 1)] if not values.is_empty() else fallback


func _get_float(values: PackedFloat32Array, level: int, fallback: float) -> float:
	return values[clampi(level, 0, values.size() - 1)] if not values.is_empty() else fallback
