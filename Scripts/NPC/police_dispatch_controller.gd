class_name PoliceDispatchController
extends Node3D

signal cruiser_dispatched(cruiser, incident_id: int)
signal cruiser_arrived(cruiser, incident_id: int)
signal response_completed(incident_id: int)


class ResponseUnit extends RefCounted:
	enum State { QUEUED, EN_ROUTE, PURSUING, PULL_OVER, DEPLOYING, ON_SCENE, RETURNING, EXITING }

	var cruiser: BaseVehicle
	var ai: TrafficVehicleAIComponent
	var zone: Dictionary
	var start: TrafficWaypoint3D
	var seat_count := 0
	var officers: Array[PoliceNPC] = []
	var state := State.QUEUED
	var hold := 0.0
	var unload_remaining := 0.0
	var deploy_elapsed := 0.0
	var stationary_elapsed := 0.0
	var route_refresh_remaining := 0.0
	var response_elapsed := 0.0
	var stalled_elapsed := 0.0
	var last_progress_position := Vector3.ZERO
	var recovery_count := 0
	var destination_position := Vector3.INF
	var approach_direction := Vector3.ZERO
	var target_snapshot := Vector3.ZERO
	var stand_off_distance := 10.0
	var last_failure_reason: StringName = &""
	var replacement_requested := false
	var empty_scene_elapsed := 0.0
	var return_elapsed := 0.0
	var return_retargeted := false
	var return_positions: Array[Vector3] = []
	var exit_elapsed := 0.0
	var exit_stalled_elapsed := 0.0
	var exit_progress_position := Vector3.ZERO
	var exit_coasting := false
	var finished := false
	var last_traced_state := -1

	func state_name() -> StringName:
		return [&"queued", &"en_route", &"pursuing", &"pull_over", &"deploying", &"on_scene", &"returning", &"exiting"][state]


@export var cruiser_scene: PackedScene
@export var player_path: NodePath
@export var traffic_container_path: NodePath
@export var traffic_coordinator_path: NodePath
@export var response_profile: PoliceResponseProfile
@export var zones: Array[PoliceDispatchZone] = []

# Kept for scene/save compatibility while older scenes migrate to zones.
@export var traffic_network_path: NodePath
@export var police_population_manager_path: NodePath
@export var territory_id: StringName = &"hood_east"

@export_range(10.0, 250.0, 1.0) var minimum_dispatch_distance := 55.0
@export_range(20.0, 400.0, 1.0) var maximum_dispatch_distance := 180.0
@export_range(2.0, 20.0, 0.5) var spawn_clearance := 8.0
@export_range(5.0, 100.0, 1.0) var reroute_distance := 20.0
@export_range(0.1, 2.0, 0.05) var unload_interval := 0.35
@export_range(0.25, 5.0, 0.25) var pursuit_route_refresh := 1.0
@export_range(1.0, 15.0, 0.5) var deployment_failure_timeout := 6.0
@export_range(1.0, 30.0, 0.5) var empty_cruiser_cleanup_delay := 8.0
@export_range(1, 12, 1) var maximum_route_starts_per_dispatch := 5
@export_range(4.0, 20.0, 0.5) var response_destination_separation := 9.0
@export_range(6.0, 16.0, 0.5) var on_foot_stand_off_minimum := 8.0
@export_range(8.0, 20.0, 0.5) var on_foot_stand_off_maximum := 12.0
@export_range(0.0, 3.0, 0.05) var pursuit_prediction_seconds := 0.75
@export_range(0.5, 12.0, 0.5) var minimum_dynamic_retarget_distance := 3.0
@export_range(1.5, 5.0, 0.1) var officer_reentry_distance := 3.0
@export_range(2.0, 30.0, 0.5) var officer_return_timeout := 12.0
@export_range(4.0, 20.0, 0.5) var officer_return_nearby_fallback := 8.0
@export_range(5.0, 45.0, 0.5) var officer_return_hard_timeout := 24.0
@export_range(1.0, 15.0, 0.5) var exit_stall_reroute_seconds := 5.0
@export_range(1.0, 15.0, 0.5) var exit_coast_timeout := 7.0
@export_range(30.0, 120.0, 5.0) var police_traffic_query_radius := 70.0

@onready var player := get_node(player_path) as CharacterBody3D
@onready var wanted := player.get_node("Components/WantedComponent") as PlayerWantedComponent
@onready var vehicle_component := player.get_node("Components/VehicleComponent") as PlayerVehicleComponent
@onready var traffic_container := get_node(traffic_container_path) as Node3D
@onready var traffic_coordinator: Node = get_node_or_null(
	traffic_coordinator_path
)

var _random := RandomNumberGenerator.new()
var _incident
var _responses: Array[ResponseUnit] = []
var _zone_runtime := {}
var _inactive_cruisers := {}
var _reserved_starts := {}
var _dispatch_remaining := 0.0
var _launch_remaining := 0.0
var _audit_remaining := 0.0
var _resolved := false
var _last_known_position := Vector3.ZERO
var _police_sedan_definition: VehicleDefinition
var _police_suv_definition: VehicleDefinition
var _last_dispatch_route_search_count := 0
var _fallback_officers: Array[PoliceNPC] = []
var _fallback_population_by_officer := {}
var _strength_deficit_elapsed := 0.0
var _casualty_replacement_deficit := 0


func _ready() -> void:
	add_to_group(&"police_dispatch")
	_random.randomize()
	if response_profile == null:
		response_profile = PoliceResponseProfile.new()
	_police_sedan_definition = _create_police_definition(false)
	_police_suv_definition = _create_police_definition(true)
	_resolve_zones()
	wanted.incident_reported.connect(_on_incident_reported)
	wanted.incident_updated.connect(_on_incident_updated)
	wanted.incident_resolved.connect(_on_incident_resolved)
	wanted.wanted_level_changed.connect(_on_wanted_level_changed)
	call_deferred("_prewarm_cruiser_pool")


func _process(delta: float) -> void:
	_dispatch_remaining = maxf(_dispatch_remaining - delta, 0.0)
	_launch_remaining = maxf(_launch_remaining - delta, 0.0)
	_audit_remaining = maxf(_audit_remaining - delta, 0.0)
	if _incident == null or _resolved or wanted.wanted_level <= 0:
		_strength_deficit_elapsed = 0.0
		return
	var effective_target := response_profile.get_officer_target(wanted.wanted_level)
	if get_effective_officer_count() < effective_target:
		_strength_deficit_elapsed += delta
	else:
		_strength_deficit_elapsed = 0.0
	if is_zero_approx(_audit_remaining):
		_audit_response()
		_audit_remaining = response_profile.response_audit_interval
	if is_zero_approx(_dispatch_remaining) and is_zero_approx(_launch_remaining):
		_ensure_response_strength()


