class_name BaseNPC
extends CharacterBody3D

## Composition root for all NPCs.
##
## Keep public NPC contracts here so callers do not need to know which component
## owns a behavior. Movement, animation, and damage/ragdoll implementation live
## in child components, matching the player architecture.

@onready var visual := $Visual as Node3D
@onready var navigation_agent := $NavigationAgent3D as NavigationAgent3D
@onready var animation_player := $Visual/PlayerTest2/AnimationPlayer as AnimationPlayer
@onready var animation_tree := $AnimationTree as AnimationTree
@onready var appearance_component := $AppearanceComponent as PlayerAppearanceComponent
@onready var damageable := $DamageableComponent as DamageableComponent
@onready var body_collision := $CollisionShape3D as CollisionShape3D
@onready var movement_component := (
	$Components/MovementComponent as NPCMovementComponent
)
@onready var animation_component := (
	$Components/AnimationComponent as NPCAnimationComponent
)
@onready var health_component := (
	$Components/HealthComponent as NPCHealthComponent
)

# Compatibility properties keep role scripts and game systems decoupled from
# the component tree. Tuning values themselves live on their owning component.
var move_speed: float:
	get: return movement_component.move_speed
	set(value): movement_component.move_speed = value
var acceleration: float:
	get: return movement_component.acceleration
var turn_speed: float:
	get: return movement_component.turn_speed
var obstacle_probe_distance: float:
	get: return movement_component.obstacle_probe_distance
var obstacle_probe_angle_degrees: float:
	get: return movement_component.obstacle_probe_angle_degrees
var obstacle_probe_interval: float:
	get: return movement_component.obstacle_probe_interval
var obstacle_steering_strength: float:
	get: return movement_component.obstacle_steering_strength
var obstacle_probe_height: float:
	get: return movement_component.obstacle_probe_height
var obstacle_probe_collision_mask: int:
	get: return movement_component.obstacle_probe_collision_mask
var walk_animation_speed_scale: float:
	get: return animation_component.walk_animation_speed_scale
	set(value): animation_component.walk_animation_speed_scale = value
var locomotion_blend_parameter: String:
	get: return animation_component.locomotion_blend_parameter
var locomotion_speed_parameter: String:
	get: return animation_component.locomotion_speed_parameter
var animation_walk_reference_speed: float:
	get: return animation_component.animation_walk_reference_speed
var animation_sprint_reference_speed: float:
	get: return animation_component.animation_sprint_reference_speed
var head_hit_height: float:
	get: return animation_component.head_hit_height
var hit_reaction_blend_time: float:
	get: return animation_component.hit_reaction_blend_time
var hit_reaction_exit_lead_time: float:
	get: return animation_component.hit_reaction_exit_lead_time
var hit_reaction_duration: float:
	get: return animation_component.hit_reaction_duration
var ragdoll_impulse_strength: float:
	get: return health_component.ragdoll_impulse_strength
var ragdoll_min_upward_direction: float:
	get: return health_component.ragdoll_min_upward_direction
var vehicle_ragdoll_impulse_multiplier: float:
	get: return health_component.vehicle_ragdoll_impulse_multiplier
var maximum_vehicle_ragdoll_impulse: float:
	get: return health_component.maximum_vehicle_ragdoll_impulse
var vehicle_blood_impact_height: float:
	get: return health_component.vehicle_blood_impact_height
var body_cleanup_delay: float:
	get: return health_component.body_cleanup_delay


func _enter_tree() -> void:
	var component := get_node_or_null(
		"Components/HealthComponent"
	) as NPCHealthComponent
	if component != null:
		component.prepare_before_tree_ready()


func _ready() -> void:
	add_to_group(&"lock_target")
	movement_component.initialize(self)
	animation_component.initialize(self)
	health_component.initialize(self)
	damageable.damaged.connect(animation_component.handle_damaged)
	damageable.depleted.connect(_on_defeated)


func can_interact(_player: CharacterBody3D) -> bool:
	return false


func get_interaction_prompt(_player: CharacterBody3D) -> String:
	return ""


func interact(_player: CharacterBody3D) -> void:
	pass


func set_navigation_target(target: Vector3) -> bool:
	return movement_component.set_navigation_target(target)


func clear_navigation_target() -> void:
	movement_component.clear_navigation_target()


func get_navigation_target_update_count() -> int:
	return movement_component.get_navigation_target_update_count()


func set_navigation_avoidance_enabled(enabled: bool) -> void:
	movement_component.set_navigation_avoidance_enabled(enabled)


func set_local_obstacle_steering_enabled(enabled: bool) -> void:
	movement_component.set_local_obstacle_steering_enabled(enabled)


func set_obstacle_probe_delay(delay: float) -> void:
	movement_component.set_obstacle_probe_delay(delay)


func set_facing_override(world_position: Vector3) -> void:
	movement_component.set_facing_override(world_position)


func clear_facing_override() -> void:
	movement_component.clear_facing_override()


func set_visual_animation_active(enabled: bool) -> void:
	animation_component.set_visual_animation_active(enabled)


func move_toward_navigation_target(target: Vector3, delta: float) -> void:
	movement_component.move_toward_navigation_target(target, delta)


func advance_navigation(delta: float) -> void:
	movement_component.advance_navigation(delta)


func stop_moving(delta: float) -> void:
	movement_component.stop_moving(delta)


func get_horizontal_speed() -> float:
	return movement_component.get_horizontal_speed()


func get_horizontal_speed_squared() -> float:
	return movement_component.get_horizontal_speed_squared()


func is_defeated() -> bool:
	return health_component.is_defeated()


func apply_vehicle_impact(source: Node, impact_velocity: Vector3) -> void:
	health_component.apply_vehicle_impact(source, impact_velocity)


func reset_for_reuse() -> void:
	add_to_group(&"lock_target")
	health_component.reset_for_reuse()
	movement_component.reset_for_reuse()
	animation_component.reset_for_reuse()
	set_physics_process(true)


func create_vfx_attachment(world_position: Vector3) -> Node3D:
	return health_component.create_vfx_attachment(world_position)


func snap_vfx_position_to_body(world_position: Vector3) -> Vector3:
	return health_component.snap_vfx_position_to_body(world_position)


func get_vfx_pool_origin() -> Vector3:
	return health_component.get_vfx_pool_origin()


func get_vfx_collision_exclusions() -> Array[RID]:
	return health_component.get_vfx_collision_exclusions()


func refresh_locomotion_animation() -> void:
	animation_component.update_locomotion_animation()


func _on_defeated(
	source: Node,
	hit_position: Vector3,
	hit_direction: Vector3
) -> void:
	remove_from_group(&"lock_target")
	health_component.handle_defeated(source, hit_position, hit_direction)
