class_name PoliceBrainComponent
extends Node

enum State {
	INACTIVE,
	PATROL,
	RESPOND,
	INVESTIGATE,
	SEARCH,
	ARREST,
	CHALLENGE,
	COMBAT,
	SURRENDER,
}

const STATE_NAMES := [
	&"inactive",
	&"patrol",
	&"respond",
	&"investigate",
	&"search",
	&"arrest",
	&"challenge",
	&"combat",
	&"surrender",
]

@export_category("Movement")
@export_range(0.5, 8.0, 0.1) var patrol_speed := 2.5
@export_range(1.0, 12.0, 0.1) var pursuit_speed := 5.5
@export_range(0.5, 6.0, 0.1) var aimed_move_speed := 2.3
@export_range(0.5, 5.0, 0.1) var arrest_distance := 1.8
@export_range(2.0, 20.0, 0.5) var challenge_hold_distance := 7.0
@export_range(2.0, 20.0, 0.5) var minimum_combat_distance := 7.0
@export_range(5.0, 40.0, 0.5) var preferred_combat_distance := 18.0
@export_range(10.0, 60.0, 0.5) var maximum_combat_distance := 32.0
@export_range(5.0, 80.0, 1.0) var direct_movement_range := 36.0

@export_category("Search")
@export_range(0.5, 5.0, 0.1) var search_arrival_distance := 1.5
@export_range(0.1, 5.0, 0.1) var search_scan_minimum := 0.8
@export_range(0.1, 5.0, 0.1) var search_scan_maximum := 1.4
@export_range(1.0, 20.0, 0.5) var search_initial_radius := 4.0
@export_range(0.5, 10.0, 0.5) var search_radius_step := 3.0
@export_range(5.0, 60.0, 1.0) var search_maximum_radius := 28.0
@export_range(0.5, 5.0, 0.1) var intelligence_retarget_distance := 2.0
@export_range(0.5, 5.0, 0.1) var movement_stall_timeout := 1.5
@export_range(0.05, 1.0, 0.05) var movement_progress_distance := 0.25
@export_range(5.0, 90.0, 1.0) var investigation_lifetime := 30.0
@export_range(1.0, 15.0, 0.5) var response_commit_seconds := 7.0

@export_category("Combat")
@export_range(0.1, 3.0, 0.05) var visual_memory_seconds := 0.9
@export_range(0.0, 10.0, 0.1) var minimum_burst_pause := 0.8
@export_range(0.0, 10.0, 0.1) var maximum_burst_pause := 1.5
@export_range(0.05, 1.0, 0.01) var minimum_shot_interval := 0.18
@export_range(0.05, 1.0, 0.01) var maximum_shot_interval := 0.31
@export_range(0.0, 15.0, 0.1) var shot_spread_degrees := 3.5

var npc: PoliceNPC
var player: CharacterBody3D
var wanted: PlayerWantedComponent
var arrest: PlayerArrestComponent
var player_health: PlayerHealthComponent
var patrol: PedestrianPatrolComponent
var perception: PolicePerceptionComponent
var combat: NPCCombatComponent
var coordinator: Node

var _active := false
var _state := State.INACTIVE
var _state_elapsed := 0.0
var _state_reason: StringName = &"disabled"
var _random := RandomNumberGenerator.new()

var _response_target := Vector3.ZERO
var _has_response_target := false
var _response_remaining := 0.0

var _investigation_center := Vector3.ZERO
var _investigation_source: Node
var _investigation_event_id := 0
var _investigation_remaining := 0.0

var _search_center := Vector3.ZERO
var _search_destination := Vector3.ZERO
var _has_search_center := false
var _has_search_destination := false
var _search_revision := -1
var _search_role: StringName = &"tracker"
var _search_waypoint_index := 0
var _search_scan_remaining := 0.0
var _search_scanning := false
var _search_elapsed := 0.0

var _progress_position := Vector3.ZERO
var _stall_elapsed := 0.0
var _stall_repaths := 0

