class_name TerritoryStatsComponent
extends Node

signal reputation_changed(current: float)
signal heat_changed(current: float)
signal owner_faction_changed(current: OwnerFaction)
signal pressure_tier_changed(current: RivalPressureTier)
signal takeover_availability_changed(available: bool)
signal purchase_availability_changed(available: bool)
signal wipe_availability_changed(available: bool)

enum OwnerFaction {
	NEUTRAL,
	RIVAL,
	PLAYER,
}

enum RivalPressureTier {
	NONE,
	LOW,
	MEDIUM,
	HIGH,
}

@export var territory_id: StringName = &"test_territory"
@export_range(-100.0, 100.0, 0.1) var starting_reputation := 0.0
@export_range(0.0, 100.0, 0.1) var starting_heat := 0.0
@export_range(0.0, 10.0, 0.05) var heat_decay_per_second := 0.25
@export_range(0.0, 100.0, 0.1) var trade_lock_heat := 76.0
@export var starting_owner_faction := OwnerFaction.NEUTRAL

var reputation: float:
	get:
		return _reputation
var heat: float:
	get:
		return _heat
var owner_faction: OwnerFaction:
	get:
		return _owner_faction

var _reputation := 0.0
var _heat := 0.0
var _owner_faction := OwnerFaction.NEUTRAL
var _pressure_tier := RivalPressureTier.NONE
var _takeover_available := false


func _ready() -> void:
	_reputation = clampf(starting_reputation, -100.0, 100.0)
	_heat = clampf(starting_heat, 0.0, 100.0)
	_owner_faction = OwnerFaction.values()[clampi(
		int(starting_owner_faction),
		OwnerFaction.NEUTRAL,
		OwnerFaction.PLAYER
	)]
	_refresh_derived_state(false)
	reputation_changed.emit(_reputation)
	heat_changed.emit(_heat)
	owner_faction_changed.emit(_owner_faction)
	pressure_tier_changed.emit(_pressure_tier)
	takeover_availability_changed.emit(_takeover_available)
	purchase_availability_changed.emit(_takeover_available)
	wipe_availability_changed.emit(_takeover_available)


func _process(delta: float) -> void:
	if _heat > 0.0 and heat_decay_per_second > 0.0:
		set_heat(_heat - heat_decay_per_second * delta)


func add_reputation(amount: float) -> bool:
	if is_zero_approx(amount):
		return false
	return set_reputation(_reputation + amount)


func set_reputation(value: float) -> bool:
	var next_reputation := clampf(value, -100.0, 100.0)
	if is_equal_approx(next_reputation, _reputation):
		return false

	_reputation = next_reputation
	reputation_changed.emit(_reputation)
	_refresh_derived_state()
	return true


func set_owner_faction(value: OwnerFaction) -> bool:
	var next_owner: OwnerFaction = OwnerFaction.values()[clampi(
		int(value),
		OwnerFaction.NEUTRAL,
		OwnerFaction.PLAYER
	)]
	if next_owner == _owner_faction:
		return false
	_owner_faction = next_owner
	owner_faction_changed.emit(_owner_faction)
	_refresh_derived_state()
	return true


func get_pressure_tier() -> RivalPressureTier:
	return _pressure_tier


func is_takeover_available() -> bool:
	return _takeover_available


func can_purchase_territory() -> bool:
	return _takeover_available


func can_wipe_dealers_for_takeover() -> bool:
	return _takeover_available


func add_heat(amount: float) -> bool:
	if amount <= 0.0:
		return false
	return set_heat(_heat + amount)


func set_heat(value: float) -> bool:
	var next_heat := clampf(value, 0.0, 100.0)
	if is_equal_approx(next_heat, _heat):
		return false
	_heat = next_heat
	heat_changed.emit(_heat)
	return true


func record_sale(reputation_amount: float, heat_amount: float) -> void:
	add_reputation(reputation_amount)
	add_heat(heat_amount)


func is_trade_locked() -> bool:
	return _heat >= trade_lock_heat


func export_save_data() -> Dictionary:
	return {
		"reputation": _reputation,
		"heat": _heat,
		"owner_faction": int(_owner_faction),
	}


func import_save_data(data: Dictionary) -> void:
	var next_reputation := clampf(
		float(data.get("reputation", starting_reputation)),
		-100.0,
		100.0
	)
	_reputation = next_reputation
	_owner_faction = OwnerFaction.values()[clampi(
		int(data.get("owner_faction", OwnerFaction.NEUTRAL)),
		OwnerFaction.NEUTRAL,
		OwnerFaction.PLAYER
	)]
	_refresh_derived_state(false)
	reputation_changed.emit(_reputation)
	owner_faction_changed.emit(_owner_faction)
	pressure_tier_changed.emit(_pressure_tier)
	takeover_availability_changed.emit(_takeover_available)
	purchase_availability_changed.emit(_takeover_available)
	wipe_availability_changed.emit(_takeover_available)
	set_heat(float(data.get("heat", starting_heat)))


func _refresh_derived_state(emit_changes := true) -> void:
	var next_pressure := RivalPressureTier.NONE
	if _reputation <= -75.0:
		next_pressure = RivalPressureTier.HIGH
	elif _reputation <= -50.0:
		next_pressure = RivalPressureTier.MEDIUM
	elif _reputation <= -25.0:
		next_pressure = RivalPressureTier.LOW
	if next_pressure != _pressure_tier:
		_pressure_tier = next_pressure
		if emit_changes:
			pressure_tier_changed.emit(_pressure_tier)

	var next_takeover := (
		_reputation >= 100.0
		and _owner_faction != OwnerFaction.PLAYER
	)
	if next_takeover != _takeover_available:
		_takeover_available = next_takeover
		if emit_changes:
			takeover_availability_changed.emit(_takeover_available)
			purchase_availability_changed.emit(_takeover_available)
			wipe_availability_changed.emit(_takeover_available)
