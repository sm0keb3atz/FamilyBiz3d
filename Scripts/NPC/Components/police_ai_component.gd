class_name PoliceAIComponent
extends Node

const MODE_PATROL := 0
const MODE_ARREST := 1
const MODE_COMBAT := 2
const MODE_SEARCH_ARREST := 3
const MODE_SEARCH_COMBAT := 4
const MODE_CHALLENGE := 5
const MODE_SEARCH_CHALLENGE := 6
const MODE_INVESTIGATE := 7

@export_range(1.0, 12.0, 0.1) var patrol_speed := 2.5
@export_range(1.0, 12.0, 0.1) var pursuit_speed := 5.5
@export_range(5.0, 80.0, 1.0) var direct_pursuit_range := 45.0
@export_range(0.5, 5.0, 0.1) var combat_aim_move_speed := 2.25
@export_range(0.5, 5.0, 0.1) var arrest_distance := 1.8
@export_range(2.0, 30.0, 0.5) var preferred_combat_distance := 11.0
@export_range(1.0, 20.0, 0.5) var minimum_combat_distance := 3.0
@export_range(1.0, 20.0, 0.5) var retreat_target_distance := 5.0
@export_range(1.0, 20.0, 0.5) var reposition_min_distance := 3.0
@export_range(1.0, 20.0, 0.5) var reposition_max_distance := 6.0
@export_range(0.1, 10.0, 0.1) var retreat_cooldown := 2.5
@export_range(0.1, 5.0, 0.1) var movement_decision_minimum := 0.8
@export_range(0.1, 5.0, 0.1) var movement_decision_maximum := 1.6
@export_range(0.1, 3.0, 0.05) var combat_strafe_minimum := 0.55
@export_range(0.1, 3.0, 0.05) var combat_strafe_maximum := 1.05
@export_range(0.0, 2.0, 0.05) var combat_strafe_pause_minimum := 0.25
@export_range(0.0, 2.0, 0.05) var combat_strafe_pause_maximum := 0.55
@export_range(1.0, 20.0, 0.5) var search_inner_radius := 2.5
@export_range(1.0, 30.0, 0.5) var search_outer_radius := 9.0
@export_category("Investigation and Search")
@export_range(5.0, 60.0, 1.0) var investigation_lifetime := 30.0
@export_range(0.1, 2.0, 0.05) var search_replan_interval := 0.4
@export_range(0.0, 5.0, 0.1) var search_pause_minimum := 0.45
@export_range(0.0, 5.0, 0.1) var search_pause_maximum := 1.2
@export_range(0.0, 10.0, 0.1) var minimum_burst_pause := 0.8
@export_range(0.0, 10.0, 0.1) var maximum_burst_pause := 1.6
@export_range(0.05, 1.0, 0.01) var minimum_shot_interval := 0.18
@export_range(0.05, 1.0, 0.01) var maximum_shot_interval := 0.32
@export_range(0.0, 15.0, 0.1) var shot_spread_degrees := 3.5
@export_category("Dispatched Response")
@export_range(1.0, 12.0, 0.5) var response_commit_seconds := 6.0

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
var _burst_remaining := 0
var _shot_remaining := 0.0
var _pause_remaining := 0.0
var _reposition_target := Vector3.ZERO
var _has_reposition_target := false
var _last_mode := -1
var _reaction_remaining := 0.0
var _movement_decision_remaining := 0.0
var _retreat_cooldown_remaining := 0.0
var _combat_strafe_sign := 0.0
var _search_center := Vector3.ZERO
var _has_search_center := false
var _has_search_destination := false
var _last_search_revision := -1
var _search_pause_remaining := 0.0
var _search_pause_pending := false
var _response_commit_remaining := 0.0
var _response_target := Vector3.ZERO
var _has_response_target := false
var _investigation_remaining := 0.0
var _investigation_event_id := 0
var _investigation_source_actor: Node
var _search_elapsed := 0.0
var _search_replan_remaining := 0.0
var _search_role: StringName = &"sweeper"
var _search_center_pending := false
var _retaliation_reaction_remaining := 0.0
var _retaliation_burst_remaining := 0
var _retaliation_shot_remaining := 0.0
var _retaliation_pause_remaining := 0.0


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
	_response_commit_remaining = maxf(
		_response_commit_remaining - delta,
		0.0
	)
	_investigation_remaining = maxf(_investigation_remaining - delta, 0.0)
	_search_replan_remaining = maxf(_search_replan_remaining - delta, 0.0)
	if (
		has_active_investigation()
		and _investigation_source_actor == player
		and perception.can_see_player()
	):
		_confirm_player_weapon_discharge()
		return
	if mode == MODE_PATROL and has_active_investigation():
		mode = MODE_INVESTIGATE
	if mode != _last_mode:
		_trace_mode_transition(_last_mode, mode)
		_enter_mode(mode)
		_last_mode = mode
	match mode:
		MODE_PATROL:
			_tick_patrol(delta)
		MODE_ARREST:
			_tick_arrest(delta)
		MODE_COMBAT:
			_tick_combat(delta)
		MODE_SEARCH_ARREST:
			_tick_search(delta, false, false)
		MODE_SEARCH_COMBAT:
			_tick_search(delta, true, true)
		MODE_CHALLENGE:
			_tick_challenge(delta)
		MODE_SEARCH_CHALLENGE:
			_tick_search(delta, true, false)
		MODE_INVESTIGATE:
			_tick_investigation(delta)