var _retaliation_target: Node3D
var _last_seen_position := Vector3.ZERO
var _visual_memory_remaining := 0.0
var _reaction_remaining := 0.0
var _shot_remaining := 0.0
var _burst_pause_remaining := 0.0
var _burst_remaining := 0
var _strafe_sign := 1.0
var _strafe_remaining := 0.0


func _ready() -> void:
	set_physics_process(false)


func initialize(owner_npc: PoliceNPC, target_player: CharacterBody3D) -> void:
	npc = owner_npc
	player = target_player
	wanted = player.get_node("Components/WantedComponent") as PlayerWantedComponent
	arrest = player.get_node("Components/ArrestComponent") as PlayerArrestComponent
	player_health = player.get_node("Components/HealthComponent") as PlayerHealthComponent
	patrol = npc.patrol_component
	perception = npc.perception_component
	combat = npc.combat_component
	coordinator = player.get_tree().get_first_node_in_group(&"police_coordinator")
	_random.seed = npc.get_instance_id() * 7919 + Time.get_ticks_msec()
	reset_for_reuse()


func activate() -> void:
	_active = true
	_progress_position = npc.global_position
	_change_state(State.PATROL, &"spawned")
	set_physics_process(true)


func deactivate() -> void:
	_active = false
	set_physics_process(false)
	_change_state(State.INACTIVE, &"pooled")
	if combat != null:
		combat.clear_aim()
		combat.set_equipped(false)
	if npc != null:
		npc.clear_navigation_target()
		npc.clear_facing_override()


func reset_for_reuse() -> void:
	_state = State.INACTIVE
	_state_elapsed = 0.0
	_state_reason = &"reset"
	_response_target = Vector3.ZERO
	_has_response_target = false
	_response_remaining = 0.0
	_investigation_center = Vector3.ZERO
	_investigation_source = null
	_investigation_event_id = 0
	_investigation_remaining = 0.0
	_clear_search()
	_retaliation_target = null
	_last_seen_position = Vector3.ZERO
	_visual_memory_remaining = 0.0
	_reaction_remaining = 0.0
	_shot_remaining = 0.0
	_burst_pause_remaining = 0.0
	_burst_remaining = 0
	_strafe_sign = 1.0
	_strafe_remaining = 0.0
	_progress_position = npc.global_position if npc != null else Vector3.ZERO
	_stall_elapsed = 0.0
	_stall_repaths = 0


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if not _active or npc == null or npc.is_defeated() or player == null:
		return
	_state_elapsed += delta
	_response_remaining = maxf(_response_remaining - delta, 0.0)
	_investigation_remaining = maxf(_investigation_remaining - delta, 0.0)
	_visual_memory_remaining = maxf(_visual_memory_remaining - delta, 0.0)
	_reaction_remaining = maxf(_reaction_remaining - delta, 0.0)
	_shot_remaining = maxf(_shot_remaining - delta, 0.0)
	_burst_pause_remaining = maxf(_burst_pause_remaining - delta, 0.0)
	_strafe_remaining = maxf(_strafe_remaining - delta, 0.0)

	var sees_player := perception.can_see_player()
	if sees_player:
		_last_seen_position = player.global_position
		_visual_memory_remaining = visual_memory_seconds
		if wanted.wanted_level > 0:
			_report_visual_contact()

	if _should_confirm_investigation(sees_player):
		_confirm_player_weapon_discharge()
		sees_player = true

	var desired_state := _select_state(sees_player)
	if desired_state != _state:
		_change_state(desired_state, _transition_reason(desired_state, sees_player))

	match _state:
		State.PATROL:
			_tick_patrol(delta)
		State.RESPOND:
			_tick_respond(delta)
		State.INVESTIGATE:
			_tick_investigate(delta)
		State.SEARCH:
			_tick_search(delta)
		State.ARREST:
			_tick_arrest(delta)
		State.CHALLENGE:
			_tick_challenge(delta)
		State.COMBAT:
			_tick_combat(delta)
		State.SURRENDER:
			_tick_surrender(delta)


