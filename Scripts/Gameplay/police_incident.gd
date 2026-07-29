class_name PoliceIncident
extends Resource

enum CrimeType {
	UNKNOWN,
	SUSPICIOUS_ACTIVITY,
	ILLEGAL_ACTIVITY,
	WEAPON_DISCHARGE,
	ASSAULT,
	HOMICIDE,
	OFFICER_DOWN,
}

var incident_id := 0
var crime_type := CrimeType.UNKNOWN
var severity := 1
var position := Vector3.ZERO
var territory_id: StringName
var reported_at_minute := 0
var last_known_player_position := Vector3.ZERO
var last_known_velocity := Vector3.ZERO
var observed_at_seconds := 0.0
var confidence := 1.0
var uncertainty_radius := 2.0
var suspect_known := true
var revision := 1
var force_authorized := false
var charge_ledger: Array[Dictionary] = []


func record_charge(
	charge_id: StringName,
	display_name: String,
	unit_points: int,
	unique_key: String = ""
) -> void:
	if charge_id == &"" or unit_points <= 0:
		return
	var ledger_key := unique_key if not unique_key.is_empty() else String(charge_id)
	for entry in charge_ledger:
		if str(entry.get("unique_key", "")) == ledger_key:
			return
	charge_ledger.append({
		"charge_id": String(charge_id),
		"display_name": display_name,
		"unit_points": unit_points,
		"count": 1,
		"unique_key": ledger_key,
	})


func to_dictionary() -> Dictionary:
	return {
		"incident_id": incident_id,
		"crime_type": crime_type,
		"severity": severity,
		"position": _vector_to_array(position),
		"territory_id": String(territory_id),
		"reported_at_minute": reported_at_minute,
		"last_known_player_position": _vector_to_array(last_known_player_position),
		"last_known_velocity": _vector_to_array(last_known_velocity),
		"observed_at_seconds": observed_at_seconds,
		"confidence": confidence,
		"uncertainty_radius": uncertainty_radius,
		"suspect_known": suspect_known,
		"revision": revision,
		"force_authorized": force_authorized,
		"charge_ledger": charge_ledger.duplicate(true),
	}


static func from_dictionary(data: Dictionary) -> PoliceIncident:
	if data.is_empty():
		return null
	var incident := PoliceIncident.new()
	incident.incident_id = maxi(int(data.get("incident_id", 0)), 0)
	incident.crime_type = clampi(
		int(data.get("crime_type", CrimeType.UNKNOWN)),
		CrimeType.UNKNOWN,
		CrimeType.OFFICER_DOWN
	)
	incident.severity = clampi(int(data.get("severity", 1)), 1, 3)
	incident.position = _array_to_vector(data.get("position", []) as Array)
	incident.territory_id = StringName(str(data.get("territory_id", "")))
	incident.reported_at_minute = maxi(int(data.get("reported_at_minute", 0)), 0)
	incident.last_known_player_position = _array_to_vector(
		data.get("last_known_player_position", []) as Array
	)
	incident.last_known_velocity = _array_to_vector(
		data.get("last_known_velocity", []) as Array
	)
	incident.observed_at_seconds = maxf(float(data.get("observed_at_seconds", 0.0)), 0.0)
	incident.confidence = clampf(float(data.get("confidence", 1.0)), 0.0, 1.0)
	incident.uncertainty_radius = maxf(float(data.get("uncertainty_radius", 2.0)), 0.0)
	incident.suspect_known = bool(data.get("suspect_known", true))
	incident.revision = maxi(int(data.get("revision", 1)), 1)
	incident.force_authorized = bool(
		data.get("force_authorized", incident.severity >= 3)
	)
	var raw_ledger: Variant = data.get("charge_ledger", [])
	if raw_ledger is Array:
		for entry in raw_ledger:
			if entry is Dictionary:
				incident.charge_ledger.append(entry.duplicate(true))
	return incident


static func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func _array_to_vector(value: Array) -> Vector3:
	if value.size() != 3:
		return Vector3.ZERO
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
