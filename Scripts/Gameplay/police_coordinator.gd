class_name PoliceCoordinator
extends Node

const PoliceObservationData := preload("res://Scripts/Gameplay/police_observation.gd")

signal phase_changed(previous: int, current: int)
signal aggregate_contact_changed(has_contact: bool)
signal intelligence_updated(world_position: Vector3, revision: int)
signal threat_state_changed(previous: int, current: int)

enum WantedPhase { CLEAR, INVESTIGATING, OBSERVED, SEARCHING, EVADING, SURRENDERING }
enum ThreatState { NONE, ARMED, ACTIVE_LETHAL, COMPLIANT }

const CONTACT_HEARTBEAT_GRACE := 0.3
const COMPLIANCE_SECONDS := 1.25
const COMPLIANCE_SPEED := 0.6

var phase := WantedPhase.CLEAR
var threat_state := ThreatState.NONE
var last_known_position := Vector3.ZERO
var last_known_velocity := Vector3.ZERO
var intelligence_revision := 0
var uncertainty_radius := 2.0
var has_intelligence := false

var _player: CharacterBody3D
var _wanted: PlayerWantedComponent
var _weapon: PlayerWeaponComponent
var _visual_heartbeats := {}
var _officer_search_roles := {}
var _next_search_role_index := 0
var _investigation_remaining := 0.0
var _compliance_elapsed := 0.0


func _ready() -> void:
	add_to_group(&"police_coordinator")
	call_deferred(&"_initialize")


func _initialize() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	if _player == null:
		return
	_wanted = _player.get_node_or_null("Components/WantedComponent") as PlayerWantedComponent
	_weapon = _player.get_node_or_null("Components/WeaponComponent") as PlayerWeaponComponent
	if _wanted != null:
		_wanted.wanted_level_changed.connect(_on_wanted_level_changed)
		_wanted.escape_progress_changed.connect(_on_escape_progress_changed)
		_wanted.incident_updated.connect(_on_incident_updated)
		_wanted.incident_reported.connect(_on_incident_updated)
		_on_wanted_level_changed(0, _wanted.wanted_level)


func _process(delta: float) -> void:
	_expire_visual_heartbeats(delta)
	_investigation_remaining = maxf(_investigation_remaining - delta, 0.0)
	_update_compliance(delta)
	_update_phase()
	if has_intelligence and not has_confirmed_visual_contact():
		uncertainty_radius = minf(uncertainty_radius + delta * 1.5, 60.0)


func submit_observation(observation) -> void:
	if observation == null or not observation.world_position.is_finite():
		return
	match observation.kind:
		PoliceObservationData.Kind.VISUAL:
			var had_contact := has_confirmed_visual_contact()
			_visual_heartbeats[observation.reporter_id] = CONTACT_HEARTBEAT_GRACE
			if not had_contact:
				aggregate_contact_changed.emit(true)
			last_known_position = observation.world_position
			last_known_velocity = observation.velocity
			uncertainty_radius = 2.0
			has_intelligence = true
			intelligence_revision += 1
			intelligence_updated.emit(last_known_position, intelligence_revision)
			if _wanted != null and _wanted.wanted_level > 0:
				_wanted.report_police_visual_contact(last_known_position)
		PoliceObservationData.Kind.SOUND:
			_investigation_remaining = maxf(_investigation_remaining, 30.0)
			if not has_intelligence or (_wanted != null and _wanted.wanted_level <= 0):
				last_known_position = observation.world_position
				last_known_velocity = Vector3.ZERO
				uncertainty_radius = lerpf(16.0, 6.0, observation.confidence)
				has_intelligence = true
				intelligence_revision += 1
				intelligence_updated.emit(last_known_position, intelligence_revision)
		_:
			_investigation_remaining = maxf(_investigation_remaining, 30.0)
			last_known_position = observation.world_position
			last_known_velocity = observation.velocity
			uncertainty_radius = lerpf(12.0, 3.0, observation.confidence)
			has_intelligence = true
			intelligence_revision += 1
			intelligence_updated.emit(last_known_position, intelligence_revision)
	_update_phase()


func report_visual_contact(observer: Node, world_position: Vector3) -> void:
	var observed_velocity := _player.velocity if _player != null else Vector3.ZERO
	submit_observation(PoliceObservationData.create(
		PoliceObservationData.Kind.VISUAL, world_position, observer, _player,
		1.0, observed_velocity
	))


func report_sound(reporter: Node, world_position: Vector3, confidence := 0.75, event_id := 0) -> void:
	submit_observation(PoliceObservationData.create(
		PoliceObservationData.Kind.SOUND, world_position, reporter, null,
		confidence, Vector3.ZERO, event_id
	))


func has_confirmed_visual_contact() -> bool:
	return not _visual_heartbeats.is_empty()


func has_actionable_intelligence() -> bool:
	return has_intelligence and (
		_investigation_remaining > 0.0
		or (_wanted != null and _wanted.wanted_level > 0)
	)