func _trace_mode_transition(previous_mode: int, next_mode: int) -> void:
	var bus := WorldEventBus.find(npc.get_tree())
	if bus == null:
		return
	bus.record_state_transition(
		&"police_ai",
		npc,
		previous_mode,
		next_mode,
		&"behavior_tree_selection",
		{"search_role": String(_search_role), "incident_revision": _last_search_revision}
	)


func note_incident(world_position: Vector3) -> void:
	wanted.report_police_incident(world_position)
	_sync_search_dispatch(true)


func note_investigation(
	world_position: Vector3,
	event_id := 0,
	source_actor: Node = null
) -> void:
	if not world_position.is_finite():
		return
	_investigation_event_id = event_id
	_investigation_source_actor = source_actor
	_investigation_remaining = investigation_lifetime
	_search_elapsed = 0.0
	_search_center = world_position
	_has_search_center = true
	# Keep the exact sound origin as a usable fallback. Navigation may not have
	# completed its first map iteration when a pooled officer hears the event;
	# previously that left the destination at Vector3.ZERO and sent the officer
	# away from the gunshot.
	_last_known_position = world_position
	_has_search_destination = true
	_search_pause_remaining = 0.0
	# Pause at the reported position even when the navigation map has not
	# completed its first iteration and cannot project a destination yet.
	_search_pause_pending = true
	_search_role = _get_stable_search_role()
	_set_search_destination(world_position)


func confirm_wanted_player_gunshot(
	world_position: Vector3,
	event_id := 0
) -> void:
	if wanted == null or wanted.wanted_level <= 0:
		note_investigation(world_position, event_id, player)
		return
	note_investigation(world_position, event_id, player)
	assign_dispatched_response_target(world_position)
	var response_level := maxi(wanted.wanted_level, 2)
	wanted.report_police_incident(
		world_position,
		PoliceIncident.CrimeType.WEAPON_DISCHARGE,
		response_level
	)
	wanted.set_wanted_level(response_level)
	_sync_search_dispatch(true)
	npc.set_facing_override(world_position)


func has_active_investigation() -> bool:
	return _investigation_remaining > 0.0 and _has_search_center


func get_search_debug_state() -> Dictionary:
	return {
		"event_id": _investigation_event_id,
		"role": String(_search_role),
		"center": _search_center,
		"destination": _last_known_position,
		"elapsed": _search_elapsed,
		"remaining": _investigation_remaining,
	}


func get_ai_debug_state() -> Dictionary:
	return {
		"mode": _last_mode,
		"search_role": String(_search_role),
		"search_center": _search_center,
		"search_destination": _last_known_position,
		"investigation_event_id": _investigation_event_id,
		"response_committed": has_committed_response_target(),
	}


