class_name StaticMultiMeshBatcher
extends Node3D

const EXCLUDE_GROUP := &"exclude_static_batch"
const META_WINDOW_SURFACE := &"fb_window_surface"
const META_WINDOW_LIT := &"fb_window_lit"
const META_WINDOW_OFF_MATERIAL := &"fb_window_off_material"
const META_WINDOW_ON_MATERIAL := &"fb_window_on_material"
const META_WINDOW_BATCH := &"fb_window_batch"

## Batches repeated static map meshes at runtime while keeping the authored
## MeshInstance3D nodes intact and editable in the territory scene.

## Each root is batched separately so large map blocks keep independent bounds
## and can still be culled independently.
@export var source_roots: Array[NodePath] = []
@export_range(2, 100, 1) var minimum_instances_per_batch := 2

var batch_count := 0
var batched_instance_count := 0
var window_batch_count := 0
var batched_window_instance_count := 0
var _window_batches: Array[Dictionary] = []
var _world_time: WorldTimeComponent


func _ready() -> void:
	call_deferred("_initialize_batches")


func _initialize_batches() -> void:
	_build_batches()
	_connect_world_time()


func _exit_tree() -> void:
	if (
		_world_time != null
		and _world_time.night_state_changed.is_connected(_on_night_state_changed)
	):
		_world_time.night_state_changed.disconnect(_on_night_state_changed)


func _build_batches() -> void:
	for root_path in source_roots:
		if root_path.is_empty():
			push_warning(
				"StaticMultiMeshBatcher ignored an empty source root on %s."
				% get_path()
			)
			continue
		var source_root := get_node_or_null(root_path)
		if source_root == null:
			push_warning(
				"StaticMultiMeshBatcher could not find source root %s from %s."
				% [root_path, get_path()]
			)
			continue

		var groups: Dictionary = {}
		_collect_meshes(source_root, groups)
		for group_value in groups.values():
			var meshes := group_value as Array
			if meshes.size() < minimum_instances_per_batch:
				continue
			_create_batch(meshes, source_root)


