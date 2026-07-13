class_name CustomerNPC
extends BaseNPC

enum State {
	ROAMING,
	APPROACHING,
	WAITING,
	RETURNING,
	PANICKING,
}

const GIRLFRIEND_FOLLOWING := &"FOLLOWING"
const GIRLFRIEND_HOME := &"HOME"

const EVENT_SOLICITED := &"solicited"
const EVENT_REACHED_PLAYER := &"reached_player"
const EVENT_RETURN_TO_ROUTE := &"return_to_route"
const EVENT_RESUMED_ROUTE := &"resumed_route"
const EVENT_GUNSHOT_HEARD := &"gunshot_heard"
const EVENT_PANIC_FINISHED := &"panic_finished"
const CUSTOMER_OUTLINE_SHADER := preload(
	"res://Assets/VFX/Shaders/target_lock_outline.gdshader"
)

@export_range(0.5, 5.0, 0.1) var player_stop_distance := 1.6
@export_range(0.5, 10.0, 0.1) var route_stop_distance := 0.75
@export_range(0.0, 60.0, 0.5) var cooldown_duration := 5.0
@export_range(1.0, 60.0, 0.5) var waiting_duration := 12.0
@export_range(1.0, 60.0, 0.5) var approach_timeout := 15.0
@export_range(1.0, 60.0, 0.5) var return_timeout := 20.0
@export_range(0.1, 5.0, 0.1) var player_repath_distance := 0.75
@export_range(0.05, 2.0, 0.05) var player_repath_interval := 0.25
@export_range(0.1, 1.0, 0.05) var departure_turn_timeout := 0.45
@export_range(2.0, 30.0, 1.0) var departure_facing_tolerance := 8.0

@export_category("Crowd Variation")
@export_range(0.0, 2.0, 0.05) var route_lane_half_width := 1.1
@export_range(0.0, 2.0, 0.05) var speed_variation := 0.0
@export_range(0.5, 5.0, 0.1) var route_stuck_timeout := 1.75
@export_range(0.75, 4.0, 0.05) var corner_anticipation_distance := 2.0

@export_category("Panic")
@export_range(2.0, 12.0, 0.1) var panic_move_speed := 6.5
@export_range(0.5, 2.0, 0.05) var panic_animation_speed_scale := 1.0
@export_range(5.0, 100.0, 1.0) var panic_safe_distance := 32.0
@export_range(0.5, 30.0, 0.5) var panic_minimum_duration := 4.0
@export_range(1.0, 60.0, 0.5) var panic_maximum_duration := 12.0

@export_category("Solicitation Outline")
@export var solicitation_outline_color := Color(1.0, 0.78, 0.18, 1.0)
@export_range(0.0, 0.3, 0.005) var solicitation_outline_thickness := 0.028
@export_range(0.0, 4.0, 0.05) var solicitation_outline_energy := 1.35
@export_range(0.0, 1.0, 0.05) var solicitation_outline_transparency := 0.9

@onready var hsm := $LimboHSM as LimboHSM
@onready var roaming_state := $LimboHSM/Roaming as LimboState
@onready var approaching_state := $LimboHSM/Approaching as LimboState
@onready var waiting_state := $LimboHSM/Waiting as LimboState
@onready var returning_state := $LimboHSM/Returning as LimboState
@onready var panicking_state := $LimboHSM/Panicking as LimboState
@onready var role_label := $RoleLabel as Label3D
@onready var role_component := (
	$Components/RoleComponent as CivilianRoleComponent
)

var product_wanted: ProductDefinition:
	get:
		return role_component.product_wanted

var amount_wanted: int:
	get:
		return role_component.amount_wanted

