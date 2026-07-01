class_name PlayerCameraComponent
extends Node

@export var camera_pivot_path := NodePath("../../CameraPivot")
@export var spring_arm_path := NodePath("../../CameraPivot/SpringArm3D")
@export var weapon_component_path := NodePath("../WeaponComponent")
@export var camera_sensitivity := 0.003
@export var min_camera_pitch := deg_to_rad(-45.0)
@export var max_camera_pitch := deg_to_rad(30.0)

@export_category("Zoom")
@export var aim_action := &"aim"
@export_range(0.5, 10.0, 0.1) var default_distance := 3.0
@export_range(0.5, 10.0, 0.1) var aim_distance := 2.2
@export_range(0.1, 20.0, 0.1) var zoom_speed := 6.0

@export_category("Shoulder Offset")
@export_range(-2.0, 2.0, 0.05) var default_shoulder_offset := 0.0
@export_range(-2.0, 2.0, 0.05) var aim_shoulder_offset := 0.6
@export_range(0.1, 20.0, 0.1) var shoulder_transition_speed := 4.0

@onready var camera_pivot := get_node(camera_pivot_path) as Node3D
@onready var spring_arm := get_node(spring_arm_path) as SpringArm3D
@onready var weapon_component := (
	get_node(weapon_component_path) as PlayerWeaponComponent
)

var _camera_pitch := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring_arm.spring_length = default_distance
	spring_arm.position.x = default_shoulder_offset


func _process(delta: float) -> void:
	var is_aiming := weapon_component.is_aiming()
	var target_distance := aim_distance if is_aiming else default_distance
	spring_arm.spring_length = move_toward(
		spring_arm.spring_length,
		target_distance,
		zoom_speed * delta
	)
	var target_shoulder_offset := (
		aim_shoulder_offset if is_aiming else default_shoulder_offset
	)
	spring_arm.position.x = move_toward(
		spring_arm.position.x,
		target_shoulder_offset,
		shoulder_transition_speed * delta
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotation.y -= event.relative.x * camera_sensitivity
		_camera_pitch = clamp(
			_camera_pitch - event.relative.y * camera_sensitivity,
			min_camera_pitch,
			max_camera_pitch
		)
		camera_pivot.rotation.x = _camera_pitch


func get_yaw() -> float:
	return camera_pivot.rotation.y


func get_pitch() -> float:
	return _camera_pitch
