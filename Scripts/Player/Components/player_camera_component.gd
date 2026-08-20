class_name PlayerCameraComponent
extends Node

@export var camera_pivot_path := NodePath("../../CameraPivot")
@export var spring_arm_path := NodePath("../../CameraPivot/SpringArm3D")
@export var camera_path := NodePath("../../CameraPivot/SpringArm3D/Camera3D")
@export var body_path := NodePath("../..")
@export var movement_component_path := NodePath("../MovementComponent")
@export var weapon_component_path := NodePath("../WeaponComponent")
@export var target_lock_component_path := NodePath("../TargetLockComponent")
@export var sound_component_path := NodePath("../SoundComponent")
@export var settings_component_path := NodePath("../GameFeelSettingsComponent")
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

@export_category("Target Lock")
@export_range(0.0, 30.0, 0.1) var lock_camera_assist_speed := 7.5
@export_range(0.0, 1.0, 0.01) var lock_camera_assist_strength := 0.72

@export_category("Cinematic Focus")
@export var default_depth_of_field_enabled := true
@export_range(0.0, 0.1, 0.001) var default_dof_blur_amount := 0.012
@export_range(1.0, 100.0, 0.5) var default_dof_focus_distance := 24.0
@export_range(0.0, 30.0, 0.5) var default_dof_focus_padding := 8.0
@export_range(1.0, 40.0, 0.5) var default_dof_far_transition := 18.0
@export var aim_depth_of_field_enabled := true
@export_range(0.0, 0.2, 0.005) var aim_dof_blur_amount := 0.055
@export_range(1.0, 60.0, 0.5) var aim_dof_default_focus_distance := 14.0
@export_range(1.0, 20.0, 0.25) var aim_dof_minimum_focus_distance := 4.0
@export_range(5.0, 100.0, 0.5) var aim_dof_maximum_focus_distance := 35.0
@export_range(0.0, 10.0, 0.1) var aim_dof_focus_padding := 1.8
@export_range(0.1, 20.0, 0.1) var aim_dof_far_transition := 5.5
@export_range(0.1, 30.0, 0.1) var aim_dof_transition_speed := 6.0

@export_category("Movement Bob")
@export_range(0.0, 0.2, 0.001) var walk_bob_height := 0.032
@export_range(0.0, 0.2, 0.001) var walk_bob_width := 0.02
@export_range(0.1, 20.0, 0.1) var walk_bob_frequency := 7.5
@export_range(1.0, 3.0, 0.05) var sprint_bob_multiplier := 1.85
@export_range(1.0, 3.0, 0.05) var sprint_frequency_multiplier := 1.25
@export_range(0.1, 30.0, 0.1) var bob_transition_speed := 10.0
@export_range(0.0, 3.0, 0.05) var movement_roll_degrees := 0.32
@export_range(0.0, 0.1, 0.001) var acceleration_sway_strength := 0.012
@export_range(0.0, 10.0, 0.1) var sprint_fov_boost := 3.0
@export_range(0.1, 30.0, 0.1) var fov_transition_speed := 8.0

@export_category("Weapon Shake")
@export_range(0.0, 5.0, 0.05) var shot_rotation_degrees := 0.85
@export_range(0.0, 0.2, 0.001) var shot_position_strength := 0.025
@export_range(0.1, 30.0, 0.1) var shot_shake_attack := 22.0
@export_range(0.1, 30.0, 0.1) var shot_shake_decay := 6.0

