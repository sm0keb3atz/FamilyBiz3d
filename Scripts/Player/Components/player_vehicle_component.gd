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
@export var animation_component_path := NodePath("../AnimationComponent")
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
@onready var animation_component := get_node(
	animation_component_path
) as PlayerAnimationComponent
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
var _visual_original_parent: Node
var _visual_original_transform := Transform3D.IDENTITY
var _visual_original_index := -1
var _visual_original_visibility := true
var _stowed_weapon_model: Node3D
var _stowed_weapon_visibility := false


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
	sound_component.set_footsteps_enabled(false)
	body.add_collision_exception_with(vehicle)
	_current_vehicle.exit_denied.connect(_on_exit_denied)
	_current_vehicle.tree_exiting.connect(
		_on_current_vehicle_tree_exiting,
		CONNECT_ONE_SHOT
	)
	body.velocity = Vector3.ZERO
	_attach_player_visual(vehicle)
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
	if vehicle.tree_exiting.is_connected(_on_current_vehicle_tree_exiting):
		vehicle.tree_exiting.disconnect(_on_current_vehicle_tree_exiting)
	vehicle.clear_driver()
	_current_vehicle = null
	body.global_position = exit_position
	body.velocity = Vector3.ZERO
	_restore_player_visual()
	body_collision.set_deferred("disabled", false)
	menu_controller.set_gameplay_locked(false)
	_set_on_foot_gameplay_enabled(true)
	sound_component.set_footsteps_enabled(true)
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


func get_safe_save_position() -> Vector3:
	if _current_vehicle == null:
		return body.global_position
	var vehicle: Variant = _current_vehicle
	for marker_path in vehicle.exit_marker_paths:
		var marker := vehicle.get_node_or_null(marker_path) as Marker3D
		if marker != null:
			return marker.global_position
	return vehicle.global_position + vehicle.global_basis.x * 2.5


func get_effective_velocity() -> Vector3:
	return (
		_current_vehicle.linear_velocity
		if _current_vehicle != null
		else body.velocity
	)


func prepare_for_load() -> void:
	var service_menu := body.get_node_or_null("GasStationMenu")
	if service_menu != null and service_menu.has_method("close"):
		service_menu.call("close")
	if _current_vehicle == null:
		return
	var vehicle: Variant = _current_vehicle
	if vehicle.exit_denied.is_connected(_on_exit_denied):
		vehicle.exit_denied.disconnect(_on_exit_denied)
	if vehicle.tree_exiting.is_connected(_on_current_vehicle_tree_exiting):
		vehicle.tree_exiting.disconnect(_on_current_vehicle_tree_exiting)
	vehicle.clear_driver()
	_current_vehicle = null
	_restore_player_visual()
	body_collision.set_deferred("disabled", false)
	menu_controller.set_gameplay_locked(false)
	_set_on_foot_gameplay_enabled(true)
	sound_component.set_footsteps_enabled(true)
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


func _attach_player_visual(vehicle: BaseVehicle) -> void:
	_visual_original_parent = visual.get_parent()
	_visual_original_transform = visual.transform
	_visual_original_index = visual.get_index()
	_visual_original_visibility = visual.visible
	_stowed_weapon_model = weapon_component.get("weapon_model") as Node3D
	if is_instance_valid(_stowed_weapon_model):
		_stowed_weapon_visibility = _stowed_weapon_model.visible
		_stowed_weapon_model.visible = false
	else:
		_stowed_weapon_visibility = false
	animation_component.enter_driving_pose()
	var seat := vehicle.get_driver_marker()
	visual.reparent(seat, false)
	visual.transform = Transform3D.IDENTITY
	visual.visible = true


func _restore_player_visual() -> void:
	if _visual_original_parent != null and is_instance_valid(_visual_original_parent):
		visual.reparent(_visual_original_parent, false)
		visual.transform = _visual_original_transform
		if (
			_visual_original_index >= 0
			and _visual_original_index < _visual_original_parent.get_child_count()
		):
			_visual_original_parent.move_child(visual, _visual_original_index)
	visual.visible = _visual_original_visibility
	animation_component.exit_driving_pose()
	if is_instance_valid(_stowed_weapon_model):
		_stowed_weapon_model.visible = _stowed_weapon_visibility
	_visual_original_parent = null
	_visual_original_index = -1
	_stowed_weapon_model = null


func _on_current_vehicle_tree_exiting() -> void:
	if _current_vehicle == null:
		return
	var vehicle := _current_vehicle as BaseVehicle
	_current_vehicle = null
	body.global_position = vehicle.global_position + Vector3.UP
	body.velocity = Vector3.ZERO
	_restore_player_visual()
	body_collision.set_deferred("disabled", false)
	menu_controller.set_gameplay_locked(false)
	_set_on_foot_gameplay_enabled(true)
	sound_component.set_footsteps_enabled(true)
	body.remove_collision_exception_with(vehicle)
	vehicle_exited.emit(vehicle)


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
