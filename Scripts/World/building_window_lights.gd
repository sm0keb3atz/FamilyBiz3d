class_name BuildingWindowLights
extends Node3D

@export_range(0.0, 1.0, 0.05) var lit_window_ratio := 0.5
@export var window_light_color := Color(1.0, 0.58, 0.26)
@export_range(0.0, 4.0, 0.05) var window_light_energy := 0.65
@export_range(0.5, 10.0, 0.1) var window_light_range := 2.8

var _world_time: WorldTimeComponent


func _ready() -> void:
	visible = false
	_configure_windows()
	call_deferred("_connect_world_time")


func _configure_windows() -> void:
	var window_panels: Array[MeshInstance3D] = []
	for child in get_children():
		if child is MeshInstance3D:
			window_panels.append(child as MeshInstance3D)
	if window_panels.is_empty():
		return

	var random := RandomNumberGenerator.new()
	var building_path := str(get_parent().get_path()) if get_parent() != null else str(get_path())
	random.seed = hash("%s|%s" % [building_path, global_position])
	var lit_count := 0
	for panel in window_panels:
		var is_lit := random.randf() < lit_window_ratio
		panel.visible = is_lit
		if is_lit:
			lit_count += 1
			_add_area_light(panel)

	if lit_count == 0:
		var fallback := window_panels[random.randi_range(0, window_panels.size() - 1)]
		fallback.visible = true
		_add_area_light(fallback)


func _add_area_light(panel: MeshInstance3D) -> void:
	var area_light := AreaLight3D.new()
	area_light.name = "WindowAreaLight"
	area_light.rotation_degrees.y = 180.0
	area_light.position.z = 0.04
	area_light.light_color = window_light_color
	area_light.light_energy = window_light_energy
	area_light.light_indirect_energy = 0.5
	area_light.light_specular = 0.2
	area_light.shadow_enabled = false
	area_light.area_range = window_light_range
	area_light.area_attenuation = 1.6
	area_light.area_normalize_energy = true
	var panel_scale := panel.transform.basis.get_scale()
	var panel_size := Vector2(panel_scale.x, panel_scale.y)
	var quad := panel.mesh as QuadMesh
	if quad != null:
		panel_size *= quad.size
	area_light.area_size = panel_size
	area_light.distance_fade_enabled = true
	area_light.distance_fade_begin = 22.0
	area_light.distance_fade_length = 10.0
	panel.add_child(area_light)


func _connect_world_time() -> void:
	_world_time = get_tree().get_first_node_in_group(&"world_time") as WorldTimeComponent
	if _world_time == null:
		push_warning("BuildingWindowLights could not find the WorldTimeComponent.")
		return
	if not _world_time.time_changed.is_connected(_on_time_changed):
		_world_time.time_changed.connect(_on_time_changed)
	_update_visibility()


func _on_time_changed(_date_text: String, _time_text: String) -> void:
	_update_visibility()


func _update_visibility() -> void:
	if _world_time != null:
		visible = _world_time.is_nighttime()
