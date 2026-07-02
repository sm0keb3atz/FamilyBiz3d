class_name PlayerRagdollComponent
extends Node

@export_category("Scene References")
@export var health_component_path := NodePath("../HealthComponent")
@export var movement_component_path := NodePath("../MovementComponent")
@export var appearance_component_path := NodePath("../AppearanceComponent")
@export var body_path := NodePath("../..")
@export var body_collision_path := NodePath("../../CollisionShape3D")
@export var animation_tree_path := NodePath("../../AnimationTree")
@export var skeleton_path := NodePath(
	"../../Visual/PlayerTest2/Armature/GeneralSkeleton"
)
@export var simulator_path := NodePath(
	"../../Visual/PlayerTest2/Armature/GeneralSkeleton/PhysicalBoneSimulator3D"
)

@onready var health_component := (
	get_node(health_component_path) as PlayerHealthComponent
)
@onready var movement_component := (
	get_node(movement_component_path) as PlayerMovementComponent
)
@onready var appearance_component := (
	get_node_or_null(appearance_component_path) as PlayerAppearanceComponent
)
@onready var body := get_node(body_path) as CharacterBody3D
@onready var body_collision := (
	get_node(body_collision_path) as CollisionShape3D
)
@onready var animation_tree := (
	get_node(animation_tree_path) as AnimationTree
)
@onready var skeleton := get_node_or_null(skeleton_path) as Skeleton3D
@onready var simulator := (
	get_node_or_null(simulator_path) as PhysicalBoneSimulator3D
)

var _is_ragdoll_active := false


func _enter_tree() -> void:
	var startup_simulator := get_node_or_null(
		simulator_path
	) as PhysicalBoneSimulator3D
	if startup_simulator == null:
		return
	startup_simulator.active = false
	startup_simulator.physical_bones_stop_simulation()
	_set_physical_bone_collisions(startup_simulator, false)


func _ready() -> void:
	health_component.downed.connect(activate_ragdoll)
	health_component.respawn_started.connect(_prepare_respawn)
	health_component.respawn_completed.connect(_finish_respawn)
	if simulator == null:
		return
	simulator.physical_bones_stop_simulation()
	simulator.active = false
	_set_physical_bone_collisions(simulator, false)


func activate_ragdoll() -> void:
	if _is_ragdoll_active or simulator == null:
		return

	_is_ragdoll_active = true
	movement_component.set_physics_process(false)
	body.velocity = Vector3.ZERO
	if appearance_component != null:
		appearance_component.set_ragdoll_visibility(true)
	body_collision.set_deferred("disabled", true)
	_set_physical_bone_collisions(simulator, true)
	call_deferred("_start_simulation")


func _prepare_respawn() -> void:
	if not _is_ragdoll_active:
		return

	_is_ragdoll_active = false
	simulator.physical_bones_stop_simulation()
	simulator.active = false
	_set_physical_bone_collisions(simulator, false)
	if skeleton != null:
		skeleton.reset_bone_poses()
	if appearance_component != null:
		appearance_component.set_ragdoll_visibility(false)


func _finish_respawn() -> void:
	body_collision.set_deferred("disabled", false)
	animation_tree.active = true
	movement_component.set_physics_process(true)


func is_ragdoll_active() -> bool:
	return _is_ragdoll_active


func _start_simulation() -> void:
	if _is_ragdoll_active:
		simulator.active = true
		simulator.physical_bones_start_simulation()


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
