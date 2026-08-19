@tool
class_name BuildingGenerator3D
extends Node3D

const MODULE_SIZE := 4.0
const FACADE_CELL_SIZE := 2.0
const STORY_HEIGHT := 3.0
const COLLISION_MARGIN := Vector2(0.5, 0.4)

const GENERATED_NAME := &"Generated"
const MANUAL_DETAILS_NAME := &"ManualDetails"

const WINDOW_COMPONENT_SCRIPT := preload(
	"res://Scripts/World/building_window_material_component.gd"
)
const WINDOW_OFF_MATERIAL := preload(
	"res://Assets/MapStuff/Textures/Tiled/Game/AssetsvilleTown/Textures/Tiled/WindowOff.tres"
)
const WINDOW_ON_MATERIAL := preload(
	"res://Assets/MapStuff/Textures/Tiled/Game/AssetsvilleTown/Textures/Tiled/WindowOn.tres"
)

const VERIFIED_STYLE_PATHS := [
	"res://Assets/MapStuff/BuildingGenerator/Styles/classic_mixed_use.tres",
	"res://Assets/MapStuff/BuildingGenerator/Styles/brick_retail.tres",
	"res://Assets/MapStuff/BuildingGenerator/Styles/office_high_rise.tres",
]

@export var profile: BuildingGenerationProfile
@export_tool_button("Generate / Regenerate") var _generate_button := regenerate
@export_tool_button("Randomize Appearance") var _randomize_button := randomize_building
@export_tool_button("Bake To Editable Nodes") var _bake_button := bake

var _random := RandomNumberGenerator.new()
var _style: BuildingStyleProfile
var _facade_material: StandardMaterial3D
var _trim_material: StandardMaterial3D
var _name_counts: Dictionary = {}


func _init() -> void:
	if profile == null:
		profile = BuildingGenerationProfile.new()


func _ready() -> void:
	_ensure_manual_details()


## Generates a complete, deterministic exterior from [member profile].
func generate() -> void:
	_ensure_profile()
	profile.sanitize()
	_style = _load_verified_style(profile.preset)
	if _style == null:
		push_error("BuildingGenerator3D could not load its verified style profile.")
		return

	_remove_generated()
	_ensure_manual_details()
	_name_counts.clear()
	_random.seed = profile.seed
	_create_building_materials()

	var generated := Node3D.new()
	generated.name = GENERATED_NAME
	generated.set_meta(&"building_generator_seed", profile.seed)
	generated.set_meta(&"building_generator_preset", profile.preset)
	generated.set_meta(&"building_generator_palette", profile.material_palette)
	generated.set_meta(&"building_generator_width_modules", profile.width_modules)
	generated.set_meta(&"building_generator_depth_modules", profile.depth_modules)
	generated.set_meta(&"building_generator_story_count", profile.story_count)
	_add_owned_child(self, generated)

	var walls := Node3D.new()
	walls.name = &"Walls"
	_add_owned_child(generated, walls)
	_build_stories(walls)
	_build_attic_cap(walls)

	var floor_shell := Node3D.new()
	floor_shell.name = &"Floor"
	_add_owned_child(generated, floor_shell)
	_build_floor_shell(floor_shell)

	var roof := Node3D.new()
	roof.name = &"Roof"
	_add_owned_child(generated, roof)
	_build_roof(roof)

	_build_collision(generated)
	_build_props(generated)
	_add_window_component(generated)

	generated.set_meta(&"building_generator_complete", true)


## Public alias used by the inspector and by headless verification.
func regenerate() -> void:
	generate()


