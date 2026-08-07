class_name PlayerWantedComponent
extends Node

const PoliceIncidentData := preload("res://Scripts/Gameplay/police_incident.gd")

signal wanted_level_changed(previous: int, current: int)
signal wanted_cleared
signal escape_progress_changed(progress: float, escaping: bool)
signal police_search_updated(world_position: Vector3, revision: int)
signal incident_reported(incident)
signal incident_updated(incident)
signal incident_resolved(incident_id: int)
signal force_authorization_changed(authorized: bool)

const MAX_WANTED_LEVEL := 3

@export var player_path := NodePath("../..")
@export var weapon_component_path := NodePath("../WeaponComponent")
@export var health_component_path := NodePath("../HealthComponent")
@export_range(0.0, 100.0, 0.5) var visible_weapon_heat_per_second := 25.0
@export_range(0.0, 100.0, 1.0) var witnessed_sale_heat := 50.0
@export_range(0.0, 100.0, 1.0) var witnessed_solicitation_heat := 25.0
@export_range(0.0, 100.0, 1.0) var arrest_heat_reset := 25.0
@export_range(0.05, 1.0, 0.05) var witness_heartbeat_grace := 0.3
@export_range(1.0, 30.0, 0.5) var escape_seconds_per_star := 8.0
@export_range(0.05, 1.0, 0.05) var visual_contact_grace := 0.3
@export_range(0.5, 10.0, 0.5) var dispatch_update_distance := 2.5
@export_range(5.0, 100.0, 1.0) var search_area_radius := 35.0
@export_range(0.0, 10.0, 0.25) var escape_exit_grace := 2.0
@export_range(0.001, 0.25, 0.005) var intelligence_confidence_decay := 0.035
@export_range(0.0, 10.0, 0.25) var intelligence_uncertainty_growth := 1.5
@export_category("Performance")
@export_range(0.05, 2.0, 0.05) var territory_query_interval := 0.25
@export_range(0.25, 10.0, 0.25) var territory_query_movement_threshold := 2.0

@onready var player := get_node(player_path) as CharacterBody3D
@onready var weapon_component := (
	get_node(weapon_component_path) as PlayerWeaponComponent
)
@onready var health_component := (
	get_node(health_component_path) as PlayerHealthComponent
)

var wanted_level: int:
	get:
		return _wanted_level

var escape_progress: float:
	get:
		return _escape_progress

var is_escaping: bool:
	get:
		return _is_escaping

var police_search_position: Vector3:
	get:
		return _police_search_position

var police_search_revision: int:
	get:
		return _police_search_revision

var has_police_search_position: bool:
	get:
		return _has_police_search_position

var active_incident:
	get:
		return _active_incident

var is_force_authorized: bool:
	get:
		return (
			_wanted_level >= 3
			or (_active_incident != null and _active_incident.force_authorized)
		)

var _wanted_level := 0
var _trigger_territory_id := &""
var _weapon_witness_remaining := 0.0
var _visual_contact_remaining := 0.0
var _escape_progress := 1.0
var _is_escaping := false
var _police_search_position := Vector3.ZERO
var _police_search_revision := 0
var _has_police_search_position := false
var _gang_war_suppressed := false
var _suspended_wanted_level := 0
var _suspended_trigger_territory_id := &""
var _active_incident
var _next_incident_id := 1
var _outside_search_elapsed := 0.0
var _loaded_without_incident := false
var _suspended_incident_data := {}
var _importing_save_data := false
var _last_visual_position := Vector3.ZERO
var _last_visual_time := 0.0
var _cached_player_boundary: TerritoryBoundary
var _territory_query_remaining := 0.0
var _territory_query_position := Vector3.INF