func _physics_process(delta: float) -> void:
	for response in _responses.duplicate():
		_tick_response(response, delta)
		_trace_response_state(response)
		if response.finished:
			_release_reservations(response)
			_responses.erase(response)
	if _resolved and _responses.is_empty() and _incident != null:
		var completed_id: int = _incident.incident_id
		_incident = null
		_resolved = false
		response_completed.emit(completed_id)


func get_active_cruisers() -> Array[BaseVehicle]:
	var results: Array[BaseVehicle] = []
	for response in _responses:
		if is_instance_valid(response.cruiser):
			results.append(response.cruiser)
	return results


func get_scheduled_officer_count() -> int:
	var count := 0
	for response in _responses:
		count += _get_response_scheduled_count(response)
	for officer in _fallback_officers:
		if is_instance_valid(officer) and not officer.is_defeated():
			count += 1
	return count


func get_desired_officer_count() -> int:
	return response_profile.get_officer_target(wanted.wanted_level)


func get_effective_officer_count() -> int:
	var count := 0
	for response in _responses:
		for officer in response.officers:
			if _is_officer_effective(officer, response.state):
				count += 1
	for officer in _fallback_officers:
		if _is_officer_effective(officer):
			count += 1
	return count


func get_unavailable_officer_count() -> int:
	return maxi(get_scheduled_officer_count() - get_effective_officer_count(), 0)


func get_response_debug_snapshot() -> Dictionary:
	var response_details: Array[Dictionary] = []
	for response in _responses:
		response_details.append({
			"state": response.state_name(),
			"destination": response.destination_position,
			"target_snapshot": response.target_snapshot,
			"player_distance": (
				response.cruiser.global_position.distance_to(
					vehicle_component.get_effective_position()
				)
				if is_instance_valid(response.cruiser) else INF
			),
			"response_elapsed": response.response_elapsed,
			"progress_age": response.stalled_elapsed,
			"recovery_count": response.recovery_count,
			"failure_reason": response.last_failure_reason,
		})
	return {
		"incident_id": _incident.incident_id if _incident != null else 0,
		"desired": get_desired_officer_count(),
		"scheduled": get_scheduled_officer_count(),
		"effective": get_effective_officer_count(),
		"unavailable": get_unavailable_officer_count(),
		"cruisers": _responses.size(),
		"fallback_officers": _fallback_officers.size(),
		"deficit_elapsed": _strength_deficit_elapsed,
		"states": get_response_states(),
		"response_details": response_details,
	}


func get_response_states() -> Array[StringName]:
	var states: Array[StringName] = []
	for response in _responses:
		states.append(response.state_name())
	return states


func get_unloaded_officer_count() -> int:
	var count := 0
	for response in _responses:
		for officer in response.officers:
			if is_instance_valid(officer) and not officer.is_defeated():
				count += 1
	return count


func get_reserved_spawn_count() -> int:
	return _reserved_starts.size()


func get_last_dispatch_route_search_count() -> int:
	return _last_dispatch_route_search_count


func reset_for_load() -> void:
	_recycle_fallback_officers()
	for response in _responses:
		var population := response.zone.get("population") as CivilianPopulationManager
		for police in response.officers:
			if is_instance_valid(police) and not police.is_defeated() and population != null:
				population.recycle_response_officer(police)
		_recycle_cruiser(response.cruiser)
	_responses.clear()
	_reserved_starts.clear()
	_incident = null
	_resolved = false
	_dispatch_remaining = 0.0
	_launch_remaining = 0.0
	_last_known_position = Vector3.ZERO
	_strength_deficit_elapsed = 0.0
	_casualty_replacement_deficit = 0


func _resolve_zones() -> void:
	_zone_runtime.clear()
	for config in zones:
		if config == null or not config.is_configured():
			continue
		var network := get_node_or_null(config.traffic_network_path) as TrafficNetwork3D
		var population := get_node_or_null(config.population_manager_path) as CivilianPopulationManager
		if network != null and population != null:
			_zone_runtime[config.territory_id] = {"config": config, "network": network, "population": population}
	if _zone_runtime.is_empty() and not traffic_network_path.is_empty() and not police_population_manager_path.is_empty():
		var network := get_node_or_null(traffic_network_path) as TrafficNetwork3D
		var population := get_node_or_null(police_population_manager_path) as CivilianPopulationManager
		if network != null and population != null:
			_zone_runtime[territory_id] = {"network": network, "population": population}


func _on_incident_reported(incident) -> void:
	if incident == null or not _zone_runtime.has(incident.territory_id):
		return
	_incident = incident
	_last_known_position = incident.last_known_player_position
	_resolved = false
	_reactivate_nearby_returning_responses(incident)
	_dispatch_remaining = response_profile.get_dispatch_delay(wanted.wanted_level)
	_audit_remaining = 0.0
	_strength_deficit_elapsed = 0.0


func _reactivate_nearby_returning_responses(incident) -> void:
	var response_level := clampi(
		maxi(wanted.wanted_level, int(incident.severity)),
		1,
		PlayerWantedComponent.MAX_WANTED_LEVEL
	)
	var awareness_radius := response_profile.get_awareness_radius(response_level)
	var awareness_radius_squared := awareness_radius * awareness_radius
	for response in _responses:
		if response.state != ResponseUnit.State.RETURNING:
			continue
		var has_nearby_officer := false
		for officer in response.officers:
			if (
				is_instance_valid(officer)
				and not officer.is_defeated()
				and officer.is_pool_active()
				and officer.global_position.distance_squared_to(
					incident.last_known_player_position
				) <= awareness_radius_squared
			):
				has_nearby_officer = true
				break
		if not has_nearby_officer:
			continue
		for officer in response.officers:
			if (
				is_instance_valid(officer)
				and not officer.is_defeated()
				and officer.is_pool_active()
			):
				officer.resume_police_response(
					incident.incident_id,
					incident.last_known_player_position
				)
		response.state = ResponseUnit.State.ON_SCENE
		response.empty_scene_elapsed = 0.0
		response.hold = 0.0
		response.return_elapsed = 0.0
		response.return_retargeted = false
		response.return_positions.clear()
		response.finished = false


func _on_incident_updated(incident) -> void:
	if incident == null or _incident == null or incident.incident_id != _incident.incident_id:
		return
	var previous_position := _last_known_position
	var previous_territory: StringName = _incident.territory_id
	_incident = incident
	_last_known_position = incident.last_known_player_position
	if previous_territory != incident.territory_id:
		for response in _responses:
			if response.state in [ResponseUnit.State.EN_ROUTE, ResponseUnit.State.PURSUING, ResponseUnit.State.PULL_OVER]:
				_begin_response_return(response)
		_dispatch_remaining = response_profile.get_dispatch_delay(wanted.wanted_level)
		_launch_remaining = 0.0
	if previous_position.distance_to(_last_known_position) >= reroute_distance:
		for response in _responses:
			if response.state in [ResponseUnit.State.EN_ROUTE, ResponseUnit.State.PURSUING]:
				response.route_refresh_remaining = 0.0