## Changes the visual recipe while deliberately preserving the chosen shape.
func randomize_building() -> void:
	_ensure_profile()
	var appearance_random := RandomNumberGenerator.new()
	appearance_random.randomize()
	profile.seed = appearance_random.randi_range(0, 2147483647)
	profile.preset = appearance_random.randi_range(
		BuildingGenerationProfile.Preset.CLASSIC_MIXED_USE,
		BuildingGenerationProfile.Preset.OFFICE_HIGH_RISE
	)
	profile.material_palette = appearance_random.randi_range(
		BuildingGenerationProfile.MaterialPalette.WHITE_BRICK,
		BuildingGenerationProfile.MaterialPalette.YELLOW_BRICK
	)
	profile.prop_density = appearance_random.randi_range(
		BuildingGenerationProfile.PropDensity.LOW,
		BuildingGenerationProfile.PropDensity.HIGH
	)
	profile.emit_changed()
	generate()


## Leaves the generated hierarchy intact but removes the procedural script.
## The result is an ordinary Node3D scene that cannot be regenerated.
func bake() -> void:
	var generated := get_node_or_null(NodePath(String(GENERATED_NAME)))
	if generated == null:
		push_warning("Generate the building before baking it.")
		return
	generated.set_meta(&"building_generator_baked", true)
	generated.remove_meta(&"building_generator_complete")
	set_script(null)


func _ensure_profile() -> void:
	if profile == null:
		profile = BuildingGenerationProfile.new()


func _load_verified_style(preset: int) -> BuildingStyleProfile:
	var index := clampi(preset, 0, VERIFIED_STYLE_PATHS.size() - 1)
	return load(VERIFIED_STYLE_PATHS[index]) as BuildingStyleProfile


func _remove_generated() -> void:
	var previous := get_node_or_null(NodePath(String(GENERATED_NAME)))
	if previous == null:
		return
	remove_child(previous)
	previous.free()


func _ensure_manual_details() -> Node3D:
	var existing := get_node_or_null(NodePath(String(MANUAL_DETAILS_NAME))) as Node3D
	if existing != null:
		return existing
	var manual_details := Node3D.new()
	manual_details.name = MANUAL_DETAILS_NAME
	_add_owned_child(self, manual_details)
	return manual_details


func _build_stories(walls: Node3D) -> void:
	var entrance_module := profile.entrance_module
	if entrance_module < 0:
		entrance_module = _random.randi_range(0, profile.depth_modules - 1)

	for story_index in profile.story_count:
		var story_root := Node3D.new()
		story_root.name = "Story%02d" % (story_index + 1)
		story_root.position.y = float(story_index) * STORY_HEIGHT
		_add_owned_child(walls, story_root)

		_build_story_corners(story_root, story_index, false)
		for side in 4:
			var side_cells := (
				profile.depth_modules * 2
				if side == 0 or side == 2
				else profile.width_modules * 2
			)
			var entrance_start := -1
			if story_index == 0 and side == 0:
				entrance_start = entrance_module * 2
			_build_facade_edge(
				story_root,
				side,
				side_cells,
				story_index,
				false,
				entrance_start
			)


func _build_attic_cap(walls: Node3D) -> void:
	var attic_root := Node3D.new()
	attic_root.name = &"AtticCap"
	attic_root.position.y = float(profile.story_count) * STORY_HEIGHT
	_add_owned_child(walls, attic_root)
	_build_story_corners(attic_root, profile.story_count, true)
	for side in 4:
		var side_cells := (
			profile.depth_modules * 2
			if side == 0 or side == 2
			else profile.width_modules * 2
		)
		_build_facade_edge(
			attic_root,
			side,
			side_cells,
			profile.story_count,
			true,
			-1
		)


func _build_story_corners(
	parent: Node3D,
	story_index: int,
	is_top_story: bool
) -> void:
	var tile := _style.attic_corner if is_top_story else _style.corner
	if tile == null:
		tile = _style.corner
	if tile == null or not tile.has_visual():
		push_warning("%s has no usable corner tile." % _style.display_name)
		return

	var half_width := float(profile.width_modules) * MODULE_SIZE * 0.5
	var half_depth := float(profile.depth_modules) * MODULE_SIZE * 0.5
	var placements := [
		[Vector3(half_width, 0.0, half_depth), 90.0, "front_left"],
		[Vector3(half_width, 0.0, -half_depth), 180.0, "front_right"],
		[Vector3(-half_width, 0.0, -half_depth), -90.0, "back_right"],
		[Vector3(-half_width, 0.0, half_depth), 0.0, "back_left"],
	]
	for placement in placements:
		_add_tile(
			parent,
			tile,
			placement[0] as Vector3,
			float(placement[1]),
			story_index,
			String(placement[2]),
			0,
			0,
			"attic_corner" if is_top_story else "corner"
		)