func assign_dispatched_response_target(world_position: Vector3) -> void:
	_response_target = world_position
	_has_response_target = true
	_response_commit_remaining = response_commit_seconds
	_last_known_position = world_position
	_search_center = world_position
	_has_search_center = true
	_has_search_destination = true
	_search_pause_remaining = 0.0
	_search_pause_pending = false
	npc.clear_navigation_target()
	npc.set_facing_override(world_position)
	var facing_direction: Vector3 = world_position - npc.global_position
	facing_direction.y = 0.0
	if not facing_direction.is_zero_approx():
		npc.visual.rotation.y = atan2(
			facing_direction.x,
			facing_direction.z
		)


func has_committed_response_target() -> bool:
	return _has_response_target and _response_commit_remaining > 0.0


func has_actionable_wanted_location() -> bool:
	return (
		wanted != null
		and wanted.wanted_level > 0
		and (
			has_committed_response_target()
			or (_has_search_center and _has_search_destination)
		)
	)


func begin_retaliation(_target: Node3D) -> void:
	_retaliation_reaction_remaining = _random.randf_range(0.2, 0.5)
	_retaliation_burst_remaining = 0
	_retaliation_shot_remaining = 0.0
	_retaliation_pause_remaining = 0.0
	combat.set_equipped(true)


func end_retaliation() -> void:
	_retaliation_reaction_remaining = 0.0
	_retaliation_burst_remaining = 0
	_retaliation_shot_remaining = 0.0
	_retaliation_pause_remaining = 0.0
	if combat != null:
		combat.clear_aim()


func tick_retaliation(target: Node3D, delta: float) -> bool:
	if not _is_actor_alive(target):
		return false
	combat.set_equipped(true)
	var target_position := target.global_position + Vector3.UP
	var can_see_target := _has_line_to_actor(target, target_position)
	if not can_see_target:
		combat.clear_aim()
		npc.clear_facing_override()
		_pursue_position(target.global_position, delta)
		return true
	var distance: float = npc.global_position.distance_to(
		target.global_position
	)
	if distance > preferred_combat_distance * 1.25:
		combat.clear_aim()
		npc.clear_facing_override()
		_pursue_position(target.global_position, delta)
		return true
	npc.clear_navigation_target()
	npc.stop_moving(delta)
	npc.set_facing_override(target_position)
	combat.set_aim_target(target_position)
	_retaliation_reaction_remaining = maxf(
		_retaliation_reaction_remaining - delta,
		0.0
	)
	_retaliation_shot_remaining = maxf(
		_retaliation_shot_remaining - delta,
		0.0
	)
	_retaliation_pause_remaining = maxf(
		_retaliation_pause_remaining - delta,
		0.0
	)
	if (
		combat.is_reloading()
		or _retaliation_reaction_remaining > 0.0
		or _retaliation_pause_remaining > 0.0
		or _retaliation_shot_remaining > 0.0
	):
		return true
	if _retaliation_burst_remaining <= 0:
		_retaliation_burst_remaining = _random.randi_range(2, 4)
	if not combat.has_line_of_fire(target, target_position):
		return true
	if combat.try_fire_at(target_position, shot_spread_degrees):
		_retaliation_burst_remaining -= 1
		_retaliation_shot_remaining = _random.randf_range(
			minimum_shot_interval,
			maximum_shot_interval
		)
	if _retaliation_burst_remaining <= 0:
		_retaliation_pause_remaining = _random.randf_range(
			minimum_burst_pause,
			maximum_burst_pause
		)
	return true


func _is_actor_alive(actor: Node3D) -> bool:
	if not is_instance_valid(actor):
		return false
	if actor.has_method("is_defeated"):
		return not bool(actor.call("is_defeated"))
	var health := actor.get_node_or_null("Components/HealthComponent")
	return (
		health == null
		or not health.has_method("is_alive")
		or bool(health.call("is_alive"))
	)