func get_search_assignment(officer_id: int) -> Dictionary:
	var role := StringName(_officer_search_roles.get(officer_id, &""))
	if role.is_empty():
		if _next_search_role_index == 0:
			role = &"tracker"
		else:
			var support_roles := [&"left_sweeper", &"right_sweeper", &"cutoff"]
			role = support_roles[(_next_search_role_index - 1) % support_roles.size()]
		_officer_search_roles[officer_id] = role
		_next_search_role_index += 1
	var angle := 0.0
	match role:
		&"left_sweeper": angle = PI * 0.55
		&"right_sweeper": angle = -PI * 0.55
		&"cutoff": angle = PI
	var radius := 0.0 if role == &"tracker" else maxf(uncertainty_radius * 0.65, 4.0)
	return {
		"role": role,
		"center": last_known_position,
		"destination": last_known_position + Vector3(cos(angle), 0.0, sin(angle)) * radius,
		"revision": intelligence_revision,
	}


func note_active_lethal_threat() -> void:
	_set_threat_state(ThreatState.ACTIVE_LETHAL)
	_compliance_elapsed = 0.0


func clear_active_lethal_threat() -> void:
	if threat_state != ThreatState.ACTIVE_LETHAL:
		return
	var armed := _weapon != null and _weapon.get_equipped_weapon() != null
	_set_threat_state(ThreatState.ARMED if armed else ThreatState.NONE)


func is_force_authorized() -> bool:
	return threat_state == ThreatState.ACTIVE_LETHAL


func is_player_compliant() -> bool:
	return threat_state == ThreatState.COMPLIANT


func clear_runtime_intelligence() -> void:
	_visual_heartbeats.clear()
	_officer_search_roles.clear()
	_next_search_role_index = 0
	_investigation_remaining = 0.0
	has_intelligence = false
	last_known_position = Vector3.ZERO
	last_known_velocity = Vector3.ZERO
	uncertainty_radius = 2.0
	intelligence_revision += 1
	_set_threat_state(ThreatState.NONE)
	_update_phase()


func _expire_visual_heartbeats(delta: float) -> void:
	var had_contact := has_confirmed_visual_contact()
	for observer_id in _visual_heartbeats.keys():
		var remaining := float(_visual_heartbeats[observer_id]) - delta
		if remaining <= 0.0:
			_visual_heartbeats.erase(observer_id)
		else:
			_visual_heartbeats[observer_id] = remaining
	var has_contact := has_confirmed_visual_contact()
	if had_contact != has_contact:
		aggregate_contact_changed.emit(has_contact)


func _update_compliance(delta: float) -> void:
	if _player == null or _wanted == null or _wanted.wanted_level <= 0:
		_compliance_elapsed = 0.0
		_set_threat_state(ThreatState.NONE)
		return
	var armed := _weapon != null and _weapon.get_equipped_weapon() != null
	var moving := _player.velocity.length() > COMPLIANCE_SPEED
	if not armed and not moving and has_confirmed_visual_contact():
		_compliance_elapsed += delta
		if _compliance_elapsed >= COMPLIANCE_SECONDS:
			_set_threat_state(ThreatState.COMPLIANT)
		return
	_compliance_elapsed = 0.0
	if threat_state != ThreatState.ACTIVE_LETHAL:
		_set_threat_state(ThreatState.ARMED if armed else ThreatState.NONE)


func _update_phase() -> void:
	var next_phase := WantedPhase.CLEAR
	if _wanted != null and _wanted.wanted_level > 0:
		if threat_state == ThreatState.COMPLIANT:
			next_phase = WantedPhase.SURRENDERING
		elif has_confirmed_visual_contact():
			next_phase = WantedPhase.OBSERVED
		elif _wanted.is_escaping:
			next_phase = WantedPhase.EVADING
		else:
			next_phase = WantedPhase.SEARCHING
	elif _investigation_remaining > 0.0:
		next_phase = WantedPhase.INVESTIGATING
	_set_phase(next_phase)


func _set_phase(next_phase: int) -> void:
	if next_phase == phase:
		return
	var previous := phase
	phase = next_phase
	phase_changed.emit(previous, phase)


func _set_threat_state(next_state: int) -> void:
	if next_state == threat_state:
		return
	var previous := threat_state
	threat_state = next_state
	threat_state_changed.emit(previous, threat_state)


func _on_wanted_level_changed(_previous: int, current: int) -> void:
	if current <= 0:
		# Anonymous observations may continue after an incident is resolved, but
		# combat authorization and visual suspect contact must never leak into the
		# next wanted event.
		var had_contact := has_confirmed_visual_contact()
		_visual_heartbeats.clear()
		if had_contact:
			aggregate_contact_changed.emit(false)
		_officer_search_roles.clear()
		_next_search_role_index = 0
		_compliance_elapsed = 0.0
		_set_threat_state(ThreatState.NONE)
		if _investigation_remaining <= 0.0:
			clear_runtime_intelligence()
	_update_phase()


func _on_escape_progress_changed(_progress: float, _escaping: bool) -> void:
	_update_phase()


func _on_incident_updated(incident) -> void:
	if incident == null:
		return
	if bool(incident.force_authorized):
		note_active_lethal_threat()
	last_known_position = incident.last_known_player_position
	last_known_velocity = incident.last_known_velocity
	uncertainty_radius = incident.uncertainty_radius
	has_intelligence = true
	intelligence_revision = maxi(intelligence_revision + 1, incident.revision)
	intelligence_updated.emit(last_known_position, intelligence_revision)
