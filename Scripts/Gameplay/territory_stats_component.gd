class_name TerritoryStatsComponent
extends Node

signal reputation_changed(current: float)
signal heat_changed(current: float)

@export var territory_id: StringName = &"test_territory"
@export_range(0.0, 100.0, 0.1) var starting_reputation := 0.0
@export_range(0.0, 100.0, 0.1) var starting_heat := 0.0
@export_range(0.0, 10.0, 0.05) var heat_decay_per_second := 0.25
@export_range(0.0, 100.0, 0.1) var trade_lock_heat := 76.0

var reputation: float:
	get:
		return _reputation
var heat: float:
	get:
		return _heat

var _reputation := 0.0
var _heat := 0.0


func _ready() -> void:
	_reputation = clampf(starting_reputation, 0.0, 100.0)
	_heat = clampf(starting_heat, 0.0, 100.0)
	reputation_changed.emit(_reputation)
	heat_changed.emit(_heat)


func _process(delta: float) -> void:
	if _heat > 0.0 and heat_decay_per_second > 0.0:
		set_heat(_heat - heat_decay_per_second * delta)


func add_reputation(amount: float) -> bool:
	if amount <= 0.0:
		return false

	var next_reputation := clampf(_reputation + amount, 0.0, 100.0)
	if is_equal_approx(next_reputation, _reputation):
		return false

	_reputation = next_reputation
	reputation_changed.emit(_reputation)
	return true


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
	}


func import_save_data(data: Dictionary) -> void:
	var next_reputation := clampf(
		float(data.get("reputation", starting_reputation)),
		0.0,
		100.0
	)
	_reputation = next_reputation
	reputation_changed.emit(_reputation)
	set_heat(float(data.get("heat", starting_heat)))