func _ready() -> void:
	weapon_component.shot_resolved.connect(_on_player_shot_resolved)
	health_component.downed.connect(_on_player_downed)
	health_component.respawn_completed.connect(_on_respawn_completed)
	for node in get_tree().get_nodes_in_group("territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if (
			boundary != null
			and boundary.stats != null
		):
			boundary.stats.heat_changed.connect(
				_on_territory_heat_changed.bind(boundary)
			)
	set_process(true)


func _process(delta: float) -> void:
	_update_intelligence_age(delta)
	_weapon_witness_remaining = maxf(
		_weapon_witness_remaining - delta,
		0.0
	)
	_visual_contact_remaining = maxf(
		_visual_contact_remaining - delta,
		0.0
	)
	_update_escape(delta)
	if _gang_war_suppressed:
		return
	if _weapon_witness_remaining > 0.0 and _wanted_level == 0:
		add_suspicion_heat(
			player.global_position,
			visible_weapon_heat_per_second * delta
		)
	if _wanted_level == 0:
		var boundary := _get_cached_player_boundary(delta)
		if (
			boundary != null
			and boundary.stats != null
			and boundary.stats.heat >= 100.0
		):
			_trigger_territory_id = boundary.territory_id
			set_wanted_level(1)


func _get_cached_player_boundary(delta: float) -> TerritoryBoundary:
	_territory_query_remaining = maxf(
		_territory_query_remaining - delta,
		0.0
	)
	var moved_far_enough := (
		not _territory_query_position.is_finite()
		or _territory_query_position.distance_squared_to(player.global_position)
		>= territory_query_movement_threshold * territory_query_movement_threshold
	)
	if (
		not is_zero_approx(_territory_query_remaining)
		and not moved_far_enough
		and (
			_cached_player_boundary == null
			or is_instance_valid(_cached_player_boundary)
		)
	):
		return _cached_player_boundary
	_cached_player_boundary = TerritoryBoundary.find_at_position(
		get_tree(),
		player.global_position
	)
	_territory_query_position = player.global_position
	_territory_query_remaining = territory_query_interval
	return _cached_player_boundary


func report_visible_weapon_witness() -> void:
	if _gang_war_suppressed:
		return
	if weapon_component.get_equipped_weapon() == null:
		return
	_weapon_witness_remaining = witness_heartbeat_grace


func report_police_visual_contact(
	world_position: Vector3 = Vector3.INF
) -> void:
	if _gang_war_suppressed:
		return
	if _wanted_level <= 0:
		return
	_visual_contact_remaining = visual_contact_grace
	_set_escape_state(1.0, false)
	_outside_search_elapsed = 0.0
	if world_position.is_finite():
		_update_active_incident_last_known(world_position)


func report_police_incident(
	world_position: Vector3,
	crime_type: int = PoliceIncidentData.CrimeType.UNKNOWN,
	severity := 1
) -> void:
	if _gang_war_suppressed:
		return
	if not world_position.is_finite():
		return
	var boundary := TerritoryBoundary.find_at_position(get_tree(), world_position)
	var territory_id := boundary.territory_id if boundary != null else &""
	var absolute_minute := 0
	var world_time := get_tree().get_first_node_in_group(&"world_time") as WorldTimeComponent
	if world_time != null:
		absolute_minute = world_time.get_absolute_minute()
	if _active_incident == null:
		_active_incident = PoliceIncidentData.new()
		_active_incident.incident_id = _next_incident_id
		_next_incident_id += 1
		_active_incident.crime_type = crime_type
		_active_incident.severity = clampi(severity, 1, 3)
		_active_incident.position = world_position
		_active_incident.territory_id = territory_id
		_active_incident.reported_at_minute = absolute_minute
		_active_incident.last_known_player_position = world_position
		_active_incident.last_known_velocity = Vector3.ZERO
		_active_incident.observed_at_seconds = Time.get_ticks_msec() * 0.001
		_active_incident.confidence = 1.0
		_active_incident.uncertainty_radius = 2.0
		_active_incident.suspect_known = true
		_last_visual_position = world_position
		_last_visual_time = _active_incident.observed_at_seconds
		_active_incident.revision = 1
		_update_police_search_position(world_position, true)
		_outside_search_elapsed = 0.0
		incident_reported.emit(_active_incident)
		_record_low_level_charge(crime_type)
		return
	var next_severity := clampi(severity, 1, 3)
	if next_severity >= _active_incident.severity:
		_active_incident.crime_type = crime_type
	_active_incident.severity = maxi(_active_incident.severity, next_severity)
	_active_incident.last_known_player_position = world_position
	_active_incident.suspect_known = true
	if territory_id != &"":
		_active_incident.territory_id = territory_id
	_active_incident.revision += 1
	_update_police_search_position(world_position, true)
	_outside_search_elapsed = 0.0
	incident_updated.emit(_active_incident)
	_record_low_level_charge(crime_type)