var _state := State.ROAMING
var _home_position := Vector3.ZERO
var _target_player: CharacterBody3D
var _network: PedestrianNetwork3D
var _previous_waypoint: PedestrianWaypoint3D
var _current_waypoint: PedestrianWaypoint3D
var _route_target: PedestrianWaypoint3D
var _resume_waypoint: PedestrianWaypoint3D
var _resume_route_target: PedestrianWaypoint3D
var _waiting_remaining := 0.0
var _solicitation_cooldown := 0.0
var _state_elapsed := 0.0
var _repath_remaining := 0.0
var _last_player_path_target := Vector3.INF
var _pool_active := true
var _random := RandomNumberGenerator.new()
var _base_move_speed := 2.5
var _base_walk_animation_speed_scale := 2.0
var _route_lane_offset := 0.0
var _route_stuck_elapsed := 0.0
var _crowd_detail_enabled := true
var _roaming_move_speed := 2.5
var _roaming_animation_speed_scale := 2.0
var _panic_source_position := Vector3.ZERO
var _cached_route_target_position := Vector3.ZERO
var _cached_return_position := Vector3.ZERO
var _departure_turn_remaining := 0.0
var _solicitation_outline_material: ShaderMaterial
var _solicitation_outline_overlays: Dictionary[int, Array] = {}
var _girlfriend_roster: PlayerGirlfriendComponent
var _girlfriend_player: CharacterBody3D
var _girlfriend_status := &""
var _girlfriend_follow_slot := 0
var _girlfriend_repath_remaining := 0.0
var _civilian_name := "Woman"


func _ready() -> void:
	super()
	_home_position = global_position
	_random.randomize()
	_base_move_speed = move_speed
	_base_walk_animation_speed_scale = walk_animation_speed_scale
	_roaming_move_speed = move_speed
	_roaming_animation_speed_scale = walk_animation_speed_scale
	appearance_component.randomize_civilian_appearance(_random)
	role_component.initialize(self)
	role_component.activate()
	_initialize_solicitation_outline()
	navigation_agent.path_desired_distance = 0.3
	navigation_agent.target_desired_distance = route_stop_distance
	navigation_agent.max_speed = move_speed
	_initialize_state_machine()


func can_respond_to_solicitation() -> bool:
	return role_component.can_respond_to_solicitation()


func can_player_fill_order(player: CharacterBody3D) -> bool:
	return role_component.can_player_fill_order(player)


func respond_to_solicitation(player: CharacterBody3D) -> bool:
	return role_component.respond_to_solicitation(player)


func assign_solicitation_order(
	requested_product: ProductDefinition,
	requested_amount: int
) -> void:
	role_component.assign_solicitation_order(
		requested_product,
		requested_amount
	)


func roll_solicitation_amount() -> int:
	return role_component.roll_solicitation_amount()


func get_solicitation_amount_range() -> Vector2i:
	return role_component.get_solicitation_amount_range()


func is_committed_to_solicitation(player: CharacterBody3D) -> bool:
	return (
		player == _target_player
		and _state in [State.APPROACHING, State.WAITING]
	)


func is_solicitation_ready() -> bool:
	return is_zero_approx(_solicitation_cooldown)


func begin_solicitation(player: CharacterBody3D) -> void:
	_target_player = player
	_resume_waypoint = (
		_route_target
		if is_instance_valid(_route_target)
		else _current_waypoint
	)
	_resume_route_target = null
	if (
		_network != null
		and is_instance_valid(_resume_waypoint)
	):
		_resume_route_target = _network.get_next_waypoint(
			_resume_waypoint,
			_current_waypoint,
			_random
		)
	hsm.dispatch(EVENT_SOLICITED)


func is_waiting_for_customer_trade(player: CharacterBody3D) -> bool:
	return _state == State.WAITING and player == _target_player


func finish_customer_trade() -> void:
	hsm.dispatch(EVENT_RETURN_TO_ROUTE)


func can_interact(player: CharacterBody3D) -> bool:
	if can_receive_gift(player):
		return true
	return role_component.can_interact(player)


func get_interaction_prompt(player: CharacterBody3D) -> String:
	if can_receive_gift(player):
		return "E - Give money to %s" % _civilian_name
	return role_component.get_interaction_prompt(player)


func interact(player: CharacterBody3D) -> void:
	if can_receive_gift(player):
		var gift_menu := player.get_node_or_null("GirlfriendGiftMenu")
		if gift_menu != null and gift_menu.has_method("open_for"):
			gift_menu.call("open_for", self)
		return
	role_component.interact(player)


func can_receive_gift(player: CharacterBody3D) -> bool:
	return _girlfriend_status == GIRLFRIEND_FOLLOWING and player == _girlfriend_player and _girlfriend_roster != null and not is_defeated()


func get_state_name() -> String:
	if not _girlfriend_status.is_empty():
		return String(_girlfriend_status)
	return State.keys()[_state]


func get_customer_level() -> int:
	return role_component.customer_level


func get_civilian_name() -> String:
	return _civilian_name


func is_female_civilian() -> bool:
	return appearance_component.get_body_variant() == PlayerAppearanceComponent.BODY_VARIANT_FEMALE


