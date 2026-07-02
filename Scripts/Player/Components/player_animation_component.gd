class_name PlayerAnimationComponent
extends Node

const AIM_ANIMATION := &"PistolAim"
const IDLE_ANIMATION := &"Idle"
const RELOAD_ANIMATION := &"Pistol_Reload"
const HIPS_TRACK := NodePath("%GeneralSkeleton:Hips")
const CHARACTER_SCALE := 1.75
const SPINE_TRACK := NodePath("%GeneralSkeleton:Spine")
const LEFT_UP_LEG_TRACK := NodePath("%GeneralSkeleton:LeftUpperLeg")
const RIGHT_UP_LEG_TRACK := NodePath("%GeneralSkeleton:RightUpperLeg")
const STRAFE_ANIMATIONS := [&"LeftStrafe", &"RightStrafe"]
const LOOPING_ANIMATIONS := [
	&"Idle",
	&"Walk",
	&"Sprint",
	&"LeftStrafe",
	&"RightStrafe",
	&"LeftStrafeSprint",
	&"RightStrafeSprint",
	&"PistolAim",
	&"RifleAim",
	&"RifleIdle",
]
const RELOAD_EXCLUDED_BONES := [
	&"Hips",
	&"LeftUpperLeg",
	&"LeftLowerLeg",
	&"LeftFoot",
	&"LeftToes",
	&"RightUpperLeg",
	&"RightLowerLeg",
	&"RightFoot",
	&"RightToes",
]

@export_category("Scene References")
@export var animation_tree_path := NodePath("../../AnimationTree")
@export var animation_player_path := NodePath(
	"../../Visual/PlayerTest2/AnimationPlayer"
)
@export var skeleton_path := NodePath(
	"../../Visual/PlayerTest2/Armature/GeneralSkeleton"
)
@export var visual_model_path := NodePath("../../Visual/PlayerTest2")
@export var armature_path := NodePath("../../Visual/PlayerTest2/Armature")

@export_category("Locomotion")
@export var locomotion_blend_parameter := (
	"parameters/Locomotion/BaseLocomotion/blend_position"
)
@export var locomotion_speed_parameter := (
	"parameters/Locomotion/BaseLocomotionSpeed/scale"
)
@export_range(-1.0, 1.0, 0.01) var idle_blend_position := -1.0
@export_range(-1.0, 1.0, 0.01) var walk_blend_position := 0.0
@export_range(-1.0, 1.0, 0.01) var sprint_blend_position := 1.0
@export_range(0.1, 3.0, 0.05) var walk_animation_speed_scale := 2.0

@export_category("Aiming")
@export var aim_blend_parameter := "parameters/Locomotion/AimBlend/blend_amount"
@export var aim_movement_blend_parameter := (
	"parameters/Locomotion/MovementModeBlend/blend_amount"
)
@export var aim_direction_parameter := (
	"parameters/Locomotion/AimMovement/blend_position"
)
@export var aim_movement_speed_parameter := (
	"parameters/Locomotion/AimMovementSpeed/scale"
)
@export var reload_request_parameter := (
	"parameters/Locomotion/ReloadOneShot/request"
)
@export var reload_speed_parameter := (
	"parameters/Locomotion/ReloadSpeed/scale"
)
@export_range(0.1, 3.0, 0.05) var aim_movement_animation_speed_scale := 1.35
@export_range(0.1, 30.0, 0.1) var aim_direction_blend_speed := 8.0
@export_range(0.1, 30.0, 0.1) var aim_pose_blend_speed := 6.0
@export_range(0.1, 30.0, 0.1) var aim_pose_exit_blend_speed := 2.5
@export_range(-2.0, 2.0, 0.05) var vertical_aim_scale := -1.0
@export_range(0.1, 30.0, 0.1) var vertical_aim_speed := 10.0
@export var vertical_aim_bones: Array[StringName] = [
	&"Spine",
	&"Chest",
	&"UpperChest",
]