func _on_incident_resolved(incident_id: int) -> void:
	if _incident == null or incident_id != _incident.incident_id:
		return
	_resolved = true
	for response in _responses:
		_begin_response_return(response)
	_recycle_fallback_officers()


func _on_wanted_level_changed(previous: int, current: int) -> void:
	if current == 0:
		_resolved = _incident != null
		for response in _responses:
			_begin_response_return(response)
		_recycle_fallback_officers()
		return
	if _incident == null:
		return
	if current > previous:
		_dispatch_remaining = minf(_dispatch_remaining, response_profile.get_dispatch_delay(current))
	elif current > 0:
		_trim_excess_response()


func _get_active_zone() -> Dictionary:
	if _incident != null and _zone_runtime.has(_incident.territory_id):
		return _zone_runtime[_incident.territory_id] as Dictionary
	var boundary := TerritoryBoundary.find_at_position(get_tree(), _last_known_position)
	if boundary != null and _zone_runtime.has(boundary.territory_id):
		return _zone_runtime[boundary.territory_id] as Dictionary
	return {}


func _audit_response() -> void:
	var missing_crew_members := 0
	for response in _responses:
		for index in range(response.officers.size() - 1, -1, -1):
			var officer := response.officers[index]
			if not is_instance_valid(officer) or officer.is_defeated():
				response.officers.remove_at(index)
		if response.state == ResponseUnit.State.ON_SCENE:
			missing_crew_members += maxi(
				response.seat_count - response.officers.size(),
				0
			)
	for index in range(_fallback_officers.size() - 1, -1, -1):
		var fallback := _fallback_officers[index]
		if not is_instance_valid(fallback) or fallback.is_defeated():
			_fallback_population_by_officer.erase(
				fallback.get_instance_id() if is_instance_valid(fallback) else 0
			)
			_fallback_officers.remove_at(index)
	_casualty_replacement_deficit = maxi(
		missing_crew_members - _fallback_officers.size(),
		0
	)
	_trim_excess_response()
	if (
		_casualty_replacement_deficit > 0
		and get_effective_officer_count() < get_desired_officer_count()
		and _spawn_fallback_officer()
	):
		_casualty_replacement_deficit -= 1
	if get_effective_officer_count() < get_desired_officer_count():
		_dispatch_remaining = 0.0


func _trim_excess_response() -> void:
	var target := response_profile.get_cruiser_target(wanted.wanted_level)
	for index in range(_responses.size() - 1, -1, -1):
		if _get_engaged_cruiser_count() <= target:
			break
		var response := _responses[index]
		if response.state in [ResponseUnit.State.EN_ROUTE, ResponseUnit.State.PURSUING, ResponseUnit.State.PULL_OVER]:
			_begin_response_return(response)


func _ensure_response_strength() -> void:
	if _incident == null or _resolved:
		return
	var officer_target := response_profile.get_officer_target(wanted.wanted_level)
	if get_effective_officer_count() >= officer_target:
		return
	# Mounted officers are already committed to this incident. Do not create
	# disconnected foot responders merely because their cruiser is still driving.
	if get_scheduled_officer_count() >= officer_target:
		return
	var cruiser_limit := response_profile.get_cruiser_target(wanted.wanted_level)
	var engaged_count := _get_engaged_cruiser_count()
	if engaged_count >= cruiser_limit:
		if (
			_strength_deficit_elapsed
			>= response_profile.deployment_deadline_seconds
		):
			_spawn_fallback_officer()
		return
	var remaining := maxi(officer_target - get_scheduled_officer_count(), 1)
	if _dispatch_cruiser(mini(remaining, 2)):
		_launch_remaining = response_profile.cruiser_launch_spacing
	else:
		_dispatch_remaining = 1.0


func _dispatch_cruiser(seat_count: int) -> bool:
	var zone := _get_active_zone()
	if zone.is_empty():
		return false
	var stand_off := _random.randf_range(
		on_foot_stand_off_minimum,
		on_foot_stand_off_maximum
	)
	var response_target := _get_dynamic_response_target()
	var choice := _choose_dispatch_route(zone, response_target, stand_off)
	if choice.is_empty():
		return false
	var definition := _choose_police_definition()
	var cruiser := _acquire_cruiser(definition)
	if cruiser == null:
		return false
	var ai := _ensure_ai(cruiser)
	var start := choice.get("start") as TrafficWaypoint3D
	var network := zone.get("network") as TrafficNetwork3D
	var stop_at_destination := (
		not vehicle_component.is_driving()
		or vehicle_component.get_effective_velocity().length()
		<= response_profile.stationary_speed
	)
	var selected_road_target := choice.get("road_target", {}) as Dictionary
	if not ai.assign_route_to_road_target(
		network,
		start,
		selected_road_target,
		_random.randi(),
		stop_at_destination
	):
		_recycle_cruiser(cruiser)
		return false
	ai.set_emergency_mode(true)
	var grounded_spawn := _get_grounded_cruiser_spawn(
		ai.get_spawn_transform(),
		cruiser
	)
	if grounded_spawn.is_empty():
		_recycle_cruiser(cruiser)
		return false
	cruiser.global_transform = grounded_spawn.get("transform") as Transform3D
	cruiser.linear_velocity = Vector3.ZERO
	cruiser.angular_velocity = Vector3.ZERO
	cruiser.sleeping = false
	cruiser.collision_layer = 1
	cruiser.collision_mask = 3
	cruiser.process_mode = Node.PROCESS_MODE_INHERIT
	cruiser.visible = true
	cruiser.set_managed_traffic_enabled(true)
	if traffic_coordinator != null:
		traffic_coordinator.register_vehicle(cruiser)
	cruiser.call("set_emergency_active", true, true)
	var response := ResponseUnit.new()
	response.cruiser = cruiser
	response.ai = ai
	response.zone = zone
	response.start = start
	response.seat_count = seat_count
	response.state = (
		ResponseUnit.State.PURSUING
		if vehicle_component.is_driving()
		else ResponseUnit.State.EN_ROUTE
	)
	response.stand_off_distance = stand_off
	response.destination_position = ai.get_destination_position()
	response.approach_direction = ai.get_destination_approach_direction()
	response.target_snapshot = response_target
	response.last_progress_position = cruiser.global_position
	_responses.append(response)
	_reserved_starts[start.get_instance_id()] = response
	var event_bus := WorldEventBus.find(get_tree())
	if event_bus != null:
		event_bus.publish_spatial_event(
			WorldEvent.Type.SIREN,
			cruiser,
			cruiser.global_position,
			45.0,
			1,
			&"police",
			{"incident_id": _incident.incident_id}
		)
	cruiser_dispatched.emit(cruiser, _incident.incident_id)
	return true