func is_recruited_girlfriend() -> bool:
	return _girlfriend_roster != null


func can_attempt_girlfriend_recruitment(player: CharacterBody3D) -> bool:
	return player != null and _pool_active and not is_defeated() and _state == State.ROAMING and _girlfriend_roster == null and is_female_civilian() and player.get_node_or_null("Components/GirlfriendComponent") is PlayerGirlfriendComponent


func attempt_girlfriend_recruitment(player: CharacterBody3D) -> void:
	var roster := player.get_node_or_null("Components/GirlfriendComponent") as PlayerGirlfriendComponent
	var hud := player.get_node_or_null("PlayerHUD") as PlayerHUD
	if roster == null:
		return
	var required := roster.get_aura_requirement(get_customer_level())
	if roster.get_current_aura() < required:
		if hud != null:
			hud.show_feedback("She rejected you. Level %d requires %d Aura." % [get_customer_level(), required])
		return
	roster.recruit(self)


func begin_girlfriend_following(player: CharacterBody3D, roster: PlayerGirlfriendComponent, follow_slot: int) -> void:
	_girlfriend_player = player
	_girlfriend_roster = roster
	_girlfriend_follow_slot = follow_slot
	_girlfriend_status = GIRLFRIEND_FOLLOWING
	_civilian_name = str(roster.get_roster()[follow_slot]["name"])
	hsm.set_active(false)
	role_component.deactivate()
	add_to_group(&"girlfriend_npc")
	add_to_group(&"interactable")
	set_physics_process(true)


func set_girlfriend_follow_slot(slot: int) -> void:
	_girlfriend_follow_slot = maxi(slot, 0)


func send_girlfriend_home() -> void:
	_girlfriend_status = GIRLFRIEND_HOME
	_girlfriend_player = null
	move_speed = _roaming_move_speed
	navigation_agent.max_speed = move_speed
	remove_from_group(&"interactable")
	hsm.set_active(true)
	role_component.activate()


func call_girlfriend(player: CharacterBody3D, follow_slot: int) -> void:
	_girlfriend_player = player
	_girlfriend_follow_slot = follow_slot
	_girlfriend_status = GIRLFRIEND_FOLLOWING
	hsm.set_active(false)
	role_component.deactivate()
	add_to_group(&"interactable")
	var side := -1.0 if follow_slot % 2 == 0 else 1.0
	var spawn_position := player.global_position + player.global_basis.z * 8.0 + player.global_basis.x * side * (2.0 + float(follow_slot / 2))
	var navigation_map := navigation_agent.get_navigation_map()
	if navigation_map.is_valid():
		spawn_position = NavigationServer3D.map_get_closest_point(navigation_map, spawn_position)
	global_position = spawn_position
	velocity = Vector3.ZERO
	navigation_agent.set_velocity_forced(Vector3.ZERO)


func end_girlfriend_relationship() -> void:
	_girlfriend_roster = null
	_girlfriend_player = null
	_girlfriend_status = &""
	move_speed = _roaming_move_speed
	navigation_agent.max_speed = move_speed
	remove_from_group(&"girlfriend_npc")
	remove_from_group(&"interactable")
	hsm.set_active(true)
	role_component.activate()


func _physics_process(delta: float) -> void:
	if _girlfriend_status != GIRLFRIEND_FOLLOWING:
		return
	if not is_instance_valid(_girlfriend_player) or is_defeated():
		stop_moving(delta)
		return
	var player_movement := _girlfriend_player.get_node_or_null("Components/MovementComponent") as PlayerMovementComponent
	var sprinting := player_movement != null and player_movement.is_sprinting()
	move_speed = player_movement.run_speed if sprinting else _roaming_move_speed
	navigation_agent.max_speed = move_speed
	var row := float(_girlfriend_follow_slot / 2)
	var side := -1.0 if _girlfriend_follow_slot % 2 == 0 else 1.0
	var target := _girlfriend_player.global_position + _girlfriend_player.global_basis.z * (2.2 + row * 1.2) + _girlfriend_player.global_basis.x * side * (1.0 + row * 0.4)
	_girlfriend_repath_remaining = maxf(_girlfriend_repath_remaining - delta, 0.0)
	if _girlfriend_repath_remaining <= 0.0:
		set_navigation_target(target)
		_girlfriend_repath_remaining = 0.25
	if global_position.distance_squared_to(target) > 1.4 * 1.4:
		advance_navigation(delta)
	else:
		stop_moving(delta)


