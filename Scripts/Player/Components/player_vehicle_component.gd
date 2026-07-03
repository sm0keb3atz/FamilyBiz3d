class_name PlayerVehicleComponent
extends Node

signal vehicle_entered(vehicle: Node)
signal vehicle_exited(vehicle: Node)

@export var body_path := NodePath("../..")
@export var visual_path := NodePath("../../Visual")
@export var collision_path := NodePath("../../CollisionShape3D")
@export var on_foot_camera_path := NodePath(
	"../../CameraPivot/SpringArm3D/Camera3D"
)
@export var movement_component_path := NodePath("../MovementComponent")
@export var camera_component_path := NodePath("../CameraComponent")
@export var weapon_component_path := NodePath("../WeaponComponent")
@export var health_component_path := NodePath("../HealthComponent")
@export var interaction_component_path := NodePath("../InteractionComponent")
@export var solicitation_component_path := NodePath("../SolicitationComponent")
@export var sound_component_path := NodePath("../SoundComponent")
@export var menu_controller_path := NodePath("../MenuController")
@export var hud_path := NodePath("../../PlayerHUD")

@onready var body := get_node(body_path) as CharacterBody3D
@onready var visual := get_node(visual_path) as Node3D
@onready var body_collision := get_node(collision_path) as CollisionShape3D
@onready var on_foot_camera := get_node(on_foot_camera_path) as Camera3D
@onready var movement_component := get_node(movement_component_path)
@onready var camera_component := get_node(camera_component_path)
@onready var weapon_component := get_node(weapon_component_path)
@onready var health_component := (
	get_node(health_component_path) as PlayerHealthComponent
)
@onready var interaction_component := get_node(interaction_component_path)
@onready var solicitation_component := get_node(solicitation_component_path)
@onready var sound_component := (
	get_node(sound_component_path) as PlayerSoundComponent
)
@onready var menu_controller := (
	get_node(menu_controller_path) as PlayerMenuController
)
@onready var hud := get_node(hud_path) as PlayerHUD

var _current_vehicle: Variant


func _ready() -> void:
	health_component.downed.connect(_on_player_downed)


func enter_vehicle(vehicle: Variant) -> bool:
	if (
		_current_vehicle != null
		or vehicle == null
		or vehicle.has_driver()
		or not health_component.is_alive()
		or not menu_controller.active_menu.is_empty()
	):
		return false
	if not vehicle.enter_driver(body):
		return false
	_current_vehicle = vehicle
	sound_component.stop_footsteps()
	body.add_collision_exception_with(vehicle)
	_current_vehicle.exit_denied.connect(_on_exit_denied)
	body.velocity = Vector3.ZERO
	visual.visible = false
	body_collision.set_deferred("disabled", true)
	menu_controller.set_gameplay_locked(true)
	_set_on_foot_gameplay_enabled(false)
	vehicle_entered.emit(vehicle)
	return true


func exit_vehicle(force := false) -> bool:
	if _current_vehicle == null:
		return false
	var vehicle: Variant = _current_vehicle
	var exit_position: Vector3 = vehicle.request_exit(body)
	if force and exit_position == Vector3.INF:
		exit_position = vehicle.global_position + Vector3.UP
	if exit_position == Vector3.INF:
		return false
	if vehicle.exit_denied.is_connected(_on_exit_denied):
		vehicle.exit_denied.disconnect(_on_exit_denied)
	vehicle.clear_driver()
	_current_vehicle = null
	body.global_position = exit_position
	body.velocity = Vector3.ZERO
	visual.visible = true
	body_collision.set_deferred("disabled", false)
	menu_controller.set_gameplay_locked(false)
	_set_on_foot_gameplay_enabled(true)
	_schedule_vehicle_collision_restore(vehicle)
	vehicle_exited.emit(vehicle)
	return true


func is_driving() -> bool:
	return _current_vehicle != null


func get_current_vehicle() -> Variant:
	return _current_vehicle


func get_effective_position() -> Vector3:
	return (
		_current_vehicle.global_position
		if _current_vehicle != null
		else body.global_position
	)


func prepare_for_load() -> void:
	if _current_vehicle == null:
		return
	var vehicle: Variant = _current_vehicle
	if vehicle.exit_denied.is_connected(_on_exit_denied):
		vehicle.exit_denied.disconnect(_on_exit_denied)
	vehicle.clear_driver()
	_current_vehicle = null
	visual.visible = true
	body_collision.set_deferred("disabled", false)
	menu_controller.set_gameplay_locked(false)
	_set_on_foot_gameplay_enabled(true)
	_schedule_vehicle_collision_restore(vehicle)
	vehicle_exited.emit(vehicle)


func _set_on_foot_gameplay_enabled(enabled: bool) -> void:
	movement_component.set_physics_process(
		enabled and health_component.is_alive()
	)
	camera_component.set_process(enabled)
	camera_component.set_process_unhandled_input(enabled)
	weapon_component.set_process_unhandled_input(enabled)
	interaction_component.set_gameplay_enabled(enabled)
	solicitation_component.set_gameplay_enabled(enabled)
	on_foot_camera.current = enabled
	if enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_exit_denied(message: String) -> void:
	hud.show_feedback(message)


func _on_player_downed() -> void:
	if _current_vehicle != null:
		exit_vehicle(true)


func _schedule_vehicle_collision_restore(vehicle: PhysicsBody3D) -> void:
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(
		func() -> void:
			if (
				_current_vehicle != vehicle
				and is_instance_valid(body)
				and is_instance_valid(vehicle)
			):
				body.remove_collision_exception_with(vehicle)
	)
