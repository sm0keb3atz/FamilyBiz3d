@tool
class_name DealerActivityZone3D
extends Node3D

signal member_defeated(zone_id: StringName, member_id: StringName)
signal faction_changed(zone_id: StringName, faction: int)

@export var zone_id: StringName
@export var territory_id: StringName = &"hood_east"
@export var faction := TerritoryStatsComponent.OwnerFaction.RIVAL
@export var dealer_scene: PackedScene
@export var member_ids := PackedStringArray()
@export var dealer_levels := PackedInt32Array()
@export var member_positions: Array[Vector3] = []
@export var member_rotations_degrees := PackedFloat32Array()
@export var activity_animations := PackedStringArray()
@export_range(0, 16, 1) var required_interactable_index := 0
@export var reinforcement_positions: Array[Vector3] = []
@export var spawn_on_ready := true
@export_range(1.0, 30.0, 0.5) var lean_wall_search_distance := 12.0
@export_range(0.02, 1.0, 0.01) var lean_wall_offset := 0.08
@export_flags_3d_physics var lean_wall_collision_mask := 1
@export_range(5.0, 60.0, 1.0) var activity_cycle_min_seconds := 15.0
@export_range(5.0, 60.0, 1.0) var activity_cycle_max_seconds := 30.0
@export_range(1.5, 10.0, 0.5) var hangout_radius := 4.5
@export_range(1.0, 60.0, 1.0) var ally_alert_radius := 28.0
@export_range(1, 1440, 1) var dealer_respawn_minutes := 60

var _dealers: Dictionary[StringName, DealerNPC] = {}
var _member_state: Dictionary = {}
var _world_time: WorldTimeComponent
var _presentation_generation := 0
var _activity_cycle_index := 0
var _activity_time_remaining := 0.0
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_random.randomize()
	set_process(false)
	add_to_group(&"dealer_activity_zone")
	call_deferred("_initialize_runtime")


func _process(delta: float) -> void:
	_activity_time_remaining -= delta
	if _activity_time_remaining > 0.0:
		return
	if not _dealer_navigation_maps_are_ready():
		_activity_time_remaining = 0.5
		return
	_configure_group_presentation()


func _initialize_runtime() -> void:
	_world_time = get_tree().get_first_node_in_group(&"world_time") as WorldTimeComponent
	if _world_time != null:
		_world_time.minute_advanced.connect(_on_minute_advanced)
	if spawn_on_ready:
		spawn_available_members()


func spawn_available_members() -> void:
	for index in range(member_ids.size()):
		var member_id := StringName(member_ids[index])
		var state := _get_member_state(member_id)
		if faction == TerritoryStatsComponent.OwnerFaction.PLAYER and not bool(state.get("employed", false)):
			continue
		if bool(state.get("dead", false)):
			continue
		if is_instance_valid(_dealers.get(member_id)):
			continue
		_spawn_member(index, state)
	_schedule_group_presentation()


func _spawn_member(index: int, state: Dictionary) -> DealerNPC:
	if dealer_scene == null or index < 0 or index >= member_ids.size():
		return null
	var dealer := dealer_scene.instantiate() as DealerNPC
	if dealer == null:
		return null
	if StringName(member_ids[index]) == &"south_l1_primary":
		dealer.name = "EastDealer"
	else:
		dealer.name = "%s_%s" % [String(zone_id), String(member_ids[index])]
	var world_root := get_tree().current_scene
	if world_root == null:
		world_root = get_parent().get_parent()
	var container := world_root.get_node_or_null("Gameplay")
	if container == null:
		container = get_parent()
	container.add_child(dealer)
	dealer.global_position = global_transform * _get_member_position(index)
	dealer.global_rotation.y = 0.0
	var level := clampi(
		int(state.get("player_level", 1))
		if faction == TerritoryStatsComponent.OwnerFaction.PLAYER
		else _array_int(dealer_levels, index, 1),
		1,
		4
	)
	dealer.configure_zone_member(
		self,
		StringName(member_ids[index]),
		level,
		StringName(_array_string(activity_animations, index, "Idle")),
		index == required_interactable_index
	)
	if state.has("dealer"):
		dealer.import_save_data(state["dealer"] as Dictionary)
	dealer.set_player_operated(faction == TerritoryStatsComponent.OwnerFaction.PLAYER)
	_dealers[StringName(member_ids[index])] = dealer
	return dealer


