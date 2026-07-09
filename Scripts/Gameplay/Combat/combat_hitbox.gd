class_name CombatHitbox
extends Area3D

const HEAD_ZONE := "head"
const BODY_ZONE := "body"

@export_enum("body", "head") var hit_zone := BODY_ZONE


func resolve_damage(
	amount: float,
	source: Node = null,
	hit_position := Vector3.ZERO,
	hit_direction := Vector3.ZERO
) -> bool:
	var damageable := get_damageable()
	if damageable == null:
		return false

	var applied_amount := amount
	if hit_zone == HEAD_ZONE:
		applied_amount = maxf(damageable.health, amount)
	return damageable.apply_damage(
		applied_amount,
		source,
		hit_position,
		hit_direction
	)


func get_damageable() -> DamageableComponent:
	var current := get_parent()
	while current != null:
		var component := current.get_node_or_null(
			"DamageableComponent"
		) as DamageableComponent
		if component != null:
			return component
		current = current.get_parent()
	return null


func get_damage_owner() -> Node:
	var damageable := get_damageable()
	if damageable == null:
		return null
	return damageable.get_parent()