func apply_customer_level_style(level: int) -> void:
	match clampi(level, 1, 4):
		1:
			solicitation_outline_color = Color(0.18, 1.0, 0.38, 1.0)
		2:
			solicitation_outline_color = Color(0.18, 0.55, 1.0, 1.0)
		3:
			solicitation_outline_color = Color(0.72, 0.28, 1.0, 1.0)
		4:
			solicitation_outline_color = Color(1.0, 0.78, 0.18, 1.0)
	if _solicitation_outline_material != null:
		_solicitation_outline_material.set_shader_parameter(
			&"outline_color",
			Vector3(
				solicitation_outline_color.r,
				solicitation_outline_color.g,
				solicitation_outline_color.b
			)
		)


func get_solicitation_outline_mesh_count() -> int:
	return _solicitation_outline_overlays.size()


func assign_route(
	network: PedestrianNetwork3D,
	start_waypoint: PedestrianWaypoint3D
) -> void:
	_network = network
	_current_waypoint = start_waypoint
	_previous_waypoint = null
	_route_target = null
	_resume_waypoint = start_waypoint
	_resume_route_target = null
	_route_stuck_elapsed = 0.0
	_cached_route_target_position = start_waypoint.global_position
	_choose_next_route_target()


func prepare_for_pool_spawn(
	network: PedestrianNetwork3D,
	start_waypoint: PedestrianWaypoint3D,
	random_seed: int
) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	hsm.set_active(false)
	reset_for_reuse()
	_pool_active = true
	_random.seed = random_seed
	appearance_component.randomize_civilian_appearance(_random)
	_apply_crowd_variation()
	_target_player = null
	_solicitation_cooldown = 0.0
	assign_route(network, start_waypoint)
	global_position = _get_route_start_position()
	_home_position = global_position
	navigation_agent.set_velocity_forced(Vector3.ZERO)
	role_component.activate()
	hsm.set_active(true)


func prepare_for_pool_recycle() -> void:
	if not _pool_active or is_defeated():
		return
	_pool_active = false
	hsm.set_active(false)
	set_navigation_avoidance_enabled(false)
	set_local_obstacle_steering_enabled(false)
	set_visual_animation_active(false)
	clear_navigation_target()
	velocity = Vector3.ZERO
	_target_player = null
	_panic_source_position = Vector3.ZERO
	_network = null
	_previous_waypoint = null
	_current_waypoint = null
	_route_target = null
	_resume_waypoint = null
	_resume_route_target = null
	_cached_route_target_position = Vector3.ZERO
	_cached_return_position = Vector3.ZERO
	role_component.deactivate()
	_clear_solicitation_outline()
	body_collision.set_deferred("disabled", true)
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func can_be_recycled() -> bool:
	return (
		_pool_active
		and _girlfriend_roster == null
		and not is_defeated()
		and _network != null
		and _state == State.ROAMING
	)


func hear_gunshot(source_position: Vector3, hearing_radius: float) -> void:
	if (
		not _pool_active
		or is_defeated()
		or _network == null
		or global_position.distance_squared_to(source_position)
		> hearing_radius * hearing_radius
	):
		return
	_panic_source_position = source_position
	_target_player = null
	if _state == State.PANICKING:
		_state_elapsed = 0.0
		_begin_panic_route()
		return
	hsm.dispatch(EVENT_GUNSHOT_HEARD)


func is_pool_active() -> bool:
	return _pool_active


func set_crowd_detail_enabled(enabled: bool) -> void:
	_crowd_detail_enabled = enabled
	set_local_obstacle_steering_enabled(
		enabled or _state == State.PANICKING
	)
	_refresh_navigation_avoidance()


func set_role_label_visible(enabled: bool) -> void:
	role_label.visible = enabled


func get_current_waypoint() -> PedestrianWaypoint3D:
	return _current_waypoint


func get_route_target() -> PedestrianWaypoint3D:
	return _route_target


