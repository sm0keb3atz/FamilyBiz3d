class_name PlayerLegalComponent
extends Node

signal legal_state_changed
signal case_created(legal_case: LegalCase)
signal hearing_requested(legal_case: LegalCase, defaulted: bool)
signal lawyer_resigned(lawyer_id: StringName)
signal custody_completed(legal_case: LegalCase)

const LAWYER_DEFINITIONS: Array[LawyerDefinition] = [
	preload("res://Scripts/Gameplay/Legal/lawyer_level_1.tres"),
	preload("res://Scripts/Gameplay/Legal/lawyer_level_2.tres"),
	preload("res://Scripts/Gameplay/Legal/lawyer_level_3.tres"),
	preload("res://Scripts/Gameplay/Legal/lawyer_level_4.tres"),
]
const PUBLIC_DEFENDER_MIN := 0
const PUBLIC_DEFENDER_MAX := 100
const COURT_HOUR_MINUTE := 10 * 60
const COURT_WINDOW_MINUTES := 60
const BOND_DAYS := 3
const COURT_DAYS_AFTER_RELEASE := 3

@export var inventory_path := NodePath("../InventoryComponent")
@export var weapon_path := NodePath("../WeaponComponent")
@export var wallet_path := NodePath("../WalletComponent")
@export var wanted_path := NodePath("../WantedComponent")
@export var property_path := NodePath("../PropertyComponent")
@export var girlfriend_path := NodePath("../GirlfriendComponent")
@export var stats_path := NodePath("../StatsComponent")
@export var wardrobe_path := NodePath("../WardrobeComponent")
@export var vehicle_path := NodePath("../VehicleComponent")
@export var vehicle_garage_path := NodePath("../VehicleGarageComponent")

@onready var inventory := get_node(inventory_path) as PlayerInventoryComponent
@onready var weapon := get_node(weapon_path) as PlayerWeaponComponent
@onready var wallet := get_node(wallet_path) as PlayerWalletComponent
@onready var wanted := get_node(wanted_path) as PlayerWantedComponent
@onready var properties := get_node(property_path) as PlayerPropertyComponent
@onready var girlfriends := get_node(girlfriend_path) as PlayerGirlfriendComponent
@onready var stats := get_node(stats_path) as PlayerStatsComponent
@onready var wardrobe := get_node(wardrobe_path) as PlayerWardrobeComponent
@onready var vehicle := get_node(vehicle_path) as PlayerVehicleComponent
@onready var vehicle_garage := get_node(
	vehicle_garage_path
) as PlayerVehicleGarageComponent

var _cases: Array[LegalCase] = []
var _contracts: Dictionary[StringName, Dictionary] = {}
var _court_presence_count := 0
var _hearing_requested_ids: Dictionary[String, bool] = {}
var _custody_active := false
var _sentence_active := false
var _next_case_number := 1
var _world_time: WorldTimeComponent
var _last_release_summary: Array[String] = []


func _ready() -> void:
	add_to_group(&"player_legal")
	call_deferred("_connect_world_time")


func _connect_world_time() -> void:
	_world_time = get_tree().get_first_node_in_group(&"world_time") as WorldTimeComponent
	if _world_time == null:
		return
	if not _world_time.minute_advanced.is_connected(_on_minute_advanced):
		_world_time.minute_advanced.connect(_on_minute_advanced)
	if not _world_time.day_ending.is_connected(_on_day_ending):
		_world_time.day_ending.connect(_on_day_ending)
	if not _world_time.calendar_skipped.is_connected(_on_calendar_skipped):
		_world_time.calendar_skipped.connect(_on_calendar_skipped)


func get_lawyer_definitions() -> Array[LawyerDefinition]:
	return LAWYER_DEFINITIONS.duplicate()


func get_lawyer_definition(lawyer_id: StringName) -> LawyerDefinition:
	for definition in LAWYER_DEFINITIONS:
		if definition.lawyer_id == lawyer_id:
			return definition
	return null


func is_lawyer_retained(lawyer_id: StringName) -> bool:
	return _contracts.has(lawyer_id)


func get_contract(lawyer_id: StringName) -> Dictionary:
	return (_contracts.get(lawyer_id, {}) as Dictionary).duplicate(true)


