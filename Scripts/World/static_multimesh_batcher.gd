class_name StaticMultiMeshBatcher
extends Node3D

## Batches repeated static map meshes at runtime while keeping the authored
## MeshInstance3D nodes intact and editable in the territory scene.

## Each root is batched separately so large map blocks keep independent bounds
## and can still be culled independently.
@export var source_roots: Array[NodePath] = []
@export_range(2, 100, 1) var minimum_instances_per_batch := 2

var batch_count := 0
var batched_instance_count := 0


func _ready() -> void:
	_build_batches()


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
	)


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
