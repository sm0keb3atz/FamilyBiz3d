extends SceneTree

const IslandBoundaryScene := preload(
	"res://Scenes/Maps/World/IslandBoundary.tscn"
)
const SurfaceStylerScript := preload(
	"res://Scripts/World/world_surface_styler.gd"
)
const WaterMaterial := preload(
	"res://Assets/VFX/Shaders/stylized_island_water.tres"
)
const VegetationWindShader := preload(
	"res://Assets/VFX/Shaders/vegetation_wind.gdshader"
)

const EXPANSION_EDGE_X := 256.0
const WATER_LEVEL_Y := -3.5


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	stage.name = "IslandBoundaryStage"
	root.add_child(stage)

	var boundary := IslandBoundaryScene.instantiate() as Node3D
	assert(boundary != null)
	stage.add_child(boundary)

	_assert_scene_contract(boundary)
	_assert_water(boundary)
	_assert_closed_edges(boundary)
	_assert_east_expansion_seam(boundary)
	_assert_vegetation_wind(boundary)

	var styler := SurfaceStylerScript.new() as WorldSurfaceStyler
	styler.name = "WorldSurfaceStyler"
	styler.source_roots = [NodePath("../IslandBoundary/Shore")]
	stage.add_child(styler)
	assert(styler.styled_mesh_count > 0)
	assert(
		boundary.get_node(
			"Shore/North/GroundTiles/DirtEdge01"
		).get_surface_override_material(0) is ShaderMaterial
	)

	await process_frame
	await process_frame
	var batcher := boundary.get_node("StaticMeshBatches") as StaticMultiMeshBatcher
	assert(batcher != null)
	assert(batcher.batch_count >= 6)
	assert(batcher.batched_instance_count >= 20)

	var world_scene := load("res://Scenes/Maps/World/world.tscn") as PackedScene
	assert(world_scene != null)

	stage.queue_free()
	await process_frame
	print("ISLAND_BOUNDARY_SMOKE_TEST_PASS")
	quit(0)


func _assert_scene_contract(boundary: Node3D) -> void:
	assert(boundary.has_node("Water"))
	assert(boundary.has_node("Shore"))
	assert(boundary.has_node("Backdrop"))
	assert(boundary.has_node("Collision"))
	assert(boundary.has_node("Shore/North"))
	assert(boundary.has_node("Shore/West"))
	assert(boundary.has_node("Shore/South"))
	assert(not boundary.has_node("Shore/East"))


func _assert_water(boundary: Node3D) -> void:
	var water_nodes := boundary.get_tree().get_nodes_in_group(
		"island_boundary_water"
	)
	assert(water_nodes.size() == 3)
	for water_value in water_nodes:
		var water := water_value as MeshInstance3D
		assert(water != null)
		assert(is_equal_approx(water.position.y, WATER_LEVEL_Y))
		assert(water.material_override == WaterMaterial)
		assert(water.mesh is PlaneMesh)

	var shader_material := WaterMaterial as ShaderMaterial
	assert(shader_material != null)
	assert(shader_material.shader != null)
	assert("INV_PROJECTION_MATRIX" in shader_material.shader.code)
	assert("legacy near/far" in shader_material.shader.code)
	assert(shader_material.get_shader_parameter("noise_texture_a") != null)
	assert(shader_material.get_shader_parameter("noise_texture_b") != null)
	assert(shader_material.get_shader_parameter("wave_texture") != null)
	assert(shader_material.get_shader_parameter("normal_texture") != null)
	assert(is_equal_approx(
		float(shader_material.get_shader_parameter("wave_height")),
		0.18
	))


func _assert_closed_edges(boundary: Node3D) -> void:
	var collision_root := boundary.get_node("Collision")
	assert(collision_root.get_child_count() == 3)
	for blocker_name in ["NorthBarrier", "WestBarrier", "SouthBarrier"]:
		var blocker := collision_root.get_node(blocker_name) as StaticBody3D
		assert(blocker != null)
		assert(blocker.is_in_group("island_boundary_blocker"))
		var shape := blocker.get_node("CollisionShape3D") as CollisionShape3D
		assert(shape != null and shape.shape is BoxShape3D)


func _assert_east_expansion_seam(boundary: Node3D) -> void:
	assert(not boundary.has_node("Water/EastWater"))
	assert(not boundary.has_node("Collision/EastBarrier"))
	for water_name in ["NorthWater", "SouthWater"]:
		var water := boundary.get_node("Water/%s" % water_name) as MeshInstance3D
		var plane := water.mesh as PlaneMesh
		var maximum_x := water.position.x + plane.size.x * 0.5
		assert(maximum_x <= EXPANSION_EDGE_X + 0.01)

	for shore_name in ["North", "South"]:
		var wall := boundary.get_node(
			"Shore/%s/RetainingWall" % shore_name
		) as MeshInstance3D
		var box := wall.mesh as BoxMesh
		var maximum_x := wall.position.x + box.size.x * 0.5
		assert(maximum_x <= EXPANSION_EDGE_X + 0.01)


func _assert_vegetation_wind(boundary: Node3D) -> void:
	var wind := boundary.get_node("VegetationWind") as IslandVegetationWind
	assert(wind != null)
	assert(wind.tree_count > 0)
	assert(wind.bush_count > 0)

	var tree_one := boundary.get_node(
		"Shore/North/Vegetation/Tree01"
	) as Node3D
	var tree_two := boundary.get_node(
		"Shore/North/Vegetation/Tree02"
	) as Node3D
	assert(not is_equal_approx(tree_one.scale.y, tree_one.scale.x))
	assert(not is_equal_approx(tree_one.scale.y, tree_two.scale.y))

	var tree_mesh := _find_first_mesh(tree_one)
	assert(tree_mesh != null)
	var wind_material := tree_mesh.get_surface_override_material(0) as ShaderMaterial
	assert(wind_material != null)
	assert(wind_material.shader == VegetationWindShader)
	wind.set_weather_wind_intensity(0.72)
	assert(is_equal_approx(wind.current_weather_wind_multiplier, 2.65))
	assert(is_equal_approx(wind.current_weather_speed_multiplier, 1.35))
	assert(is_equal_approx(wind.current_weather_gustiness, 1.0))
	assert(is_equal_approx(
		float(wind_material.get_shader_parameter("weather_wind_multiplier")),
		2.65
	))


func _find_first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh(child)
		if found != null:
			return found
	return null
