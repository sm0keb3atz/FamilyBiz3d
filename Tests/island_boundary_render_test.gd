extends SceneTree

const IslandBoundaryScene := preload(
	"res://Scenes/Maps/World/IslandBoundary.tscn"
)
const SurfaceStylerScript := preload(
	"res://Scripts/World/world_surface_styler.gd"
)
const HoodEastScene := preload(
	"res://Scenes/Maps/Territorys/HoodEast.tscn"
)
const HoodWestScene := preload(
	"res://Scenes/Maps/Territorys/HoodWest.tscn"
)
const DowntownEastScene := preload(
	"res://Scenes/Maps/Territorys/downtown_east.tscn"
)
const DowntownWestScene := preload(
	"res://Scenes/Maps/Territorys/down_town_west.tscn"
)

var _camera: Camera3D
var _environment: Environment
var _sun: DirectionalLight3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var stage := Node3D.new()
	stage.name = "IslandBoundaryRenderStage"
	root.add_child(stage)

	var world_environment := WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.50, 0.58, 0.66)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.55, 0.62, 0.70)
	_environment.ambient_light_energy = 0.7
	_environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	_environment.fog_enabled = true
	_environment.fog_light_color = Color(0.56, 0.65, 0.73)
	_environment.fog_density = 0.00125
	_environment.fog_aerial_perspective = 0.42
	world_environment.environment = _environment
	stage.add_child(world_environment)

	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.rotation_degrees = Vector3(-48, -28, 0)
	_sun.light_color = Color(1.0, 0.77, 0.57)
	_sun.light_energy = 1.35
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 110.0
	stage.add_child(_sun)

	var territories := Node3D.new()
	territories.name = "Territories"
	stage.add_child(territories)
	var hood_east := HoodEastScene.instantiate() as Node3D
	territories.add_child(hood_east)
	var hood_west := HoodWestScene.instantiate() as Node3D
	hood_west.position = Vector3(2, 0, -252)
	territories.add_child(hood_west)
	var downtown_east := DowntownEastScene.instantiate() as Node3D
	downtown_east.position = Vector3(113.987, 0, -138.001)
	downtown_east.rotation.y = -PI * 0.5
	territories.add_child(downtown_east)
	var downtown_west := DowntownWestScene.instantiate() as Node3D
	downtown_west.position = Vector3(249.993, 0, -254.999)
	downtown_west.rotation.y = PI
	territories.add_child(downtown_west)

	var boundary := IslandBoundaryScene.instantiate() as Node3D
	stage.add_child(boundary)
	var styler := SurfaceStylerScript.new() as WorldSurfaceStyler
	styler.source_roots = [
		NodePath("../Territories"),
		NodePath("../IslandBoundary/Shore"),
	]
	stage.add_child(styler)

	_camera = Camera3D.new()
	_camera.fov = 64.0
	_camera.far = 2200.0
	_camera.current = true
	stage.add_child(_camera)

	for _frame in 8:
		await process_frame

	var output_directory := _get_output_directory()
	DirAccess.make_dir_recursive_absolute(output_directory)
	await _capture(
		output_directory.path_join("north_morning.png"),
		Vector3(86, 6.0, 108),
		Vector3(86, -1.0, 151),
		Color(0.50, 0.58, 0.66),
		Color(1.0, 0.77, 0.57),
		1.35
	)
	await _capture(
		output_directory.path_join("west_dusk.png"),
		Vector3(16, 7.0, -92),
		Vector3(-46, -1.0, -92),
		Color(0.42, 0.28, 0.36),
		Color(1.0, 0.49, 0.30),
		0.9
	)
	await _capture(
		output_directory.path_join("south_night.png"),
		Vector3(112, 6.0, -360),
		Vector3(112, -1.0, -408),
		Color(0.025, 0.045, 0.09),
		Color(0.42, 0.55, 0.82),
		0.34
	)
	await _capture(
		output_directory.path_join("overview.png"),
		Vector3(390, 470, -118),
		Vector3(95, 0, -130),
		Color(0.50, 0.58, 0.66),
		Color(1.0, 0.77, 0.57),
		1.25
	)

	print("ISLAND_BOUNDARY_RENDER_TEST_PASS:%s" % output_directory)
	quit(0)


func _capture(
	path: String,
	position: Vector3,
	target: Vector3,
	background: Color,
	light_color: Color,
	light_energy: float
) -> void:
	_environment.background_color = background
	_environment.ambient_light_color = background.lightened(0.2)
	_sun.light_color = light_color
	_sun.light_energy = light_energy
	_camera.position = position
	_camera.look_at(target, Vector3.UP)
	for _frame in 3:
		await process_frame
	var image := root.get_texture().get_image()
	assert(image != null and not image.is_empty())
	assert(image.save_png(path) == OK)


func _get_output_directory() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			return ProjectSettings.globalize_path(argument.trim_prefix("--output="))
	return ProjectSettings.globalize_path(
		"res://.runtime_appdata/island_edge_renders"
	)
