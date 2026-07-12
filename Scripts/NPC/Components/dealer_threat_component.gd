class_name DealerThreatComponent
extends Node

signal provoked(source: Node, world_position: Vector3)

@export_range(1.0, 100.0, 0.5) var threat_range := 24.0
@export_range(20.0, 180.0, 1.0) var field_of_view_degrees := 100.0
@export_range(0.05, 2.0, 0.05) var aim_confirmation_time := 0.35
@export_range(0.25, 3.0, 0.05) var aim_point_radius := 1.25
@export_flags_3d_physics var sight_collision_mask := 3

var npc: DealerNPC
var player: CharacterBody3D
var player_weapon: PlayerWeaponComponent
var _aim_time := 0.0


func initialize(owner_npc: DealerNPC, target_player: CharacterBody3D) -> void:
	npc = owner_npc
	player = target_player
	player_weapon = player.get_node_or_null(
		"Components/WeaponComponent"
	) as PlayerWeaponComponent
	if (
		player_weapon != null
		and not player_weapon.shot_resolved.is_connected(_on_shot_resolved)
	):
		player_weapon.shot_resolved.connect(_on_shot_resolved)


func _process(delta: float) -> void:
	if npc == null or player == null or npc.is_hostile() or npc.is_defeated():
		_aim_time = 0.0
		return
	if _is_player_aiming_at_dealer() and can_see_player():
		_aim_time += delta
		if _aim_time >= aim_confirmation_time:
			provoked.emit(player, player.global_position)
	else:
		_aim_time = 0.0


func can_see_player() -> bool:
	if npc == null or player == null:
		return false
	var origin := npc.global_position + Vector3.UP * 1.35
	var target := player.global_position + Vector3.UP
	var offset := target - origin
	if offset.length_squared() > threat_range * threat_range:
		return false
	var forward := npc.visual.global_basis.z
	forward.y = 0.0
	var flat_offset := Vector3(offset.x, 0.0, offset.z).normalized()
	var minimum_dot := cos(deg_to_rad(field_of_view_degrees * 0.5))
	if forward.normalized().dot(flat_offset) < minimum_dot:
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [npc.get_rid()]
	query.collision_mask = sight_collision_mask
	var hit := npc.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or _is_node_or_descendant(hit.get("collider") as Node, player)


func _is_player_aiming_at_dealer() -> bool:
	if player_weapon == null or not player_weapon.is_aiming():
		return false
	var aim_point := player_weapon.get_aim_target_position()
	var body_center := npc.global_position + Vector3.UP
	return aim_point.distance_squared_to(body_center) <= aim_point_radius * aim_point_radius


func _on_shot_resolved(
	target: Node,
	_fatal: bool,
	hit_position: Vector3
) -> void:
	if npc == null or npc.is_hostile() or npc.is_defeated():
		return
	if target == npc or _is_node_or_descendant(target, npc):
		provoked.emit(player, hit_position)


func _is_node_or_descendant(node: Node, ancestor: Node) -> bool:
	var current := node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false
