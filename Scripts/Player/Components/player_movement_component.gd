class_name PlayerMovementComponent
extends Node

@export_category("Scene References")
@export var body_path := NodePath("../..")
@export var visual_path := NodePath("../../Visual")
@export var camera_component_path := NodePath("../CameraComponent")
@export var animation_component_path := NodePath("../AnimationComponent")
@export var stats_component_path := NodePath("../StatsComponent")
@export var weapon_component_path := NodePath("../WeaponComponent")

@export_category("Movement")
@export var walk_speed := 3.0
@export var run_speed := 6.5
@export var aim_move_speed := 3.0
@export var acceleration := 10.0
@export var deceleration := 36.0
@export var gravity_scale := 1.0
@export var turn_speed := 10.0
@export var steering_speed := 8.0
@export var stop_speed_threshold := 0.15

@export_category("Stamina")
@export_range(0.0, 1000.0, 0.1) var sprint_stamina_per_second := 20.0

@export_category("Aiming")
@export var aim_action := &"aim"
@export var aim_body_turn_speed := 8.0
@export_range(-180.0, 180.0, 0.1) var aim_facing_offset_degrees := 0.0

@export_category("Input")
@export var move_left_action := &"move_left"
@export var move_right_action := &"move_right"
@export var move_forward_action := &"move_forward"
@export var move_back_action := &"move_back"
@export var sprint_action := &"sprint"

@onready var body := get_node(body_path) as CharacterBody3D
@onready var visual := get_node(visual_path) as Node3D
@onready var camera_component := (
	get_node(camera_component_path) as PlayerCameraComponent
)
@onready var animation_component := (
	get_node(animation_component_path) as PlayerAnimationComponent
)
@onready var stats_component := (
	get_node(stats_component_path) as PlayerStatsComponent
)
@onready var weapon_component := (
	get_node(weapon_component_path) as PlayerWeaponComponent
)

var _gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _move_input := Vector2.ZERO
var _is_aiming := false
var _sprint_exhausted := false


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)

	_move_input = Input.get_vector(
		move_left_action,
		move_right_action,
		move_forward_action,
		move_back_action
	)
	_is_aiming = weapon_component.is_aiming()
	if (
		_sprint_exhausted
		and is_equal_approx(
			stats_component.stamina,
			stats_component.get_max_stamina()
		)
	):
		_sprint_exhausted = false

	var wants_to_sprint := (
		Input.is_action_pressed(sprint_action)
		and _move_input != Vector2.ZERO
		and not _is_aiming
	)
	var is_sprinting := wants_to_sprint and not _sprint_exhausted
	if is_sprinting:
		var stamina_cost := sprint_stamina_per_second * delta
		if not stats_component.consume_stamina(stamina_cost):
			stats_component.consume_stamina(stats_component.stamina)
			_sprint_exhausted = true
			is_sprinting = false
		elif is_zero_approx(stats_component.stamina):
			_sprint_exhausted = true
	var camera_basis := Basis(Vector3.UP, camera_component.get_yaw())
	var move_direction := (
		camera_basis * Vector3(_move_input.x, 0.0, _move_input.y)
	).normalized()
	var target_speed := aim_move_speed if _is_aiming else (
		run_speed if is_sprinting else walk_speed
	)
	var horizontal_velocity := Vector3(body.velocity.x, 0.0, body.velocity.z)

	if move_direction != Vector3.ZERO:
		horizontal_velocity = _accelerate(
			horizontal_velocity,
			move_direction,
			target_speed,
			delta
		)
	else:
		horizontal_velocity = horizontal_velocity.move_toward(
			Vector3.ZERO,
			deceleration * delta
		)
		if horizontal_velocity.length() <= stop_speed_threshold:
			horizontal_velocity = Vector3.ZERO

	_update_facing(delta, move_direction)
	body.velocity.x = horizontal_velocity.x
	body.velocity.z = horizontal_velocity.z
	body.move_and_slide()

	animation_component.update_animation(
		Vector2(body.velocity.x, body.velocity.z).length(),
		_move_input,
		_is_aiming,
		camera_component.get_pitch(),
		walk_speed,
		run_speed
	)


func _apply_gravity(delta: float) -> void:
	if not body.is_on_floor():
		body.velocity.y -= _gravity * gravity_scale * delta
	else:
		body.velocity.y = 0.0


func _accelerate(
	current_velocity: Vector3,
	move_direction: Vector3,
	target_speed: float,
	delta: float
) -> Vector3:
	var current_speed := current_velocity.length()
	var next_speed := move_toward(current_speed, target_speed, acceleration * delta)
	var desired_direction := move_direction

	if current_speed > 0.001:
		var current_direction := current_velocity / current_speed
		desired_direction = current_direction.slerp(
			move_direction,
			min(steering_speed * delta, 1.0)
		).normalized()

	return desired_direction * next_speed


func _update_facing(delta: float, move_direction: Vector3) -> void:
	var target_angle: float
	var rotation_speed: float

	if _is_aiming:
		target_angle = (
			camera_component.get_yaw()
			+ PI
			+ deg_to_rad(aim_facing_offset_degrees)
		)
		rotation_speed = aim_body_turn_speed
	elif move_direction != Vector3.ZERO:
		target_angle = atan2(move_direction.x, move_direction.z)
		rotation_speed = turn_speed
	else:
		return

	visual.rotation.y = lerp_angle(
		visual.rotation.y,
		target_angle,
		min(rotation_speed * delta, 1.0)
	)