func handle_member_first_hit(dealer: DealerNPC) -> void:
	if dealer == null or faction == TerritoryStatsComponent.OwnerFaction.PLAYER:
		return
	var stats := get_territory_stats()
	if stats != null and stats.reputation < 100.0:
		stats.add_reputation(-5.0)
		_show_feedback("-5 %s Reputation" % _territory_display_name())


func alert_allies(source: Node, incident_position: Vector3, attacked: DealerNPC) -> void:
	if source == null:
		return
	var maximum_distance_squared := ally_alert_radius * ally_alert_radius
	for node in get_tree().get_nodes_in_group(&"dealer_activity_zone"):
		var zone := node as DealerActivityZone3D
		if zone == null or zone.territory_id != territory_id:
			continue
		for ally in zone.get_living_dealers():
			if (
				ally == attacked
				or ally.is_hostile()
				or ally.global_position.distance_squared_to(incident_position)
				> maximum_distance_squared
			):
				continue
			ally.provoke(source, incident_position)


func handle_member_defeated(dealer: DealerNPC, player_caused: bool) -> void:
	if dealer == null:
		return
	var member_id := dealer.zone_member_id
	var state := _get_member_state(member_id)
	var stats := get_territory_stats()
	state["dead"] = true
	state["respawn_minute"] = _get_absolute_minute() + dealer_respawn_minutes
	state.erase("respawn_day")
	state["takeover_kill"] = (
		player_caused
		and stats != null
		and stats.reputation >= 100.0
		and faction != TerritoryStatsComponent.OwnerFaction.PLAYER
	)
	state["dealer"] = dealer.export_save_data()
	_member_state[String(member_id)] = state
	_dealers.erase(member_id)
	_schedule_group_presentation()
	if player_caused:
		if stats != null and faction != TerritoryStatsComponent.OwnerFaction.PLAYER and stats.reputation < 100.0:
			stats.add_reputation(-10.0)
			_show_feedback("Dealer killed: -10 Reputation. Search the body.", 3.0)
		elif faction != TerritoryStatsComponent.OwnerFaction.PLAYER:
			_show_feedback("Dealer killed at +100: search the body.", 3.0)
	member_defeated.emit(zone_id, member_id)
	get_tree().call_group(&"territory_encounter", "on_permanent_dealer_defeated", self, dealer)


func set_faction(value: int) -> void:
	var next := clampi(value, TerritoryStatsComponent.OwnerFaction.NEUTRAL, TerritoryStatsComponent.OwnerFaction.PLAYER)
	if next == faction:
		return
	faction = next
	if faction == TerritoryStatsComponent.OwnerFaction.PLAYER:
		for member_id_text in member_ids:
			var member_id := StringName(member_id_text)
			var state := _get_member_state(member_id)
			state["employed"] = false
			_member_state[String(member_id)] = state
			despawn_member(member_id)
	for dealer in _dealers.values():
		if is_instance_valid(dealer):
			var existing := dealer as DealerNPC
			existing.clear_hostility()
			existing.set_player_operated(faction == TerritoryStatsComponent.OwnerFaction.PLAYER)
	faction_changed.emit(zone_id, faction)


func get_member_level(member_id: StringName) -> int:
	var index := member_ids.find(String(member_id))
	return clampi(_array_int(dealer_levels, index, 1), 1, 4) if index >= 0 else 1