func _build_facade_edge(
	parent: Node3D,
	side: int,
	cell_count: int,
	story_index: int,
	is_top_story: bool,
	entrance_start: int
) -> void:
	var candidates: Array[BuildingTileDefinition]
	if is_top_story:
		candidates = []
		if _style.attic_wall != null:
			candidates.append(_style.attic_wall)
	elif story_index == 0:
		candidates = _style.ground_facades()
	else:
		candidates = _style.regular_facades()
	candidates = _filter_tiles_for_side(candidates, side)

	var entrances := _filter_tiles_for_side(_style.entrances(), side)
	var selected_entrance: BuildingTileDefinition
	if entrance_start >= 0:
		var entrance_selection := _select_entrance(
			entrances,
			candidates,
			cell_count,
			entrance_start
		)
		if entrance_selection.is_empty():
			push_error(
				"%s has no entrance that fits a %d-cell front facade."
				% [_style.display_name, cell_count]
			)
			return
		selected_entrance = entrance_selection["tile"] as BuildingTileDefinition
		entrance_start = int(entrance_selection["start"])

	var cursor := 0
	while cursor < cell_count:
		var tile: BuildingTileDefinition
		var is_entrance := selected_entrance != null and cursor == entrance_start
		if is_entrance:
			tile = selected_entrance
		else:
			var remaining := cell_count - cursor
			if entrance_start > cursor:
				remaining = entrance_start - cursor
			tile = _choose_tile(candidates, remaining)

		if tile == null:
			push_error(
				"%s cannot fill facade side %d at cell %d."
				% [_style.display_name, side, cursor]
			)
			return

		var span := mini(tile.facade_cells, cell_count - cursor)
		# Verified facade meshes are end-anchored and extend down local -Z.
		var distance := float(cursor) * FACADE_CELL_SIZE
		var placement := _edge_placement(side, distance)
		_add_tile(
			parent,
			tile,
			placement[0] as Vector3,
			float(placement[1]),
			story_index,
			_side_name(side),
			cursor,
			span,
			"entrance" if is_entrance else ("attic" if is_top_story else "facade")
		)
		cursor += span


func _edge_placement(side: int, distance: float) -> Array:
	var half_width := float(profile.width_modules) * MODULE_SIZE * 0.5
	var half_depth := float(profile.depth_modules) * MODULE_SIZE * 0.5
	match side:
		0:
			return [Vector3(half_width, 0.0, half_depth - distance), 0.0]
		1:
			return [Vector3(half_width - distance, 0.0, -half_depth), 90.0]
		2:
			return [Vector3(-half_width, 0.0, -half_depth + distance), 180.0]
		_:
			return [Vector3(-half_width + distance, 0.0, half_depth), -90.0]


func _choose_tile(
	candidates: Array[BuildingTileDefinition],
	remaining_cells: int
) -> BuildingTileDefinition:
	var usable: Array[BuildingTileDefinition] = []
	var total_weight := 0.0
	for tile in candidates:
		if tile == null or not tile.has_visual():
			continue
		if tile.facade_cells > remaining_cells:
			continue
		if not _can_fill_cells(candidates, remaining_cells - tile.facade_cells):
			continue
		usable.append(tile)
		total_weight += tile.weight
	if usable.is_empty():
		return null

	var pick := _random.randf_range(0.0, total_weight)
	for tile in usable:
		pick -= tile.weight
		if pick <= 0.0:
			return tile
	return usable.back()