@export_category("Impact Feedback")
@export_range(0.0, 5.0, 0.05) var damage_rotation_degrees := 1.25
@export_range(0.0, 0.2, 0.001) var damage_position_strength := 0.035
@export_range(0.0, 3.0, 0.05) var near_miss_rotation_degrees := 0.35
@export_range(0.0, 0.2, 0.001) var near_miss_position_strength := 0.01
@export_range(0.0, 0.2, 0.001) var landing_position_strength := 0.032
@export_range(0.1, 30.0, 0.1) var impulse_recovery_speed := 9.0

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
@onready var target_lock_component := (
	get_node_or_null(target_lock_component_path) as PlayerTargetLockComponent
)
@onready var sound_component := (
	get_node(sound_component_path) as PlayerSoundComponent
)
@onready var settings_component := (
	get_node(settings_component_path) as GameFeelSettingsComponent
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
var _camera_base_fov := 75.0
var _lock_assist_suppression := 0.0
var _rotation_impulse := Vector3.ZERO
var _position_impulse := Vector3.ZERO
var _movement_sway := Vector3.ZERO
var _previous_horizontal_velocity := Vector3.ZERO
var _impulse_recovery := 9.0
var _camera_attributes: CameraAttributesPractical
var _dof_focus_distance := 14.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring_arm.spring_length = default_distance
	spring_arm.position.x = default_shoulder_offset
	_camera_base_rotation = camera.rotation
	_camera_base_h_offset = camera.h_offset
	_camera_base_v_offset = camera.v_offset
	_camera_base_fov = camera.fov
	_initialize_aim_depth_of_field()
	weapon_component.fired.connect(_on_weapon_fired)
	sound_component.footstep_played.connect(_on_footstep_played)
	movement_component.landed.connect(_on_landed)


func _process(delta: float) -> void:
	var is_aiming := weapon_component.is_aiming()
	var sight_distance := weapon_component.get_aim_distance_override()
	var target_distance := default_distance
	if is_aiming:
		target_distance = aim_distance
		if sight_distance > 0.0:
			target_distance = sight_distance
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
	if is_aiming:
		_apply_target_lock_camera_assist(delta)
	else:
		_lock_assist_suppression = 0.0
	_update_camera_motion(delta)
	_update_fov(delta, is_aiming)
	_update_aim_depth_of_field(delta, is_aiming)


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
		if (
			target_lock_component != null
			and target_lock_component.has_locked_target()
			and weapon_component.is_aiming()
		):
			_lock_assist_suppression = clampf(
				_lock_assist_suppression + event.relative.length() * 0.025,
				0.0,
				1.0
			)


func get_yaw() -> float:
	return camera_pivot.rotation.y


func get_pitch() -> float:
	return _camera_pitch


func _apply_target_lock_camera_assist(delta: float) -> void:
	if (
		target_lock_component == null
		or not weapon_component.is_target_lock_enabled()
		or not target_lock_component.has_locked_target()
		or lock_camera_assist_strength <= 0.0
	):
		return

	var to_target: Vector3 = (
		target_lock_component.get_lock_point()
		- camera.global_position
	)
	if to_target.length_squared() <= 0.001:
		return

	var horizontal: float = Vector2(to_target.x, to_target.z).length()
	var target_yaw: float = atan2(to_target.x, to_target.z) + PI
	var target_pitch: float = clampf(
		atan2(to_target.y, maxf(horizontal, 0.01)),
		min_camera_pitch,
		max_camera_pitch
	)
	var weight: float = (
		1.0
		- exp(-lock_camera_assist_speed * lock_camera_assist_strength * delta)
	)
	_lock_assist_suppression = move_toward(
		_lock_assist_suppression,
		0.0,
		delta * 1.8
	)
	weight *= 1.0 - _lock_assist_suppression * 0.75
	camera_pivot.rotation.y = lerp_angle(
		camera_pivot.rotation.y,
		target_yaw,
		weight
	)
	_camera_pitch = lerp_angle(_camera_pitch, target_pitch, weight)
	_camera_pitch = clamp(_camera_pitch, min_camera_pitch, max_camera_pitch)
	camera_pivot.rotation.x = _camera_pitch


func _update_camera_motion(delta: float) -> void:
	var horizontal_speed := movement_component.get_horizontal_speed()
	var is_moving := horizontal_speed > 0.2 and body.is_on_floor()
	var is_sprinting := movement_component.is_sprinting()
	var is_aiming := weapon_component.is_aiming()
	var is_crouching := movement_component.is_crouching()
	var speed_reference := run_speed_reference() if is_sprinting else walk_speed_reference()
	var speed_ratio := clampf(horizontal_speed / maxf(speed_reference, 0.01), 0.0, 1.15)
	var bob_multiplier := sprint_bob_multiplier if is_sprinting else 1.0
	if is_aiming:
		bob_multiplier *= 0.42
	if is_crouching:
		bob_multiplier *= 0.34
	bob_multiplier *= settings_component.movement_bob_intensity * speed_ratio
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
		1.0 - exp(-bob_transition_speed * delta)
	)

	var horizontal_velocity := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var acceleration := (horizontal_velocity - _previous_horizontal_velocity) / maxf(delta, 0.001)
	_previous_horizontal_velocity = horizontal_velocity
	var camera_local_acceleration := camera_pivot.global_basis.inverse() * acceleration
	var target_sway := Vector3(
		clampf(-camera_local_acceleration.x * acceleration_sway_strength, -0.025, 0.025),
		clampf(camera_local_acceleration.z * acceleration_sway_strength * 0.35, -0.012, 0.012),
		0.0
	) * settings_component.movement_bob_intensity
	_movement_sway = _movement_sway.lerp(target_sway, 1.0 - exp(-8.0 * delta))

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
	var shake_intensity := settings_component.camera_shake_intensity
	_rotation_impulse = _rotation_impulse.lerp(
		Vector3.ZERO,
		1.0 - exp(-_impulse_recovery * delta)
	)
	_position_impulse = _position_impulse.lerp(
		Vector3.ZERO,
		1.0 - exp(-_impulse_recovery * delta)
	)
	var movement_roll := deg_to_rad(movement_roll_degrees) * (
		cos(_bob_time) * bob_multiplier if is_moving else 0.0
	)
	camera.h_offset = (
		_camera_base_h_offset
		+ _bob_offset.x
		+ _movement_sway.x
		+ shake_wave.x * shot_position_strength * _shot_shake * shake_intensity
		+ _position_impulse.x * shake_intensity
	)
	camera.v_offset = (
		_camera_base_v_offset
		+ _bob_offset.y
		+ _movement_sway.y
		+ shake_wave.y * shot_position_strength * _shot_shake * shake_intensity
		+ _position_impulse.y * shake_intensity
	)
	camera.rotation = (
		_camera_base_rotation
		+ Vector3(0.0, 0.0, movement_roll)
		+ shake_wave * rotation_strength * shake_intensity
		+ _rotation_impulse * shake_intensity
	)