func get_member_dealer(member_id: StringName) -> DealerNPC:
	var dealer := _dealers.get(member_id) as DealerNPC
	return dealer if is_instance_valid(dealer) else null


func set_member_employed(member_id: StringName, employed: bool) -> void:
	var index := member_ids.find(String(member_id))
	if index < 0 or faction != TerritoryStatsComponent.OwnerFaction.PLAYER:
		return
	var state := _get_member_state(member_id)
	state["employed"] = employed
	if employed:
		state["dead"] = false
		state.erase("dealer")
		state.erase("respawn_minute")
		state.erase("takeover_kill")
	_member_state[String(member_id)] = state
	if employed:
		if not is_instance_valid(_dealers.get(member_id)):
			_spawn_member(index, state)
	else:
		despawn_member(member_id)
	_schedule_group_presentation()


func set_member_player_level(member_id: StringName, level: int) -> void:
	var index := member_ids.find(String(member_id))
	if index < 0 or faction != TerritoryStatsComponent.OwnerFaction.PLAYER:
		return
	var next_level := clampi(level, 1, 4)
	var state := _get_member_state(member_id)
	state["player_level"] = next_level
	_member_state[String(member_id)] = state
	var dealer := get_member_dealer(member_id)
	if dealer != null:
		dealer.set_player_operation_level(next_level)


func apply_player_staffing(staffing: Dictionary) -> void:
	if faction != TerritoryStatsComponent.OwnerFaction.PLAYER:
		return
	for member_id_text in member_ids:
		var member_id := StringName(member_id_text)
		set_member_employed(member_id, bool(staffing.get(String(member_id), false)))


func despawn_member(member_id: StringName) -> void:
	var dealer := _dealers.get(member_id) as DealerNPC
	_dealers.erase(member_id)
	if is_instance_valid(dealer):
		dealer.cancel_customer_sale_presentation()
		dealer.queue_free()


func get_living_dealers() -> Array[DealerNPC]:
	var result: Array[DealerNPC] = []
	for dealer in _dealers.values():
		if is_instance_valid(dealer) and not (dealer as DealerNPC).is_defeated():
			result.append(dealer)
	return result


func get_spawned_dealers() -> Array[DealerNPC]:
	return get_living_dealers()


func get_required_member_count() -> int:
	return member_ids.size()


func get_living_member_count() -> int:
	return get_living_dealers().size()


func refresh_group_presentation() -> void:
	_schedule_group_presentation()


func has_completed_takeover_wipe() -> bool:
	if member_ids.is_empty():
		return false
	var stats := get_territory_stats()
	var respawns_locked := stats != null and stats.reputation >= 100.0
	for member_id in member_ids:
		var state := _get_member_state(StringName(member_id))
		if respawns_locked and not bool(state.get("dead", false)):
			return false
		if not respawns_locked and not bool(state.get("takeover_kill", false)):
			return false
	return true


func get_reinforcement_world_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for position in reinforcement_positions:
		result.append(global_transform * position)
	return result