func hire_lawyer(lawyer_id: StringName) -> bool:
	var definition := get_lawyer_definition(lawyer_id)
	if definition == null or is_lawyer_retained(lawyer_id):
		return false
	if not wallet.spend_clean(definition.retainer_clean):
		return false
	var now := _get_absolute_minute()
	_contracts[lawyer_id] = {
		"next_fee_minute": ((now / WorldTimeComponent.MINUTES_PER_DAY) + 1) * WorldTimeComponent.MINUTES_PER_DAY,
		"service_day": now / WorldTimeComponent.MINUTES_PER_DAY,
		"laundered_today": 0,
		"heat_used_today": 0,
	}
	legal_state_changed.emit()
	return true


func terminate_lawyer(lawyer_id: StringName) -> bool:
	if not _contracts.has(lawyer_id):
		return false
	_contracts.erase(lawyer_id)
	for legal_case in _cases:
		if legal_case.is_pending() and legal_case.assigned_lawyer_id == lawyer_id:
			legal_case.assigned_lawyer_id = &""
	legal_state_changed.emit()
	return true


func assign_lawyer(case_id: String, lawyer_id: StringName) -> bool:
	var legal_case := get_case(case_id)
	if legal_case == null or not legal_case.is_pending():
		return false
	if lawyer_id != &"" and not is_lawyer_retained(lawyer_id):
		return false
	legal_case.assigned_lawyer_id = lawyer_id
	legal_state_changed.emit()
	return true


func launder_money(lawyer_id: StringName, requested_dirty: int) -> Dictionary:
	var definition := get_lawyer_definition(lawyer_id)
	if definition == null or requested_dirty <= 0 or not is_lawyer_retained(lawyer_id):
		return {}
	var contract := _sync_contract_day(lawyer_id)
	var remaining := definition.laundering_daily_limit - int(contract.get("laundered_today", 0))
	var amount := mini(requested_dirty, mini(remaining, wallet.dirty_cash))
	if amount <= 0 or not wallet.spend_dirty(amount):
		return {}
	var clean_amount := floori(float(amount) * (1.0 - definition.laundering_cut))
	if clean_amount > 0:
		wallet.add_clean(clean_amount)
	contract["laundered_today"] = int(contract.get("laundered_today", 0)) + amount
	_contracts[lawyer_id] = contract
	legal_state_changed.emit()
	return {"dirty_spent": amount, "clean_received": clean_amount}


func reduce_territory_heat(
	lawyer_id: StringName,
	territory_id: StringName,
	requested_points: int
) -> Dictionary:
	var definition := get_lawyer_definition(lawyer_id)
	if definition == null or requested_points <= 0 or not is_lawyer_retained(lawyer_id):
		return {}
	var boundary := _find_territory(territory_id)
	if boundary == null or boundary.stats == null:
		return {}
	var contract := _sync_contract_day(lawyer_id)
	var remaining := definition.heat_daily_limit - int(contract.get("heat_used_today", 0))
	var points := mini(
		requested_points,
		mini(remaining, ceili(boundary.stats.heat))
	)
	var cost := points * definition.heat_cost_per_point
	if points <= 0 or not wallet.spend_dirty(cost):
		return {}
	boundary.stats.set_heat(maxf(boundary.stats.heat - float(points), 0.0))
	contract["heat_used_today"] = int(contract.get("heat_used_today", 0)) + points
	_contracts[lawyer_id] = contract
	legal_state_changed.emit()
	return {"points": points, "dirty_spent": cost}


func begin_police_custody() -> LegalCase:
	if _custody_active:
		return null
	_custody_active = true
	var legal_case := _create_case_from_current_evidence()
	var booking_day := _get_absolute_minute() / WorldTimeComponent.MINUTES_PER_DAY
	legal_case.hearing_absolute_minute = (
		(booking_day + BOND_DAYS + COURT_DAYS_AFTER_RELEASE)
		* WorldTimeComponent.MINUTES_PER_DAY
		+ COURT_HOUR_MINUTE
	)
	inventory.confiscate_all()
	weapon.confiscate_all()
	wallet.deduct_percentage(0.10)
	if vehicle.is_driving():
		vehicle.exit_vehicle(true)
	vehicle_garage.reset_to_new_game()
	wanted.resolve_arrest()
	if _world_time != null:
		_world_time.fast_forward_days(BOND_DAYS, &"bond", true)
	_custody_active = false
	custody_completed.emit(legal_case)
	legal_state_changed.emit()
	return legal_case