func _initialize_state_machine() -> void:
	hsm.add_transition(
		roaming_state,
		approaching_state,
		EVENT_SOLICITED
	)
	hsm.add_transition(
		approaching_state,
		waiting_state,
		EVENT_REACHED_PLAYER
	)
	hsm.add_transition(
		approaching_state,
		returning_state,
		EVENT_RETURN_TO_ROUTE
	)
	hsm.add_transition(
		waiting_state,
		returning_state,
		EVENT_RETURN_TO_ROUTE
	)
	hsm.add_transition(
		returning_state,
		roaming_state,
		EVENT_RESUMED_ROUTE
	)
	hsm.add_transition(
		hsm.ANYSTATE,
		panicking_state,
		EVENT_GUNSHOT_HEARD
	)
	hsm.add_transition(
		panicking_state,
		roaming_state,
		EVENT_PANIC_FINISHED
	)
	hsm.initialize(self)
	hsm.set_active(true)


func _limbo_state_enter(state_id: int) -> void:
	_state = state_id
	_state_elapsed = 0.0
	match _state:
		State.ROAMING:
			_clear_solicitation_outline()
			_target_player = null
			_departure_turn_remaining = 0.0
			navigation_agent.target_desired_distance = route_stop_distance
			if _network != null and _route_target == null:
				_choose_next_route_target()
			if is_instance_valid(_route_target):
				set_navigation_target(_get_route_target_position())
				_refresh_navigation_avoidance()
			else:
				set_navigation_avoidance_enabled(false)
				clear_navigation_target()
		State.APPROACHING:
			_apply_solicitation_outline()
			navigation_agent.target_desired_distance = player_stop_distance
			_repath_remaining = 0.0
			_last_player_path_target = Vector3.INF
			_refresh_navigation_avoidance()
			_update_player_navigation_target(true)
		State.WAITING:
			_apply_solicitation_outline()
			_waiting_remaining = waiting_duration
			set_navigation_avoidance_enabled(false)
			clear_navigation_target()
		State.RETURNING:
			_clear_solicitation_outline()
			_solicitation_cooldown = cooldown_duration
			navigation_agent.target_desired_distance = route_stop_distance
			_cached_return_position = _get_return_position()
			set_navigation_target(_cached_return_position)
			_departure_turn_remaining = departure_turn_timeout
			set_navigation_avoidance_enabled(false)
			set_local_obstacle_steering_enabled(false)
		State.PANICKING:
			_clear_solicitation_outline()
			_solicitation_cooldown = cooldown_duration
			navigation_agent.target_desired_distance = route_stop_distance
			move_speed = panic_move_speed
			walk_animation_speed_scale = panic_animation_speed_scale
			navigation_agent.max_speed = panic_move_speed
			set_local_obstacle_steering_enabled(true)
			_refresh_navigation_avoidance()
			_begin_panic_route()


func _limbo_state_update(state_id: int, delta: float) -> void:
	if is_defeated() or not _pool_active or state_id != _state:
		return
	_solicitation_cooldown = maxf(
		_solicitation_cooldown - delta,
		0.0
	)
	_state_elapsed += delta
	match _state:
		State.ROAMING:
			_update_roaming(delta)
		State.APPROACHING:
			_update_approaching(delta)
		State.WAITING:
			_update_waiting(delta)
		State.RETURNING:
			_update_returning(delta)
		State.PANICKING:
			_update_panicking(delta)


func _limbo_state_exit(state_id: int) -> void:
	if state_id in [State.APPROACHING, State.WAITING]:
		_clear_solicitation_outline()
	if state_id != State.PANICKING:
		return
	move_speed = _roaming_move_speed
	walk_animation_speed_scale = _roaming_animation_speed_scale
	navigation_agent.max_speed = move_speed
	set_local_obstacle_steering_enabled(_crowd_detail_enabled)


func _update_roaming(delta: float) -> void:
	if _network == null or not is_instance_valid(_route_target):
		set_navigation_avoidance_enabled(false)
		stop_moving(delta)
		return
	var route_target_position := _get_route_target_position()
	var arrival_distance := maxf(
		route_stop_distance,
		corner_anticipation_distance
	)
	if (
		global_position.distance_squared_to(route_target_position)
		<= arrival_distance * arrival_distance
	):
		_previous_waypoint = _current_waypoint
		_current_waypoint = _route_target
		_route_stuck_elapsed = 0.0
		_choose_next_route_target()
		if is_instance_valid(_route_target):
			set_navigation_target(_get_route_target_position())
	elif (
		get_horizontal_speed_squared() < 0.12 * 0.12
		and _state_elapsed > 0.5
	):
		_route_stuck_elapsed += delta
		if _route_stuck_elapsed >= route_stuck_timeout:
			_recover_from_blocked_route()
	else:
		_route_stuck_elapsed = 0.0
	advance_navigation(delta)


