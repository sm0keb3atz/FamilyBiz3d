extends SceneTree

const GENERATOR_SCENE := preload(
	"res://Scenes/Maps/Buildings/BuildingGeneratorTemplate.tscn"
)
const WINDOW_OFF := preload(
	"res://Assets/MapStuff/Textures/Tiled/Game/AssetsvilleTown/Textures/Tiled/WindowOff.tres"
)
const WINDOW_ON := preload(
	"res://Assets/MapStuff/Textures/Tiled/Game/AssetsvilleTown/Textures/Tiled/WindowOn.tres"
)
const REFERENCE_SCENES := [
	"res://Scenes/Maps/Buildings/building_2.tscn",
	"res://Scenes/Maps/Buildings/building_3.tscn",
	"res://Scenes/Maps/Buildings/building_4.tscn",
	"res://Scenes/Maps/Buildings/building_5.tscn",
	"res://Scenes/Maps/Buildings/building_6.tscn",
	"res://Scenes/Maps/Territorys/Blocks/hood_east_block_2.tscn",
	"res://Scenes/Maps/Territorys/Blocks/downtown_east_block_1.tscn",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for scene_path in REFERENCE_SCENES:
		assert(load(scene_path) is PackedScene)
	_assert_catalog_spans()

	var world_time := WorldTimeComponent.new()
	root.add_child(world_time)
	assert(world_time.set_time_of_day(8, 0))

	var low_rise := _create_generator(
		"LowRise",
		2,
		2,
		2,
		BuildingGenerationProfile.Preset.BRICK_RETAIL,
		101
	)
	_assert_valid_shell(low_rise)

	var mid_rise := _create_generator(
		"MidRise",
		4,
		3,
		5,
		BuildingGenerationProfile.Preset.CLASSIC_MIXED_USE,
		202
	)
	_assert_valid_shell(mid_rise)
	_assert_classic_window_families(mid_rise)

	var high_rise := _create_generator(
		"HighRise",
		4,
		3,
		11,
		BuildingGenerationProfile.Preset.OFFICE_HIGH_RISE,
		303
	)
	_assert_valid_shell(high_rise)

	_assert_deterministic_generation(mid_rise)
	_assert_manual_details_survive(mid_rise)
	_assert_materials_are_building_local(low_rise, mid_rise)
	await _assert_window_lighting_and_batching(mid_rise, world_time)
	_assert_bake()

	print("BUILDING_GENERATOR_SMOKE_TEST_PASS")
	quit()


func _create_generator(
	building_name: String,
	width_modules: int,
	depth_modules: int,
	stories: int,
	preset: int,
	seed_value: int
) -> BuildingGenerator3D:
	var generator := GENERATOR_SCENE.instantiate() as BuildingGenerator3D
	assert(generator != null)
	generator.name = building_name
	root.add_child(generator)
	assert(generator.profile != null)
	generator.profile.width_modules = width_modules
	generator.profile.depth_modules = depth_modules
	generator.profile.story_count = stories
	generator.profile.preset = preset
	generator.profile.material_palette = (
		BuildingGenerationProfile.MaterialPalette.WHITE_BRICK
	)
	generator.profile.prop_density = BuildingGenerationProfile.PropDensity.MEDIUM
	generator.profile.seed = seed_value
	generator.generate()
	return generator


func _assert_valid_shell(generator: BuildingGenerator3D) -> void:
	var generated := generator.get_node("Generated")
	assert(bool(generated.get_meta(&"building_generator_complete")))
	var width: int = generator.profile.width_modules
	var depth: int = generator.profile.depth_modules
	var stories: int = generator.profile.story_count

	var counts := {
		"entrance": 0,
		"corner": 0,
		"attic_corner": 0,
		"floor": 0,
		"roof": 0,
	}
	var coverage: Dictionary = {}
	var windows: Array[MeshInstance3D] = []
	_collect_generated_facts(generated, coverage, windows, counts)

	assert(int(counts["entrance"]) == 1)
	assert(
		int(counts["corner"]) + int(counts["attic_corner"])
		== (stories + 1) * 4
	)
	assert(int(counts["floor"]) == width * depth)
	assert(int(counts["roof"]) == width * depth)
	assert(not windows.is_empty())
	for window in windows:
		assert(window.has_meta(&"fb_window_surface"))
		var surface := int(window.get_meta(&"fb_window_surface"))
		assert(surface >= 0 and surface < window.mesh.get_surface_count())

	for story_index in stories + 1:
		for side in 4:
			var key := "%d:%s" % [story_index, _side_name(side)]
			var expected := depth * 2 if side == 0 or side == 2 else width * 2
			assert(int(coverage.get(key, 0)) == expected)
	_assert_perimeter_anchors(generated, width, depth, stories)
	_assert_roof_attachment(generated, stories)
	_assert_roof_trim_materials(generated)

	var collision := generated.get_node(
		"StaticBody3D/CollisionShape3D"
	) as CollisionShape3D
	assert(collision != null)
	var shape := collision.shape as BoxShape3D
	assert(shape != null)
	var expected_height := float(stories) * BuildingGenerator3D.STORY_HEIGHT
	assert(shape.size.is_equal_approx(Vector3(
		float(width) * BuildingGenerator3D.MODULE_SIZE + BuildingGenerator3D.COLLISION_MARGIN.x,
		expected_height,
		float(depth) * BuildingGenerator3D.MODULE_SIZE + BuildingGenerator3D.COLLISION_MARGIN.y
	)))
	assert(is_equal_approx(collision.position.y, expected_height * 0.5))
	assert(generated.get_node_or_null("BuildingWindowMaterials") != null)


func _assert_catalog_spans() -> void:
	for style_path in BuildingGenerator3D.VERIFIED_STYLE_PATHS:
		var style := load(style_path) as BuildingStyleProfile
		assert(style != null)
		var tiles: Array[BuildingTileDefinition] = []
		tiles.append_array(style.regular_facades())
		tiles.append_array(style.ground_facades())
		tiles.append_array(style.entrances())
		if style.attic_wall != null:
			tiles.append(style.attic_wall)
		for tile in tiles:
			assert(tile.mesh != null)
			var measured_cells := maxi(
				1,
				roundi(tile.mesh.get_aabb().size.z / BuildingGenerator3D.FACADE_CELL_SIZE)
			)
			assert(tile.facade_cells == measured_cells)


func _assert_classic_window_families(generator: BuildingGenerator3D) -> void:
	var checked := 0
	var pending: Array[Node] = [generator.get_node("Generated/Walls")]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		if String(node.get_meta(&"building_generator_kind", "")) != "facade":
			continue
		var source := String(node.get_meta(&"building_generator_source", ""))
		var side := String(node.get_meta(&"building_generator_side", ""))
		if source.ends_with("SM_window_01.glb"):
			assert(side == "front" or side == "back")
			checked += 1
		elif source.ends_with("SM_window_02_long.glb"):
			assert(side == "front")
			checked += 1
		elif source.ends_with("SM_window_03.glb"):
			assert(side == "right" or side == "left")
			checked += 1
	assert(checked > 0)


func _assert_roof_attachment(generated: Node, stories: int) -> void:
	var roof_y := float(stories) * BuildingGenerator3D.STORY_HEIGHT
	var top_story := generated.get_node(
		"Walls/Story%02d" % stories
	) as Node3D
	assert(top_story != null)
	var checked_top := false
	for child in top_story.get_children():
		if not child is MeshInstance3D:
			continue
		if String(child.get_meta(&"building_generator_kind", "")) != "facade":
			continue
		var mesh_instance := child as MeshInstance3D
		var wall_top := (
			top_story.position.y
			+ mesh_instance.position.y
			+ mesh_instance.mesh.get_aabb().end.y
		)
		assert(is_equal_approx(wall_top, roof_y))
		checked_top = true
	assert(checked_top)
	var attic_cap := generated.get_node("Walls/AtticCap") as Node3D
	assert(attic_cap != null)
	assert(is_equal_approx(attic_cap.position.y, roof_y))
	for roof_tile in generated.get_node("Roof").get_children():
		if String(roof_tile.get_meta(&"building_generator_kind", "")) == "roof":
			assert(is_equal_approx((roof_tile as Node3D).position.y, roof_y))


func _assert_roof_trim_materials(generated: Node) -> void:
	var checked := 0
	for child in generated.get_node("Roof").get_children():
		var kind := String(child.get_meta(&"building_generator_kind", ""))
		if kind != "cornice" and kind != "cornice_corner":
			continue
		assert(child is MeshInstance3D)
		var cornice := child as MeshInstance3D
		assert(cornice.get_surface_override_material(0) == null)
		checked += 1
	assert(checked > 0)


func _assert_perimeter_anchors(
	generated: Node,
	width_modules: int,
	depth_modules: int,
	stories: int
) -> void:
	var half_width := float(width_modules) * BuildingGenerator3D.MODULE_SIZE * 0.5
	var half_depth := float(depth_modules) * BuildingGenerator3D.MODULE_SIZE * 0.5
	var cornice_count := 0
	var perimeter_tiles: Array[Node3D] = []
	_collect_perimeter_tiles(generated, perimeter_tiles)
	for tile in perimeter_tiles:
		var kind := String(tile.get_meta(&"building_generator_kind"))
		if kind == "cornice":
			cornice_count += 1
		var side := String(tile.get_meta(&"building_generator_side"))
		match side:
			"front":
				assert(is_equal_approx(tile.position.x, half_width))
				assert(tile.position.z <= half_depth + 0.01)
				assert(tile.position.z >= -half_depth - 0.01)
				assert(is_equal_approx(tile.rotation_degrees.y, 0.0))
			"right":
				assert(is_equal_approx(tile.position.z, -half_depth))
				assert(tile.position.x <= half_width + 0.01)
				assert(tile.position.x >= -half_width - 0.01)
				assert(is_equal_approx(tile.rotation_degrees.y, 90.0))
			"back":
				assert(is_equal_approx(tile.position.x, -half_width))
				assert(tile.position.z <= half_depth + 0.01)
				assert(tile.position.z >= -half_depth - 0.01)
				assert(absf(absf(tile.rotation_degrees.y) - 180.0) < 0.01)
			"left":
				assert(is_equal_approx(tile.position.z, half_depth))
				assert(tile.position.x <= half_width + 0.01)
				assert(tile.position.x >= -half_width - 0.01)
				assert(is_equal_approx(tile.rotation_degrees.y, -90.0))

	var expected_cornices := 2 * (
		ceili(float(depth_modules) / 2.0)
		+ ceili(float(width_modules) / 2.0)
	)
	assert(cornice_count == expected_cornices)
	assert(stories >= 2)


func _collect_perimeter_tiles(node: Node, result: Array[Node3D]) -> void:
	if node is Node3D and node.has_meta(&"building_generator_kind"):
		var kind := String(node.get_meta(&"building_generator_kind"))
		if kind == "facade" or kind == "attic" or kind == "entrance" or kind == "cornice":
			result.append(node as Node3D)
	for child in node.get_children():
		_collect_perimeter_tiles(child, result)


func _collect_generated_facts(
	node: Node,
	coverage: Dictionary,
	windows: Array[MeshInstance3D],
	counts: Dictionary
) -> void:
	if node.has_meta(&"building_generator_kind"):
		var kind := String(node.get_meta(&"building_generator_kind"))
		if counts.has(kind):
			counts[kind] = int(counts[kind]) + 1
		if kind == "facade" or kind == "attic" or kind == "entrance":
			var key := "%d:%s" % [
				int(node.get_meta(&"building_generator_story")),
				String(node.get_meta(&"building_generator_side")),
			]
			coverage[key] = int(coverage.get(key, 0)) + int(
				node.get_meta(&"building_generator_cell_span")
			)
	if node is MeshInstance3D and node.name.to_lower().begins_with("smwindow"):
		windows.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_generated_facts(child, coverage, windows, counts)


func _assert_deterministic_generation(generator: BuildingGenerator3D) -> void:
	var original_signature := _generation_signature(generator.get_node("Generated"))
	generator.regenerate()
	assert(_generation_signature(generator.get_node("Generated")) == original_signature)

	generator.profile.seed += 1
	generator.regenerate()
	assert(_generation_signature(generator.get_node("Generated")) != original_signature)


func _generation_signature(node: Node) -> String:
	var entries := PackedStringArray()
	_collect_signature(node, entries)
	entries.sort()
	return "\n".join(entries)


func _collect_signature(node: Node, entries: PackedStringArray) -> void:
	if node.has_meta(&"building_generator_source") and node is Node3D:
		var node_3d := node as Node3D
		entries.append("%s|%s|%s|%s" % [
			String(node.get_meta(&"building_generator_source")),
			str(node_3d.position),
			str(node_3d.rotation),
			String(node.get_meta(&"building_generator_kind")),
		])
	for child in node.get_children():
		_collect_signature(child, entries)


func _assert_manual_details_survive(generator: BuildingGenerator3D) -> void:
	var manual_details := generator.get_node("ManualDetails")
	var marker := Marker3D.new()
	marker.name = "HandAuthoredSignAnchor"
	manual_details.add_child(marker)
	generator.regenerate()
	assert(generator.get_node_or_null("ManualDetails/HandAuthoredSignAnchor") == marker)


func _assert_materials_are_building_local(
	first: BuildingGenerator3D,
	second: BuildingGenerator3D
) -> void:
	var first_material := _find_facade_material(first.get_node("Generated"))
	var second_material := _find_facade_material(second.get_node("Generated"))
	assert(first_material != null)
	assert(second_material != null)
	assert(first_material != second_material)
	assert(first_material.resource_local_to_scene)
	assert(second_material.resource_local_to_scene)


func _find_facade_material(node: Node) -> Material:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var material := mesh_instance.get_surface_override_material(0)
		if material is StandardMaterial3D and material != WINDOW_OFF and material != WINDOW_ON:
			return material
	for child in node.get_children():
		var found := _find_facade_material(child)
		if found != null:
			return found
	return null


func _assert_window_lighting_and_batching(
	generator: BuildingGenerator3D,
	world_time: WorldTimeComponent
) -> void:
	await process_frame
	await process_frame
	var windows := _find_windows(generator.get_node("Generated"))
	assert(not windows.is_empty())
	_assert_all_windows_off(windows)
	assert(world_time.set_time_of_day(19, 30))
	var lit_count := 0
	var unlit_count := 0
	for window in windows:
		var surface := int(window.get_meta(&"fb_window_surface"))
		var material := window.get_surface_override_material(surface)
		assert(material == WINDOW_ON or material == WINDOW_OFF)
		if material == WINDOW_ON:
			lit_count += 1
		else:
			unlit_count += 1
	assert(lit_count > 0 and unlit_count > 0)

	var batcher := StaticMultiMeshBatcher.new()
	batcher.source_roots = [NodePath("../Generated")]
	batcher.minimum_instances_per_batch = 2
	generator.add_child(batcher)
	await process_frame
	await process_frame
	assert(batcher.window_batch_count > 0)
	assert(batcher.batched_window_instance_count > 0)
	assert(world_time.set_time_of_day(8, 0))


func _find_windows(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and node.name.to_lower().begins_with("smwindow"):
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		result.append_array(_find_windows(child))
	return result


func _assert_all_windows_off(windows: Array[MeshInstance3D]) -> void:
	for window in windows:
		var surface := int(window.get_meta(&"fb_window_surface"))
		assert(window.get_surface_override_material(surface) == WINDOW_OFF)


func _assert_bake() -> void:
	var generator := _create_generator(
		"BakeCandidate",
		3,
		2,
		3,
		BuildingGenerationProfile.Preset.BRICK_RETAIL,
		404
	)
	generator.bake()
	assert(generator.get_script() == null)
	assert(generator.get_node_or_null("Generated") != null)
	assert(generator.get_node_or_null("ManualDetails") != null)


func _side_name(side: int) -> String:
	return ["front", "right", "back", "left"][side]