func _trace_response_state(response: ResponseUnit) -> void:
	if response == null or response.state == response.last_traced_state:
		return
	var bus := WorldEventBus.find(get_tree())
	if bus != null:
		var previous: Variant = &"untracked"
		if response.last_traced_state >= 0:
			previous = [&"queued", &"en_route", &"pursuing", &"pull_over", &"deploying", &"on_scene", &"returning", &"exiting"][response.last_traced_state]
		bus.record_state_transition(
			&"police_response",
			response.cruiser,
			previous,
			response.state_name(),
			&"response_lifecycle",
			{
				"incident_id": _incident.incident_id if _incident != null else 0,
				"response_unit_id": response.cruiser.get_instance_id() if is_instance_valid(response.cruiser) else 0,
				"territory_id": String(_incident.territory_id) if _incident != null else "",
			}
		)
	response.last_traced_state = response.state


func _choose_dispatch_route(
	zone: Dictionary,
	target_position: Vector3,
	stand_off_distance: float
) -> Dictionary:
	_last_dispatch_route_search_count = 0
	var network := zone.get("network") as TrafficNetwork3D
	if network == null:
		return {}
	var camera := get_viewport().get_camera_3d()
	var starts: Array[TrafficWaypoint3D] = []
	var effective_position := vehicle_component.get_effective_position()
	var dispatch_candidates: Array[TrafficWaypoint3D] = (
		network.get_dispatch_candidates()
	)
	# The original external dispatch markers can sit beyond the map's collision
	# surface. Grounded normal-road spawns are valid fallback ingress points.
	for road_start in network.get_spawn_candidates(
		effective_position,
		minimum_dispatch_distance,
		maximum_dispatch_distance
	):
		if road_start not in dispatch_candidates:
			dispatch_candidates.append(road_start)
	var best := {}
	var best_score := INF
	for start in dispatch_candidates:
		if _reserved_starts.has(start.get_instance_id()):
			continue
		var player_distance := start.global_position.distance_to(effective_position)
		if player_distance < minimum_dispatch_distance or player_distance > maximum_dispatch_distance:
			continue
		if camera != null and camera.is_position_in_frustum(start.global_position + Vector3.UP):
			continue
		starts.append(start)
	starts.sort_custom(func(a: TrafficWaypoint3D, b: TrafficWaypoint3D) -> bool:
		var preferred_distance := (minimum_dispatch_distance + maximum_dispatch_distance) * 0.5
		return absf(a.global_position.distance_to(effective_position) - preferred_distance) < absf(b.global_position.distance_to(effective_position) - preferred_distance)
	)
	var clear_starts: Array[TrafficWaypoint3D] = []
	for start in starts:
		if (
			_has_road_surface(start.global_position)
			and _is_spawn_clear(start.global_position)
		):
			clear_starts.append(start)
			if clear_starts.size() >= maximum_route_starts_per_dispatch:
				break
	var desired := (response_profile.get_arrival_minimum(wanted.wanted_level) + response_profile.get_arrival_maximum(wanted.wanted_level)) * 0.5
	var exclusions := _get_response_destination_exclusions()
	for start in clear_starts:
		_last_dispatch_route_search_count += 1
		var road_target := network.find_reachable_road_target(
			start,
			target_position,
			start.global_position,
			stand_off_distance if not vehicle_component.is_driving() else 0.0,
			exclusions,
			response_destination_separation
		)
		if road_target.is_empty():
			continue
		var route_distance := float(road_target.get("route_distance", INF))
		var eta := route_distance / 16.0
		var score := (
			absf(eta - desired) * 8.0
			+ float(road_target.get("target_distance", INF)) * 2.0
			+ route_distance * 0.05
		)
		if score < best_score:
			best_score = score
			best = {"start": start, "road_target": road_target}
	return best


func _tick_response(response: ResponseUnit, delta: float) -> void:
	if not is_instance_valid(response.cruiser):
		response.finished = true
		return
	if response.start != null and response.cruiser.global_position.distance_to(response.start.global_position) > spawn_clearance * 1.5:
		_reserved_starts.erase(response.start.get_instance_id())
		response.start = null
	match response.state:
		ResponseUnit.State.EN_ROUTE, ResponseUnit.State.PURSUING:
			_tick_mobile_response(response, delta)
		ResponseUnit.State.PULL_OVER:
			_tick_pull_over(response, delta)
		ResponseUnit.State.DEPLOYING:
			_tick_unloading(response, delta)
		ResponseUnit.State.ON_SCENE:
			_tick_on_scene(response, delta)
		ResponseUnit.State.RETURNING:
			_tick_officer_return(response, delta)
		ResponseUnit.State.EXITING:
			_tick_cruiser_exit(response, delta)


func _tick_mobile_response(response: ResponseUnit, delta: float) -> void:
	response.response_elapsed += delta
	var moved := response.cruiser.global_position.distance_to(
		response.last_progress_position
	)
	if moved >= 1.0:
		response.last_progress_position = response.cruiser.global_position
		response.stalled_elapsed = 0.0
	elif response.cruiser.linear_velocity.length() < 0.75:
		response.stalled_elapsed += delta
	if response.stalled_elapsed >= response_profile.stalled_reroute_seconds:
		_recover_stalled_response(response)
		response.stalled_elapsed = 0.0
		if response.state == ResponseUnit.State.EXITING:
			return
	var target := _get_effective_target_node()
	var sees_target := target != null and bool(response.cruiser.call("can_see_target", target))
	if sees_target:
		wanted.report_police_visual_contact(vehicle_component.get_effective_position())
	var response_target := _get_dynamic_response_target(sees_target)
	response.route_refresh_remaining = maxf(response.route_refresh_remaining - delta, 0.0)
	var target_speed := vehicle_component.get_effective_velocity().length()
	var player_is_moving_vehicle := (
		vehicle_component.is_driving()
		and target_speed > response_profile.stationary_speed
	)
	if player_is_moving_vehicle:
		response.state = ResponseUnit.State.PURSUING
		response.stationary_elapsed = 0.0
		if (
			is_zero_approx(response.route_refresh_remaining)
			or response.ai.has_reached_destination()
		):
			_retarget_dynamic_response(response, response_target, false, &"pursuit_refresh")
			response.route_refresh_remaining = pursuit_route_refresh
	else:
		response.stationary_elapsed = (
			response.stationary_elapsed + delta
			if vehicle_component.is_driving()
			else 0.0
		)
		if is_zero_approx(response.route_refresh_remaining):
			_retarget_dynamic_response(response, response_target, true, &"approach_refresh")
			response.route_refresh_remaining = pursuit_route_refresh
		var close_to_player := (
			response.cruiser.global_position.distance_to(
				vehicle_component.get_effective_position()
			) <= response_profile.deployment_distance
		)
		var target_ready := (
			not vehicle_component.is_driving()
			or response.stationary_elapsed
			>= response_profile.stationary_deploy_seconds
		)
		if sees_target and close_to_player and target_ready:
			response.ai.clear()
			response.state = ResponseUnit.State.PULL_OVER
			return
	response.ai.tick_traffic(delta, _get_traffic_vehicles(response.cruiser), true)
	if response.ai.wants_recycle():
		_request_response_replacement(response, &"route_blocked")
		return
	if response.ai.has_reached_destination():
		if player_is_moving_vehicle:
			_retarget_dynamic_response(response, response_target, false, &"intercept_reached")
			return
		if vehicle_component.is_driving():
			var close_to_vehicle := (
				response.cruiser.global_position.distance_to(
					vehicle_component.get_effective_position()
				) <= response_profile.deployment_distance
			)
			if (
				response.stationary_elapsed
				< response_profile.stationary_deploy_seconds
				or not close_to_vehicle
			):
				_retarget_dynamic_response(
					response,
					response_target,
					true,
					&"stopped_vehicle_not_close"
				)
				return
		response.ai.clear()
		response.state = ResponseUnit.State.PULL_OVER