func get_territory_stats() -> TerritoryStatsComponent:
	for node in get_tree().get_nodes_in_group(&"territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if boundary != null and boundary.territory_id == territory_id:
			return boundary.stats
	return null


func export_save_data() -> Dictionary:
	var states := _member_state.duplicate(true)
	for member_id in _dealers.keys():
		var dealer := _dealers[member_id] as DealerNPC
		if is_instance_valid(dealer):
			var state := _get_member_state(member_id)
			state["dealer"] = dealer.export_save_data()
			states[String(member_id)] = state
	return {"faction": faction, "members": states}


func import_save_data(data: Dictionary) -> void:
	faction = clampi(int(data.get("faction", faction)), 0, 2)
	_member_state = (data.get("members", {}) as Dictionary).duplicate(true)
	_clamp_imported_respawn_deadlines()
	for dealer in _dealers.values():
		if is_instance_valid(dealer):
			var existing := dealer as DealerNPC
			if existing.get_parent() != null:
				existing.get_parent().remove_child(existing)
			existing.queue_free()
	_dealers.clear()
	spawn_available_members()


func _on_minute_advanced(_absolute_minute: int) -> void:
	var changed := false
	var stats := get_territory_stats()
	var respawns_locked := stats != null and stats.reputation >= 100.0
	for member_id in member_ids:
		var state := _get_member_state(StringName(member_id))
		var respawn_minute := int(state.get(
			"respawn_minute",
			int(state.get("respawn_day", 0)) * WorldTimeComponent.MINUTES_PER_DAY
		))
		if (
			bool(state.get("dead", false))
			and not respawns_locked
			and respawn_minute <= _get_absolute_minute()
		):
			state["dead"] = false
			state["takeover_kill"] = false
			state.erase("dealer")
			state.erase("respawn_day")
			state.erase("respawn_minute")
			_member_state[String(member_id)] = state
			changed = true
	if changed:
		spawn_available_members()


func _clamp_imported_respawn_deadlines() -> void:
	var maximum_deadline := _get_absolute_minute() + dealer_respawn_minutes
	for member_id in member_ids:
		var state := _get_member_state(StringName(member_id))
		if not bool(state.get("dead", false)):
			continue
		var saved_deadline := int(state.get(
			"respawn_minute",
			int(state.get("respawn_day", 0))
			* WorldTimeComponent.MINUTES_PER_DAY
		))
		state["respawn_minute"] = mini(saved_deadline, maximum_deadline)
		state.erase("respawn_day")
		_member_state[String(member_id)] = state


func _get_member_state(member_id: StringName) -> Dictionary:
	return (_member_state.get(String(member_id), {}) as Dictionary).duplicate(true)


func _get_absolute_minute() -> int:
	if _world_time == null and is_inside_tree():
		_world_time = get_tree().get_first_node_in_group(
			&"world_time"
		) as WorldTimeComponent
	return _world_time.get_absolute_minute() if _world_time != null else 0


func _configure_group_presentation() -> void:
	var available: Array[DealerNPC] = []
	for member_id_text in member_ids:
		var dealer := _dealers.get(StringName(member_id_text)) as DealerNPC
		if (
			is_instance_valid(dealer)
			and not dealer.is_defeated()
			and not dealer.is_hostile()
			and not dealer.is_shop_interaction_active()
		):
			available.append(dealer)
	if available.size() == 1:
		_configure_ambient_dealer(available[0], true)
	elif available.size() >= 2:
		var first_index := _activity_cycle_index % available.size()
		var second_index := (first_index + 1) % available.size()
		var first := available[first_index]
		var second := available[second_index]
		var first_target := _project_to_navigation(
			first,
			global_transform * Vector3(-1.25, 0.0, 0.0),
			first.global_position
		)
		var second_target := _project_to_navigation(
			second,
			global_transform * Vector3(1.25, 0.0, 0.0),
			second.global_position
		)
		first.set_zone_presentation(
			first_target,
			&"Talking",
			_yaw_toward(first_target, second_target)
		)
		second.set_zone_presentation(
			second_target,
			&"Talking",
			_yaw_toward(second_target, first_target)
		)
		for offset in range(2, available.size()):
			var dealer_index := (first_index + offset) % available.size()
			_configure_ambient_dealer(available[dealer_index], offset == 2)
	_activity_cycle_index += 1
	_reset_activity_timer()
	set_process(true)


func _configure_ambient_dealer(dealer: DealerNPC, allow_lean: bool) -> void:
	if allow_lean:
		var wall := _find_nearby_building_wall(dealer)
		if not wall.is_empty():
			var normal := wall["normal"] as Vector3
			var lean_animation := (
				&"LeaningOnWall1"
				if _activity_cycle_index % 2 == 0
				else &"LeaningOnWall2"
			)
			dealer.set_zone_presentation(
				wall["position"] as Vector3,
				lean_animation,
				atan2(normal.x, normal.z),
				wall["approach_position"] as Vector3
			)
			return
	var pacing_target := _find_pacing_target(dealer)
	dealer.set_zone_presentation(
		pacing_target,
		&"Idle",
		_yaw_toward(pacing_target, global_position)
	)


func _schedule_group_presentation() -> void:
	_presentation_generation += 1
	set_process(false)
	if get_living_dealers().is_empty():
		return
	_configure_group_presentation_when_navigation_ready(
		_presentation_generation
	)


func _configure_group_presentation_when_navigation_ready(
	generation: int
) -> void:
	# Navigation regions synchronize after scene readiness. Waiting for a real
	# iteration avoids querying a valid RID whose map has not been built yet.
	for _frame in range(120):
		if generation != _presentation_generation:
			return
		if _dealer_navigation_maps_are_ready():
			_configure_group_presentation()
			return
		await get_tree().physics_frame
	if generation == _presentation_generation:
		_configure_group_presentation()


func _dealer_navigation_maps_are_ready() -> bool:
	var found_dealer := false
	for dealer in _dealers.values():
		if not is_instance_valid(dealer):
			continue
		found_dealer = true
		var navigation_map := (dealer as DealerNPC).navigation_agent.get_navigation_map()
		if (
			not navigation_map.is_valid()
			or NavigationServer3D.map_get_iteration_id(navigation_map) == 0
		):
			return false
	return found_dealer


func _find_nearby_building_wall(dealer: DealerNPC) -> Dictionary:
	var navigation_map := dealer.navigation_agent.get_navigation_map()
	if (
		not navigation_map.is_valid()
		or NavigationServer3D.map_get_iteration_id(navigation_map) == 0
	):
		return {}
	var space_state := dealer.get_world_3d().direct_space_state
	var ray_origin := _get_wall_search_position(dealer) + Vector3.UP * 0.9
	var best_result := {}
	var best_distance_squared := INF
	for ray_index in 24:
		var angle := TAU * float(ray_index) / 24.0
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		var query := PhysicsRayQueryParameters3D.create(
			ray_origin,
			ray_origin + direction * lean_wall_search_distance,
			lean_wall_collision_mask
		)
		query.exclude = [dealer.get_rid()]
		var result := space_state.intersect_ray(query)
		if result.is_empty():
			continue
		var normal := result["normal"] as Vector3
		if absf(normal.y) > 0.25 or not _is_building_collider(result["collider"]):
			continue
		normal.y = 0.0
		normal = normal.normalized()
		var wall_position := result["position"] as Vector3
		var target := wall_position + normal * lean_wall_offset
		var approach_position := NavigationServer3D.map_get_closest_point(
			navigation_map, target
		)
		if approach_position.distance_squared_to(target) > 3.0 * 3.0:
			continue
		if not _has_clear_wall_approach(
			space_state,
			dealer,
			approach_position,
			wall_position,
			result["collider"]
		):
			continue
		target.y = approach_position.y
		var distance_squared := dealer.global_position.distance_squared_to(
			approach_position
		)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_result = {
				"position": target,
				"approach_position": approach_position,
				"normal": normal,
			}
	return best_result


func _has_clear_wall_approach(
	space_state: PhysicsDirectSpaceState3D,
	dealer: DealerNPC,
	approach_position: Vector3,
	wall_position: Vector3,
	expected_collider: Object
) -> bool:
	var origin := approach_position + Vector3.UP * 0.9
	var direction := wall_position - origin
	if direction.length_squared() <= 0.01:
		return true
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		wall_position + direction.normalized() * 0.1,
		lean_wall_collision_mask
	)
	query.exclude = [dealer.get_rid()]
	var result := space_state.intersect_ray(query)
	return not result.is_empty() and result["collider"] == expected_collider


