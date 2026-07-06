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


func _ready() -> void:
	super()
	role_component.initialize(self)
	patrol_component.initialize(self)
	combat_component.initialize(self)
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
	patrol_component.assign_route(network, start_waypoint, random_seed)
	global_position = patrol_component.get_spawn_position()
	perception_component.initialize(self, player)
	ai_component.initialize(self, player)
	combat_component.reset_for_reuse()
	ai_component.reset_for_reuse()
	role_component.activate()
	bt_player.restart()
	bt_player.set_active(true)


func prepare_for_pool_recycle() -> void:
	if not _pool_active or is_defeated():
		return
	_pool_active = false
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
	)


func is_pool_active() -> bool:
	return _pool_active


func set_crowd_detail_enabled(enabled: bool) -> void:
	set_navigation_avoidance_enabled(enabled)
	set_local_obstacle_steering_enabled(enabled)


func set_role_label_visible(enabled: bool) -> void:
	role_label.visible = enabled


func get_wanted_level() -> int:
	return _wanted.wanted_level if _wanted != null else 0


func can_see_wanted_player() -> bool:
	return (
		_pool_active
		and _wanted != null
		and _wanted.wanted_level > 0
		and perception_component.can_see_player()
	)


func tick_ai_mode(mode: int, delta: float) -> void:
	if _pool_active:
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
		ai_component.note_incident(source_position)


func _on_defeated(
	source: Node,
	hit_position: Vector3,
	hit_direction: Vector3
) -> void:
	_pool_active = false
	role_component.deactivate()
	combat_component.set_equipped(false)
	if bt_player != null:
		bt_player.set_active(false)
	super(source, hit_position, hit_direction)
