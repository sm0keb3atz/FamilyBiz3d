class_name VehicleConditionComponent
extends Node

signal fuel_changed(current_gallons: float, capacity_gallons: float)
signal damage_changed(current_damage: float, maximum_damage: float)
signal appearance_changed
signal performance_tier_changed(tier: int)
signal fuel_empty

const MAXIMUM_DAMAGE := 100.0
const MINIMUM_LIMP_SPEED := 8.0
const ENGINE_FORCE_AT_MAX_DAMAGE := 0.35
const UPGRADE_FORCE_MULTIPLIERS := [1.0, 1.08, 1.16, 1.25]
const UPGRADE_SPEED_MULTIPLIERS := [1.0, 1.05, 1.10, 1.15]

var vehicle: BaseVehicle
var fuel_gallons := -1.0
var damage := 0.0
var primary_color := Color.WHITE
var secondary_color := Color.WHITE
var window_tint := 0.0
var performance_tier := 0

var _previous_position := Vector3.ZERO
var _position_initialized := false
var _primary_materials: Array[BaseMaterial3D] = []
var _secondary_materials: Array[BaseMaterial3D] = []
var _window_materials: Array[BaseMaterial3D] = []
var _primary_factory_colors: Array[Color] = []
var _secondary_factory_colors: Array[Color] = []
var _window_factory_colors: Array[Color] = []


func setup(owner_vehicle: BaseVehicle) -> void:
	vehicle = owner_vehicle
	if fuel_gallons < 0.0:
		fuel_gallons = get_fuel_capacity()
	_cache_customizable_materials()
	fuel_changed.emit(fuel_gallons, get_fuel_capacity())
	damage_changed.emit(damage, MAXIMUM_DAMAGE)


func update(delta: float) -> void:
	if vehicle == null:
		return
	if not _position_initialized:
		_previous_position = vehicle.global_position
		_position_initialized = true
		return
	var distance := vehicle.global_position.distance_to(_previous_position)
	_previous_position = vehicle.global_position
	if vehicle.is_managed_traffic() or not vehicle.has_driver() or fuel_gallons <= 0.0:
		return
	var burn := distance * vehicle.definition.fuel_gallons_per_meter
	if vehicle.audio_component.engine_ready:
		burn += (
			vehicle.definition.idle_fuel_gallons_per_real_minute
			* delta / 60.0
		)
	consume_fuel(burn)


func get_fuel_capacity() -> float:
	return vehicle.definition.fuel_tank_capacity_gallons if vehicle != null else 1.0


func get_fuel_gallons() -> float:
	return fuel_gallons


func get_damage() -> float:
	return damage


func get_primary_color() -> Color:
	return primary_color


func get_secondary_color() -> Color:
	return secondary_color


func get_window_tint() -> float:
	return window_tint


func get_performance_tier() -> int:
	return performance_tier


func get_fuel_ratio() -> float:
	return clampf(fuel_gallons / maxf(get_fuel_capacity(), 0.001), 0.0, 1.0)


func has_fuel() -> bool:
	return fuel_gallons > 0.0001


func consume_fuel(amount: float) -> float:
	if amount <= 0.0 or fuel_gallons <= 0.0:
		return 0.0
	var previous := fuel_gallons
	fuel_gallons = maxf(fuel_gallons - amount, 0.0)
	var consumed := previous - fuel_gallons
	if consumed > 0.0:
		fuel_changed.emit(fuel_gallons, get_fuel_capacity())
	if previous > 0.0 and is_zero_approx(fuel_gallons):
		fuel_empty.emit()
	return consumed


