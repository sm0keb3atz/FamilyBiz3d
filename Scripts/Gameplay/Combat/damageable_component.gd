class_name DamageableComponent
extends Node

signal health_changed(current: float, maximum: float)
signal damaged(
	amount: float,
	remaining_health: float,
	source: Node,
	hit_position: Vector3,
	hit_direction: Vector3
)
signal depleted(
	source: Node,
	hit_position: Vector3,
	hit_direction: Vector3
)

@export_range(1.0, 10000.0, 1.0) var maximum_health := 100.0

var health: float:
	get:
		return _health

var _health := 100.0


func _ready() -> void:
	_health = maximum_health
	health_changed.emit(_health, maximum_health)


func apply_damage(
	amount: float,
	source: Node = null,
	hit_position := Vector3.ZERO,
	hit_direction := Vector3.ZERO
) -> bool:
	if amount <= 0.0 or is_depleted():
		return false

	var applied_damage := minf(amount, _health)
	_health = maxf(_health - amount, 0.0)
	health_changed.emit(_health, maximum_health)
	var normalized_hit_direction := hit_direction.normalized()
	damaged.emit(
		applied_damage,
		_health,
		source,
		hit_position,
		normalized_hit_direction
	)
	if is_depleted():
		depleted.emit(source, hit_position, normalized_hit_direction)
	return true


func is_depleted() -> bool:
	return is_zero_approx(_health)


func restore_full_health() -> void:
	_health = maximum_health
	health_changed.emit(_health, maximum_health)
