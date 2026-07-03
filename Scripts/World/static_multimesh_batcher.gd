class_name StaticMultiMeshBatcher
extends Node3D

## Batches repeated static map meshes at runtime while keeping the authored
## MeshInstance3D nodes intact and editable in the territory scene.

@export var source_roots: Array[NodePath] = [
	NodePath("../Roads"),
	NodePath("../Sidewalk"),
	NodePath("../Ground"),
]
@export_range(2, 100, 1) var minimum_instances_per_batch := 2

var batch_count := 0
var batched_instance_count := 0


func _ready() -> void:
	_build_batches()


func _build_batches() -> void:
	var groups: Dictionary = {}
	for root_path in source_roots:
		var source_root := get_node_or_null(root_path)
		if source_root != null:
			_collect_meshes(source_root, groups)

	for group_value in groups.values():
		var meshes := group_value as Array
		if meshes.size() < minimum_instances_per_batch:
			continue
		_create_batch(meshes)


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
	return "%d:%d:%d:%d" % [
		mesh_instance.mesh.get_instance_id(),
		material_id,
		mesh_instance.cast_shadow,
		mesh_instance.layers,
	]


func _create_batch(meshes: Array) -> void:
	var source := meshes[0] as MeshInstance3D
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = source.mesh
	multi_mesh.instance_count = meshes.size()

	var batch := MultiMeshInstance3D.new()
	batch.name = "Batch_%03d_%s" % [batch_count + 1, source.name]
	batch.multimesh = multi_mesh
	batch.material_override = source.material_override
	batch.cast_shadow = source.cast_shadow
	batch.layers = source.layers
	add_child(batch)

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
