class_name NPCAnimationComponent
extends Node

static var _shared_runtime_animation_library: AnimationLibrary

const LOOPING_ANIMATIONS := [
	&"Idle", &"Walk", &"FemaleWalk", &"Sprint", &"LeftStrafe",
	&"RightStrafe", &"PistolAim", &"LeaningOnWall1", &"LeaningOnWall2",
	&"Talking", &"TextingWalking1", &"TextingWalking2",
]
const HIT_REACTION_ANIMATIONS := [&"Hit_Head", &"Hit_Chest"]
const HIT_REACTION_INCLUDED_BONES := [
	&"Spine", &"Chest", &"UpperChest", &"Neck", &"Head",
]
const CHARACTER_SCALE := 1.75
const NPC_VISUAL_SCALE_MULTIPLIER := 1.0
const COMBAT_ANIMATIONS := [&"PistolAim", &"Pistol_Reload"]
const LOWER_BODY_BONES := [
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
const COMBAT_AIM_BONES := [&"Spine", &"Chest", &"UpperChest"]
const HIPS_TRACK := NodePath("%GeneralSkeleton:Hips")
const SPINE_TRACK := NodePath("%GeneralSkeleton:Spine")
const LEFT_UP_LEG_TRACK := NodePath("%GeneralSkeleton:LeftUpperLeg")
const RIGHT_UP_LEG_TRACK := NodePath("%GeneralSkeleton:RightUpperLeg")
const TEXTING_ARM_BLEND := {
	&"LeftShoulder": 0.72,
	&"RightShoulder": 0.72,
	&"LeftUpperArm": 0.86,
	&"RightUpperArm": 0.86,
}

@export_category("Locomotion")
@export var locomotion_blend_parameter := (
	"parameters/BaseLocomotion/blend_position"
)
@export var locomotion_speed_parameter := (
	"parameters/BaseLocomotionSpeed/scale"
)
@export var aim_movement_blend_parameter := (
	"parameters/MovementModeBlend/blend_amount"
)
@export var aim_direction_parameter := (
	"parameters/AimMovement/blend_position"
)
@export var aim_movement_speed_parameter := (
	"parameters/AimMovementSpeed/scale"
)
@export_range(0.1, 3.0, 0.05) var walk_animation_speed_scale := 2.0
@export_range(0.1, 3.0, 0.05) var sprint_animation_speed_scale := 1.65
@export_range(0.1, 2.0, 0.05) var foot_slide_correction_scale := 1.15
@export_range(0.1, 10.0, 0.1) var animation_walk_reference_speed := 2.5
@export_range(0.2, 15.0, 0.1) var animation_sprint_reference_speed := 6.5
@export_range(0.1, 3.0, 0.05) var aim_movement_animation_speed_scale := 1.35
@export_range(0.1, 30.0, 0.1) var aim_direction_blend_speed := 8.0

@export_category("Damage Reactions")
@export_range(0.5, 3.0, 0.05) var head_hit_height := 1.45
@export_range(0.0, 0.5, 0.01) var hit_reaction_blend_time := 0.08
@export_range(0.0, 0.5, 0.01) var hit_reaction_exit_lead_time := 0.08
@export_range(0.1, 2.0, 0.05) var hit_reaction_duration := 0.45

@export_category("Combat")
@export var combat_aim_blend_parameter := (
	"parameters/AimBlend/blend_amount"
)
@export var combat_reload_request_parameter := (
	"parameters/ReloadOneShot/request"
)
@export var combat_reload_speed_parameter := (
	"parameters/ReloadSpeed/scale"
)

var npc
var _hit_reaction_remaining := 0.0
var _hit_reaction_player: AnimationPlayer
var _combat_animation_player: AnimationPlayer
var _activity_animation_player: AnimationPlayer
var _instance_runtime_animation_library: AnimationLibrary
var _locomotion_walk_node: AnimationNodeAnimation
var _current_walk_variant := &"Walk"
var _last_locomotion_blend := INF
var _last_locomotion_scale := INF
var _combat_aiming := false
var _combat_aim_pitch := 0.0
var _combat_recoil_pitch := 0.0
var _combat_reload_remaining := 0.0
var _combat_aim_bone_ids: Array[int] = []
var _target_aim_direction := Vector2.ZERO
var _current_aim_direction := Vector2.ZERO


func initialize(owner_npc: CharacterBody3D) -> void:
	npc = owner_npc
	_apply_character_visual_scale()
	_configure_looping_animations()
	_configure_instance_animation_tree()
	_create_hit_reaction_layer()
	_create_activity_animation_layer()
	_cache_combat_aim_bones()
	npc.animation_tree.active = true
	update_locomotion_animation()
	var notifier := npc.get_node(
		"VisibilityNotifier3D"
	) as VisibleOnScreenNotifier3D
	notifier.screen_entered.connect(_refresh_animation_processing)
	notifier.screen_exited.connect(_refresh_animation_processing)
	_refresh_animation_processing()
	set_process(false)


func _process(delta: float) -> void:
	if npc.is_defeated():
		set_process(false)
		return
	if _hit_reaction_remaining > 0.0:
		_hit_reaction_remaining = maxf(
			_hit_reaction_remaining - delta,
			0.0
		)
	if is_zero_approx(_hit_reaction_remaining):
		if _hit_reaction_player != null:
			_hit_reaction_player.stop()
	_combat_recoil_pitch = move_toward(
		_combat_recoil_pitch,
		0.0,
		deg_to_rad(24.0) * delta
	)
	_combat_reload_remaining = maxf(
		_combat_reload_remaining - delta,
		0.0
	)
	_current_aim_direction = _current_aim_direction.move_toward(
		_target_aim_direction,
		aim_direction_blend_speed * delta
	)
	npc.animation_tree.set(
		aim_direction_parameter,
		_current_aim_direction
	)
	if (
		is_zero_approx(_combat_reload_remaining)
		and _combat_aiming
		and _combat_animation_player != null
		and not _combat_animation_player.is_playing()
	):
		_combat_animation_player.play(&"PistolAim", 0.12)
	if _combat_aiming and is_zero_approx(_combat_reload_remaining):
		_apply_combat_aim_pose()
	if (
		is_zero_approx(_hit_reaction_remaining)
		and not _combat_aiming
		and is_zero_approx(_combat_recoil_pitch)
		and is_zero_approx(_combat_reload_remaining)
	):
		set_process(false)


func set_visual_animation_active(enabled: bool) -> void:
	npc.animation_tree.active = enabled and not npc.is_defeated()
	if not npc.animation_tree.active:
		npc.animation_player.stop()
		if _activity_animation_player != null:
			_activity_animation_player.stop()
		_last_locomotion_blend = INF
		_last_locomotion_scale = INF
	else:
		update_locomotion_animation()
	_refresh_animation_processing()


func set_walk_variant(animation_name: StringName) -> bool:
	if (
		_instance_runtime_animation_library == null
		or _locomotion_walk_node == null
		or not _instance_runtime_animation_library.has_animation(animation_name)
	):
		return false
	if (
		_current_walk_variant == animation_name
		and _locomotion_walk_node.animation == animation_name
	):
		return true
	_locomotion_walk_node.animation = animation_name
	_current_walk_variant = animation_name
	_last_locomotion_blend = INF
	update_locomotion_animation()
	return true


func use_sex_appropriate_walk() -> void:
	var animation_name := &"Walk"
	if (
		npc.appearance_component.get_body_variant()
		== PlayerAppearanceComponent.BODY_VARIANT_FEMALE
	):
		animation_name = &"FemaleWalk"
	if not set_walk_variant(animation_name):
		set_walk_variant(&"Walk")


func get_walk_variant() -> StringName:
	return _current_walk_variant


func get_locomotion_walk_animation() -> StringName:
	return (
		_locomotion_walk_node.animation
		if _locomotion_walk_node != null
		else &""
	)


func play_activity_animation(animation_name: StringName) -> StringName:
	if _activity_animation_player == null:
		return &""
	var selected := animation_name
	if not _activity_animation_player.has_animation(selected):
		selected = &"Idle"
	if not _activity_animation_player.has_animation(selected):
		return &""
	npc.animation_tree.active = false
	npc.animation_player.stop()
	_activity_animation_player.play(selected, 0.15)
	_activity_animation_player.seek(0.0, true)
	_refresh_animation_processing()
	return selected


func stop_activity_animation() -> void:
	if _activity_animation_player != null:
		_activity_animation_player.stop()
	if npc.is_defeated():
		return
	npc.animation_tree.active = true
	_last_locomotion_blend = INF
	_last_locomotion_scale = INF
	_refresh_animation_processing()


func update_locomotion_animation() -> void:
	if (
		not npc.animation_tree.active
		or npc.animation_tree.process_mode == Node.PROCESS_MODE_DISABLED
	):
		return
	var horizontal_speed: float = npc.get_horizontal_speed()
	var blend_position := -1.0
	var playback_scale := 1.0
	if horizontal_speed > 0.01:
		if horizontal_speed <= npc.animation_walk_reference_speed:
			var walk_speed_ratio := clampf(
				horizontal_speed / npc.animation_walk_reference_speed,
				0.35,
				1.25
			)
			blend_position = remap(
				horizontal_speed,
				0.0,
				npc.animation_walk_reference_speed,
				-1.0,
				0.0
			)
			playback_scale = (
				npc.walk_animation_speed_scale
				* walk_speed_ratio
				* foot_slide_correction_scale
			)
		else:
			var sprint_blend := clampf(
				inverse_lerp(
					npc.animation_walk_reference_speed,
					npc.animation_sprint_reference_speed,
					horizontal_speed
				),
				0.0,
				1.0
			)
			var sprint_speed_ratio := clampf(
				horizontal_speed / npc.animation_sprint_reference_speed,
				0.55,
				1.25
			)
			blend_position = sprint_blend
			playback_scale = lerpf(
				npc.walk_animation_speed_scale,
				sprint_animation_speed_scale * sprint_speed_ratio,
				sprint_blend
			)
			playback_scale *= foot_slide_correction_scale
	blend_position = clampf(blend_position, -1.0, 1.0)
	if not is_equal_approx(blend_position, _last_locomotion_blend):
		npc.animation_tree.set(
			npc.locomotion_blend_parameter, blend_position
		)
		_last_locomotion_blend = blend_position
	if not is_equal_approx(playback_scale, _last_locomotion_scale):
		npc.animation_tree.set(
			npc.locomotion_speed_parameter, playback_scale
		)
		_last_locomotion_scale = playback_scale
	if _combat_aiming:
		var local_velocity: Vector3 = (
			npc.visual.global_basis.inverse()
			* Vector3(npc.velocity.x, 0.0, npc.velocity.z)
		)
		var reference_speed: float = maxf(npc.move_speed, 0.01)
		var aim_speed_ratio := clampf(
			horizontal_speed / reference_speed,
			0.45,
			1.2
		)
		_target_aim_direction = AimStrafeBlend.from_local_velocity(
			local_velocity,
			reference_speed
		)
		npc.animation_tree.set(
			aim_movement_speed_parameter,
			aim_movement_animation_speed_scale * aim_speed_ratio
			if horizontal_speed > 0.01
			else 1.0
		)


func handle_damaged(
	_amount: float,
	remaining_health: float,
	_source: Node,
	hit_position: Vector3,
	_hit_direction: Vector3
) -> void:
	if npc.is_defeated() or remaining_health <= 0.0:
		return
	var reaction_animation: StringName = (
		&"Hit_Head"
		if hit_position.y - npc.global_position.y >= npc.head_hit_height
		else &"Hit_Chest"
	)
	if not npc.animation_player.has_animation(reaction_animation):
		return
	var reaction: Animation = npc.animation_player.get_animation(
		reaction_animation
	)
	_hit_reaction_remaining = minf(
		npc.hit_reaction_duration,
		maxf(reaction.length - npc.hit_reaction_exit_lead_time, 0.05)
	)
	set_process(true)
	if _hit_reaction_player != null:
		_hit_reaction_player.play(
			reaction_animation, npc.hit_reaction_blend_time
		)
		_hit_reaction_player.seek(0.0, true)


func stop_all() -> void:
	npc.animation_tree.active = false
	_refresh_animation_processing()
	npc.animation_player.stop()
	if _hit_reaction_player != null:
		_hit_reaction_player.stop()
	if _combat_animation_player != null:
		_combat_animation_player.stop()
	if _activity_animation_player != null:
		_activity_animation_player.stop()
	_combat_aiming = false
	set_process(false)


func reset_for_reuse() -> void:
	_hit_reaction_remaining = 0.0
	_last_locomotion_blend = INF
	_last_locomotion_scale = INF
	_apply_character_visual_scale()
	if _hit_reaction_player != null:
		_hit_reaction_player.stop()
	if _combat_animation_player != null:
		_combat_animation_player.stop()
	if _activity_animation_player != null:
		_activity_animation_player.stop()
	_combat_aiming = false
	_combat_aim_pitch = 0.0
	_combat_recoil_pitch = 0.0
	_combat_reload_remaining = 0.0
	_target_aim_direction = Vector2.ZERO
	_current_aim_direction = Vector2.ZERO
	npc.animation_tree.set(combat_aim_blend_parameter, 0.0)
	npc.animation_tree.set(aim_movement_blend_parameter, 0.0)
	npc.animation_tree.set(aim_direction_parameter, Vector2.ZERO)
	npc.animation_tree.set(
		combat_reload_request_parameter,
		AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
	)
	set_process(false)
	set_visual_animation_active(true)


func _refresh_animation_processing() -> void:
	var notifier := npc.get_node(
		"VisibilityNotifier3D"
	) as VisibleOnScreenNotifier3D
	var should_process: bool = (
		npc.animation_tree.active and notifier.is_on_screen()
	)
	npc.animation_tree.process_mode = (
		Node.PROCESS_MODE_INHERIT
		if should_process
		else Node.PROCESS_MODE_DISABLED
	)
	if should_process:
		update_locomotion_animation()


func _apply_character_visual_scale() -> void:
	npc.visual.scale = Vector3.ONE * NPC_VISUAL_SCALE_MULTIPLIER
	var visual_model := npc.get_node("Visual/PlayerTest2") as Node3D
	var armature := npc.get_node("Visual/PlayerTest2/Armature") as Node3D
	visual_model.scale = Vector3.ONE
	armature.scale = Vector3.ONE * CHARACTER_SCALE


func _create_hit_reaction_layer() -> void:
	var runtime_library: AnimationLibrary = (
		npc.animation_player.get_animation_library(&"")
	)
	if runtime_library == null:
		return
	_hit_reaction_player = AnimationPlayer.new()
	_hit_reaction_player.name = "HitReactionAnimationPlayer"
	npc.animation_player.get_parent().add_child(_hit_reaction_player)
	_hit_reaction_player.root_node = npc.animation_player.root_node
	_hit_reaction_player.add_animation_library(&"", runtime_library)


func _create_activity_animation_layer() -> void:
	var runtime_library: AnimationLibrary = (
		npc.animation_player.get_animation_library(&"")
	)
	if runtime_library == null:
		return
	_activity_animation_player = AnimationPlayer.new()
	_activity_animation_player.name = "ActivityAnimationPlayer"
	npc.animation_player.get_parent().add_child(_activity_animation_player)
	_activity_animation_player.root_node = npc.animation_player.root_node
	_activity_animation_player.add_animation_library(&"", runtime_library)


func _create_combat_animation_layer() -> void:
	var source_library: AnimationLibrary = (
		npc.animation_player.get_animation_library(&"")
	)
	if source_library == null:
		return
	var combat_library := AnimationLibrary.new()
	for animation_name in COMBAT_ANIMATIONS:
		if not source_library.has_animation(animation_name):
			continue
		var animation := _create_upper_body_combat_animation(
			source_library.get_animation(animation_name)
		)
		animation.loop_mode = (
			Animation.LOOP_LINEAR
			if animation_name == &"PistolAim"
			else Animation.LOOP_NONE
		)
		combat_library.add_animation(animation_name, animation)
	_combat_animation_player = AnimationPlayer.new()
	_combat_animation_player.name = "CombatAnimationPlayer"
	npc.animation_player.get_parent().add_child(_combat_animation_player)
	_combat_animation_player.root_node = npc.animation_player.root_node
	_combat_animation_player.add_animation_library(&"", combat_library)


func set_combat_aiming(enabled: bool) -> void:
	if _combat_aiming == enabled:
		return
	_combat_aiming = enabled
	set_process(true)
	npc.animation_tree.set(
		combat_aim_blend_parameter,
		1.0 if enabled else 0.0
	)
	npc.animation_tree.set(
		aim_movement_blend_parameter,
		1.0 if enabled else 0.0
	)
	if not enabled:
		_target_aim_direction = Vector2.ZERO
		_current_aim_direction = Vector2.ZERO
		npc.animation_tree.set(aim_direction_parameter, Vector2.ZERO)


func set_combat_aim_target(world_position: Vector3) -> void:
	var origin: Vector3 = npc.global_position + Vector3.UP * 1.35
	var offset := world_position - origin
	var horizontal_distance := Vector2(offset.x, offset.z).length()
	_combat_aim_pitch = -atan2(offset.y, maxf(horizontal_distance, 0.01))


func trigger_combat_recoil() -> void:
	if not _combat_aiming:
		return
	_combat_recoil_pitch = -deg_to_rad(7.0)
	set_process(true)


func trigger_combat_reload(duration: float) -> void:
	if not npc.animation_player.has_animation(&"Pistol_Reload"):
		return
	_combat_reload_remaining = maxf(duration, 0.01)
	var reload_animation: Animation = npc.animation_player.get_animation(
		&"Pistol_Reload"
	)
	npc.animation_tree.set(
		combat_reload_speed_parameter,
		reload_animation.length / _combat_reload_remaining
	)
	npc.animation_tree.set(
		combat_reload_request_parameter,
		AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	)
	set_process(true)


func _cache_combat_aim_bones() -> void:
	var skeleton := npc.get_node(
		"Visual/PlayerTest2/Armature/GeneralSkeleton"
	) as Skeleton3D
	for bone_name in COMBAT_AIM_BONES:
		var bone_id := skeleton.find_bone(bone_name)
		if bone_id >= 0:
			_combat_aim_bone_ids.append(bone_id)


func _apply_combat_aim_pose() -> void:
	if _combat_aim_bone_ids.is_empty():
		return
	var skeleton := npc.get_node(
		"Visual/PlayerTest2/Armature/GeneralSkeleton"
	) as Skeleton3D
	var rotation_per_bone := (
		_combat_aim_pitch + _combat_recoil_pitch
	) / float(_combat_aim_bone_ids.size())
	var adjustment := Quaternion(Vector3.RIGHT, rotation_per_bone)
	for bone_id in _combat_aim_bone_ids:
		skeleton.set_bone_pose_rotation(
			bone_id,
			(
				skeleton.get_bone_pose_rotation(bone_id)
				* adjustment
			).normalized()
		)


func _create_upper_body_combat_animation(
	source_animation: Animation
) -> Animation:
	var animation := source_animation.duplicate(true) as Animation
	var skeleton := npc.get_node(
		"Visual/PlayerTest2/Armature/GeneralSkeleton"
	) as Skeleton3D
	for track_index in range(animation.get_track_count() - 1, -1, -1):
		var track_type := animation.track_get_type(track_index)
		var track_path := animation.track_get_path(track_index)
		var bone_name := (
			track_path.get_subname(0)
			if track_path.get_subname_count() > 0
			else &""
		)
		var remove_track := (
			track_type != Animation.TYPE_ROTATION_3D
			or bone_name.is_empty()
			or bone_name in LOWER_BODY_BONES
			or (
				not bone_name.is_empty()
				and skeleton.find_bone(bone_name) < 0
			)
		)
		if remove_track:
			animation.remove_track(track_index)
	return animation


func _configure_looping_animations() -> void:
	var source_library: AnimationLibrary = (
		npc.animation_player.get_animation_library(&"")
	)
	if source_library == null:
		return
	if _shared_runtime_animation_library == null:
		var runtime_library := (
			source_library.duplicate(false) as AnimationLibrary
		)
		for animation_name in LOOPING_ANIMATIONS:
			if not source_library.has_animation(animation_name):
				continue
			var animation: Animation
			if (
				animation_name in [&"LeftStrafe", &"RightStrafe"]
				and source_library.has_animation(&"Idle")
			):
				animation = _create_forward_facing_strafe(
					source_library.get_animation(animation_name),
					source_library.get_animation(&"Idle")
				)
			else:
				animation = (
					_create_forward_facing_aim(
					source_library.get_animation(animation_name),
					source_library.get_animation(&"Idle")
				)
				if animation_name == &"PistolAim"
				and source_library.has_animation(&"Idle")
				else source_library.get_animation(
					animation_name
					).duplicate(true) as Animation
				)
			if (
				animation_name in [&"TextingWalking1", &"TextingWalking2"]
				and source_library.has_animation(&"Idle")
			):
				animation = _create_relaxed_in_place_texting_walk(
					animation,
					source_library.get_animation(&"Idle")
				)
			animation.loop_mode = Animation.LOOP_LINEAR
			_remove_armature_scale_tracks(animation)
			runtime_library.remove_animation(animation_name)
			runtime_library.add_animation(animation_name, animation)
		for animation_name in HIT_REACTION_ANIMATIONS:
			if not source_library.has_animation(animation_name):
				continue
			var animation := _create_upper_body_hit_reaction(
				source_library.get_animation(animation_name)
			)
			animation.loop_mode = Animation.LOOP_NONE
			runtime_library.remove_animation(animation_name)
			runtime_library.add_animation(animation_name, animation)
		for animation_name in runtime_library.get_animation_list():
			var cleaned_animation := runtime_library.get_animation(
				animation_name
			).duplicate(true) as Animation
			_remove_npc_only_tracks(cleaned_animation)
			runtime_library.remove_animation(animation_name)
			runtime_library.add_animation(
				animation_name,
				cleaned_animation
			)
		_shared_runtime_animation_library = runtime_library
	_instance_runtime_animation_library = (
		_shared_runtime_animation_library.duplicate(false) as AnimationLibrary
	)
	npc.animation_player.remove_animation_library(&"")
	npc.animation_player.add_animation_library(
		&"", _instance_runtime_animation_library
	)


func _configure_instance_animation_tree() -> void:
	var source_root: AnimationRootNode = npc.animation_tree.tree_root
	if source_root == null:
		return
	npc.animation_tree.tree_root = (
		source_root.duplicate(true) as AnimationRootNode
	)
	var blend_tree := (
		npc.animation_tree.tree_root as AnimationNodeBlendTree
	)
	if blend_tree == null:
		return
	var locomotion := (
		blend_tree.get_node(&"BaseLocomotion") as AnimationNodeBlendSpace1D
	)
	if locomotion == null:
		return
	for point_index in locomotion.get_blend_point_count():
		var animation_node := (
			locomotion.get_blend_point_node(point_index)
			as AnimationNodeAnimation
		)
		if animation_node != null and animation_node.animation == &"Walk":
			_locomotion_walk_node = animation_node
			break


func _create_relaxed_in_place_texting_walk(
	source_animation: Animation,
	idle_animation: Animation
) -> Animation:
	var corrected := source_animation.duplicate(true) as Animation
	var hips_position_track := corrected.find_track(
		HIPS_TRACK,
		Animation.TYPE_POSITION_3D
	)
	if hips_position_track >= 0:
		var start_position := corrected.position_track_interpolate(
			hips_position_track,
			0.0
		)
		for key_index in corrected.track_get_key_count(hips_position_track):
			var position: Vector3 = corrected.track_get_key_value(
				hips_position_track,
				key_index
			)
			position.x = start_position.x
			position.z = start_position.z
			corrected.track_set_key_value(
				hips_position_track,
				key_index,
				position
			)
	for bone_name in TEXTING_ARM_BLEND:
		var track_path := NodePath(
			"%GeneralSkeleton:" + String(bone_name)
		)
		var corrected_track := corrected.find_track(
			track_path,
			Animation.TYPE_ROTATION_3D
		)
		var idle_track := idle_animation.find_track(
			track_path,
			Animation.TYPE_ROTATION_3D
		)
		if corrected_track < 0 or idle_track < 0:
			continue
		var animation_weight := float(TEXTING_ARM_BLEND[bone_name])
		for key_index in corrected.track_get_key_count(corrected_track):
			var key_time := corrected.track_get_key_time(
				corrected_track,
				key_index
			)
			var idle_rotation := idle_animation.rotation_track_interpolate(
				idle_track,
				key_time
			)
			var texting_rotation: Quaternion = corrected.track_get_key_value(
				corrected_track,
				key_index
			)
			corrected.track_set_key_value(
				corrected_track,
				key_index,
				idle_rotation.slerp(texting_rotation, animation_weight)
			)
	return corrected


func _create_forward_facing_aim(
	aim_animation: Animation,
	idle_animation: Animation
) -> Animation:
	var aligned_aim := aim_animation.duplicate(true) as Animation
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
		return aligned_aim
	var base_hips_rotation := idle_animation.rotation_track_interpolate(
		idle_hips_track,
		0.0
	)
	for key_index in aligned_aim.track_get_key_count(aim_spine_track):
		var key_time := aligned_aim.track_get_key_time(
			aim_spine_track,
			key_index
		)
		var aim_hips_rotation := aim_animation.rotation_track_interpolate(
			aim_hips_track,
			key_time
		)
		var aim_spine_rotation := aim_animation.rotation_track_interpolate(
			aim_spine_track,
			key_time
		)
		var hips_correction := (
			base_hips_rotation.inverse() * aim_hips_rotation
		)
		aligned_aim.track_set_key_value(
			aim_spine_track,
			key_index,
			(hips_correction * aim_spine_rotation).normalized()
		)
	return aligned_aim


func _create_forward_facing_strafe(
	source_animation: Animation,
	idle_animation: Animation
) -> Animation:
	var aligned_strafe := source_animation.duplicate(true) as Animation
	var hips_track := source_animation.find_track(
		HIPS_TRACK,
		Animation.TYPE_ROTATION_3D
	)
	var idle_hips_track := idle_animation.find_track(
		HIPS_TRACK,
		Animation.TYPE_ROTATION_3D
	)
	if hips_track < 0 or idle_hips_track < 0:
		return aligned_strafe
	var base_hips_rotation := idle_animation.rotation_track_interpolate(
		idle_hips_track,
		0.0
	)
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
			var hips_rotation := source_animation.rotation_track_interpolate(
				hips_track,
				key_time
			)
			var leg_rotation := source_animation.rotation_track_interpolate(
				leg_track,
				key_time
			)
			aligned_strafe.track_set_key_value(
				leg_track,
				key_index,
				(
					base_hips_rotation.inverse()
					* hips_rotation
					* leg_rotation
				).normalized()
			)
	for key_index in aligned_strafe.track_get_key_count(hips_track):
		aligned_strafe.track_set_key_value(
			hips_track,
			key_index,
			base_hips_rotation
		)
	if hips_position_track >= 0:
		var starting_position := source_animation.position_track_interpolate(
			hips_position_track,
			0.0
		)
		for key_index in aligned_strafe.track_get_key_count(
			hips_position_track
		):
			var key_time := aligned_strafe.track_get_key_time(
				hips_position_track,
				key_index
			)
			var hips_position := source_animation.position_track_interpolate(
				hips_position_track,
				key_time
			)
			hips_position.x = starting_position.x
			hips_position.z = starting_position.z
			aligned_strafe.track_set_key_value(
				hips_position_track,
				key_index,
				hips_position
			)
	return aligned_strafe


func _create_upper_body_hit_reaction(
	source_animation: Animation
) -> Animation:
	var reaction := source_animation.duplicate(true) as Animation
	var skeleton := npc.get_node(
		"Visual/PlayerTest2/Armature/GeneralSkeleton"
	) as Skeleton3D
	for track_index in range(reaction.get_track_count() - 1, -1, -1):
		var track_type := reaction.track_get_type(track_index)
		var track_path := reaction.track_get_path(track_index)
		var bone_name := (
			track_path.get_subname(0)
			if track_path.get_subname_count() > 0
			else &""
		)
		var remove_track := (
			track_type == Animation.TYPE_POSITION_3D
			or track_type == Animation.TYPE_SCALE_3D
			or bone_name.is_empty()
			or (
				not bone_name.is_empty()
				and (
					skeleton.find_bone(bone_name) < 0
					or bone_name not in HIT_REACTION_INCLUDED_BONES
				)
			)
		)
		if remove_track:
			reaction.remove_track(track_index)
	return reaction


func _remove_armature_scale_tracks(animation: Animation) -> void:
	for track_index in range(animation.get_track_count() - 1, -1, -1):
		if (
			animation.track_get_type(track_index) == Animation.TYPE_SCALE_3D
			and animation.track_get_path(track_index) == NodePath("Armature")
		):
			animation.remove_track(track_index)


func _remove_npc_only_tracks(animation: Animation) -> void:
	_remove_armature_scale_tracks(animation)
	for track_index in range(animation.get_track_count() - 1, -1, -1):
		if (
			animation.track_get_type(track_index)
			== Animation.TYPE_SCALE_3D
		):
			animation.remove_track(track_index)
			continue
		var track_path_text := String(
			animation.track_get_path(track_index)
		)
		if track_path_text.contains("Components/SoundComponent"):
			animation.remove_track(track_index)
