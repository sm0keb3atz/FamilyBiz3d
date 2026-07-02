class_name BaseNPC
extends CharacterBody3D

const LOOPING_ANIMATIONS := [&"Idle", &"Walk"]
const HIT_REACTION_ANIMATIONS := [&"Hit_Head", &"Hit_Chest"]
const CHARACTER_SCALE := 1.75
const HIT_REACTION_INCLUDED_BONES := [
	&"Spine",
	&"Chest",
	&"UpperChest",
	&"Neck",
	&"Head",
]
const RAGDOLL_IMPULSE_BONES := [
	&"Hips",
	&"Spine",
	&"Chest",
	&"UpperChest",
]
const VFX_ATTACHMENT_BONES := [
	&"Hips",
	&"Spine",
	&"Chest",
	&"UpperChest",
	&"Neck",
	&"Head",
	&"LeftUpperArm",
	&"LeftLowerArm",
	&"RightUpperArm",
	&"RightLowerArm",
	&"LeftUpperLeg",
	&"LeftLowerLeg",
	&"RightUpperLeg",
	&"RightLowerLeg",
]

@export_category("Movement")
@export_range(0.1, 20.0, 0.1) var move_speed := 2.5
@export_range(0.1, 30.0, 0.1) var acceleration := 10.0
@export_range(0.1, 30.0, 0.1) var turn_speed := 8.0
@export_range(0.1, 3.0, 0.05) var walk_animation_speed_scale := 2.0
@export_range(0.0, 1.0, 0.05) var animation_blend_time := 0.2

@export_category("Damage Reactions")
@export_range(0.5, 3.0, 0.05) var head_hit_height := 1.45
@export_range(0.0, 0.5, 0.01) var hit_reaction_blend_time := 0.08
@export_range(0.0, 1.0, 0.01) var hit_reaction_exit_blend_time := 0.35
@export_range(0.0, 0.5, 0.01) var hit_reaction_exit_lead_time := 0.08
@export_range(0.1, 2.0, 0.05) var hit_reaction_duration := 0.45
@export_range(0.0, 8.0, 0.05) var ragdoll_impulse_strength := 3.6
@export_range(0.0, 0.5, 0.01) var ragdoll_min_upward_direction := 0.14

@export_category("Body Cleanup")
@export_range(0.0, 60.0, 0.5) var body_cleanup_delay := 7.0

@onready var visual := $Visual as Node3D
@onready var navigation_agent := $NavigationAgent3D as NavigationAgent3D
@onready var animation_player := (
	$Visual/PlayerTest2/AnimationPlayer as AnimationPlayer
)
@onready var visual_model := $Visual/PlayerTest2 as Node3D
@onready var armature := $Visual/PlayerTest2/Armature as Node3D
@onready var body_collision := $CollisionShape3D as CollisionShape3D
@onready var damageable := $DamageableComponent as DamageableComponent
@onready var skeleton := get_node_or_null(
	"Visual/PlayerTest2/Armature/GeneralSkeleton"
) as Skeleton3D
@onready var simulator := get_node_or_null(
	"Visual/PlayerTest2/Armature/GeneralSkeleton/PhysicalBoneSimulator3D"
) as PhysicalBoneSimulator3D

var _gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _is_defeated := false
var _hit_reaction_remaining := 0.0
var _pending_ragdoll_direction := Vector3.ZERO
var _defeated_elapsed := 0.0
var _hit_reaction_player: AnimationPlayer


func _enter_tree() -> void:
	var startup_simulator := get_node_or_null(
		"Visual/PlayerTest2/Armature/GeneralSkeleton/PhysicalBoneSimulator3D"
	) as PhysicalBoneSimulator3D
	if startup_simulator == null:
		return
	startup_simulator.active = false
	startup_simulator.physical_bones_stop_simulation()
	_set_physical_bone_collisions(startup_simulator, false)


func _ready() -> void:
	visual_model.scale = Vector3.ONE
	armature.scale = Vector3.ONE * CHARACTER_SCALE
	_configure_looping_animations()
	_create_hit_reaction_layer()
	_play_animation(&"Idle")
	damageable.damaged.connect(_on_damaged)
	damageable.depleted.connect(_on_defeated)
	if simulator != null:
		simulator.physical_bones_stop_simulation()
		simulator.active = false
		_set_physical_bone_collisions(simulator, false)


func _process(delta: float) -> void:
	if _is_defeated:
		_update_body_cleanup(delta)
		return

	var was_reacting := _hit_reaction_remaining > 0.0
	_hit_reaction_remaining = maxf(
		_hit_reaction_remaining - delta,
		0.0
	)
	if was_reacting and is_zero_approx(_hit_reaction_remaining):
		if _hit_reaction_player != null:
			_hit_reaction_player.stop()


