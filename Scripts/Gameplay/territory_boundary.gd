class_name TerritoryBoundary
extends Area3D

@export var territory_id: StringName
@export var display_name := "Unknown Territory"
@export var local_center := Vector3(64.0, 0.0, 0.0)
@export var local_half_extents := Vector3(73.0, 10.0, 126.5)
@export var stats_path := NodePath("../TerritoryStats")

@onready var stats := get_node(stats_path) as TerritoryStatsComponent

var _box_shapes: Array[CollisionShape3D] = []


func _ready() -> void:
	add_to_group("territory_boundaries")
	_cache_box_shapes()
	if stats != null:
		stats.territory_id = territory_id


func contains_world_position(world_position: Vector3) -> bool:
	# Use the shapes artists see and edit in the scene as the authoritative
	# territory bounds. The exported center/extents remain as a fallback for
	# boundaries created entirely from code or older scenes without a box.
	if not _box_shapes.is_empty():
		for collision_shape in _box_shapes:
			if collision_shape.disabled or collision_shape.shape == null:
				continue
			var box := collision_shape.shape as BoxShape3D
			var shape_position := collision_shape.to_local(world_position)
			var half_extents := box.size * 0.5
			if (
				absf(shape_position.x) <= half_extents.x
				and absf(shape_position.y) <= half_extents.y
				and absf(shape_position.z) <= half_extents.z
			):
				return true
		return false

	var local_position := to_local(world_position) - local_center
	return (
		absf(local_position.x) <= local_half_extents.x
		and absf(local_position.y) <= local_half_extents.y
		and absf(local_position.z) <= local_half_extents.z
	)


func _cache_box_shapes() -> void:
	_box_shapes.clear()
	for node in find_children("*", "CollisionShape3D", true, false):
		var collision_shape := node as CollisionShape3D
		if collision_shape != null and collision_shape.shape is BoxShape3D:
			_box_shapes.append(collision_shape)


static func find_at_position(
	tree: SceneTree,
	world_position: Vector3
) -> TerritoryBoundary:
	for node in tree.get_nodes_in_group("territory_boundaries"):
		var boundary := node as TerritoryBoundary
		if boundary != null and boundary.contains_world_position(world_position):
			return boundary
	return null
