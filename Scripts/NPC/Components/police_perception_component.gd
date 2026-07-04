class_name PolicePerceptionComponent
extends Node

@export_range(1.0, 100.0, 1.0) var witness_range := 20.0
@export_range(1.0, 150.0, 1.0) var combat_sight_range := 45.0
@export_range(1.0, 200.0, 1.0) var hearing_range := 45.0
@export_range(20.0, 180.0, 1.0) var field_of_view_degrees := 110.0
@export_flags_3d_physics var sight_collision_mask := 3

var npc
var player: CharacterBody3D
var wanted: PlayerWantedComponent
var player_weapon: PlayerWeaponComponent


func initialize(owner_npc: BaseNPC, target_player: CharacterBody3D) -> void:
	npc = owner_npc
	player = target_player
	wanted = player.get_node(
		"Components/WantedComponent"
	) as PlayerWantedComponent
	player_weapon = player.get_node(
		"Components/WeaponComponent"
	) as PlayerWeaponComponent


func _process(_delta: float) -> void:
	if (
		npc == null
		or player == null
		or npc.is_defeated()
		or player_weapon.get_equipped_weapon() == null
	):
		return
	if can_witness_position(player.global_position + Vector3.UP):
		wanted.report_visible_weapon_witness()


func can_see_player() -> bool:
	if player == null:
		return false
	return _has_sight(
		player.global_position + Vector3.UP,
		combat_sight_range,
		false
	)


func can_witness_position(world_position: Vector3) -> bool:
	return _has_sight(world_position, witness_range, true)


func can_hear_position(world_position: Vector3) -> bool:
	return (
		npc != null
		and not npc.is_defeated()
		and npc.global_position.distance_squared_to(world_position)
		<= hearing_range * hearing_range
	)


func _has_sight(
	world_position: Vector3,
	maximum_range: float,
	require_fov: bool
) -> bool:
	if npc == null or npc.is_defeated():
		return false
	var origin: Vector3 = npc.global_position + Vector3.UP * 1.35
	var offset := world_position - origin
	if offset.length_squared() > maximum_range * maximum_range:
		return false
	if require_fov:
		var forward: Vector3 = npc.visual.global_basis.z.normalized()
		var flat_offset := Vector3(offset.x, 0.0, offset.z).normalized()
		var minimum_dot := cos(deg_to_rad(field_of_view_degrees * 0.5))
		if forward.dot(flat_offset) < minimum_dot:
			return false
	var query := PhysicsRayQueryParameters3D.create(origin, world_position)
	query.collision_mask = sight_collision_mask
	query.exclude = [npc.get_rid()]
	var hit: Dictionary = (
		npc.get_world_3d().direct_space_state.intersect_ray(query)
	)
	if hit.is_empty():
		return true
	var collider := hit.get("collider") as Node
	return _is_player_node(collider)


func _is_player_node(node: Node) -> bool:
	var current := node
	while current != null:
		if current == player:
			return true
		current = current.get_parent()
	return false