func _select_state(sees_player: bool) -> int:
	if is_instance_valid(_retaliation_target):
		return State.COMBAT
	if wanted == null or wanted.wanted_level <= 0:
		return State.INVESTIGATE if has_active_investigation() else State.PATROL
	if not player_health.is_alive():
		return State.SEARCH
	if sees_player:
		if coordinator != null and coordinator.is_player_compliant():
			return State.SURRENDER
		if wanted.is_force_authorized:
			return State.COMBAT
		return State.ARREST if wanted.wanted_level <= 1 else State.CHALLENGE
	if (
		_state == State.COMBAT
		and wanted.is_force_authorized
		and _visual_memory_remaining > 0.0
	):
		return State.COMBAT
	if has_committed_response_target():
		return State.RESPOND
	return State.SEARCH


func _transition_reason(next_state: int, sees_player: bool) -> StringName:
	match next_state:
		State.PATROL:
			return &"no_active_incident"
		State.RESPOND:
			return &"assigned_response"
		State.INVESTIGATE:
			return &"anonymous_observation"
		State.SEARCH:
			return &"lost_visual" if not sees_player else &"search_order"
		State.ARREST:
			return &"low_risk_visual"
		State.CHALLENGE:
			return &"challenge_visual"
		State.COMBAT:
			return &"authorized_force"
		State.SURRENDER:
			return &"player_compliant"
	return &"state_change"


func _change_state(next_state: int, reason: StringName) -> void:
	if _state == next_state and _state_reason == reason:
		return
	var previous := _state
	_state = next_state
	_state_elapsed = 0.0
	_state_reason = reason
	_stall_elapsed = 0.0
	_stall_repaths = 0
	_progress_position = npc.global_position if npc != null else Vector3.ZERO
	if npc == null:
		return
	npc.clear_navigation_target()
	npc.clear_facing_override()
	combat.clear_aim()
	var should_equip := next_state in [
		State.CHALLENGE,
		State.COMBAT,
		State.SURRENDER,
	] or (next_state == State.SEARCH and wanted != null and wanted.wanted_level >= 2)
	combat.set_equipped(should_equip)
	if next_state == State.COMBAT:
		_reaction_remaining = _random.randf_range(0.35, 0.75)
		_burst_remaining = 0
		_shot_remaining = 0.0
		_burst_pause_remaining = 0.0
	if next_state in [State.ARREST, State.CHALLENGE, State.COMBAT, State.SURRENDER]:
		npc.audio_component.play_police_aggro()
	if next_state in [State.SEARCH, State.INVESTIGATE]:
		_search_scanning = false
		_search_scan_remaining = 0.0
	_trace_transition(previous, next_state, reason)


func _tick_patrol(delta: float) -> void:
	_state_reason = &"following_patrol_route"
	npc.move_speed = patrol_speed
	combat.set_equipped(false)
	patrol.tick_patrol(delta)


func _tick_respond(delta: float) -> void:
	combat.set_equipped(wanted != null and wanted.wanted_level >= 2)
	if not _has_response_target or _response_remaining <= 0.0:
		_has_response_target = false
		_begin_search_from_intelligence()
		_change_state(State.SEARCH, &"response_expired")
		_tick_search(delta)
		return
	if npc.global_position.distance_to(_response_target) <= search_arrival_distance:
		_has_response_target = false
		_response_remaining = 0.0
		npc.clear_navigation_target()
		_begin_search_at(_response_target)
		_change_state(State.SEARCH, &"arrived_on_scene")
		_tick_search(delta)
		return
	_state_reason = &"traveling_to_incident"
	_move_to(_response_target, pursuit_speed, &"police_response", 100, delta)


func _tick_investigate(delta: float) -> void:
	combat.set_equipped(false)
	if not has_active_investigation():
		_change_state(State.PATROL, &"investigation_expired")
		_tick_patrol(delta)
		return
	if not _has_search_center:
		_begin_search_at(_investigation_center)
	_tick_search_pattern(delta, patrol_speed, &"police_investigation", 60)