func add_fuel(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var previous := fuel_gallons
	fuel_gallons = minf(fuel_gallons + amount, get_fuel_capacity())
	var added := fuel_gallons - previous
	if added > 0.0:
		fuel_changed.emit(fuel_gallons, get_fuel_capacity())
	return added


func apply_damage(amount: float) -> float:
	if amount <= 0.0 or vehicle == null or vehicle.is_managed_traffic():
		return 0.0
	var previous := damage
	damage = clampf(damage + amount, 0.0, MAXIMUM_DAMAGE)
	var applied := damage - previous
	if applied > 0.0:
		damage_changed.emit(damage, MAXIMUM_DAMAGE)
	return applied


func repair_full() -> float:
	var repaired := damage
	damage = 0.0
	if repaired > 0.0:
		damage_changed.emit(damage, MAXIMUM_DAMAGE)
	return repaired


func get_effective_engine_force() -> float:
	var upgraded: float = vehicle.definition.engine_force * float(UPGRADE_FORCE_MULTIPLIERS[performance_tier])
	return upgraded * lerpf(1.0, ENGINE_FORCE_AT_MAX_DAMAGE, damage / MAXIMUM_DAMAGE)


func get_effective_reverse_engine_force() -> float:
	var upgraded: float = vehicle.definition.reverse_engine_force * float(UPGRADE_FORCE_MULTIPLIERS[performance_tier])
	return upgraded * lerpf(1.0, ENGINE_FORCE_AT_MAX_DAMAGE, damage / MAXIMUM_DAMAGE)


func get_effective_max_forward_speed() -> float:
	var upgraded: float = vehicle.definition.max_forward_speed * float(UPGRADE_SPEED_MULTIPLIERS[performance_tier])
	return lerpf(upgraded, MINIMUM_LIMP_SPEED, damage / MAXIMUM_DAMAGE)


func set_performance_tier(value: int) -> bool:
	var next := clampi(value, 0, 3)
	if next == performance_tier:
		return false
	performance_tier = next
	performance_tier_changed.emit(performance_tier)
	return true


func set_primary_color(color: Color) -> void:
	primary_color = color
	_apply_color(_primary_materials, primary_color)
	appearance_changed.emit()


func set_secondary_color(color: Color) -> void:
	secondary_color = color
	_apply_color(_secondary_materials, secondary_color)
	appearance_changed.emit()


func set_window_tint(value: float) -> void:
	window_tint = clampf(value, 0.0, 1.0)
	for index in _window_materials.size():
		var factory := _window_factory_colors[index]
		_window_materials[index].albedo_color = get_tinted_window_color(
			factory,
			window_tint
		)
	appearance_changed.emit()


static func get_tinted_window_color(factory: Color, tint: float) -> Color:
	var safe_tint := clampf(tint, 0.0, 1.0)
	var tinted := factory.lerp(
		Color(0.015, 0.02, 0.03, 1.0),
		safe_tint
	)
	var opacity_strength := clampf(safe_tint / 0.9, 0.0, 1.0)
	tinted.a = lerpf(factory.a, 1.0, opacity_strength * opacity_strength)
	return tinted


static func apply_appearance_to_visual(
	visual: Node3D,
	definition: VehicleDefinition,
	state: Dictionary
) -> void:
	if visual == null or definition == null or state.is_empty():
		return
	var candidates: Array[MeshInstance3D] = []
	var maximum_surfaces := 0
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var count := mesh_instance.mesh.get_surface_count()
		if count > maximum_surfaces:
			maximum_surfaces = count
			candidates.clear()
		if count == maximum_surfaces:
			candidates.append(mesh_instance)
	var primary := _saved_color(state, "primary_color")
	var secondary := _saved_color(state, "secondary_color")
	var tint := clampf(float(state.get("window_tint", 0.0)), 0.0, 1.0)
	for mesh_instance in candidates:
		_apply_preview_color(
			mesh_instance, definition.primary_surface_indices, primary
		)
		_apply_preview_color(
			mesh_instance, definition.secondary_surface_indices, secondary
		)
		_apply_preview_tint(
			mesh_instance, definition.window_surface_indices, tint
		)


static func _saved_color(state: Dictionary, key: String) -> Color:
	var value: Variant = state.get(key)
	if value is Color:
		return value as Color
	var encoded := ""
	if value != null:
		encoded = String(value)
	return Color(encoded) if Color.html_is_valid(encoded) else Color(-1, -1, -1, -1)


static func _apply_preview_color(
	mesh_instance: MeshInstance3D,
	indices: Array[int],
	color: Color
) -> void:
	if color.r < 0.0:
		return
	for surface_index in indices:
		var material := _duplicate_preview_material(mesh_instance, surface_index)
		if material == null:
			continue
		var next := color
		next.a = material.albedo_color.a
		material.albedo_color = next


static func _apply_preview_tint(
	mesh_instance: MeshInstance3D,
	indices: Array[int],
	tint: float
) -> void:
	for surface_index in indices:
		var material := _duplicate_preview_material(mesh_instance, surface_index)
		if material != null:
			material.albedo_color = get_tinted_window_color(
				material.albedo_color,
				tint
			)


static func _duplicate_preview_material(
	mesh_instance: MeshInstance3D,
	surface_index: int
) -> BaseMaterial3D:
	if (
		mesh_instance.mesh == null
		or surface_index < 0
		or surface_index >= mesh_instance.mesh.get_surface_count()
	):
		return null
	var source := mesh_instance.get_active_material(surface_index) as BaseMaterial3D
	if source == null:
		return null
	var local := source.duplicate(true) as BaseMaterial3D
	mesh_instance.set_surface_override_material(surface_index, local)
	return local


func export_state() -> Dictionary:
	return {
		"fuel_gallons": fuel_gallons,
		"damage": damage,
		"primary_color": primary_color.to_html(true),
		"secondary_color": secondary_color.to_html(true),
		"window_tint": window_tint,
		"performance_tier": performance_tier,
	}


func import_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	fuel_gallons = clampf(
		float(state.get("fuel_gallons", get_fuel_capacity())),
		0.0,
		get_fuel_capacity()
	)
	damage = clampf(float(state.get("damage", 0.0)), 0.0, MAXIMUM_DAMAGE)
	primary_color = _decode_color(state.get("primary_color", primary_color), primary_color)
	secondary_color = _decode_color(state.get("secondary_color", secondary_color), secondary_color)
	window_tint = clampf(float(state.get("window_tint", 0.0)), 0.0, 1.0)
	performance_tier = clampi(int(state.get("performance_tier", 0)), 0, 3)
	_apply_color(_primary_materials, primary_color)
	_apply_color(_secondary_materials, secondary_color)
	set_window_tint(window_tint)
	fuel_changed.emit(fuel_gallons, get_fuel_capacity())
	damage_changed.emit(damage, MAXIMUM_DAMAGE)
	performance_tier_changed.emit(performance_tier)


func _cache_customizable_materials() -> void:
	_primary_materials.clear()
	_secondary_materials.clear()
	_window_materials.clear()
	_primary_factory_colors.clear()
	_secondary_factory_colors.clear()
	_window_factory_colors.clear()
	var candidates: Array[MeshInstance3D] = []
	var maximum_surfaces := 0
	for node in vehicle.visual_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var count := mesh_instance.mesh.get_surface_count()
		if count > maximum_surfaces:
			maximum_surfaces = count
			candidates.clear()
		if count == maximum_surfaces:
			candidates.append(mesh_instance)
	for mesh_instance in candidates:
		_cache_surface_group(mesh_instance, vehicle.definition.primary_surface_indices, _primary_materials, _primary_factory_colors)
		_cache_surface_group(mesh_instance, vehicle.definition.secondary_surface_indices, _secondary_materials, _secondary_factory_colors)
		_cache_surface_group(mesh_instance, vehicle.definition.window_surface_indices, _window_materials, _window_factory_colors)
	if not _primary_factory_colors.is_empty():
		primary_color = _primary_factory_colors[0]
	if not _secondary_factory_colors.is_empty():
		secondary_color = _secondary_factory_colors[0]


func _cache_surface_group(
	mesh_instance: MeshInstance3D,
	indices: Array[int],
	materials: Array[BaseMaterial3D],
	factory_colors: Array[Color]
) -> void:
	for surface_index in indices:
		if surface_index < 0 or surface_index >= mesh_instance.mesh.get_surface_count():
			continue
		var source := mesh_instance.get_active_material(surface_index) as BaseMaterial3D
		if source == null:
			continue
		var local := source.duplicate(true) as BaseMaterial3D
		mesh_instance.set_surface_override_material(surface_index, local)
		materials.append(local)
		factory_colors.append(local.albedo_color)


func _apply_color(materials: Array[BaseMaterial3D], color: Color) -> void:
	for material in materials:
		var next := color
		next.a = material.albedo_color.a
		material.albedo_color = next


func _decode_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value as Color
	var encoded := String(value)
	return Color(encoded) if Color.html_is_valid(encoded) else fallback
