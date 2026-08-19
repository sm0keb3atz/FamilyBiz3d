class_name PoliceNPC
extends BaseNPC

const PoliceObservationData := preload("res://Scripts/Gameplay/police_observation.gd")

@export var use_clean_slate_brain := true

@onready var role_component := (
	$Components/RoleComponent as PoliceRoleComponent
)
@onready var patrol_component := (
	$Components/PatrolComponent as PedestrianPatrolComponent
)
@onready var perception_component := (
	$Components/PerceptionComponent as PolicePerceptionComponent
)
@onready var combat_component := (
	$Components/CombatComponent as NPCCombatComponent
)
@onready var ai_component := (
	$Components/AIComponent as PoliceAIComponent
)
@onready var brain_component := (
	$Components/BrainComponent as PoliceBrainComponent
)
@onready var bt_player := $BTPlayer as BTPlayer
@onready var role_label := $RoleLabel as Label3D
@onready var awareness_badge := $AwarenessBadge as Label3D

var _pool_active := false
var _target_player: CharacterBody3D
var _wanted: PlayerWantedComponent
var _response_assigned := false
var _response_id := 0
var _retaliation_target: Node3D


func _ready() -> void:
	super()
	add_to_group(&"world_event_listener")
	role_component.initialize(self)
	patrol_component.initialize(self)
	combat_component.initialize(self)
	damageable.damaged.connect(_on_damaged)
	bt_player.set_active(false)
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func _process(_delta: float) -> void:
	if _pool_active and use_clean_slate_brain:
		_update_awareness_badge()


func prepare_for_pool_spawn(
	network: PedestrianNetwork3D,
	start_waypoint: PedestrianWaypoint3D,
	random_seed: int,
	player: CharacterBody3D
) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	reset_for_reuse()
	_pool_active = true
	_target_player = player
	_wanted = player.get_node(
		"Components/WantedComponent"
	) as PlayerWantedComponent
	if not _wanted.wanted_level_changed.is_connected(
		_on_wanted_level_changed
	):
		_wanted.wanted_level_changed.connect(_on_wanted_level_changed)
	patrol_component.assign_route(network, start_waypoint, random_seed)
	global_position = patrol_component.get_spawn_position()
	perception_component.initialize(self, player)
	ai_component.initialize(self, player)
	brain_component.initialize(self, player)
	combat_component.reset_for_reuse()
	ai_component.reset_for_reuse()
	role_component.activate()
	if use_clean_slate_brain:
		bt_player.set_active(false)
		brain_component.activate()
	else:
		brain_component.deactivate()
		bt_player.restart()
		bt_player.set_active(true)


func prepare_for_response_spawn(
	network: PedestrianNetwork3D,
	spawn_position: Vector3,
	random_seed: int,
	player: CharacterBody3D,
	response_id: int,
	response_target: Vector3
) -> bool:
	var start_waypoint := network.get_nearest_waypoint(spawn_position, 35.0)
	if start_waypoint == null:
		return false
	prepare_for_pool_spawn(network, start_waypoint, random_seed, player)
	var navigation_map := navigation_agent.get_navigation_map()
	var grounded_spawn := spawn_position
	if (
		navigation_map.is_valid()
		and NavigationServer3D.map_get_iteration_id(navigation_map) > 0
	):
		var reachable := NavigationServer3D.map_get_closest_point(
			navigation_map,
			spawn_position
		)
		if reachable.distance_to(spawn_position) <= 4.0:
			grounded_spawn = reachable
	global_position = grounded_spawn
	assign_police_response(response_id)
	ai_component.assign_dispatched_response_target(response_target)
	brain_component.assign_response_target(response_target)
	return true


func prepare_for_pool_recycle() -> void:
	if not _pool_active or is_defeated():
		return
	_pool_active = false
	clear_police_response()
	clear_retaliation_target()
	bt_player.set_active(false)
	brain_component.deactivate()
	role_component.deactivate()
	combat_component.set_equipped(false)
	patrol_component.clear()
	clear_navigation_target()
	velocity = Vector3.ZERO
	audio_component.stop_all()
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func can_be_recycled() -> bool:
	return (
		_pool_active
		and not is_defeated()
		and not _response_assigned
	)


func is_pool_active() -> bool:
	return _pool_active


func assign_police_response(response_id: int) -> void:
	_response_assigned = true
	_response_id = response_id
	if bt_player != null and not use_clean_slate_brain:
		bt_player.restart()