func _update_approaching(delta: float) -> void:
	if not is_instance_valid(_target_player):
		hsm.dispatch(EVENT_RETURN_TO_ROUTE)
		return
	if (
		global_position.distance_squared_to(_target_player.global_position)
		<= player_stop_distance * player_stop_distance
	):
		hsm.dispatch(EVENT_REACHED_PLAYER)
		return
	if _state_elapsed >= approach_timeout:
		hsm.dispatch(EVENT_RETURN_TO_ROUTE)
		return

	_repath_remaining = maxf(_repath_remaining - delta, 0.0)
	_update_player_navigation_target(false)
	if (
		_state_elapsed > 1.0
		and navigation_agent.is_navigation_finished()
		and not navigation_agent.is_target_reachable()
	):
		hsm.dispatch(EVENT_RETURN_TO_ROUTE)
		return
	advance_navigation(delta)


func _update_waiting(delta: float) -> void:
	stop_moving(delta)
	if not is_instance_valid(_target_player):
		hsm.dispatch(EVENT_RETURN_TO_ROUTE)
		return
	_face_target(_target_player.global_position, delta)
	_waiting_remaining = maxf(_waiting_remaining - delta, 0.0)
	if is_zero_approx(_waiting_remaining):
		hsm.dispatch(EVENT_RETURN_TO_ROUTE)


func _update_returning(delta: float) -> void:
	if (
		global_position.distance_squared_to(_cached_return_position)
		<= route_stop_distance * route_stop_distance
	):
		_finish_returning()
		return
	if _departure_turn_remaining > 0.0:
		_departure_turn_remaining = maxf(
			_departure_turn_remaining - delta,
			0.0
		)
		stop_moving(delta)
		_face_target(_cached_return_position, delta)
		if (
			_departure_turn_remaining <= 0.0
			or _is_facing_position(
				_cached_return_position,
				departure_facing_tolerance
			)
		):
			_finish_departure_turn()
		return
	if _state_elapsed >= return_timeout:
		global_position = _cached_return_position
		velocity = Vector3.ZERO
		navigation_agent.set_velocity_forced(Vector3.ZERO)
		_finish_returning()
		return
	advance_navigation(delta)


func _finish_departure_turn() -> void:
	_departure_turn_remaining = 0.0
	set_local_obstacle_steering_enabled(_crowd_detail_enabled)
	_refresh_navigation_avoidance()


func _is_facing_position(
	target: Vector3,
	tolerance_degrees: float
) -> bool:
	var direction := target - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return true
	var target_angle := atan2(direction.x, direction.z)
	return absf(angle_difference(visual.rotation.y, target_angle)) <= (
		deg_to_rad(tolerance_degrees)
	)


func _update_panicking(delta: float) -> void:
	if _network == null or not is_instance_valid(_route_target):
		hsm.dispatch(EVENT_PANIC_FINISHED)
		return
	var distance_from_threat_squared := global_position.distance_squared_to(
		_panic_source_position
	)
	if (
		_state_elapsed >= panic_maximum_duration
		or (
			_state_elapsed >= panic_minimum_duration
			and distance_from_threat_squared
			>= panic_safe_distance * panic_safe_distance
		)
	):
		hsm.dispatch(EVENT_PANIC_FINISHED)
		return

	var route_target_position := _get_route_target_position()
	var arrival_distance := maxf(
		route_stop_distance,
		corner_anticipation_distance
	)
	if (
		global_position.distance_squared_to(route_target_position)
		<= arrival_distance * arrival_distance
	):
		_previous_waypoint = _current_waypoint
		_current_waypoint = _route_target
		_route_stuck_elapsed = 0.0
		_choose_panic_route_target()
		if is_instance_valid(_route_target):
			set_navigation_target(_get_route_target_position())
	elif (
		get_horizontal_speed_squared() < 0.18 * 0.18
		and _state_elapsed > 0.5
	):
		_route_stuck_elapsed += delta
		if _route_stuck_elapsed >= route_stuck_timeout:
			_begin_panic_route()
	else:
		_route_stuck_elapsed = 0.0
	advance_navigation(delta)