func _collect_meshes(node: Node, groups: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if _can_batch(mesh_instance):
			var key := _get_batch_key(mesh_instance)
			if not groups.has(key):
				groups[key] = []
			(groups[key] as Array).append(mesh_instance)

	for child in node.get_children():
		_collect_meshes(child, groups)


func _can_batch(mesh_instance: MeshInstance3D) -> bool:
	return (
		mesh_instance.mesh != null
		and mesh_instance.visible
		and mesh_instance.skin == null
		and mesh_instance.skeleton.is_empty()
		and not _has_runtime_visual_ancestor(mesh_instance)
	)


func _has_runtime_visual_ancestor(node: Node) -> bool:
	var current: Node = node
	while current != null:
		# Doors, signs, and other stateful visuals must remain as authored nodes.
		# A MultiMesh copy cannot follow their animation or visibility changes.
		if current.is_in_group(EXCLUDE_GROUP):
			return true
		# A batched copy cannot respond to a signal state change. Keep the pole,
		# lenses, and glow meshes together as normal scene nodes instead.
		if current is TrafficSignalVisual3D:
			return true
		current = current.get_parent()
	return false


func _get_batch_key(mesh_instance: MeshInstance3D) -> String:
	var material_id := 0
	if mesh_instance.material_override != null:
		material_id = mesh_instance.material_override.get_instance_id()
	var key_parts := PackedStringArray([
		str(mesh_instance.mesh.get_instance_id()),
		str(material_id),
		str(mesh_instance.cast_shadow),
		str(mesh_instance.layers),
	])
	for surface_index in mesh_instance.get_surface_override_material_count():
		var surface_material := (
			mesh_instance.get_surface_override_material(surface_index)
		)
		key_parts.append(
			str(surface_material.get_instance_id())
			if surface_material != null
			else "0"
		)
	if mesh_instance.has_meta(META_WINDOW_SURFACE):
		var off_material := mesh_instance.get_meta(
			META_WINDOW_OFF_MATERIAL
		) as Material
		var on_material := mesh_instance.get_meta(
			META_WINDOW_ON_MATERIAL
		) as Material
		key_parts.append("window")
		key_parts.append(str(int(mesh_instance.get_meta(META_WINDOW_SURFACE))))
		key_parts.append("1" if bool(mesh_instance.get_meta(META_WINDOW_LIT)) else "0")
		key_parts.append(str(off_material.get_instance_id()) if off_material != null else "0")
		key_parts.append(str(on_material.get_instance_id()) if on_material != null else "0")
	return ":".join(key_parts)


func _get_batch_mesh(source: MeshInstance3D) -> Mesh:
	var batch_mesh: Mesh = source.mesh
	for surface_index in source.get_surface_override_material_count():
		var surface_material := source.get_surface_override_material(surface_index)
		if surface_material == null:
			continue
		if batch_mesh == source.mesh:
			batch_mesh = source.mesh.duplicate() as Mesh
		batch_mesh.surface_set_material(surface_index, surface_material)
	if source.has_meta(META_WINDOW_SURFACE):
		if batch_mesh == source.mesh:
			batch_mesh = source.mesh.duplicate() as Mesh
		var window_surface := int(source.get_meta(META_WINDOW_SURFACE))
		var off_material := source.get_meta(
			META_WINDOW_OFF_MATERIAL
		) as Material
		if off_material != null and window_surface < batch_mesh.get_surface_count():
			batch_mesh.surface_set_material(window_surface, off_material)
	return batch_mesh


func _create_batch(meshes: Array, source_root: Node) -> void:
	var source := meshes[0] as MeshInstance3D
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = _get_batch_mesh(source)
	multi_mesh.instance_count = meshes.size()

	var batch := MultiMeshInstance3D.new()
	batch.name = "Batch_%03d_%s_%s" % [
		batch_count + 1,
		source_root.name,
		source.name,
	]
	batch.multimesh = multi_mesh
	batch.material_override = source.material_override
	batch.cast_shadow = source.cast_shadow
	batch.layers = source.layers
	source_root.add_child(batch)
	if source.has_meta(META_WINDOW_SURFACE):
		var window_surface := int(source.get_meta(META_WINDOW_SURFACE))
		var is_lit_pattern := bool(source.get_meta(META_WINDOW_LIT))
		var off_material := source.get_meta(
			META_WINDOW_OFF_MATERIAL
		) as Material
		var on_material := source.get_meta(
			META_WINDOW_ON_MATERIAL
		) as Material
		batch.set_meta(META_WINDOW_BATCH, true)
		batch.set_meta(META_WINDOW_SURFACE, window_surface)
		batch.set_meta(META_WINDOW_LIT, is_lit_pattern)
		_window_batches.append({
			"batch": batch,
			"mesh": multi_mesh.mesh,
			"surface": window_surface,
			"lit": is_lit_pattern,
			"off_material": off_material,
			"on_material": on_material,
		})
		window_batch_count += 1
		batched_window_instance_count += meshes.size()

	var inverse_batch_transform := batch.global_transform.affine_inverse()
	for index in meshes.size():
		var mesh_instance := meshes[index] as MeshInstance3D
		multi_mesh.set_instance_transform(
			index,
			inverse_batch_transform * mesh_instance.global_transform
		)
		mesh_instance.visible = false

	batch_count += 1
	batched_instance_count += meshes.size()


func _connect_world_time() -> void:
	_world_time = get_tree().get_first_node_in_group(
		&"world_time"
	) as WorldTimeComponent
	if _world_time == null:
		_apply_window_batch_materials(false)
		return
	if not _world_time.night_state_changed.is_connected(_on_night_state_changed):
		_world_time.night_state_changed.connect(_on_night_state_changed)
	_apply_window_batch_materials(_world_time.is_nighttime())


func _on_night_state_changed(is_night: bool) -> void:
	_apply_window_batch_materials(is_night)


func _apply_window_batch_materials(is_night: bool) -> void:
	for entry in _window_batches:
		var mesh := entry["mesh"] as Mesh
		var batch := entry["batch"] as MultiMeshInstance3D
		if mesh == null or batch == null:
			continue
		var material := entry["off_material"] as Material
		if is_night and bool(entry["lit"]):
			material = entry["on_material"] as Material
		var surface := int(entry["surface"])
		if material == null or surface >= mesh.get_surface_count():
			continue
		if mesh.surface_get_material(surface) != material:
			mesh.surface_set_material(surface, material)
			batch.multimesh.mesh = mesh
