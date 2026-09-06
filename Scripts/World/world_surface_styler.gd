class_name WorldSurfaceStyler
extends Node

const DETAIL_SHADER := preload(
	"res://Assets/VFX/Shaders/world_surface_detail.gdshader"
)
const PUDDLE_SHADER := preload(
	"res://Assets/VFX/Shaders/rain_puddle_overlay.gdshader"
)
const DEFAULT_VISUAL_PROFILE := preload(
	"res://Assets/VFX/GrittyCinematicWorldVisualProfile.tres"
)
const STYLED_META := &"fb_world_surface_styled"
const PUDDLE_VISIBLE_WETNESS := 0.20
const EXCLUDED_NAME_PARTS := [
	"glass", "sign", "light", "lamp", "screen", "water",
]
const EXCLUDED_MATERIAL_PARTS := [
	"window", "glass", "sign", "light", "lamp", "screen", "neon", "water",
]

@export var source_roots: Array[NodePath] = [NodePath("../Territories")]
@export var visual_profile: WorldVisualProfile = DEFAULT_VISUAL_PROFILE

var styled_surface_count := 0
var styled_mesh_count := 0
var _material_cache: Dictionary = {}
var _wetness := 0.0
var _rain_intensity := 0.0
var _road_meshes: Array[MeshInstance3D] = []
var _puddle_field: MultiMeshInstance3D
var _puddle_material: ShaderMaterial


func _ready() -> void:
	style_now()


func style_now() -> void:
	styled_surface_count = 0
	styled_mesh_count = 0
	_road_meshes.clear()
	if visual_profile == null:
		_clear_puddle_field()
		return
	for root_path in source_roots:
		var source_root := get_node_or_null(root_path)
		if source_root != null:
			_style_branch(source_root)
	_rebuild_puddle_field()


func get_cached_material_count() -> int:
	return _material_cache.size()


func set_wetness(value: float) -> void:
	_wetness = clampf(value, 0.0, 1.0)
	for cached_material in _material_cache.values():
		var material := cached_material as ShaderMaterial
		if material != null:
			material.set_shader_parameter("wetness", _wetness)
	if _puddle_material != null:
		_puddle_material.set_shader_parameter("wetness", _wetness)
	if is_instance_valid(_puddle_field):
		_puddle_field.visible = _wetness > PUDDLE_VISIBLE_WETNESS


func get_wetness() -> float:
	return _wetness


func set_rain_intensity(value: float) -> void:
	_rain_intensity = clampf(value, 0.0, 1.0)
	if _puddle_material != null:
		_puddle_material.set_shader_parameter("rain_activity", _rain_intensity)


func get_rain_intensity() -> float:
	return _rain_intensity


func get_puddle_instance_count() -> int:
	if _puddle_field == null or _puddle_field.multimesh == null:
		return 0
	return _puddle_field.multimesh.instance_count


func get_puddle_material() -> ShaderMaterial:
	return _puddle_material


func _style_branch(node: Node) -> void:
	if node is MeshInstance3D:
		_style_mesh(node as MeshInstance3D)
	for child in node.get_children():
		_style_branch(child)


func _style_mesh(mesh_instance: MeshInstance3D) -> void:
	if not _can_style(mesh_instance):
		return
	var surface_resource_path := _surface_resource_path(mesh_instance)
	var category := _ground_category(surface_resource_path)
	var building_family := _is_building_family(surface_resource_path)
	if category == &"road":
		_road_meshes.append(mesh_instance)
	var changed := false
	for surface_index in mesh_instance.mesh.get_surface_count():
		if _is_window_surface(mesh_instance, surface_index):
			continue
		var source := mesh_instance.get_surface_override_material(surface_index)
		if source == null:
			source = mesh_instance.mesh.surface_get_material(surface_index)
		if source == null or source.has_meta(STYLED_META):
			continue
		var styled: Material
		if not category.is_empty() and source is BaseMaterial3D:
			styled = _ground_material(source as BaseMaterial3D, category)
		elif building_family and _is_weatherable_building_material(source):
			var building_category := (
				&"brick" if _is_brick_material(source) else &"building"
			)
			styled = _ground_material(
				source as BaseMaterial3D,
				building_category
			)
		if styled == null:
			continue
		mesh_instance.set_surface_override_material(surface_index, styled)
		styled_surface_count += 1
		changed = true
	if changed:
		styled_mesh_count += 1