@export_category("Weapon Recoil")
@export_range(0.0, 30.0, 0.1) var recoil_angle_degrees := 7.0
@export_range(0.1, 60.0, 0.1) var recoil_recovery_speed := 24.0
@export_range(0.0, 1.0, 0.05) var elbow_recoil_scale := 0.45
@export_range(0.0, 1.0, 0.05) var wrist_recoil_scale := 0.25
@export var recoil_elbow_bones: Array[StringName] = [
	&"LeftLowerArm",
	&"RightLowerArm",
]
@export var recoil_wrist_bones: Array[StringName] = [
	&"LeftHand",
	&"RightHand",
]

@onready var animation_tree := get_node(animation_tree_path) as AnimationTree
@onready var animation_player := (
	get_node(animation_player_path) as AnimationPlayer
)
@onready var skeleton := get_node(skeleton_path) as Skeleton3D
@onready var visual_model := get_node(visual_model_path) as Node3D
@onready var armature := get_node(armature_path) as Node3D

var _available_parameters: Dictionary[String, bool] = {}
var _vertical_aim_bone_ids: Array[int] = []
var _recoil_elbow_bone_ids: Array[int] = []
var _recoil_wrist_bone_ids: Array[int] = []
var _target_aim_pitch := 0.0
var _current_aim_pitch := 0.0
var _target_aim_direction := Vector2.ZERO
var _current_aim_direction := Vector2.ZERO
var _target_aim_blend := 0.0
var _current_aim_blend := 0.0
var _recoil_pitch := 0.0
var _reload_remaining := 0.0
var _is_aiming := false


func _ready() -> void:
	visual_model.scale = Vector3.ONE
	armature.scale = Vector3.ONE * CHARACTER_SCALE
	_prepare_runtime_animations()
	animation_tree.active = true
	_cache_parameters()
	_cache_vertical_aim_bones()
	_recoil_elbow_bone_ids = _find_bone_ids(recoil_elbow_bones)
	_recoil_wrist_bone_ids = _find_bone_ids(recoil_wrist_bones)
	_reset_parameters()


func _process(delta: float) -> void:
	var target_pitch := _target_aim_pitch if _is_aiming else 0.0
	_current_aim_pitch = move_toward(
		_current_aim_pitch,
		target_pitch,
		vertical_aim_speed * delta
	)
	_current_aim_direction = _current_aim_direction.move_toward(
		_target_aim_direction,
		aim_direction_blend_speed * delta
	)
	_current_aim_blend = move_toward(
		_current_aim_blend,
		_target_aim_blend,
		(
			aim_pose_blend_speed
			if _target_aim_blend > _current_aim_blend
			else aim_pose_exit_blend_speed
		) * delta
	)
	_recoil_pitch = move_toward(
		_recoil_pitch,
		0.0,
		deg_to_rad(recoil_recovery_speed) * delta
	)
	_reload_remaining = maxf(_reload_remaining - delta, 0.0)
	_set_if_available(aim_direction_parameter, _current_aim_direction)
	_set_if_available(aim_blend_parameter, _current_aim_blend)
	_set_if_available(aim_movement_blend_parameter, _current_aim_blend)
	if animation_tree.active:
		_apply_vertical_aim()


func update_animation(
	horizontal_speed: float,
	move_input: Vector2,
	is_aiming: bool,
	aim_pitch: float,
	walk_speed: float,
	run_speed: float
) -> void:
	var effective_aiming := is_aiming or _reload_remaining > 0.0
	_is_aiming = effective_aiming
	_target_aim_blend = 1.0 if effective_aiming else 0.0
	_target_aim_pitch = aim_pitch * vertical_aim_scale
	_target_aim_direction = (
		Vector2(move_input.x, -move_input.y)
		if effective_aiming
		else Vector2.ZERO
	)
	_update_locomotion(
		horizontal_speed,
		effective_aiming,
		walk_speed,
		run_speed
	)
	_set_if_available(
		aim_movement_speed_parameter,
		aim_movement_animation_speed_scale
		if effective_aiming and move_input.length_squared() > 0.001
		else 1.0
	)


