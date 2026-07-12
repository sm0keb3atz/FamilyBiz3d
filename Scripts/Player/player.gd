extends CharacterBody3D

## Composition root for the player. Gameplay behavior lives in child components.

const VFX_ATTACHMENT_BONES := [
	&"Hips", &"Spine", &"Chest", &"UpperChest", &"Neck", &"Head",
	&"LeftUpperArm", &"LeftLowerArm", &"RightUpperArm", &"RightLowerArm",
	&"LeftUpperLeg", &"LeftLowerLeg", &"RightUpperLeg", &"RightLowerLeg",
]

@onready var _vfx_skeleton := (
	get_node_or_null("Visual/PlayerTest2/Armature/GeneralSkeleton")
	as Skeleton3D
)


func _ready() -> void:
	add_to_group(&"player")
	add_to_group(&"traffic_obstacle")


func create_vfx_attachment(world_position: Vector3) -> Node3D:
	if _vfx_skeleton == null:
		return self
	var closest_bone := (
		_find_closest_vfx_bone(world_position).name as StringName
	)
	var attachment := BoneAttachment3D.new()
	attachment.name = "BloodMark_%s" % closest_bone
	_vfx_skeleton.add_child(attachment)
	attachment.bone_name = closest_bone
	var bone_index := _vfx_skeleton.find_bone(closest_bone)
	if bone_index >= 0:
		attachment.transform = _vfx_skeleton.get_bone_global_pose(bone_index)
	return attachment


func snap_vfx_position_to_body(world_position: Vector3) -> Vector3:
	if _vfx_skeleton == null:
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
	return global_position + Vector3.UP * 0.5


func get_vfx_collision_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = [get_rid()]
	return exclusions


func _find_closest_vfx_bone(world_position: Vector3) -> Dictionary:
	var closest_bone := &"Chest"
	var closest_position := global_position + Vector3.UP
	var closest_distance_squared := INF
	for bone_name in VFX_ATTACHMENT_BONES:
		var bone_index := _vfx_skeleton.find_bone(bone_name)
		if bone_index < 0:
			continue
		var bone_position := (
			_vfx_skeleton.global_transform
			* _vfx_skeleton.get_bone_global_pose(bone_index)
		).origin
		var distance_squared := bone_position.distance_squared_to(
			world_position
		)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_bone = bone_name
			closest_position = bone_position
	return {"name": closest_bone, "position": closest_position}