func _get_wall_search_position(dealer: DealerNPC) -> Vector3:
	for index in range(activity_animations.size()):
		if StringName(activity_animations[index]) in [
			&"LeaningOnWall1", &"LeaningOnWall2"
		]:
			return global_transform * _get_member_position(index)
	return global_position if dealer == null else dealer.global_position


func _find_pacing_target(dealer: DealerNPC) -> Vector3:
	for _attempt in range(8):
		var angle := _random.randf_range(0.0, TAU)
		var radius := _random.randf_range(1.5, hangout_radius)
		var desired := global_transform * Vector3(
			sin(angle) * radius,
			0.0,
			cos(angle) * radius
		)
		var candidate := _project_to_navigation(
			dealer, desired, dealer.global_position
		)
		if candidate.distance_squared_to(global_position) <= (
			hangout_radius + 1.5
		) * (hangout_radius + 1.5):
			return candidate
	var member_index := member_ids.find(String(dealer.zone_member_id))
	var fallback := (
		global_transform * _get_member_position(member_index)
		if member_index >= 0
		else dealer.global_position
	)
	return _project_to_navigation(dealer, fallback, dealer.global_position)


func _project_to_navigation(
	dealer: DealerNPC,
	desired: Vector3,
	fallback: Vector3
) -> Vector3:
	var navigation_map := dealer.navigation_agent.get_navigation_map()
	if (
		not navigation_map.is_valid()
		or NavigationServer3D.map_get_iteration_id(navigation_map) == 0
	):
		return fallback
	var candidate := NavigationServer3D.map_get_closest_point(
		navigation_map, desired
	)
	return candidate if candidate.distance_squared_to(desired) <= 3.0 * 3.0 else fallback


