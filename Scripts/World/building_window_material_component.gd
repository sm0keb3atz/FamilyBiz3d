class_name BuildingWindowMaterialComponent
extends Node

const META_WINDOW_SURFACE := &"fb_window_surface"
const META_WINDOW_LIT := &"fb_window_lit"
const META_WINDOW_OFF_MATERIAL := &"fb_window_off_material"
const META_WINDOW_ON_MATERIAL := &"fb_window_on_material"

@export var window_off_material: Material
@export var window_on_material: Material
@export var windows_root: Node
@export var window_name_prefix := "SmWindow"
@export_range(0, 32, 1) var regular_window_surface := 3
@export_range(0, 32, 1) var long_window_surface := 1
@export_range(0.0, 1.0, 0.05) var lit_window_ratio := 0.55
@export_range(0.0, 0.45, 0.05) var ratio_variation_per_building := 0.15

var _world_time: WorldTimeComponent
var _window_surfaces: Array[Dictionary] = []
var _last_applied_night_state := -1


func _ready() -> void:
	_cache_window_surfaces()
	_apply_window_material(false)
	call_deferred("_connect_world_time")


func _exit_tree() -> void:
	if (
		_world_time != null
		and _world_time.night_state_changed.is_connected(_on_night_state_changed)
	):
		_world_time.night_state_changed.disconnect(_on_night_state_changed)


func _cache_window_surfaces() -> void:
	_window_surfaces.clear()
	var search_root := windows_root
	if search_root == null:
		search_root = get_parent()
	if search_root == null:
		push_warning("BuildingWindowMaterialComponent has no building root to search.")
		return
	_collect_window_surfaces(search_root)
	if _window_surfaces.is_empty():
		push_warning("BuildingWindowMaterialComponent found no window meshes under %s." % search_root.get_path())
		return
	_assign_lit_window_pattern(search_root)


func _collect_window_surfaces(node: Node) -> void:
	if node is MeshInstance3D and node.name.to_lower().begins_with(window_name_prefix.to_lower()):
		var window_mesh := node as MeshInstance3D
		var surface_index := (
			int(window_mesh.get_meta(META_WINDOW_SURFACE))
			if window_mesh.has_meta(META_WINDOW_SURFACE)
			else (
				long_window_surface
				if "long" in window_mesh.name.to_lower()
				else regular_window_surface
			)
		)
		if window_mesh.mesh != null and surface_index < window_mesh.mesh.get_surface_count():
			_window_surfaces.append({
				"mesh": window_mesh,
				"surface": surface_index,
				"lit": false,
			})
		else:
			push_warning("%s does not have window material surface %d." % [window_mesh.get_path(), surface_index])
	for child in node.get_children():
		_collect_window_surfaces(child)


func _assign_lit_window_pattern(search_root: Node) -> void:
	var random := RandomNumberGenerator.new()
	var building_position := Vector3.ZERO
	if search_root is Node3D:
		building_position = (search_root as Node3D).global_position
	random.seed = hash("%s|%s" % [search_root.get_path(), building_position])

	var building_ratio := clampf(
		lit_window_ratio + random.randf_range(
			-ratio_variation_per_building,
			ratio_variation_per_building
		),
		0.0,
		1.0
	)
	var lit_count := roundi(float(_window_surfaces.size()) * building_ratio)
	if _window_surfaces.size() > 1:
		lit_count = clampi(lit_count, 1, _window_surfaces.size() - 1)
	else:
		lit_count = clampi(lit_count, 0, 1)

	var shuffled_indices := range(_window_surfaces.size())
	for index in range(shuffled_indices.size() - 1, 0, -1):
		var swap_index := random.randi_range(0, index)
		var held_index: int = shuffled_indices[index]
		shuffled_indices[index] = shuffled_indices[swap_index]
		shuffled_indices[swap_index] = held_index
	for index in lit_count:
		_window_surfaces[shuffled_indices[index]]["lit"] = true
	for entry in _window_surfaces:
		var window_mesh := entry["mesh"] as MeshInstance3D
		window_mesh.set_meta(META_WINDOW_SURFACE, int(entry["surface"]))
		window_mesh.set_meta(META_WINDOW_LIT, bool(entry["lit"]))
		window_mesh.set_meta(META_WINDOW_OFF_MATERIAL, window_off_material)
		window_mesh.set_meta(META_WINDOW_ON_MATERIAL, window_on_material)


func _connect_world_time() -> void:
	_world_time = get_tree().get_first_node_in_group(&"world_time") as WorldTimeComponent
	if _world_time == null:
		push_warning("BuildingWindowMaterialComponent could not find the WorldTimeComponent.")
		_apply_window_material(false)
		return
	if not _world_time.night_state_changed.is_connected(_on_night_state_changed):
		_world_time.night_state_changed.connect(_on_night_state_changed)
	_apply_window_material(_world_time.is_nighttime())


func _on_night_state_changed(is_night: bool) -> void:
	_apply_window_material(is_night)


func _apply_window_material(turn_on: bool) -> void:
	var night_state := 1 if turn_on else 0
	if _last_applied_night_state == night_state:
		return
	_last_applied_night_state = night_state
	if window_off_material == null or window_on_material == null:
		push_warning("BuildingWindowMaterialComponent is missing an on/off window material.")
		return
	for entry in _window_surfaces:
		var window_mesh := entry["mesh"] as MeshInstance3D
		var use_lit_material := turn_on and bool(entry["lit"])
		var material := window_on_material if use_lit_material else window_off_material
		window_mesh.set_surface_override_material(int(entry["surface"]), material)
