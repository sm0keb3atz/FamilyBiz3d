class_name PlayerConsumableComponent
extends Node

signal effect_state_changed
signal item_used(item: ConsumableDefinition, message: String, success: bool)

@export var inventory_component_path := NodePath("../InventoryComponent")
@export var stats_component_path := NodePath("../StatsComponent")
@export var health_component_path := NodePath("../HealthComponent")
@export var player_path := NodePath("../..")

@onready var inventory := get_node(inventory_component_path) as PlayerInventoryComponent
@onready var stats := get_node(stats_component_path) as PlayerStatsComponent
@onready var health := get_node(health_component_path) as PlayerHealthComponent
@onready var player := get_node(player_path) as CharacterBody3D

var health_regen_until_minute := -1
var stamina_regen_until_minute := -1
var _world_time: WorldTimeComponent


func _ready() -> void:
	call_deferred("_resolve_world_time")


func use(item: ConsumableDefinition) -> bool:
	if item == null or not inventory.has_consumable(item) or not health.is_alive():
		return _finish(item, "Cannot use that item right now.", false)
	if item.vehicle_fuel_gallons > 0.0:
		var vehicle := _find_nearby_vehicle()
		if vehicle == null:
			return _finish(item, "Move within 4 meters of a vehicle.", false)
		if vehicle.condition_component.add_fuel(item.vehicle_fuel_gallons) <= 0.0:
			return _finish(item, "That vehicle's tank is already full.", false)
		inventory.remove_consumable(item)
		return _finish(item, "Added one gallon of fuel.", true)
	var health_useful := item.health_restore > 0.0 and stats.health < stats.get_max_health()
	var stamina_useful := item.stamina_restore > 0.0 and stats.stamina < stats.get_max_stamina()
	if not health_useful and not stamina_useful and not item.has_timed_effect():
		return _finish(item, "Your health and stamina are already full.", false)
	if not inventory.remove_consumable(item):
		return _finish(item, "That item is unavailable.", false)
	stats.heal(item.health_restore)
	stats.restore_stamina(item.stamina_restore)
	var now := _get_absolute_minute()
	if item.health_regen_multiplier > 1.0:
		health_regen_until_minute = now + item.duration_game_minutes
	if item.stamina_regen_multiplier > 1.0:
		stamina_regen_until_minute = now + item.duration_game_minutes
	_refresh_effects(now)
	return _finish(item, "Used %s." % item.display_name, true)


func export_save_data() -> Dictionary:
	return {
		"health_regen_until_minute": health_regen_until_minute,
		"stamina_regen_until_minute": stamina_regen_until_minute,
	}


func import_save_data(data: Dictionary) -> void:
	health_regen_until_minute = int(data.get("health_regen_until_minute", -1))
	stamina_regen_until_minute = int(data.get("stamina_regen_until_minute", -1))
	call_deferred("_refresh_effects", _get_absolute_minute())


func reset_to_new_game() -> void:
	import_save_data({})


func _resolve_world_time() -> void:
	_world_time = get_tree().get_first_node_in_group(&"world_time") as WorldTimeComponent
	if _world_time != null and not _world_time.minute_advanced.is_connected(_refresh_effects):
		_world_time.minute_advanced.connect(_refresh_effects)
	if _world_time != null and not _world_time.calendar_skipped.is_connected(_on_calendar_skipped):
		_world_time.calendar_skipped.connect(_on_calendar_skipped)
	_refresh_effects(_get_absolute_minute())


func _on_calendar_skipped(
	_from_absolute_minute: int,
	to_absolute_minute: int,
	_reason: StringName
) -> void:
	_refresh_effects(to_absolute_minute)


func _refresh_effects(absolute_minute: int) -> void:
	stats.health_regen_multiplier = 2.0 if health_regen_until_minute > absolute_minute else 1.0
	stats.stamina_regen_multiplier = 2.0 if stamina_regen_until_minute > absolute_minute else 1.0
	effect_state_changed.emit()


func _find_nearby_vehicle() -> BaseVehicle:
	var nearest: BaseVehicle
	var nearest_distance := 4.0
	var nearest_full: BaseVehicle
	var nearest_full_distance := 4.0
	for node in get_tree().get_nodes_in_group(&"interactable"):
		var vehicle := node as BaseVehicle
		if vehicle == null or vehicle.is_managed_traffic():
			continue
		var distance := player.global_position.distance_to(vehicle.global_position)
		var needs_fuel := (
			vehicle.condition_component.fuel_gallons
			< vehicle.condition_component.get_fuel_capacity() - 0.001
		)
		if needs_fuel and distance <= nearest_distance:
			nearest = vehicle
			nearest_distance = distance
		elif not needs_fuel and distance <= nearest_full_distance:
			nearest_full = vehicle
			nearest_full_distance = distance
	return nearest if nearest != null else nearest_full


func _get_absolute_minute() -> int:
	return _world_time.get_absolute_minute() if _world_time != null else 0


func _finish(item: ConsumableDefinition, message: String, success: bool) -> bool:
	item_used.emit(item, message, success)
	return success