func _has_line_to_actor(
	actor: Node3D,
	world_position: Vector3
) -> bool:
	var origin: Vector3 = npc.global_position + Vector3.UP * 1.35
	var query := PhysicsRayQueryParameters3D.create(origin, world_position)
	query.collision_mask = perception.sight_collision_mask
	query.exclude = [npc.get_rid()]
	var hit: Dictionary = (
		npc.get_world_3d().direct_space_state.intersect_ray(query)
	)
	if hit.is_empty():
		return true
	var current := hit.get("collider") as Node
	while current != null:
		if current == actor:
			return true
		current = current.get_parent()
	return false


func reset_for_reuse() -> void:
	_last_known_position = Vector3.ZERO
	_burst_remaining = 0
	_shot_remaining = 0.0
	_pause_remaining = 0.0
	_has_reposition_target = false
	_last_mode = -1
	_reaction_remaining = 0.0
	_movement_decision_remaining = 0.0
	_combat_strafe_sign = 0.0
	_retreat_cooldown_remaining = 0.0
	_search_center = Vector3.ZERO
	_has_search_center = false
	_has_search_destination = false
	_last_search_revision = -1
	_search_pause_remaining = 0.0
	_search_pause_pending = false
	_response_commit_remaining = 0.0
	_response_target = Vector3.ZERO
	_has_response_target = false
	_investigation_remaining = 0.0
	_investigation_event_id = 0
	_investigation_source_actor = null
	_search_elapsed = 0.0
	_search_replan_remaining = 0.0
	_search_role = _get_stable_search_role()
	_search_center_pending = false
	end_retaliation()


func _enter_mode(mode: int) -> void:
	npc.clear_navigation_target()
	npc.clear_facing_override()
	_has_reposition_target = false
	_burst_remaining = 0
	_pause_remaining = 0.0
	_movement_decision_remaining = 0.0
	_combat_strafe_sign = 0.0
	if mode != MODE_PATROL:
		_sync_search_dispatch(true)
		if perception.can_see_player():
			_last_known_position = player.global_position
	if mode in [MODE_COMBAT, MODE_SEARCH_COMBAT, MODE_CHALLENGE, MODE_SEARCH_CHALLENGE]:
		_reaction_remaining = _random.randf_range(0.35, 0.8)
		combat.set_equipped(true)
	else:
		combat.clear_aim()
		combat.set_equipped(false)


func _tick_patrol(delta: float) -> void:
	npc.move_speed = patrol_speed
	combat.set_equipped(false)
	# The wanted condition runs before this action. Prime fresh dispatch data
	# here so an ambient officer that just lost sight can enter the search branch
	# on the next behavior-tree tick instead of remaining stuck on patrol.
	_sync_search_dispatch()
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
		wanted.report_police_visual_contact(player.global_position)
	else:
		_tick_search(delta, false, false)
		return
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
	_pursue_position(destination, delta)