func report_sale(world_position: Vector3) -> void:
	if _gang_war_suppressed:
		return
	if _has_police_witness(world_position):
		report_police_incident(
			world_position,
			PoliceIncidentData.CrimeType.ILLEGAL_ACTIVITY,
			1
		)
		add_suspicion_heat(world_position, witnessed_sale_heat)


func report_solicitation(
	world_position: Vector3,
	solicitation_radius: float
) -> void:
	if _gang_war_suppressed:
		return
	if _has_police_in_radius(world_position, solicitation_radius):
		report_police_incident(
			world_position,
			PoliceIncidentData.CrimeType.ILLEGAL_ACTIVITY,
			1
		)
		add_suspicion_heat(
			world_position,
			witnessed_solicitation_heat
		)


func add_suspicion_heat(world_position: Vector3, amount: float) -> void:
	if _gang_war_suppressed or amount <= 0.0:
		return
	var boundary := TerritoryBoundary.find_at_position(
		get_tree(),
		world_position
	)
	if boundary == null or boundary.stats == null:
		return
	_trigger_territory_id = boundary.territory_id
	boundary.stats.add_heat(amount)
	if boundary.stats.heat >= 100.0:
		set_wanted_level(1)


func report_violence(target: Node, fatal: bool) -> void:
	if _gang_war_suppressed or target == null:
		return
	var was_wanted := _wanted_level > 0
	var next_level := 3 if fatal else 2
	var boundary := TerritoryBoundary.find_at_position(
		get_tree(),
		player.global_position
	)
	if boundary != null:
		_trigger_territory_id = boundary.territory_id
	var crime_type := (
		PoliceIncidentData.CrimeType.OFFICER_DOWN
		if fatal and target is PoliceNPC
		else PoliceIncidentData.CrimeType.HOMICIDE
		if fatal
		else PoliceIncidentData.CrimeType.ASSAULT
	)
	report_police_incident(player.global_position, crime_type, next_level)
	var victim_key := str(target.get_instance_id())
	match crime_type:
		PoliceIncidentData.CrimeType.ASSAULT:
			_active_incident.record_charge(
				&"assault", "Assault", 250, "assault:%s" % victim_key
			)
		PoliceIncidentData.CrimeType.HOMICIDE:
			_active_incident.record_charge(
				&"homicide", "Homicide", 500, "homicide:%s" % victim_key
			)
		PoliceIncidentData.CrimeType.OFFICER_DOWN:
			_active_incident.record_charge(
				&"officer_down", "Officer Down", 750, "officer:%s" % victim_key
			)
	set_wanted_level(maxi(_wanted_level, next_level))
	if fatal or target is PoliceNPC or was_wanted:
		set_force_authorized(true)