func _can_style(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.mesh == null or mesh_instance.skin != null:
		return false
	if not mesh_instance.skeleton.is_empty():
		return false
	var current: Node = mesh_instance
	while current != null:
		if current.is_in_group(&"exclude_static_batch"):
			return false
		current = current.get_parent()
	var lower_name := mesh_instance.name.to_lower()
	for excluded_part in EXCLUDED_NAME_PARTS:
		if excluded_part in lower_name:
			return false
	return true


func _ground_category(resource_path: String) -> StringName:
	var lower_path := resource_path.to_lower()
	if "/groundtileset/sm_grass" in lower_path:
		return &"grass"
	if "/groundtileset/sm_dirt" in lower_path:
		return &"dirt"
	if (
		"/groundtileset/sm_road" in lower_path
		or "/groundtileset/sm_parcel_road" in lower_path
		or "/groundtileset/sm_parking" in lower_path
	):
		return &"road"
	if "/groundtileset/sm_sidewalk" in lower_path:
		return &"sidewalk"
	return &""


func _ground_material(source: BaseMaterial3D, category: StringName) -> ShaderMaterial:
	if source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return null
	var cache_key := "surface:%s:%s" % [category, _resource_cache_key(source)]
	if _material_cache.has(cache_key):
		return _material_cache[cache_key] as ShaderMaterial
	var styled := ShaderMaterial.new()
	styled.shader = DETAIL_SHADER
	styled.resource_name = "FB_%s_%s" % [category, source.resource_name]
	styled.set_meta(STYLED_META, true)
	styled.set_shader_parameter("albedo_color", source.albedo_color)
	styled.set_shader_parameter("use_albedo_texture", source.albedo_texture != null)
	styled.set_shader_parameter("albedo_texture", source.albedo_texture)
	styled.set_shader_parameter("metallic", source.metallic)
	styled.set_shader_parameter("use_metallic_texture", source.metallic_texture != null)
	styled.set_shader_parameter("metallic_texture", source.metallic_texture)
	styled.set_shader_parameter("metallic_channel", int(source.metallic_texture_channel))
	styled.set_shader_parameter("roughness", source.roughness)
	styled.set_shader_parameter("use_roughness_texture", source.roughness_texture != null)
	styled.set_shader_parameter("roughness_texture", source.roughness_texture)
	styled.set_shader_parameter("roughness_channel", int(source.roughness_texture_channel))
	styled.set_shader_parameter("use_ao_texture", source.ao_texture != null)
	styled.set_shader_parameter("ao_texture", source.ao_texture)
	styled.set_shader_parameter("ao_channel", int(source.ao_texture_channel))
	styled.set_shader_parameter("use_normal_texture", source.normal_texture != null)
	styled.set_shader_parameter("normal_texture", source.normal_texture)
	styled.set_shader_parameter("normal_scale", source.normal_scale)
	styled.set_shader_parameter("uv_scale", source.uv1_scale)
	styled.set_shader_parameter("uv_offset", source.uv1_offset)
	styled.set_shader_parameter("macro_scale", visual_profile.ground_macro_scale)
	styled.set_shader_parameter(
		"macro_variation",
		visual_profile.ground_macro_variation
	)
	styled.set_shader_parameter(
		"roughness_variation",
		visual_profile.ground_roughness_variation
	)
	var category_values := _category_values(category)
	styled.set_shader_parameter("surface_tint", category_values["tint"])
	styled.set_shader_parameter("roughness_bias", category_values["roughness_bias"])
	styled.set_shader_parameter("wetness", _wetness)
	styled.set_shader_parameter("wet_response", category_values["wet_response"])
	styled.set_shader_parameter("wet_darkening", category_values["wet_darkening"])
	styled.set_shader_parameter("wet_roughness", category_values["wet_roughness"])
	styled.set_shader_parameter(
		"planar_normal_stabilization",
		category_values["planar_normal_stabilization"]
	)
	_material_cache[cache_key] = styled
	return styled


func _resource_cache_key(resource: Resource) -> String:
	if not resource.resource_path.is_empty():
		return resource.resource_path
	return "%s:%s:%d" % [
		resource.get_class(),
		resource.resource_name,
		resource.get_instance_id(),
	]


func _category_values(category: StringName) -> Dictionary:
	match category:
		&"grass":
			return {
				"tint": Color(0.88, 0.91, 0.78),
				"roughness_bias": 0.08,
				"wet_response": 0.35,
				"wet_darkening": 0.06,
				"wet_roughness": 0.42,
				"planar_normal_stabilization": 0.0,
			}
		&"dirt":
			return {
				"tint": Color(0.86, 0.82, 0.76),
				"roughness_bias": 0.06,
				"wet_response": 0.65,
				"wet_darkening": 0.12,
				"wet_roughness": 0.30,
				"planar_normal_stabilization": 0.0,
			}
		&"road":
			return {
				"tint": Color(0.82, 0.84, 0.88),
				"roughness_bias": 0.025,
				"wet_response": 1.0,
				"wet_darkening": visual_profile.wet_road_darkening,
				"wet_roughness": visual_profile.wet_road_roughness,
				"planar_normal_stabilization": 1.0,
			}
		&"brick":
			return {
				"tint": Color(0.94, 0.92, 0.90),
				"roughness_bias": 0.08,
				"wet_response": 0.78,
				"wet_darkening": 0.11,
				"wet_roughness": 0.27,
				"planar_normal_stabilization": 0.0,
			}
		&"building":
			return {
				"tint": Color(0.96, 0.96, 0.97),
				"roughness_bias": 0.035,
				"wet_response": 0.75,
				"wet_darkening": 0.10,
				"wet_roughness": 0.24,
				"planar_normal_stabilization": 0.15,
			}
		_:
			return {
				"tint": Color(0.92, 0.93, 0.95),
				"roughness_bias": 0.04,
				"wet_response": 0.90,
				"wet_darkening": 0.12,
				"wet_roughness": 0.28,
				"planar_normal_stabilization": 0.90,
			}


func _surface_resource_path(mesh_instance: MeshInstance3D) -> String:
	var generated_source := String(
		mesh_instance.get_meta(&"building_generator_source", "")
	)
	if not generated_source.is_empty():
		return generated_source
	return mesh_instance.mesh.resource_path


func _is_building_family(resource_path: String) -> bool:
	return "/buildingtileset/" in resource_path.to_lower()


func _is_window_surface(mesh_instance: MeshInstance3D, surface_index: int) -> bool:
	return (
		mesh_instance.has_meta(&"fb_window_surface")
		and int(mesh_instance.get_meta(&"fb_window_surface")) == surface_index
	)


func _is_weatherable_building_material(source: Material) -> bool:
	if source is not BaseMaterial3D:
		return false
	var base := source as BaseMaterial3D
	if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false
	if base.emission_enabled:
		return false
	var description := base.resource_name.to_lower()
	if not base.resource_path.is_empty():
		description += " " + base.resource_path.to_lower()
	if base.albedo_texture != null:
		description += " " + base.albedo_texture.resource_path.to_lower()
	for excluded_part in EXCLUDED_MATERIAL_PARTS:
		if excluded_part in description:
			return false
	return true


func _is_brick_material(source: Material) -> bool:
	if source is not BaseMaterial3D:
		return false
	var base := source as BaseMaterial3D
	if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false
	if base.albedo_texture == null:
		return false
	return "brick" in base.albedo_texture.resource_path.to_lower()


func _clear_puddle_field() -> void:
	if is_instance_valid(_puddle_field):
		_puddle_field.free()
	_puddle_field = null
	_puddle_material = null


func _rebuild_puddle_field() -> void:
	_clear_puddle_field()
	if (
		visual_profile == null
		or not visual_profile.puddle_overlays_enabled
		or _road_meshes.is_empty()
	):
		return
	var transforms: Array[Transform3D] = []
	var custom_data: Array[Color] = []
	for road_mesh in _road_meshes:
		_append_road_puddles(road_mesh, transforms, custom_data)
	if transforms.is_empty():
		return

	_puddle_material = ShaderMaterial.new()
	_puddle_material.shader = PUDDLE_SHADER
	_puddle_material.resource_name = "FB_RainPuddleOverlay"
	_puddle_material.render_priority = 1
	_puddle_material.set_shader_parameter("wetness", _wetness)
	_puddle_material.set_shader_parameter("rain_activity", _rain_intensity)
	_puddle_material.set_shader_parameter(
		"puddle_opacity",
		visual_profile.puddle_overlay_opacity
	)
	_puddle_material.set_shader_parameter(
		"puddle_roughness",
		visual_profile.puddle_roughness
	)
	_puddle_material.set_shader_parameter(
		"edge_softness",
		visual_profile.puddle_edge_softness
	)
	_puddle_material.set_shader_parameter(
		"ripple_normal_strength",
		visual_profile.puddle_ripple_normal_strength
	)

	var puddle_mesh := PlaneMesh.new()
	puddle_mesh.size = Vector2.ONE
	var puddle_multimesh := MultiMesh.new()
	puddle_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	puddle_multimesh.use_custom_data = true
	puddle_multimesh.mesh = puddle_mesh
	puddle_multimesh.instance_count = transforms.size()
	for index in transforms.size():
		puddle_multimesh.set_instance_transform(index, transforms[index])
		puddle_multimesh.set_instance_custom_data(index, custom_data[index])

	_puddle_field = MultiMeshInstance3D.new()
	_puddle_field.name = "RainPuddleField"
	_puddle_field.multimesh = puddle_multimesh
	_puddle_field.material_override = _puddle_material
	_puddle_field.visible = _wetness > PUDDLE_VISIBLE_WETNESS
	_puddle_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_puddle_field.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_puddle_field.visibility_range_end = visual_profile.puddle_visibility_distance
	_puddle_field.extra_cull_margin = visual_profile.puddle_maximum_diameter
	_puddle_field.add_to_group(&"exclude_static_batch")
	add_child(_puddle_field)


func _append_road_puddles(
	road_mesh: MeshInstance3D,
	transforms: Array[Transform3D],
	custom_data: Array[Color]
) -> void:
	if not is_instance_valid(road_mesh) or road_mesh.mesh == null:
		return
	var local_bounds := road_mesh.mesh.get_aabb()
	var global_basis := road_mesh.global_transform.basis
	var x_scale := global_basis.x.length()
	var z_scale := global_basis.z.length()
	if x_scale < 0.001 or z_scale < 0.001:
		return
	var world_width := local_bounds.size.x * x_scale
	var world_depth := local_bounds.size.z * z_scale
	var surface_area := world_width * world_depth
	if surface_area < 4.0:
		return
	var puddle_count := clampi(
		roundi(
			surface_area
			/ 100.0
			* visual_profile.puddles_per_100_square_meters
		),
		1,
		visual_profile.maximum_puddles_per_road_mesh
	)
	var rng := RandomNumberGenerator.new()
	var puddle_seed := hash("%s:%s:%s" % [
		_surface_resource_path(road_mesh),
		road_mesh.name,
		road_mesh.global_position.round(),
	])
	rng.seed = absi(puddle_seed)
	var surface_orientation := global_basis.orthonormalized()
	if absf(surface_orientation.y.dot(Vector3.UP)) < 0.75:
		return
	for _puddle_index in puddle_count:
		var aspect := rng.randf_range(
			visual_profile.puddle_minimum_aspect,
			0.88
		)
		var diameter := minf(
			rng.randf_range(
				visual_profile.puddle_minimum_diameter,
				visual_profile.puddle_maximum_diameter
			),
			minf(world_width * 0.82, world_depth * 0.82 / aspect)
		)
		if diameter < 0.5:
			continue
		var half_local_x := minf(
			diameter * 0.5 / x_scale,
			local_bounds.size.x * 0.42
		)
		var half_local_z := minf(
			diameter * aspect * 0.5 / z_scale,
			local_bounds.size.z * 0.42
		)
		var local_x := rng.randf_range(
			local_bounds.position.x + half_local_x,
			local_bounds.end.x - half_local_x
		)
		var local_z := rng.randf_range(
			local_bounds.position.z + half_local_z,
			local_bounds.end.z - half_local_z
		)
		var local_position := Vector3(
			local_x,
			local_bounds.end.y + visual_profile.puddle_surface_offset,
			local_z
		)
		var puddle_basis := surface_orientation.rotated(
			surface_orientation.y.normalized(),
			rng.randf_range(0.0, TAU)
		)
		puddle_basis.x *= diameter
		puddle_basis.z *= diameter * aspect
		transforms.append(Transform3D(
			puddle_basis,
			road_mesh.global_transform * local_position
		))
		custom_data.append(Color(
			rng.randf(),
			aspect,
			rng.randf(),
			rng.randf()
		))