func _update_body_cleanup(delta: float) -> void:
	_defeated_elapsed += delta
	if _defeated_elapsed < body_cleanup_delay:
		return
	if simulator != null:
		simulator.physical_bones_stop_simulation()
		_set_physical_bone_collisions(simulator, false)
	queue_free()


func can_interact(_player: CharacterBody3D) -> bool:
	return false


func get_interaction_prompt(_player: CharacterBody3D) -> String:
	return ""


func interact(_player: CharacterBody3D) -> void:
	pass


func move_toward_navigation_target(target: Vector3, delta: float) -> void:
	if _is_defeated:
		return
	navigation_agent.target_position = target
	var next_position := navigation_agent.get_next_path_position()
	var direction := next_position - global_position
	direction.y = 0.0

	if direction.length_squared() > 0.001:
		direction = direction.normalized()
		var target_velocity := direction * move_speed
		velocity.x = move_toward(
			velocity.x,
			target_velocity.x,
			acceleration * delta
		)
		velocity.z = move_toward(
			velocity.z,
			target_velocity.z,
			acceleration * delta
		)
		visual.rotation.y = lerp_angle(
			visual.rotation.y,
			atan2(direction.x, direction.z),
			minf(turn_speed * delta, 1.0)
		)
	else:
		stop_moving(delta)

	_apply_gravity(delta)
	move_and_slide()
	_play_animation(&"Walk" if get_horizontal_speed() > 0.1 else &"Idle")


func stop_moving(delta: float) -> void:
	if _is_defeated:
		return
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	_apply_gravity(delta)
	move_and_slide()
	_play_animation(&"Walk" if get_horizontal_speed() > 0.1 else &"Idle")


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func is_defeated() -> bool:
	return _is_defeated


func create_vfx_attachment(world_position: Vector3) -> Node3D:
	if skeleton == null:
		return self

	var closest_bone := (
		_find_closest_vfx_bone(world_position).name as StringName
	)
	var attachment := BoneAttachment3D.new()
	attachment.name = "BloodMark_%s" % closest_bone
	skeleton.add_child(attachment)
	attachment.bone_name = closest_bone
	var bone_index := skeleton.find_bone(closest_bone)
	if bone_index >= 0:
		attachment.transform = skeleton.get_bone_global_pose(bone_index)
	return attachment


func snap_vfx_position_to_body(world_position: Vector3) -> Vector3:
	if skeleton == null:
		return world_position
	var closest := _find_closest_vfx_bone(world_position)
	var bone_name := closest.name as StringName
	var bone_position := closest.position as Vector3
	var surface_radius := 0.16
	if bone_name == &"Head" or bone_name == &"Neck":
		surface_radius = 0.10
	elif (
		String(bone_name).contains("Arm")
		or String(bone_name).contains("Leg")
	):
		surface_radius = 0.08
	var offset := world_position - bone_position
	if offset.length() <= surface_radius:
		return world_position
	return bone_position + offset.normalized() * surface_radius


func get_vfx_pool_origin() -> Vector3:
	if _is_defeated:
		var hips := _find_physical_bone(&"Hips")
		if hips != null:
			return hips.global_position
	return global_position + Vector3.UP * 0.5


func get_vfx_collision_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = [get_rid()]
	if simulator == null:
		return exclusions
	for child in simulator.get_children():
		if child is CollisionObject3D:
			exclusions.append((child as CollisionObject3D).get_rid())
	return exclusions


func _find_closest_vfx_bone(world_position: Vector3) -> Dictionary:
	var closest_bone := &"Chest"
	var closest_position := global_position + Vector3.UP
	var closest_distance_squared := INF
	for bone_name in VFX_ATTACHMENT_BONES:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index < 0:
			continue
		var bone_position := (
			skeleton.global_transform
			* skeleton.get_bone_global_pose(bone_index)
		).origin
		var distance_squared := bone_position.distance_squared_to(
			world_position
		)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_bone = bone_name
			closest_position = bone_position
	return {
		"name": closest_bone,
		"position": closest_position,
	}


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0


func _play_animation(animation_name: StringName) -> void:
	var playback_speed := (
		walk_animation_speed_scale
		if animation_name == &"Walk"
		else 1.0
	)
	if (
		animation_player.has_animation(animation_name)
		and animation_player.current_animation != animation_name
	):
		animation_player.play(
			animation_name,
			animation_blend_time,
			playback_speed
		)


