class_name CivilianPopulationManager
extends Node3D

@export var customer_scene: PackedScene
@export var police_scene: PackedScene
@export var network_path: NodePath
@export var player_path: NodePath
@export var npc_container_path: NodePath

@export_category("Population")
@export_range(1, 500, 1) var pool_capacity := 60
@export_range(0, 500, 1) var active_target := 24
@export_range(0.0, 500.0, 1.0) var minimum_spawn_distance := 18.0
@export_range(1.0, 1000.0, 1.0) var maximum_spawn_distance := 55.0
@export_range(1.0, 1000.0, 1.0) var recycle_distance := 70.0
@export_range(0.1, 10.0, 0.1) var population_update_interval := 0.65
@export_range(1, 20, 1) var maximum_activations_per_update := 1
@export_range(1, 100, 1) var recycle_checks_per_update := 12
@export_range(0.5, 10.0, 0.1) var spawn_separation := 2.5
@export_range(5.0, 200.0, 1.0) var high_detail_distance := 35.0
@export var show_managed_role_labels := false
@export_range(1, 100, 1) var civilians_per_police := 3
@export_range(0.0, 120.0, 1.0) var police_replacement_delay := 20.0
@export_range(0, 20, 1) var one_star_police_minimum := 5
@export_range(0, 20, 1) var two_star_police_minimum := 6
@export_range(0, 20, 1) var three_star_police_minimum := 8

@onready var network := get_node(network_path) as PedestrianNetwork3D
@onready var player := get_node(player_path) as CharacterBody3D
@onready var npc_container := get_node(npc_container_path) as Node3D
@onready var wanted := player.get_node(
	"Components/WantedComponent"
) as PlayerWantedComponent

var _active: Array[CustomerNPC] = []
var _inactive: Array[CustomerNPC] = []
var _active_police: Array[PoliceNPC] = []
var _inactive_police: Array[PoliceNPC] = []
var _random := RandomNumberGenerator.new()
var _update_remaining := 0.0
var _recycle_cursor := 0
var _enabled := true
var _police_replacement_remaining := 0.0


func _ready() -> void:
	_random.randomize()
	_update_remaining = population_update_interval


func _process(delta: float) -> void:
	_police_replacement_remaining = maxf(
		_police_replacement_remaining - delta,
		0.0
	)
	if not _enabled:
		return
	_update_remaining -= delta
	if _update_remaining > 0.0:
		return
	_update_remaining = population_update_interval
	update_population()


func update_population() -> void:
	if (
		customer_scene == null
		or network == null
		or player == null
		or npc_container == null
	):
		return
	_recycle_distant_customers()
	_recycle_distant_police()

	var activation_count := 0
	while (
		_active.size() < mini(active_target, pool_capacity)
		and activation_count < maximum_activations_per_update
	):
		if not _activate_one():
			break
		activation_count += 1
	var police_target: int = _get_police_target()
	if (
		_active_police.size() < police_target
		and is_zero_approx(_police_replacement_remaining)
	):
		_activate_one_police()


func populate_immediately(requested_count := -1) -> int:
	var target_count := (
		mini(active_target, pool_capacity)
		if requested_count < 0
		else mini(requested_count, pool_capacity)
	)
	var activated := 0
	while _active.size() < target_count:
		if not _activate_one():
			break
		activated += 1
	while (
		_active_police.size() < _get_police_target()
		and is_zero_approx(_police_replacement_remaining)
	):
		if not _activate_one_police():
			break
	return activated


func set_population_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_process(enabled)


func get_active_count() -> int:
	return _active.size()


func get_inactive_count() -> int:
	return _inactive.size()


func get_live_pool_count() -> int:
	return _active.size() + _inactive.size()


func get_active_customers() -> Array[CustomerNPC]:
	return _active.duplicate()


func get_active_police() -> Array[PoliceNPC]:
	return _active_police.duplicate()