func _retarget_dynamic_response(
	response: ResponseUnit,
	world_position: Vector3,
	stop_at_destination: bool,
	reason: StringName,
	force_retarget := false
) -> bool:
	var network := response.zone.get("network") as TrafficNetwork3D
	if network == null:
		response.last_failure_reason = &"missing_network"
		return false
	if (
		not force_retarget
		and response.ai.has_route()
		and not response.ai.has_reached_destination()
		and response.target_snapshot.distance_to(world_position)
		< minimum_dynamic_retarget_distance
	):
		return true
	var exclusions := _get_response_destination_exclusions(response)
	var stand_off := response.stand_off_distance if not vehicle_component.is_driving() else 0.0
	var assigned := response.ai.retarget_world_position(
		world_position,
		stop_at_destination,
		stand_off,
		exclusions,
		response_destination_separation
	)
	if not assigned:
		var start := network.get_nearest_waypoint(
			response.cruiser.global_position,
			60.0
		)
		if start != null:
			assigned = response.ai.assign_route_to_world_position(
				network,
				start,
				world_position,
				_random.randi(),
				stop_at_destination,
				stand_off,
				exclusions,
				response_destination_separation
			)
	if not assigned:
		response.last_failure_reason = reason
		return false
	response.destination_position = response.ai.get_destination_position()
	response.approach_direction = response.ai.get_destination_approach_direction()
	response.target_snapshot = world_position
	response.last_failure_reason = &""
	return true


func _tick_pull_over(response: ResponseUnit, delta: float) -> void:
	var target_speed := vehicle_component.get_effective_velocity().length()
	if (
		vehicle_component.is_driving()
		and target_speed > response_profile.stationary_speed
	):
		_resume_mounted_response(response)
		return
	if (
		not vehicle_component.is_driving()
		and response.hold < 0.5
		and response.cruiser.global_position.distance_to(
			vehicle_component.get_effective_position()
		) > response_profile.deployment_distance * 1.5
	):
		_resume_mounted_response(response)
		return
	response.cruiser.drive_component.set_ai_control(0.0, 1.0, 0.0)
	if response.cruiser.linear_velocity.length() < 0.75:
		response.hold += delta
	else:
		response.hold = 0.0
	if response.hold >= 0.5:
		response.cruiser.call("silence_siren")
		response.state = ResponseUnit.State.DEPLOYING
		response.unload_remaining = 0.0
		var event_bus := WorldEventBus.find(get_tree())
		if event_bus != null:
			event_bus.publish_spatial_event(
				WorldEvent.Type.POLICE_PRESENCE,
				response.cruiser,
				response.cruiser.global_position,
				22.0,
				1,
				&"police",
				{"incident_id": _incident.incident_id if _incident != null else 0}
			)
		cruiser_arrived.emit(response.cruiser, _incident.incident_id if _incident != null else 0)


func _recover_stalled_response(response: ResponseUnit) -> void:
	if _incident == null:
		return
	if response.recovery_count >= 2:
		_request_response_replacement(response, &"recovery_exhausted")
		return
	var moving_vehicle := (
		vehicle_component.is_driving()
		and vehicle_component.get_effective_velocity().length()
		> response_profile.stationary_speed
	)
	if _retarget_dynamic_response(
		response,
		_get_dynamic_response_target(),
		not moving_vehicle,
		&"stalled_reroute_failed",
		true
	):
		response.recovery_count += 1


func _resume_mounted_response(response: ResponseUnit) -> void:
	response.hold = 0.0
	response.unload_remaining = 0.0
	response.stationary_elapsed = 0.0
	response.cruiser.call("set_emergency_active", true, true)
	response.state = (
		ResponseUnit.State.PURSUING
		if vehicle_component.is_driving()
		else ResponseUnit.State.EN_ROUTE
	)
	var moving_vehicle := (
		vehicle_component.is_driving()
		and vehicle_component.get_effective_velocity().length()
		> response_profile.stationary_speed
	)
	if not _retarget_dynamic_response(
		response,
		_get_dynamic_response_target(),
		not moving_vehicle,
		&"resume_route_failed",
		true
	):
		_request_response_replacement(response, &"resume_route_failed")


func _request_response_replacement(
	response: ResponseUnit,
	reason: StringName
) -> void:
	if response.replacement_requested:
		return
	response.replacement_requested = true
	response.last_failure_reason = reason
	response.seat_count = response.officers.size()
	_dispatch_remaining = 0.0
	_launch_remaining = 0.0
	_begin_cruiser_exit(response)


func _get_dynamic_response_target(use_live_position := false) -> Vector3:
	var position := (
		vehicle_component.get_effective_position()
		if use_live_position or _last_known_position.is_zero_approx()
		else _last_known_position
	)
	if not vehicle_component.is_driving():
		return position
	var velocity := Vector3.ZERO
	if use_live_position:
		velocity = vehicle_component.get_effective_velocity()
	elif _incident != null:
		velocity = _incident.last_known_velocity
	return position + velocity * pursuit_prediction_seconds


func _get_response_destination_exclusions(
	excluded_response: ResponseUnit = null
) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for response in _responses:
		if response == excluded_response or not response.destination_position.is_finite():
			continue
		if response.state in [ResponseUnit.State.RETURNING, ResponseUnit.State.EXITING]:
			continue
		positions.append(response.destination_position)
	return positions


