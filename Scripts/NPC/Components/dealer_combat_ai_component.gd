class_name DealerCombatAIComponent
extends Node

const MODE_PATROL := 0
const MODE_COMBAT := 2
const MODE_SEARCH_COMBAT := 4

@export_range(1.0, 12.0, 0.1) var pursuit_speed := 5.5
@export_range(0.5, 5.0, 0.1) var combat_aim_move_speed := 2.25
@export_range(2.0, 30.0, 0.5) var preferred_combat_distance := 11.0
@export_range(1.0, 20.0, 0.5) var minimum_combat_distance := 3.0
@export_range(1.0, 20.0, 0.5) var retreat_target_distance := 5.0
@export_range(1.0, 20.0, 0.5) var reposition_min_distance := 3.0
@export_range(1.0, 20.0, 0.5) var reposition_max_distance := 6.0
@export_range(0.1, 10.0, 0.1) var retreat_cooldown := 2.5
@export_range(0.1, 5.0, 0.1) var movement_decision_minimum := 0.8
@export_range(0.1, 5.0, 0.1) var movement_decision_maximum := 1.6
@export_range(1.0, 20.0, 0.5) var search_inner_radius := 2.5
@export_range(1.0, 30.0, 0.5) var search_outer_radius := 9.0
@export_range(0.0, 5.0, 0.1) var search_pause_minimum := 0.45
@export_range(0.0, 5.0, 0.1) var search_pause_maximum := 1.2
@export_range(0.0, 10.0, 0.1) var minimum_burst_pause := 0.8
@export_range(0.0, 10.0, 0.1) var maximum_burst_pause := 1.6
@export_range(0.05, 1.0, 0.01) var minimum_shot_interval := 0.18
@export_range(0.05, 1.0, 0.01) var maximum_shot_interval := 0.32
@export_range(2, 30, 1) var automatic_burst_minimum := 7
@export_range(2, 30, 1) var automatic_burst_maximum := 12
@export_range(0.0, 3.0, 0.05) var automatic_burst_pause_minimum := 0.25
@export_range(0.0, 3.0, 0.05) var automatic_burst_pause_maximum := 0.55
@export_range(0.0, 15.0, 0.1) var shot_spread_degrees := 3.5

var npc: DealerNPC
var player: CharacterBody3D
var player_health: PlayerHealthComponent
var perception: Node
var combat: NPCCombatComponent
var _random := RandomNumberGenerator.new()
var _last_known_position := Vector3.ZERO
var _burst_remaining := 0
var _shot_remaining := 0.0
var _pause_remaining := 0.0
var _reposition_target := Vector3.ZERO
var _has_reposition_target := false
var _last_mode := -1
var _reaction_remaining := 0.0
var _movement_decision_remaining := 0.0
var _retreat_cooldown_remaining := 0.0
var _search_center := Vector3.ZERO
var _has_search_center := false
var _has_search_destination := false
var _search_pause_remaining := 0.0
var _search_pause_pending := false


func initialize(owner_npc: DealerNPC, target_player: CharacterBody3D) -> void:
	npc = owner_npc
	player = target_player
	player_health = player.get_node(
		"Components/HealthComponent"
	) as PlayerHealthComponent
	perception = npc.get_node("Components/ThreatComponent")
	combat = npc.get_node(
		"Components/CombatComponent"
	) as NPCCombatComponent
	_random.randomize()
	reset_for_reuse()


func tick_mode(mode: int, delta: float) -> void:
	if npc == null or npc.is_defeated() or player == null:
		return
	if mode != _last_mode:
		_enter_mode(mode)
		_last_mode = mode
	match mode:
		MODE_COMBAT:
			_tick_combat(delta)
		MODE_SEARCH_COMBAT:
			_tick_search(delta)
		_:
			_tick_neutral(delta)


func note_incident(world_position: Vector3) -> void:
	_set_search_center(world_position)


func reset_for_reuse() -> void:
	_last_known_position = Vector3.ZERO
	_burst_remaining = 0
	_shot_remaining = 0.0
	_pause_remaining = 0.0
	_has_reposition_target = false
	_last_mode = -1
	_reaction_remaining = 0.0
	_movement_decision_remaining = 0.0
	_retreat_cooldown_remaining = 0.0
	_search_center = Vector3.ZERO
	_has_search_center = false
	_has_search_destination = false
	_search_pause_remaining = 0.0
	_search_pause_pending = false