func _filter_tiles_for_side(
	candidates: Array[BuildingTileDefinition],
	side: int
) -> Array[BuildingTileDefinition]:
	var result: Array[BuildingTileDefinition] = []
	for tile in candidates:
		if tile != null and tile.is_allowed_on_side(side):
			result.append(tile)
	return result


func _can_fill_cells(
	candidates: Array[BuildingTileDefinition],
	cell_count: int
) -> bool:
	if cell_count == 0:
		return true
	if cell_count < 0:
		return false
	for tile in candidates:
		if tile == null or tile.facade_cells > cell_count:
			continue
		if _can_fill_cells(candidates, cell_count - tile.facade_cells):
			return true
	return false


func _select_entrance(
	entrances: Array[BuildingTileDefinition],
	fillers: Array[BuildingTileDefinition],
	cell_count: int,
	requested_start: int
) -> Dictionary:
	var viable_tiles: Array[BuildingTileDefinition] = []
	var starts_by_tile: Dictionary = {}
	for tile in entrances:
		if tile == null or tile.facade_cells > cell_count:
			continue
		var valid_starts: Array[int] = []
		for start in range(0, cell_count - tile.facade_cells + 1):
			if not _can_fill_cells(fillers, start):
				continue
			if not _can_fill_cells(
				fillers,
				cell_count - start - tile.facade_cells
			):
				continue
			valid_starts.append(start)
		if not valid_starts.is_empty():
			viable_tiles.append(tile)
			starts_by_tile[tile] = valid_starts
	if viable_tiles.is_empty():
		return {}

	var selected_tile := _choose_weighted(viable_tiles)
	var valid_starts := starts_by_tile[selected_tile] as Array
	var closest_starts: Array[int] = []
	var closest_distance := 2147483647
	for value in valid_starts:
		var start := int(value)
		var distance := absi(start - requested_start)
		if distance < closest_distance:
			closest_distance = distance
			closest_starts = [start]
		elif distance == closest_distance:
			closest_starts.append(start)
	return {
		"tile": selected_tile,
		"start": closest_starts[_random.randi_range(0, closest_starts.size() - 1)],
	}


func _choose_weighted(
	candidates: Array[BuildingTileDefinition]
) -> BuildingTileDefinition:
	var total_weight := 0.0
	for tile in candidates:
		total_weight += tile.weight
	var pick := _random.randf_range(0.0, total_weight)
	for tile in candidates:
		pick -= tile.weight
		if pick <= 0.0:
			return tile
	return candidates.back() if not candidates.is_empty() else null


func _build_floor_shell(parent: Node3D) -> void:
	if _style.floor_tile == null:
		return
	var half_width := float(profile.width_modules) * MODULE_SIZE * 0.5
	var half_depth := float(profile.depth_modules) * MODULE_SIZE * 0.5
	for x_index in profile.width_modules:
		for z_index in profile.depth_modules:
			var position := Vector3(
				-half_width + MODULE_SIZE * (float(x_index) + 0.5),
				0.1,
				-half_depth + MODULE_SIZE * (float(z_index) + 0.5)
			)
			_add_tile(
				parent,
				_style.floor_tile,
				position,
				0.0,
				0,
				"interior",
				x_index + z_index * profile.width_modules,
				1,
				"floor"
			)


func _build_roof(parent: Node3D) -> void:
	var roof_y := float(profile.story_count) * STORY_HEIGHT
	var half_width := float(profile.width_modules) * MODULE_SIZE * 0.5
	var half_depth := float(profile.depth_modules) * MODULE_SIZE * 0.5
	if _style.roof_tile != null:
		for x_index in profile.width_modules:
			for z_index in profile.depth_modules:
				var position := Vector3(
					-half_width + MODULE_SIZE * (float(x_index) + 0.5),
					roof_y,
					-half_depth + MODULE_SIZE * (float(z_index) + 0.5)
				)
				_add_tile(
					parent,
					_style.roof_tile,
					position,
					0.0,
					profile.story_count,
					"interior",
					x_index + z_index * profile.width_modules,
					1,
					"roof"
				)
	_build_cornice(parent, roof_y)