func _update_player_navigation_target(force: bool) -> void:
	if not is_instance_valid(_target_player):
		return
	var player_position := _target_player.global_position
	if (
		force
		or _repath_remaining <= 0.0
		and _last_player_path_target.distance_squared_to(player_position)
		>= player_repath_distance * player_repath_distance
	):
		set_navigation_target(player_position)
		_last_player_path_target = player_position
		_repath_remaining = player_repath_interval


func _choose_next_route_target() -> void:
	if _network == null or not is_instance_valid(_current_waypoint):
		_route_target = null
		return
	_route_target = _network.get_next_waypoint(
		_current_waypoint,
		_previous_waypoint,
		_random
	)
	_cache_route_target_position()


func _recover_from_blocked_route() -> void:
	if _network == null or not is_instance_valid(_current_waypoint):
		return
	var blocked_target := _route_target
	var alternative := _network.get_next_waypoint(
		_current_waypoint,
		blocked_target,
		_random
	)
	if is_instance_valid(alternative) and alternative != blocked_target:
		_previous_waypoint = blocked_target
		_route_target = alternative
		_cache_route_target_position()
		set_navigation_target(_get_route_target_position())
	_route_stuck_elapsed = 0.0


func _begin_panic_route() -> void:
	if _network == null:
		_route_target = null
		return
	var nearest := _network.get_nearest_waypoint(
		global_position,
		40.0
	)
	if nearest != null:
		_current_waypoint = nearest
	_previous_waypoint = null
	_route_stuck_elapsed = 0.0
	_choose_panic_route_target()
	if is_instance_valid(_route_target):
		set_navigation_target(_get_route_target_position())


func _choose_panic_route_target() -> void:
	if _network == null or not is_instance_valid(_current_waypoint):
		_route_target = null
		return
	_route_target = _network.get_waypoint_away_from(
		_current_waypoint,
		_previous_waypoint,
		_panic_source_position,
		_random
	)
	_cache_route_target_position()


func _apply_crowd_variation() -> void:
	_route_lane_offset = _random.randf_range(
		-route_lane_half_width,
		route_lane_half_width
	)
	move_speed = maxf(
		_base_move_speed
			+ _random.randf_range(-speed_variation, speed_variation),
		0.5
	)
	walk_animation_speed_scale = _base_walk_animation_speed_scale
	navigation_agent.max_speed = move_speed
	navigation_agent.radius = _random.randf_range(0.45, 0.55)
	navigation_agent.avoidance_priority = _random.randf_range(0.45, 0.8)
	set_obstacle_probe_delay(_random.randf_range(
		0.0,
		obstacle_probe_interval
	))
	_roaming_move_speed = move_speed
	_roaming_animation_speed_scale = walk_animation_speed_scale


func _refresh_navigation_avoidance() -> void:
	var is_walking_state := (
		_state == State.ROAMING
		or _state == State.APPROACHING
		or _state == State.RETURNING
		or _state == State.PANICKING
	)
	set_navigation_avoidance_enabled(
		(_crowd_detail_enabled or _state == State.PANICKING)
		and is_walking_state
	)


func _get_route_start_position() -> Vector3:
	if not is_instance_valid(_current_waypoint):
		return global_position
	if not is_instance_valid(_route_target):
		return _current_waypoint.global_position
	return (
		_current_waypoint.global_position
		+ _get_segment_lane_offset(_current_waypoint, _route_target)
	)


func _get_route_target_position() -> Vector3:
	if not is_instance_valid(_route_target):
		return global_position
	return _cached_route_target_position


func _cache_route_target_position() -> void:
	if not is_instance_valid(_route_target):
		_cached_route_target_position = global_position
		return
	_cached_route_target_position = (
		_route_target.global_position
		+ _get_segment_lane_offset(_current_waypoint, _route_target)
	)


func _get_segment_lane_offset(
	from_waypoint: PedestrianWaypoint3D,
	to_waypoint: PedestrianWaypoint3D
) -> Vector3:
	if not (
		is_instance_valid(from_waypoint)
		and is_instance_valid(to_waypoint)
	):
		return Vector3.ZERO
	var segment_direction := (
		to_waypoint.global_position - from_waypoint.global_position
	)
	segment_direction.y = 0.0
	if segment_direction.is_zero_approx():
		return Vector3.ZERO
	var lateral_direction := Vector3(
		-segment_direction.z,
		0.0,
		segment_direction.x
	).normalized()
	return lateral_direction * _route_lane_offset