func _tick_unloading(response: ResponseUnit, delta: float) -> void:
	if (
		response.officers.is_empty()
		and vehicle_component.is_driving()
		and vehicle_component.get_effective_velocity().length()
		> response_profile.stationary_speed
	):
		_resume_mounted_response(response)
		return
	if response.officers.size() >= response.seat_count:
		response.state = ResponseUnit.State.ON_SCENE
		return
	response.deploy_elapsed += delta
	response.unload_remaining = maxf(response.unload_remaining - delta, 0.0)
	if response.unload_remaining > 0.0:
		return
	var population := response.zone.get("population") as CivilianPopulationManager
	var response_target := (
		_last_known_position
		if not _last_known_position.is_zero_approx()
		else vehicle_component.get_effective_position()
	)
	var exit_position := _get_safe_officer_exit_position(
		response.cruiser,
		response.officers.size(),
		population
	)
	var officer := population.spawn_response_officer(
		exit_position,
		_incident.incident_id if _incident != null else 0,
		response_target
	) if population != null else null
	if officer == null and population != null:
		var nearest := population.network.get_nearest_waypoint(response.cruiser.global_position, 45.0)
		if nearest != null:
			officer = population.spawn_response_officer(
				nearest.global_position,
				_incident.incident_id if _incident != null else 0,
				response_target
			)
	if officer != null:
		response.officers.append(officer)
	if response.deploy_elapsed >= deployment_failure_timeout and officer == null:
		response.seat_count = response.officers.size()
		response.state = ResponseUnit.State.ON_SCENE
	response.unload_remaining = unload_interval


func _tick_on_scene(response: ResponseUnit, delta: float) -> void:
	var living: Array[PoliceNPC] = []
	for officer in response.officers:
		if is_instance_valid(officer) and not officer.is_defeated():
			living.append(officer)
	response.officers = living
	if not living.is_empty():
		response.empty_scene_elapsed = 0.0
		return
	response.empty_scene_elapsed += delta
	if response.empty_scene_elapsed < empty_cruiser_cleanup_delay:
		return
	_begin_cruiser_exit(response)
	if wanted.wanted_level > 0:
		_dispatch_remaining = 0.0


func _get_safe_officer_exit_position(
	cruiser: BaseVehicle,
	officer_index: int,
	population: CivilianPopulationManager
) -> Vector3:
	var door_position := cruiser.call(
		"get_officer_exit_position", officer_index
	) as Vector3
	var side := door_position - cruiser.global_position
	side.y = 0.0
	side = side.normalized()
	if side.is_zero_approx():
		side = cruiser.global_basis.x.normalized()
	var forward := cruiser.global_basis.z.normalized()
	var candidates: Array[Vector3] = [
		door_position,
		door_position + side * 0.9,
		door_position + side * 0.9 + forward * 1.0,
		door_position + side * 0.9 - forward * 1.0,
	]
	for candidate in candidates:
		var grounded := _ground_officer_exit(candidate, cruiser)
		if _is_officer_exit_clear(grounded, cruiser):
			return grounded
	if population != null and population.network != null:
		var nearest := population.network.get_nearest_waypoint(
			cruiser.global_position,
			45.0
		)
		if nearest != null:
			return nearest.global_position
	return door_position


