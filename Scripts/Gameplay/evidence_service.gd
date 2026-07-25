class_name EvidenceService
extends Node

signal report_accepted(report: CrimeReport)
signal report_rejected(report: CrimeReport, reason: StringName)

var _event_bus: WorldEventBus
var _wanted: PlayerWantedComponent


func _ready() -> void:
	add_to_group(&"evidence_service")
	call_deferred(&"_initialize")


func _initialize() -> void:
	_event_bus = WorldEventBus.find(get_tree())
	var player := get_tree().get_first_node_in_group(&"player")
	if player != null:
		_wanted = player.get_node_or_null("Components/WantedComponent") as PlayerWantedComponent
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
	_wanted.report_police_incident(
		report.observation_position,
		report.crime_type,
		clampi(report.severity, 1, 3)
	)
	_wanted.set_wanted_level(maxi(_wanted.wanted_level, clampi(report.severity, 1, 3)))
	report_accepted.emit(report)


func _is_player_actor(actor: Node) -> bool:
	var current := actor
	while current != null:
		if current.is_in_group(&"player"):
			return true
		current = current.get_parent()
	return false