func _enter_mode(mode: int) -> void:
	npc.clear_navigation_target()
	npc.clear_facing_override()
	_has_reposition_target = false
	_burst_remaining = 0
	_pause_remaining = 0.0
	_movement_decision_remaining = 0.0
	if mode == MODE_COMBAT or mode == MODE_SEARCH_COMBAT:
		if perception.call("can_see_player"):
			_set_search_center(player.global_position)
		_reaction_remaining = _random.randf_range(0.35, 0.8)
		combat.set_equipped(true)
	else:
		combat.clear_aim()
		combat.set_equipped(false)


func _tick_neutral(delta: float) -> void:
	combat.clear_aim()
	combat.set_equipped(false)
	npc.stop_moving(delta)


func _tick_combat(delta: float) -> void:
	combat.set_equipped(true)
	if not player_health.is_alive():
		npc.clear_hostility()
		combat.clear_aim()
		npc.stop_moving(delta)
		return
	var target_position := player.global_position + Vector3.UP
	if perception.call("can_see_player"):
		_set_search_center(player.global_position)
	else:
		_tick_search(delta)
		return
	var combat_distance := npc.global_position.distance_to(player.global_position)
	var advance_threshold := preferred_combat_distance * 1.25
	if combat_distance > advance_threshold:
		npc.move_speed = pursuit_speed
		combat.clear_aim()
		_has_reposition_target = false
		npc.set_navigation_target(player.global_position)
		npc.set_facing_override(target_position)
		npc.advance_navigation(delta)
		return
	_reaction_remaining = maxf(_reaction_remaining - delta, 0.0)
	_movement_decision_remaining = maxf(
		_movement_decision_remaining - delta, 0.0
	)
	_retreat_cooldown_remaining = maxf(
		_retreat_cooldown_remaining - delta, 0.0
	)
	npc.move_speed = combat_aim_move_speed
	combat.set_aim_target(target_position)
	_update_combat_movement(combat_distance, target_position, delta)
	_pause_remaining = maxf(_pause_remaining - delta, 0.0)
	_shot_remaining = maxf(_shot_remaining - delta, 0.0)
	if combat.is_reloading() or _pause_remaining > 0.0:
		return
	if _reaction_remaining > 0.0:
		return
	if _burst_remaining <= 0:
		_burst_remaining = _get_next_burst_size()
	if _shot_remaining > 0.0:
		return
	if not combat.has_line_of_fire(player, target_position):
		if not _has_reposition_target:
			_choose_reposition()
		return
	if combat.try_fire_at(target_position, shot_spread_degrees):
		_burst_remaining -= 1
		_shot_remaining = _get_next_shot_interval()
	if _burst_remaining <= 0:
		_pause_remaining = _get_next_burst_pause()
		if not _has_reposition_target:
			_choose_reposition()


func _get_next_burst_size() -> int:
	if combat.is_fully_automatic():
		return _random.randi_range(
			automatic_burst_minimum, automatic_burst_maximum
		)
	return _random.randi_range(2, 4)


func _get_next_shot_interval() -> float:
	if combat.is_fully_automatic():
		return combat.get_fire_interval()
	return _random.randf_range(minimum_shot_interval, maximum_shot_interval)


func _get_next_burst_pause() -> float:
	if combat.is_fully_automatic():
		return _random.randf_range(
			automatic_burst_pause_minimum,
			automatic_burst_pause_maximum
		)
	return _random.randf_range(minimum_burst_pause, maximum_burst_pause)


func get_automatic_cadence_for_test() -> float:
	return combat.get_fire_interval() if combat != null else 0.0


func _update_combat_movement(
	combat_distance: float,
	target_position: Vector3,
	delta: float
) -> void:
	if (
		combat_distance < minimum_combat_distance
		and _retreat_cooldown_remaining <= 0.0
	):
		_choose_retreat_position(combat_distance)
		_retreat_cooldown_remaining = retreat_cooldown
	if not _has_reposition_target and _movement_decision_remaining <= 0.0:
		_choose_aggressive_reposition(combat_distance)
	if _has_reposition_target:
		if (
			npc.global_position.distance_squared_to(_reposition_target) > 0.8
			and _movement_decision_remaining > 0.0
		):
			npc.set_facing_override(target_position)
			npc.set_navigation_target(_reposition_target)
			npc.advance_navigation(delta)
			return
		_has_reposition_target = false
	npc.stop_moving(delta)