func _ground_officer_exit(position: Vector3, cruiser: BaseVehicle) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(
		position + Vector3.UP * 2.5,
		position - Vector3.UP * 3.0
	)
	query.collision_mask = 0xffffffff
	query.collide_with_areas = false
	query.exclude = [cruiser.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("position", position) as Vector3


func _is_officer_exit_clear(
	position: Vector3,
	cruiser: BaseVehicle
) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(
		Basis.IDENTITY,
		position + Vector3.UP * 0.9
	)
	query.collision_mask = 3
	query.collide_with_areas = false
	query.exclude = [cruiser.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _begin_response_return(response: ResponseUnit) -> void:
	if not is_instance_valid(response.cruiser) or response.state in [ResponseUnit.State.RETURNING, ResponseUnit.State.EXITING]:
		return
	response.cruiser.call("set_emergency_active", false)
	if response.state in [ResponseUnit.State.EN_ROUTE, ResponseUnit.State.PURSUING, ResponseUnit.State.PULL_OVER]:
		_begin_cruiser_exit(response)
		return
	response.ai.clear()
	response.cruiser.drive_component.set_ai_control(0.0, 1.0, 0.0)
	response.return_elapsed = 0.0
	response.return_retargeted = false
	response.return_positions.clear()
	var population := response.zone.get("population") as CivilianPopulationManager
	var returning_officers: Array[PoliceNPC] = []
	for officer_index in response.officers.size():
		var police := response.officers[officer_index]
		if is_instance_valid(police) and not police.is_defeated():
			police.bt_player.set_active(false)
			var door_position := _get_safe_officer_exit_position(
				response.cruiser,
				officer_index,
				population
			)
			returning_officers.append(police)
			response.return_positions.append(door_position)
			police.set_navigation_target(door_position)
	response.officers = returning_officers
	response.state = ResponseUnit.State.RETURNING


func _tick_officer_return(response: ResponseUnit, delta: float) -> void:
	response.return_elapsed += delta
	response.cruiser.drive_component.set_ai_control(0.0, 1.0, 0.0)
	var population := response.zone.get("population") as CivilianPopulationManager
	var remaining: Array[PoliceNPC] = []
	var remaining_positions: Array[Vector3] = []
	for officer_index in response.officers.size():
		var police := response.officers[officer_index]
		if not is_instance_valid(police) or police.is_defeated():
			continue
		var door_position := (
			response.return_positions[officer_index]
			if officer_index < response.return_positions.size()
			else response.cruiser.call("get_officer_exit_position", officer_index) as Vector3
		)
		var door_distance := police.global_position.distance_to(door_position)
		var both_offscreen := (
			_is_offscreen(police.global_position)
			and _is_offscreen(response.cruiser.global_position)
		)
		var can_finish_boarding := (
			door_distance <= officer_reentry_distance
			or (response.return_elapsed >= 1.5 and both_offscreen)
			or (
				response.return_elapsed >= officer_return_timeout
				and door_distance <= officer_return_nearby_fallback
			)
			or response.return_elapsed >= officer_return_hard_timeout
		)
		if can_finish_boarding:
			_recycle_returning_officer(police, population)
			continue
		if (
			response.return_elapsed >= officer_return_timeout
			and not response.return_retargeted
		):
			police.set_navigation_target(door_position)
		police.advance_navigation(delta)
		remaining.append(police)
		remaining_positions.append(door_position)
	if response.return_elapsed >= officer_return_timeout:
		response.return_retargeted = true
	response.officers = remaining
	response.return_positions = remaining_positions
	if remaining.is_empty():
		_begin_cruiser_exit(response)


func _recycle_returning_officer(
	police: PoliceNPC,
	population: CivilianPopulationManager
) -> void:
	if population != null:
		population.recycle_response_officer(police)
	else:
		police.prepare_for_pool_recycle()


func _begin_cruiser_exit(response: ResponseUnit) -> void:
	response.state = ResponseUnit.State.EXITING
	response.exit_elapsed = 0.0
	response.exit_stalled_elapsed = 0.0
	response.exit_progress_position = response.cruiser.global_position
	response.exit_coasting = false
	response.cruiser.call("set_emergency_active", false)
	if _is_offscreen(response.cruiser.global_position):
		_recycle_cruiser(response.cruiser)
		response.finished = true
		return
	if _assign_cruiser_exit_route(response):
		return
	response.ai.clear()
	response.exit_coasting = true


func _assign_cruiser_exit_route(response: ResponseUnit) -> bool:
	var network := response.zone.get("network") as TrafficNetwork3D
	var current := response.ai.get_current_waypoint()
	if current == null and network != null:
		current = network.get_nearest_waypoint(
			response.cruiser.global_position,
			90.0
		)
	var exit := network.choose_reachable_exit(current, _random) if network != null and current != null else null
	if current == null or exit == null:
		return false
	if not response.ai.assign_route_to(network, current, exit, _random.randi(), false):
		return false
	response.ai.set_emergency_mode(false)
	response.exit_stalled_elapsed = 0.0
	response.exit_progress_position = response.cruiser.global_position
	return true


func _tick_cruiser_exit(response: ResponseUnit, delta: float) -> void:
	response.exit_elapsed += delta
	if response.exit_coasting:
		response.cruiser.drive_component.set_ai_control(0.5, 0.0, 0.0)
		if (
			_is_offscreen(response.cruiser.global_position)
			or response.exit_elapsed >= exit_coast_timeout
		):
			_recycle_cruiser(response.cruiser)
			response.finished = true
		return
	var moved := response.cruiser.global_position.distance_to(
		response.exit_progress_position
	)
	if moved >= 1.0:
		response.exit_progress_position = response.cruiser.global_position
		response.exit_stalled_elapsed = 0.0
	elif response.cruiser.linear_velocity.length() < 0.75:
		response.exit_stalled_elapsed += delta
	response.ai.tick_traffic(
		delta,
		_get_traffic_vehicles(response.cruiser),
		true
	)
	if response.ai.wants_recycle():
		var current := response.ai.get_current_waypoint()
		if current != null and current.is_exit():
			response.exit_coasting = true
			response.exit_elapsed = 0.0
			return
		if not _assign_cruiser_exit_route(response):
			response.ai.clear()
			response.exit_coasting = true
			response.exit_elapsed = 0.0
		return
	if response.exit_stalled_elapsed >= exit_stall_reroute_seconds:
		if not _assign_cruiser_exit_route(response):
			response.ai.clear()
			response.exit_coasting = true
		response.exit_elapsed = 0.0


func _release_reservations(response: ResponseUnit) -> void:
	if response.start != null:
		_reserved_starts.erase(response.start.get_instance_id())


func _is_spawn_clear(position: Vector3) -> bool:
	if traffic_coordinator != null:
		return traffic_coordinator.is_spawn_clear(
			Transform3D(Basis.IDENTITY, position),
			Vector3(2.2, 1.65, 4.9)
		)
	for node in get_tree().get_nodes_in_group(&"traffic_vehicle"):
		if node is BaseVehicle and (node as BaseVehicle).global_position.distance_to(position) < spawn_clearance:
			return false
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 1.0, 6.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * 1.2)
	query.collision_mask = 3
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _has_road_surface(position: Vector3) -> bool:
	return not _find_road_surface(position).is_empty()


func _get_grounded_cruiser_spawn(
	spawn_transform: Transform3D,
	cruiser: BaseVehicle
) -> Dictionary:
	var hit := _find_road_surface(spawn_transform.origin)
	if hit.is_empty():
		return {}
	spawn_transform.origin = (
		hit.get("position") as Vector3
		+ Vector3.UP * cruiser.get_grounded_spawn_height()
	)
	return {"transform": spawn_transform}


func _find_road_surface(position: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		position + Vector3.UP * 8.0,
		position - Vector3.UP * 20.0
	)
	query.collision_mask = 0xffffffff
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query)


func _get_route_distance(route: Array[TrafficWaypoint3D]) -> float:
	var result := 0.0
	for index in range(1, route.size()):
		result += route[index - 1].global_position.distance_to(route[index].global_position)
	return result


func _get_response_scheduled_count(response: ResponseUnit) -> int:
	if response.state in [ResponseUnit.State.RETURNING, ResponseUnit.State.EXITING]:
		return 0
	var living := 0
	for officer in response.officers:
		if is_instance_valid(officer) and not officer.is_defeated():
			living += 1
	if response.state in [ResponseUnit.State.EN_ROUTE, ResponseUnit.State.PURSUING, ResponseUnit.State.PULL_OVER, ResponseUnit.State.DEPLOYING]:
		return maxi(living, response.seat_count)
	return living


func _is_officer_effective(officer: PoliceNPC, response_state := -1) -> bool:
	if (
		not is_instance_valid(officer)
		or officer.is_defeated()
		or not officer.is_pool_active()
		or not officer.is_response_assigned()
		or _incident == null
		or response_state in [ResponseUnit.State.RETURNING, ResponseUnit.State.EXITING]
	):
		return false
	var maximum_distance := response_profile.get_awareness_radius(wanted.wanted_level)
	return officer.global_position.distance_squared_to(_last_known_position) <= maximum_distance * maximum_distance


func _spawn_fallback_officer() -> bool:
	var zone := _get_active_zone()
	if zone.is_empty() or _incident == null:
		return false
	var population := zone.get("population") as CivilianPopulationManager
	if population == null or population.network == null:
		return false
	var candidates: Array[PedestrianWaypoint3D] = population.network.get_spawn_candidates(
		_last_known_position,
		22.0,
		45.0,
		16
	)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var fallback_waypoint: PedestrianWaypoint3D
	for waypoint: PedestrianWaypoint3D in candidates:
		if fallback_waypoint == null:
			fallback_waypoint = waypoint
		if camera != null and camera.is_position_in_frustum(waypoint.global_position + Vector3.UP):
			continue
		var officer: PoliceNPC = population.spawn_response_officer(
			waypoint.global_position,
			_incident.incident_id,
			_last_known_position
		)
		if officer == null:
			continue
		_register_fallback_officer(officer, population)
		return true
	if fallback_waypoint != null:
		var fallback_officer := population.spawn_response_officer(
			fallback_waypoint.global_position,
			_incident.incident_id,
			_last_known_position
		)
		if fallback_officer != null:
			_register_fallback_officer(fallback_officer, population)
			return true
	var nearest := population.network.get_nearest_waypoint(
		_last_known_position,
		response_profile.get_awareness_radius(wanted.wanted_level)
	)
	if nearest != null:
		var nearest_officer := population.spawn_response_officer(
			nearest.global_position,
			_incident.incident_id,
			_last_known_position
		)
		if nearest_officer != null:
			_register_fallback_officer(nearest_officer, population)
			return true
	return false


