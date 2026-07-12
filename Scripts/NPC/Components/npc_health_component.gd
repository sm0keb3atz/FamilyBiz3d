class_name NPCHealthComponent
extends Node

static var _shared_ragdoll_simulator_template: PhysicalBoneSimulator3D

const RAGDOLL_TEMPLATE := preload("res://Scenes/PlayerVisual.scn")
const BLOOD_IMPACT_VFX := preload("res://Scenes/VFX/BloodImpactVFX.tscn")
const RAGDOLL_IMPULSE_BONES := [&"Hips", &"Spine", &"Chest", &"UpperChest"]
const VFX_ATTACHMENT_BONES := [
	&"Hips", &"Spine", &"Chest", &"UpperChest", &"Neck", &"Head",
	&"LeftUpperArm", &"LeftLowerArm", &"RightUpperArm", &"RightLowerArm",
	&"LeftUpperLeg", &"LeftLowerLeg", &"RightUpperLeg", &"RightLowerLeg",
]

@export_category("Ragdoll")
@export_range(0.0, 8.0, 0.05) var ragdoll_impulse_strength := 3.6
@export_range(0.0, 0.5, 0.01) var ragdoll_min_upward_direction := 0.14
@export_range(0.1, 5.0, 0.1) var vehicle_ragdoll_impulse_multiplier := 1.8
@export_range(1.0, 50.0, 0.5) var maximum_vehicle_ragdoll_impulse := 30.0
@export_range(0.2, 2.0, 0.05) var vehicle_blood_impact_height := 0.9

@export_category("Body Cleanup")
@export_range(0.0, 60.0, 0.5) var body_cleanup_delay := 7.0

var npc
var _is_defeated := false
var _pending_ragdoll_direction := Vector3.ZERO
var _pending_ragdoll_impulse_strength := 0.0
var _defeated_elapsed := 0.0
var _skeleton: Skeleton3D
var _simulator: PhysicalBoneSimulator3D


func prepare_before_tree_ready() -> void:
	var startup_simulator := get_node_or_null(
		"../../Visual/PlayerTest2/Armature/GeneralSkeleton/PhysicalBoneSimulator3D"
	) as PhysicalBoneSimulator3D
	if startup_simulator != null:
		startup_simulator.active = false
		startup_simulator.physical_bones_stop_simulation()
		_set_physical_bone_collisions(startup_simulator, false)


func initialize(owner_npc: CharacterBody3D) -> void:
	npc = owner_npc
	_skeleton = npc.get_node_or_null(
		"Visual/PlayerTest2/Armature/GeneralSkeleton"
	) as Skeleton3D
	_simulator = npc.get_node_or_null(
		"Visual/PlayerTest2/Armature/GeneralSkeleton/PhysicalBoneSimulator3D"
	) as PhysicalBoneSimulator3D
	_prepare_ragdoll_template()
	if _simulator != null:
		_simulator.physical_bones_stop_simulation()
		_simulator.active = false
		_set_physical_bone_collisions(_simulator, false)
	set_process(false)


func _process(delta: float) -> void:
	if not _is_defeated:
		set_process(false)
		return
	_defeated_elapsed += delta
	if _defeated_elapsed < npc.body_cleanup_delay:
		return
	if _simulator != null:
		_simulator.physical_bones_stop_simulation()
		_set_physical_bone_collisions(_simulator, false)
	npc.queue_free()


func is_defeated() -> bool:
	return _is_defeated


func handle_defeated(
	_source: Node,
	_hit_position: Vector3,
	hit_direction: Vector3
) -> void:
	if _is_defeated:
		return
	_is_defeated = true
	_pending_ragdoll_direction = hit_direction
	set_process(true)
	npc.set_physics_process(false)
	npc.set_navigation_avoidance_enabled(false)
	npc.set_local_obstacle_steering_enabled(false)
	npc.clear_navigation_target()
	npc.velocity = Vector3.ZERO
	npc.remove_from_group("interactable_npc")
	npc.remove_from_group("customer_npc")
	npc.remove_from_group("interactable")
	npc.animation_component.stop_all()
	var body_collision := npc.get_node("CollisionShape3D") as CollisionShape3D
	body_collision.set_deferred("disabled", true)
	_attach_ragdoll_simulator()
	if _simulator != null:
		_set_physical_bone_collisions(_simulator, true)
		call_deferred("_start_ragdoll")


func apply_vehicle_impact(source: Node, impact_velocity: Vector3) -> void:
	if _is_defeated or npc.damageable.is_depleted():
		return
	var hit_direction := impact_velocity.normalized()
	hit_direction.y = maxf(
		hit_direction.y, npc.ragdoll_min_upward_direction
	)
	_pending_ragdoll_impulse_strength = clampf(
		impact_velocity.length() * npc.vehicle_ragdoll_impulse_multiplier,
		npc.ragdoll_impulse_strength,
		npc.maximum_vehicle_ragdoll_impulse
	)
	var hit_position: Vector3 = (
		npc.global_position + Vector3.UP * npc.vehicle_blood_impact_height
	)
	npc.damageable.apply_damage(
		npc.damageable.maximum_health,
		source,
		hit_position,
		hit_direction
	)
	var effect := BLOOD_IMPACT_VFX.instantiate() as BloodImpactVFX
	npc.get_tree().current_scene.add_child(effect)
	effect.setup_blood_hit(
		hit_position, -hit_direction, hit_direction, npc, true
	)