func _tick_combat(delta: float) -> void:
	combat.set_equipped(true)
	if not player_health.is_alive():
		combat.clear_aim()
		npc.stop_moving(delta)
		return
	var target_position: Vector3 = player.global_position + Vector3.UP
	var sees_player: bool = perception.can_see_player()
	if sees_player:
		_last_known_position = player.global_position
		wanted.report_police_visual_contact(player.global_position)
	else:
		_tick_search(delta, true, true)
		return
	var combat_distance: float = npc.global_position.distance_to(
		player.global_position
	)
	var advance_threshold := preferred_combat_distance * 1.25
	if combat_distance > advance_threshold:
		npc.move_speed = pursuit_speed
		combat.clear_aim()
		_has_reposition_target = false
		var pursuit_position := player.global_position
		# This is a full sprint, not an aimed strafe. Let movement face the
		# officer down the pursuit direction so a forward run never slides
		# sideways while the body remains locked on the player.
		npc.clear_facing_override()
		_pursue_position(pursuit_position, delta)
		return

	_reaction_remaining = maxf(_reaction_remaining - delta, 0.0)
	_movement_decision_remaining = maxf(
		_movement_decision_remaining - delta,
		0.0
	)
	_retreat_cooldown_remaining = maxf(
		_retreat_cooldown_remaining - delta,
		0.0
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
		_burst_remaining = _random.randi_range(2, 4)
	if _shot_remaining > 0.0:
		return
	if not combat.has_line_of_fire(player, target_position):
		# Keep moving laterally to expose a firing lane. Do not start a long
		# navigation run that looks like the officer is fleeing.
		_movement_decision_remaining = minf(
			_movement_decision_remaining,
			combat_strafe_minimum
		)
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


func _update_combat_movement(
	combat_distance: float,
	target_position: Vector3,
	delta: float
) -> void:
	# Close-range officers hold their ground or take short lateral steps. They
	# no longer run several metres away from the attacker through navigation.
	npc.clear_navigation_target()
	_has_reposition_target = false
	if _movement_decision_remaining <= 0.0:
		if is_zero_approx(_combat_strafe_sign):
			_combat_strafe_sign = -1.0 if _random.randf() < 0.5 else 1.0
			_movement_decision_remaining = _random.randf_range(
				combat_strafe_minimum,
				maxf(combat_strafe_maximum, combat_strafe_minimum)
			)
		else:
			_combat_strafe_sign = 0.0
			_movement_decision_remaining = _random.randf_range(
				combat_strafe_pause_minimum,
				maxf(combat_strafe_pause_maximum, combat_strafe_pause_minimum)
			)
	if is_zero_approx(_combat_strafe_sign):
		npc.stop_moving(delta)
		return
	var toward_player: Vector3 = player.global_position - npc.global_position
	toward_player.y = 0.0
	if toward_player.is_zero_approx():
		npc.stop_moving(delta)
		return
	var strafe_direction: Vector3 = toward_player.normalized().rotated(
		Vector3.UP,
		_combat_strafe_sign * PI * 0.5
	)
	# Outside the preferred range, arc slightly inward without ever retreating.
	if combat_distance > preferred_combat_distance:
		strafe_direction = (
			strafe_direction + toward_player.normalized() * 0.3
		).normalized()
	npc.set_facing_override(target_position)
	npc.move_in_world_direction(
		strafe_direction,
		combat_aim_move_speed,
		delta
	)


func _choose_aggressive_reposition(combat_distance: float) -> void:
	_movement_decision_remaining = _random.randf_range(
		movement_decision_minimum,
		movement_decision_maximum
	)
	var roll := _random.randf()
	if combat_distance > preferred_combat_distance:
		var toward: Vector3 = player.global_position - npc.global_position
		toward.y = 0.0
		if toward.is_zero_approx():
			return
		var candidate: Vector3 = (
			npc.global_position
			+ toward.normalized() * _random.randf_range(2.0, 4.0)
		)
		_set_reachable_reposition(candidate)
	elif roll < 0.85:
		_choose_reposition()


func _tick_challenge(delta: float) -> void:
	npc.move_speed = pursuit_speed
	combat.set_equipped(true)
	if not player_health.is_alive():
		combat.clear_aim()
		npc.stop_moving(delta)
		return
	if not perception.can_see_player():
		_tick_search(delta, true, false)
		return
	wanted.report_police_visual_contact(player.global_position)
	_last_known_position = player.global_position
	var target_position := player.global_position + Vector3.UP
	combat.set_aim_target(target_position)
	if (
		npc.global_position.distance_squared_to(player.global_position)
		<= arrest_distance * arrest_distance
	):
		npc.stop_moving(delta)
		npc.set_facing_override(target_position)
		arrest.report_police_contact()
		return
	npc.set_facing_override(target_position)
	_pursue_position(player.global_position, delta, true)


func _tick_search(delta: float, armed: bool, engage_combat: bool) -> void:
	npc.move_speed = pursuit_speed
	combat.set_equipped(armed)
	if not player_health.is_alive():
		combat.clear_aim()
		npc.stop_moving(delta)
		return
	if perception.can_see_player():
		wanted.report_police_visual_contact(player.global_position)
		if armed and engage_combat:
			_tick_combat(delta)
		elif armed:
			_tick_challenge(delta)
		else:
			_tick_arrest(delta)
		return
	if _response_commit_remaining > 0.0 and _has_response_target:
		_chase_dispatched_response_target(delta)
		return
	_sync_search_dispatch()
	_chase_last_known(delta)


func _tick_investigation(delta: float) -> void:
	npc.move_speed = patrol_speed
	combat.clear_aim()
	combat.set_equipped(false)
	_search_elapsed += delta
	if not has_active_investigation():
		npc.clear_navigation_target()
		return
	if (
		npc.global_position.distance_squared_to(_last_known_position)
		> 1.5 * 1.5
	):
		npc.set_navigation_target(_last_known_position)
		npc.advance_navigation(delta)
		return
	npc.stop_moving(delta)
	if _search_pause_pending:
		_search_pause_remaining = _random.randf_range(
			search_pause_minimum,
			search_pause_maximum
		)
		_search_pause_pending = false
	if _search_pause_remaining > 0.0:
		_search_pause_remaining = maxf(
			_search_pause_remaining - delta,
			0.0
		)
		return
	if _search_replan_remaining <= 0.0:
		_choose_search_position()
		_search_replan_remaining = search_replan_interval


func _chase_dispatched_response_target(delta: float) -> void:
	combat.clear_aim()
	_last_known_position = _response_target
	if npc.global_position.distance_squared_to(_response_target) <= 1.5 * 1.5:
		npc.stop_moving(delta)
		npc.set_facing_override(_response_target)
		_response_commit_remaining = 0.0
		return
	# Officers traveling to an incident are not aiming yet. Their full-body run
	# should follow the path; target-facing is restored after they arrive or
	# enter an armed challenge/combat state.
	npc.clear_facing_override()
	_pursue_position(_response_target, delta)


func _confirm_player_weapon_discharge() -> void:
	_last_known_position = player.global_position
	_search_center = player.global_position
	_has_search_center = true
	_has_search_destination = true
	_investigation_remaining = 0.0
	_investigation_source_actor = null
	var next_wanted_level := 1 if wanted.wanted_level <= 0 else 2
	wanted.report_police_incident(
		player.global_position,
		PoliceIncident.CrimeType.WEAPON_DISCHARGE,
		next_wanted_level
	)
	wanted.set_wanted_level(maxi(wanted.wanted_level, next_wanted_level))
	wanted.report_police_visual_contact(player.global_position)
	npc.clear_navigation_target()
	npc.set_facing_override(player.global_position)


func _chase_last_known(delta: float) -> void:
	combat.clear_aim()
	_sync_search_dispatch()
	if not _has_search_destination:
		npc.stop_moving(delta)
		return
	if (
		npc.global_position.distance_squared_to(_last_known_position)
		> 2.25
	):
		if _search_center_pending:
			_pursue_position(_last_known_position, delta)
		else:
			npc.set_navigation_intent(
				_last_known_position,
				&"police_search",
				80
			)
			npc.advance_navigation(delta)
	else:
		npc.stop_moving(delta)
		_search_center_pending = false
		if _has_search_center:
			npc.set_facing_override(_search_center)
		if _search_pause_pending:
			_search_pause_remaining = _random.randf_range(
				search_pause_minimum,
				search_pause_maximum
			)
			_search_pause_pending = false
		if _search_pause_remaining > 0.0:
			_search_pause_remaining = maxf(
				_search_pause_remaining - delta,
				0.0
			)
			return
		_choose_search_position()


func _pursue_position(
	world_position: Vector3,
	delta: float,
	preserve_facing := false
) -> void:
	var offset: Vector3 = world_position - npc.global_position
	offset.y = 0.0
	if offset.is_zero_approx():
		npc.stop_moving(delta)
		return
	if (
		offset.length_squared() <= direct_pursuit_range * direct_pursuit_range
		and perception.has_unobstructed_line_to(
			world_position + Vector3.UP,
			direct_pursuit_range
		)
	):
		# Bypass pedestrian/crosswalk routing when there is open space between
		# officer and suspect. Local probes still steer around cars and props.
		npc.clear_navigation_target()
		if not preserve_facing:
			npc.clear_facing_override()
		npc.move_in_world_direction(offset, pursuit_speed, delta)
		return
	if not preserve_facing:
		npc.clear_facing_override()
	npc.set_navigation_intent(world_position, &"police_pursuit", 100)
	npc.advance_navigation(delta)


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
	_movement_decision_remaining = _random.randf_range(
		movement_decision_minimum,
		movement_decision_maximum
	)


func _choose_retreat_position(combat_distance: float) -> void:
	var away: Vector3 = npc.global_position - player.global_position
	away.y = 0.0
	if away.is_zero_approx():
		away = Vector3.FORWARD
	var candidate: Vector3 = (
		npc.global_position
		+ away.normalized()
		* maxf(retreat_target_distance - combat_distance, 1.5)
	)
	_set_reachable_reposition(candidate)
	_movement_decision_remaining = minf(
		1.0,
		movement_decision_maximum
	)


func _choose_search_position() -> void:
	if not _has_search_center:
		return
	var role_angle := _get_search_role_angle()
	var angle := role_angle + _random.randf_range(-PI * 0.35, PI * 0.35)
	var phase_radius := search_outer_radius
	if _search_elapsed <= 3.0:
		phase_radius = minf(3.0, search_outer_radius)
	elif _search_elapsed <= 12.0:
		phase_radius = minf(6.0, search_outer_radius)
	var candidate := _search_center + Vector3(
		cos(angle),
		0.0,
		sin(angle)
	) * _random.randf_range(search_inner_radius, phase_radius)
	_set_search_destination(candidate)


func _sync_search_dispatch(force := false) -> void:
	if wanted == null or not wanted.has_police_search_position:
		return
	if (
		not force
		and _last_search_revision == wanted.police_search_revision
	):
		return
	_last_search_revision = wanted.police_search_revision
	_search_center = wanted.police_search_position
	var incident := wanted.active_incident as PoliceIncident
	if incident != null:
		var observation_age := maxf(
			Time.get_ticks_msec() * 0.001 - incident.observed_at_seconds,
			0.0
		)
		_search_center += incident.last_known_velocity * minf(
			observation_age,
			4.0
		) * incident.confidence
	_has_search_center = true
	_search_role = _get_stable_search_role()
	# Intercept every fresh report exactly before fanning out. Replacing a new
	# location with a random perimeter point made officers run away from a
	# shooter they had just located.
	_search_center_pending = true
	_set_search_destination(_search_center)
	_search_elapsed = 0.0
	_search_role = _get_stable_search_role()


func _get_stable_search_role() -> StringName:
	var index := int(npc.get_instance_id()) % 3 if npc != null else 2
	return [&"tracker", &"cutoff", &"sweeper"][index]


func _get_search_role_angle() -> float:
	match _search_role:
		&"tracker":
			return 0.0
		&"cutoff":
			return PI * 0.66
		_:
			return -PI * 0.66


func _set_search_destination(candidate: Vector3) -> void:
	var navigation_map: RID = npc.navigation_agent.get_navigation_map()
	if (
		not navigation_map.is_valid()
		or NavigationServer3D.map_get_iteration_id(navigation_map) == 0
	):
		return
	var reachable := NavigationServer3D.map_get_closest_point(
		navigation_map,
		candidate
	)
	_last_known_position = reachable
	_has_search_destination = true
	_search_pause_remaining = 0.0
	_search_pause_pending = true


func _set_reachable_reposition(candidate: Vector3) -> void:
	var navigation_map: RID = npc.navigation_agent.get_navigation_map()
	if (
		not navigation_map.is_valid()
		or NavigationServer3D.map_get_iteration_id(navigation_map) == 0
	):
		return
	var reachable := NavigationServer3D.map_get_closest_point(
		navigation_map,
		candidate
	)
	if reachable.is_equal_approx(Vector3.ZERO):
		return
	_reposition_target = reachable
	_has_reposition_target = true