func trigger_recoil() -> void:
	if _is_aiming:
		_recoil_pitch = -deg_to_rad(recoil_angle_degrees)


func trigger_reload(duration: float) -> bool:
	if (
		_reload_remaining > 0.0
		or not animation_player.has_animation(RELOAD_ANIMATION)
		or not _available_parameters.has(reload_request_parameter)
	):
		return false

	_reload_remaining = maxf(duration, 0.01)
	_recoil_pitch = 0.0
	var reload_animation := animation_player.get_animation(RELOAD_ANIMATION)
	_set_if_available(
		reload_speed_parameter,
		reload_animation.length / _reload_remaining
	)
	_set_if_available(
		reload_request_parameter,
		AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	)
	return true


func cancel_reload() -> void:
	if _reload_remaining <= 0.0:
		return

	_reload_remaining = 0.0
	_set_if_available(
		reload_request_parameter,
		AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
	)


func _update_locomotion(
	horizontal_speed: float,
	is_aiming: bool,
	walk_speed: float,
	run_speed: float
) -> void:
	var blend_position := idle_blend_position
	var sprint_blend := clampf(
		inverse_lerp(walk_speed, run_speed, horizontal_speed),
		0.0,
		1.0
	)

	if horizontal_speed > 0.01:
		if horizontal_speed <= walk_speed:
			blend_position = remap(
				horizontal_speed,
				0.0,
				walk_speed,
				idle_blend_position,
				walk_blend_position
			)
		else:
			blend_position = remap(
				horizontal_speed,
				walk_speed,
				run_speed,
				walk_blend_position,
				sprint_blend_position
			)

	_set_if_available(
		locomotion_blend_parameter,
		clamp(blend_position, -1.0, 1.0)
	)
	var playback_scale := 1.0
	if not is_aiming and horizontal_speed > 0.01:
		if horizontal_speed <= walk_speed:
			playback_scale = walk_animation_speed_scale
		else:
			playback_scale = lerpf(
				walk_animation_speed_scale,
				1.0,
				sprint_blend
			)
	_set_if_available(
		locomotion_speed_parameter,
		playback_scale
	)


func _cache_parameters() -> void:
	for property in animation_tree.get_property_list():
		_available_parameters[property.name] = true


func _cache_vertical_aim_bones() -> void:
	_vertical_aim_bone_ids = _find_bone_ids(vertical_aim_bones)


func _find_bone_ids(bone_names: Array[StringName]) -> Array[int]:
	var bone_ids: Array[int] = []
	for bone_name in bone_names:
		var bone_id := skeleton.find_bone(bone_name)
		if bone_id >= 0:
			bone_ids.append(bone_id)
	return bone_ids


func _apply_vertical_aim() -> void:
	if _vertical_aim_bone_ids.is_empty() or _reload_remaining > 0.0:
		return

	var pitch_per_bone := (
		(_current_aim_pitch + _recoil_pitch)
		/ float(_vertical_aim_bone_ids.size())
	)
	_rotate_bones_in_skeleton_space(
		_vertical_aim_bone_ids,
		pitch_per_bone
	)
	_rotate_bones_in_skeleton_space(
		_recoil_elbow_bone_ids,
		_recoil_pitch * elbow_recoil_scale
	)
	_rotate_bones_in_skeleton_space(
		_recoil_wrist_bone_ids,
		_recoil_pitch * wrist_recoil_scale
	)
func _rotate_bones_in_skeleton_space(
	bone_ids: Array[int],
	angle: float
) -> void:
	if is_zero_approx(angle):
		return

	var rotation_basis := Basis(Vector3.RIGHT, angle)
	for bone_id in bone_ids:
		var animated_global_pose := skeleton.get_bone_global_pose(bone_id)
		animated_global_pose.basis = (
			rotation_basis * animated_global_pose.basis
		).orthonormalized()
		skeleton.set_bone_global_pose(bone_id, animated_global_pose)