func _create_hit_reaction_layer() -> void:
	var runtime_library := animation_player.get_animation_library(&"")
	if runtime_library == null:
		return

	_hit_reaction_player = AnimationPlayer.new()
	_hit_reaction_player.name = "HitReactionAnimationPlayer"
	animation_player.get_parent().add_child(_hit_reaction_player)
	_hit_reaction_player.root_node = animation_player.root_node
	_hit_reaction_player.add_animation_library(&"", runtime_library)


func _configure_looping_animations() -> void:
	var source_library := animation_player.get_animation_library(&"")
	if source_library == null:
		return
	var runtime_library := source_library.duplicate(false) as AnimationLibrary
	for animation_name in LOOPING_ANIMATIONS:
		if not source_library.has_animation(animation_name):
			continue
		var animation := source_library.get_animation(
			animation_name
		).duplicate(true) as Animation
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
	animation_player.remove_animation_library(&"")
	animation_player.add_animation_library(&"", runtime_library)


func _create_upper_body_hit_reaction(
	source_animation: Animation
) -> Animation:
	var reaction := source_animation.duplicate(true) as Animation
	for track_index in range(reaction.get_track_count() - 1, -1, -1):
		var track_type := reaction.track_get_type(track_index)
		var track_path := reaction.track_get_path(track_index)
		var bone_name := track_path.get_subname(0)
		var remove_track := (
			track_type == Animation.TYPE_POSITION_3D
			or track_type == Animation.TYPE_SCALE_3D
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


func _on_damaged(
	_amount: float,
	remaining_health: float,
	_source: Node,
	hit_position: Vector3,
	_hit_direction: Vector3
) -> void:
	if _is_defeated or remaining_health <= 0.0:
		return

	var local_hit_height := hit_position.y - global_position.y
	var reaction_animation := (
		&"Hit_Head"
		if local_hit_height >= head_hit_height
		else &"Hit_Chest"
	)
	if not animation_player.has_animation(reaction_animation):
		return

	var reaction := animation_player.get_animation(reaction_animation)
	_hit_reaction_remaining = minf(
		hit_reaction_duration,
		maxf(
			reaction.length - hit_reaction_exit_lead_time,
			0.05
		)
	)
	if _hit_reaction_player == null:
		return
	_hit_reaction_player.play(
		reaction_animation,
		hit_reaction_blend_time
	)
	_hit_reaction_player.seek(0.0, true)


func _on_defeated(
	_source: Node,
	_hit_position: Vector3,
	hit_direction: Vector3
) -> void:
	if _is_defeated:
		return

	_is_defeated = true
	_pending_ragdoll_direction = hit_direction
	set_physics_process(false)
	velocity = Vector3.ZERO
	remove_from_group("interactable_npc")
	remove_from_group("customer_npc")
	animation_player.stop()
	if _hit_reaction_player != null:
		_hit_reaction_player.stop()
	body_collision.set_deferred("disabled", true)
	if simulator != null:
		_set_physical_bone_collisions(simulator, true)
		call_deferred("_start_ragdoll")


func _start_ragdoll() -> void:
	if not _is_defeated or simulator == null:
		return
	simulator.active = true
	simulator.physical_bones_start_simulation()
	call_deferred("_apply_ragdoll_impulse")


func _apply_ragdoll_impulse() -> void:
	await get_tree().physics_frame
	if simulator == null or _pending_ragdoll_direction.is_zero_approx():
		return

	var impulse_direction := _pending_ragdoll_direction
	impulse_direction.y = maxf(
		impulse_direction.y,
		ragdoll_min_upward_direction
	)
	impulse_direction = impulse_direction.normalized()
	for bone_name in RAGDOLL_IMPULSE_BONES:
		var target_bone := _find_physical_bone(bone_name)
		if target_bone != null:
			target_bone.apply_central_impulse(
				impulse_direction * ragdoll_impulse_strength
			)


func _find_physical_bone(bone_name: StringName) -> PhysicalBone3D:
	if simulator == null or skeleton == null:
		return null

	for child in simulator.get_children():
		if child is not PhysicalBone3D:
			continue
		var physical_bone := child as PhysicalBone3D
		if skeleton.get_bone_name(physical_bone.get_bone_id()) == bone_name:
			return physical_bone
	return null


func _set_physical_bone_collisions(
	target_simulator: PhysicalBoneSimulator3D,
	enabled: bool
) -> void:
	for child in target_simulator.get_children():
		if child is PhysicalBone3D:
			var physical_bone := child as PhysicalBone3D
			physical_bone.collision_layer = 0
			physical_bone.collision_mask = 0
			if enabled:
				physical_bone.set_collision_layer_value(2, true)
				physical_bone.set_collision_mask_value(1, true)


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
