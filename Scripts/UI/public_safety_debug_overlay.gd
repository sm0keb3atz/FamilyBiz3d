class_name PublicSafetyDebugOverlay
extends CanvasLayer

const PoliceCoordinatorData := preload("res://Scripts/Gameplay/police_coordinator.gd")

@export var toggle_key := KEY_F7

var _label: Label
var _visible := false
var _overlay_refresh_remaining := 0.0
var _frame_time_samples: Array[float] = []


func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.position = Vector2(18.0, 80.0)
	_label.add_theme_font_size_override(&"font_size", 15)
	_label.add_theme_color_override(&"font_color", Color(0.92, 0.96, 1.0))
	_label.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_label.add_theme_constant_override(&"shadow_offset_x", 2)
	_label.add_theme_constant_override(&"shadow_offset_y", 2)
	add_child(_label)
	_label.visible = false
	set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == toggle_key:
		_visible = not _visible
		_label.visible = _visible
		set_process(_visible)
		if _visible:
			_frame_time_samples.clear()
			_overlay_refresh_remaining = 0.0
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_frame_time_samples.append(delta * 1000.0)
	if _frame_time_samples.size() > 600:
		_frame_time_samples.pop_front()
	_overlay_refresh_remaining -= delta
	if _overlay_refresh_remaining > 0.0:
		return
	_overlay_refresh_remaining = 0.25
	var lines := PackedStringArray([
		"PUBLIC SAFETY + PERFORMANCE [F7]",
		"FPS=%d frame=%.2fms p99=%.2fms max=%.2fms draw_calls=%d objects=%d"
		% [
			Engine.get_frames_per_second(),
			delta * 1000.0,
			_get_percentile_frame_time(0.99),
			_get_maximum_frame_time(),
			int(Performance.get_monitor(
				Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME
			)),
			int(Performance.get_monitor(
				Performance.RENDER_TOTAL_OBJECTS_IN_FRAME
			)),
		],
	])
	var player := get_tree().get_first_node_in_group(&"player")
	var wanted := (
		player.get_node_or_null("Components/WantedComponent") as PlayerWantedComponent
		if player != null else null
	)
	if wanted != null:
		var incident := wanted.active_incident as PoliceIncident
		lines.append("Wanted %d | force=%s | incident=%s" % [
			wanted.wanted_level,
			wanted.is_force_authorized,
			incident.incident_id if incident != null else "none",
		])
		if incident != null:
			lines.append("Intel conf=%.2f uncertainty=%.1fm rev=%d LKP=%s" % [
				incident.confidence,
				incident.uncertainty_radius,
				incident.revision,
				incident.last_known_player_position,
			])
	var coordinator: Node = get_tree().get_first_node_in_group(&"police_coordinator")
	if coordinator != null:
		lines.append("Coordinator phase=%s threat=%s visual=%s uncertainty=%.1fm" % [
			PoliceCoordinatorData.WantedPhase.keys()[int(coordinator.phase)],
			PoliceCoordinatorData.ThreatState.keys()[int(coordinator.threat_state)],
			coordinator.has_confirmed_visual_contact(),
			float(coordinator.uncertainty_radius),
		])
	var dispatch := get_tree().get_first_node_in_group(&"police_dispatch")
	if dispatch != null and dispatch.has_method("get_response_debug_snapshot"):
		var response := dispatch.call("get_response_debug_snapshot") as Dictionary
		lines.append("Response desired=%d scheduled=%d effective=%d unavailable=%d" % [
			int(response.get("desired", 0)),
			int(response.get("scheduled", 0)),
			int(response.get("effective", 0)),
			int(response.get("unavailable", 0)),
		])
		lines.append("Cruisers=%d fallback=%d states=%s deficit=%.1fs" % [
			int(response.get("cruisers", 0)),
			int(response.get("fallback_officers", 0)),
			response.get("states", []),
			float(response.get("deficit_elapsed", 0.0)),
		])
		for detail in response.get("response_details", []):
			lines.append("Cruiser %s/%s player=%.1fm progress=%.1fs recovery=%d" % [
				detail.get("role", &"lead"),
				detail.get("state", &"unknown"),
				float(detail.get("player_distance", INF)),
				float(detail.get("progress_age", 0.0)),
				int(detail.get("recovery_count", 0)),
			])
			lines.append("  destination=%s failure=%s" % [
				detail.get("destination", Vector3.INF),
				detail.get("failure_reason", &""),
			])
	var active_civilians := 0
	var active_police := 0
	var pooled_civilians := 0
	var population_managers := 0
	var pedestrian_networks := 0
	for node in get_tree().get_nodes_in_group(&"civilian_population_manager"):
		population_managers += 1
		if node.has_method("get_active_count"):
			active_civilians += int(node.call("get_active_count"))
		if node.has_method("get_active_police_count"):
			active_police += int(node.call("get_active_police_count"))
		if node.has_method("get_live_pool_count"):
			pooled_civilians += int(node.call("get_live_pool_count"))
		if node.has_method("get_network_count"):
			pedestrian_networks += int(node.call("get_network_count"))
	lines.append(
		"Population managers=%d networks=%d active=%d pooled=%d police=%d"
		% [
			population_managers,
			pedestrian_networks,
			active_civilians,
			pooled_civilians,
			active_police,
		]
	)
	var bus := WorldEventBus.find(get_tree())
	if bus != null:
		lines.append("Trace records=%d" % bus.get_trace_snapshot().size())
	var nearest := _get_nearest_police(player as Node3D)
	if nearest != null:
		var ai_state := nearest.get_police_ai_debug_state()
		var nav_state := nearest.movement_component.get_navigation_debug_state()
		lines.append("Nearest officer #%d state=%s reason=%s role=%s" % [
			nearest.get_instance_id(),
			ai_state.get("state", ai_state.get("mode", "none")),
			ai_state.get("reason", "none"),
			ai_state.get("search_role", "none"),
		])
		lines.append("AI destination=%s scan=%.2f stall=%.2f repaths=%d" % [
			ai_state.get("destination", Vector3.ZERO),
			float(ai_state.get("scan_remaining", 0.0)),
			float(ai_state.get("stall_elapsed", 0.0)),
			int(ai_state.get("stall_repaths", 0)),
		])
		lines.append("Nav owner=%s reachable=%s stuck=%s attempts=%d target=%s" % [
			nav_state.get("owner", "none"),
			nav_state.get("target_reachable", false),
			nav_state.get("stuck", false),
			int(nav_state.get("stuck_attempts", 0)),
			nav_state.get("target", Vector3.ZERO),
		])
	_label.text = "\n".join(lines)


func _get_percentile_frame_time(percentile: float) -> float:
	if _frame_time_samples.is_empty():
		return 0.0
	var sorted_samples := _frame_time_samples.duplicate()
	sorted_samples.sort()
	var index := clampi(
		ceili(percentile * float(sorted_samples.size())) - 1,
		0,
		sorted_samples.size() - 1
	)
	return sorted_samples[index]


func _get_maximum_frame_time() -> float:
	var result := 0.0
	for sample in _frame_time_samples:
		result = maxf(result, sample)
	return result


func _get_nearest_police(origin: Node3D) -> PoliceNPC:
	if origin == null:
		return null
	var nearest: PoliceNPC
	var best := INF
	for node in get_tree().get_nodes_in_group(&"police_npc"):
		var officer := node as PoliceNPC
		if officer == null or not officer.is_pool_active() or officer.is_defeated():
			continue
		var distance := origin.global_position.distance_squared_to(officer.global_position)
		if distance < best:
			best = distance
			nearest = officer
	return nearest