func _get_return_position() -> Vector3:
	if (
		_network != null
		and is_instance_valid(_resume_waypoint)
		and _network.has_waypoint(_resume_waypoint)
	):
		if (
			is_instance_valid(_resume_route_target)
			and _network.has_waypoint(_resume_route_target)
		):
			return (
				_resume_waypoint.global_position
				+ _get_segment_lane_offset(
					_resume_waypoint,
					_resume_route_target
				)
			)
		return (
			_resume_waypoint.global_position
			+ _get_segment_lane_offset(
				_current_waypoint,
				_resume_waypoint
			)
		)
	return _home_position


func _finish_returning() -> void:
	if (
		_network != null
		and is_instance_valid(_resume_waypoint)
		and _network.has_waypoint(_resume_waypoint)
	):
		_previous_waypoint = _current_waypoint
		_current_waypoint = _resume_waypoint
	_route_target = null
	if (
		_network != null
		and is_instance_valid(_resume_route_target)
		and _network.has_waypoint(_resume_route_target)
	):
		_route_target = _resume_route_target
		_cache_route_target_position()
	_resume_waypoint = _current_waypoint
	_resume_route_target = null
	if not is_instance_valid(_route_target):
		_choose_next_route_target()
	hsm.dispatch(EVENT_RESUMED_ROUTE)


func _initialize_solicitation_outline() -> void:
	_solicitation_outline_material = ShaderMaterial.new()
	_solicitation_outline_material.shader = CUSTOMER_OUTLINE_SHADER
	apply_customer_level_style(role_component.customer_level)
	_solicitation_outline_material.set_shader_parameter(
		&"thickness",
		solicitation_outline_thickness
	)
	_solicitation_outline_material.set_shader_parameter(
		&"outline_energy",
		solicitation_outline_energy
	)
	_solicitation_outline_material.set_shader_parameter(
		&"outline_transparency",
		solicitation_outline_transparency
	)
	_solicitation_outline_material.set_shader_parameter(
		&"silhouette_start",
		0.18
	)
	_solicitation_outline_material.set_shader_parameter(
		&"silhouette_end",
		0.42
	)
	_solicitation_outline_material.set_shader_parameter(&"merge_group", true)
	_solicitation_outline_material.set_shader_parameter(
		&"merge_depth_range",
		10.0
	)


func _apply_solicitation_outline() -> void:
	if _solicitation_outline_material == null:
		return
	_solicitation_outline_material.set_shader_parameter(
		&"outline_transparency",
		solicitation_outline_transparency
	)
	var root := get_node_or_null("Visual") as Node
	if root == null:
		root = self
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh == null or not mesh.visible:
			continue
		var id := mesh.get_instance_id()
		if _solicitation_outline_overlays.has(id):
			continue
		_solicitation_outline_overlays[id] = [
			mesh,
			mesh.material_overlay,
			mesh.extra_cull_margin,
		]
		mesh.material_overlay = _solicitation_outline_material
		mesh.extra_cull_margin = maxf(
			mesh.extra_cull_margin,
			solicitation_outline_thickness * 4.0
		)


func _clear_solicitation_outline() -> void:
	if _solicitation_outline_material != null:
		_solicitation_outline_material.set_shader_parameter(
			&"outline_transparency",
			0.0
		)
	for item in _solicitation_outline_overlays.values():
		var mesh_object: Variant = item[0]
		if is_instance_valid(mesh_object) and mesh_object is MeshInstance3D:
			var mesh := mesh_object as MeshInstance3D
			if mesh.material_overlay == _solicitation_outline_material:
				mesh.material_overlay = item[1] as Material
				mesh.extra_cull_margin = float(item[2])
	_solicitation_outline_overlays.clear()


func _face_target(target: Vector3, delta: float) -> void:
	var direction := target - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	visual.rotation.y = lerp_angle(
		visual.rotation.y,
		atan2(direction.x, direction.z),
		minf(turn_speed * delta, 1.0)
	)


func _on_defeated(
	source: Node,
	hit_position: Vector3,
	hit_direction: Vector3
) -> void:
	if _girlfriend_roster != null:
		var roster := _girlfriend_roster
		_girlfriend_roster = null
		_girlfriend_player = null
		_girlfriend_status = &""
		remove_from_group(&"girlfriend_npc")
		roster.remove_girlfriend_due_to_death(self)
	_pool_active = false
	role_component.deactivate()
	_clear_solicitation_outline()
	if hsm != null:
		hsm.set_active(false)
	super(source, hit_position, hit_direction)
