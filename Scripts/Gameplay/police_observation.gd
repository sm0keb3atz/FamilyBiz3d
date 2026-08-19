class_name PoliceObservation
extends RefCounted

enum Kind { SOUND, VISUAL, CIVILIAN_REPORT, BODY }

var kind := Kind.SOUND
var world_position := Vector3.ZERO
var velocity := Vector3.ZERO
var reporter_id := 0
var suspect_id := 0
var confidence := 0.0
var created_at_seconds := 0.0
var event_id := 0


func identifies_suspect() -> bool:
	return suspect_id != 0


static func create(
	observation_kind: int,
	position: Vector3,
	reporter: Node = null,
	suspect: Node = null,
	observation_confidence := 1.0,
	observed_velocity := Vector3.ZERO,
	source_event_id := 0
) -> RefCounted:
	var observation := PoliceObservation.new()
	observation.kind = clampi(observation_kind, Kind.SOUND, Kind.BODY)
	observation.world_position = position
	observation.velocity = observed_velocity
	observation.reporter_id = reporter.get_instance_id() if is_instance_valid(reporter) else 0
	observation.suspect_id = suspect.get_instance_id() if is_instance_valid(suspect) else 0
	observation.confidence = clampf(observation_confidence, 0.0, 1.0)
	observation.created_at_seconds = Time.get_ticks_msec() * 0.001
	observation.event_id = maxi(source_event_id, 0)
	return observation
