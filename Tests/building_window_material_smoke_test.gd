extends SceneTree

const BUILDING_SCENES := [
	"res://Scenes/Maps/Buildings/building_1.tscn",
	"res://Scenes/Maps/Buildings/building_2.tscn",
	"res://Scenes/Maps/Buildings/building_3.tscn",
	"res://Scenes/Maps/Buildings/building_4.tscn",
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
		assert(window_mesh.is_in_group(&"exclude_static_batch"))
	assert(lit_count > 0)
	assert(unlit_count > 0)