func _reset_parameters() -> void:
	_set_if_available(locomotion_blend_parameter, idle_blend_position)
	_set_if_available(locomotion_speed_parameter, 1.0)
	_set_if_available(aim_blend_parameter, 0.0)
	_set_if_available(aim_movement_blend_parameter, 0.0)
	_set_if_available(aim_direction_parameter, Vector2.ZERO)
	_set_if_available(aim_movement_speed_parameter, 1.0)
	_set_if_available(reload_speed_parameter, 1.0)


func _set_if_available(parameter_path: String, value: Variant) -> void:
	if _available_parameters.has(parameter_path):
		animation_tree.set(parameter_path, value)


func _prepare_runtime_animations() -> void:
	if not animation_player.has_animation(AIM_ANIMATION):
		return
	if not animation_player.has_animation(IDLE_ANIMATION):
		return

	var aim_animation := animation_player.get_animation(AIM_ANIMATION)
	var idle_animation := animation_player.get_animation(IDLE_ANIMATION)
	var aim_hips_track := aim_animation.find_track(
		HIPS_TRACK,
		Animation.TYPE_ROTATION_3D
	)
	var aim_spine_track := aim_animation.find_track(
		SPINE_TRACK,
		Animation.TYPE_ROTATION_3D
	)
	var idle_hips_track := idle_animation.find_track(
		HIPS_TRACK,
		Animation.TYPE_ROTATION_3D
	)
	if aim_hips_track < 0 or aim_spine_track < 0 or idle_hips_track < 0:
		return

	var aligned_aim := aim_animation.duplicate(true) as Animation
	var base_hips_rotation := idle_animation.rotation_track_interpolate(
		idle_hips_track,
		0.0
	)

	for key_index in aligned_aim.track_get_key_count(aim_spine_track):
		var key_time := aligned_aim.track_get_key_time(aim_spine_track, key_index)
		var aim_hips_rotation := aim_animation.rotation_track_interpolate(
			aim_hips_track,
			key_time
		)
		var aim_spine_rotation := aim_animation.rotation_track_interpolate(
			aim_spine_track,
			key_time
		)
		var hips_correction := base_hips_rotation.inverse() * aim_hips_rotation
		aligned_aim.track_set_key_value(
			aim_spine_track,
			key_index,
			(hips_correction * aim_spine_rotation).normalized()
		)

	var source_library := animation_player.get_animation_library(&"")
	if source_library == null:
		return

	var runtime_library := source_library.duplicate(false) as AnimationLibrary
	runtime_library.remove_animation(AIM_ANIMATION)
	runtime_library.add_animation(AIM_ANIMATION, aligned_aim)

	for strafe_animation_name in STRAFE_ANIMATIONS:
		if not source_library.has_animation(strafe_animation_name):
			continue

		var aligned_strafe := _create_forward_facing_strafe(
			source_library.get_animation(strafe_animation_name),
			base_hips_rotation
		)
		runtime_library.remove_animation(strafe_animation_name)
		runtime_library.add_animation(strafe_animation_name, aligned_strafe)

	if source_library.has_animation(RELOAD_ANIMATION):
		var aligned_reload := _create_upper_body_reload(
			source_library.get_animation(RELOAD_ANIMATION)
		)
		runtime_library.remove_animation(RELOAD_ANIMATION)
		runtime_library.add_animation(RELOAD_ANIMATION, aligned_reload)

	for looping_animation_name in LOOPING_ANIMATIONS:
		if not runtime_library.has_animation(looping_animation_name):
			continue
		var looping_animation := runtime_library.get_animation(
			looping_animation_name
		).duplicate(true) as Animation
		looping_animation.loop_mode = Animation.LOOP_LINEAR
		runtime_library.remove_animation(looping_animation_name)
		runtime_library.add_animation(
			looping_animation_name,
			looping_animation
		)

	for animation_name in runtime_library.get_animation_list():
		var normalized_animation := runtime_library.get_animation(
			animation_name
		).duplicate(true) as Animation
		_remove_armature_scale_tracks(normalized_animation)
		runtime_library.remove_animation(animation_name)
		runtime_library.add_animation(animation_name, normalized_animation)

	animation_player.remove_animation_library(&"")
	animation_player.add_animation_library(&"", runtime_library)