func _build_cornice(parent: Node3D, roof_y: float) -> void:
	if _style.cornice != null:
		for side in 4:
			var side_length := (
				float(profile.depth_modules) * MODULE_SIZE
				if side == 0 or side == 2
				else float(profile.width_modules) * MODULE_SIZE
			)
			# SM_cornice_01 is an end-anchored eight-meter mesh. Distribute the
			# minimum number of pieces across the side, overlapping only when a
			# side is not an exact multiple of eight meters.
			var piece_count := maxi(1, ceili(side_length / 8.0))
			var stride := 0.0
			if piece_count > 1:
				stride = (side_length - 8.0) / float(piece_count - 1)
			for piece_index in piece_count:
				var distance := float(piece_index) * stride
				var placement := _edge_placement(side, distance)
				var position := placement[0] as Vector3
				position.y = roof_y
				_add_tile(
					parent,
					_style.cornice,
					position,
					float(placement[1]),
					profile.story_count,
					_side_name(side),
					roundi(distance / FACADE_CELL_SIZE),
					4,
					"cornice"
				)

	if _style.cornice_corner == null:
		return
	var half_width := float(profile.width_modules) * MODULE_SIZE * 0.5
	var half_depth := float(profile.depth_modules) * MODULE_SIZE * 0.5
	var placements := [
		[Vector3(half_width, roof_y, half_depth), -90.0, "front_left"],
		[Vector3(half_width, roof_y, -half_depth), 0.0, "front_right"],
		[Vector3(-half_width, roof_y, -half_depth), 90.0, "back_right"],
		[Vector3(-half_width, roof_y, half_depth), 180.0, "back_left"],
	]
	for placement in placements:
		_add_tile(
			parent,
			_style.cornice_corner,
			placement[0] as Vector3,
			float(placement[1]),
			profile.story_count,
			String(placement[2]),
			0,
			0,
			"cornice_corner"
		)


func _build_collision(generated: Node3D) -> void:
	var static_body := StaticBody3D.new()
	static_body.name = &"StaticBody3D"
	_add_owned_child(generated, static_body)

	var collision := CollisionShape3D.new()
	collision.name = &"CollisionShape3D"
	var shape := BoxShape3D.new()
	var height := float(profile.story_count) * STORY_HEIGHT
	shape.size = Vector3(
		float(profile.width_modules) * MODULE_SIZE + COLLISION_MARGIN.x,
		height,
		float(profile.depth_modules) * MODULE_SIZE + COLLISION_MARGIN.y
	)
	collision.shape = shape
	collision.position.y = height * 0.5
	_add_owned_child(static_body, collision)


func _build_props(generated: Node3D) -> void:
	var props_root := Node3D.new()
	props_root.name = &"Props"
	_add_owned_child(generated, props_root)

	var prop_count: int = int([0, 1, 3, 5][clampi(profile.prop_density, 0, 3)])
	var candidates := _style.exterior_props()
	if prop_count == 0 or candidates.is_empty():
		return

	var used_slots: Dictionary = {}
	for prop_index in prop_count:
		var tile := _choose_prop(candidates)
		if tile == null:
			continue
		var placement := _find_prop_placement(tile, used_slots)
		if placement.is_empty():
			continue
		var prop := _instantiate_visual(tile)
		if prop == null:
			continue
		prop.name = _next_name(tile.node_name_prefix)
		prop.position = placement[0] as Vector3
		prop.rotation.y = deg_to_rad(float(placement[1]) + tile.yaw_offset_degrees)
		prop.set_meta(&"building_generator_source", tile.source_path())
		prop.set_meta(&"building_generator_kind", "prop")
		prop.set_meta(&"building_generator_prop_index", prop_index)
		_add_owned_child(props_root, prop)