func resume_police_response(response_id: int, response_target: Vector3) -> void:
	assign_police_response(response_id)
	ai_component.assign_dispatched_response_target(response_target)
	brain_component.assign_response_target(response_target)
	if use_clean_slate_brain:
		brain_component.activate()
	elif bt_player != null:
		bt_player.set_active(true)


func clear_police_response() -> void:
	_response_assigned = false
	_response_id = 0


func is_response_assigned() -> bool:
	return _response_assigned


func get_response_id() -> int:
	return _response_id


func set_crowd_detail_enabled(enabled: bool) -> void:
	set_navigation_avoidance_enabled(enabled)
	set_local_obstacle_steering_enabled(enabled)


func set_role_label_visible(enabled: bool) -> void:
	role_label.visible = enabled


func get_wanted_level() -> int:
	return _wanted.wanted_level if _wanted != null else 0


func is_force_authorized() -> bool:
	return _wanted != null and _wanted.is_force_authorized


func is_player_compliant() -> bool:
	var coordinator: Node = get_tree().get_first_node_in_group(&"police_coordinator")
	return coordinator != null and coordinator.is_player_compliant()


func has_active_police_investigation() -> bool:
	return (
		brain_component.has_active_investigation()
		if use_clean_slate_brain
		else ai_component != null and ai_component.has_active_investigation()
	)


func abort_police_ai_mode(mode: int) -> void:
	if ai_component != null:
		ai_component.abort_mode(mode)


func get_police_blackboard_state() -> Dictionary:
	var coordinator: Node = get_tree().get_first_node_in_group(&"police_coordinator")
	var assignment_role: StringName = &""
	var last_known := Vector3.ZERO
	var phase := 0
	var threat := 0
	var compliant := false
	if coordinator != null and coordinator.has_actionable_intelligence():
		var assignment: Dictionary = coordinator.get_search_assignment(get_instance_id())
		assignment_role = StringName(assignment.get("role", &""))
		last_known = coordinator.last_known_position
		phase = int(coordinator.phase)
		threat = int(coordinator.threat_state)
		compliant = coordinator.is_player_compliant()
	return {
		&"target_visible": perception_component.can_see_player(),
		&"last_known_position": last_known,
		&"threat_state": threat,
		&"combat_range": (
			global_position.distance_to(_target_player.global_position)
			if is_instance_valid(_target_player) else 0.0
		),
		&"compliant": compliant,
		&"assignment_role": assignment_role,
		&"perception_confidence": (
			1.0 if perception_component.can_see_player() else 0.0
		),
		&"police_phase": phase,
	}


func can_see_wanted_player() -> bool:
	return (
		_pool_active
		and _wanted != null
		and _wanted.wanted_level > 0
		and perception_component.can_see_player()
	)


func has_confirmed_wanted_player_location() -> bool:
	return (
		_pool_active
		and _wanted != null
		and _wanted.wanted_level > 0
		and (
			brain_component.has_actionable_wanted_location()
			if use_clean_slate_brain
			else ai_component.has_actionable_wanted_location()
		)
	)


func get_police_ai_debug_state() -> Dictionary:
	return (
		brain_component.get_debug_state()
		if use_clean_slate_brain
		else ai_component.get_ai_debug_state()
	)


func tick_ai_mode(mode: int, delta: float) -> void:
	if _pool_active:
		_update_awareness_badge()
		if get_wanted_level() <= 0:
			if _retaliation_target == _target_player:
				clear_retaliation_target()
			ai_component.tick_mode(PoliceAIComponent.MODE_PATROL, delta)
			return
		if is_instance_valid(_retaliation_target):
			if ai_component.tick_retaliation(_retaliation_target, delta):
				return
			clear_retaliation_target()
		ai_component.tick_mode(mode, delta)


func can_witness_position(world_position: Vector3) -> bool:
	return (
		_pool_active
		and perception_component.can_witness_position(world_position)
	)


func can_hear_position(world_position: Vector3) -> bool:
	return (
		_pool_active
		and perception_component.can_hear_position(world_position)
	)


func set_detection_debug_visible(enabled: bool) -> void:
	perception_component.set_debug_draw_visible(enabled)


func hear_gunshot(source_position: Vector3, hearing_radius: float) -> void:
	var effective_radius := minf(
		hearing_radius,
		perception_component.hearing_range
	)
	if (
		_pool_active
		and global_position.distance_squared_to(source_position)
		<= effective_radius * effective_radius
	):
		_note_investigation(source_position)


