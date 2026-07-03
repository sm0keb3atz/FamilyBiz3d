class_name PlayerMenuController
extends Node

signal active_menu_changed(menu_id: StringName)

@export var movement_component_path := NodePath("../MovementComponent")
@export var camera_component_path := NodePath("../CameraComponent")
@export var weapon_component_path := NodePath("../WeaponComponent")
@export var health_component_path := NodePath("../HealthComponent")
@export var interaction_component_path := NodePath("../InteractionComponent")
@export var solicitation_component_path := NodePath("../SolicitationComponent")

var active_menu: StringName = &""
var _gameplay_locked := false

@onready var movement_component := get_node(movement_component_path)
@onready var camera_component := get_node(camera_component_path)
@onready var weapon_component := get_node(weapon_component_path)
@onready var health_component := get_node(health_component_path)
@onready var interaction_component := get_node(interaction_component_path)
@onready var solicitation_component := get_node(solicitation_component_path)


func request_open(menu_id: StringName) -> bool:
	if (
		_gameplay_locked
		or menu_id.is_empty()
		or not active_menu.is_empty()
	):
		return false

	active_menu = menu_id
	_apply_gameplay_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	active_menu_changed.emit(active_menu)
	return true


func close(menu_id: StringName) -> bool:
	if active_menu != menu_id:
		return false

	active_menu = &""
	_apply_gameplay_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	active_menu_changed.emit(active_menu)
	return true


func is_open(menu_id: StringName) -> bool:
	return active_menu == menu_id


func set_gameplay_locked(locked: bool) -> void:
	_gameplay_locked = locked


func _apply_gameplay_enabled(enabled: bool) -> void:
	enabled = enabled and not _gameplay_locked
	movement_component.set_physics_process(
		enabled and health_component.is_alive()
	)
	camera_component.set_process_unhandled_input(enabled)
	weapon_component.set_process_unhandled_input(enabled)
	interaction_component.set_gameplay_enabled(enabled)
	solicitation_component.set_gameplay_enabled(enabled)