func _choose_prop(
	candidates: Array[BuildingTileDefinition]
) -> BuildingTileDefinition:
	var total_weight := 0.0
	for tile in candidates:
		total_weight += tile.weight
	var pick := _random.randf_range(0.0, total_weight)
	for tile in candidates:
		pick -= tile.weight
		if pick <= 0.0:
			return tile
	return candidates.back() if not candidates.is_empty() else null


func _find_prop_placement(
	tile: BuildingTileDefinition,
	used_slots: Dictionary
) -> Array:
	var allowed_sides: Array[int]
	match tile.prop_placement:
		BuildingTileDefinition.PropPlacement.FRONT_WALL, BuildingTileDefinition.PropPlacement.GROUND_FRONT:
			allowed_sides = [0]
		_:
			allowed_sides = [1, 2, 3]

	for attempt in 12:
		var side: int = allowed_sides[_random.randi_range(0, allowed_sides.size() - 1)]
		var cells := (
			profile.depth_modules * 2
			if side == 0 or side == 2
			else profile.width_modules * 2
		)
		var slot := _random.randi_range(0, cells - 1)
		var key := "%d:%d" % [side, slot]
		if used_slots.has(key):
			continue
		used_slots[key] = true
		var distance := (float(slot) + 0.5) * FACADE_CELL_SIZE
		var edge := _edge_placement(side, distance)
		var position := edge[0] as Vector3
		var outward: Vector3 = [
			Vector3(1.0, 0.0, 0.0),
			Vector3(0.0, 0.0, -1.0),
			Vector3(-1.0, 0.0, 0.0),
			Vector3(0.0, 0.0, 1.0),
		][side]
		position += outward * tile.prop_outward_offset
		if tile.prop_placement == BuildingTileDefinition.PropPlacement.GROUND_FRONT:
			position.y = tile.prop_min_height
		else:
			var maximum := minf(
				tile.prop_max_height,
				float(profile.story_count) * STORY_HEIGHT - 0.5
			)
			position.y = _random.randf_range(minf(tile.prop_min_height, maximum), maximum)
		return [position + tile.placement_offset, float(edge[1])]
	return []


func _add_window_component(generated: Node3D) -> void:
	var component := Node.new()
	component.name = &"BuildingWindowMaterials"
	component.set_script(WINDOW_COMPONENT_SCRIPT)
	component.set("window_off_material", WINDOW_OFF_MATERIAL)
	component.set("window_on_material", WINDOW_ON_MATERIAL)
	_add_owned_child(generated, component)


func _add_tile(
	parent: Node3D,
	tile: BuildingTileDefinition,
	position: Vector3,
	yaw_degrees: float,
	story_index: int,
	side: String,
	cell_start: int,
	cell_span: int,
	kind: String
) -> Node3D:
	if tile == null or not tile.has_visual():
		return null
	var visual := _instantiate_visual(tile)
	if visual == null:
		return null
	visual.name = _next_name(tile.node_name_prefix)
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_degrees))
	visual.position = position + basis * tile.placement_offset
	visual.rotation.y = deg_to_rad(yaw_degrees + tile.yaw_offset_degrees)
	visual.set_meta(&"building_generator_source", tile.source_path())
	visual.set_meta(&"building_generator_role", tile.role)
	visual.set_meta(&"building_generator_kind", kind)
	visual.set_meta(&"building_generator_story", story_index)
	visual.set_meta(&"building_generator_side", side)
	visual.set_meta(&"building_generator_cell_start", cell_start)
	visual.set_meta(&"building_generator_cell_span", cell_span)
	_add_owned_child(parent, visual)
	if visual is MeshInstance3D:
		_apply_tile_materials(visual as MeshInstance3D, tile)
	if kind == "entrance" and tile.paired_detail != null:
		_add_tile(
			parent,
			tile.paired_detail,
			position,
			yaw_degrees,
			story_index,
			side,
			cell_start,
			0,
			"entrance_detail"
		)
	return visual


