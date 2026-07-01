@tool
extends Node3D

@export var model_path := NodePath("PlayerTest2")
@export_range(0.1, 5.0, 0.05) var character_scale := 1.75


func _enter_tree() -> void:
	_apply_visual_scale()
	_disable_physical_bones()


func _ready() -> void:
	process_priority = 100
	_apply_visual_scale()
	_disable_physical_bones()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_apply_visual_scale()


func _apply_visual_scale() -> void:
	var model := get_node_or_null(model_path) as Node3D
	if model == null:
		return
	var armature := model.get_node_or_null("Armature") as Node3D
	if armature == null:
		return

	if not model.scale.is_equal_approx(Vector3.ONE):
		model.scale = Vector3.ONE
	var target_scale := Vector3.ONE * character_scale
	if not armature.scale.is_equal_approx(target_scale):
		armature.scale = target_scale


func _disable_physical_bones() -> void:
	var model := get_node_or_null(model_path) as Node3D
	if model == null:
		return
	var simulator := model.get_node_or_null(
		"Armature/GeneralSkeleton/PhysicalBoneSimulator3D"
	) as PhysicalBoneSimulator3D
	if simulator == null:
		return

	simulator.active = false
	simulator.physical_bones_stop_simulation()
	for child in simulator.get_children():
		if child is PhysicalBone3D:
			var physical_bone := child as PhysicalBone3D
			physical_bone.collision_layer = 0
			physical_bone.collision_mask = 0