func _create_upper_body_reload(source_animation: Animation) -> Animation:
	var aligned_reload := source_animation.duplicate(true) as Animation
	for track_index in range(
		aligned_reload.get_track_count() - 1,
		-1,
		-1
	):
		var track_type := aligned_reload.track_get_type(track_index)
		if (
			track_type != Animation.TYPE_POSITION_3D
			and track_type != Animation.TYPE_ROTATION_3D
			and track_type != Animation.TYPE_SCALE_3D
		):
			continue
		var track_path := aligned_reload.track_get_path(track_index)
		var bone_name := track_path.get_subname(0)
		var remove_track := (
			track_type == Animation.TYPE_POSITION_3D
			or track_type == Animation.TYPE_SCALE_3D
			or bone_name in RELOAD_EXCLUDED_BONES
			or skeleton.find_bone(bone_name) < 0
		)
		if remove_track:
			aligned_reload.remove_track(track_index)
	return aligned_reload


func _remove_armature_scale_tracks(animation: Animation) -> void:
	for track_index in range(
		animation.get_track_count() - 1,
		-1,
		-1
	):
		if (
			animation.track_get_type(track_index)
			== Animation.TYPE_SCALE_3D
			and animation.track_get_path(track_index)
			== NodePath("Armature")
		):
			animation.remove_track(track_index)


func _create_forward_facing_strafe(
	source_animation: Animation,
	base_hips_rotation: Quaternion
) -> Animation:
	var aligned_strafe := source_animation.duplicate(true) as Animation
	var hips_track := source_animation.find_track(
		HIPS_TRACK,
		Animation.TYPE_ROTATION_3D
	)
	if hips_track < 0:
		return aligned_strafe
	var hips_position_track := source_animation.find_track(
		HIPS_TRACK,
		Animation.TYPE_POSITION_3D
	)

	for leg_path in [LEFT_UP_LEG_TRACK, RIGHT_UP_LEG_TRACK]:
		var leg_track := source_animation.find_track(
			leg_path,
			Animation.TYPE_ROTATION_3D
		)
		if leg_track < 0:
			continue

		for key_index in aligned_strafe.track_get_key_count(leg_track):
			var key_time := aligned_strafe.track_get_key_time(
				leg_track,
				key_index
			)
			var strafe_hips_rotation := source_animation.rotation_track_interpolate(
				hips_track,
				key_time
			)
			var leg_rotation := source_animation.rotation_track_interpolate(
				leg_track,
				key_time
			)
			var hips_correction := (
				base_hips_rotation.inverse() * strafe_hips_rotation
			)
			aligned_strafe.track_set_key_value(
				leg_track,
				key_index,
				(hips_correction * leg_rotation).normalized()
			)

	for key_index in aligned_strafe.track_get_key_count(hips_track):
		aligned_strafe.track_set_key_value(
			hips_track,
			key_index,
			base_hips_rotation
		)

	if hips_position_track >= 0:
		var starting_hips_position := source_animation.position_track_interpolate(
			hips_position_track,
			0.0
		)
		for key_index in aligned_strafe.track_get_key_count(hips_position_track):
			var key_time := aligned_strafe.track_get_key_time(
				hips_position_track,
				key_index
			)
			var hips_position := source_animation.position_track_interpolate(
				hips_position_track,
				key_time
			)
			hips_position.x = starting_hips_position.x
			hips_position.z = starting_hips_position.z
			aligned_strafe.track_set_key_value(
				hips_position_track,
				key_index,
				hips_position
			)

	return aligned_strafe