func handle_world_event(event: WorldEvent) -> void:
	if (
		event == null
		or event.source_actor == self
		or event.source_faction == &"police"
	):
		return
	if event.event_type == WorldEvent.Type.BODY_DISCOVERED:
		if bool(event.metadata.get("police_exempt", false)):
			return
		if not can_hear_position(event.world_position):
			return
		_note_investigation(event.world_position, event.event_id, null)
		var body_coordinator: Node = get_tree().get_first_node_in_group(
			&"police_coordinator"
		)
		if body_coordinator != null:
			body_coordinator.submit_observation(PoliceObservationData.create(
				PoliceObservationData.Kind.BODY,
				event.world_position,
				self,
				null,
				0.9,
				Vector3.ZERO,
				event.event_id
			))
		return
	if event.event_type != WorldEvent.Type.GUNSHOT:
		return
	var effective_radius := minf(
		event.audible_radius,
		perception_component.hearing_range
	)
	if (
		_pool_active
		and global_position.distance_squared_to(event.world_position)
		<= effective_radius * effective_radius
	):
		var hearing_confidence := perception_component.get_hearing_confidence(
			event.world_position
		)
		if hearing_confidence < 0.12:
			return
		if bool(event.metadata.get("police_exempt", false)):
			_note_investigation(
				event.world_position,
				event.event_id,
				null
			)
			return
		_note_investigation(
			event.world_position,
			event.event_id,
			event.source_actor
		)
		var coordinator: Node = get_tree().get_first_node_in_group(&"police_coordinator")
		if coordinator != null:
			coordinator.report_sound(
				self,
				event.world_position,
				hearing_confidence,
				event.event_id
			)


func get_faction_id() -> StringName:
	return &"police"


func get_combat_target() -> Node3D:
	return (
		_retaliation_target
		if is_instance_valid(_retaliation_target)
		else _target_player
	)


func clear_retaliation_target() -> void:
	_retaliation_target = null
	if brain_component != null:
		brain_component.clear_retaliation_target()
	if ai_component != null:
		ai_component.end_retaliation()


func _on_wanted_level_changed(_previous: int, current: int) -> void:
	if current > 0 or not _pool_active:
		return
	clear_retaliation_target()
	brain_component.cancel_wanted_engagement()
	ai_component.cancel_wanted_engagement()


func _on_damaged(
	_amount: float,
	_remaining_health: float,
	source: Node,
	_hit_position: Vector3,
	_hit_direction: Vector3
) -> void:
	var attacker := _find_combat_actor(source)
	if (
		attacker == null
		or not attacker.has_method("get_faction_id")
		or StringName(attacker.call("get_faction_id")) != &"player_allies"
	):
		return
	_retaliation_target = attacker
	brain_component.set_retaliation_target(attacker)
	ai_component.begin_retaliation(attacker)


func _find_combat_actor(source: Node) -> Node3D:
	var current := source
	while current != null:
		if current is Node3D and (
			current.is_in_group(&"player")
			or current.has_method("get_faction_id")
		):
			return current as Node3D
		current = current.get_parent()
	return null


func _update_awareness_badge() -> void:
	if awareness_badge == null or _target_player == null:
		return
	if global_position.distance_squared_to(_target_player.global_position) > 45.0 * 45.0:
		awareness_badge.visible = false
		return
	if can_see_wanted_player():
		awareness_badge.text = "!"
		awareness_badge.modulate = Color(1.0, 0.2, 0.14, 1.0)
		awareness_badge.visible = true
	elif (
		brain_component.is_searching()
		if use_clean_slate_brain
		else ai_component.has_active_investigation()
			or has_confirmed_wanted_player_location()
	):
		awareness_badge.text = "?"
		awareness_badge.modulate = Color(1.0, 0.78, 0.12, 1.0)
		awareness_badge.visible = true
	else:
		awareness_badge.visible = false


func _on_defeated(
	source: Node,
	hit_position: Vector3,
	hit_direction: Vector3
) -> void:
	_pool_active = false
	clear_police_response()
	clear_retaliation_target()
	brain_component.deactivate()
	role_component.deactivate()
	combat_component.set_equipped(false)
	if bt_player != null:
		bt_player.set_active(false)
	super(source, hit_position, hit_direction)


func _note_investigation(
	world_position: Vector3,
	event_id := 0,
	source_actor: Node = null
) -> void:
	# Keep the legacy component synchronized for rollback and old diagnostic
	# tools, but only the clean-slate brain drives movement in normal gameplay.
	ai_component.note_investigation(world_position, event_id, source_actor)
	if use_clean_slate_brain:
		brain_component.note_investigation(
			world_position,
			event_id,
			source_actor
		)
