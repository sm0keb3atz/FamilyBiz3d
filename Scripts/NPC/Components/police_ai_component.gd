class_name PoliceAIComponent
extends Node

const MODE_PATROL := 0
const MODE_ARREST := 1
const MODE_COMBAT := 2

@export_range(1.0, 12.0, 0.1) var patrol_speed := 2.5
@export_range(1.0, 12.0, 0.1) var pursuit_speed := 5.5
@export_range(0.5, 5.0, 0.1) var arrest_distance := 1.8
@export_range(2.0, 30.0, 0.5) var preferred_combat_distance := 16.0
@export_range(1.0, 20.0, 0.5) var minimum_combat_distance := 7.0
@export_range(1.0, 20.0, 0.5) var reposition_min_distance := 5.0
@export_range(1.0, 20.0, 0.5) var reposition_max_distance := 10.0
@export_range(0.0, 10.0, 0.1) var search_duration := 8.0
@export_range(0.0, 10.0, 0.1) var minimum_burst_pause := 0.8
@export_range(0.0, 10.0, 0.1) var maximum_burst_pause := 1.6
@export_range(0.05, 1.0, 0.01) var minimum_shot_interval := 0.18
@export_range(0.05, 1.0, 0.01) var maximum_shot_interval := 0.32
@export_range(0.0, 15.0, 0.1) var shot_spread_degrees := 3.5

var npc
var player: CharacterBody3D
var wanted: PlayerWantedComponent
var arrest: PlayerArrestComponent
var player_health: PlayerHealthComponent
var patrol: PedestrianPatrolComponent
var perception: PolicePerceptionComponent
var combat: NPCCombatComponent
var _random := RandomNumberGenerator.new()
var _last_known_position := Vector3.ZERO
var _search_remaining := 0.0
var _burst_remaining := 0
var _shot_remaining := 0.0
var _pause_remaining := 0.0
var _reposition_target := Vector3.ZERO
var _has_reposition_target := false
var _last_mode := -1
var _reaction_remaining := 0.0


func initialize(owner_npc: BaseNPC, target_player: CharacterBody3D) -> void:
	npc = owner_npc
	player = target_player
	wanted = player.get_node(
		"Components/WantedComponent"
	) as PlayerWantedComponent
	arrest = player.get_node(
		"Components/ArrestComponent"
	) as PlayerArrestComponent
	player_health = player.get_node(
		"Components/HealthComponent"
	) as PlayerHealthComponent
	patrol = npc.get_node(
		"Components/PatrolComponent"
	) as PedestrianPatrolComponent
	perception = npc.get_node(
		"Components/PerceptionComponent"
	) as PolicePerceptionComponent
	combat = npc.get_node(
		"Components/CombatComponent"
	) as NPCCombatComponent
	_random.randomize()


func tick_mode(mode: int, delta: float) -> void:
	if npc.is_defeated() or player == null:
		return
	if mode != _last_mode:
		_enter_mode(mode)
		_last_mode = mode
	match mode:
		MODE_PATROL:
			_tick_patrol(delta)
		MODE_ARREST:
			_tick_arrest(delta)
		MODE_COMBAT:
			_tick_combat(delta)


func note_incident(world_position: Vector3) -> void:
	_last_known_position = world_position
	_search_remaining = search_duration


func reset_for_reuse() -> void:
	_last_known_position = Vector3.ZERO
	_search_remaining = 0.0
	_burst_remaining = 0
	_shot_remaining = 0.0
	_pause_remaining = 0.0
	_has_reposition_target = false
	_last_mode = -1
	_reaction_remaining = 0.0


func _enter_mode(mode: int) -> void:
	npc.clear_navigation_target()
	npc.clear_facing_override()
	_has_reposition_target = false
	_burst_remaining = 0
	_pause_remaining = 0.0
	if mode == MODE_ARREST or mode == MODE_COMBAT:
		_last_known_position = player.global_position
		_search_remaining = search_duration
	if mode == MODE_COMBAT:
		_reaction_remaining = _random.randf_range(0.35, 0.8)
		combat.set_equipped(true)
	else:
		combat.clear_aim()
		combat.set_equipped(false)


func _tick_patrol(delta: float) -> void:
	npc.move_speed = patrol_speed
	combat.set_equipped(false)
	patrol.tick_patrol(delta)


func _tick_arrest(delta: float) -> void:
	npc.move_speed = pursuit_speed
	combat.set_equipped(false)
	if not player_health.is_alive():
		npc.stop_moving(delta)
		return
	var sees_player: bool = perception.can_see_player()
	if sees_player:
		_last_known_position = player.global_position
		_search_remaining = search_duration
	var distance_squared: float = npc.global_position.distance_squared_to(
		player.global_position
	)
	if (
		sees_player
		and distance_squared <= arrest_distance * arrest_distance
	):
		npc.stop_moving(delta)
		npc.set_facing_override(player.global_position)
		arrest.report_police_contact()
		return
	var destination: Vector3 = (
		player.global_position
		if sees_player
		else _last_known_position
	)
	if destination.is_zero_approx():
		npc.stop_moving(delta)
		return
	npc.set_navigation_target(destination)
	npc.advance_navigation(delta)


