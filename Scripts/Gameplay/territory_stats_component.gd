class_name TerritoryStatsComponent
extends Node

signal reputation_changed(current: float)

@export var territory_id: StringName = &"test_territory"
@export_range(0.0, 100.0, 0.1) var starting_reputation := 0.0

var reputation: float:
	get:
		return _reputation

var _reputation := 0.0


func _ready() -> void:
	_reputation = clampf(starting_reputation, 0.0, 100.0)
	reputation_changed.emit(_reputation)


func add_reputation(amount: float) -> bool:
	if amount <= 0.0:
		return false

	var next_reputation := clampf(_reputation + amount, 0.0, 100.0)
	if is_equal_approx(next_reputation, _reputation):
		return false

	_reputation = next_reputation
	reputation_changed.emit(_reputation)
	return true