func reset_for_reuse() -> void:
	_is_defeated = false
	_pending_ragdoll_direction = Vector3.ZERO
	_pending_ragdoll_impulse_strength = 0.0
	_defeated_elapsed = 0.0
	set_process(false)
	var body_collision := npc.get_node("CollisionShape3D") as CollisionShape3D
	body_collision.set_deferred("disabled", false)
	npc.damageable.restore_full_health()
	if _simulator != null:
		_simulator.physical_bones_stop_simulation()
		_simulator.active = false
		_set_physical_bone_collisions(_simulator, false)


func create_vfx_attachment(world_position: Vector3) -> Node3D:
	if _skeleton == null:
		return npc
	var closest_bone := (
		_find_closest_vfx_bone(world_position).name as StringName
	)
	var attachment := BoneAttachment3D.new()
	attachment.name = "BloodMark_%s" % closest_bone
	_skeleton.add_child(attachment)
	attachment.bone_name = closest_bone
	var bone_index := _skeleton.find_bone(closest_bone)
	if bone_index >= 0:
		attachment.transform = _skeleton.get_bone_global_pose(bone_index)
	return attachment


func snap_vfx_position_to_body(world_position: Vector3) -> Vector3:
	if _skeleton == null:
		return world_position
	var closest := _find_closest_vfx_bone(world_position)
	var bone_name := closest.name as StringName
	var bone_position := closest.position as Vector3
	var surface_radius := 0.15
	if bone_name == &"Head" or bone_name == &"Neck":
		surface_radius = 0.10
	elif String(bone_name).contains("Arm") or String(bone_name).contains("Leg"):
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
	return npc.global_position + Vector3.UP * 0.5


func get_vfx_collision_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = [npc.get_rid()]
	if _simulator == null:
		return exclusions
	for child in _simulator.get_children():
		if child is CollisionObject3D:
			exclusions.append((child as CollisionObject3D).get_rid())
	return exclusions


func _find_closest_vfx_bone(world_position: Vector3) -> Dictionary:
	var closest_bone := &"Chest"
	var closest_position: Vector3 = npc.global_position + Vector3.UP
	var closest_distance_squared := INF
	for bone_name in VFX_ATTACHMENT_BONES:
		var bone_index := _skeleton.find_bone(bone_name)
		if bone_index < 0:
			continue
		var bone_position := (
			_skeleton.global_transform
			* _skeleton.get_bone_global_pose(bone_index)
		).origin
		var distance_squared := bone_position.distance_squared_to(
			world_position
		)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_bone = bone_name
			closest_position = bone_position
	return {"name": closest_bone, "position": closest_position}


func _prepare_ragdoll_template() -> void:
	if _skeleton == null or _simulator == null:
		return
	if _shared_ragdoll_simulator_template == null:
		var template_visual := RAGDOLL_TEMPLATE.instantiate() as Node3D
		var template_skeleton := template_visual.get_node_or_null(
			"Armature/GeneralSkeleton"
		) as Skeleton3D
		if template_skeleton == null:
			template_visual.free()
			return
		var template_simulator := template_skeleton.get_node_or_null(
			"PhysicalBoneSimulator3D"
		) as PhysicalBoneSimulator3D
		if template_simulator == null:
			template_visual.free()
			return
		template_simulator.active = false
		template_simulator.physical_bones_stop_simulation()
		template_skeleton.remove_child(template_simulator)
		_shared_ragdoll_simulator_template = template_simulator
		template_visual.free()
	_simulator.free()
	_simulator = null


func _attach_ragdoll_simulator() -> void:
	if (
		_skeleton == null
		or _simulator != null
		or _shared_ragdoll_simulator_template == null
	):
		return
	var replacement := (
		_shared_ragdoll_simulator_template.duplicate()
		as PhysicalBoneSimulator3D
	)
	if replacement == null:
		return
	_skeleton.add_child(replacement)
	replacement.name = "PhysicalBoneSimulator3D"
	_simulator = replacement


func _start_ragdoll() -> void:
	if not _is_defeated or _simulator == null:
		return
	_simulator.active = true
	_simulator.physical_bones_start_simulation()
	call_deferred("_apply_ragdoll_impulse")


func _apply_ragdoll_impulse() -> void:
	await npc.get_tree().physics_frame
	if _simulator == null or _pending_ragdoll_direction.is_zero_approx():
		return
	var impulse_direction := _pending_ragdoll_direction
	impulse_direction.y = maxf(
		impulse_direction.y, npc.ragdoll_min_upward_direction
	)
	impulse_direction = impulse_direction.normalized()
	var impulse_strength: float = (
		_pending_ragdoll_impulse_strength
		if _pending_ragdoll_impulse_strength > 0.0
		else npc.ragdoll_impulse_strength
	)
	for bone_name in RAGDOLL_IMPULSE_BONES:
		var target_bone := _find_physical_bone(bone_name)
		if target_bone != null:
			target_bone.apply_central_impulse(
				impulse_direction * impulse_strength
			)


func _find_physical_bone(bone_name: StringName) -> PhysicalBone3D:
	if _simulator == null or _skeleton == null:
		return null
	for child in _simulator.get_children():
		if child is not PhysicalBone3D:
			continue
		var physical_bone := child as PhysicalBone3D
		if _skeleton.get_bone_name(physical_bone.get_bone_id()) == bone_name:
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
