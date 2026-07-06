@tool
extends EditorScenePostImport

const OUTPUT_DIR := "res://Assets/BaseChracters/Player/Meshes/Auto"
const BODY_NAMES := {
	"BODY_Head": true,
	"BODY_Hands": true,
	"BODY_Torso": true,
	"BODY_Legs": true,
	"BODY_Feet": true,
}


func _post_import(scene: Node) -> Object:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIR)
	)
	var extracted := 0
	for mesh_instance in _find_export_meshes(scene):
		var mesh_copy := mesh_instance.mesh.duplicate(true) as ArrayMesh
		if mesh_copy == null:
			push_warning(
				"FB pipeline could not duplicate %s." % mesh_instance.name
			)
			continue
		mesh_copy.resource_name = "MESH_" + mesh_instance.name
		var save_path := "%s/%s.res" % [
			OUTPUT_DIR,
			mesh_instance.name,
		]
		var error := ResourceSaver.save(mesh_copy, save_path)
		if error != OK:
			push_error(
				"FB pipeline could not save %s (error %s)." % [
					mesh_instance.name,
					error,
				]
			)
			continue
		extracted += 1
	print(
		"FB clothing pipeline refreshed %d modular meshes." % extracted
	)
	return scene


func _find_export_meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			if (
				mesh_instance.mesh != null
				and _is_export_name(mesh_instance.name)
			):
				result.append(mesh_instance)
		for child in node.get_children():
			pending.append(child)
	return result


func _is_export_name(node_name: String) -> bool:
	return (
		BODY_NAMES.has(node_name)
		or node_name.begins_with("TOP_")
		or node_name.begins_with("BOTTOM_")
		or node_name.begins_with("SHOES_")
	)