func build_evidence_snapshot() -> Array[LegalCharge]:
	var result: Array[LegalCharge] = []
	var drug_grams := {
		ProductDefinition.DrugType.WEED: 0,
		ProductDefinition.DrugType.COKE: 0,
		ProductDefinition.DrugType.FENT: 0,
	}
	for product in inventory.get_known_products():
		var quantity := inventory.get_quantity(product)
		if quantity > 0:
			drug_grams[product.drug_type] = (
				int(drug_grams.get(product.drug_type, 0))
				+ quantity * product.package_size_grams
			)
	var drug_names := ["Weed Possession", "Cocaine Possession", "Fentanyl Possession"]
	var drug_ids := [&"weed_possession", &"cocaine_possession", &"fentanyl_possession"]
	var multipliers := [1, 2, 3]
	for drug_type in 3:
		var grams := int(drug_grams.get(drug_type, 0))
		if grams > 0:
			result.append(_make_charge(
				drug_ids[drug_type], drug_names[drug_type], multipliers[drug_type], grams,
				"%dg carried" % grams
			))
	var weapon_data := weapon.export_save_data()
	var state_data := weapon_data.get("attachment_states", {}) as Dictionary
	for weapon_id_value in weapon_data.get("owned_weapon_ids", []) as Array:
		var weapon_id := StringName(str(weapon_id_value))
		var definition := weapon.get_weapon_definition(weapon_id)
		var is_rifle := weapon_id == &"draco" or "rifle" in String(weapon_id).to_lower()
		result.append(_make_charge(
			&"rifle_possession" if is_rifle else &"pistol_possession",
			"Rifle / Draco Possession" if is_rifle else "Pistol Possession",
			250 if is_rifle else 100,
			1,
			definition.display_name if definition != null else String(weapon_id)
		))
		var state := state_data.get(String(weapon_id), {}) as Dictionary
		if bool(state.get("switch", false)):
			result.append(_make_charge(
				&"automatic_switch", "Enabled Automatic Switch", 300, 1, String(weapon_id)
			))
		var magazine_type := int(state.get("magazine_type", PlayerWeaponComponent.MagazineType.STANDARD))
		if magazine_type in [
			PlayerWeaponComponent.MagazineType.EXTENDED,
			PlayerWeaponComponent.MagazineType.DRUM,
		]:
			result.append(_make_charge(
				&"high_capacity_magazine", "Extended / Drum Magazine", 100, 1,
				String(weapon_id)
			))
	if wanted.active_incident != null:
		var ledger: Array = wanted.active_incident.charge_ledger
		for entry in ledger:
			result.append(LegalCharge.from_dict(entry))
		if ledger.is_empty():
			var fallback := _charge_for_crime_type(wanted.active_incident.crime_type)
			if fallback != null:
				result.append(fallback)
	if result.is_empty():
		result.append(_make_charge(
			&"evading", "Evading / Suspicious Activity", 50
		))
	return result


func get_case(case_id: String) -> LegalCase:
	for legal_case in _cases:
		if legal_case.case_id == case_id:
			return legal_case
	return null


func get_pending_cases() -> Array[LegalCase]:
	var result: Array[LegalCase] = []
	for legal_case in _cases:
		if legal_case.is_pending():
			result.append(legal_case)
	result.sort_custom(func(a: LegalCase, b: LegalCase) -> bool:
		return a.hearing_absolute_minute < b.hearing_absolute_minute
	)
	return result


func get_recent_cases(limit := 8) -> Array[LegalCase]:
	var result: Array[LegalCase] = []
	for legal_case in _cases:
		if not legal_case.is_pending():
			result.append(legal_case)
	result.sort_custom(func(a: LegalCase, b: LegalCase) -> bool:
		return a.resolved_absolute_minute > b.resolved_absolute_minute
	)
	return result.slice(0, mini(limit, result.size()))


func get_defense_range(legal_case: LegalCase) -> Vector2i:
	if legal_case != null and legal_case.assigned_lawyer_id != &"":
		var definition := get_lawyer_definition(legal_case.assigned_lawyer_id)
		if definition != null and is_lawyer_retained(definition.lawyer_id):
			return Vector2i(definition.defense_min, definition.defense_max)
	return Vector2i(PUBLIC_DEFENDER_MIN, PUBLIC_DEFENDER_MAX)


