class_name EvidenceService
extends Node

const PoliceObservationData := preload("res://Scripts/Gameplay/police_observation.gd")

signal report_accepted(report: CrimeReport)
signal report_rejected(report: CrimeReport, reason: StringName)

var _event_bus: WorldEventBus
var _wanted: PlayerWantedComponent
var _coordinator: Node
var _processed_event_ids := {}


func _ready() -> void:
	add_to_group(&"evidence_service")
	call_deferred(&"_initialize")


func _initialize() -> void:
	_event_bus = WorldEventBus.find(get_tree())
	var player := get_tree().get_first_node_in_group(&"player")
	if player != null:
		_wanted = player.get_node_or_null("Components/WantedComponent") as PlayerWantedComponent
	_coordinator = get_tree().get_first_node_in_group(&"police_coordinator")
	if _event_bus != null and not _event_bus.crime_report_submitted.is_connected(_on_crime_report_submitted):
		_event_bus.crime_report_submitted.connect(_on_crime_report_submitted)


func _on_crime_report_submitted(report: CrimeReport) -> void:
	if report == null or not report.completed or report.interrupted:
		report_rejected.emit(report, &"incomplete")
		return
	if _wanted == null or not report.has_identified_suspect():
		report_rejected.emit(report, &"unknown_suspect")
		return
	if not _is_player_actor(report.suspect):
		report_rejected.emit(report, &"non_player_suspect")
		return
	if report.event_id > 0 and _processed_event_ids.has(report.event_id):
		report_rejected.emit(report, &"duplicate_event")
		return
	if report.event_id > 0:
		_processed_event_ids[report.event_id] = true
	var crime_floor := _get_crime_floor(report.crime_type)
	var next_level := maxi(_wanted.wanted_level, crime_floor)
	var duplicate_active_incident := false
	var current_incident := _wanted.active_incident as PoliceIncident
	if current_incident != null:
		duplicate_active_incident = (
			current_incident.crime_type == report.crime_type
			and current_incident.last_known_player_position.distance_to(
				report.observation_position
			) <= 2.0
			and (
				Time.get_ticks_msec() * 0.001
				- current_incident.observed_at_seconds
			) <= 2.0
		)
	if (
		not duplicate_active_incident
		and _wanted.wanted_level >= crime_floor
		and report.crime_type in [
			PoliceIncident.CrimeType.ASSAULT,
			PoliceIncident.CrimeType.HOMICIDE,
			PoliceIncident.CrimeType.OFFICER_DOWN,
			PoliceIncident.CrimeType.WEAPON_DISCHARGE,
		]
	):
		next_level = mini(
			_wanted.wanted_level + 1,
			PlayerWantedComponent.MAX_WANTED_LEVEL
		)
	_wanted.report_police_incident(
		report.observation_position,
		report.crime_type,
		next_level
	)
	_wanted.set_wanted_level(next_level)
	if report.crime_type in [
		PoliceIncident.CrimeType.HOMICIDE,
		PoliceIncident.CrimeType.OFFICER_DOWN,
	]:
		_wanted.set_force_authorized(true)
	if _coordinator != null:
		_coordinator.submit_observation(PoliceObservationData.create(
			PoliceObservationData.Kind.CIVILIAN_REPORT,
			report.observation_position,
			report.reporter,
			report.suspect,
			report.confidence
		))
	report_accepted.emit(report)


func _get_crime_floor(crime_type: int) -> int:
	match crime_type:
		PoliceIncident.CrimeType.OFFICER_DOWN:
			return 5
		PoliceIncident.CrimeType.HOMICIDE:
			return 4
		PoliceIncident.CrimeType.ASSAULT, PoliceIncident.CrimeType.WEAPON_DISCHARGE:
			return 2
		_:
			return 1


func _is_player_actor(actor: Node) -> bool:
	var current := actor
	while current != null:
		if current.is_in_group(&"player"):
			return true
		current = current.get_parent()
	return false
