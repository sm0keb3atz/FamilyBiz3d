extends SceneTree

const BUILDING_SCENES := [
	"res://Scenes/Maps/Buildings/building_1.tscn",
	"res://Scenes/Maps/Buildings/building_2.tscn",
	"res://Scenes/Maps/Buildings/building_3.tscn",
	"res://Scenes/Maps/Buildings/building_4.tscn",
	"res://Scenes/Maps/Buildings/building_5.tscn",
	"res://Scenes/Maps/Buildings/building_6.tscn",
]
const WINDOW_OFF := preload(
	"res://Assets/MapStuff/Textures/Tiled/Game/AssetsvilleTown/Textures/Tiled/WindowOff.tres"
)
const WINDOW_ON := preload(
	"res://Assets/MapStuff/Textures/Tiled/Game/AssetsvilleTown/Textures/Tiled/WindowOn.tres"
)


func _initialize() -> void:
	var world_time := WorldTimeComponent.new()
	root.add_child(world_time)
	assert(world_time.set_time_of_day(8, 0))

	for scene_path in BUILDING_SCENES:
		var packed_scene := load(scene_path) as PackedScene
		assert(packed_scene != null)
		var building := packed_scene.instantiate()
		root.add_child(building)
		await process_frame
		await process_frame

		var component := building.get_node_or_null("BuildingWindowMaterials")
		assert(component != null)
		assert(component.get_script() == load("res://Scripts/World/building_window_material_component.gd"))
		var window_meshes := _find_window_meshes(building)
		assert(not window_meshes.is_empty())
		_assert_window_material(window_meshes, WINDOW_OFF)

		assert(world_time.set_time_of_day(19, 30))
		_assert_mixed_night_materials(window_meshes)

		assert(world_time.set_time_of_day(6, 0))
		_assert_window_material(window_meshes, WINDOW_OFF)
		building.queue_free()
		await process_frame

	await _assert_window_batching(world_time)
	print("BUILDING_WINDOW_MATERIAL_SMOKE_TEST_PASS")
	quit()


func _find_window_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and node.name.to_lower().begins_with("smwindow"):
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		result.append_array(_find_window_meshes(child))
	return result


func _assert_window_material(window_meshes: Array[MeshInstance3D], expected: Material) -> void:
	for window_mesh in window_meshes:
		var surface := 1 if "long" in window_mesh.name.to_lower() else 3
		assert(window_mesh.get_surface_override_material(surface) == expected)


func _assert_mixed_night_materials(window_meshes: Array[MeshInstance3D]) -> void:
	var lit_count := 0
	var unlit_count := 0
	for window_mesh in window_meshes:
		var surface := 1 if "long" in window_mesh.name.to_lower() else 3
		var material := window_mesh.get_surface_override_material(surface)
		assert(material == WINDOW_ON or material == WINDOW_OFF)
		if material == WINDOW_ON:
			lit_count += 1
		else:
			unlit_count += 1
		assert(window_mesh.has_meta(&"fb_window_surface"))
		assert(window_mesh.has_meta(&"fb_window_lit"))
	assert(lit_count > 0)
	assert(unlit_count > 0)


func _assert_window_batching(world_time: WorldTimeComponent) -> void:
	assert(world_time.set_time_of_day(8, 0))
	var batch_root := Node3D.new()
	batch_root.name = "WindowBatchTest"
	var source_paths: Array[NodePath] = []
	for index in 3:
		var building := (
			load(BUILDING_SCENES[0]) as PackedScene
		).instantiate() as Node3D
		building.name = "Building%d" % index
		building.position.x = float(index) * 20.0
		batch_root.add_child(building)
		source_paths.append(NodePath("../%s" % building.name))
	var batcher := StaticMultiMeshBatcher.new()
	batcher.name = "StaticMeshBatches"
	batcher.source_roots = source_paths
	batcher.minimum_instances_per_batch = 1
	batch_root.add_child(batcher)
	root.add_child(batch_root)
	await process_frame
	await process_frame

	assert(batcher.window_batch_count > 0)
	assert(batcher.batched_window_instance_count == 39)
	var source_windows := _find_window_meshes(batch_root)
	assert(source_windows.size() == 39)
	for window_mesh in source_windows:
		assert(not window_mesh.visible)
	_assert_window_batch_materials(batch_root, false)

	assert(world_time.set_time_of_day(19, 30))
	_assert_window_batch_materials(batch_root, true)
	assert(world_time.set_time_of_day(6, 0))
	_assert_window_batch_materials(batch_root, false)
	batch_root.queue_free()
	await process_frame


func _assert_window_batch_materials(node: Node, is_night: bool) -> void:
	if node is MultiMeshInstance3D and node.has_meta(&"fb_window_batch"):
		var batch := node as MultiMeshInstance3D
		var surface := int(batch.get_meta(&"fb_window_surface"))
		var material := batch.multimesh.mesh.surface_get_material(surface)
		var should_be_lit := is_night and bool(batch.get_meta(&"fb_window_lit"))
		assert(material == (WINDOW_ON if should_be_lit else WINDOW_OFF))
	for child in node.get_children():
		_assert_window_batch_materials(child, is_night)