func _on_weapon_fired(_hit_position: Vector3) -> void:
	add_shot_impulse(weapon_component.get_equipped_weapon())


func _on_footstep_played(_is_sprinting: bool) -> void:
	if movement_component.get_horizontal_speed() <= 0.2 or not body.is_on_floor():
		return
	_bob_time = -PI * 0.5
	_bob_step_side *= -1.0


func add_shot_impulse(definition: WeaponDefinition) -> void:
	var pitch_degrees := shot_rotation_degrees
	var yaw_degrees := shot_rotation_degrees * 0.2
	var position_kick := shot_position_strength
	var shake_strength := 1.0
	var recovery := shot_shake_decay
	if definition != null:
		pitch_degrees = definition.visual_recoil_pitch_degrees
		yaw_degrees = definition.visual_recoil_yaw_degrees
		position_kick = definition.visual_recoil_position_kick
		shake_strength = definition.visual_shake_strength
		recovery = definition.visual_recoil_recovery
	_rotation_impulse += Vector3(
		-deg_to_rad(pitch_degrees),
		deg_to_rad(randf_range(-yaw_degrees, yaw_degrees)),
		deg_to_rad(randf_range(-yaw_degrees * 0.35, yaw_degrees * 0.35))
	)
	_position_impulse.y = minf(_position_impulse.y + position_kick * 0.45, 0.045)
	_rotation_impulse.x = maxf(_rotation_impulse.x, deg_to_rad(-3.0))
	_impulse_recovery = maxf(recovery, 0.1)
	_shot_shake_target = minf(_shot_shake_target + shake_strength, 1.35)


func add_damage_impulse(world_direction: Vector3, strength := 1.0) -> void:
	var safe_strength := clampf(strength, 0.2, 1.5)
	var local_direction := camera.global_basis.inverse() * world_direction.normalized()
	_rotation_impulse += Vector3(
		deg_to_rad(damage_rotation_degrees * 0.35 * safe_strength),
		deg_to_rad(-local_direction.x * damage_rotation_degrees * safe_strength),
		deg_to_rad(-local_direction.x * damage_rotation_degrees * 0.65 * safe_strength)
	)
	_position_impulse += Vector3(
		-local_direction.x,
		0.45,
		0.0
	).normalized() * damage_position_strength * safe_strength
	_shot_shake_target = minf(_shot_shake_target + 0.7 * safe_strength, 1.35)
	_impulse_recovery = impulse_recovery_speed


func add_near_miss_impulse(
	world_direction: Vector3,
	proximity_strength: float
) -> void:
	var strength := clampf(proximity_strength, 0.0, 1.0)
	var local_direction := camera.global_basis.inverse() * world_direction.normalized()
	_rotation_impulse += Vector3(
		0.0,
		deg_to_rad(-local_direction.x * near_miss_rotation_degrees * strength),
		deg_to_rad(local_direction.x * near_miss_rotation_degrees * strength)
	)
	_position_impulse.x += -local_direction.x * near_miss_position_strength * strength
	_shot_shake_target = minf(_shot_shake_target + 0.22 * strength, 1.35)
	_impulse_recovery = impulse_recovery_speed * 1.35