func _tick_search(delta: float) -> void:
	_search_elapsed += delta
	_refresh_search_intelligence()
	if not _has_search_center:
		_begin_search_from_intelligence()
	if not _has_search_center:
		_state_reason = &"waiting_for_incident_location"
		npc.stop_moving(delta)
		return
	_tick_search_pattern(delta, pursuit_speed, &"police_search", 80)


func _tick_search_pattern(
	delta: float,
	speed: float,
	intent_owner: StringName,
	intent_priority: int
) -> void:
	if not _has_search_destination:
		_choose_next_search_destination()
	if not _has_search_destination:
		_state_reason = &"waiting_for_search_destination"
		npc.stop_moving(delta)
		return
	var distance := npc.global_position.distance_to(_search_destination)
	if distance > search_arrival_distance:
		_search_scanning = false
		_state_reason = &"moving_to_search_point"
		_move_to(
			_search_destination,
			speed,
			intent_owner,
			intent_priority,
			delta
		)
		return
	npc.clear_navigation_target()
	npc.stop_moving(delta)
	if not _search_scanning:
		_search_scanning = true
		_search_scan_remaining = _random.randf_range(
			search_scan_minimum,
			maxf(search_scan_maximum, search_scan_minimum)
		)
	if _search_scan_remaining > 0.0:
		_search_scan_remaining = maxf(_search_scan_remaining - delta, 0.0)
		_state_reason = &"scanning_area"
		_update_scan_facing()
		return
	_search_scanning = false
	_search_waypoint_index += 1
	_choose_next_search_destination()


func _tick_arrest(delta: float) -> void:
	combat.set_equipped(false)
	if not perception.can_see_player():
		_change_state(State.SEARCH, &"lost_arrest_visual")
		_tick_search(delta)
		return
	var distance := npc.global_position.distance_to(player.global_position)
	if distance <= arrest_distance:
		_state_reason = &"making_arrest_contact"
		npc.clear_navigation_target()
		npc.stop_moving(delta)
		npc.set_facing_override(player.global_position)
		arrest.report_police_contact()
		return
	_state_reason = &"closing_for_arrest"
	_move_to(player.global_position, pursuit_speed, &"police_arrest", 100, delta)


func _tick_challenge(delta: float) -> void:
	combat.set_equipped(true)
	if not perception.can_see_player():
		combat.clear_aim()
		_change_state(State.SEARCH, &"lost_challenge_visual")
		_tick_search(delta)
		return
	var target_position := player.global_position + Vector3.UP
	combat.set_aim_target(target_position)
	npc.set_facing_override(target_position)
	var distance := npc.global_position.distance_to(player.global_position)
	if distance <= arrest_distance:
		_state_reason = &"challenge_contact"
		npc.clear_navigation_target()
		npc.stop_moving(delta)
		arrest.report_police_contact()
		return
	if distance <= challenge_hold_distance:
		_state_reason = &"holding_at_gunpoint"
		npc.clear_navigation_target()
		npc.stop_moving(delta)
		return
	_state_reason = &"closing_to_challenge"
	_move_to(player.global_position, pursuit_speed, &"police_challenge", 100, delta, true)


func _tick_surrender(delta: float) -> void:
	combat.set_equipped(true)
	var target_position := player.global_position + Vector3.UP
	combat.set_aim_target(target_position)
	npc.set_facing_override(target_position)
	var distance := npc.global_position.distance_to(player.global_position)
	var contact_officer := _search_role == &"tracker"
	if distance <= arrest_distance:
		_state_reason = &"arresting_compliant_player"
		npc.clear_navigation_target()
		npc.stop_moving(delta)
		arrest.report_police_contact()
		return
	if not contact_officer and distance <= 10.0:
		_state_reason = &"covering_arrest"
		npc.clear_navigation_target()
		npc.stop_moving(delta)
		return
	_state_reason = &"approaching_compliant_player"
	_move_to(player.global_position, aimed_move_speed, &"police_surrender", 100, delta, true)