func _choose_aggressive_reposition(combat_distance: float) -> void:
	_movement_decision_remaining = _random.randf_range(
		movement_decision_minimum, movement_decision_maximum
	)
	var roll := _random.randf()
	if combat_distance > preferred_combat_distance:
		var toward := player.global_position - npc.global_position
		toward.y = 0.0
		if toward.is_zero_approx():
			return
		var candidate := npc.global_position + toward.normalized() * _random.randf_range(2.0, 4.0)
		_set_reachable_reposition(candidate)
	elif roll < 0.85:
		_choose_reposition()


func _tick_search(delta: float) -> void:
	npc.move_speed = pursuit_speed
	combat.set_equipped(true)
	if not player_health.is_alive():
		npc.clear_hostility()
		combat.clear_aim()
		npc.stop_moving(delta)
		return
	if perception.call("can_see_player"):
		_tick_combat(delta)
		return
	_chase_last_known(delta)


func _chase_last_known(delta: float) -> void:
	combat.clear_aim()
	if not _has_search_destination:
		npc.stop_moving(delta)
		return
	if npc.global_position.distance_squared_to(_last_known_position) > 2.25:
		npc.set_navigation_target(_last_known_position)
		npc.advance_navigation(delta)
	else:
		npc.stop_moving(delta)
		if _has_search_center:
			npc.set_facing_override(_search_center)
		if _search_pause_pending:
			_search_pause_remaining = _random.randf_range(
				search_pause_minimum, search_pause_maximum
			)
			_search_pause_pending = false
		if _search_pause_remaining > 0.0:
			_search_pause_remaining = maxf(_search_pause_remaining - delta, 0.0)
			return
		_choose_search_position()


func _choose_reposition() -> void:
	var away := npc.global_position - player.global_position
	away.y = 0.0
	if away.is_zero_approx():
		away = Vector3.FORWARD
	var side := away.normalized().rotated(
		Vector3.UP, PI * 0.5 * (-1.0 if _random.randf() < 0.5 else 1.0)
	)
	var candidate := npc.global_position + side * _random.randf_range(
		reposition_min_distance, reposition_max_distance
	)
	_set_reachable_reposition(candidate)
	_movement_decision_remaining = _random.randf_range(
		movement_decision_minimum, movement_decision_maximum
	)


func _choose_retreat_position(combat_distance: float) -> void:
	var away := npc.global_position - player.global_position
	away.y = 0.0
	if away.is_zero_approx():
		away = Vector3.FORWARD
	var candidate := npc.global_position + away.normalized() * maxf(
		retreat_target_distance - combat_distance, 1.5
	)
	_set_reachable_reposition(candidate)
	_movement_decision_remaining = minf(1.0, movement_decision_maximum)


func _choose_search_position() -> void:
	if not _has_search_center:
		return
	var angle := _random.randf_range(-PI, PI)
	var candidate := _search_center + Vector3(
		cos(angle), 0.0, sin(angle)
	) * _random.randf_range(search_inner_radius, search_outer_radius)
	_set_search_destination(candidate)


func _set_search_center(world_position: Vector3) -> void:
	_search_center = world_position
	_has_search_center = true
	_set_search_destination(world_position)


func _set_search_destination(candidate: Vector3) -> void:
	var navigation_map := npc.navigation_agent.get_navigation_map()
	if not navigation_map.is_valid():
		return
	_last_known_position = NavigationServer3D.map_get_closest_point(
		navigation_map, candidate
	)
	_has_search_destination = true
	_search_pause_remaining = 0.0
	_search_pause_pending = true


func _set_reachable_reposition(candidate: Vector3) -> void:
	var navigation_map := npc.navigation_agent.get_navigation_map()
	var reachable := NavigationServer3D.map_get_closest_point(
		navigation_map, candidate
	)
	if reachable.is_equal_approx(Vector3.ZERO):
		return
	_reposition_target = reachable
	_has_reposition_target = true