func get_active_police_count() -> int:
	return _active_police.size()


func _activate_one() -> bool:
	var chosen: PedestrianWaypoint3D = _choose_spawn_waypoint()
	if chosen == null:
		return false

	var customer: CustomerNPC = _acquire_customer()
	if customer == null:
		return false
	customer.prepare_for_pool_spawn(
		network,
		chosen,
		_random.randi()
	)
	var high_detail_distance_squared: float = (
		high_detail_distance * high_detail_distance
	)
	customer.set_crowd_detail_enabled(
		chosen.global_position.distance_squared_to(player.global_position)
		<= high_detail_distance_squared
	)
	customer.set_role_label_visible(show_managed_role_labels)
	_active.append(customer)
	return true


func _activate_one_police() -> bool:
	if police_scene == null:
		return false
	var chosen: PedestrianWaypoint3D = _choose_spawn_waypoint()
	if chosen == null:
		return false
	var police: PoliceNPC = _acquire_police()
	if police == null:
		return false
	police.prepare_for_pool_spawn(
		network,
		chosen,
		_random.randi(),
		player
	)
	var high_detail_distance_squared: float = (
		high_detail_distance * high_detail_distance
	)
	police.set_crowd_detail_enabled(
		chosen.global_position.distance_squared_to(player.global_position)
		<= high_detail_distance_squared
	)
	police.set_role_label_visible(show_managed_role_labels)
	_active_police.append(police)
	return true


func _choose_spawn_waypoint() -> PedestrianWaypoint3D:
	var candidates := network.get_spawn_candidates(
		player.global_position,
		minimum_spawn_distance,
		maximum_spawn_distance
	)
	if candidates.is_empty():
		return null
	_shuffle_waypoints(candidates)
	var camera := get_viewport().get_camera_3d()
	var chosen: PedestrianWaypoint3D
	var visible_fallback: PedestrianWaypoint3D
	for waypoint in candidates:
		if _is_spawn_occupied(waypoint.global_position):
			continue
		if visible_fallback == null:
			visible_fallback = waypoint
		if camera == null or not camera.is_position_in_frustum(
			waypoint.global_position + Vector3.UP
		):
			chosen = waypoint
			break
	return chosen if chosen != null else visible_fallback


func _acquire_customer() -> CustomerNPC:
	if not _inactive.is_empty():
		return _inactive.pop_back() as CustomerNPC
	if get_live_pool_count() >= pool_capacity:
		return null

	var customer := customer_scene.instantiate() as CustomerNPC
	if customer == null:
		return null
	customer.process_mode = Node.PROCESS_MODE_DISABLED
	customer.visible = false
	npc_container.add_child(customer)
	customer.tree_exiting.connect(
		_on_customer_tree_exiting.bind(customer),
		CONNECT_ONE_SHOT
	)
	customer.damageable.depleted.connect(
		_on_customer_depleted.bind(customer),
		CONNECT_ONE_SHOT
	)
	return customer


func _acquire_police() -> PoliceNPC:
	if not _inactive_police.is_empty():
		return _inactive_police.pop_back() as PoliceNPC
	var police := police_scene.instantiate() as PoliceNPC
	if police == null:
		return null
	police.process_mode = Node.PROCESS_MODE_DISABLED
	police.visible = false
	npc_container.add_child(police)
	police.tree_exiting.connect(
		_on_police_tree_exiting.bind(police),
		CONNECT_ONE_SHOT
	)
	police.damageable.depleted.connect(
		_on_police_depleted.bind(police),
		CONNECT_ONE_SHOT
	)
	return police


