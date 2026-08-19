class_name WorldSurfaceStyler
extends Node

const DETAIL_SHADER := preload(
	"res://Assets/VFX/Shaders/world_surface_detail.gdshader"
)
const DEFAULT_VISUAL_PROFILE := preload(
	"res://Assets/VFX/GrittyCinematicWorldVisualProfile.tres"
)
const STYLED_META := &"fb_world_surface_styled"
const EXCLUDED_NAME_PARTS := [
	"window", "glass", "sign", "light", "lamp", "screen", "water",
]

@export var source_roots: Array[NodePath] = [NodePath("../Territories")]
@export var visual_profile: WorldVisualProfile = DEFAULT_VISUAL_PROFILE

var styled_surface_count := 0
var styled_mesh_count := 0
var _material_cache: Dictionary = {}


func _ready() -> void:
	style_now()


func style_now() -> void:
	styled_surface_count = 0
	styled_mesh_count = 0
	if visual_profile == null:
		return
	for root_path in source_roots:
		var source_root := get_node_or_null(root_path)
		if source_root != null:
			_style_branch(source_root)


func get_cached_material_count() -> int:
	return _material_cache.size()


func _style_branch(node: Node) -> void:
	if node is MeshInstance3D:
		_style_mesh(node as MeshInstance3D)
	for child in node.get_children():
		_style_branch(child)


func _style_mesh(mesh_instance: MeshInstance3D) -> void:
	if not _can_style(mesh_instance):
		return
	var category := _ground_category(mesh_instance.mesh.resource_path)
	var changed := false
	for surface_index in mesh_instance.mesh.get_surface_count():
		var source := mesh_instance.get_surface_override_material(surface_index)
		if source == null:
			source = mesh_instance.mesh.surface_get_material(surface_index)
		if source == null or source.has_meta(STYLED_META):
			continue
		var styled: Material
		if not category.is_empty() and source is BaseMaterial3D:
			styled = _ground_material(source as BaseMaterial3D, category)
		elif (
			_is_brick_family(mesh_instance.mesh.resource_path)
			and _is_brick_material(source)
		):
			styled = _ground_material(source as BaseMaterial3D, &"brick")
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
			return {"tint": Color(0.88, 0.91, 0.78), "roughness_bias": 0.08}
		&"dirt":
			return {"tint": Color(0.86, 0.82, 0.76), "roughness_bias": 0.06}
		&"road":
			return {"tint": Color(0.82, 0.84, 0.88), "roughness_bias": 0.025}
		&"brick":
			return {"tint": Color(0.94, 0.92, 0.90), "roughness_bias": 0.08}
		_:
			return {"tint": Color(0.92, 0.93, 0.95), "roughness_bias": 0.04}


func _is_brick_family(resource_path: String) -> bool:
	return "/buildingtileset/" in resource_path.to_lower()


func _is_brick_material(source: Material) -> bool:
	if source is not BaseMaterial3D:
		return false
	var base := source as BaseMaterial3D
	if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false
	if base.albedo_texture == null:
		return false
	return "brick" in base.albedo_texture.resource_path.to_lower()