func _reset_activity_timer() -> void:
	var low := minf(activity_cycle_min_seconds, activity_cycle_max_seconds)
	var high := maxf(activity_cycle_min_seconds, activity_cycle_max_seconds)
	_activity_time_remaining = _random.randf_range(low, high)


func _is_building_collider(collider: Object) -> bool:
	var node := collider as Node
	while node != null:
		if node.name == &"Buildings" or String(node.name).contains("Building"):
			return true
		node = node.get_parent()
	return false


func _get_member_world_yaw(index: int) -> float:
	return (
		global_rotation.y
		+ deg_to_rad(_array_float(member_rotations_degrees, index, 0.0))
	)


func _yaw_toward(from: Vector3, to: Vector3) -> float:
	var direction := to - from
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return 0.0
	return atan2(direction.x, direction.z)


func _show_feedback(message: String, duration := 2.5) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	if player == null:
		return
	var hud := player.get_node_or_null("PlayerHUD") as PlayerHUD
	if hud != null:
		hud.show_feedback(message, duration)


func _territory_display_name() -> String:
	return String(territory_id).replace("_", " ").capitalize()


func _get_day_index() -> int:
	return _world_time.get_absolute_minute() / WorldTimeComponent.MINUTES_PER_DAY if _world_time != null else 0


func _get_member_position(index: int) -> Vector3:
	return member_positions[index] if index < member_positions.size() else Vector3(float(index) * 1.5, 0.0, 0.0)


func _array_int(values: PackedInt32Array, index: int, fallback: int) -> int:
	return values[index] if index < values.size() else fallback


func _array_float(values: PackedFloat32Array, index: int, fallback: float) -> float:
	return values[index] if index < values.size() else fallback


func _array_string(values: PackedStringArray, index: int, fallback: String) -> String:
	return values[index] if index < values.size() else fallback


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if zone_id.is_empty():
		warnings.append("Zone ID is required.")
	if member_ids.is_empty():
		warnings.append("At least one stable member ID is required.")
	if required_interactable_index >= member_ids.size():
		warnings.append("Required interactable index is outside the member roster.")
	return warnings