func get_win_chance(legal_case: LegalCase) -> float:
	if legal_case == null:
		return 0.0
	var defense_range := get_defense_range(legal_case)
	var possible := defense_range.y - defense_range.x + 1
	var winning := maxi(defense_range.y - maxi(legal_case.get_total_points(), defense_range.x - 1), 0)
	return float(winning) / float(maxi(possible, 1))


func adjudicate_case(case_id: String, defaulted := false) -> Dictionary:
	var legal_case := get_case(case_id)
	if legal_case == null or not legal_case.is_pending():
		return {}
	var defense_range := get_defense_range(legal_case)
	var rng := RandomNumberGenerator.new()
	rng.seed = legal_case.defense_seed
	var roll := rng.randi_range(defense_range.x, defense_range.y)
	legal_case.revealed_defense_roll = roll
	var guilty := defaulted or roll <= legal_case.get_total_points()
	legal_case.status = (
		LegalCase.Status.DEFAULTED if defaulted
		else LegalCase.Status.GUILTY if guilty
		else LegalCase.Status.NOT_GUILTY
	)
	legal_case.sentence_years = (
		clampi(ceili(float(legal_case.get_total_points()) / 100.0), 1, 20)
		if guilty else 0
	)
	legal_case.resolved_absolute_minute = _get_absolute_minute()
	_hearing_requested_ids.erase(case_id)
	legal_state_changed.emit()
	return {
		"guilty": guilty,
		"roll": roll,
		"sentence_years": legal_case.sentence_years,
		"defense_min": defense_range.x,
		"defense_max": defense_range.y,
	}


func apply_case_outcome(case_id: String) -> Array[String]:
	var legal_case := get_case(case_id)
	if legal_case == null or legal_case.status == LegalCase.Status.PENDING:
		return []
	if legal_case.status == LegalCase.Status.NOT_GUILTY:
		return []
	var points := legal_case.get_total_points()
	var forfeitures: Array[String] = []
	if points <= 500:
		properties.forfeit_front_businesses()
		girlfriends.clear_all_due_to_conviction()
		wallet.deduct_percentage(0.50)
		forfeitures = ["Front businesses", "Girlfriends", "50% of wallet cash"]
	elif points <= 1000:
		properties.forfeit_front_businesses()
		properties.forfeit_stash_houses()
		girlfriends.clear_all_due_to_conviction()
		wallet.deduct_percentage(0.75)
		forfeitures = [
			"Front businesses", "Stash houses and contents",
			"Girlfriends", "75% of wallet cash",
		]
	else:
		_apply_full_new_game_reset()
		forfeitures = ["All criminal assets and player progression"]
	legal_case.forfeiture_summary = forfeitures
	if legal_case.sentence_years > 0 and _world_time != null:
		_last_release_summary = [
			"%s: %d years (%d points)"
			% [legal_case.case_id, legal_case.sentence_years, legal_case.get_total_points()]
		]
		_sentence_active = true
		_world_time.fast_forward_years(legal_case.sentence_years, &"prison")
		_sentence_active = false
		_resolve_cases_due_during_prison()
	legal_state_changed.emit()
	return forfeitures


func get_last_release_summary() -> Array[String]:
	return _last_release_summary.duplicate()


func set_court_presence(present: bool) -> void:
	_court_presence_count = maxi(_court_presence_count + (1 if present else -1), 0)
	_check_hearings(_get_absolute_minute())


func is_in_court_area() -> bool:
	return _court_presence_count > 0


func get_hearing_countdown_text(legal_case: LegalCase) -> String:
	if legal_case == null:
		return ""
	var minutes := legal_case.hearing_absolute_minute - _get_absolute_minute()
	if minutes <= 0:
		return "DUE NOW"
	var days := minutes / WorldTimeComponent.MINUTES_PER_DAY
	var hours := (minutes % WorldTimeComponent.MINUTES_PER_DAY) / 60
	var mins := minutes % 60
	return "%dd %dh %dm" % [days, hours, mins]


