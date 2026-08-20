class_name IslandVegetationWind
extends Node

const WIND_SHADER := preload(
	"res://Assets/VFX/Shaders/vegetation_wind.gdshader"
)
const VARIATION_META := &"fb_island_height_varied"

@export var vegetation_roots: Array[NodePath] = [
	NodePath("../Shore/North/Vegetation"),
	NodePath("../Shore/West/Vegetation"),
	NodePath("../Shore/South/Vegetation"),
]
@export_range(0.5, 1.0, 0.01) var tree_height_min := 0.86
@export_range(1.0, 1.5, 0.01) var tree_height_max := 1.14
@export_range(0.5, 1.0, 0.01) var bush_height_min := 0.92
@export_range(1.0, 1.5, 0.01) var bush_height_max := 1.08
@export_range(0.0, 0.5, 0.01) var tree_wind_strength := 0.16
@export_range(0.0, 0.5, 0.01) var bush_wind_strength := 0.11
@export_category("Storm Response")
@export_range(1.0, 4.0, 0.05) var storm_wind_multiplier := 2.65
@export_range(1.0, 2.0, 0.05) var storm_speed_multiplier := 1.35

var tree_count := 0
var bush_count := 0
var current_weather_wind_multiplier := 1.0
var current_weather_speed_multiplier := 1.0
var current_weather_gustiness := 0.0
var _material_cache: Dictionary = {}
var _weather_system: WeatherSystem


func _ready() -> void:
	apply_variation_and_wind()
	set_process(false)
	call_deferred("_connect_weather_system")


func _process(_delta: float) -> void:
	if _weather_system == null:
		set_process(false)
		return
	set_weather_wind_intensity(_weather_system.get_wind_intensity())


func apply_variation_and_wind() -> void:
	tree_count = 0
	bush_count = 0
	for root_path in vegetation_roots:
		var vegetation_root := get_node_or_null(root_path)
		if vegetation_root == null:
			push_warning(
				"IslandVegetationWind could not find vegetation root %s."
				% root_path
			)
			continue
		for child in vegetation_root.get_children():
			var plant := child as Node3D
			if plant == null:
				continue
			var lower_name := plant.name.to_lower()
			var is_bush := lower_name.begins_with("bush")
			var is_tree := lower_name.begins_with("tree")
			if not is_tree and not is_bush:
				continue
			_apply_height_variation(plant, is_bush)
			_apply_wind_materials(plant, is_bush)
			if is_bush:
				bush_count += 1
			else:
				tree_count += 1


func set_weather_wind_intensity(intensity: float) -> void:
	# WeatherSystem profiles range from 0.05 in clear weather to 0.72 in a
	# thunderstorm. Normalizing that range retains the approved clear breeze
	# while smoothly building much stronger, less regular storm movement.
	var storm_amount := clampf(inverse_lerp(0.05, 0.72, intensity), 0.0, 1.0)
	var shaped_amount := pow(storm_amount, 1.08)
	var wind_multiplier := lerpf(1.0, storm_wind_multiplier, shaped_amount)
	var speed_multiplier := lerpf(1.0, storm_speed_multiplier, shaped_amount)
	var gustiness := pow(storm_amount, 1.35)
	if (
		is_equal_approx(wind_multiplier, current_weather_wind_multiplier)
		and is_equal_approx(speed_multiplier, current_weather_speed_multiplier)
		and is_equal_approx(gustiness, current_weather_gustiness)
	):
		return
	current_weather_wind_multiplier = wind_multiplier
	current_weather_speed_multiplier = speed_multiplier
	current_weather_gustiness = gustiness
	for material_value in _material_cache.values():
		var material := material_value as ShaderMaterial
		if material == null:
			continue
		material.set_shader_parameter(
			"weather_wind_multiplier",
			current_weather_wind_multiplier
		)
		material.set_shader_parameter(
			"weather_speed_multiplier",
			current_weather_speed_multiplier
		)
		material.set_shader_parameter(
			"weather_gustiness",
			current_weather_gustiness
		)


