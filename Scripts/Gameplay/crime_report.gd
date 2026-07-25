class_name CrimeReport
extends RefCounted

var event_id := 0
var reporter: Node
var reporter_id := 0
var suspect: Node
var suspect_id := 0
var observation_position := Vector3.ZERO
var observed_at_seconds := 0.0
var confidence := 0.0
var crime_type := 0
var severity := 1
var completed := false
var interrupted := false


func has_identified_suspect() -> bool:
	return is_instance_valid(suspect) or suspect_id != 0