func set_wanted_level(level: int) -> void:
	var next_level := clampi(level, 0, MAX_WANTED_LEVEL)
	if _gang_war_suppressed and next_level > _wanted_level:
		return
	if next_level == _wanted_level:
		return
	var previous: int = _wanted_level
	_wanted_level = next_level
	if _wanted_level > previous:
		if not _has_police_search_position and not _importing_save_data:
			report_police_incident(
				player.global_position,
				PoliceIncidentData.CrimeType.SUSPICIOUS_ACTIVITY,
				maxi(_wanted_level, 1)
			)
		_visual_contact_remaining = 0.0
		_set_escape_state(1.0, false)
		if _wanted_level >= 3:
			set_force_authorized(true)
	elif _wanted_level == 0:
		_set_escape_state(1.0, false)
	wanted_level_changed.emit(previous, _wanted_level)
	if _wanted_level == 0:
		wanted_cleared.emit()


func resolve_arrest() -> void:
	clear_wanted(true)


func clear_wanted(cool_territory := true) -> void:
	if cool_territory:
		var boundary := _find_trigger_territory()
		if boundary != null and boundary.stats != null:
			boundary.stats.set_heat(arrest_heat_reset)
	set_wanted_level(0)
	_weapon_witness_remaining = 0.0
	_visual_contact_remaining = 0.0
	_set_escape_state(1.0, false)
	_clear_police_search()
	_resolve_active_incident()
	force_authorization_changed.emit(false)


func can_attempt_arrest() -> bool:
	return _wanted_level in [1, 2] and not is_force_authorized


func set_force_authorized(authorized: bool) -> void:
	if _active_incident == null:
		return
	var previous: bool = bool(_active_incident.force_authorized)
	_active_incident.force_authorized = authorized or _wanted_level >= 3
	if previous == _active_incident.force_authorized:
		return
	_active_incident.revision += 1
	force_authorization_changed.emit(_active_incident.force_authorized)
	incident_updated.emit(_active_incident)


func set_gang_war_suppressed(active: bool) -> void:
	if active == _gang_war_suppressed:
		return
	if active:
		_suspended_wanted_level = _wanted_level
		_suspended_trigger_territory_id = _trigger_territory_id
		_suspended_incident_data = (
			_active_incident.to_dictionary()
			if _active_incident != null else {}
		)
		_gang_war_suppressed = true
		clear_wanted(false)
		return
	_gang_war_suppressed = false
	_trigger_territory_id = _suspended_trigger_territory_id
	var restore_level := _suspended_wanted_level
	_suspended_wanted_level = 0
	_suspended_trigger_territory_id = &""
	if restore_level > 0:
		_active_incident = PoliceIncidentData.from_dictionary(_suspended_incident_data)
		_suspended_incident_data = {}
		if _active_incident != null:
			_update_police_search_position(
				_active_incident.last_known_player_position,
				true
			)
		set_wanted_level(restore_level)
		if _active_incident != null:
			incident_reported.emit(_active_incident)


func is_gang_war_suppressed() -> bool:
	return _gang_war_suppressed


func export_save_data() -> Dictionary:
	return {
		"wanted_level": _wanted_level,
		"trigger_territory_id": String(_trigger_territory_id),
		"gang_war_suppressed": _gang_war_suppressed,
		"suspended_wanted_level": _suspended_wanted_level,
		"suspended_trigger_territory_id": String(
			_suspended_trigger_territory_id
		),
		"active_incident": (
			_active_incident.to_dictionary()
			if _active_incident != null else {}
		),
		"next_incident_id": _next_incident_id,
		"suspended_incident": _suspended_incident_data.duplicate(true),
	}


func import_save_data(data: Dictionary) -> void:
	_importing_save_data = true
	_gang_war_suppressed = bool(data.get("gang_war_suppressed", false))
	_suspended_wanted_level = clampi(
		int(data.get("suspended_wanted_level", 0)), 0, MAX_WANTED_LEVEL
	)
	_suspended_trigger_territory_id = StringName(str(
		data.get("suspended_trigger_territory_id", "")
	))
	_trigger_territory_id = StringName(
		str(data.get("trigger_territory_id", ""))
	)
	_active_incident = PoliceIncidentData.from_dictionary(
		data.get("active_incident", {}) as Dictionary
	)
	_next_incident_id = maxi(int(data.get("next_incident_id", 1)), 1)
	_suspended_incident_data = (
		data.get("suspended_incident", {}) as Dictionary
	).duplicate(true)
	_loaded_without_incident = (
		int(data.get("wanted_level", 0)) > 0 and _active_incident == null
	)
	if _active_incident != null:
		_update_police_search_position(
			_active_incident.last_known_player_position,
			true
		)
	set_wanted_level(int(data.get("wanted_level", 0)))
	_importing_save_data = false