func _connect_weather_system() -> void:
	_weather_system = get_tree().get_first_node_in_group(
		&"weather_system"
	) as WeatherSystem
	if _weather_system == null:
		return
	set_weather_wind_intensity(_weather_system.get_wind_intensity())
	set_process(true)


func _apply_height_variation(plant: Node3D, is_bush: bool) -> void:
	if plant.has_meta(VARIATION_META):
		return
	var unit_value := _stable_unit_value(str(plant.get_path()))
	var minimum := bush_height_min if is_bush else tree_height_min
	var maximum := bush_height_max if is_bush else tree_height_max
	var varied_scale := plant.scale
	varied_scale.y *= lerpf(minimum, maximum, unit_value)
	plant.scale = varied_scale
	plant.set_meta(VARIATION_META, true)


func _apply_wind_materials(node: Node, is_bush: bool) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in mesh_instance.mesh.get_surface_count():
				var source := mesh_instance.get_surface_override_material(surface_index)
				if source == null:
					source = mesh_instance.mesh.surface_get_material(surface_index)
				if source is BaseMaterial3D:
					mesh_instance.set_surface_override_material(
						surface_index,
						_wind_material(source as BaseMaterial3D, is_bush)
					)
	for child in node.get_children():
		_apply_wind_materials(child, is_bush)


func _wind_material(source: BaseMaterial3D, is_bush: bool) -> ShaderMaterial:
	var kind := "bush" if is_bush else "tree"
	var cache_key := "%s:%s" % [_resource_key(source), kind]
	if _material_cache.has(cache_key):
		return _material_cache[cache_key] as ShaderMaterial

	var material := ShaderMaterial.new()
	material.shader = WIND_SHADER
	material.resource_name = "FB_Wind_%s_%s" % [kind, source.resource_name]
	material.set_shader_parameter("albedo_color", source.albedo_color)
	material.set_shader_parameter("use_albedo_texture", source.albedo_texture != null)
	material.set_shader_parameter("albedo_texture", source.albedo_texture)
	material.set_shader_parameter("roughness", source.roughness)
	material.set_shader_parameter("metallic", source.metallic)
	material.set_shader_parameter("use_normal_texture", source.normal_texture != null)
	material.set_shader_parameter("normal_texture", source.normal_texture)
	material.set_shader_parameter("normal_scale", source.normal_scale)
	material.set_shader_parameter("uv_scale", source.uv1_scale)
	material.set_shader_parameter("uv_offset", source.uv1_offset)
	material.set_shader_parameter(
		"alpha_scissor",
		maxf(source.alpha_scissor_threshold, 0.2)
	)
	if is_bush:
		material.set_shader_parameter("wind_strength", bush_wind_strength)
		material.set_shader_parameter("wind_speed", 0.88)
		material.set_shader_parameter("anchor_height", -0.7)
		material.set_shader_parameter("full_sway_height", 3.0)
		material.set_shader_parameter("flutter_strength", 0.024)
	else:
		material.set_shader_parameter("wind_strength", tree_wind_strength)
		material.set_shader_parameter("wind_speed", 0.72)
		material.set_shader_parameter("anchor_height", 0.0)
		material.set_shader_parameter("full_sway_height", 11.0)
		material.set_shader_parameter("flutter_strength", 0.016)
	material.set_shader_parameter(
		"weather_wind_multiplier",
		current_weather_wind_multiplier
	)
	material.set_shader_parameter(
		"weather_speed_multiplier",
		current_weather_speed_multiplier
	)
	material.set_shader_parameter(
		"weather_gustiness",
		current_weather_gustiness
	)
	_material_cache[cache_key] = material
	return material


func _resource_key(resource: Resource) -> String:
	if not resource.resource_path.is_empty():
		return resource.resource_path
	return "%s:%s:%d" % [
		resource.get_class(),
		resource.resource_name,
		resource.get_instance_id(),
	]


func _stable_unit_value(text: String) -> float:
	var value := 104729
	for byte in text.to_utf8_buffer():
		value = (value * 48271 + int(byte) * 7919) % 2147483647
	return float(value % 10000) / 9999.0