func add_landing_feedback(impact_speed: float) -> void:
	var strength := clampf((impact_speed - 2.0) / 8.0, 0.0, 1.0)
	if strength <= 0.0:
		return
	_position_impulse.y -= landing_position_strength * strength
	_rotation_impulse.x += deg_to_rad(0.65 * strength)
	_impulse_recovery = impulse_recovery_speed * 0.75


func _on_landed(impact_speed: float) -> void:
	add_landing_feedback(impact_speed)


func _update_fov(delta: float, is_aiming: bool) -> void:
	var target_fov := _camera_base_fov
	if movement_component.is_sprinting() and not is_aiming:
		target_fov += sprint_fov_boost
	camera.fov = lerpf(
		camera.fov,
		target_fov,
		1.0 - exp(-fov_transition_speed * delta)
	)


func _initialize_aim_depth_of_field() -> void:
	if camera.attributes is CameraAttributesPractical:
		_camera_attributes = (
			camera.attributes.duplicate(true) as CameraAttributesPractical
		)
	else:
		_camera_attributes = CameraAttributesPractical.new()
	_camera_attributes.resource_local_to_scene = true
	_camera_attributes.dof_blur_amount = (
		default_dof_blur_amount if default_depth_of_field_enabled else 0.0
	)
	_camera_attributes.dof_blur_far_enabled = default_depth_of_field_enabled
	_camera_attributes.dof_blur_near_enabled = false
	_camera_attributes.dof_blur_far_distance = (
		default_dof_focus_distance + default_dof_focus_padding
	)
	_camera_attributes.dof_blur_far_transition = default_dof_far_transition
	camera.attributes = _camera_attributes
	_dof_focus_distance = default_dof_focus_distance


func _update_aim_depth_of_field(delta: float, is_aiming: bool) -> void:
	if _camera_attributes == null:
		return
	var should_aim_focus := aim_depth_of_field_enabled and is_aiming
	var default_focus_active := default_depth_of_field_enabled and not should_aim_focus
	var target_amount := 0.0
	if should_aim_focus:
		target_amount = aim_dof_blur_amount
	elif default_focus_active:
		target_amount = default_dof_blur_amount
	if should_aim_focus:
		_camera_attributes.dof_blur_far_enabled = true
		var desired_focus := aim_dof_default_focus_distance
		if (
			target_lock_component != null
			and target_lock_component.has_locked_target()
		):
			desired_focus = camera.global_position.distance_to(
				target_lock_component.get_lock_point()
			)
		desired_focus = clampf(
			desired_focus,
			aim_dof_minimum_focus_distance,
			aim_dof_maximum_focus_distance
		)
		_dof_focus_distance = lerpf(
			_dof_focus_distance,
			desired_focus,
			1.0 - exp(-aim_dof_transition_speed * delta)
		)
		_camera_attributes.dof_blur_far_distance = (
			_dof_focus_distance + aim_dof_focus_padding
		)
		_camera_attributes.dof_blur_far_transition = aim_dof_far_transition
	elif default_focus_active:
		_dof_focus_distance = lerpf(
			_dof_focus_distance,
			default_dof_focus_distance,
			1.0 - exp(-aim_dof_transition_speed * delta)
		)
		_camera_attributes.dof_blur_far_enabled = true
		_camera_attributes.dof_blur_far_distance = (
			_dof_focus_distance + default_dof_focus_padding
		)
		_camera_attributes.dof_blur_far_transition = default_dof_far_transition
	_camera_attributes.dof_blur_amount = lerpf(
		_camera_attributes.dof_blur_amount,
		target_amount,
		1.0 - exp(-aim_dof_transition_speed * delta)
	)
	if not should_aim_focus and not default_focus_active and _camera_attributes.dof_blur_amount <= 0.0005:
		_camera_attributes.dof_blur_amount = 0.0
		_camera_attributes.dof_blur_far_enabled = false


func walk_speed_reference() -> float:
	return maxf(movement_component.walk_speed, 0.01)


func run_speed_reference() -> float:
	return maxf(movement_component.run_speed, walk_speed_reference())