func _instantiate_visual(tile: BuildingTileDefinition) -> Node3D:
	if tile.mesh != null:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = tile.mesh
		return mesh_instance
	if tile.scene != null:
		var instance := tile.scene.instantiate()
		if instance is Node3D:
			return instance as Node3D
		push_warning("%s does not instantiate a Node3D." % tile.scene.resource_path)
		instance.free()
	return null


func _apply_tile_materials(
	mesh_instance: MeshInstance3D,
	tile: BuildingTileDefinition
) -> void:
	for surface in tile.facade_surfaces:
		_set_surface_material(mesh_instance, surface, _facade_material, tile)
	for surface in tile.trim_surfaces:
		_set_surface_material(mesh_instance, surface, _trim_material, tile)
	if tile.window_surface >= 0:
		_set_surface_material(
			mesh_instance,
			tile.window_surface,
			WINDOW_OFF_MATERIAL,
			tile
		)
		if mesh_instance.name.to_lower().begins_with("smwindow"):
			mesh_instance.set_meta(&"fb_window_surface", tile.window_surface)


func _set_surface_material(
	mesh_instance: MeshInstance3D,
	surface: int,
	material: Material,
	tile: BuildingTileDefinition
) -> void:
	if material == null:
		return
	if mesh_instance.mesh == null or surface >= mesh_instance.mesh.get_surface_count():
		push_warning(
			"%s expects missing material surface %d on %s."
			% [tile.display_name, surface, tile.source_path()]
		)
		return
	mesh_instance.set_surface_override_material(surface, material)


func _create_building_materials() -> void:
	_facade_material = null
	var texture_path := _palette_texture_path(profile.material_palette)
	if not texture_path.is_empty():
		var texture := load(texture_path) as Texture2D
		if texture != null:
			_facade_material = StandardMaterial3D.new()
			_facade_material.resource_name = "GeneratedFacade_%d" % profile.seed
			_facade_material.resource_local_to_scene = true
			_facade_material.albedo_texture = texture
			_facade_material.roughness = 0.82

	_trim_material = StandardMaterial3D.new()
	_trim_material.resource_name = "GeneratedTrim_%d" % profile.seed
	_trim_material.resource_local_to_scene = true
	_trim_material.albedo_color = _style.trim_color
	_trim_material.roughness = 0.72


func _palette_texture_path(palette: int) -> String:
	const TEXTURE_ROOT := (
		"res://Assets/MapStuff/Textures/Tiled/Game/AssetsvilleTown/Textures/Tiled/"
	)
	match palette:
		BuildingGenerationProfile.MaterialPalette.WHITE_BRICK:
			return TEXTURE_ROOT + "T_brickSmall_01_white.PNG"
		BuildingGenerationProfile.MaterialPalette.RED_BRICK:
			return TEXTURE_ROOT + "T_brickSmall_01_red.PNG"
		BuildingGenerationProfile.MaterialPalette.VIOLET_BRICK:
			return TEXTURE_ROOT + "T_brickSmall_01_violet.PNG"
		BuildingGenerationProfile.MaterialPalette.YELLOW_BRICK:
			return TEXTURE_ROOT + "T_brickSmall_01_yellow.PNG"
		_:
			return ""


func _next_name(prefix: String) -> StringName:
	var next_count := int(_name_counts.get(prefix, 0)) + 1
	_name_counts[prefix] = next_count
	return StringName("%s%03d" % [prefix, next_count])


func _side_name(side: int) -> String:
	return ["front", "right", "back", "left"][clampi(side, 0, 3)]


func _add_owned_child(parent: Node, child: Node) -> void:
	parent.add_child(child)
	var scene_owner := _edited_scene_owner()
	if scene_owner != null and child != scene_owner:
		child.owner = scene_owner


func _edited_scene_owner() -> Node:
	if Engine.is_editor_hint() and is_inside_tree():
		var edited_root := get_tree().edited_scene_root
		if edited_root != null:
			return edited_root
	if owner != null:
		return owner
	return null
