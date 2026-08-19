class_name BloodImpactVFX
extends Node3D

## Compatibility wrapper for older callers and scene references.
## New combat code talks to CombatVFXManager directly so transient effects are
## pooled instead of allocating an effect tree for every bullet.

enum SurfaceImpactKind {
	STONE,
	METAL,
}


static func prewarm_resources() -> void:
	pass


func prewarm_runtime() -> void:
	queue_free()


func setup_blood_hit(
	hit_position: Vector3,
	hit_normal: Vector3,
	shot_direction: Vector3,
	hit_collider: Node3D,
	fatal_hit: bool,
	spray_multiplier := 1.0
) -> void:
	var manager := CombatVFXManager.find(get_tree())
	if manager != null:
		manager.spawn_blood_hit(
			hit_position,
			hit_normal,
			shot_direction,
			hit_collider,
			fatal_hit,
			spray_multiplier
		)
	queue_free()


func setup_surface_hit(
	hit_position: Vector3,
	hit_normal: Vector3,
	hit_collider: Node3D,
	impact_kind := SurfaceImpactKind.STONE
) -> void:
	var manager := CombatVFXManager.find(get_tree())
	if manager != null:
		manager.spawn_surface_hit(
			hit_position,
			hit_normal,
			hit_collider,
			CombatVFXManager.SurfaceImpactKind.METAL
			if impact_kind == SurfaceImpactKind.METAL
			else CombatVFXManager.SurfaceImpactKind.STONE
		)
	queue_free()


func clear_marks_attached_to(owner: Node3D) -> void:
	var manager := CombatVFXManager.find(get_tree())
	if manager != null:
		manager.clear_marks_attached_to(owner)