func get_hearing_datetime_text(legal_case: LegalCase) -> String:
	if legal_case == null:
		return ""
	if _world_time == null:
		return "10:00 AM"
	return _world_time.get_formatted_absolute_datetime(
		legal_case.hearing_absolute_minute
	)


func export_save_data() -> Dictionary:
	var case_data: Array[Dictionary] = []
	for legal_case in _cases:
		case_data.append(legal_case.to_dict())
	var contracts := {}
	for lawyer_id in _contracts:
		contracts[String(lawyer_id)] = (_contracts[lawyer_id] as Dictionary).duplicate(true)
	return {
		"cases": case_data,
		"contracts": contracts,
		"next_case_number": _next_case_number,
	}


func import_save_data(data: Dictionary) -> void:
	_cases.clear()
	var raw_cases: Variant = data.get("cases", [])
	if raw_cases is Array:
		for raw_case in raw_cases:
			if raw_case is Dictionary:
				_cases.append(LegalCase.from_dict(raw_case))
	_contracts.clear()
	var raw_contracts := data.get("contracts", {}) as Dictionary
	for lawyer_id_value in raw_contracts:
		var lawyer_id := StringName(str(lawyer_id_value))
		if get_lawyer_definition(lawyer_id) != null:
			_contracts[lawyer_id] = (
				raw_contracts[lawyer_id_value] as Dictionary
			).duplicate(true)
	_next_case_number = maxi(int(data.get("next_case_number", _cases.size() + 1)), 1)
	legal_state_changed.emit()


func reset_to_new_game() -> void:
	_cases.clear()
	_contracts.clear()
	_next_case_number = 1
	_hearing_requested_ids.clear()
	legal_state_changed.emit()


func _create_case_from_current_evidence() -> LegalCase:
	var legal_case := LegalCase.new()
	legal_case.case_id = "CASE-%05d" % _next_case_number
	_next_case_number += 1
	legal_case.created_absolute_minute = _get_absolute_minute()
	legal_case.charges = build_evidence_snapshot()
	var seed_source := "%s:%d:%d" % [
		legal_case.case_id,
		legal_case.created_absolute_minute,
		Time.get_unix_time_from_system(),
	]
	legal_case.defense_seed = maxi(abs(seed_source.hash()), 1)
	_cases.append(legal_case)
	case_created.emit(legal_case)
	return legal_case


func _make_charge(
	charge_id: StringName,
	display_name: String,
	unit_points: int,
	count := 1,
	evidence_note := ""
) -> LegalCharge:
	var charge := LegalCharge.new()
	charge.charge_id = charge_id
	charge.display_name = display_name
	charge.unit_points = unit_points
	charge.count = maxi(count, 1)
	charge.evidence_note = evidence_note
	return charge


func _charge_for_crime_type(crime_type: int) -> LegalCharge:
	match crime_type:
		PoliceIncident.CrimeType.ILLEGAL_ACTIVITY:
			return _make_charge(&"illegal_sale", "Illegal Sale", 50)
		PoliceIncident.CrimeType.WEAPON_DISCHARGE:
			return _make_charge(&"weapon_discharge", "Weapon Discharge", 100)
		PoliceIncident.CrimeType.ASSAULT:
			return _make_charge(&"assault", "Assault", 250)
		PoliceIncident.CrimeType.HOMICIDE:
			return _make_charge(&"homicide", "Homicide", 500)
		PoliceIncident.CrimeType.OFFICER_DOWN:
			return _make_charge(&"officer_down", "Officer Down", 750)
		_:
			return _make_charge(&"evading", "Evading / Suspicious Activity", 50)


func _on_minute_advanced(absolute_minute: int) -> void:
	_check_hearings(absolute_minute)


func _check_hearings(absolute_minute: int) -> void:
	for legal_case in get_pending_cases():
		var window_start := legal_case.hearing_absolute_minute - COURT_WINDOW_MINUTES
		if (
			absolute_minute >= window_start
			and absolute_minute < legal_case.hearing_absolute_minute
			and is_in_court_area()
		):
			_request_hearing(legal_case, false)
		elif absolute_minute >= legal_case.hearing_absolute_minute:
			_request_hearing(legal_case, not (_custody_active or _sentence_active))


func _request_hearing(legal_case: LegalCase, defaulted: bool) -> void:
	if _hearing_requested_ids.has(legal_case.case_id):
		return
	_hearing_requested_ids[legal_case.case_id] = true
	hearing_requested.emit(legal_case, defaulted)