func _tick_combat(delta: float) -> void:
	combat.set_equipped(true)
	var target := _retaliation_target if is_instance_valid(_retaliation_target) else player
	var pursuing_player := target == player
	if pursuing_player and perception.player_vehicle != null and perception.player_vehicle.is_driving():
		target = perception.player_vehicle.get_current_vehicle()
	if not _is_actor_alive(target):
		clear_retaliation_target()
		combat.clear_aim()
		return
	var target_position := target.global_position + Vector3.UP
	var target_visible := (
		perception.can_see_player()
		if pursuing_player
		else _has_line_to_actor(target, target_position)
	)
	if target_visible:
		_last_seen_position = target.global_position
		_visual_memory_remaining = visual_memory_seconds
	if not target_visible:
		combat.clear_aim()
		if _visual_memory_remaining > 0.0:
			_state_reason = &"pursuing_recent_visual"
			_move_to(_last_seen_position, pursuit_speed, &"police_combat_memory", 110, delta)
			return
		if pursuing_player:
			_change_state(State.SEARCH, &"combat_visual_expired")
			_tick_search(delta)
		else:
			clear_retaliation_target()
		return
	combat.set_aim_target(target_position)
	var distance := npc.global_position.distance_to(target.global_position)
	_update_combat_movement(target, target_position, distance, delta)
	if combat.is_reloading() or _reaction_remaining > 0.0:
		return
	if _burst_pause_remaining > 0.0 or _shot_remaining > 0.0:
		return
	if not combat.has_line_of_fire(target, target_position):
		_state_reason = &"seeking_clear_shot"
		_strafe_remaining = 0.0
		return
	if _burst_remaining <= 0:
		_burst_remaining = _random.randi_range(2, 4)
	if combat.try_fire_at(target_position, shot_spread_degrees):
		_state_reason = &"firing_burst"
		_burst_remaining -= 1
		_shot_remaining = _random.randf_range(
			minimum_shot_interval,
			maximum_shot_interval
		)
	if _burst_remaining <= 0:
		_burst_pause_remaining = _random.randf_range(
			minimum_burst_pause,
			maximum_burst_pause
		)


func _update_combat_movement(
	target: Node3D,
	target_position: Vector3,
	distance: float,
	delta: float
) -> void:
	if distance > maximum_combat_distance:
		_state_reason = &"closing_combat_distance"
		combat.clear_aim()
		_move_to(target.global_position, pursuit_speed, &"police_combat", 110, delta)
		return
	npc.clear_navigation_target()
	if _strafe_remaining <= 0.0:
		_strafe_sign = -_strafe_sign
		_strafe_remaining = _random.randf_range(1.5, 2.8)
	var toward := target.global_position - npc.global_position
	toward.y = 0.0
	if toward.is_zero_approx():
		toward = Vector3.FORWARD
	var direction := toward.normalized().rotated(
		Vector3.UP,
		_strafe_sign * PI * 0.5
	)
	if distance < minimum_combat_distance or combat.is_reloading():
		direction = (direction - toward.normalized() * 0.9).normalized()
	elif distance > preferred_combat_distance:
		direction = (direction + toward.normalized() * 0.55).normalized()
	_state_reason = &"combat_strafe"
	npc.set_facing_override(target_position)
	# Use navigable tactical destinations rather than blindly strafing into cars
	# or walls. Hold position when projection cannot provide meaningful movement.
	var destination := _project_destination(npc.global_position + direction * 3.0)
	if destination.distance_squared_to(npc.global_position) < 0.25:
		_strafe_remaining = 0.0
		npc.stop_moving(delta)
		return
	_move_to(destination, aimed_move_speed, &"police_combat", 110, delta, true)


