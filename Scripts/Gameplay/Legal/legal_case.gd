class_name LegalCase
extends Resource

enum Status {
	PENDING,
	NOT_GUILTY,
	GUILTY,
	DEFAULTED,
}

@export var case_id: String = ""
@export var created_absolute_minute: int = 0
@export var hearing_absolute_minute: int = 0
@export var charges: Array[LegalCharge] = []
@export var assigned_lawyer_id: StringName = &""
@export var defense_seed: int = 1
@export var status: Status = Status.PENDING
@export var revealed_defense_roll: int = -1
@export var sentence_years: int = 0
@export var forfeiture_summary: Array[String] = []
@export var resolved_absolute_minute: int = -1


func get_total_points() -> int:
	var total := 0
	for charge in charges:
		if charge != null:
			total += charge.get_total_points()
	return total


func is_pending() -> bool:
	return status == Status.PENDING


func to_dict() -> Dictionary:
	var serialized_charges: Array[Dictionary] = []
	for charge in charges:
		if charge != null:
			serialized_charges.append(charge.to_dict())
	return {
		"case_id": case_id,
		"created_absolute_minute": created_absolute_minute,
		"hearing_absolute_minute": hearing_absolute_minute,
		"charges": serialized_charges,
		"assigned_lawyer_id": String(assigned_lawyer_id),
		"defense_seed": defense_seed,
		"status": int(status),
		"revealed_defense_roll": revealed_defense_roll,
		"sentence_years": sentence_years,
		"forfeiture_summary": forfeiture_summary.duplicate(),
		"resolved_absolute_minute": resolved_absolute_minute,
	}


static func from_dict(data: Dictionary) -> LegalCase:
	var legal_case := LegalCase.new()
	legal_case.case_id = str(data.get("case_id", ""))
	legal_case.created_absolute_minute = int(data.get("created_absolute_minute", 0))
	legal_case.hearing_absolute_minute = int(data.get("hearing_absolute_minute", 0))
	var charge_array: Array[LegalCharge] = []
	var raw_charges: Variant = data.get("charges", [])
	if raw_charges is Array:
		for raw_charge in raw_charges:
			if raw_charge is Dictionary:
				charge_array.append(LegalCharge.from_dict(raw_charge))
	legal_case.charges = charge_array
	legal_case.assigned_lawyer_id = StringName(str(data.get("assigned_lawyer_id", "")))
	legal_case.defense_seed = maxi(1, int(data.get("defense_seed", 1)))
	legal_case.status = clampi(int(data.get("status", Status.PENDING)), Status.PENDING, Status.DEFAULTED) as Status
	legal_case.revealed_defense_roll = int(data.get("revealed_defense_roll", -1))
	legal_case.sentence_years = maxi(0, int(data.get("sentence_years", 0)))
	var forfeitures: Array[String] = []
	var raw_forfeitures: Variant = data.get("forfeiture_summary", [])
	if raw_forfeitures is Array:
		for entry in raw_forfeitures:
			forfeitures.append(str(entry))
	legal_case.forfeiture_summary = forfeitures
	legal_case.resolved_absolute_minute = int(data.get("resolved_absolute_minute", -1))
	return legal_case