func rehydrate_incident_after_load() -> void:
	if _wanted_level <= 0:
		return
	if _loaded_without_incident or _active_incident == null:
		_active_incident = null
		report_police_incident(
			player.global_position,
			PoliceIncidentData.CrimeType.UNKNOWN,
			_wanted_level
		)
		_loaded_without_incident = false
	elif _active_incident != null:
		incident_reported.emit(_active_incident)


func _record_low_level_charge(crime_type: int) -> void:
	if _active_incident == null:
		return
	match crime_type:
		PoliceIncidentData.CrimeType.UNKNOWN, PoliceIncidentData.CrimeType.SUSPICIOUS_ACTIVITY:
			_active_incident.record_charge(
				&"evading", "Evading / Suspicious Activity", 50
			)
		PoliceIncidentData.CrimeType.ILLEGAL_ACTIVITY:
			_active_incident.record_charge(&"illegal_sale", "Illegal Sale", 50)
		PoliceIncidentData.CrimeType.WEAPON_DISCHARGE:
			_active_incident.record_charge(
				&"weapon_discharge", "Weapon Discharge", 100
			)


func _on_player_shot_resolved(
	target: Node,
	fatal: bool,
	_hit_position: Vector3
) -> void:
	if _gang_war_suppressed:
		return
	var was_wanted := _wanted_level > 0
	if target != null:
		report_violence(target, fatal)
		if was_wanted:
			set_force_authorized(true)
		return
	# A sound establishes an event location, not the shooter's identity. Police
	# and civilian witnesses submit evidence separately through WorldEventBus.