func _move_to(
	destination: Vector3,
	speed: float,
	intent_owner: StringName,
	intent_priority: int,
	delta: float,
	preserve_facing := false
) -> void:
	if not destination.is_finite():
		_state_reason = &"invalid_destination"
		npc.stop_moving(delta)
		return
	var offset := destination - npc.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.01:
		npc.clear_navigation_target()
		npc.stop_moving(delta)
		return
	npc.move_speed = speed
	var can_move_direct := (
		offset.length_squared() <= direct_movement_range * direct_movement_range
		and perception.has_unobstructed_line_to(
			destination + Vector3.UP,
			direct_movement_range
		)
	)
	if can_move_direct:
		npc.clear_navigation_target()
		if not preserve_facing:
			npc.clear_facing_override()
		npc.move_in_world_direction(offset, speed, delta)
	else:
		if not preserve_facing:
			npc.clear_facing_override()
		npc.set_navigation_intent(destination, intent_owner, intent_priority)
		npc.advance_navigation(delta)
	_update_movement_watchdog(destination, intent_owner, intent_priority, delta)


func _update_movement_watchdog(
	destination: Vector3,
	intent_owner: StringName,
	intent_priority: int,
	delta: float
) -> void:
	if npc.global_position.distance_squared_to(_progress_position) >= (
		movement_progress_distance * movement_progress_distance
	):
		_progress_position = npc.global_position
		_stall_elapsed = 0.0
		_stall_repaths = 0
		return
	_stall_elapsed += delta
	if _stall_elapsed < movement_stall_timeout:
		return
	_stall_elapsed = 0.0
	_stall_repaths += 1
	npc.clear_navigation_target()
	if _stall_repaths <= 2:
		npc.movement_component.set_navigation_intent(
			destination,
			intent_owner,
			intent_priority,
			true
		)
		_state_reason = &"repathing_stalled_movement"
		return
	if _state in [State.SEARCH, State.INVESTIGATE]:
		_search_waypoint_index += 1
		_choose_next_search_destination()
		_state_reason = &"abandoning_stalled_search_point"
	_stall_repaths = 0


func _refresh_search_intelligence() -> void:
	var center := Vector3.ZERO
	var assignment_destination := Vector3.ZERO
	var revision := -1
	var role: StringName = _search_role
	var has_intelligence := false
	if coordinator != null and coordinator.has_actionable_intelligence():
		var assignment: Dictionary = coordinator.get_search_assignment(
			npc.get_instance_id()
		)
		center = assignment.get("center", coordinator.last_known_position)
		assignment_destination = assignment.get("destination", center)
		revision = int(assignment.get("revision", -1))
		role = StringName(assignment.get("role", &"tracker"))
		has_intelligence = true
	elif wanted != null and wanted.has_police_search_position:
		center = wanted.police_search_position
		assignment_destination = center
		revision = wanted.police_search_revision
		role = _stable_role()
		has_intelligence = true
	elif wanted != null and wanted.active_incident != null:
		center = wanted.active_incident.last_known_player_position
		assignment_destination = center
		revision = int(wanted.active_incident.revision)
		role = _stable_role()
		has_intelligence = true
	if not has_intelligence or not center.is_finite():
		return
	var center_changed := (
		not _has_search_center
		or _search_center.distance_squared_to(center)
		>= intelligence_retarget_distance * intelligence_retarget_distance
	)
	_search_revision = revision
	_search_role = role
	if not center_changed:
		return
	_search_center = center
	_has_search_center = true
	_search_waypoint_index = 0
	_search_elapsed = 0.0
	_search_scanning = false
	_search_scan_remaining = 0.0
	_search_destination = _project_destination(assignment_destination)
	_has_search_destination = true
	npc.clear_navigation_target()
	_progress_position = npc.global_position
	_stall_elapsed = 0.0


func _begin_search_from_intelligence() -> void:
	_refresh_search_intelligence()
	if _has_search_center:
		return
	if wanted != null and wanted.active_incident != null:
		_begin_search_at(wanted.active_incident.last_known_player_position)
	elif _last_seen_position.is_finite() and not _last_seen_position.is_zero_approx():
		_begin_search_at(_last_seen_position)


func _begin_search_at(center: Vector3) -> void:
	if not center.is_finite():
		return
	_search_center = center
	_has_search_center = true
	_search_destination = _project_destination(center)
	_has_search_destination = true
	_search_waypoint_index = 0
	_search_scan_remaining = 0.0
	_search_scanning = false
	_search_elapsed = 0.0
	_progress_position = npc.global_position
	_stall_elapsed = 0.0


