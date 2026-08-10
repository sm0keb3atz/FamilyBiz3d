class_name VehicleLightComponent
extends Node

@export_category("Automatic Lighting")
@export var automatic_night_lights := true
@export var lights_when_parked := false
@export_category("Lamp Meshes")
@export var headlight_mesh_paths: Array[NodePath] = [
	NodePath("../../VehicleLights/Headlights/HeadlightLeft"),
	NodePath("../../VehicleLights/Headlights/HeadlightRight"),
]
@export var tail_light_mesh_paths: Array[NodePath] = [
	NodePath("../../VehicleLights/TailLights/TailLightLeft"),
	NodePath("../../VehicleLights/TailLights/TailLightRight"),
]
@export_category("Headlight Beams")
@export var headlight_beam_paths: Array[NodePath] = [
	NodePath("../../VehicleLights/Headlights/HeadlightBeamLeft"),
	NodePath("../../VehicleLights/Headlights/HeadlightBeamRight"),
]
@export_category("Materials")
@export var headlight_off_material: Material
@export var headlight_on_material: Material
@export var tail_light_off_material: Material
@export var tail_light_on_material: Material
@export var tail_light_brake_material: Material

var vehicle: BaseVehicle
var _world_time: WorldTimeComponent
var _is_night := false
var _manual_override := -1
var _last_lamps_enabled := false
var _last_beams_enabled := false
var _last_brakes_enabled := false
var _has_applied_state := false


func setup(owner_vehicle: BaseVehicle) -> void:
	vehicle = owner_vehicle
	_apply_lighting_state(true)
	call_deferred("_connect_world_time")


func _process(_delta: float) -> void:
	if vehicle == null:
		return
	_apply_lighting_state()


func _exit_tree() -> void:
	if (
		_world_time != null
		and _world_time.night_state_changed.is_connected(_on_night_state_changed)
	):
		_world_time.night_state_changed.disconnect(_on_night_state_changed)


func set_lights_enabled(enabled: bool) -> void:
	_manual_override = 1 if enabled else 0
	_apply_lighting_state(true)


func clear_manual_override() -> void:
	_manual_override = -1
	_apply_lighting_state(true)


func are_lights_enabled() -> bool:
	return _calculate_lamps_enabled()


func are_brake_lights_enabled() -> bool:
	return _calculate_brakes_enabled()


func _connect_world_time() -> void:
	_world_time = (
		get_tree().get_first_node_in_group(&"world_time")
		as WorldTimeComponent
	)
	if _world_time == null:
		_is_night = false
		_apply_lighting_state(true)
		return
	if not _world_time.night_state_changed.is_connected(_on_night_state_changed):
		_world_time.night_state_changed.connect(_on_night_state_changed)
	_is_night = _world_time.is_nighttime()
	_apply_lighting_state(true)


func _on_night_state_changed(is_night: bool) -> void:
	_is_night = is_night
	_apply_lighting_state(true)


func _calculate_lamps_enabled() -> bool:
	if _manual_override >= 0:
		return _manual_override == 1
	if not automatic_night_lights or not _is_night or vehicle == null:
		return false
	return (
		lights_when_parked
		or vehicle.has_driver()
		or vehicle.is_managed_traffic()
	)


func _calculate_brakes_enabled() -> bool:
	if vehicle == null:
		return false
	return (
		vehicle.drive_component.service_braking
		or vehicle.tire_component.handbrake_amount > 0.1
	)


func _apply_lighting_state(force := false) -> void:
	var lamps_enabled := _calculate_lamps_enabled()
	var brakes_enabled := _calculate_brakes_enabled()
	var beams_enabled := lamps_enabled and (
		vehicle == null
		or not vehicle.is_managed_traffic()
		or vehicle.is_traffic_detail_enabled()
	)
	if (
		not force
		and _has_applied_state
		and lamps_enabled == _last_lamps_enabled
		and beams_enabled == _last_beams_enabled
		and brakes_enabled == _last_brakes_enabled
	):
		return
	_last_lamps_enabled = lamps_enabled
	_last_beams_enabled = beams_enabled
	_last_brakes_enabled = brakes_enabled
	_has_applied_state = true
	_apply_mesh_materials(
		headlight_mesh_paths,
		headlight_on_material if lamps_enabled else headlight_off_material
	)
	var tail_material := tail_light_off_material
	if brakes_enabled:
		tail_material = tail_light_brake_material
	elif lamps_enabled:
		tail_material = tail_light_on_material
	_apply_mesh_materials(tail_light_mesh_paths, tail_material)
	for path in headlight_beam_paths:
		var beam := get_node_or_null(path) as SpotLight3D
		if beam != null:
			beam.visible = beams_enabled


func _apply_mesh_materials(paths: Array[NodePath], material: Material) -> void:
	if material == null:
		return
	for path in paths:
		var lamp := get_node_or_null(path) as MeshInstance3D
		if lamp != null:
			lamp.material_override = material
