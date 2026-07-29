class_name PoliceNPC
extends BaseNPC

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
@onready var bt_player := $BTPlayer as BTPlayer
@onready var role_label := $RoleLabel as Label3D

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
	combat_component.reset_for_reuse()
	ai_component.reset_for_reuse()
	role_component.activate()
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
	return true


func prepare_for_pool_recycle() -> void:
	if not _pool_active or is_defeated():
		return
	_pool_active = false
	clear_police_response()
	clear_retaliation_target()
	bt_player.set_active(false)
	role_component.deactivate()
	combat_component.set_equipped(false)
	patrol_component.clear()
	clear_navigation_target()
	velocity = Vector3.ZERO
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
	if bt_player != null:
		bt_player.restart()


func resume_police_response(response_id: int, response_target: Vector3) -> void:
	assign_police_response(response_id)
	ai_component.assign_dispatched_response_target(response_target)
	if bt_player != null:
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
		and ai_component.has_actionable_wanted_location()
	)


func tick_ai_mode(mode: int, delta: float) -> void:
	if _pool_active:
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
		ai_component.note_investigation(source_position)


func handle_world_event(event: WorldEvent) -> void:
	if (
		event == null
		or event.event_type != WorldEvent.Type.GUNSHOT
		or event.source_actor == self
		or event.source_faction == &"police"
	):
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
		if event.source_actor == _target_player and get_wanted_level() > 0:
			ai_component.confirm_wanted_player_gunshot(
				event.world_position,
				event.event_id
			)
			return
		ai_component.note_investigation(
			event.world_position,
			event.event_id,
			event.source_actor
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
	if ai_component != null:
		ai_component.end_retaliation()


func _on_wanted_level_changed(_previous: int, current: int) -> void:
	if current > 0 or not _pool_active:
		return
	clear_retaliation_target()
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


func _on_defeated(
	source: Node,
	hit_position: Vector3,
	hit_direction: Vector3
) -> void:
	_pool_active = false
	clear_police_response()
	clear_retaliation_target()
	role_component.deactivate()
	combat_component.set_equipped(false)
	if bt_player != null:
		bt_player.set_active(false)
	super(source, hit_position, hit_direction)
