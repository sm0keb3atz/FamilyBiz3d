class_name PlayerCameraComponent
extends Node

@export var camera_pivot_path := NodePath("../../CameraPivot")
@export var spring_arm_path := NodePath("../../CameraPivot/SpringArm3D")
@export var camera_path := NodePath("../../CameraPivot/SpringArm3D/Camera3D")
@export var body_path := NodePath("../..")
@export var movement_component_path := NodePath("../MovementComponent")
@export var weapon_component_path := NodePath("../WeaponComponent")
@export var sound_component_path := NodePath("../SoundComponent")
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

@export_category("Movement Bob")
@export_range(0.0, 0.2, 0.001) var walk_bob_height := 0.032
@export_range(0.0, 0.2, 0.001) var walk_bob_width := 0.02
@export_range(0.1, 20.0, 0.1) var walk_bob_frequency := 7.5
@export_range(1.0, 3.0, 0.05) var sprint_bob_multiplier := 1.85
@export_range(1.0, 3.0, 0.05) var sprint_frequency_multiplier := 1.25
@export_range(0.1, 30.0, 0.1) var bob_transition_speed := 10.0

@export_category("Weapon Shake")
@export_range(0.0, 5.0, 0.05) var shot_rotation_degrees := 0.85
@export_range(0.0, 0.2, 0.001) var shot_position_strength := 0.025
@export_range(0.1, 30.0, 0.1) var shot_shake_attack := 22.0
@export_range(0.1, 30.0, 0.1) var shot_shake_decay := 6.0

@onready var camera_pivot := get_node(camera_pivot_path) as Node3D
@onready var spring_arm := get_node(spring_arm_path) as SpringArm3D
@onready var camera := get_node(camera_path) as Camera3D
@onready var body := get_node(body_path) as CharacterBody3D
@onready var movement_component := (
	get_node(movement_component_path) as PlayerMovementComponent
)
@onready var weapon_component := (
	get_node(weapon_component_path) as PlayerWeaponComponent
)
@onready var sound_component := (
	get_node(sound_component_path) as PlayerSoundComponent
)

var _camera_pitch := 0.0
var _bob_time := 0.0
var _bob_offset := Vector3.ZERO
var _bob_step_side := 1.0
var _shot_shake := 0.0
var _shot_shake_target := 0.0
var _shot_shake_time := 0.0
var _camera_base_rotation := Vector3.ZERO
var _camera_base_h_offset := 0.0
var _camera_base_v_offset := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring_arm.spring_length = default_distance
	spring_arm.position.x = default_shoulder_offset
	_camera_base_rotation = camera.rotation
	_camera_base_h_offset = camera.h_offset
	_camera_base_v_offset = camera.v_offset
	weapon_component.fired.connect(_on_weapon_fired)
	sound_component.footstep_played.connect(_on_footstep_played)


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
	_update_camera_motion(delta)


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


func _update_camera_motion(delta: float) -> void:
	var horizontal_speed := movement_component.get_horizontal_speed()
	var is_moving := horizontal_speed > 0.2 and body.is_on_floor()
	var is_sprinting := movement_component.is_sprinting()
	var bob_multiplier := sprint_bob_multiplier if is_sprinting else 1.0
	var bob_frequency := walk_bob_frequency * (
		sprint_frequency_multiplier if is_sprinting else 1.0
	)
	var target_bob := Vector3.ZERO
	if is_moving:
		_bob_time += delta * bob_frequency
		target_bob = Vector3(
			cos(_bob_time) * walk_bob_width * bob_multiplier * _bob_step_side,
			sin(_bob_time) * walk_bob_height * bob_multiplier,
			0.0
		)
	else:
		_bob_time = 0.0
	_bob_offset = _bob_offset.lerp(
		target_bob,
		minf(bob_transition_speed * delta, 1.0)
	)

	_shot_shake_time += delta
	_shot_shake_target *= exp(-shot_shake_decay * delta)
	_shot_shake = lerpf(
		_shot_shake,
		_shot_shake_target,
		1.0 - exp(-shot_shake_attack * delta)
	)
	if _shot_shake < 0.001 and _shot_shake_target < 0.001:
		_shot_shake = 0.0
		_shot_shake_target = 0.0
	var shake_wave := Vector3(
		sin(_shot_shake_time * 18.0),
		sin(_shot_shake_time * 23.0),
		sin(_shot_shake_time * 27.0)
	)
	var rotation_strength := deg_to_rad(shot_rotation_degrees) * _shot_shake
	camera.h_offset = (
		_camera_base_h_offset
		+ _bob_offset.x
		+ shake_wave.x * shot_position_strength * _shot_shake
	)
	camera.v_offset = (
		_camera_base_v_offset
		+ _bob_offset.y
		+ shake_wave.y * shot_position_strength * _shot_shake
	)
	camera.rotation = _camera_base_rotation + shake_wave * rotation_strength


func _on_weapon_fired(_hit_position: Vector3) -> void:
	_shot_shake_target = minf(_shot_shake_target + 1.0, 1.35)


func _on_footstep_played(_is_sprinting: bool) -> void:
	if movement_component.get_horizontal_speed() <= 0.2 or not body.is_on_floor():
		return
	_bob_time = -PI * 0.5
	_bob_step_side *= -1.0