func _recycle_distant_customers() -> void:
	if _active.is_empty():
		_recycle_cursor = 0
		return
	var checks := mini(recycle_checks_per_update, _active.size())
	var player_position: Vector3 = player.global_position
	var high_detail_distance_squared: float = (
		high_detail_distance * high_detail_distance
	)
	var recycle_distance_squared: float = recycle_distance * recycle_distance
	for _index in range(checks):
		if _active.is_empty():
			break
		_recycle_cursor %= _active.size()
		var customer := _active[_recycle_cursor]
		if not is_instance_valid(customer):
			_recycle_cursor += 1
			continue
		var distance_to_player_squared: float = (
			customer.global_position.distance_squared_to(
				player_position
			)
		)
		customer.set_crowd_detail_enabled(
			distance_to_player_squared <= high_detail_distance_squared
		)
		if (
			customer.can_be_recycled()
			and distance_to_player_squared > recycle_distance_squared
		):
			_recycle_customer(customer)
			continue
		_recycle_cursor += 1


func _recycle_distant_police() -> void:
	var player_position: Vector3 = player.global_position
	var high_detail_distance_squared: float = (
		high_detail_distance * high_detail_distance
	)
	var recycle_distance_squared: float = recycle_distance * recycle_distance
	for police: PoliceNPC in _active_police.duplicate():
		if not is_instance_valid(police):
			continue
		var distance_squared: float = (
			police.global_position.distance_squared_to(
				player_position
			)
		)
		police.set_crowd_detail_enabled(
			distance_squared <= high_detail_distance_squared
		)
		if police.can_be_recycled() and distance_squared > recycle_distance_squared:
			_recycle_police(police)


func _recycle_customer(customer: CustomerNPC) -> void:
	_active.erase(customer)
	customer.prepare_for_pool_recycle()
	_inactive.append(customer)
	if not _active.is_empty():
		_recycle_cursor %= _active.size()
	else:
		_recycle_cursor = 0


func _recycle_police(police: PoliceNPC) -> void:
	_active_police.erase(police)
	police.prepare_for_pool_recycle()
	_inactive_police.append(police)


func _is_spawn_occupied(position: Vector3) -> bool:
	var separation_squared: float = spawn_separation * spawn_separation
	for customer in _active:
		if (
			is_instance_valid(customer)
			and customer.global_position.distance_squared_to(position)
			< separation_squared
		):
			return true
	for police in _active_police:
		if (
			is_instance_valid(police)
			and police.global_position.distance_squared_to(position)
			< separation_squared
		):
			return true
	return false


func _get_police_target() -> int:
	if police_scene == null or civilians_per_police <= 0:
		return 0
	var ambient_target := int(
		floori(float(_active.size()) / float(civilians_per_police))
	)
	var wanted_target := 0
	match wanted.wanted_level:
		1:
			wanted_target = one_star_police_minimum
		2:
			wanted_target = two_star_police_minimum
		3:
			wanted_target = three_star_police_minimum
	return maxi(ambient_target, wanted_target)


func _shuffle_waypoints(
	waypoints: Array[PedestrianWaypoint3D]
) -> void:
	for index in range(waypoints.size() - 1, 0, -1):
		var swap_index := _random.randi_range(0, index)
		var temporary := waypoints[index]
		waypoints[index] = waypoints[swap_index]
		waypoints[swap_index] = temporary


func _on_customer_depleted(
	_source: Node,
	_hit_position: Vector3,
	_hit_direction: Vector3,
	customer: CustomerNPC
) -> void:
	_active.erase(customer)
	_inactive.erase(customer)
	if not _active.is_empty():
		_recycle_cursor %= _active.size()
	else:
		_recycle_cursor = 0


func _on_customer_tree_exiting(customer: CustomerNPC) -> void:
	_active.erase(customer)
	_inactive.erase(customer)


func _on_police_depleted(
	_source: Node,
	_hit_position: Vector3,
	_hit_direction: Vector3,
	police: PoliceNPC
) -> void:
	_active_police.erase(police)
	_inactive_police.erase(police)
	_police_replacement_remaining = police_replacement_delay


func _on_police_tree_exiting(police: PoliceNPC) -> void:
	_active_police.erase(police)
	_inactive_police.erase(police)