func _tick_combat(delta: float) -> void:
	npc.move_speed = pursuit_speed
	combat.set_equipped(true)
	if not player_health.is_alive():
		combat.clear_aim()
		npc.stop_moving(delta)
		return
	var target_position: Vector3 = player.global_position + Vector3.UP
	var sees_player: bool = perception.can_see_player()
	if sees_player:
		_last_known_position = player.global_position
		_search_remaining = search_duration
	else:
		_search_remaining = maxf(_search_remaining - delta, 0.0)
		_chase_last_known(delta)
		return
	var combat_distance: float = npc.global_position.distance_to(
		player.global_position
	)
	_reaction_remaining = maxf(_reaction_remaining - delta, 0.0)
	if combat_distance > preferred_combat_distance * 1.35:
		combat.set_aim_target(target_position)
		npc.set_navigation_target(player.global_position)
		npc.advance_navigation(delta)
		return
	if combat_distance < minimum_combat_distance and not _has_reposition_target:
		_choose_retreat_position()
	if _has_reposition_target:
		if (
			npc.global_position.distance_squared_to(_reposition_target)
			> 1.0
		):
			npc.set_facing_override(target_position)
			npc.set_navigation_target(_reposition_target)
			npc.advance_navigation(delta)
			return
		_has_reposition_target = false
	npc.stop_moving(delta)
	combat.set_aim_target(target_position)
	_pause_remaining = maxf(_pause_remaining - delta, 0.0)
	_shot_remaining = maxf(_shot_remaining - delta, 0.0)
	if combat.is_reloading() or _pause_remaining > 0.0:
		return
	if _reaction_remaining > 0.0:
		return
	if _burst_remaining <= 0:
		_burst_remaining = _random.randi_range(2, 4)
	if _shot_remaining > 0.0:
		return
	if not combat.has_line_of_fire(player, target_position):
		_choose_reposition()
		return
	if combat.try_fire_at(target_position, shot_spread_degrees):
		_burst_remaining -= 1
		_shot_remaining = _random.randf_range(
			minimum_shot_interval,
			maximum_shot_interval
		)
	if _burst_remaining <= 0:
		_pause_remaining = _random.randf_range(
			minimum_burst_pause,
			maximum_burst_pause
		)
		_choose_reposition()


func _chase_last_known(delta: float) -> void:
	combat.clear_aim()
	if _last_known_position.is_zero_approx():
		npc.stop_moving(delta)
		return
	if (
		npc.global_position.distance_squared_to(_last_known_position)
		> 2.25
	):
		npc.set_navigation_target(_last_known_position)
		npc.advance_navigation(delta)
	elif _search_remaining <= 0.0:
		npc.stop_moving(delta)
	else:
		_choose_search_position()


func _choose_reposition() -> void:
	var away: Vector3 = npc.global_position - player.global_position
	away.y = 0.0
	if away.is_zero_approx():
		away = Vector3.FORWARD
	var side := away.normalized().rotated(
		Vector3.UP,
		PI * 0.5 * (-1.0 if _random.randf() < 0.5 else 1.0)
	)
	var candidate: Vector3 = npc.global_position + side * _random.randf_range(
		reposition_min_distance,
		reposition_max_distance
	)
	_set_reachable_reposition(candidate)


func _choose_retreat_position() -> void:
	var away: Vector3 = npc.global_position - player.global_position
	away.y = 0.0
	if away.is_zero_approx():
		away = Vector3.FORWARD
	var candidate: Vector3 = (
		npc.global_position
		+ away.normalized() * reposition_max_distance
	)
	_set_reachable_reposition(candidate)


func _choose_search_position() -> void:
	var angle := _random.randf_range(-PI, PI)
	var candidate := _last_known_position + Vector3(
		cos(angle),
		0.0,
		sin(angle)
	) * _random.randf_range(3.0, 7.0)
	_set_reachable_reposition(candidate)
	if _has_reposition_target:
		_last_known_position = _reposition_target


func _set_reachable_reposition(candidate: Vector3) -> void:
	var navigation_map: RID = npc.navigation_agent.get_navigation_map()
	var reachable := NavigationServer3D.map_get_closest_point(
		navigation_map,
		candidate
	)
	if reachable.is_equal_approx(Vector3.ZERO):
		return
	_reposition_target = reachable
	_has_reposition_target = true