func _has_police_witness(world_position: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group("police_npc"):
		if (
			node.has_method("can_witness_position")
			and bool(node.call("can_witness_position", world_position))
		):
			return true
	return false


func _has_police_hearing(world_position: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group("police_npc"):
		if (
			node.has_method("can_hear_position")
			and bool(node.call("can_hear_position", world_position))
		):
			return true
	return false


func _has_police_in_radius(
	world_position: Vector3,
	radius: float
) -> bool:
	var radius_squared := maxf(radius, 0.0) * maxf(radius, 0.0)
	for node in get_tree().get_nodes_in_group("police_npc"):
		var police := node as PoliceNPC
		if (
			police != null
			and police.is_pool_active()
			and not police.is_defeated()
			and police.global_position.distance_squared_to(world_position)
			<= radius_squared
		):
			return true
	return false


func _find_trigger_territory() -> TerritoryBoundary:
	for node in get_tree().get_nodes_in_group("territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if boundary != null and boundary.territory_id == _trigger_territory_id:
			return boundary
	return null


func _update_escape(delta: float) -> void:
	if _wanted_level <= 0:
		_outside_search_elapsed = 0.0
		_set_escape_state(1.0, false)
		return
	if _visual_contact_remaining > 0.0:
		_outside_search_elapsed = 0.0
		_set_escape_state(1.0, false)
		return
	if _active_incident != null:
		var search_center: Vector3 = _active_incident.last_known_player_position
		var inside_search_area := (
			player.global_position.distance_squared_to(search_center)
			<= search_area_radius * search_area_radius
		)
		if inside_search_area:
			_outside_search_elapsed = 0.0
			_set_escape_state(1.0, false)
			return
		_outside_search_elapsed += delta
		if _outside_search_elapsed < escape_exit_grace:
			_set_escape_state(1.0, false)
			return
	var next_progress := maxf(
		_escape_progress
		- delta / maxf(escape_seconds_per_star, 0.01),
		0.0
	)
	_set_escape_state(next_progress, true)
	if next_progress > 0.0:
		return
	var next_level := _wanted_level - 1
	if next_level <= 0:
		clear_wanted(true)
		return
	set_wanted_level(next_level)
	_set_escape_state(1.0, true)


func _set_escape_state(progress: float, escaping: bool) -> void:
	var next_progress := clampf(progress, 0.0, 1.0)
	if (
		is_equal_approx(next_progress, _escape_progress)
		and escaping == _is_escaping
	):
		return
	_escape_progress = next_progress
	_is_escaping = escaping
	escape_progress_changed.emit(_escape_progress, _is_escaping)


func _update_police_search_position(
	world_position: Vector3,
	force := false
) -> void:
	if not world_position.is_finite():
		return
	var update_distance_squared := (
		dispatch_update_distance * dispatch_update_distance
	)
	if (
		not force
		and _has_police_search_position
		and _police_search_position.distance_squared_to(world_position)
		< update_distance_squared
	):
		return
	_police_search_position = world_position
	_has_police_search_position = true
	_police_search_revision += 1
	police_search_updated.emit(
		_police_search_position,
		_police_search_revision
	)


func _update_active_incident_last_known(world_position: Vector3) -> void:
	if not world_position.is_finite():
		return
	if _active_incident == null:
		report_police_incident(
			world_position,
			PoliceIncidentData.CrimeType.UNKNOWN,
			maxi(_wanted_level, 1)
		)
		return
	if (
		_active_incident.last_known_player_position.distance_squared_to(world_position)
		< dispatch_update_distance * dispatch_update_distance
	):
		return
	_active_incident.last_known_player_position = world_position
	var now := Time.get_ticks_msec() * 0.001
	var elapsed := now - _last_visual_time
	if elapsed > 0.001:
		_active_incident.last_known_velocity = (
			world_position - _last_visual_position
		) / elapsed
	_active_incident.observed_at_seconds = now
	_active_incident.confidence = 1.0
	_active_incident.uncertainty_radius = 2.0
	_active_incident.suspect_known = true
	_last_visual_position = world_position
	_last_visual_time = now
	var boundary := TerritoryBoundary.find_at_position(get_tree(), world_position)
	if boundary != null:
		_active_incident.territory_id = boundary.territory_id
	_active_incident.revision += 1
	_update_police_search_position(world_position, true)
	incident_updated.emit(_active_incident)


func _update_intelligence_age(delta: float) -> void:
	if _active_incident == null or _visual_contact_remaining > 0.0:
		return
	_active_incident.confidence = maxf(
		_active_incident.confidence - intelligence_confidence_decay * delta,
		0.0
	)
	_active_incident.uncertainty_radius = minf(
		_active_incident.uncertainty_radius + intelligence_uncertainty_growth * delta,
		search_area_radius
	)


func _resolve_active_incident() -> void:
	if _active_incident == null:
		return
	var resolved_id: int = _active_incident.incident_id
	_active_incident = null
	_outside_search_elapsed = 0.0
	incident_resolved.emit(resolved_id)


func _clear_police_search() -> void:
	if not _has_police_search_position:
		return
	_has_police_search_position = false
	_police_search_position = Vector3.ZERO
	_police_search_revision += 1


func _on_respawn_completed() -> void:
	if _wanted_level > 0:
		clear_wanted(true)


func _on_player_downed() -> void:
	if _wanted_level > 0:
		clear_wanted(true)


func _on_territory_heat_changed(
	current: float,
	boundary: TerritoryBoundary
) -> void:
	if _gang_war_suppressed or current < 100.0 or _wanted_level > 0:
		return
	_trigger_territory_id = boundary.territory_id
	set_wanted_level(1)