func _register_fallback_officer(officer: PoliceNPC, population: CivilianPopulationManager) -> void:
	_fallback_officers.append(officer)
	_fallback_population_by_officer[officer.get_instance_id()] = population
	var bus := WorldEventBus.find(get_tree())
	if bus != null:
		bus.record_state_transition(
			&"police_response",
			officer,
			&"pooled",
			&"effective",
			&"foot_fallback_spawned",
			{
				"incident_id": _incident.incident_id if _incident != null else 0,
				"territory_id": String(_incident.territory_id) if _incident != null else "",
			}
		)


func _recycle_fallback_officers() -> void:
	for officer in _fallback_officers:
		if not is_instance_valid(officer) or officer.is_defeated():
			continue
		var population := _fallback_population_by_officer.get(
			officer.get_instance_id()
		) as CivilianPopulationManager
		if population != null:
			population.recycle_response_officer(officer)
	_fallback_officers.clear()
	_fallback_population_by_officer.clear()


func _get_mobile_cruiser_count() -> int:
	var count := 0
	for response in _responses:
		if (
			not response.replacement_requested
			and response.state in [ResponseUnit.State.EN_ROUTE, ResponseUnit.State.PURSUING, ResponseUnit.State.PULL_OVER]
		):
			count += 1
	return count


func _get_engaged_cruiser_count() -> int:
	var count := 0
	for response in _responses:
		if (
			not response.replacement_requested
			and response.state not in [ResponseUnit.State.RETURNING, ResponseUnit.State.EXITING]
		):
			count += 1
	return count


func _get_effective_target_node() -> Node3D:
	return vehicle_component.get_current_vehicle() as Node3D if vehicle_component.is_driving() else player


func _acquire_cruiser(definition: VehicleDefinition) -> BaseVehicle:
	var pool := _inactive_cruisers.get(definition.vehicle_id, []) as Array
	if not pool.is_empty():
		var cruiser := pool.pop_back() as BaseVehicle
		_inactive_cruisers[definition.vehicle_id] = pool
		return cruiser
	var cruiser := cruiser_scene.instantiate() as BaseVehicle
	if cruiser == null:
		return null
	cruiser.configure_definition_before_tree(definition)
	traffic_container.add_child(cruiser)
	return cruiser


func _recycle_cruiser(cruiser: BaseVehicle) -> void:
	if not is_instance_valid(cruiser):
		return
	var id := cruiser.get_vehicle_id()
	cruiser.call("set_emergency_active", false)
	cruiser.set_managed_traffic_enabled(false)
	if traffic_coordinator != null:
		traffic_coordinator.unregister_vehicle(cruiser)
	cruiser.linear_velocity = Vector3.ZERO
	cruiser.angular_velocity = Vector3.ZERO
	cruiser.sleeping = true
	cruiser.visible = false
	cruiser.process_mode = Node.PROCESS_MODE_DISABLED
	cruiser.collision_layer = 0
	cruiser.collision_mask = 0
	if not _inactive_cruisers.has(id):
		_inactive_cruisers[id] = []
	if cruiser not in (_inactive_cruisers[id] as Array):
		(_inactive_cruisers[id] as Array).append(cruiser)


func _ensure_ai(cruiser: BaseVehicle) -> TrafficVehicleAIComponent:
	var ai := cruiser.get_node_or_null("TrafficAIComponent") as TrafficVehicleAIComponent
	if ai == null:
		ai = TrafficVehicleAIComponent.new()
		ai.name = "TrafficAIComponent"
		cruiser.add_child(ai)
	ai.initialize(cruiser)
	return ai


func _choose_police_definition() -> VehicleDefinition:
	var level := clampi(wanted.wanted_level, 1, 3)
	return _police_suv_definition if _random.randf() < [0.0, 0.2, 0.4, 0.6][level] else _police_sedan_definition


func _prewarm_cruiser_pool() -> void:
	var definitions: Array[VehicleDefinition] = [
		_police_sedan_definition,
		_police_sedan_definition,
		_police_suv_definition,
	]
	for definition in definitions:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		var cruiser := cruiser_scene.instantiate() as BaseVehicle
		if cruiser == null:
			continue
		cruiser.configure_definition_before_tree(definition)
		traffic_container.add_child(cruiser)
		_recycle_cruiser(cruiser)


func _create_police_definition(suv: bool) -> VehicleDefinition:
	var definition := VehicleDefinition.new()
	definition.vehicle_id = &"police_suv" if suv else &"police_sedan"
	definition.display_name = "Police SUV" if suv else "Police Sedan"
	definition.visual_scene = load("res://Assets/MapStuff/Meshs/Vehicles/%s" % ("SK_veh_PoliceCarSUV_01.gltf" if suv else "SK_veh_PoliceCarSedan_01.gltf")) as PackedScene
	if suv:
		definition.collision_size = Vector3(2.15, 1.65, 4.65)
		definition.collision_offset = Vector3(0, 1.0, -.05)
		definition.front_left_wheel_anchor = Vector3(.838, .596849, 1.604)
		definition.front_right_wheel_anchor = Vector3(-.838, .596849, 1.604)
		definition.rear_left_wheel_anchor = Vector3(.838, .596849, -1.424)
		definition.rear_right_wheel_anchor = Vector3(-.838, .596849, -1.424)
		definition.wheel_radius = .376849
	else:
		definition.collision_size = Vector3(2.2, 1.15, 4.9)
		definition.collision_offset = Vector3(0, .78, .05)
		definition.front_left_wheel_anchor = Vector3(.886, .568836, 1.631)
		definition.front_right_wheel_anchor = Vector3(-.887, .568836, 1.631)
		definition.rear_left_wheel_anchor = Vector3(.886, .568836, -1.321)
		definition.rear_right_wheel_anchor = Vector3(-.887, .568836, -1.321)
		definition.wheel_radius = .348836
	definition.mass = 1700.0 if suv else 1500.0
	definition.engine_force = 9000.0
	definition.max_forward_speed = 42.0
	return definition


func _get_traffic_vehicles(excluding: BaseVehicle) -> Array[BaseVehicle]:
	if traffic_coordinator != null:
		return traffic_coordinator.get_nearby_vehicles(
			excluding,
			police_traffic_query_radius
		)
	var results: Array[BaseVehicle] = []
	for node in get_tree().get_nodes_in_group(&"traffic_vehicle"):
		if node is BaseVehicle and node != excluding:
			results.append(node as BaseVehicle)
	return results


func _is_offscreen(world_position: Vector3) -> bool:
	var camera := get_viewport().get_camera_3d()
	return camera == null or not camera.is_position_in_frustum(world_position + Vector3.UP)
