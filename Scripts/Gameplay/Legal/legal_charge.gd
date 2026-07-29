class_name LegalCharge
extends Resource

@export var charge_id: StringName = &""
@export var display_name: String = ""
@export var unit_points: int = 0
@export var count: int = 1
@export var evidence_note: String = ""


func get_total_points() -> int:
	return maxi(0, unit_points) * maxi(0, count)


func to_dict() -> Dictionary:
	return {
		"charge_id": String(charge_id),
		"display_name": display_name,
		"unit_points": unit_points,
		"count": count,
		"evidence_note": evidence_note,
	}


static func from_dict(data: Dictionary) -> LegalCharge:
	var charge := LegalCharge.new()
	charge.charge_id = StringName(str(data.get("charge_id", "")))
	charge.display_name = str(data.get("display_name", "Unknown charge"))
	charge.unit_points = maxi(0, int(data.get("unit_points", 0)))
	charge.count = maxi(1, int(data.get("count", 1)))
	charge.evidence_note = str(data.get("evidence_note", ""))
	return charge