func _on_day_ending(_report_date: String) -> void:
	if _sentence_active:
		return
	var billing_minute := _get_absolute_minute() + 1
	for lawyer_id_value in _contracts.keys().duplicate():
		var lawyer_id := StringName(lawyer_id_value)
		var definition := get_lawyer_definition(lawyer_id)
		var contract := _contracts.get(lawyer_id, {}) as Dictionary
		if definition == null:
			terminate_lawyer(lawyer_id)
			continue
		if billing_minute < int(contract.get("next_fee_minute", billing_minute)):
			continue
		if not wallet.spend_clean(definition.daily_fee_clean):
			terminate_lawyer(lawyer_id)
			lawyer_resigned.emit(lawyer_id)
			continue
		contract["next_fee_minute"] = billing_minute + WorldTimeComponent.MINUTES_PER_DAY
		_contracts[lawyer_id] = contract
	legal_state_changed.emit()


func _on_calendar_skipped(
	_from_absolute_minute: int,
	to_absolute_minute: int,
	_reason: StringName
) -> void:
	if not _sentence_active:
		_check_hearings(to_absolute_minute)


func _sync_contract_day(lawyer_id: StringName) -> Dictionary:
	var contract := _contracts.get(lawyer_id, {}) as Dictionary
	var current_day := _get_absolute_minute() / WorldTimeComponent.MINUTES_PER_DAY
	if int(contract.get("service_day", -1)) != current_day:
		contract["service_day"] = current_day
		contract["laundered_today"] = 0
		contract["heat_used_today"] = 0
		_contracts[lawyer_id] = contract
	return contract


func _resolve_cases_due_during_prison() -> void:
	while true:
		var additional_years := 0
		var resolved_any := false
		for legal_case in get_pending_cases():
			if legal_case.hearing_absolute_minute > _get_absolute_minute():
				continue
			resolved_any = true
			var result := adjudicate_case(legal_case.case_id, false)
			if bool(result.get("guilty", false)):
				var points := legal_case.get_total_points()
				if points > 1000:
					_apply_full_new_game_reset(false)
				elif points > 500:
					properties.forfeit_front_businesses()
					properties.forfeit_stash_houses()
					girlfriends.clear_all_due_to_conviction()
					wallet.deduct_percentage(0.75)
				else:
					properties.forfeit_front_businesses()
					girlfriends.clear_all_due_to_conviction()
					wallet.deduct_percentage(0.50)
				var years := int(result.get("sentence_years", 0))
				additional_years += years
				_last_release_summary.append(
					"%s: guilty, %d years (%d points)"
					% [legal_case.case_id, years, points]
				)
			else:
				_last_release_summary.append(
					"%s: not guilty (%d points)"
					% [legal_case.case_id, legal_case.get_total_points()]
				)
		if not resolved_any or additional_years <= 0 or _world_time == null:
			break
		_world_time.fast_forward_years(additional_years, &"prison")


func _apply_full_new_game_reset(clear_legal := true) -> void:
	properties.reset_to_new_game()
	girlfriends.clear_all_due_to_conviction()
	inventory.reset_to_new_game()
	weapon.reset_to_new_game()
	stats.reset_to_new_game()
	wardrobe.reset_to_new_game()
	wallet.reset_to_new_game()
	if vehicle.is_driving():
		vehicle.exit_vehicle(true)
	for node in get_tree().get_nodes_in_group(&"territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if boundary != null and boundary.stats != null:
			boundary.stats.reset_to_new_game()
	var dealer_service := get_tree().get_first_node_in_group(&"territory_dealer_service")
	if dealer_service != null and dealer_service.has_method("reset_to_new_game"):
		dealer_service.call("reset_to_new_game")
	_contracts.clear()
	if clear_legal:
		for pending_case in _cases:
			if pending_case.is_pending():
				pending_case.assigned_lawyer_id = &""


func _find_territory(territory_id: StringName) -> TerritoryBoundary:
	for node in get_tree().get_nodes_in_group(&"territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if boundary != null and boundary.territory_id == territory_id:
			return boundary
	return null


func _get_absolute_minute() -> int:
	return _world_time.get_absolute_minute() if _world_time != null else 0