func _choose_next_search_destination() -> void:
	if not _has_search_center:
		_has_search_destination = false
		return
	var role_angle := _role_angle(_search_role)
	var sequence_index := _search_waypoint_index + int(npc.get_instance_id() % 5)
	var ring := sequence_index / 2
	var radius := minf(
		search_initial_radius + float(ring) * search_radius_step,
		search_maximum_radius
	)
	var angle := role_angle + float(sequence_index) * 2.399963
	var candidate := _search_center + Vector3(cos(angle), 0.0, sin(angle)) * radius
	_search_destination = _project_destination(candidate)
	_has_search_destination = true
	_search_scanning = false
	_search_scan_remaining = 0.0
	_progress_position = npc.global_position
	_stall_elapsed = 0.0
	npc.clear_navigation_target()


func _project_destination(candidate: Vector3) -> Vector3:
	if not candidate.is_finite():
		return npc.global_position
	var navigation_map := npc.navigation_agent.get_navigation_map()
	if (
		navigation_map.is_valid()
		and NavigationServer3D.map_get_iteration_id(navigation_map) > 0
	):
		var projected := NavigationServer3D.map_get_closest_point(
			navigation_map,
			candidate
		)
		if projected.is_finite():
			return projected
	return candidate


func _update_scan_facing() -> void:
	var base_direction := _search_center - npc.global_position
	base_direction.y = 0.0
	if base_direction.is_zero_approx():
		base_direction = npc.visual.global_basis.z
	var phase := _state_elapsed * 3.5 + float(npc.get_instance_id() % 11)
	var angle := sin(phase) * deg_to_rad(65.0)
	npc.set_facing_override(
		npc.global_position
		+ base_direction.normalized().rotated(Vector3.UP, angle)
	)


func assign_response_target(world_position: Vector3) -> void:
	if not world_position.is_finite():
		return
	_response_target = world_position
	_has_response_target = true
	_response_remaining = response_commit_seconds
	_begin_search_at(world_position)
	if _active:
		_change_state(State.RESPOND, &"dispatch_assignment")


func has_committed_response_target() -> bool:
	return _has_response_target and _response_remaining > 0.0


func note_investigation(
	world_position: Vector3,
	event_id := 0,
	source_actor: Node = null
) -> void:
	if not world_position.is_finite():
		return
	_investigation_center = world_position
	_investigation_event_id = event_id
	_investigation_source = source_actor
	_investigation_remaining = investigation_lifetime
	_begin_search_at(world_position)
	if _active and (wanted == null or wanted.wanted_level <= 0):
		_change_state(State.INVESTIGATE, &"observation_received")


func has_active_investigation() -> bool:
	return _investigation_remaining > 0.0


func has_actionable_wanted_location() -> bool:
	return (
		wanted != null
		and wanted.wanted_level > 0
		and (
			has_committed_response_target()
			or _has_search_center
			or (coordinator != null and coordinator.has_actionable_intelligence())
		)
	)


func set_retaliation_target(target: Node3D) -> void:
	_retaliation_target = target
	_reaction_remaining = _random.randf_range(0.2, 0.5)
	_burst_remaining = 0
	if is_instance_valid(target):
		_last_seen_position = target.global_position
		_visual_memory_remaining = visual_memory_seconds
	if _active:
		_change_state(State.COMBAT, &"attacked")


func clear_retaliation_target() -> void:
	_retaliation_target = null


func cancel_wanted_engagement() -> void:
	_has_response_target = false
	_response_remaining = 0.0
	# Resolved incidents must not be reopened by an old gunshot observation.
	_investigation_remaining = 0.0
	_investigation_source = null
	_investigation_event_id = 0
	clear_retaliation_target()
	_clear_search()
	_visual_memory_remaining = 0.0
	combat.clear_aim()
	combat.set_equipped(false)
	npc.clear_navigation_target()
	npc.clear_facing_override()
	if _active:
		_change_state(
			State.INVESTIGATE if has_active_investigation() else State.PATROL,
			&"wanted_cleared"
		)


func get_debug_state() -> Dictionary:
	return {
		"brain": "clean_slate",
		"state": get_state_name(),
		"state_id": _state,
		"reason": String(_state_reason),
		"state_elapsed": _state_elapsed,
		"search_role": String(_search_role),
		"search_center": _search_center,
		"destination": _search_destination,
		"has_destination": _has_search_destination,
		"search_waypoint": _search_waypoint_index,
		"scan_remaining": _search_scan_remaining,
		"stall_elapsed": _stall_elapsed,
		"stall_repaths": _stall_repaths,
		"response_committed": has_committed_response_target(),
		"investigation_remaining": _investigation_remaining,
		"navigation": npc.movement_component.get_navigation_debug_state(),
	}


func get_state_name() -> StringName:
	return STATE_NAMES[_state]


func is_searching() -> bool:
	return _state in [State.RESPOND, State.INVESTIGATE, State.SEARCH]


func force_search_for_test(center: Vector3) -> void:
	_begin_search_at(center)
	_change_state(State.SEARCH, &"test_search")


func _should_confirm_investigation(sees_player: bool) -> bool:
	if not has_active_investigation() or not sees_player:
		return false
	if _investigation_source == player:
		return true
	return (
		_investigation_source == null
		and wanted != null
		and wanted.weapon_component != null
		and wanted.weapon_component.get_equipped_weapon() != null
	)


func _confirm_player_weapon_discharge() -> void:
	_investigation_remaining = 0.0
	_investigation_source = null
	var level := maxi(wanted.wanted_level, 2)
	wanted.report_police_incident(
		player.global_position,
		PoliceIncident.CrimeType.WEAPON_DISCHARGE,
		level
	)
	wanted.set_wanted_level(level)
	wanted.set_force_authorized(true)
	_report_visual_contact()


func _report_visual_contact() -> void:
	if coordinator != null:
		coordinator.report_visual_contact(npc, player.global_position)
	else:
		wanted.report_police_visual_contact(player.global_position)


func _stable_role() -> StringName:
	var roles := [&"tracker", &"left_sweeper", &"right_sweeper", &"cutoff"]
	return roles[int(npc.get_instance_id()) % roles.size()]


func _role_angle(role: StringName) -> float:
	match role:
		&"left_sweeper":
			return PI * 0.55
		&"right_sweeper":
			return -PI * 0.55
		&"cutoff":
			return PI
	return 0.0


func _clear_search() -> void:
	_search_center = Vector3.ZERO
	_search_destination = Vector3.ZERO
	_has_search_center = false
	_has_search_destination = false
	_search_revision = -1
	_search_role = &"tracker"
	_search_waypoint_index = 0
	_search_scan_remaining = 0.0
	_search_scanning = false
	_search_elapsed = 0.0


func _is_actor_alive(actor: Node3D) -> bool:
	if not is_instance_valid(actor):
		return false
	if actor.has_method("is_defeated"):
		return not bool(actor.call("is_defeated"))
	var health := actor.get_node_or_null("Components/HealthComponent")
	return health == null or not health.has_method("is_alive") or bool(health.call("is_alive"))


func _has_line_to_actor(actor: Node3D, world_position: Vector3) -> bool:
	var origin := npc.global_position + Vector3.UP * 1.35
	var query := PhysicsRayQueryParameters3D.create(origin, world_position)
	query.collision_mask = perception.sight_collision_mask
	query.exclude = [npc.get_rid()]
	var hit := npc.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var current := hit.get("collider") as Node
	while current != null:
		if current == actor:
			return true
		current = current.get_parent()
	return false


func _trace_transition(previous: int, next_state: int, reason: StringName) -> void:
	var bus := WorldEventBus.find(npc.get_tree())
	if bus == null:
		return
	bus.record_state_transition(
		&"police_brain",
		npc,
		previous,
		next_state,
		reason,
		{
			"state": String(STATE_NAMES[next_state]),
			"role": String(_search_role),
			"destination": _search_destination,
		}
	)
